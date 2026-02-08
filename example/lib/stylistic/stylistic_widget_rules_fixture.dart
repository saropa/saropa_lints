// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: avoid_unnecessary_containers, prefer_clip_behavior
// ignore_for_file: unused_element, depend_on_referenced_packages
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters, override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member, extends_non_class
// ignore_for_file: mixin_of_non_class, field_initializer_outside_constructor
// ignore_for_file: final_not_initialized, super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member, type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument, undefined_named_parameter
// ignore_for_file: argument_type_not_assignable, invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named, undefined_annotation
// ignore_for_file: creation_with_non_type, invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this, expected_class_member
// ignore_for_file: body_might_complete_normally, not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value, return_of_invalid_type
// ignore_for_file: use_of_void_result, missing_function_body
// ignore_for_file: extra_positional_arguments, not_enough_positional_arguments
// ignore_for_file: unused_label, unused_element_parameter
// ignore_for_file: non_type_as_type_argument, expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token, duplicate_definition
// ignore_for_file: override_on_non_overriding_member, extends_non_class
// ignore_for_file: no_default_super_constructor, extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters, invalid_annotation
// ignore_for_file: invalid_assignment, expected_executable
// ignore_for_file: named_parameter_outside_group, obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration, await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause, could_not_infer
// ignore_for_file: uri_does_not_exist, const_method
// ignore_for_file: redirect_to_non_class, unused_catch_clause
// ignore_for_file: type_test_with_undefined_name, undefined_identifier
// ignore_for_file: undefined_function, undefined_method
// ignore_for_file: undefined_getter, undefined_setter
// ignore_for_file: undefined_class, undefined_super_member
// ignore_for_file: extraneous_modifier, experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type, undefined_operator
// ignore_for_file: dead_code, invalid_override
// ignore_for_file: not_initialized_non_nullable_variable, list_element_type_not_assignable
// ignore_for_file: assignment_to_final, equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration, const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element, missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check, invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type, instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable, constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final, mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class, dead_code_on_catch_subtype
// ignore_for_file: unreachable_switch_case, new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local, late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter, non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression, illegal_async_return_type
// ignore_for_file: type_test_with_non_type, invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure, wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable, static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor, abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type

import 'package:flutter/material.dart';

/// Fixture file for stylistic widget rules.
/// These demonstrate the patterns each rule detects.

// =============================================================================
// prefer_sizedbox_over_container / prefer_container_over_sizedbox
// =============================================================================

class SizedBoxVsContainerExamples extends StatelessWidget {
  const SizedBoxVsContainerExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Container for simple sizing (prefer_sizedbox_over_container)
        // expect_lint: prefer_sizedbox_over_container
        Container(width: 16, height: 16),

        // expect_lint: prefer_sizedbox_over_container
        Container(width: 100),

        // expect_lint: prefer_sizedbox_over_container
        Container(height: 50),

        // expect_lint: prefer_sizedbox_over_container
        Container(
          width: 100,
          height: 100,
          child: Text('Hello'),
        ),

        // GOOD: Container with decoration (not flagged)
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(color: Colors.red),
        ),

        // GOOD: Container with color (not flagged)
        Container(
          width: 100,
          color: Colors.blue,
        ),

        // GOOD: SizedBox for sizing
        SizedBox(width: 16, height: 16),
        SizedBox(width: 100),
        const SizedBox.shrink(),
        const SizedBox.expand(),
      ],
    );
  }
}

// =============================================================================
// prefer_text_rich_over_richtext / prefer_richtext_over_text_rich
// =============================================================================

class TextRichVsRichTextExamples extends StatelessWidget {
  const TextRichVsRichTextExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: RichText widget (prefer_text_rich_over_richtext)
        // expect_lint: prefer_text_rich_over_richtext
        RichText(
          text: TextSpan(
            text: 'Hello ',
            children: [
              TextSpan(
                  text: 'World', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        // GOOD: Text.rich()
        Text.rich(
          TextSpan(
            text: 'Hello ',
            children: [
              TextSpan(
                  text: 'World', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_edgeinsets_symmetric / prefer_edgeinsets_only
// =============================================================================

class EdgeInsetsExamples extends StatelessWidget {
  const EdgeInsetsExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: EdgeInsets.only when symmetric would work (prefer_edgeinsets_symmetric)
        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
          child: Text('Hello'),
        ),

        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16),
          child: Text('Horizontal only'),
        ),

        // expect_lint: prefer_edgeinsets_symmetric
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text('Vertical only'),
        ),

        // GOOD: EdgeInsets.only when values differ
        Padding(
          padding: EdgeInsets.only(left: 16, right: 8),
          child: Text('Different horizontal'),
        ),

        // GOOD: symmetric pair with unpaired side — no clean replacement
        Padding(
          padding: EdgeInsets.only(right: 8, top: 16, bottom: 16),
          child: Text('Unpaired right with symmetric vertical'),
        ),
        Padding(
          padding: EdgeInsets.only(left: 8, top: 16, bottom: 16),
          child: Text('Unpaired left with symmetric vertical'),
        ),
        Padding(
          padding: EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text('Unpaired top with symmetric horizontal'),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 8, left: 16, right: 16),
          child: Text('Unpaired bottom with symmetric horizontal'),
        ),

        // GOOD: one axis symmetric, other axis has mismatched values
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 4),
          child: Text('Symmetric horizontal, different vertical'),
        ),

        // GOOD: EdgeInsets.symmetric
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('Symmetric'),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_borderradius_circular
// =============================================================================

class BorderRadiusExamples extends StatelessWidget {
  const BorderRadiusExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: BorderRadius.all(Radius.circular()) (prefer_borderradius_circular)
        // expect_lint: prefer_borderradius_circular
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),

        // GOOD: BorderRadius.circular()
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
        ),

        // GOOD: BorderRadius.all with elliptical (different use case)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.elliptical(8, 4)),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_expanded_over_flexible / prefer_flexible_over_expanded
// =============================================================================

class ExpandedVsFlexibleExamples extends StatelessWidget {
  const ExpandedVsFlexibleExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // BAD: Flexible with FlexFit.tight (prefer_expanded_over_flexible)
        // expect_lint: prefer_expanded_over_flexible
        Flexible(
          fit: FlexFit.tight,
          child: Text('Should be Expanded'),
        ),

        // GOOD: Expanded
        Expanded(
          child: Text('Already Expanded'),
        ),

        // GOOD: Flexible with FlexFit.loose (different behavior)
        Flexible(
          fit: FlexFit.loose,
          child: Text('Flexible loose'),
        ),

        // GOOD: Flexible without explicit fit (defaults to loose)
        Flexible(
          child: Text('Flexible default'),
        ),
      ],
    );
  }
}

// =============================================================================
// prefer_material_theme_colors / prefer_explicit_colors
// =============================================================================

class ThemeColorsExamples extends StatelessWidget {
  const ThemeColorsExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Hardcoded colors (prefer_material_theme_colors)
        // expect_lint: prefer_material_theme_colors
        Container(color: Colors.blue),

        // expect_lint: prefer_material_theme_colors
        Container(backgroundColor: Colors.red),

        // expect_lint: prefer_material_theme_colors
        Icon(Icons.home, color: Colors.green),

        // GOOD: Theme colors
        Container(color: Theme.of(context).colorScheme.primary),
        Container(color: Theme.of(context).colorScheme.error),
        Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
      ],
    );
  }
}

// =============================================================================
// prefer_clip_r_superellipse / prefer_clip_r_superellipse_clipper
// =============================================================================

class ClipRSuperellipseExamples extends StatelessWidget {
  const ClipRSuperellipseExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: ClipRRect without clipper (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network('https://example.com/image.png'),
        ),

        // BAD: ClipRRect with only child (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          child: Image.network('https://example.com/image.png'),
        ),

        // BAD: ClipRRect with clipBehavior (prefer_clip_r_superellipse)
        // expect_lint: prefer_clip_r_superellipse
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: Image.network('https://example.com/image.png'),
        ),

        // GOOD: ClipRSuperellipse (already using preferred widget)
        ClipRSuperellipse(
          borderRadius: BorderRadius.circular(10),
          child: Image.network('https://example.com/image.png'),
        ),

        // GOOD: ClipRRect with custom clipper (handled by _clipper rule)
        // expect_lint: prefer_clip_r_superellipse_clipper
        ClipRRect(
          clipper: _MyCustomClipper(),
          child: Image.network('https://example.com/image.png'),
        ),
      ],
    );
  }
}

class _MyCustomClipper extends CustomClipper<RRect> {
  @override
  RRect getClip(Size size) => RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(10),
      );

  @override
  bool shouldReclip(covariant CustomClipper<RRect> oldClipper) => false;
}
