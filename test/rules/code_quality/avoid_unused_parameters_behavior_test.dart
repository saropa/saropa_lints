// Behavioral test for AvoidUnusedParametersRule: verifies the rule fires on
// concrete unused parameters and stays silent on abstract/external/native/
// override method declarations where parameters define a contract, not usage.
//
// Uses the resolved rule harness so type resolution (usesTypeResolution=true)
// is available — matching the real analyzer pipeline.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('AvoidUnusedParametersRule behavior', () {
    late AvoidUnusedParametersRule rule;

    setUp(() {
      rule = AvoidUnusedParametersRule();
    });

    // --- True positives: the rule MUST fire ---

    test('fires on concrete function with unused parameter', () async {
      final diags = await runRuleResolved(rule, '''
void process(String data, int count) {
  print(data);
}
''');
      // `count` is unused — should fire on line 1 (the param declaration).
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'avoid_unused_parameters');
    });

    test('fires on concrete method with unused parameter', () async {
      final diags = await runRuleResolved(rule, '''
class Service {
  void execute(String command, int timeout) {
    print(command);
  }
}
''');
      // `timeout` is unused — exactly one diagnostic.
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'avoid_unused_parameters');
    });

    // --- True negatives: the rule must NOT fire ---

    test('silent on abstract interface class methods (#319)', () async {
      // Exact pattern from the GitHub issue reporter.
      final diags = await runRuleResolved(rule, '''
abstract interface class NoteRepo {
  Future<void> get({
    required String id,
    required String? userId,
    required bool markViewed,
  });
}
''');
      expect(
        diags,
        isEmpty,
        reason: 'abstract methods have no body to use params in',
      );
    });

    test('silent on abstract class methods', () async {
      final diags = await runRuleResolved(rule, '''
abstract class BaseService {
  void execute(String command, int timeout);
}
''');
      expect(
        diags,
        isEmpty,
        reason: 'abstract methods define contracts, not usage',
      );
    });

    test('silent on external methods', () async {
      final diags = await runRuleResolved(rule, '''
class NativeHelper {
  external void compute(int value);
}
''');
      expect(
        diags,
        isEmpty,
        reason: 'external methods have no implementation body',
      );
    });

    test('silent on override methods', () async {
      // Override params may be required by the interface — existing guard.
      final diags = await runRuleResolved(rule, '''
class Base {
  void run(int x) {}
}
class Sub extends Base {
  @override
  void run(int x) {}
}
''');
      // The override in Sub should not fire. Base.run has an empty body with
      // an unused param, so Base.run fires but Sub.run must not.
      final subDiags = diags.where((d) => d.line > 4).toList();
      expect(subDiags, isEmpty, reason: '@override methods are skipped');
    });

    test('silent on underscore-prefixed parameters', () async {
      // Intentionally unused params prefixed with _ are exempt.
      final diags = await runRuleResolved(rule, '''
void process(String data, int _count) {
  print(data);
}
''');
      expect(
        diags,
        isEmpty,
        reason: 'underscore-prefixed params are intentionally unused',
      );
    });

    test('silent when all parameters are used', () async {
      final diags = await runRuleResolved(rule, '''
void process(String data, int count) {
  print('\$data x \$count');
}
''');
      expect(diags, isEmpty, reason: 'all params referenced in body');
    });

    test('silent on expression-body function with all params used', () async {
      // Ensures ExpressionFunctionBody is correctly treated as implementation.
      final diags = await runRuleResolved(rule, '''
int add(int a, int b) => a + b;
''');
      expect(diags, isEmpty);
    });

    test('fires on expression-body function with unused param', () async {
      // Ensures ExpressionFunctionBody still checks for unused params.
      final diags = await runRuleResolved(rule, '''
int identity(int a, int b) => a;
''');
      // `b` is unused.
      expect(diags, hasLength(1));
    });
  });
}
