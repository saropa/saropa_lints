// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_opacity_in_scrollable`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: Opacity creates a per-item offscreen layer while scrolling.
// expect_lint: avoid_opacity_in_scrollable
Widget _bad(List<Widget> items) => ListView(
      children: [
        for (final w in items) Opacity(opacity: 0.5, child: w),
      ],
    );

// GOOD: no per-item Opacity — bake alpha into the child instead.
Widget _good(List<Widget> items) => ListView(children: items);
