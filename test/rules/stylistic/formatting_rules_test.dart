import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart' show LintImpact;
import 'package:saropa_lints/src/rules/stylistic/formatting_rules.dart';
import 'package:test/test.dart';
import '../../helpers/fixture_discovery.dart';
import '../../support/resolved_rule_harness.dart';

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
      'RequireIgnoreCommentPluginPrefixRule',
      'require_ignore_comment_plugin_prefix',
      () => RequireIgnoreCommentPluginPrefixRule(),
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

    testRule(
      'PreferBlankLineBeforeBreakRule',
      'prefer_blank_line_before_break',
      () => PreferBlankLineBeforeBreakRule(),
    );

    testRule(
      'PreferBlankLineBeforeContinueRule',
      'prefer_blank_line_before_continue',
      () => PreferBlankLineBeforeContinueRule(),
    );

    testRule(
      'PreferBlankLineBeforeThrowRule',
      'prefer_blank_line_before_throw',
      () => PreferBlankLineBeforeThrowRule(),
    );
  });

  group('Formatting Rules - Fixture Verification', () {
    final fixtureDir = Directory('example/lib/formatting');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

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
      'lib/src/fixes/formatting/add_blank_line_before_statement_fix.dart',
      'lib/src/fixes/formatting/require_ignore_comment_spacing_fix.dart',
      'lib/src/fixes/formatting/require_ignore_comment_plugin_prefix_fix.dart',
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

    group('prefer_blank_line_before_break', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = PreferBlankLineBeforeBreakRule();
        expect(rule.impact, LintImpact.info);
      });

      test('rule offers quick fix (add blank line before break)', () {
        final rule = PreferBlankLineBeforeBreakRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_break_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_before_break'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_break_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: sole break in loop must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_before_break_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_soleBreak'));
        },
      );
    });

    group('prefer_blank_line_before_continue', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = PreferBlankLineBeforeContinueRule();
        expect(rule.impact, LintImpact.info);
      });

      test('rule offers quick fix (add blank line before continue)', () {
        final rule = PreferBlankLineBeforeContinueRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_continue_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_before_continue'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_continue_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: sole continue guard must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_before_continue_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_soleContinue'));
        },
      );
    });

    group('prefer_blank_line_before_throw', () {
      test('is stylistic rule (opinionated impact)', () {
        final rule = PreferBlankLineBeforeThrowRule();
        expect(rule.impact, LintImpact.info);
      });

      test('rule offers quick fix (add blank line before throw)', () {
        final rule = PreferBlankLineBeforeThrowRule();
        expect(rule.fixGenerators, isNotEmpty);
      });

      test('fixture has bad example with expect_lint marker', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_throw_fixture.dart',
        ).readAsStringSync();
        expect(
          content,
          contains('// expect_lint: prefer_blank_line_before_throw'),
        );
        expect(content, contains('_bad'));
      });

      test('fixture has good example without violation', () {
        final content = File(
          'example/lib/formatting/prefer_blank_line_before_throw_fixture.dart',
        ).readAsStringSync();
        expect(content, contains('_good'));
      });

      test(
        'fixture has false-positive guard: inline throw-expression must not trigger',
        () {
          final content = File(
            'example/lib/formatting/prefer_blank_line_before_throw_fixture.dart',
          ).readAsStringSync();
          expect(content, contains('_inlineThrowExpression'));
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
    });

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
  });

  // Resolved tests: verify diagnostic messages match the detected condition.
  group('require_ignore_comment_plugin_prefix — resolved message', () {
    final rule = RequireIgnoreCommentPluginPrefixRule();

    test(
      'bare saropa rule name emits "without the required prefix" message',
      () async {
        // 'avoid_null_assertion' is a registered saropa_lints rule used bare.
        final diags = await runRuleResolved(rule, '''
// ignore: avoid_null_assertion
final x = 1;
''');
        expect(diags, hasLength(1));
        // The bare-name diagnostic tells the developer to add the prefix.
        expect(diags.first.message, contains('without the required'));
      },
    );

    test(
      'prefixed unknown rule emits "not a registered saropa_lints rule" message',
      () async {
        // 'totally_fake_rule' is NOT registered — prefix is present but wrong.
        final diags = await runRuleResolved(rule, '''
// ignore: saropa_lints/totally_fake_rule
final x = 1;
''');
        expect(diags, hasLength(1));
        // The unknown-prefix diagnostic says the rule isn't registered.
        expect(diags.first.message, contains('not a registered'));
        // Must NOT contain the bare-name message.
        expect(diags.first.message, isNot(contains('without the required')));
      },
    );

    test('prefixed registered rule emits no diagnostic', () async {
      // 'avoid_null_assertion' with correct prefix — no lint expected.
      final diags = await runRuleResolved(rule, '''
// ignore: saropa_lints/avoid_null_assertion
final x = 1;
''');
      expect(diags, isEmpty);
    });

    test('non-saropa bare rule emits no diagnostic', () async {
      // 'unused_import' is a core Dart lint, not a saropa_lints rule.
      final diags = await runRuleResolved(rule, '''
// ignore: unused_import
final x = 1;
''');
      expect(diags, isEmpty);
    });
  });

  // Resolved tests: prove the three new blank-line-before-exit rules
  // actually fire on bad code and stay silent on good/guard code, not just
  // that they instantiate (see resolved_rule_harness.dart doc comment on
  // why instantiation-only pins are not enough).
  group('prefer_blank_line_before_break — resolved firing', () {
    final rule = PreferBlankLineBeforeBreakRule();

    test('break without blank line in a switch case fires', () async {
      final diags = await runRuleResolved(rule, '''
void f(int x) {
  switch (x) {
    case 2:
      f(1);
      break;
  }
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'prefer_blank_line_before_break');
    });

    test('break with a blank line before it does not fire', () async {
      final diags = await runRuleResolved(rule, '''
void f(int x) {
  switch (x) {
    case 2:
      f(1);

      break;
  }
}
''');
      expect(diags, isEmpty);
    });

    test('break as the sole statement in a loop does not fire', () async {
      final diags = await runRuleResolved(rule, '''
void f() {
  for (var i = 0; i < 10; i++) {
    break;
  }
}
''');
      expect(diags, isEmpty);
    });
  });

  group('prefer_blank_line_before_continue — resolved firing', () {
    final rule = PreferBlankLineBeforeContinueRule();

    test('continue without blank line inside a loop fires', () async {
      final diags = await runRuleResolved(rule, '''
void f(List<int> xs) {
  for (final x in xs) {
    if (x < 0) {
      f(<int>[]);
      continue;
    }
  }
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'prefer_blank_line_before_continue');
    });

    test('continue with a blank line before it does not fire', () async {
      final diags = await runRuleResolved(rule, '''
void f(List<int> xs) {
  for (final x in xs) {
    if (x < 0) {
      f(<int>[]);

      continue;
    }
  }
}
''');
      expect(diags, isEmpty);
    });

    test(
      'continue as the sole statement in a guard clause does not fire',
      () async {
        final diags = await runRuleResolved(rule, '''
void f(List<int> xs) {
  for (final x in xs) {
    if (x < 0) continue;
  }
}
''');
        expect(diags, isEmpty);
      },
    );
  });

  group('prefer_blank_line_before_throw — resolved firing', () {
    final rule = PreferBlankLineBeforeThrowRule();

    test('throw without blank line inside a guard fires', () async {
      final diags = await runRuleResolved(rule, '''
void f(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    f(trimmed);
    throw ArgumentError('empty');
  }
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'prefer_blank_line_before_throw');
    });

    test('throw with a blank line before it does not fire', () async {
      final diags = await runRuleResolved(rule, '''
void f(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    f(trimmed);

    throw ArgumentError('empty');
  }
}
''');
      expect(diags, isEmpty);
    });

    test('throw as the sole statement in a guard does not fire', () async {
      final diags = await runRuleResolved(rule, '''
void f(bool ok) {
  if (!ok) throw StateError('invalid');
}
''');
      expect(diags, isEmpty);
    });

    test('inline throw-expression (not a statement) does not fire', () async {
      final diags = await runRuleResolved(rule, '''
int f(int? value) {
  return value ?? (throw StateError('required'));
}
''');
      expect(diags, isEmpty);
    });
  });
}
