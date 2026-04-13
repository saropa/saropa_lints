# BUG: `avoid_stream_subscription_in_field` — False Positive on Conditional `.listen()` with Proper Capture and Disposal

**Status: FIXED**

Created: 2026-04-13
Rule: `avoid_stream_subscription_in_field`
File: `lib/src/rules/core/async_rules.dart` (line ~2962)
Severity: False positive — forces unnecessary `// ignore:` suppression on correct code
Rule version: v4 | Since: v2.3.7 | Updated: v4.13.0
Related: `plan/history/2026.03/20260325/avoid_stream_subscription_in_field_false_positive.md` (marked RESOLVED, but issue persists)

---

## Summary

The rule fires on a `.listen()` call that is:

1. Assigned to a `StreamSubscription<bool>?` field named `_rebuildTriggerSubscription`
2. Properly canceled in `dispose()` via `_rebuildTriggerSubscription?.cancel()`
3. Inside an `if` block in `initState()`

The first AST-walk loop (lines 3049-3099) should match at line 3065 (`AssignmentExpression`) and return early because the left-hand identifier ends with `Subscription`. It does not — the lint fires, requiring a `// ignore:` workaround.

---

## Reproducer

Source: `contacts/lib/components/user/user_profile_avatar.dart`

```dart
class _UserProfileAvatarState extends State<UserProfileAvatar> {
  // ignore: saropa_lints/avoid_stream_subscription_in_field
  StreamSubscription<bool>? _rebuildTriggerSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.sizeCommon.isBiggerOrEqualTo(ThemeCommonSize.Large)) {
      _rebuildTriggerSubscription = _createRebuildTriggerStream().listen((_) {
        if (mounted) {
          _refreshData();
        }
      });
    }
  }

  @override
  void dispose() {
    _rebuildTriggerSubscription?.cancel();
    super.dispose();
  }
}
```

This code follows every best practice:

- Subscription stored in a properly-typed `StreamSubscription<bool>?` field
- Field name ends with `Subscription` (matches `_subscriptionVarNames` suffix check at line 3071)
- Canceled before `super.dispose()`
- Conditional subscription (only for large avatars) — a valid performance optimization

---

## Expected AST Walk (First Loop, Lines 3049-3099)

Starting from the `.listen()` MethodInvocation node at the assignment:

```
_rebuildTriggerSubscription = _createRebuildTriggerStream().listen((_) { ... })
```

| Step | `current` node type | Expected match |
|------|---------------------|----------------|
| 1 | `node.parent` = **AssignmentExpression** | Line 3065: `current is AssignmentExpression` |
| 2 | `leftSide` = `SimpleIdentifier(_rebuildTriggerSubscription)` | Line 3069: `leftSide is SimpleIdentifier` |
| 3 | `leftSource` = `'_rebuildTriggerSubscription'` | Line 3071: `leftSource.endsWith('Subscription')` = **true** |
| 4 | **Should `return`** (no lint) | Line 3072 |

The rule should exit at step 4 with no diagnostic. It does not.

---

## Possible Root Causes

### Hypothesis A: Conditional Block Interferes with Parent Walk

The `.listen()` call is nested inside an `if` block:

```
MethodDeclaration (initState)
  └─ Block
      └─ IfStatement
          └─ Block
              └─ ExpressionStatement
                  └─ AssignmentExpression          ← should match here
                      ├─ SimpleIdentifier (_rebuildTriggerSubscription)
                      └─ MethodInvocation (.listen) ← node
```

If the first loop walks `node.parent` and the immediate parent of `.listen()` is NOT the `AssignmentExpression` (e.g., if there's an intermediate `FunctionExpressionInvocation` or `ParenthesizedExpression` node), the loop would skip past the assignment and fall through to the second loop, which would find `ExpressionStatement` at line 3110 and fire the lint.

### Hypothesis B: `.listen()` Target Type Resolution

`_createRebuildTriggerStream()` returns `Stream<bool>`. The `_isStreamOrSubclass` check should pass. However, if the return type resolves differently (e.g., as the `Stream<bool>.multi` constructor return type), the `staticType` chain may differ. Unlikely but worth verifying.

### Hypothesis C: Inner `.listen()` Calls Inside `Stream.multi`

The `_createRebuildTriggerStream()` method contains inner `.listen()` calls:

```dart
Stream<bool>.multi((StreamController<bool> controller) {
  final List<StreamSubscription<bool>> subscriptions = <StreamSubscription<bool>>[];
  for (final Stream<bool> stream in streams) {
    subscriptions.add(
      stream.listen(
        (bool _) => controller.add(true),
        onError: (Object error, StackTrace stack) {
          debugException(error, stack);
        },
      ),
    );
  }
  controller.onCancel = () {
    for (final StreamSubscription<bool> sub in subscriptions) {
      sub.cancel();
    }
  };
});
```

These inner `.listen()` calls are passed as arguments to `subscriptions.add(...)`. The second loop (line 3102) should find `ArgumentList` at line 3104 and return. However, if the parent walk encounters the `for` loop body `Block` (line 3121: `current is Block`) before reaching `ArgumentList`, it would break early and fall through to fire the lint.

The AST parent chain for inner `.listen()`:

```
MethodInvocation (.add)
  └─ ArgumentList
      └─ MethodInvocation (.listen)  ← node
```

`node.parent` should be `ArgumentList` directly. But if the Dart analyzer wraps the expression differently, the walk may miss it.

---

## Additional Issue: `// ignore:` Placement Mismatch

The `// ignore:` comment is on line 55 (the field declaration):

```dart
// ignore: saropa_lints/avoid_stream_subscription_in_field
StreamSubscription<bool>? _rebuildTriggerSubscription;
```

But the rule registers via `context.addMethodInvocation` (line 3034) and reports via `reporter.atNode(node)` where `node` is the `.listen()` MethodInvocation — which is on line 70 inside `initState()`, not on the field declaration.

An `// ignore:` comment only suppresses diagnostics reported on the **next line**. The ignore at line 55 suppresses line 56 (the field), but the diagnostic is reported at line 70 (the `.listen()` call). This means:

1. The `// ignore:` on line 55 may not actually suppress the lint
2. Users place the ignore on the field because the rule name says "in field" — an intuitive but incorrect location
3. If the lint IS suppressed, it's because the custom_lint framework has broader ignore semantics than standard `dart analyze`

---

## Suggested Fixes

### Fix A: Debug the Parent Walk

Add a fixture that reproduces the exact pattern: `.listen()` inside an `if` block inside `initState()`, assigned to a field ending in `Subscription`. Verify the first loop reaches `AssignmentExpression`. If it doesn't, the intermediate AST nodes need to be handled.

### Fix B: Add `IfStatement` / `Block` Transparency to First Loop

The first loop breaks on `MethodDeclaration`, `FunctionDeclaration`, and `ClassDeclaration` (line 3092-3094). It does NOT break on `Block` or `IfStatement`. However, if some intermediate node type is not handled and causes the loop to skip the `AssignmentExpression`, adding explicit pass-through for `IfStatement`, `ForStatement`, and `Block` nodes would fix it.

### Fix C: Report on the Field Declaration, Not the `.listen()` Call

If the rule's intent is to flag fields that hold subscriptions, report on the `FieldDeclaration` node. This makes `// ignore:` placement intuitive (on the field) and allows the rule to check whether `dispose()` cancels that field — which is what the rule name and description promise.

---

## Fixture Gap

The fixture at `example_async/lib/async/avoid_stream_subscription_in_field_fixture.dart` should include:

1. **Conditional listen**: `.listen()` inside `if` block, assigned to a subscription field — expect NO lint
2. **Nested scope listen**: `.listen()` inside a `for` loop or callback, passed to `subscriptions.add()` — expect NO lint
3. **`Stream.multi` inner listen**: `.listen()` inside `Stream.multi` controller callback, stored in local list — expect NO lint
4. **Proper capture + disposal**: field assigned in `initState()`, canceled in `dispose()` — expect NO lint (the documented "GOOD" pattern)

---

## Environment

- saropa_lints rule version: v4
- Dart SDK: 3.x
- Triggering package: `contacts` (saropa)
- File: `lib/components/user/user_profile_avatar.dart`
- Lines: field at 56, `.listen()` at 70, `dispose()` cancel at 80
- Rule source: `lib/src/rules/core/async_rules.dart` lines 2962-3128
- Previous report: `plan/history/2026.03/20260325/avoid_stream_subscription_in_field_false_positive.md` — marked RESOLVED but issue persists in this pattern
