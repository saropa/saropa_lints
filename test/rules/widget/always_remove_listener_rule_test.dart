import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Behavioral notes and fixture contracts for [AlwaysRemoveListenerRule].
void main() {
  const ruleName = 'always_remove_listener';

  group('AlwaysRemoveListenerRule', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('fixture: BAD case declares expect_lint', () {
      final file = File(
        'example/lib/widget_lifecycle/${ruleName}_fixture.dart',
      );
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('// expect_lint: $ruleName'), isTrue);
    });

    test('fixture: GOOD block has no expect_lint', () {
      final content = File(
        'example/lib/widget_lifecycle/${ruleName}_fixture.dart',
      ).readAsStringSync();
      const goodMarker = '// GOOD: Should NOT trigger always_remove_listener';
      final start = content.indexOf(goodMarker);
      expect(
        start,
        greaterThan(-1),
        reason: 'GOOD marker missing from fixture',
      );
      final goodBlock = content.substring(start);
      expect(
        goodBlock.contains('expect_lint: $ruleName'),
        isFalse,
        reason: 'GOOD block must not declare expect_lint',
      );
    });

    test('problem message documents rule version tag', () {
      final rule = getRulesFromRegistry(<String>{ruleName}).single;
      expect(rule.code.problemMessage, matches(RegExp(r'\{v\d+\}')));
    });
  });
}
