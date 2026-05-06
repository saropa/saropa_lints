# BUG: `avoid_context_across_async` — Compound `&&` Mounted Check in Ternary Guard Not Recognized

**Status: Fixed (pending release in 13.0.0)**

Created: 2026-04-30
Fixed: 2026-05-01
Rule: `avoid_context_across_async`
File: `lib/src/async_context_utils.dart` (lines ~252-396)
Severity: False positive
Rule version: v7 | Since: v2.3.10 | Updated: v13.0.0

---

## Summary

`_isInMountedGuardedTernary` recognizes `context.mounted ? context : null` as a safe guarded ternary (rule documentation explicitly lists this pattern in `context_rules.dart:425`). But the helper it delegates to — `_isMountedCheck` — only handles three condition forms: bare `mounted`, `context.mounted`, and `context?.mounted ?? false`. It does NOT handle a compound `&&` condition that includes a mounted check, e.g. `context != null && context.mounted ? context : null`. That compound form is the IDIOMATIC safe pattern when `context` is a nullable parameter (`BuildContext?`), since a bare `context.mounted` would null-deref. Both `context` references inside such a ternary are flagged even though the guard is correct.

The rule's own docstring at `context_rules.dart:424` advertises support for "Compound conditions" in `if`-form guards (`if (context.mounted && other)`), so the missing branch in `_isMountedCheck` is asymmetric — `if`-form compound checks are documented as supported, but the helper used by ternary detection has no `BinaryExpression` `&&` branch.

---

## Attribution Evidence

```bash
# Positive
grep -rn "'avoid_context_across_async'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:243:    'avoid_context_across_async',

# Negative
grep -rn "'avoid_context_across_async'" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# 0 matches
```

**Emitter registration:** `lib/src/rules/core/context_rules.dart:243` (rule code definition); rule class registered via `lib/src/rules/all_rules.dart`.
**Rule class:** `AvoidContextAcrossAsyncRule`
**Helpers in scope:** `ContextUsageFinder._isInMountedGuardedTernary` and `ContextUsageFinder._isMountedCheck` in `lib/src/async_context_utils.dart` lines 298 and 324.
**Diagnostic `source` / `owner`:** `dart`

---

## Reproducer

Real source: `d:/src/contacts/lib/utils/system/screen_utils.dart` line 89, inside the catch block of an `async` extension method on `Widget` (`showScreen`). The parameter is `BuildContext? context` (nullable).

```dart
extension ScreenExtensions on Widget {
  Future<bool> showScreen(BuildContext? context) async {
    try {
      // ... awaits ...
      await Future<void>.delayed(Duration.zero);
      // ... more awaits ...
      return true;
    } on Object catch (error, stack) {
      // Idiomatic safe ternary for nullable BuildContext.
      // Both `context` identifiers are flagged: the one in the condition
      // (col 45) AND the one in the then-branch (col 82).
      debugException(
        error,
        stack,
        context: context != null && context.mounted ? context : null, // LINT — but should NOT lint (FP)
      );
      return false;
    }
  }
}
```

**Frequency:** Always — fires on every nullable-context guarded ternary using `&&` to combine the null check with the mounted check.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The condition `context != null && context.mounted` provably guards both the null case and the unmounted case. The then-branch `context` is safe because reaching it means both `context != null` AND `context.mounted` evaluated true. |
| **Actual** | `[avoid_context_across_async] BuildContext used after await crashes if widget was disposed during the async gap.` reported on BOTH `context` references on the same line — the one inside the compound condition AND the one in the then-branch. |

---

## AST Context

```
ExpressionStatement
  └─ MethodInvocation (debugException)
      └─ ArgumentList
          └─ NamedExpression (context: ...)
              └─ ConditionalExpression                       ← rule walks up to here
                  ├─ condition: BinaryExpression (&&)        ← _isMountedCheck rejects this
                  │   ├─ left:  BinaryExpression (!=)        (context != null)
                  │   └─ right: PrefixedIdentifier .mounted  (context.mounted)
                  ├─ then:  SimpleIdentifier (context)       ← FLAGGED (col 82)
                  └─ else:  NullLiteral
```

The first flagged `context` at col 45 is the LHS of the inner `context != null` BinaryExpression — it is part of the condition itself, not a usage. The reporter still emits because `ContextUsageFinder.visitSimpleIdentifier` only knows to skip `context.mounted` (PrefixedIdentifier with `mounted`) and `context?.mounted` (PropertyAccess) — it has no skip rule for `context != null`.

---

## Root Cause

Two narrow gaps in `lib/src/async_context_utils.dart`:

### Gap 1 — `_isMountedCheck` does not recognize compound `&&` conditions

`_isMountedCheck(Expression expr)` at line 324 has these arms:
- `PrefixedIdentifier` with name `mounted` → match
- `SimpleIdentifier` with name `mounted` → match
- `BinaryExpression` with `??` operator → match (nullable-safe variant)

It has no arm for `BinaryExpression` with `&&` operator. The compound condition `context != null && context.mounted` is a `BinaryExpression` of type `&&`, with one operand being `context.mounted` (which the helper would match in isolation). The helper must recurse into both operands when `&&` is encountered: if either operand is itself a mounted check, the compound is a valid mounted guard for the then-branch.

### Gap 2 — `ContextUsageFinder.visitSimpleIdentifier` does not skip `context` used as the LHS of `context != null` when that null check is part of a guarded ternary's condition

The visitor at `async_context_utils.dart:253-291` skips `context.mounted` and `context?.mounted` but reports `context` when it appears as the LHS of `context != null`. Inside a guarded-ternary condition this is provably safe — `context != null` is a guard, not a usage. The fix is to detect that the SimpleIdentifier is inside a `ConditionalExpression.condition` whose compound includes a mounted check, and skip the report.

(Closing only Gap 1 will silence the then-branch report at col 82 but NOT the condition-side report at col 45. Both gaps need to close for the FP to fully clear.)

---

## Suggested Fix

In `lib/src/async_context_utils.dart`, extend `_isMountedCheck` to handle `&&` recursively:

```dart
bool _isMountedCheck(Expression expr) {
  // existing arms: PrefixedIdentifier, SimpleIdentifier, ?? BinaryExpression …

  // NEW: compound `&&` — either operand being a mounted check is sufficient.
  // This matches the rule's own docstring at context_rules.dart:424 which
  // advertises "Compound conditions" support for if-form guards.
  if (expr is BinaryExpression &&
      expr.operator.type == TokenType.AMPERSAND_AMPERSAND) {
    return _isMountedCheck(expr.leftOperand) ||
           _isMountedCheck(expr.rightOperand);
  }

  return false;
}
```

And in `ContextUsageFinder.visitSimpleIdentifier`, add a skip for `context` used as the LHS of `context != null` when that null check sits inside a guarded-ternary condition (or inside an `if` condition that also includes a mounted check):

```dart
// Skip if context is the LHS of a `context != null` test that is itself
// part of a guarded-ternary condition OR an if-condition whose compound
// includes a mounted check. Nothing dereferences context here — it's a guard.
if (parent is BinaryExpression &&
    parent.operator.type == TokenType.BANG_EQ &&
    parent.rightOperand is NullLiteral &&
    _isInsideMountedGuardedCondition(parent)) {
  super.visitSimpleIdentifier(node);
  return;
}
```

Where `_isInsideMountedGuardedCondition` walks up to find a `ConditionalExpression` or `IfStatement` whose condition `_isMountedCheck`s true (after the Gap-1 fix).

Bump rule version to v7. Update docstring with a "Not flagged" example showing the compound nullable-context ternary.

---

## Fixture Gap

`example*/lib/context/avoid_context_across_async_fixture.dart` should include:

1. `context.mounted ? context : null` inside async catch — expect NO lint (regression — already covered)
2. `context != null && context.mounted ? context : null` inside async catch with `BuildContext?` parameter — expect NO lint (NEW, this bug)
3. `context.mounted && otherCondition ? context : null` (compound, mounted on left) — expect NO lint (NEW)
4. `otherCondition && context.mounted ? context : null` (compound, mounted on right) — expect NO lint (NEW)
5. `if (context != null && context.mounted) { context.doThing(); }` — expect NO lint (NEW, parity with ternary)
6. `if (other && !context.mounted) return; context.doThing();` — expect NO lint (compound negated guard, NEW)

---

## Changes Made

`lib/src/async_context_utils.dart` (`ContextUsageFinder`):

1. **Gap 1** — `_isMountedCheck` now recurses into compound `&&` expressions:
   `context != null && context.mounted` (and either operand-order variant)
   is recognized as a mounted check for ternary conditions, matching the
   docstring promise of "Compound conditions" support already true for
   if-form guards via `checksMounted`.
2. **Gap 2** — `visitSimpleIdentifier` skips a `context` SimpleIdentifier
   when it is one operand of a `context != null` (or `null != context`)
   `BinaryExpression` AND that null check sits inside the condition of an
   enclosing `ConditionalExpression` or `IfStatement` whose condition
   `_isMountedCheck`s true (after Gap 1). Reaching the then-branch proves
   both `!= null` AND `mounted` evaluated true; the LHS is a guard, not a
   usage.
3. New helpers `_isContextNullCheck` and `_isInsideMountedGuardedCondition`
   support Gap 2. The latter walks up to the first enclosing
   `ConditionalExpression` / `IfStatement`, requires the originating node
   to actually sit inside the condition expression (not the body), and
   stops at function boundaries so mounted scope is not violated.

`lib/src/rules/core/context_rules.dart`:

- Bumped rule version `{v6}` → `{v7}` in the `LintCode.problemMessage`.
- Bumped `Since: v2.3.10 | Updated: v13.0.0 | Rule version: v7` in the
  rule docstring.
- Extended the **Recognized Mounted Guards** docstring section with the
  compound `&&` if-form, the plain mounted ternary, and the compound
  nullable ternary, plus a paragraph clarifying that `context != null`
  inside a compound is a guard rather than a usage.

`example/lib/context/avoid_context_across_async_fixture.dart`:

- Documented the five "Not flagged" patterns from the bug's Fixture Gap
  section (plain mounted ternary, compound nullable ternary, mounted on
  left/right of `&&`, compound `if`-form). Fixture #6
  (`if (other && !context.mounted) return;`) was omitted because it is
  not a sound guard — passing the `if` does not imply mounted, so
  treating it as one would mask a real false negative.

`CHANGELOG.md`:

- Added a `### Fixed` bullet under `[13.0.0] - Unreleased` describing the
  change in user-action terms (covers both rules — see follow-up below).

### Follow-up: parallel fix in `_StaticContextUsageFinder`

`lib/src/rules/core/context_rules.dart` had a structurally identical
`_isMountedCheck` in `_StaticContextUsageFinder` driving the
`avoid_context_after_await_in_static` rule, with the same gaps. The same
two-part patch was applied:

- `_isMountedCheck` now recurses into `&&` `BinaryExpression`s (preserving
  the existing parameter-name filter when the operand is `param.mounted`).
- `visitSimpleIdentifier` skips a tracked context-param identifier when it
  is one operand of a `param != null` (or `null != param`) check inside a
  mounted-guarded ternary or `if`-condition.
- New helpers `_isContextNullCheck` (param-name aware) and
  `_isInsideMountedGuardedCondition` mirror the `ContextUsageFinder`
  helpers.
- `AvoidContextAfterAwaitInStaticRule` rule version bumped `{v4}` → `{v5}`
  (`Updated: v13.0.0 | Rule version: v5`); docstring's "Recognized
  Mounted Guards" extended with the compound nullable ternary form.

`lib/src/rules/widget/widget_lifecycle_rules.dart`'s `_isMountedCheck`
uses a permissive `\bmounted\b` regex over `condition.toSource()`, so the
compound `context != null && context.mounted` already matches via string
inclusion. Not vulnerable to this FP — left unchanged.

The `_StaticContextUsageFinder` is library-private and thus not driven by
a dedicated unit test; the fix mirrors `ContextUsageFinder`'s byte-for-byte
(modulo the param-name filter) and is covered by `dart analyze
--fatal-infos` plus the existing `context_rules_test.dart` suite.

---

## Tests Added

`test/async_context_utils_compound_ternary_test.dart` — 6 behavioral
tests that drive `ContextUsageFinder` over parsed Dart source and assert
exactly which `context` references are reported:

1. Plain `context.mounted ? context : null` — no reports (regression).
2. Compound `context != null && context.mounted ? context : null` — no
   reports (this bug — both LHS and then-branch must be skipped).
3. `context.mounted && other ? context : null` — no reports (mounted on
   left of `&&`).
4. `other && context.mounted ? context : null` — no reports (mounted on
   right of `&&`).
5. Negative control: `other ? context : null` still reports the
   then-branch (no mounted operand → guard does not apply).
6. Negative control: `context != null ? context : null` (no mounted in
   the compound) still reports both `context` references — the new
   Gap-2 skip is correctly scoped to compounds that contain a mounted
   check.

Existing `test/context_rules_test.dart` and
`test/fixture_lint_integration_test.dart` continue to pass.

---

## Commits

<!-- Fill in when merged. -->

---

## Environment

- saropa_lints version: 12.6.1 (resolved in `d:/src/contacts/pubspec.lock`); upstream HEAD reports as 12.8.4
- Dart SDK version: Flutter 3.x channel
- custom_lint version: native analyzer plugin (no custom_lint)
- Triggering project/file: `d:/src/contacts/lib/utils/system/screen_utils.dart` (line 89 — both column 45-52 and column 82-89 flagged on the same line)
