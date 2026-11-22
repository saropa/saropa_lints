# BUG: `avoid_public_members_in_states` — fires on @override members that implement a mixin contract

**Status: Fixed**

Rule: `avoid_public_members_in_states`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart`
Severity: False positive
Sites in downstream app: 8 sites in 6 files (of 18 total; the other 10 are cross-library API and not claimed here)

---

## Summary

The overriding getter in the State class is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'avoid_public_members_in_states'" lib/src/rules/
# Expected: lib/src/rules/widget/widget_lifecycle_rules.dart:NN
```

---

## Reproducer

```dart
mixin PaletteAnimationMixin<T extends StatefulWidget> on State<T> {
  AnimationController get paletteController; // public abstract hook
}
class _BarState extends State<Bar> with PaletteAnimationMixin<Bar> {
  late final AnimationController _c;
  @override
  AnimationController get paletteController => _c; // LINT, but should NOT lint
}
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: an `@override` member cannot be renamed or made private; its visibility is dictated by the supertype or mixin. |
| **Actual** | The overriding getter in the State class is reported. |

---

## Suggested Fix

Skip any member annotated `@override`. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
