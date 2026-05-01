import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration and fixture markers for `prefer_layout_builder_for_constraints`.
///
/// Regression: double-report on `.size` and `.size.width`; false positives on
/// `* 0.85`, breakpoint comparisons, and `MediaQuery.sizeOf` parity — see
/// `plan/history/2026.04/2026.04.26/prefer_layout_builder_for_constraints_false_positive_intentional_screen_percentage.md`.
void main() {
  const ruleName = 'prefer_layout_builder_for_constraints';

  group('PreferLayoutBuilderForConstraintsRule fixtures', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('getRulesFromRegistry resolves the rule when asked by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test('ships with professional tier (cumulative)', () {
      final professional = getRulesForTier('professional');
      expect(
        professional.contains(ruleName),
        isTrue,
        reason: '$ruleName is INFO layout guidance (Professional)',
      );
    });

    test('BAD fixture declares seven expect_lint markers', () {
      final file = File('example/lib/widget_layout/${ruleName}_fixture.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final markerCount = '// expect_lint: $ruleName'
          .allMatches(content)
          .length;
      expect(
        markerCount,
        equals(7),
        reason:
            'Constrained width, width+height, sizeOf width, two width operands, '
            'and AnimatedBuilder builder callback',
      );
    });

    test(
      'fixture GOOD / OK blocks after OkScreenFraction have no expect_lint',
      () {
        final file = File('example/lib/widget_layout/${ruleName}_fixture.dart');
        final content = file.readAsStringSync();
        final idx = content.indexOf('class OkScreenFraction');
        expect(idx, greaterThan(0));
        final tail = content.substring(idx);
        expect(
          tail.contains('// expect_lint: $ruleName'),
          isFalse,
          reason:
              'Screen fraction, breakpoint, viewInsets, LayoutBuilder: no '
              'diagnostic assertions',
        );
      },
    );
  });
}
