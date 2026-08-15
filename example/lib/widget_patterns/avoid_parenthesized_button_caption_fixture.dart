// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument
// ignore_for_file: undefined_named_parameter
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this
// ignore_for_file: expected_class_member
// ignore_for_file: body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type
// ignore_for_file: use_of_void_result
// ignore_for_file: missing_function_body
// ignore_for_file: extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments
// ignore_for_file: unused_label
// ignore_for_file: unused_element_parameter
// ignore_for_file: non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token
// ignore_for_file: duplicate_definition
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: extends_non_class
// ignore_for_file: no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable
// ignore_for_file: named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration
// ignore_for_file: await_in_wrong_context
// ignore_for_file: non_constant_default_value, not_a_type
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// Test fixture for: avoid_parenthesized_button_caption
// Source: lib\src\rules\widget\widget_patterns_avoid_prefer_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// File-type marker: applicableFileTypes gates on FileType.widget, which the
// scanner infers from the presence of a widget subclass in the file.
class _MarkerWidget extends StatelessWidget {
  const _MarkerWidget();

  @override
  Widget build(BuildContext context) => const _MarkerWidget();
}

// BAD: Parenthesized text in CommonButton text parameter
// expect_lint: avoid_parenthesized_button_caption
void _bad1() {
  CommonButton(
    text: 'Delete All Contacts (User & Imported)',
    onPressed: () {},
  );
}

// BAD: Parenthesized text in CommonButtonWait text parameter
// expect_lint: avoid_parenthesized_button_caption
void _bad2() {
  CommonButtonWait(
    text: 'Import Contacts (Quick Pass)',
    onPressed: () {},
  );
}

// BAD: Entire string is parenthesized — still belongs in subtitleText
// expect_lint: avoid_parenthesized_button_caption
void _bad3() {
  CommonButton(
    text: '(Coming Soon)',
    onPressed: () {},
  );
}

// BAD: Adjacent string literal concatenation containing parens
// expect_lint: avoid_parenthesized_button_caption
void _bad4() {
  CommonButton(
    text: 'Clean Database '
        '(Full Rebuild)',
    onPressed: () {},
  );
}

// BAD: `+`-operator string concatenation containing parens
// expect_lint: avoid_parenthesized_button_caption
void _bad5() {
  CommonButton(
    text: 'Clean Database ' + '(Full Rebuild)',
    onPressed: () {},
  );
}

// GOOD: No parentheses in text
void _good1() {
  CommonButton(
    text: 'Delete All Contacts',
    subtitleText: 'User & Imported',
    onPressed: () {},
  );
}

// GOOD: subtitleText may contain parentheses
void _good2() {
  CommonButton(
    text: 'Clean & Repair Database',
    subtitleText: '(Cleaning…)',
    onPressed: () {},
  );
}

// GOOD: No text parameter at all
void _good3() {
  CommonButton(
    onPressed: () {},
  );
}

// GOOD: l10n reference — not a string literal, accepted false-negative gap
dynamic l10n;
void _good4() {
  CommonButton(
    text: l10n.someKey,
    onPressed: () {},
  );
}
