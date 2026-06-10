// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, undefined_class, undefined_method
// ignore_for_file: undefined_identifier, missing_required_argument, undefined_named_parameter
// ignore_for_file: undefined_function, non_type_as_type_argument, return_of_invalid_type
// ignore_for_file: body_might_complete_normally, argument_type_not_assignable

/// Fixture for `avoid_shader_mask_in_scrollable`.
import 'package:saropa_lints_example/flutter_mocks.dart';

// BAD: ShaderMask forces an offscreen saveLayer for every visible item.
// expect_lint: avoid_shader_mask_in_scrollable
Widget _bad(List<Widget> items, dynamic cb) => ListView(
      children: [
        for (final w in items) ShaderMask(shaderCallback: cb, child: w),
      ],
    );

// GOOD: gradient applied as a decoration per item — no per-item saveLayer.
Widget _good(List<Widget> items) => ListView(children: items);
