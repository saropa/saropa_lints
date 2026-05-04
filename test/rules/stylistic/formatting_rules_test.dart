import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:saropa_lints/src/rules/stylistic/formatting_rules.dart';
import 'package:test/test.dart';

/// Tests for 10 Formatting lint rules.
///
/// Test fixtures: example/lib/formatting/*
// Trailing comma, brace style, and dart format-adjacent stylistic lints.
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
        final file = File('example/lib/formatting/${fixture}_fixture.dart');
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
    group('prefer_blank_line_before_else', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = NewlineBeforeElseRule();
        expect(rule.impact, LintImpact.info);
      });

      test('rule offers quick fix (add blank line before else)', () {
        final rule = NewlineBeforeElseRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_else_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_before_else'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_else_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: if without else must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_before_else_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_noElse'));
          expect(content, contains('if (x)'));
          // _noElse has no else clause; rule must not report there.
        },
      );

      test(
        'fixture has false-positive guard: else-if chains must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_before_else_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_elseIfChain'));
          expect(content, contains('else if'));
          // else-if is a single control-flow construct; rule must skip it.
        },
      );
    });

    group('prefer_blank_line_after_loop', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = NewlineAfterLoopRule();
        expect(rule.impact, LintImpact.info);
      });

      test('rule offers quick fix (add blank line after loop)', () {
        final rule = NewlineAfterLoopRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_after_loop'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: block with only loop must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_after_loop_fixture.dart',
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
    });

    group('prefer_member_ordering', () {});
  });

  group('Formatting - General Rules', () {
    group('unnecessary_trailing_comma', () {
      test('rule offers quick fix (remove unnecessary trailing comma)', () {
        final rule = UnnecessaryTrailingCommaRule();
        expect(rule.fixGenerators, isNotEmpty);
      });
    });

    group('format_comment_style', () {});

    group('require_ignore_comment_spacing', () {
      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/require_ignore_comment_spacing_fixture.dart',
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
            'example/lib/formatting/require_ignore_comment_spacing_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('// ignore: require_debouncer_cancel'));
          expect(content, contains('// ignore_for_file: avoid_print'));
        },
      );
    });

    group('enforce_parameters_ordering', () {});

    group('enum_constants_ordering', () {});
  });

  // Stub-only behavior tests were removed from this file. Keep metadata,
  // fixture checks, quick-fix presence checks, and regression fixture guards.
}
