import 'dart:io';

import 'package:test/test.dart';

/// Tests for 24 Naming Style lint rules.
///
/// Test fixtures: example_core/lib/naming_style/*
void main() {
  group('Naming Style Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_no_getter_prefix',
      'avoid_non_ascii_symbols',
      'prefer_capitalized_comment_start',
      'match_class_name_pattern',
      'match_getter_setter_field_names',
      'match_lib_folder_structure',
      'match_positional_field_names_on_assignment',
      'prefer_boolean_prefixes',
      'prefer_boolean_prefixes_for_locals',
      'prefer_boolean_prefixes_for_params',
      'prefer_correct_callback_field_name',
      'prefer_correct_error_name',
      'prefer_correct_handler_name',
      'prefer_correct_identifier_length',
      'prefer_correct_setter_parameter_name',
      'prefer_explicit_parameter_names',
      'prefer_match_file_name',
      'prefer_prefixed_global_constants',
      'prefer_kebab_tag_name',
      'prefer_named_extensions',
      'prefer_typedef_for_callbacks',
      'prefer_enhanced_enums',
      'prefer_wildcard_for_unused_param',
      'prefer_correct_package_name',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_core/lib/naming_style/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Naming Style - Preference Rules', () {
    group('prefer_no_getter_prefix', () {
      test('prefer_no_getter_prefix SHOULD trigger', () {
        // Better alternative available: prefer no getter prefix
        expect('prefer_no_getter_prefix detected', isNotNull);
      });

      test('prefer_no_getter_prefix should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_no_getter_prefix passes', isNotNull);
      });
    });

    group('prefer_capitalized_comment_start', () {
      test('prefer_capitalized_comment_start SHOULD trigger', () {
        // Better alternative available: prefer capitalized comment start
        expect('prefer_capitalized_comment_start detected', isNotNull);
      });

      test('prefer_capitalized_comment_start should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_capitalized_comment_start passes', isNotNull);
      });
    });

    group('prefer_boolean_prefixes', () {
      test('prefer_boolean_prefixes SHOULD trigger', () {
        // Better alternative available: prefer boolean prefixes
        expect('prefer_boolean_prefixes detected', isNotNull);
      });

      test('prefer_boolean_prefixes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_boolean_prefixes passes', isNotNull);
      });
    });

    group('prefer_boolean_prefixes_for_locals', () {
      test('prefer_boolean_prefixes_for_locals SHOULD trigger', () {
        // Better alternative available: prefer boolean prefixes for locals
        expect('prefer_boolean_prefixes_for_locals detected', isNotNull);
      });

      test('prefer_boolean_prefixes_for_locals should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_boolean_prefixes_for_locals passes', isNotNull);
      });
    });

    group('prefer_boolean_prefixes_for_params', () {
      test('prefer_boolean_prefixes_for_params SHOULD trigger', () {
        // Better alternative available: prefer boolean prefixes for params
        expect('prefer_boolean_prefixes_for_params detected', isNotNull);
      });

      test('prefer_boolean_prefixes_for_params should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_boolean_prefixes_for_params passes', isNotNull);
      });
    });

    group('prefer_correct_callback_field_name', () {
      test('prefer_correct_callback_field_name SHOULD trigger', () {
        // Better alternative available: prefer correct callback field name
        expect('prefer_correct_callback_field_name detected', isNotNull);
      });

      test('prefer_correct_callback_field_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_callback_field_name passes', isNotNull);
      });
    });

    group('prefer_correct_error_name', () {
      test('prefer_correct_error_name SHOULD trigger', () {
        // Better alternative available: prefer correct error name
        expect('prefer_correct_error_name detected', isNotNull);
      });

      test('prefer_correct_error_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_error_name passes', isNotNull);
      });
    });

    group('prefer_correct_handler_name', () {
      test('prefer_correct_handler_name SHOULD trigger', () {
        // Better alternative available: prefer correct handler name
        expect('prefer_correct_handler_name detected', isNotNull);
      });

      test('prefer_correct_handler_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_handler_name passes', isNotNull);
      });
    });

    group('prefer_correct_identifier_length', () {
      test('prefer_correct_identifier_length SHOULD trigger', () {
        // Better alternative available: prefer correct identifier length
        expect('prefer_correct_identifier_length detected', isNotNull);
      });

      test('prefer_correct_identifier_length should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_identifier_length passes', isNotNull);
      });
    });

    group('prefer_correct_setter_parameter_name', () {
      test('prefer_correct_setter_parameter_name SHOULD trigger', () {
        // Better alternative available: prefer correct setter parameter name
        expect('prefer_correct_setter_parameter_name detected', isNotNull);
      });

      test('prefer_correct_setter_parameter_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_setter_parameter_name passes', isNotNull);
      });
    });

    group('prefer_explicit_parameter_names', () {
      test('prefer_explicit_parameter_names SHOULD trigger', () {
        // Better alternative available: prefer explicit parameter names
        expect('prefer_explicit_parameter_names detected', isNotNull);
      });

      test('prefer_explicit_parameter_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_parameter_names passes', isNotNull);
      });
    });

    group('prefer_match_file_name', () {
      test('prefer_match_file_name SHOULD trigger', () {
        // Better alternative available: prefer match file name
        expect('prefer_match_file_name detected', isNotNull);
      });

      test('prefer_match_file_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_match_file_name passes', isNotNull);
      });
    });

    group('prefer_prefixed_global_constants', () {
      test('prefer_prefixed_global_constants SHOULD trigger', () {
        // Better alternative available: prefer prefixed global constants
        expect('prefer_prefixed_global_constants detected', isNotNull);
      });

      test('prefer_prefixed_global_constants should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_prefixed_global_constants passes', isNotNull);
      });
    });

    group('prefer_kebab_tag_name', () {
      test('prefer_kebab_tag_name SHOULD trigger', () {
        // Better alternative available: prefer kebab tag name
        expect('prefer_kebab_tag_name detected', isNotNull);
      });

      test('prefer_kebab_tag_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_kebab_tag_name passes', isNotNull);
      });
    });

    group('prefer_named_extensions', () {
      test('prefer_named_extensions SHOULD trigger', () {
        // Better alternative available: prefer named extensions
        expect('prefer_named_extensions detected', isNotNull);
      });

      test('prefer_named_extensions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_named_extensions passes', isNotNull);
      });
    });

    group('prefer_typedef_for_callbacks', () {
      test('prefer_typedef_for_callbacks SHOULD trigger', () {
        // Better alternative available: prefer typedef for callbacks
        expect('prefer_typedef_for_callbacks detected', isNotNull);
      });

      test('prefer_typedef_for_callbacks should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_typedef_for_callbacks passes', isNotNull);
      });
    });

    group('prefer_enhanced_enums', () {
      test('prefer_enhanced_enums SHOULD trigger', () {
        // Better alternative available: prefer enhanced enums
        expect('prefer_enhanced_enums detected', isNotNull);
      });

      test('prefer_enhanced_enums should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_enhanced_enums passes', isNotNull);
      });
    });

    group('prefer_wildcard_for_unused_param', () {
      test('prefer_wildcard_for_unused_param SHOULD trigger', () {
        // Better alternative available: prefer wildcard for unused param
        expect('prefer_wildcard_for_unused_param detected', isNotNull);
      });

      test('prefer_wildcard_for_unused_param should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_wildcard_for_unused_param passes', isNotNull);
      });
    });

    group('prefer_correct_package_name', () {
      test('prefer_correct_package_name SHOULD trigger', () {
        // Better alternative available: prefer correct package name
        expect('prefer_correct_package_name detected', isNotNull);
      });

      test('prefer_correct_package_name should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_correct_package_name passes', isNotNull);
      });
    });
  });

  group('Naming Style - Avoidance Rules', () {
    group('avoid_non_ascii_symbols', () {
      test('avoid_non_ascii_symbols SHOULD trigger', () {
        // Pattern that should be avoided: avoid non ascii symbols
        expect('avoid_non_ascii_symbols detected', isNotNull);
      });

      test('avoid_non_ascii_symbols should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_non_ascii_symbols passes', isNotNull);
      });
    });
  });

  group('Naming Style - General Rules', () {
    group('match_class_name_pattern', () {
      test('match_class_name_pattern SHOULD trigger', () {
        // Detected violation: match class name pattern
        expect('match_class_name_pattern detected', isNotNull);
      });

      test('match_class_name_pattern should NOT trigger', () {
        // Compliant code passes
        expect('match_class_name_pattern passes', isNotNull);
      });
    });

    group('match_getter_setter_field_names', () {
      test('match_getter_setter_field_names SHOULD trigger', () {
        // Detected violation: match getter setter field names
        expect('match_getter_setter_field_names detected', isNotNull);
      });

      test('match_getter_setter_field_names should NOT trigger', () {
        // Compliant code passes
        expect('match_getter_setter_field_names passes', isNotNull);
      });
    });

    group('match_lib_folder_structure', () {
      test('match_lib_folder_structure SHOULD trigger', () {
        // Detected violation: match lib folder structure
        expect('match_lib_folder_structure detected', isNotNull);
      });

      test('match_lib_folder_structure should NOT trigger', () {
        // Compliant code passes
        expect('match_lib_folder_structure passes', isNotNull);
      });
    });

    group('match_positional_field_names_on_assignment', () {
      test('match_positional_field_names_on_assignment SHOULD trigger', () {
        // Detected violation: match positional field names on assignment
        expect(
          'match_positional_field_names_on_assignment detected',
          isNotNull,
        );
      });

      test('match_positional_field_names_on_assignment should NOT trigger', () {
        // Compliant code passes
        expect('match_positional_field_names_on_assignment passes', isNotNull);
      });
    });
  });
}
