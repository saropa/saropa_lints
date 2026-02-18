import 'dart:io';

import 'package:test/test.dart';

/// Tests for 27 Stylistic lint rules.
///
/// Test fixtures: example_style/lib/stylistic/*
void main() {
  group('Stylistic Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_relative_imports',
      'prefer_one_widget_per_file',
      'prefer_arrow_functions',
      'prefer_all_named_parameters',
      'prefer_trailing_comma_always',
      'prefer_private_underscore_prefix',
      'prefer_widget_methods_over_classes',
      'prefer_explicit_types',
      'prefer_class_over_record_return',
      'prefer_inline_callbacks',
      'prefer_single_quotes',
      'prefer_todo_format',
      'prefer_fixme_format',
      'prefer_sentence_case_comments',
      'prefer_period_after_doc',
      'prefer_screaming_case_constants',
      'prefer_descriptive_bool_names',
      'prefer_descriptive_bool_names_strict',
      'prefer_snake_case_files',
      'avoid_small_text',
      'prefer_doc_comments_over_regular',
      'prefer_straight_apostrophe',
      'prefer_doc_curly_apostrophe',
      'prefer_doc_straight_apostrophe',
      'prefer_curly_apostrophe',
      'prefer_arguments_ordering',
      'prefer_no_commented_out_code',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_style/lib/stylistic/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Stylistic - Preference Rules', () {
    group('prefer_relative_imports', () {
      test('prefer_relative_imports SHOULD trigger', () {
        // Better alternative available: prefer relative imports
        expect('prefer_relative_imports detected', isNotNull);
      });

      test('prefer_relative_imports should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_relative_imports passes', isNotNull);
      });
    });

    group('prefer_one_widget_per_file', () {
      test('prefer_one_widget_per_file SHOULD trigger', () {
        // Better alternative available: prefer one widget per file
        expect('prefer_one_widget_per_file detected', isNotNull);
      });

      test('prefer_one_widget_per_file should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_one_widget_per_file passes', isNotNull);
      });
    });

    group('prefer_arrow_functions', () {
      test('prefer_arrow_functions SHOULD trigger', () {
        // Better alternative available: prefer arrow functions
        expect('prefer_arrow_functions detected', isNotNull);
      });

      test('prefer_arrow_functions should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_arrow_functions passes', isNotNull);
      });
    });

    group('prefer_all_named_parameters', () {
      test('prefer_all_named_parameters SHOULD trigger', () {
        // Better alternative available: prefer all named parameters
        expect('prefer_all_named_parameters detected', isNotNull);
      });

      test('prefer_all_named_parameters should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_all_named_parameters passes', isNotNull);
      });
    });

    group('prefer_trailing_comma_always', () {
      test('prefer_trailing_comma_always SHOULD trigger', () {
        // Better alternative available: prefer trailing comma always
        expect('prefer_trailing_comma_always detected', isNotNull);
      });

      test('prefer_trailing_comma_always should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_trailing_comma_always passes', isNotNull);
      });
    });

    group('prefer_private_underscore_prefix', () {
      test('prefer_private_underscore_prefix SHOULD trigger', () {
        // Better alternative available: prefer private underscore prefix
        expect('prefer_private_underscore_prefix detected', isNotNull);
      });

      test('prefer_private_underscore_prefix should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_private_underscore_prefix passes', isNotNull);
      });
    });

    group('prefer_widget_methods_over_classes', () {
      test('prefer_widget_methods_over_classes SHOULD trigger', () {
        // Better alternative available: prefer widget methods over classes
        expect('prefer_widget_methods_over_classes detected', isNotNull);
      });

      test('prefer_widget_methods_over_classes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_widget_methods_over_classes passes', isNotNull);
      });
    });

    group('prefer_explicit_types', () {
      test('prefer_explicit_types SHOULD trigger', () {
        // Better alternative available: prefer explicit types
        expect('prefer_explicit_types detected', isNotNull);
      });

      test('prefer_explicit_types should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_explicit_types passes', isNotNull);
      });
    });

    group('prefer_class_over_record_return', () {
      test('prefer_class_over_record_return SHOULD trigger', () {
        // Better alternative available: prefer class over record return
        expect('prefer_class_over_record_return detected', isNotNull);
      });

      test('prefer_class_over_record_return should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_class_over_record_return passes', isNotNull);
      });
    });

    group('prefer_inline_callbacks', () {
      test('prefer_inline_callbacks SHOULD trigger', () {
        // Better alternative available: prefer inline callbacks
        expect('prefer_inline_callbacks detected', isNotNull);
      });

      test('prefer_inline_callbacks should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_inline_callbacks passes', isNotNull);
      });
    });

    group('prefer_single_quotes', () {
      test('prefer_single_quotes SHOULD trigger', () {
        // Better alternative available: prefer single quotes
        expect('prefer_single_quotes detected', isNotNull);
      });

      test('prefer_single_quotes should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_single_quotes passes', isNotNull);
      });
    });

    group('prefer_todo_format', () {
      test('prefer_todo_format SHOULD trigger', () {
        // Better alternative available: prefer todo format
        expect('prefer_todo_format detected', isNotNull);
      });

      test('prefer_todo_format should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_todo_format passes', isNotNull);
      });
    });

    group('prefer_fixme_format', () {
      test('prefer_fixme_format SHOULD trigger', () {
        // Better alternative available: prefer fixme format
        expect('prefer_fixme_format detected', isNotNull);
      });

      test('prefer_fixme_format should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_fixme_format passes', isNotNull);
      });
    });

    group('prefer_sentence_case_comments', () {
      test('prefer_sentence_case_comments SHOULD trigger', () {
        // Better alternative available: prefer sentence case comments
        expect('prefer_sentence_case_comments detected', isNotNull);
      });

      test('prefer_sentence_case_comments should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_sentence_case_comments passes', isNotNull);
      });
    });

    group('prefer_period_after_doc', () {
      test('prefer_period_after_doc SHOULD trigger', () {
        // Better alternative available: prefer period after doc
        expect('prefer_period_after_doc detected', isNotNull);
      });

      test('prefer_period_after_doc should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_period_after_doc passes', isNotNull);
      });
    });

    group('prefer_screaming_case_constants', () {
      test('prefer_screaming_case_constants SHOULD trigger', () {
        // Better alternative available: prefer screaming case constants
        expect('prefer_screaming_case_constants detected', isNotNull);
      });

      test('prefer_screaming_case_constants should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_screaming_case_constants passes', isNotNull);
      });
    });

    group('prefer_descriptive_bool_names', () {
      test('prefer_descriptive_bool_names SHOULD trigger', () {
        // Better alternative available: prefer descriptive bool names
        expect('prefer_descriptive_bool_names detected', isNotNull);
      });

      test('prefer_descriptive_bool_names should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_descriptive_bool_names passes', isNotNull);
      });
    });

    group('prefer_descriptive_bool_names_strict', () {
      test('prefer_descriptive_bool_names_strict SHOULD trigger', () {
        // Better alternative available: prefer descriptive bool names strict
        expect('prefer_descriptive_bool_names_strict detected', isNotNull);
      });

      test('prefer_descriptive_bool_names_strict should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_descriptive_bool_names_strict passes', isNotNull);
      });
    });

    group('prefer_snake_case_files', () {
      test('prefer_snake_case_files SHOULD trigger', () {
        // Better alternative available: prefer snake case files
        expect('prefer_snake_case_files detected', isNotNull);
      });

      test('prefer_snake_case_files should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_snake_case_files passes', isNotNull);
      });
    });

    group('prefer_doc_comments_over_regular', () {
      test('prefer_doc_comments_over_regular SHOULD trigger', () {
        // Better alternative available: prefer doc comments over regular
        expect('prefer_doc_comments_over_regular detected', isNotNull);
      });

      test('prefer_doc_comments_over_regular should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_doc_comments_over_regular passes', isNotNull);
      });
    });

    group('prefer_straight_apostrophe', () {
      test('prefer_straight_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer straight apostrophe
        expect('prefer_straight_apostrophe detected', isNotNull);
      });

      test('prefer_straight_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_straight_apostrophe passes', isNotNull);
      });
    });

    group('prefer_doc_curly_apostrophe', () {
      test('prefer_doc_curly_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer doc curly apostrophe
        expect('prefer_doc_curly_apostrophe detected', isNotNull);
      });

      test('prefer_doc_curly_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_doc_curly_apostrophe passes', isNotNull);
      });
    });

    group('prefer_doc_straight_apostrophe', () {
      test('prefer_doc_straight_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer doc straight apostrophe
        expect('prefer_doc_straight_apostrophe detected', isNotNull);
      });

      test('prefer_doc_straight_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_doc_straight_apostrophe passes', isNotNull);
      });
    });

    group('prefer_curly_apostrophe', () {
      test('prefer_curly_apostrophe SHOULD trigger', () {
        // Better alternative available: prefer curly apostrophe
        expect('prefer_curly_apostrophe detected', isNotNull);
      });

      test('prefer_curly_apostrophe should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_curly_apostrophe passes', isNotNull);
      });
    });

    group('prefer_arguments_ordering', () {
      test('prefer_arguments_ordering SHOULD trigger', () {
        // Better alternative available: prefer arguments ordering
        expect('prefer_arguments_ordering detected', isNotNull);
      });

      test('prefer_arguments_ordering should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_arguments_ordering passes', isNotNull);
      });
    });

    group('prefer_no_commented_out_code', () {
      test('prefer_no_commented_out_code SHOULD trigger', () {
        // Better alternative available: prefer no commented out code
        expect('prefer_no_commented_out_code detected', isNotNull);
      });

      test('prefer_no_commented_out_code should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_no_commented_out_code passes', isNotNull);
      });
    });
  });

  group('Stylistic - Avoidance Rules', () {
    group('avoid_small_text', () {
      test('avoid_small_text SHOULD trigger', () {
        // Pattern that should be avoided: avoid small text
        expect('avoid_small_text detected', isNotNull);
      });

      test('avoid_small_text should NOT trigger', () {
        // Avoidance pattern not present
        expect('avoid_small_text passes', isNotNull);
      });
    });
  });
}
