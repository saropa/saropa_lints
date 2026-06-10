// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_opacity_in_animated_builder`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Opacity allocates an offscreen layer and rebuilds every animation tick.
// expect_lint: avoid_opacity_in_animated_builder
Widget _bad(dynamic controller, Widget child) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Opacity(opacity: controller.value, child: child),
    );

// GOOD: FadeTransition drives opacity directly — no per-tick Opacity rebuild.
Widget _good(dynamic animation, Widget child) =>
    FadeTransition(opacity: animation, child: child);
