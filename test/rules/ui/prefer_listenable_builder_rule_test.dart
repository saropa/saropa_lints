import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration, tier, and fixture-shape tests for
/// [PreferListenableBuilderRule]. Behavioral coverage lives in
/// `example/lib/animation/prefer_listenable_builder_fixture.dart`
/// (exercised by custom_lint via `expect_lint:` markers).
void main() {
  const ruleName = 'prefer_listenable_builder';

  group('PreferListenableBuilderRule', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('ships with recommended tier (cumulative)', () {
      final recommended = getRulesForTier('recommended');
      expect(
        recommended.contains(ruleName),
        isTrue,
        reason: '$ruleName is a migration hint and belongs in recommended+',
      );
    });

    test('is NOT in essential tier', () {
      final essential = getRulesForTier('essential');
      expect(
        essential.contains(ruleName),
        isFalse,
        reason: 'Informational migration lint — not a crash-critical rule',
      );
    });

    test('exposes quick fix, early-exit pattern, and widget file type', () {
      final rule = getRulesFromRegistry(<String>{ruleName}).single;
      expect(rule.fixGenerators, isNotEmpty);
      expect(
        rule.requiredPatterns,
        contains('AnimatedBuilder'),
        reason:
            'Early-exit pattern must be the widget name so unrelated files skip AST work',
      );
      expect(rule.applicableFileTypes, equals({FileType.widget}));
      expect(rule.impact, LintImpact.low);
    });

    test('fixture: BAD cases mark expect_lint for plain Listenables', () {
      final file = File('example/lib/animation/${ruleName}_fixture.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // Two BAD blocks: ValueNotifier + ChangeNotifier
      final markerCount = '// expect_lint: $ruleName'
          .allMatches(content)
          .length;
      expect(
        markerCount,
        greaterThanOrEqualTo(2),
        reason:
            'Fixture must pin both ValueNotifier and ChangeNotifier BAD cases',
      );
    });

    test('fixture: GOOD AnimationController block has no expect_lint', () {
      final content = File(
        'example/lib/animation/${ruleName}_fixture.dart',
      ).readAsStringSync();
      final start = content.indexOf('void _goodAnimationController');
      final end = content.indexOf('void _goodCurvedAnimation');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(
        slice.contains('expect_lint: $ruleName'),
        isFalse,
        reason: 'AnimationController is an Animation — must not be flagged',
      );
    });

    test('fixture: GOOD dynamic/unresolved block has no expect_lint', () {
      final content = File(
        'example/lib/animation/${ruleName}_fixture.dart',
      ).readAsStringSync();
      final start = content.indexOf('void _goodDynamic');
      expect(start, greaterThan(-1));
      final slice = content.substring(start);
      expect(
        slice.contains('expect_lint: $ruleName'),
        isFalse,
        reason: 'Dynamic / unresolved types must be skipped to avoid FPs',
      );
    });

    test('getRulesFromRegistry resolves the rule when asked by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });
  });
}
