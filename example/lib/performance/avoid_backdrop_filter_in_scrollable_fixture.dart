// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_backdrop_filter_in_scrollable`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: BackdropFilter re-filters the whole backdrop for every visible item.
// expect_lint: avoid_backdrop_filter_in_scrollable
Widget _bad(List<Widget> items, dynamic blur) => GridView(
      children: [
        for (final w in items) BackdropFilter(filter: blur, child: w),
      ],
    );

// GOOD: single BackdropFilter applied once, outside the scrollable.
Widget _good(Widget list, dynamic blur) =>
    BackdropFilter(filter: blur, child: list);
