// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_image_filter_in_scrollable`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: ColorFiltered pushes an offscreen filter layer for every visible item.
// expect_lint: avoid_image_filter_in_scrollable
Widget _badColor(List<Widget> items, dynamic cf) => ListView(
      children: [
        for (final w in items) ColorFiltered(colorFilter: cf, child: w),
      ],
    );

// BAD: ImageFiltered has the same per-item cost inside a scrollable.
// expect_lint: avoid_image_filter_in_scrollable
Widget _badImage(List<Widget> items, dynamic f) => GridView(
      children: [
        for (final w in items) ImageFiltered(imageFilter: f, child: w),
      ],
    );

// GOOD: pre-render the filtered image; no per-item filter layer.
Widget _good(List<Widget> items) => ListView(children: items);
