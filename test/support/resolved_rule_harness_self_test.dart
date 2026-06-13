// Validates the resolved-analyzer test oracle itself (test/support/
// resolved_rule_harness.dart): it must actually RUN a rule against resolved
// source, fire on a true positive at the right line, and stay silent on
// compliant code. Uses avoid_redundant_await because its detection depends on
// real type resolution (awaiting a non-Future) using only dart:core/dart:async.
library;

import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:test/test.dart';

import 'resolved_rule_harness.dart';

void main() {
  group('resolved rule harness', () {
    test('fires on a true positive (await of a non-Future int)', () async {
      final diags = await runRuleResolved(AvoidRedundantAwaitRule(), '''
Future<void> f() async {
  await 42;
}
''');
      expect(diags.map((d) => d.ruleName), contains('avoid_redundant_await'));
      // The `await 42;` is on line 2 of the fixture.
      expect(diags.first.line, 2);
    });

    test('stays silent on compliant code (awaiting a real Future)', () async {
      final diags = await runRuleResolved(AvoidRedundantAwaitRule(), '''
Future<void> g() async {
  await Future<void>.value();
}
''');
      expect(diags, isEmpty);
    });
  });
}
