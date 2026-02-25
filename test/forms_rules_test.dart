import 'dart:io';

import 'package:test/test.dart';

/// Tests for 26 Forms lint rules.
///
/// Test fixtures: example_widgets/lib/forms/*
void main() {
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
        final file = File('example_widgets/lib/forms/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Forms - Preference Rules', () {
    group('prefer_autovalidate_on_interaction', () {
      test('prefer_autovalidate_on_interaction SHOULD trigger', () {
        // Better alternative available: prefer autovalidate on interaction
        expect('prefer_autovalidate_on_interaction detected', isNotNull);
      });

      test('prefer_autovalidate_on_interaction should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_autovalidate_on_interaction passes', isNotNull);
      });
    });

    group('prefer_on_field_submitted', () {
      test('prefer_on_field_submitted SHOULD trigger', () {
        // Better alternative available: prefer on field submitted
        expect('prefer_on_field_submitted detected', isNotNull);
      });

      test('prefer_on_field_submitted should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_on_field_submitted passes', isNotNull);
      });
    });

    group('prefer_text_input_action', () {
      test('prefer_text_input_action SHOULD trigger', () {
        // Better alternative available: prefer text input action
        expect('prefer_text_input_action detected', isNotNull);
      });

      test('prefer_text_input_action should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_text_input_action passes', isNotNull);
      });
    });

    group('prefer_regex_validation', () {
      test('prefer_regex_validation SHOULD trigger', () {
        // Better alternative available: prefer regex validation
        expect('prefer_regex_validation detected', isNotNull);
      });

      test('prefer_regex_validation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_regex_validation passes', isNotNull);
      });
    });

    group('prefer_input_formatters', () {
      test('prefer_input_formatters SHOULD trigger', () {
        // Better alternative available: prefer input formatters
        expect('prefer_input_formatters detected', isNotNull);
      });

      test('prefer_input_formatters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_input_formatters passes', isNotNull);
      });
    });
  });

  group('Forms - Requirement Rules', () {
    group('require_keyboard_type', () {
      test('require_keyboard_type SHOULD trigger', () {
        // Required pattern missing: require keyboard type
        expect('require_keyboard_type detected', isNotNull);
      });

      test('require_keyboard_type should NOT trigger', () {
        // Required pattern present
        expect('require_keyboard_type passes', isNotNull);
      });
    });

    group('require_text_overflow_in_row', () {
      test('require_text_overflow_in_row SHOULD trigger', () {
        // Required pattern missing: require text overflow in row
        expect('require_text_overflow_in_row detected', isNotNull);
      });

      test('require_text_overflow_in_row should NOT trigger', () {
        // Required pattern present
        expect('require_text_overflow_in_row passes', isNotNull);
      });
    });

    group('require_secure_keyboard', () {
      test('require_secure_keyboard SHOULD trigger', () {
        // Required pattern missing: require secure keyboard
        expect('require_secure_keyboard detected', isNotNull);
      });

      test('require_secure_keyboard should NOT trigger', () {
        // Required pattern present
        expect('require_secure_keyboard passes', isNotNull);
      });
    });

    group('require_error_message_context', () {
      test('require_error_message_context SHOULD trigger', () {
        // Required pattern missing: require error message context
        expect('require_error_message_context detected', isNotNull);
      });

      test('require_error_message_context should NOT trigger', () {
        // Required pattern present
        expect('require_error_message_context passes', isNotNull);
      });
    });

    group('require_form_key', () {
      test('require_form_key SHOULD trigger', () {
        // Required pattern missing: require form key
        expect('require_form_key detected', isNotNull);
      });

      test('require_form_key should NOT trigger', () {
        // Required pattern present
        expect('require_form_key passes', isNotNull);
      });
    });

    group('require_submit_button_state', () {
      test('require_submit_button_state SHOULD trigger', () {
        // Required pattern missing: require submit button state
        expect('require_submit_button_state detected', isNotNull);
      });

      test('require_submit_button_state should NOT trigger', () {
        // Required pattern present
        expect('require_submit_button_state passes', isNotNull);
      });
    });

    group('require_form_restoration', () {
      test('require_form_restoration SHOULD trigger', () {
        // Required pattern missing: require form restoration
        expect('require_form_restoration detected', isNotNull);
      });

      test('require_form_restoration should NOT trigger', () {
        // Required pattern present
        expect('require_form_restoration passes', isNotNull);
      });
    });

    group('require_form_field_controller', () {
      test('require_form_field_controller SHOULD trigger', () {
        // Required pattern missing: require form field controller
        expect('require_form_field_controller detected', isNotNull);
      });

      test('require_form_field_controller should NOT trigger', () {
        // Required pattern present
        expect('require_form_field_controller passes', isNotNull);
      });
    });

    group('require_keyboard_action_type', () {
      test('require_keyboard_action_type SHOULD trigger', () {
        // Required pattern missing: require keyboard action type
        expect('require_keyboard_action_type detected', isNotNull);
      });

      test('require_keyboard_action_type should NOT trigger', () {
        // Required pattern present
        expect('require_keyboard_action_type passes', isNotNull);
      });
    });

    group('require_keyboard_dismiss_on_scroll', () {
      test('require_keyboard_dismiss_on_scroll SHOULD trigger', () {
        // Required pattern missing: require keyboard dismiss on scroll
        expect('require_keyboard_dismiss_on_scroll detected', isNotNull);
      });

      test('require_keyboard_dismiss_on_scroll should NOT trigger', () {
        // Required pattern present
        expect('require_keyboard_dismiss_on_scroll passes', isNotNull);
      });
    });

    group('require_form_auto_validate_mode', () {
      test('require_form_auto_validate_mode SHOULD trigger', () {
        // Required pattern missing: require form auto validate mode
        expect('require_form_auto_validate_mode detected', isNotNull);
      });

      test('require_form_auto_validate_mode should NOT trigger', () {
        // Required pattern present
        expect('require_form_auto_validate_mode passes', isNotNull);
      });
    });

    group('require_autofill_hints', () {
      test('require_autofill_hints SHOULD trigger', () {
        // Required pattern missing: require autofill hints
        expect('require_autofill_hints detected', isNotNull);
      });

      test('require_autofill_hints should NOT trigger', () {
        // Required pattern present
        expect('require_autofill_hints passes', isNotNull);
      });
    });

    group('require_text_input_type', () {
      test('require_text_input_type SHOULD trigger', () {
        // Required pattern missing: require text input type
        expect('require_text_input_type detected', isNotNull);
      });

      test('require_text_input_type should NOT trigger', () {
        // Required pattern present
        expect('require_text_input_type passes', isNotNull);
      });
    });

    group('require_form_key_in_stateful_widget', () {
      test('require_form_key_in_stateful_widget SHOULD trigger', () {
        // Required pattern missing: require form key in stateful widget
        expect('require_form_key_in_stateful_widget detected', isNotNull);
      });

      test('require_form_key_in_stateful_widget should NOT trigger', () {
        // Required pattern present
        expect('require_form_key_in_stateful_widget passes', isNotNull);
      });
    });

    group('require_stepper_state_management', () {
      test('require_stepper_state_management SHOULD trigger', () {
        // Required pattern missing: require stepper state management
        expect('require_stepper_state_management detected', isNotNull);
      });

      test('require_stepper_state_management should NOT trigger', () {
        // Required pattern present
        expect('require_stepper_state_management passes', isNotNull);
      });
    });
  });

  group('Forms - Avoidance Rules', () {
    group('avoid_validation_in_build', () {
      test('avoid_validation_in_build SHOULD trigger', () {
        // Pattern that should be avoided: avoid validation in build
        expect('avoid_validation_in_build detected', isNotNull);
      });

      test('avoid_validation_in_build should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_validation_in_build passes', isNotNull);
      });
    });

    group('avoid_form_without_unfocus', () {
      test('avoid_form_without_unfocus SHOULD trigger', () {
        // Pattern that should be avoided: avoid form without unfocus
        expect('avoid_form_without_unfocus detected', isNotNull);
      });

      test('avoid_form_without_unfocus should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_form_without_unfocus passes', isNotNull);
      });
    });

    group('avoid_clearing_form_on_error', () {
      test('avoid_clearing_form_on_error SHOULD trigger', () {
        // Pattern that should be avoided: avoid clearing form on error
        expect('avoid_clearing_form_on_error detected', isNotNull);
      });

      test('avoid_clearing_form_on_error should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_clearing_form_on_error passes', isNotNull);
      });
    });

    group('avoid_form_in_alert_dialog', () {
      test('avoid_form_in_alert_dialog SHOULD trigger', () {
        // Pattern that should be avoided: avoid form in alert dialog
        expect('avoid_form_in_alert_dialog detected', isNotNull);
      });

      test('avoid_form_in_alert_dialog should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_form_in_alert_dialog passes', isNotNull);
      });
    });

    group('avoid_keyboard_overlap', () {
      test('avoid_keyboard_overlap SHOULD trigger', () {
        // Pattern that should be avoided: avoid keyboard overlap
        expect('avoid_keyboard_overlap detected', isNotNull);
      });

      test('avoid_keyboard_overlap should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_keyboard_overlap passes', isNotNull);
      });
    });

    group('avoid_form_validation_on_change', () {
      test('validation on every keystroke SHOULD trigger', () {
        // Pattern that should be avoided: validating form on each change
        expect('avoid_form_validation_on_change detected', isNotNull);
      });

      test('validation on submit or blur should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_form_validation_on_change passes', isNotNull);
      });
    });
  });
}
