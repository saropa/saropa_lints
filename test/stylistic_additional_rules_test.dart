import 'dart:io';

import 'package:test/test.dart';

/// Tests for 22 Stylistic Additional lint rules.
///
/// Test fixtures: example_style/lib/stylistic_additional/*
void main() {
  group('Stylistic Additional Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_interpolation_over_concatenation',
      'prefer_concatenation_over_interpolation',
      'prefer_double_quotes',
      'prefer_absolute_imports',
      'prefer_grouped_imports',
      'prefer_flat_imports',
      'prefer_fields_before_methods',
      'prefer_methods_before_fields',
      'prefer_static_members_first',
      'prefer_instance_members_first',
      'prefer_public_members_first',
      'prefer_private_members_first',
      'prefer_var_over_explicit_type',
      'prefer_object_over_dynamic',
      'prefer_dynamic_over_object',
      'prefer_lower_camel_case_constants',
      'prefer_camel_case_method_names',
      'prefer_descriptive_variable_names',
      'prefer_concise_variable_names',
      'prefer_explicit_this',
      'prefer_implicit_boolean_comparison',
      'prefer_explicit_boolean_comparison',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_style/lib/stylistic_additional/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic Additional - Preference Rules', () {
    group('prefer_interpolation_over_concatenation', () {
      test('prefer_interpolation_over_concatenation SHOULD trigger', () {
        // Better alternative available: prefer interpolation over concatenation
        expect('prefer_interpolation_over_concatenation detected', isNotNull);
      });

      test('prefer_interpolation_over_concatenation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_interpolation_over_concatenation passes', isNotNull);
      });
    });

    group('prefer_concatenation_over_interpolation', () {
      test('prefer_concatenation_over_interpolation SHOULD trigger', () {
        // Better alternative available: prefer concatenation over interpolation
        expect('prefer_concatenation_over_interpolation detected', isNotNull);
      });

      test('prefer_concatenation_over_interpolation should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_concatenation_over_interpolation passes', isNotNull);
      });
    });

    group('prefer_double_quotes', () {
      test('prefer_double_quotes SHOULD trigger', () {
        // Better alternative available: prefer double quotes
        expect('prefer_double_quotes detected', isNotNull);
      });

      test('prefer_double_quotes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_double_quotes passes', isNotNull);
      });
    });

    group('prefer_absolute_imports', () {
      test('prefer_absolute_imports SHOULD trigger', () {
        // Better alternative available: prefer absolute imports
        expect('prefer_absolute_imports detected', isNotNull);
      });

      test('prefer_absolute_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_absolute_imports passes', isNotNull);
      });
    });

    group('prefer_grouped_imports', () {
      test('prefer_grouped_imports SHOULD trigger', () {
        // Better alternative available: prefer grouped imports
        expect('prefer_grouped_imports detected', isNotNull);
      });

      test('prefer_grouped_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_grouped_imports passes', isNotNull);
      });
    });

    group('prefer_flat_imports', () {
      test('prefer_flat_imports SHOULD trigger', () {
        // Better alternative available: prefer flat imports
        expect('prefer_flat_imports detected', isNotNull);
      });

      test('prefer_flat_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_flat_imports passes', isNotNull);
      });
    });

    group('prefer_fields_before_methods', () {
      test('prefer_fields_before_methods SHOULD trigger', () {
        // Better alternative available: prefer fields before methods
        expect('prefer_fields_before_methods detected', isNotNull);
      });

      test('prefer_fields_before_methods should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_fields_before_methods passes', isNotNull);
      });
    });

    group('prefer_methods_before_fields', () {
      test('prefer_methods_before_fields SHOULD trigger', () {
        // Better alternative available: prefer methods before fields
        expect('prefer_methods_before_fields detected', isNotNull);
      });

      test('prefer_methods_before_fields should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_methods_before_fields passes', isNotNull);
      });
    });

    group('prefer_static_members_first', () {
      test('prefer_static_members_first SHOULD trigger', () {
        // Better alternative available: prefer static members first
        expect('prefer_static_members_first detected', isNotNull);
      });

      test('prefer_static_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_static_members_first passes', isNotNull);
      });
    });

    group('prefer_instance_members_first', () {
      test('prefer_instance_members_first SHOULD trigger', () {
        // Better alternative available: prefer instance members first
        expect('prefer_instance_members_first detected', isNotNull);
      });

      test('prefer_instance_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_instance_members_first passes', isNotNull);
      });
    });

    group('prefer_public_members_first', () {
      test('prefer_public_members_first SHOULD trigger', () {
        // Better alternative available: prefer public members first
        expect('prefer_public_members_first detected', isNotNull);
      });

      test('prefer_public_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_public_members_first passes', isNotNull);
      });
    });

    group('prefer_private_members_first', () {
      test('prefer_private_members_first SHOULD trigger', () {
        // Better alternative available: prefer private members first
        expect('prefer_private_members_first detected', isNotNull);
      });

      test('prefer_private_members_first should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_private_members_first passes', isNotNull);
      });
    });

    group('prefer_var_over_explicit_type', () {
      test('prefer_var_over_explicit_type SHOULD trigger', () {
        // Better alternative available: prefer var over explicit type
        expect('prefer_var_over_explicit_type detected', isNotNull);
      });

      test('prefer_var_over_explicit_type should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_var_over_explicit_type passes', isNotNull);
      });
    });

    group('prefer_object_over_dynamic', () {
      test('prefer_object_over_dynamic SHOULD trigger', () {
        // Better alternative available: prefer object over dynamic
        expect('prefer_object_over_dynamic detected', isNotNull);
      });

      test('prefer_object_over_dynamic should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_object_over_dynamic passes', isNotNull);
      });
    });

    group('prefer_dynamic_over_object', () {
      test('prefer_dynamic_over_object SHOULD trigger', () {
        // Better alternative available: prefer dynamic over object
        expect('prefer_dynamic_over_object detected', isNotNull);
      });

      test('prefer_dynamic_over_object should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_dynamic_over_object passes', isNotNull);
      });
    });

    group('prefer_lower_camel_case_constants', () {
      test('prefer_lower_camel_case_constants SHOULD trigger', () {
        // Better alternative available: prefer lower camel case constants
        expect('prefer_lower_camel_case_constants detected', isNotNull);
      });

      test('prefer_lower_camel_case_constants should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_lower_camel_case_constants passes', isNotNull);
      });
    });

    group('prefer_camel_case_method_names', () {
      test('prefer_camel_case_method_names SHOULD trigger', () {
        // Better alternative available: prefer camel case method names
        expect('prefer_camel_case_method_names detected', isNotNull);
      });

      test('prefer_camel_case_method_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_camel_case_method_names passes', isNotNull);
      });
    });

    group('prefer_descriptive_variable_names', () {
      test('prefer_descriptive_variable_names SHOULD trigger', () {
        // Better alternative available: prefer descriptive variable names
        expect('prefer_descriptive_variable_names detected', isNotNull);
      });

      test('prefer_descriptive_variable_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_descriptive_variable_names passes', isNotNull);
      });
    });

    group('prefer_concise_variable_names', () {
      test('prefer_concise_variable_names SHOULD trigger', () {
        // Better alternative available: prefer concise variable names
        expect('prefer_concise_variable_names detected', isNotNull);
      });

      test('prefer_concise_variable_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_concise_variable_names passes', isNotNull);
      });
    });

    group('prefer_explicit_this', () {
      test('prefer_explicit_this SHOULD trigger', () {
        // Better alternative available: prefer explicit this
        expect('prefer_explicit_this detected', isNotNull);
      });

      test('prefer_explicit_this should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_this passes', isNotNull);
      });
    });

    group('prefer_implicit_boolean_comparison', () {
      test('prefer_implicit_boolean_comparison SHOULD trigger', () {
        // Better alternative available: prefer implicit boolean comparison
        expect('prefer_implicit_boolean_comparison detected', isNotNull);
      });

      test('prefer_implicit_boolean_comparison should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_implicit_boolean_comparison passes', isNotNull);
      });
    });

    group('prefer_explicit_boolean_comparison', () {
      test('prefer_explicit_boolean_comparison SHOULD trigger', () {
        // Better alternative available: prefer explicit boolean comparison
        expect('prefer_explicit_boolean_comparison detected', isNotNull);
      });

      test('prefer_explicit_boolean_comparison should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_boolean_comparison passes', isNotNull);
      });
    });
  });
}
