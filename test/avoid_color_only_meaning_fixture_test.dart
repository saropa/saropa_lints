import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration and fixture-shape tests for [AvoidColorOnlyMeaningRule].
/// Behavioral coverage is in `example/lib/accessibility/avoid_color_only_meaning_fixture.dart`
/// (custom_lint + `expect_lint:` markers).
void main() {
  const ruleName = 'avoid_color_only_meaning';

  group('AvoidColorOnlyMeaningRule', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('ships with essential tier (cumulative)', () {
      final essential = getRulesForTier('essential');
      expect(
        essential.contains(ruleName),
        isTrue,
        reason: '$ruleName is WCAG 1.4.1 — Essential',
      );
    });

    test('getRulesFromRegistry resolves the rule when asked by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test('fixture: exactly three BAD sites declare expect_lint', () {
      final file = File('example/lib/accessibility/${ruleName}_fixture.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final markerCount = '// expect_lint: $ruleName'
          .allMatches(content)
          .length;
      expect(
        markerCount,
        equals(3),
        reason:
            'Two ColoredBox BAD cases plus one unknown-wrapper regression guard',
      );
    });

    test(
      'fixture: GOOD wrapper block has no expect_lint (false-positive guard)',
      () {
        final content = File(
          'example/lib/accessibility/${ruleName}_fixture.dart',
        ).readAsStringSync();
        final start = content.indexOf('void _goodStateWithCommonIconWrapper');
        // Slice ends before the BAD regression guard (its `expect_lint` sits
        // immediately above `void _badStateWithUnknownAppWrapper`).
        final end = content.indexOf('// BAD: Prefix alone should not suppress');
        expect(start, greaterThan(-1));
        expect(end, greaterThan(start));
        final slice = content.substring(start, end);
        expect(
          slice.contains('expect_lint: $ruleName'),
          isFalse,
          reason:
              'Common*/Brand*/App* companions must not require suppression markers',
        );
      },
    );
  });
}
