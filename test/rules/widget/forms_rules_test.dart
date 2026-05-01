import 'dart:io';

import 'package:saropa_lints/src/rules/widget/forms_rules.dart';
import 'package:test/test.dart';

/// Tests for 26 Forms lint rules.
///
/// Test fixtures: example/lib/forms/*
// TextFormField, validation, and form controller usage in example widgets.
void main() {
  group('Forms Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'PreferAutovalidateOnInteractionRule',
      'prefer_autovalidate_on_interaction',
      () => PreferAutovalidateOnInteractionRule(),
    );
    testRule(
      'RequireKeyboardTypeRule',
      'require_keyboard_type',
      () => RequireKeyboardTypeRule(),
    );
    testRule(
      'RequireTextOverflowInRowRule',
      'require_text_overflow_in_row',
      () => RequireTextOverflowInRowRule(),
    );
    testRule(
      'RequireSecureKeyboardRule',
      'require_secure_keyboard',
      () => RequireSecureKeyboardRule(),
    );
    testRule(
      'RequireErrorMessageContextRule',
      'require_error_message_context',
      () => RequireErrorMessageContextRule(),
    );
    testRule(
      'RequireFormKeyRule',
      'require_form_key',
      () => RequireFormKeyRule(),
    );
    testRule(
      'AvoidValidationInBuildRule',
      'avoid_validation_in_build',
      () => AvoidValidationInBuildRule(),
    );
    testRule(
      'RequireSubmitButtonStateRule',
      'require_submit_button_state',
      () => RequireSubmitButtonStateRule(),
    );
    testRule(
      'AvoidFormWithoutUnfocusRule',
      'avoid_form_without_unfocus',
      () => AvoidFormWithoutUnfocusRule(),
    );
    testRule(
      'RequireFormRestorationRule',
      'require_form_restoration',
      () => RequireFormRestorationRule(),
    );
    testRule(
      'AvoidClearingFormOnErrorRule',
      'avoid_clearing_form_on_error',
      () => AvoidClearingFormOnErrorRule(),
    );
    testRule(
      'RequireFormFieldControllerRule',
      'require_form_field_controller',
      () => RequireFormFieldControllerRule(),
    );
    testRule(
      'AvoidFormInAlertDialogRule',
      'avoid_form_in_alert_dialog',
      () => AvoidFormInAlertDialogRule(),
    );
    testRule(
      'RequireKeyboardActionTypeRule',
      'require_keyboard_action_type',
      () => RequireKeyboardActionTypeRule(),
    );
    testRule(
      'RequireKeyboardDismissOnScrollRule',
      'require_keyboard_dismiss_on_scroll',
      () => RequireKeyboardDismissOnScrollRule(),
    );
    testRule(
      'AvoidKeyboardOverlapRule',
      'avoid_keyboard_overlap',
      () => AvoidKeyboardOverlapRule(),
    );
    testRule(
      'RequireFormAutoValidateModeRule',
      'require_form_auto_validate_mode',
      () => RequireFormAutoValidateModeRule(),
    );
    testRule(
      'RequireAutofillHintsRule',
      'require_autofill_hints',
      () => RequireAutofillHintsRule(),
    );
    testRule(
      'PreferOnFieldSubmittedRule',
      'prefer_on_field_submitted',
      () => PreferOnFieldSubmittedRule(),
    );
    testRule(
      'RequireTextInputTypeRule',
      'require_text_input_type',
      () => RequireTextInputTypeRule(),
    );
    testRule(
      'PreferTextInputActionRule',
      'prefer_text_input_action',
      () => PreferTextInputActionRule(),
    );
    testRule(
      'RequireFormKeyInStatefulWidgetRule',
      'require_form_key_in_stateful_widget',
      () => RequireFormKeyInStatefulWidgetRule(),
    );
    testRule(
      'PreferRegexValidationRule',
      'prefer_regex_validation',
      () => PreferRegexValidationRule(),
    );
    testRule(
      'PreferInputFormattersRule',
      'prefer_input_formatters',
      () => PreferInputFormattersRule(),
    );
    testRule(
      'RequireStepperStateManagementRule',
      'require_stepper_state_management',
      () => RequireStepperStateManagementRule(),
    );
    testRule(
      'AvoidFormValidationOnChangeRule',
      'avoid_form_validation_on_change',
      () => AvoidFormValidationOnChangeRule(),
    );
    testRule(
      'PreferFormBlocForComplexRule',
      'prefer_form_bloc_for_complex',
      () => PreferFormBlocForComplexRule(),
    );
  });
  group('Forms Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_autovalidate_on_interaction',
      'require_keyboard_type',
      'require_text_overflow_in_row',
      'require_secure_keyboard',
      'require_error_message_context',
      'require_form_key',
      'avoid_validation_in_build',
      'require_submit_button_state',
      'avoid_form_without_unfocus',
      'require_form_restoration',
      'avoid_clearing_form_on_error',
      'require_form_field_controller',
      'avoid_form_in_alert_dialog',
      'require_keyboard_action_type',
      'require_keyboard_dismiss_on_scroll',
      'avoid_keyboard_overlap',
      'require_form_auto_validate_mode',
      'require_autofill_hints',
      'prefer_on_field_submitted',
      'prefer_form_bloc_for_complex',
      'require_text_input_type',
      'prefer_text_input_action',
      'require_form_key_in_stateful_widget',
      'prefer_regex_validation',
      'prefer_input_formatters',
      'require_stepper_state_management',
      'avoid_form_validation_on_change',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/forms/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  // Stub-only behavior tests were removed from this file. Keep rule metadata
  // and fixture verification while migrating to analyzer-backed behavior tests.
}
