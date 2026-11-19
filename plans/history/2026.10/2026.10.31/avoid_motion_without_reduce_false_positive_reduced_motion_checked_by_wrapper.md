# BUG: `avoid_motion_without_reduce` — Flags FadeTransition/SlideTransition/ScaleTransition in widgets whose controller already settles under reduced motion

**Status: Open**

Created: 2026-10-31
Rule: `avoid_motion_without_reduce`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~3449)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags FadeTransition/SlideTransition/ScaleTransition in widgets whose controller already settles under reduced motion. In a downstream app review, 6 of 7 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_motion_without_reduce'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:3449:    'avoid_motion_without_reduce',
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:3449`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
class _ToastMotion extends StatefulWidget { ... }
class _ToastMotionState extends State<_ToastMotion> with SingleTickerProviderStateMixin {
  // controller is started through toastPlayOrSettle(), which jumps to the end value
  // when MediaQuery.disableAnimations is true.
  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _opacity, // LINT — but should NOT lint
        child: ScaleTransition(scale: _scale, child: widget.child),
      );
}
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/system/toasts/toast_motion_widgets.dart:99,101,161,260; lib/utils/system/toasts/popup_toast_wrapper.dart:79,81.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_motion_without_reduce]` reported at each site above |

---

## Root Cause

The rule looks for `MediaQuery.disableAnimations` / `accessibleNavigation` in the same build method only. A transition widget driven by a controller that the state class already settles (a helper that sets `controller.value = 1.0` under reduced motion) is compliant, but the check is local to build.

---

## Suggested Fix

Search the whole enclosing State class (initState/didChangeDependencies) for a reduced-motion read before reporting. Optionally honor a documented helper name via a configurable allowlist.

---

## Fixture Gap

The fixture for `avoid_motion_without_reduce` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Resolution

Fixed. For `*Transition` widgets, the rule now skips when the enclosing class source mentions `disableAnimations`, `accessibleNavigation`, `reduceMotion`/`reducedMotion`, or a `settle` helper (case-insensitive). Fixture has a bad near-miss (class with no handling) and a good case (`toastPlayOrSettle` in `initState`). Verified with `dart run saropa_lints:scan` on a scratch project (bad flagged, good silent). Note: the scan sees bare `Foo(...)` as a method call, so the scratch copy used `new`.
