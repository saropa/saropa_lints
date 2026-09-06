# BUG: `require_workmanager_for_background` — fires on UI-only Timer.periodic in State subclass

**Status: Fixed**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `require_workmanager_for_background`
File: `lib/src/rules/packages/workmanager_rules.dart` (line ~226)
Severity: High (forces `// ignore:` workaround on common UI patterns)
Rule version: v2 -> v3

---

## Summary

The rule fired on `Timer.periodic` usage intended to warn about background tasks that should use workmanager. However, it also fired on UI-only timers created inside `State` subclasses that are properly canceled in `dispose()` -- such as typewriter animation effects and clock-tick displays. These timers only run while the widget is mounted and visible; they are not background tasks.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'require_workmanager_for_background'" lib/src/rules/
# Result:
# lib/src/rules/packages/workmanager_rules.dart:265:    'require_workmanager_for_background',
```

**Emitter registration:** `lib/src/rules/packages/workmanager_rules.dart:265`
**Rule class:** `RequireWorkmanagerForBackgroundRule` -- registered at line 227
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// Minimal reproduction: UI clock timer properly scoped to widget lifecycle.
class _WorldClockState extends State<WorldClockScreen> {
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    // Update displayed time every second -- purely UI, not a background task.
    _clockTimer = Timer.periodic( // was LINT -- now correctly silent
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel(); // Timer is canceled on screen exit
    super.dispose();
  }
}
```

**Frequency:** Always -- fired on every `Timer.periodic` regardless of lifecycle context.

---

## Root Cause

The rule detected `Timer.periodic` calls and warned unconditionally (after checking workmanager wasn't already imported). It did not check whether the timer was created inside a `State` subclass or whether the enclosing class had a `dispose()` method that calls `cancel()` on the same field.

---

## Fix

`RequireWorkmanagerForBackgroundRule.runWithReporter` now calls a new
`_isTimerInDisposableState(MethodInvocation node)` helper before reporting:

1. Walks up from the `Timer.periodic` call to the enclosing `ClassDeclaration`
   via `thisOrAncestorOfType<ClassDeclaration>()`.
2. Returns `false` (still flag) if there is no enclosing class, or the class's
   `extendsClause` superclass name isn't `State` / doesn't end with `State`.
3. Delegates the "is the timer's field canceled inside `dispose()`" check to
   the shared `isBackgroundWorkCanceledInDispose` helper in
   `lib/src/target_matcher_utils.dart` -- the same helper already used by
   `RequireAppLifecycleHandlingRule` (`lifecycle_rules.dart`) and a disposal
   rule (`disposal_rules.dart`) for the identical Timer/State/dispose shape,
   so all three rules agree on what counts as "lifecycle-managed."

Non-State classes (services) and top-level `Timer.periodic` calls are
unaffected and continue to lint, since they have no framework-guaranteed
teardown point.

Rule version bumped v2 -> v3 (detection logic changed); `{v3}` marker updated
in the `LintCode` message.

---

## Verification

Fixture: `example_packages/lib/workmanager/require_workmanager_for_background_fixture.dart`
(previously a stub with no functional cases; now covers all four bug-report scenarios).

`dart run saropa_lints scan example_packages --tier comprehensive --resolve --files lib/workmanager/require_workmanager_for_background_fixture.dart --format json`
confirms `require_workmanager_for_background` fires exactly on the three `expect_lint`-marked
lines (State without cancel, non-State service class, top-level function) and is silent on
the two State-with-cancel GOOD cases (clock ticker, typewriter effect).

`dart test test/rules/packages/workmanager_rules_test.dart`,
`dart test test/integrity/saropa_lints_test.dart`, and
`dart test test/integrity/anti_pattern_detection_test.dart` all pass.

---

## Environment

- saropa_lints version: current
- Triggering project/files:
  - `d:\src\contacts\lib\components\main_layout\search\app_search_bar.dart:196`
  - `d:\src\contacts\lib\views\country\world_clock_list_screen.dart:129`

---

## Finish Report (2026-09-05)

`RequireWorkmanagerForBackgroundRule` reported unconditionally on every
`Timer.periodic` call, including timers created inside a widget's `State`
and canceled in `dispose()` -- a UI-lifecycle pattern (clock ticks,
typewriter animations) that cannot run in the background at all and so
needs no workmanager migration.

The fix adds `_isTimerInDisposableState(MethodInvocation node)` to
`lib/src/rules/packages/workmanager_rules.dart`, called before the existing
`reporter.atNode(node)`. It walks up to the enclosing `ClassDeclaration`,
requires the superclass name to end with `State` (covers `State<T>` and
subclasses like `ConsumerState`), and delegates the "field is canceled in
dispose()" check to the existing `isBackgroundWorkCanceledInDispose` helper
in `lib/src/target_matcher_utils.dart` -- the same helper `lifecycle_rules.dart`
(`RequireAppLifecycleHandlingRule`) and `disposal_rules.dart` already use for
the identical Timer/State/dispose shape, keeping all three rules consistent.
Non-State classes and top-level `Timer.periodic` calls are unaffected.

Rule doc bumped `Rule version: v2 -> v3` and `Updated: v4.13.0 -> v16.0.0-beta.5`;
`LintCode` message marker updated to `{v3}` to match.

The previously-stub fixture
`example_packages/lib/workmanager/require_workmanager_for_background_fixture.dart`
was rewritten with real cases: two State-with-cancel GOOD cases (clock
ticker, typewriter effect) and three `expect_lint`-marked BAD cases (State
without cancel, plain service class, top-level function). Verified via
`dart run saropa_lints scan example_packages --tier comprehensive --resolve
--files lib/workmanager/require_workmanager_for_background_fixture.dart
--format json`: the rule fires exactly on the three marked lines (71, 92,
101) and stays silent on both GOOD cases.

`dart test test/rules/packages/workmanager_rules_test.dart`,
`dart test test/integrity/saropa_lints_test.dart`, and
`dart test test/integrity/anti_pattern_detection_test.dart` all pass.
A medium-level `/code-review` pass flagged a stale `Updated:` doc tag and a
redundant boolean clause (`superName != 'State' && !superName.endsWith('State')`);
both were fixed and re-verified before commit.
