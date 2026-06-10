// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_clip_path_in_animated_builder`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: ClipPath recomputes the clip and re-rasterizes every animation frame.
// expect_lint: avoid_clip_path_in_animated_builder
Widget _bad(dynamic controller, dynamic clipper, Widget child) =>
    AnimatedBuilder(
      animation: controller,
      builder: (context, _) => ClipPath(clipper: clipper, child: child),
    );

// GOOD: clip once outside the builder (or use ClipRRect for simple shapes).
Widget _good(dynamic clipper, Widget child) =>
    ClipPath(clipper: clipper, child: child);
