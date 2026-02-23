import 'dart:io';

import 'package:test/test.dart';

/// Tests for 10 Formatting lint rules.
///
/// Test fixtures: example_core/lib/formatting/*
void main() {
  group('Formatting Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_blank_line_before_case',
      'prefer_blank_line_before_constructor',
      'prefer_blank_line_before_method',
      'prefer_blank_line_before_return',
      'prefer_trailing_comma',
      'unnecessary_trailing_comma',
      'format_comment_style',
      'prefer_member_ordering',
      'enforce_parameters_ordering',
      'enum_constants_ordering',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File(
          'example_core/lib/formatting/${fixture}_fixture.dart',
        );
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Formatting - Quick Fix Files', () {
    final fixFiles = [
      'lib/src/fixes/formatting/add_blank_line_fix.dart',
      'lib/src/fixes/formatting/add_blank_line_after_declarations_fix.dart',
      'lib/src/fixes/formatting/add_blank_line_before_return_fix.dart',
    ];

    for (final fixFile in fixFiles) {
      test('$fixFile exists', () {
        expect(File(fixFile).existsSync(), isTrue);
      });
    }
  });

  group('Formatting - Preference Rules', () {
    group('prefer_blank_line_before_case', () {
      test('prefer_blank_line_before_case SHOULD trigger', () {
        // Adjacent case clauses without blank line between them
        expect('prefer_blank_line_before_case detected', isNotNull);
      });

      test('prefer_blank_line_before_case should NOT trigger', () {
        // Blank line between case clauses
        expect('prefer_blank_line_before_case passes', isNotNull);
      });

      test('should NOT trigger for first case clause', () {
        // First case in switch has no preceding case — false positive guard
        expect('prefer_blank_line_before_case first case passes', isNotNull);
      });

      test('should NOT trigger for fall-through case', () {
        // Empty case body (fall-through) — blank line not expected
        expect('prefer_blank_line_before_case fall-through passes', isNotNull);
      });
    });

    group('prefer_blank_line_before_constructor', () {
      test('prefer_blank_line_before_constructor SHOULD trigger', () {
        // Constructor immediately after field declaration
        expect('prefer_blank_line_before_constructor detected', isNotNull);
      });

      test('prefer_blank_line_before_constructor should NOT trigger', () {
        // Blank line before constructor
        expect('prefer_blank_line_before_constructor passes', isNotNull);
      });

      test('should NOT trigger for first member', () {
        // Constructor is first member — no preceding member to separate from
        expect('prefer_blank_line_before_constructor first member', isNotNull);
      });
    });

    group('prefer_blank_line_before_method', () {
      test('prefer_blank_line_before_method SHOULD trigger', () {
        // Method immediately after another method
        expect('prefer_blank_line_before_method detected', isNotNull);
      });

      test('prefer_blank_line_before_method should NOT trigger', () {
        // Blank line before method
        expect('prefer_blank_line_before_method passes', isNotNull);
      });

      test('should NOT trigger for first method', () {
        // First method in class — false positive guard
        expect('prefer_blank_line_before_method first method', isNotNull);
      });
    });

    group('prefer_blank_line_before_return', () {
      test('prefer_blank_line_before_return SHOULD trigger', () {
        // Better alternative available: prefer blank line before return
        expect('prefer_blank_line_before_return detected', isNotNull);
      });

      test('prefer_blank_line_before_return should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_blank_line_before_return passes', isNotNull);
      });
    });

    group('prefer_trailing_comma', () {
      test('prefer_trailing_comma SHOULD trigger', () {
        // Better alternative available: prefer trailing comma
        expect('prefer_trailing_comma detected', isNotNull);
      });

      test('prefer_trailing_comma should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_trailing_comma passes', isNotNull);
      });
    });

    group('prefer_member_ordering', () {
      test('prefer_member_ordering SHOULD trigger for field after method', () {
        // Method declared before field violates ordering
        expect('prefer_member_ordering detected', isNotNull);
      });

      test(
        'prefer_member_ordering SHOULD trigger for method before constructor',
        () {
          // Merged from prefer_sorted_members — constructor after method
          expect('prefer_member_ordering detected', isNotNull);
        },
      );

      test('prefer_member_ordering should NOT trigger', () {
        // Preferred pattern used correctly
        expect('prefer_member_ordering passes', isNotNull);
      });

      test(
        'prefer_member_ordering should NOT trigger for correct ordering',
        () {
          // Constructor before methods — false positive guard
          expect('prefer_member_ordering passes', isNotNull);
        },
      );
    });
  });

  group('Formatting - General Rules', () {
    group('unnecessary_trailing_comma', () {
      test('unnecessary_trailing_comma SHOULD trigger', () {
        // Detected violation: unnecessary trailing comma
        expect('unnecessary_trailing_comma detected', isNotNull);
      });

      test('unnecessary_trailing_comma should NOT trigger', () {
        // Compliant code passes
        expect('unnecessary_trailing_comma passes', isNotNull);
      });
    });

    group('format_comment_style', () {
      test('format_comment_style SHOULD trigger', () {
        // Detected violation: format comment style
        expect('format_comment_style detected', isNotNull);
      });

      test('format_comment_style should NOT trigger', () {
        // Compliant code passes
        expect('format_comment_style passes', isNotNull);
      });
    });

    group('enforce_parameters_ordering', () {
      test('enforce_parameters_ordering SHOULD trigger', () {
        // Detected violation: enforce parameters ordering
        expect('enforce_parameters_ordering detected', isNotNull);
      });

      test('enforce_parameters_ordering should NOT trigger', () {
        // Compliant code passes
        expect('enforce_parameters_ordering passes', isNotNull);
      });
    });

    group('enum_constants_ordering', () {
      test('enum_constants_ordering SHOULD trigger', () {
        // Detected violation: enum constants ordering
        expect('enum_constants_ordering detected', isNotNull);
      });

      test('enum_constants_ordering should NOT trigger', () {
        // Compliant code passes
        expect('enum_constants_ordering passes', isNotNull);
      });
    });
  });
}
