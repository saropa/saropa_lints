import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  const ruleName = 'avoid_nested_scrollables_conflict';
  const fixturePath =
      'example/lib/scroll/avoid_nested_scrollables_conflict_fixture.dart';

  group('avoid_nested_scrollables_conflict cross-axis nesting', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('fixture exists', () {
      expect(File(fixturePath).existsSync(), isTrue);
    });

    test('cross-axis vertical outer + horizontal inner has no expect_lint', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf(
        'class FixtureCrossAxisVerticalOuterHorizontalInner',
      );
      final end = content.indexOf(
        'class FixtureCrossAxisPageViewOuterVerticalListInner',
      );
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(
        slice.contains('// expect_lint: $ruleName'),
        isFalse,
        reason: 'Cross-axis nesting should not be reported',
      );
    });

    test('PageView outer + vertical ListView has no expect_lint', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf(
        'class FixtureCrossAxisPageViewOuterVerticalListInner',
      );
      final end = content.indexOf('class FixtureSameAxisHorizontalNested');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(slice.contains('// expect_lint: $ruleName'), isFalse);
    });

    test('same-axis horizontal nested inner is marked expect_lint', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf('class FixtureSameAxisHorizontalNested');
      final end = content.indexOf('class FixtureSameAxisVerticalNested');
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(slice.contains('// expect_lint: $ruleName'), isTrue);
    });

    test('same-axis vertical nested inner is marked expect_lint', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf('class FixtureSameAxisVerticalNested');
      final end = content.indexOf(
        'class FixtureCrossAxisInnerHasExplicitPhysics',
      );
      expect(start, greaterThan(-1));
      expect(end, greaterThan(start));
      final slice = content.substring(start, end);
      expect(slice.contains('// expect_lint: $ruleName'), isTrue);
    });

    test('cross-axis with explicit inner physics has no expect_lint', () {
      final content = File(fixturePath).readAsStringSync();
      final start = content.indexOf(
        'class FixtureCrossAxisInnerHasExplicitPhysics',
      );
      expect(start, greaterThan(-1));
      final slice = content.substring(start);
      expect(slice.contains('// expect_lint: $ruleName'), isFalse);
    });
  });
}
