import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration and fixture markers for `avoid_excessive_rebuilds_animation`.
void main() {
  const ruleName = 'avoid_excessive_rebuilds_animation';

  group('AvoidExcessiveRebuildsAnimationRule fixtures', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('getRulesFromRegistry resolves the rule when asked by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test(
      'fixture declares two expect_lint markers (animation-driven builders)',
      () {
        final file = File('example/lib/animation/${ruleName}_fixture.dart');
        expect(file.existsSync(), isTrue);
        final content = file.readAsStringSync();
        final markerCount = '// expect_lint: $ruleName'
            .allMatches(content)
            .length;
        expect(markerCount, equals(2));
      },
    );

    test('ships with essential tier (cumulative)', () {
      final essential = getRulesForTier('essential');
      expect(
        essential.contains(ruleName),
        isTrue,
        reason: '$ruleName ships Essential (animation perf)',
      );
    });

    test(
      'fixture GOOD block documents async/reactive builders without expect_lint',
      () {
        final file = File('example/lib/animation/${ruleName}_fixture.dart');
        final content = file.readAsStringSync();
        final goodIdx = content.indexOf('// GOOD');
        expect(goodIdx, greaterThan(0));
        final tail = content.substring(goodIdx);
        expect(
          tail.contains('// expect_lint: $ruleName'),
          isFalse,
          reason:
              'False-positive guards must not assert diagnostics under GOOD',
        );
      },
    );
  });
}
