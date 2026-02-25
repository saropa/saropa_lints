// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
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
// ignore_for_file: non_type_in_catch_clause
// ignore_for_file: could_not_infer
// ignore_for_file: uri_does_not_exist
// ignore_for_file: const_method
// ignore_for_file: redirect_to_non_class
// ignore_for_file: unused_catch_clause
// ignore_for_file: type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member
// ignore_for_file: extraneous_modifier
// ignore_for_file: experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override
// ignore_for_file: not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable
// ignore_for_file: assignment_to_final
// ignore_for_file: equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element
// ignore_for_file: missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type
// ignore_for_file: instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter
// ignore_for_file: non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type
// ignore_for_file: type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for: avoid_entitlement_without_server
// Source: lib\src\rules\iap_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

// Local IAP mocks (not in flutter_mocks.dart)
class PurchaseStatus {
  static const purchased = PurchaseStatus._('purchased');
  static const restored = PurchaseStatus._('restored');
  static const pending = PurchaseStatus._('pending');
  static const error = PurchaseStatus._('error');
  final String _value;
  const PurchaseStatus._(this._value);
}

class PurchaseDetails {
  PurchaseStatus status = PurchaseStatus.purchased;
  VerificationData verificationData = VerificationData();
}

class VerificationData {
  String serverVerificationData = '';
}

// ============================================================================
// BAD: Should trigger avoid_entitlement_without_server
// ============================================================================

// expect_lint: avoid_entitlement_without_server
void _bad1(PurchaseDetails purchaseDetails) {
  // Client-only verification: bypassable on rooted devices!
  if (purchaseDetails.status == PurchaseStatus.purchased) {
    _isPremium = true;
  }
}

// expect_lint: avoid_entitlement_without_server
void _bad2(PurchaseDetails purchaseDetails) {
  // Restored purchases also need server verification
  if (purchaseDetails.status == PurchaseStatus.restored) {
    _isPremium = true;
  }
}

// ============================================================================
// GOOD: Should NOT trigger avoid_entitlement_without_server
// ============================================================================

// OK: Verifies with server before unlocking
Future<void> _good1(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.status == PurchaseStatus.purchased) {
    final verified = await api.verifyReceipt(
      purchaseDetails.verificationData.serverVerificationData,
    );
    if (verified) {
      _isPremium = true;
    }
  }
}

// OK: Uses validatePurchase pattern
Future<void> _good2(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.status == PurchaseStatus.purchased) {
    final valid = await api.validatePurchase(purchaseDetails);
    if (valid) {
      _isPremium = true;
    }
  }
}

// OK: Uses RevenueCat (handles server verification automatically)
Future<void> _good3(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.status == PurchaseStatus.purchased) {
    // RevenueCat handles server-side validation
    final entitlements = await RevenueCat.getEntitlements();
    _isPremium = entitlements.isActive;
  }
}

// ============================================================================
// FALSE POSITIVES: Should NOT trigger avoid_entitlement_without_server
// ============================================================================

// OK: Checking pending status (not a purchase confirmation)
void _falsePositive1(PurchaseDetails purchaseDetails) {
  if (purchaseDetails.status == PurchaseStatus.pending) {
    showPendingUI();
  }
}

// OK: Checking error status
void _falsePositive2(PurchaseDetails purchaseDetails) {
  if (purchaseDetails.status == PurchaseStatus.error) {
    showErrorUI();
  }
}

// Helpers
bool _isPremium = false;

class _Api {
  Future<bool> verifyReceipt(String data) async => true;
  Future<bool> validatePurchase(PurchaseDetails details) async => true;
}

final api = _Api();

class RevenueCat {
  static Future<_Entitlements> getEntitlements() async => _Entitlements();
}

class _Entitlements {
  bool isActive = true;
}

void showPendingUI() {}
void showErrorUI() {}
