# BUG: `avoid_ios_battery_drain_patterns` — fires on UI-only Timer.periodic in State subclass

**Status: Open**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `avoid_ios_battery_drain_patterns`
File: `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart` (line ~3982)
Severity: High (forces `// ignore:` workaround on common UI patterns)
Rule version: v2

---

## Summary

The rule fires on `Timer.periodic` warning about iOS battery drain. However, the flagged timer is a UI clock-tick display inside a `State` subclass that is properly cancelled in `dispose()`. The timer only runs while the widget is mounted and visible on screen -- it cannot drain battery when the app is backgrounded because the widget (and its timer) are disposed.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'avoid_ios_battery_drain_patterns'" lib/src/rules/
# Result:
# lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:4005:    'avoid_ios_battery_drain_patterns',
```

**Emitter registration:** `lib/src/rules/platforms/ios_platform_lifecycle_rules.dart:4005`
**Rule class:** `AvoidIosBatteryDrainPatternsRule` -- registered at line 3982
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
// UI clock timer -- updates displayed time every second while screen is visible.
class _WorldClockState extends State<WorldClockScreen> {
  Timer? _clockTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic( // LINT -- but should NOT lint
      const Duration(seconds: 1),
      (_) => _setStateSafe(),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel(); // Cancelled on screen exit -- cannot drain battery
    super.dispose();
  }
}
```

**Frequency:** Always -- fires on every `Timer.periodic` regardless of lifecycle context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic -- the timer is inside a `State` subclass with `cancel()` in `dispose()`, ensuring it does not run when the app is backgrounded |
| **Actual** | `[avoid_ios_battery_drain_patterns] Pattern detected that may cause excessive battery drain` reported at the Timer.periodic call |

---

## AST Context

```
ClassDeclaration (_WorldClockState) extends State<WorldClockScreen>
  └─ MethodDeclaration (didChangeDependencies)
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression (_clockTimer = ...)
                  └─ MethodInvocation (Timer.periodic)  <- node reported here
```

---

## Root Cause

Same structural limitation as `require_workmanager_for_background` (filed separately). The rule detects `Timer.periodic` as a potential battery drain pattern but does not check whether the timer is lifecycle-bound to a widget via `State.dispose()` cancellation. A properly disposed UI timer cannot cause battery drain because it stops running when the widget is removed from the tree -- which happens before or during app backgrounding.

---

## Suggested Fix

Same heuristic as `require_workmanager_for_background`:

1. Is the `Timer.periodic` call inside a class that extends `State<T>`?
2. Does the enclosing class have a `dispose()` method that calls `cancel()` on the timer field?

If both are true, skip the diagnostic. The timer is widget-lifecycle-bound and cannot run in the background.

Both rules (`require_workmanager_for_background` and `avoid_ios_battery_drain_patterns`) would benefit from a shared utility that checks "is this Timer.periodic lifecycle-managed in a State subclass?"

---

## Fixture Gap

The fixture should include:

1. **Timer.periodic in State with cancel in dispose** -- expect NO lint
2. **Timer.periodic in State WITHOUT cancel in dispose** -- expect LINT (real battery drain risk)
3. **Timer.periodic in a service class** -- expect LINT
4. **Timer.periodic with AppLifecycleState handling** -- expect NO lint (manages own backgrounding)

---

## Environment

- saropa_lints version: current
- Triggering project/file: `d:\src\contacts\lib\views\country\world_clock_list_screen.dart:129`
