# BUG: `avoid_motion_without_reduce` — lint does not recognize a project reduce-motion helper

**Status: Fixed**

Rule: `avoid_motion_without_reduce`
File: `lib/src/rules/ui/accessibility_rules.dart`
Severity: False positive
Sites in downstream app: 8 sites in 7 files

---

## Summary

The animated widget is reported because only direct `MediaQuery.disableAnimations*` reads in the same build method are recognized. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_motion_without_reduce'" lib/src/rules/
# Expected: lib/src/rules/ui/accessibility_rules.dart:NN
```

---

## Reproducer

```dart
// Project helper wraps MediaQuery.disableAnimationsOf plus the platform Reduce Motion flag.
return AnimatedOpacity( // LINT, but should NOT lint
  opacity: _opacity,
  duration: MotionPreferenceUtils.isMotionReduced(context) ? Duration.zero : widget.fadeIn,
  child: child,
);
// Variant: AnimatedBuilder driven by a controller that jumps to its end when
// isMotionReduced is true (the check lives in the controller, not the widget).
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the duration is gated on a reduce-motion check performed through a user-defined helper, or when the driving controller is already collapsed under reduced motion. |
| **Actual** | The animated widget is reported because only direct `MediaQuery.disableAnimations*` reads in the same build method are recognized. |

---

## Suggested Fix

Treat any call whose name matches `isMotionReduced|reduceMotion|disableAnimations` as a guard; skip when `duration` is a conditional expression or `Duration.zero`. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
