# BUG: `avoid_inert_animation_value_in_build` - False positive inside AnimatedBuilder child build

**Status: Fixed**

Created: 2026-04-29
Resolved: 2026-04-29
Rule: `avoid_inert_animation_value_in_build`
File: `lib/src/rules/ui/animation_rules.dart` (line ~2747)
Severity: False positive

---

## Summary

The rule reported `.value` reads in a widget build even when that subtree was rebuilt by an `AnimatedBuilder` listening to the same animation controller.

---

## Attribution Evidence

```bash
rg "'avoid_inert_animation_value_in_build'" d:/src/saropa_lints/lib/src/rules
# d:/src/saropa_lints/lib/src/rules/ui/animation_rules.dart:2747
```

---

## Reproducer

```dart
AnimatedBuilder(
  animation: controller,
  builder: (context, _) => _DisplayWidget(
    colorAnimation: colorAnimation,
    elevationAnimation: elevationAnimation,
    translateAnimation: translateAnimation,
  ),
);

class _DisplayWidget extends StatelessWidget {
  const _DisplayWidget({
    required this.colorAnimation,
    required this.elevationAnimation,
    required this.translateAnimation,
  });

  final Animation<Color?> colorAnimation;
  final Animation<double> elevationAnimation;
  final Animation<double> translateAnimation;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colorAnimation.value, // OK (should not lint)
      elevation: elevationAnimation.value, // OK (should not lint)
      child: Transform.translate(
        offset: Offset(0, translateAnimation.value), // OK (should not lint)
      ),
    );
  }
}
```

Frequency: Always

---

## Resolution

- Added a conservative AST guard that skips diagnostics when the `.value` receiver is a widget field and that widget is instantiated through a listening builder callback (`AnimatedBuilder`, `ListenableBuilder`, `ValueListenableBuilder`) for the same animation field flow.
- Added fixture coverage for the child-widget read pattern in `example/lib/animation/avoid_inert_animation_value_in_build_fixture.dart`.
- Added regression coverage in `test/avoid_inert_animation_value_in_build_rule_test.dart` to lock the false-positive boundary.
