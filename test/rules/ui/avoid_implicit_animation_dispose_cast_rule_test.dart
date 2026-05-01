import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Behavioral and registration tests for [AvoidImplicitAnimationDisposeCastRule].
///
/// Complements `example/lib/animation/avoid_implicit_animation_dispose_cast_fixture.dart`
/// (expect_lint) and documents false-positive boundaries.
void main() {
  const ruleName = 'avoid_implicit_animation_dispose_cast';

  group('AvoidImplicitAnimationDisposeCastRule', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test(
      'is in professional tier (cumulative includes recommended + essential)',
      () {
        final professional = getRulesForTier('professional');
        expect(
          professional.contains(ruleName),
          isTrue,
          reason: '$ruleName should ship with professional tier',
        );
      },
    );

    test('is not in essential tier alone', () {
      final essentialOnly = getRulesForTier('essential');
      expect(
        essentialOnly.contains(ruleName),
        isFalse,
        reason:
            'implicit animation dispose cast is polish/migration, not crash-critical tier-1',
      );
    });

    test('rule exposes quick fix and performance hints', () {
      final rule = getRulesFromRegistry(<String>{ruleName}).single;
      expect(rule.fixGenerators, isNotEmpty);
      expect(rule.requiredPatterns, contains('as CurvedAnimation'));
      expect(rule.applicableFileTypes, equals({FileType.widget}));
      expect(rule.impact, LintImpact.high);
    });

    test('fixture: BAD case has expect_lint before violation', () {
      final file = File('example/lib/animation/${ruleName}_fixture.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(
        content.contains('// expect_lint: $ruleName'),
        isTrue,
        reason:
            'Fixture must document the diagnostic site for custom_lint workflows',
      );
    });

    test(
      'fixture: GOOD dispose-only block has no expect_lint (false positive guard)',
      () {
        final content = File(
          'example/lib/animation/${ruleName}_fixture.dart',
        ).readAsStringSync();
        final start = content.indexOf('class _GoodImplicitAnimState');
        final end = content.indexOf('class _GoodCurveReadWidget');
        expect(start, greaterThan(-1));
        expect(end, greaterThan(start));
        final slice = content.substring(start, end);
        expect(
          slice.contains('expect_lint: $ruleName'),
          isFalse,
          reason: 'super.dispose()-only GOOD state must not expect this lint',
        );
      },
    );

    test(
      'fixture: curve-read GOOD block has no expect_lint (non-dispose cast)',
      () {
        final content = File(
          'example/lib/animation/${ruleName}_fixture.dart',
        ).readAsStringSync();
        final start = content.indexOf('class _GoodCurveReadState');
        expect(start, greaterThan(-1));
        final tail = content.substring(start);
        expect(
          tail.contains('expect_lint: $ruleName'),
          isFalse,
          reason: '(animation as CurvedAnimation).curve must not be flagged',
        );
      },
    );

    test('getRulesFromRegistry includes rule when explicitly requested', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });
  });
}
