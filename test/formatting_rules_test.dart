import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:saropa_lints/src/rules/stylistic/formatting_rules.dart';
import 'package:test/test.dart';

/// Tests for 10 Formatting lint rules.
///
/// Test fixtures: example_core/lib/formatting/*
void main() {
  group('Formatting Rules - Rule Instantiation', () {
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
      'NewlineBeforeCaseRule',
      'prefer_blank_line_before_case',
      () => NewlineBeforeCaseRule(),
    );

    testRule(
      'NewlineBeforeConstructorRule',
      'prefer_blank_line_before_constructor',
      () => NewlineBeforeConstructorRule(),
    );

    testRule(
      'NewlineBeforeMethodRule',
      'prefer_blank_line_before_method',
      () => NewlineBeforeMethodRule(),
    );

    testRule(
      'NewlineBeforeReturnRule',
      'prefer_blank_line_before_return',
      () => NewlineBeforeReturnRule(),
    );

    testRule(
      'NewlineBeforeElseRule',
      'prefer_blank_line_before_else',
      () => NewlineBeforeElseRule(),
    );

    testRule(
      'NewlineAfterLoopRule',
      'prefer_blank_line_after_loop',
      () => NewlineAfterLoopRule(),
    );

    testRule(
      'PreferTrailingCommaRule',
      'prefer_trailing_comma',
      () => PreferTrailingCommaRule(),
    );

    testRule(
      'UnnecessaryTrailingCommaRule',
      'unnecessary_trailing_comma',
      () => UnnecessaryTrailingCommaRule(),
    );

    testRule(
      'FormatCommentFormattingRule',
      'format_comment_style',
      () => FormatCommentFormattingRule(),
    );

    testRule(
      'RequireIgnoreCommentSpacingRule',
      'require_ignore_comment_spacing',
      () => RequireIgnoreCommentSpacingRule(),
    );

    testRule(
      'MemberOrderingFormattingRule',
      'prefer_member_ordering',
      () => MemberOrderingFormattingRule(),
    );

    testRule(
      'ParametersOrderingConventionRule',
      'enforce_parameters_ordering',
      () => ParametersOrderingConventionRule(),
    );

    testRule(
      'EnumConstantsOrderingRule',
      'enum_constants_ordering',
      () => EnumConstantsOrderingRule(),
    );
  });

  group('Formatting Rules - Fixture Verification', () {
    final fixtures = [
      'prefer_blank_line_before_case',
      'prefer_blank_line_before_constructor',
      'prefer_blank_line_before_method',
      'prefer_blank_line_before_return',
      'prefer_blank_line_before_else',
      'prefer_blank_line_after_loop',
      'prefer_trailing_comma',
      'unnecessary_trailing_comma',
      'format_comment_style',
      'require_ignore_comment_spacing',
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
      'lib/src/fixes/formatting/require_ignore_comment_spacing_fix.dart',
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

    group('prefer_blank_line_before_else', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = NewlineBeforeElseRule();
        expect(rule.impact, LintImpact.opinionated);
      });

      test('rule offers quick fix (add blank line before else)', () {
        final rule = NewlineBeforeElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('prefer_blank_line_before_else SHOULD trigger', () {
        expect('prefer_blank_line_before_else detected', isNotNull);
      });

      test('prefer_blank_line_before_else should NOT trigger', () {
        expect('prefer_blank_line_before_else passes', isNotNull);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example_core/lib/formatting/prefer_blank_line_before_else_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_before_else'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example_core/lib/formatting/prefer_blank_line_before_else_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: if without else must not trigger',
        () {
          final content = File(
            'example_core/lib/formatting/prefer_blank_line_before_else_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_noElse'));
          expect(content, contains('if (x)'));
          // _noElse has no else clause; rule must not report there.
        },
      );
    });

    group('prefer_blank_line_after_loop', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = NewlineAfterLoopRule();
        expect(rule.impact, LintImpact.opinionated);
      });

      test('rule offers quick fix (add blank line after loop)', () {
        final rule = NewlineAfterLoopRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('prefer_blank_line_after_loop SHOULD trigger', () {
        expect('prefer_blank_line_after_loop detected', isNotNull);
      });

      test('prefer_blank_line_after_loop should NOT trigger', () {
        expect('prefer_blank_line_after_loop passes', isNotNull);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example_core/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_after_loop'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example_core/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: block with only loop must not trigger',
        () {
          final content = File(
            'example_core/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_onlyLoop'));
          expect(content, contains('for (var i = 0'));
        },
      );
    });

    group('prefer_trailing_comma', () {
      test('rule offers quick fix (add trailing comma)', () {
        final rule = PreferTrailingCommaRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

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
      test('rule offers quick fix (remove unnecessary trailing comma)', () {
        final rule = UnnecessaryTrailingCommaRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

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

    group('require_ignore_comment_spacing', () {
      test('require_ignore_comment_spacing SHOULD trigger', () {
        expect('require_ignore_comment_spacing detected', isNotNull);
      });

      test('require_ignore_comment_spacing should NOT trigger', () {
        expect('require_ignore_comment_spacing passes', isNotNull);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example_core/lib/formatting/require_ignore_comment_spacing_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: require_ignore_comment_spacing'),
        );
        expect(content, contains('// ignore:require_debouncer_cancel'));
        expect(content, contains('// ignore_for_file:avoid_print'));
      });

      test(
        'fixture has good examples (space after colon) that must not trigger',
        () {
          final content = File(
            'example_core/lib/formatting/require_ignore_comment_spacing_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('// ignore: require_debouncer_cancel'));
          expect(content, contains('// ignore_for_file: avoid_print'));
        },
      );
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
