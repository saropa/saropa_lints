// Validates the resolved-analyzer test oracle itself (test/support/
// resolved_rule_harness.dart): it must actually RUN a rule against resolved
// source, fire on a true positive at the right line, and stay silent on
// compliant code. Uses avoid_redundant_await because its detection depends on
// real type resolution (awaiting a non-Future) using only dart:core/dart:async.
library;

import 'package:saropa_lints/saropa_lints.dart'
    show
        RuleLane,
        activeRuleLane,
        ensureRuleRegistryBuilt,
        ruleAllowedByLane,
        setActiveRuleLane;
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

    test('is not gated by the light lane once the registry is built', () async {
      // Regression: the light-lane membership set is filled lazily the first
      // time the rule registry is built (e.g. by report/summary code running
      // mid-suite), and the default lane is `light`. A rule outside the lane
      // (any type-resolving rule) then became a silent no-op for every later
      // harness run, so positive tests failed with an empty result set only
      // when that build happened to land first. The oracle must always run
      // the rule at full fidelity.
      ensureRuleRegistryBuilt();
      final originalLane = activeRuleLane;
      addTearDown(() => setActiveRuleLane(originalLane));
      setActiveRuleLane(RuleLane.light);
      final diags = await runRuleResolved(AvoidRedundantAwaitRule(), '''
Future<void> f() async {
  await 42;
}
''');
      expect(diags.map((d) => d.ruleName), contains('avoid_redundant_await'));
      // The harness override must not leak: the caller's lane is restored.
      expect(activeRuleLane, RuleLane.light);
      setActiveRuleLane(RuleLane.full);
      expect(ruleAllowedByLane('avoid_redundant_await'), isTrue);
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
