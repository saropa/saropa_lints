import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  const ruleName = 'avoid_inert_animation_value_in_build';
  const fixturePath =
      'example/lib/animation/avoid_inert_animation_value_in_build_fixture.dart';

  group('avoid_inert_animation_value_in_build AnimatedBuilder child reads', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('getRulesFromRegistry resolves the rule', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test('fixture exists', () {
      expect(File(fixturePath).existsSync(), isTrue);
    });

    test(
      'GOOD AnimatedBuilder builder block has no expect_lint marker',
      () {
        final content = File(fixturePath).readAsStringSync();
        final start = content.indexOf('class _GoodAnimatedBuilderChildReads');
        final end = content.indexOf('class _GoodDisplayWidget');
        expect(start, greaterThan(-1));
        expect(end, greaterThan(start));
        final slice = content.substring(start, end);
        expect(
          slice.contains('// expect_lint: $ruleName'),
          isFalse,
          reason:
              'AnimatedBuilder callback rebuilding child widget should be treated as live',
        );
      },
    );

    test('GOOD child widget build has no expect_lint marker', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf('class _GoodDisplayWidget');
      expect(start, greaterThan(-1));
      final tail = content.substring(start);
      expect(
        tail.contains('// expect_lint: $ruleName'),
        isFalse,
        reason:
            'Child widget .value read fed from listening builder must not be considered inert',
      );
    });
  });
}
