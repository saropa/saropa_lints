# BUG: `require_workmanager_for_background` — fires on UI-only Timer.periodic in State subclass

**Status: Open**

<!-- Status values: Open -> Investigating -> Fix Ready -> Closed -->

Created: 2026-09-05
Rule: `require_workmanager_for_background`
File: `lib/src/rules/packages/workmanager_rules.dart` (line ~226)
Severity: High (forces `// ignore:` workaround on common UI patterns)
Rule version: v2

---

## Summary

The rule fires on `Timer.periodic` usage intended to warn about background tasks that should use workmanager. However, it also fires on UI-only timers created inside `State` subclasses that are properly cancelled in `dispose()` -- such as typewriter animation effects and clock-tick displays. These timers only run while the widget is mounted and visible; they are not background tasks.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`.

```bash
# Positive -- rule IS defined here
grep -rn "'require_workmanager_for_background'" lib/src/rules/
# Result:
# lib/src/rules/packages/workmanager_rules.dart:243:    'require_workmanager_for_background',
```

**Emitter registration:** `lib/src/rules/packages/workmanager_rules.dart:243`
**Rule class:** `RequireWorkmanagerForBackgroundRule` -- registered at line 226
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
    _clockTimer = Timer.periodic( // LINT -- but should NOT lint
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _clockTimer?.cancel(); // Timer is cancelled on screen exit
    super.dispose();
  }
}

// Second case: typewriter animation effect
class _SearchBarState extends State<AppSearchBar> {
  Timer? _typewriterTimer;

  @override
  void initState() {
    super.initState();
    // Animate placeholder text character by character -- UI effect only.
    _typewriterTimer = Timer.periodic( // LINT -- but should NOT lint
      const Duration(milliseconds: 80),
      (_) => _advanceTypewriter(),
    );
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    super.dispose();
  }
}
```

**Frequency:** Always -- fires on every `Timer.periodic` regardless of lifecycle context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic -- the timer is inside a `State` subclass with a corresponding `cancel()` in `dispose()`, confirming it is a UI timer bound to widget lifecycle |
| **Actual** | `[require_workmanager_for_background] Periodic task detected without workmanager. Dart isolates die when the app is backgrounded...` reported at the Timer.periodic call |

---

## AST Context

```
ClassDeclaration (_WorldClockState) extends State<WorldClockScreen>
  └─ MethodDeclaration (initState)
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression (_clockTimer = ...)
                  └─ MethodInvocation (Timer.periodic)  <- node reported here
```

---

## Root Cause

The rule detects `Timer.periodic` calls and warns that periodic tasks should use workmanager for background execution. However, it does not check whether the timer is created inside a `State` subclass or whether the enclosing class has a `dispose()` method that calls `cancel()` on the timer. A `Timer.periodic` inside a `State` with proper cancellation in `dispose()` is a standard UI pattern (clock ticks, animations, polling while visible) -- not a background task candidate.

---

## Suggested Fix

Before emitting the diagnostic, check:

1. Is the `Timer.periodic` call inside a class that extends `State<T>`?
2. Does the enclosing class have a `dispose()` method?
3. Does that `dispose()` method contain a `cancel()` call on the same field that stores the timer?

If all three are true, the timer is lifecycle-bound to a widget and should not trigger the diagnostic. Only flag `Timer.periodic` in non-State contexts (services, isolates, top-level functions) or in State classes without proper cancellation.

---

## Fixture Gap

The fixture should include:

1. **Timer.periodic in State with cancel in dispose** -- expect NO lint
2. **Timer.periodic in State WITHOUT cancel in dispose** -- expect LINT
3. **Timer.periodic in a service/non-State class** -- expect LINT
4. **Timer.periodic at top level** -- expect LINT

---

## Environment

- saropa_lints version: current
- Triggering project/files:
  - `d:\src\contacts\lib\components\main_layout\search\app_search_bar.dart:196`
  - `d:\src\contacts\lib\views\country\world_clock_list_screen.dart:129`
