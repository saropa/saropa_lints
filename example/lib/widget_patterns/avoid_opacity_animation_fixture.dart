// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// Test fixture for: avoid_opacity_animation
// Source: lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

final AnimationController _controller = AnimationController(
  vsync: null,
  duration: const Duration(milliseconds: 300),
);

bool _isShown = true;

// BAD: Opacity wrapping a child inside an AnimatedBuilder where the opacity
// value is a *non-literal* expression — potentially animation-driven, so this
// is exactly the per-frame opacity rebuild the rule targets.
Widget _badAnimatedOpacity() {
  return AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) {
      // expect_lint: avoid_opacity_animation
      return Opacity(
        opacity: _controller.value,
        child: const Text('animated'),
      );
    },
  );
}

// GOOD: Opacity inside an AnimatedBuilder, but the opacity is a *constant*
// numeric literal. The animation drives a sibling property (the icon swap);
// the opacity itself never changes per frame, so no rebuild cost is paid.
// Replacing this with FadeTransition would introduce an animation that
// doesn't currently exist.
Widget _goodConstantOpacityInsideAnimatedBuilder() {
  return AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) {
      final String label = _controller.value > 0.5 ? 'collapse' : 'expand';
      return Opacity(opacity: 0.6, child: Text(label));
    },
  );
}

// GOOD: Constant integer opacity inside an AnimatedBuilder — same reasoning
// as the double-literal case above.
Widget _goodIntegerLiteralOpacityInsideAnimatedBuilder() {
  return AnimatedBuilder(
    animation: _controller,
    builder: (BuildContext context, Widget? child) {
      return Opacity(opacity: 1, child: const Text('static'));
    },
  );
}

// GOOD: Opacity outside any animation context — never triggers regardless of
// whether the value is constant or not.
Widget _goodOpacityOutsideAnimation() {
  return Opacity(opacity: 0.5, child: const Text('static'));
}
