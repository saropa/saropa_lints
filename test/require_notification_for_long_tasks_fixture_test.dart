import 'dart:io';

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Registration and fixture-shape tests for `require_notification_for_long_tasks`.
/// Behavioral matching is covered by `longOperationMethodNameMatchesPattern` tests
/// and `example/lib/ios/require_notification_for_long_tasks*_fixture.dart`.
void main() {
  const ruleName = 'require_notification_for_long_tasks';

  group('RequireNotificationForLongTasksRule fixtures', () {
    test('is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('getRulesFromRegistry resolves the rule when asked by name', () {
      final rules = getRulesFromRegistry(<String>{ruleName});
      expect(rules, hasLength(1));
      expect(rules.single.code.lowerCaseName, ruleName);
    });

    test('BAD fixture declares three expect_lint markers', () {
      final file = File('example/lib/ios/${ruleName}_fixture.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      final markerCount = '// expect_lint: $ruleName'
          .allMatches(content)
          .length;
      expect(markerCount, equals(3));
    });

    test('boundary and no-lint fixtures have no expect_lint for this rule', () {
      for (final suffix in <String>[
        '${ruleName}_boundary_ok_fixture.dart',
        '${ruleName}_no_lint_fixture.dart',
      ]) {
        final file = File('example/lib/ios/$suffix');
        expect(file.existsSync(), isTrue, reason: suffix);
        final content = file.readAsStringSync();
        expect(
          content.contains('// expect_lint: $ruleName'),
          isFalse,
          reason: '$suffix must not assert diagnostics',
        );
      }
    });
  });
}
