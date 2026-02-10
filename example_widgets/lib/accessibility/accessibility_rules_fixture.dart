// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
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
// Test fixture for accessibility rules (Plan Group C)

import 'package:saropa_lints_example/flutter_mocks.dart';

// =========================================================================
// require_avatar_alt_text (C1)
// =========================================================================

class BadAvatarWidget extends StatelessWidget {
  const BadAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: Missing semanticLabel, should trigger lint
    // expect_lint: require_avatar_alt_text
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
    );
  }
}

class GoodAvatarWidget extends StatelessWidget {
  const GoodAvatarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Has semanticLabel
    return CircleAvatar(
      backgroundImage: NetworkImage('https://example.com/avatar.jpg'),
      semanticLabel: 'User profile picture',
    );
  }
}

// =========================================================================
// require_badge_semantics (C2)
// =========================================================================

class BadBadgeWidget extends StatelessWidget {
  const BadBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_badge_semantics
    return Badge(
      label: Text('5'),
      child: Icon(Icons.notifications),
    );
  }
}

class GoodBadgeWidget extends StatelessWidget {
  const GoodBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Wrapped in Semantics
    return Semantics(
      label: '5 notifications',
      child: Badge(
        label: Text('5'),
        child: Icon(Icons.notifications),
      ),
    );
  }
}

// =========================================================================
// require_badge_count_limit (C3)
// =========================================================================

class BadBadgeCountWidget extends StatelessWidget {
  const BadBadgeCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '150 notifications',
      child: Badge(
        // expect_lint: require_badge_count_limit
        label: Text('150'),
        child: Icon(Icons.mail),
      ),
    );
  }
}

class GoodBadgeCountWidget extends StatelessWidget {
  const GoodBadgeCountWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // GOOD: Using 99+ pattern
    return Semantics(
      label: '99+ notifications',
      child: Badge(
        label: Text('99+'),
        child: Icon(Icons.mail),
      ),
    );
  }
}

// =========================================================================
// Accessibility Rules
// =========================================================================

// BAD: Small touch target
class SmallTouchWidget extends StatelessWidget {
  const SmallTouchWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: prefer_large_touch_targets
    return GestureDetector(
      child: Container(width: 30, height: 30), // Too small!
      onTap: () {},
    );
  }
}

// BAD: Short toast duration
void testShortDuration(BuildContext context) {
  // expect_lint: avoid_time_limits
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Quick message'),
      duration: Duration(seconds: 2), // Too short!
    ),
  );
}

// BAD: Drag without button alternative
class DragWithoutButtonWidget extends StatelessWidget {
  const DragWithoutButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_drag_alternatives
    return ReorderableListView(
      children: [Container(key: Key('1'))],
      onReorder: (_, __) {},
    );
  }
}

// Mock classes for accessibility rules
class ScaffoldMessenger {
  static ScaffoldMessenger of(BuildContext context) => ScaffoldMessenger();
  void showSnackBar(SnackBar snackBar) {}
}

class SnackBar {
  SnackBar({required this.content, this.duration});
  final Widget content;
  final Duration? duration;
}

class ReorderableListView extends StatelessWidget {
  const ReorderableListView(
      {super.key, required this.children, this.onReorder});
  final List<Widget> children;
  final void Function(int, int)? onReorder;

  @override
  Widget build(BuildContext context) => Container();
}

class Key {
  const Key(String value);
}

// =========================================================================
// avoid_flashing_content
// =========================================================================

// Mock AnimationController for testing
class AnimationController {
  AnimationController({this.duration, this.vsync});
  final Duration? duration;
  final dynamic vsync;

  void forward() {}
  void reverse() {}
  void animateTo(double target) {}
  AnimationController repeat({bool reverse = false}) => this;
}

// BAD: Fast repeat animation - causes flashing
void badFastRepeatAnimation() {
  AnimationController(
    // expect_lint: avoid_flashing_content
    duration: Duration(milliseconds: 100), // 10 flashes/second!
  )..repeat(reverse: true);
}

// BAD: Fast repeat without reverse - still flashes
void badFastRepeatNoReverse() {
  AnimationController(
    // expect_lint: avoid_flashing_content
    duration: Duration(milliseconds: 200),
  )..repeat();
}

// GOOD: Fast forward-only animation - no flashing (single direction)
void goodFastForwardOnly() {
  // OK: Single-direction animations don't flash
  AnimationController(
    duration: Duration(milliseconds: 100),
  )..forward();
}

// GOOD: Fast reverse-only animation - no flashing (single direction)
void goodFastReverseOnly() {
  // OK: Single-direction animations don't flash
  AnimationController(
    duration: Duration(milliseconds: 100),
  )..reverse();
}

// GOOD: Slow repeat animation - under 3Hz threshold
void goodSlowRepeat() {
  // OK: 500ms duration = 2 flashes/second
  AnimationController(
    duration: Duration(milliseconds: 500),
  )..repeat(reverse: true);
}

// GOOD: No cascade - can't detect repeat usage
void goodNoCascade() {
  // OK: Without cascade, we can't know if it repeats
  final controller = AnimationController(
    duration: Duration(milliseconds: 100),
  );
  controller.forward();
}

// GOOD: Fast animateTo - single direction
void goodFastAnimateTo() {
  // OK: animateTo is single-direction
  AnimationController(
    duration: Duration(milliseconds: 100),
  )..animateTo(1.0);
}
