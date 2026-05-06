# Bug: `avoid_context_after_await_in_static` false positives on guarded context inside try-catch

## Summary

The `avoid_context_after_await_in_static` rule incorrectly flags context usage inside a `try-catch` block even when properly guarded by `if (!context.mounted) return;` and `context.mounted ? context : null` ternary patterns. Two false positives are reported:

1. `context` in the mounted guard itself (`if (!context.mounted) return;`)
2. `context` in the guarded ternary (`context.mounted ? context : null`) inside the catch block

## Severity

**High** -- ERROR-level false positives on idiomatic Flutter safety patterns. The flagged code is doing exactly what the rule recommends: checking `context.mounted` before using context after an await.

## Affected Rule

- **Rule**: `avoid_context_after_await_in_static`
- **File**: `lib/src/rules/context_rules.dart` (lines 452-656)
- **Detection path**: `addMethodDeclaration` handler -> `_checkAsyncStaticBody` -> `_reportContextUsageInStatic` -> `_StaticContextUsageFinder` visitor

## Reproduction

### Triggering code (from `contacts` project)

File: `lib/components/contact/menu/menu_restore_user_contacts.dart`

```dart
static Future<void> _onRestoreAllUserContacts(BuildContext context) async {
  try {
    final List<ContactModel>? contacts = await DatabaseContactIO.dbContactLoadList(
      filters: ContactFilters(...),
      processPrivacySettings: false,
    );

    if (contacts != null && contacts.isNotEmpty) {
      for (final ContactModel contact in contacts) {
        contact.hiddenAt = null;
      }
      await DatabaseContactIO.dbContactUpdateList(contacts);
      if (!context.mounted) return;                          // <-- FALSE POSITIVE 1 (line 52)

      PopupToastUtils.showCommonNotice(
        message: '${contacts.length} Contact restored',
        options: const PopupToastOptions(iconCommon: ThemeCommonIcon.HideRestore),
      );
    }
  } on Object catch (error, stack) {
    debugException(error, stack, context: context.mounted ? context : null);  // <-- FALSE POSITIVE 2 (line 60)
  }
}
```

IDE errors reported:
```
avoid_context_after_await_in_static [ERROR]
Line 52, columns 14-21 (highlights "context" in "if (!context.mounted) return;")

avoid_context_after_await_in_static [ERROR]
Line 60, columns 36-43 (highlights "context" in "context: context.mounted ? context : null")
```

### Why the lint is wrong

**False positive 1 (line 52):** `context` in `if (!context.mounted) return;` is the mounted guard itself. The rule is supposed to RECOGNIZE this as a guard, not flag it. Accessing `context.mounted` after an await is the ONLY way to check if the context is still valid -- flagging it creates an impossible situation where the developer can't use the recommended guard pattern.

**False positive 2 (line 60):** `context.mounted ? context : null` is the guarded ternary pattern. The `context` in the then-branch is protected by the mounted check in the condition. The `_StaticContextUsageFinder` has explicit logic to recognize this pattern (line 695-698), yet it's being flagged.

## Root Cause Analysis

The `_checkAsyncStaticBody` method (lines 509-557) iterates over **top-level block statements** only. The method body structure is:

```
Method body Block
  -> TryStatement              *** Only top-level statement ***
    -> try Block
      -> await (line 37)
      -> if (contacts != null) Block
        -> await (line 51)
        -> if (!context.mounted) return;    (line 52) -- SHOULD be guard
        -> PopupToastUtils.showCommonNotice  (line 54)
    -> catch Block
      -> debugException(... context.mounted ? context : null)  (line 60)
```

### The core problem: `TryStatement` is a single top-level statement

The method body has exactly ONE top-level statement: the `TryStatement`. The `_checkAsyncStaticBody` loop processes this:

```dart
for (final statement in block.statements) {
  // Statement 1: TryStatement
  if (containsAwait(statement)) {  // TRUE -- await is inside the try body
    seenAwait = true;
    hasGuard = false;
    continue;  // SKIPS the entire TryStatement
  }
  // ... no more statements
}
```

The `containsAwait(tryStatement)` call returns `true` because `AwaitFinder` descends into the try body and finds both `await` expressions. The `continue` then skips the entire `TryStatement`.

### But diagnostics ARE reported

Since `containsAwait` returns true and the statement is skipped, the loop ends without reporting anything. This contradicts the observed behavior where two diagnostics are reported.

This means there's either:

1. **A different code path reporting these diagnostics** -- perhaps a secondary registration or a different rule producing diagnostics with the same code name
2. **`containsAwait` on `TryStatement` behaves unexpectedly** -- perhaps `AwaitFinder`'s `visitFunctionExpression` override causes it to miss the await somehow (unlikely since the await is not inside a nested function)
3. **The `_checkAsyncStaticBody` is called recursively** -- perhaps something calls it on the inner try-block body or catch-block body separately
4. **The analysis server is using a cached/different version** of the rule that DOES descend into try-catch blocks and processes inner statements

### Regardless of code path: both usages are safe

Even if the rule does analyze the inner statements:

**For line 52 (`if (!context.mounted) return;`):**
- The `_isContextMountedGuard` check (line 527) should recognize this and set `hasGuard = true`
- But this check only fires on TOP-LEVEL statements of the block being analyzed
- If the rule is analyzing the inner `if (contacts != null)` block, the guard at line 52 would be a nested statement within that if-block, and the mounted guard check might not apply because it's not a direct child of the block being iterated

**For line 60 (`context.mounted ? context : null`):**
- This is in the CATCH block, which is completely separate from the try-block's await/guard flow
- The `_StaticContextUsageFinder` has `_isInMountedGuardedTernary` (line 695) which should recognize this
- But the catch block represents a fundamentally different execution path -- if an exception occurs during the await, the catch block runs. The catch clause receives the same `context` parameter, and the ternary guard is the correct safety pattern

## Proposed Fix

### Fix 1: Descend into try-catch blocks properly (Recommended)

The `_checkAsyncStaticBody` should recognize `TryStatement` and analyze its sub-blocks:

```dart
// Handle try-catch: analyze try body and catch bodies separately
if (statement is TryStatement) {
  // Analyze the try body block
  _checkAsyncStaticBody(
    statement.body,
    contextParamNames,
    onUnguardedUsage,
  );

  // Analyze each catch clause body
  // Note: catch blocks execute when exceptions occur during awaits,
  // so context may be invalid. Apply the same await/guard analysis.
  for (final catchClause in statement.catchClauses) {
    // Catch blocks after a try with await are in the danger zone.
    // But context.mounted ternary guards inside catch are safe.
    _checkAsyncStaticBody(
      catchClause.body,
      contextParamNames,
      onUnguardedUsage,
    );
  }
  continue;
}
```

This recurses into the try and catch blocks rather than treating the entire `TryStatement` as an opaque await-containing statement.

### Fix 2: Ensure `_StaticContextUsageFinder` skips mounted guards in catch blocks

The `_StaticContextUsageFinder` already has `_isInMountedGuardedTernary` and `_hasAncestorContextMountedCheck`. Verify these work correctly for the catch block pattern:

```dart
// In catch block:
debugException(error, stack, context: context.mounted ? context : null);
```

The `context` at column 36 is the named argument label `context:` in `context: context.mounted ? context : null`. The visitor should skip it at line 683 (`if (parent is Label)`).

The `context` at column 36-43 might actually be the second `context` in `context.mounted` (the prefix of `PrefixedIdentifier`). This should be skipped at line 689 (`if (parent is PrefixedIdentifier && parent.identifier.name == 'mounted')`).

Or it could be the third `context` in the ternary's then-branch: `context.mounted ? context : null`. This should be caught by `_isInMountedGuardedTernary` (line 695).

If the column range 36-43 points to `context` at a different position, verify which `context` token is being flagged and ensure the appropriate skip logic covers it.

### Fix 3: Never flag `context.mounted` access itself

As a safety net, ensure the visitor ALWAYS skips `context` when it's the prefix of `context.mounted`, regardless of where it appears:

```dart
// Safe: context.mounted check (context is receiver of .mounted)
// This must ALWAYS be safe -- it's the only way to check mounted status
if (parent is PrefixedIdentifier && parent.identifier.name == 'mounted') {
  super.visitSimpleIdentifier(node);
  return;
}
```

This check exists at line 689 but verify it fires before other checks and is not bypassed.

## Test Cases to Add

Add to `example/lib/context/context_rules_fixture.dart`:

```dart
// GOOD: Context guarded inside try-catch in async static method
// The try body has await + mounted guard, and the catch uses guarded ternary.
// ignore: avoid_context_in_async_static
static Future<void> goodTryCatchWithGuards(BuildContext context) async {
  try {
    final result = await someAsyncOperation();
    if (!context.mounted) return;  // Should NOT trigger

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Result: $result')),
    );
  } on Exception catch (error, stack) {
    debugError(error, stack, context: context.mounted ? context : null);  // Should NOT trigger
  }
}

// GOOD: Nested if-block with mounted guard inside try-catch
// ignore: avoid_context_in_async_static
static Future<void> goodNestedIfWithGuard(BuildContext context) async {
  try {
    final data = await fetchData();
    if (data != null && data.isNotEmpty) {
      await processData(data);
      if (!context.mounted) return;  // Should NOT trigger

      showDialog(
        context: context,  // Should NOT trigger (guarded above)
        builder: (_) => AlertDialog(title: Text('Done')),
      );
    }
  } on Object catch (error, stack) {
    debugException(error, stack, context: context.mounted ? context : null);  // Should NOT trigger
  }
}

// BAD: Context used after await in try-catch WITHOUT guard
// ignore: avoid_context_in_async_static
static Future<void> badTryCatchNoGuard(BuildContext context) async {
  try {
    await someAsyncOperation();
    // expect_lint: avoid_context_after_await_in_static
    Navigator.of(context).pop();  // SHOULD trigger -- no mounted guard
  } catch (e) {
    // expect_lint: avoid_context_after_await_in_static
    ScaffoldMessenger.of(context).showSnackBar(  // SHOULD trigger -- no ternary guard
      SnackBar(content: Text('Error: $e')),
    );
  }
}
```

## Impact Assessment

- **False positive rate**: Any async static method with a try-catch wrapping its body will have context usage flagged, even when properly guarded. This is a very common Flutter error-handling pattern.
- **Workaround**: Add `// ignore: avoid_context_after_await_in_static` to each flagged line
- **Fix complexity**: Medium -- requires `_checkAsyncStaticBody` to handle `TryStatement` by recursing into sub-blocks
- **Regression risk**: Low-Medium -- recursing into try/catch blocks changes the analysis scope; new test cases needed to verify both true positives and true negatives inside try-catch

## Related

- The `_checkAsyncStaticBody` method only iterates top-level `block.statements` and has no special handling for `TryStatement`, `ForStatement`, `WhileStatement`, or other compound statements that contain inner blocks
- The same issue likely affects `SwitchStatement`, `ForStatement`, and other compound statements that wrap code after await
- The `AwaitFinder` correctly descends into try-catch blocks (it only skips `FunctionExpression`), so `containsAwait` on a `TryStatement` returns true
- Commit `ebd496e` (Jan 11, 2026) introduced the three-tier context/static rules
