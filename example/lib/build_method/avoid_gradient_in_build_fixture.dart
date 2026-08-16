// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters_skip_private
// ignore_for_file: undefined_class, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_identifier
// ignore_for_file: undefined_named_parameter, missing_required_argument
// ignore_for_file: argument_type_not_assignable, return_of_invalid_type
// ignore_for_file: body_might_complete_normally
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: new_with_undefined_constructor
// ignore_for_file: non_type_as_type_argument
// ignore_for_file: const_initialized_with_non_constant_value
// ignore_for_file: invalid_assignment, list_element_type_not_assignable
// ignore_for_file: not_initialized_non_nullable_variable
// Test fixture for: avoid_gradient_in_build
// Source: lib/src/rules/widget/build_method_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// Hoisted gradient — declared once outside build(), reused on every rebuild.
// Rule should NOT fire here because the visitor only walks `build` bodies.
final BoxDecoration _hoistedDecoration = BoxDecoration(
  gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
);

// BAD: bare non-const LinearGradient in build() return — allocates per build.
// expect_lint: avoid_gradient_in_build
Widget _badBareGradientBuild(BuildContext context) {
  return LinearGradient(colors: [Colors.red, Colors.blue]);
}

// BAD: LinearGradient nested in BoxDecoration that itself is constructed in
// build() — the gradient is the genuine build-time allocation we want to flag.
Widget _badGradientInDecorationBuild(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      // expect_lint: avoid_gradient_in_build
      gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
    ),
  );
}

// GOOD: const LinearGradient — canonicalized by the compiler, no per-build
// allocation. Rule explicitly skips const constructors.
Widget _goodConstGradientBuild(BuildContext context) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Colors.red, Colors.blue]),
    ),
  );
}

// GOOD: gradient lives inside a ShaderMask.shaderCallback closure. The
// framework stores the closure on the render object and invokes it at PAINT
// time with the layout `Rect bounds` — there is no "outside build" location
// to hoist it to (and the animation value changes every frame). Rule must
// not fire here. Regression coverage for:
//   plan/history/2026.05/2026.05.03/avoid_gradient_in_build_false_positive_shadermask_shadercallback.md
Widget _goodShaderCallbackBuild(BuildContext context) {
  return ShaderMask(
    shaderCallback: (Rect bounds) {
      return LinearGradient(
        colors: [Colors.white, Colors.blue, Colors.white],
      ).createShader(bounds);
    },
    child: const Text('shimmer'),
  );
}

// GOOD: hoisted top-level decoration — referenced from build(), not
// constructed in it. Visitor never reaches the LinearGradient because it
// lives outside the build body.
Widget _goodHoistedDecorationBuild(BuildContext context) {
  return Container(decoration: _hoistedDecoration);
}

// GOOD: gradient inside AnimatedBuilder.builder closure. The closure re-runs
// every animation frame with animation-dependent values (alignment driven by
// AnimationController.value), so the gradient intentionally varies per tick.
// Hoisting it would defeat the animation. Regression coverage for:
//   plans/history/2026.08/2026.08.16/avoid_gradient_in_build_fp_animated_builder_closure.md
Widget _goodAnimatedBuilderGradientBuild(BuildContext context) {
  return AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-1.0, 0),
            colors: [Colors.red, Colors.blue],
          ),
        ),
        child: child,
      );
    },
    child: const SizedBox(),
  );
}

// GOOD: gradient inside TweenAnimationBuilder.builder closure — same
// exemption as AnimatedBuilder; the gradient depends on the tween value.
Widget _goodTweenAnimationBuilderGradientBuild(BuildContext context) {
  return TweenAnimationBuilder(
    tween: tween,
    builder: (context, value, child) {
      return Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(colors: [value, Colors.blue]),
        ),
      );
    },
  );
}
