// Regression test for an always_specify_parameter_names false positive,
// verified against resolved source via the oracle harness:
//
// The rule's correctionMessage tells the developer to redeclare the flagged
// parameters as named — advice that only makes sense when the caller owns
// the callee's declaration. SDK methods like `String.substring(int start,
// [int? end])` and `Pattern.replaceAll(Pattern from, String replace)` are
// positional-only by design and the declaration can never be changed by any
// caller, so the rule fired on every 2+ consecutive positional call to such
// SDK methods even though its own suggested fix is inapplicable. The fix
// skips invocations whose target element resolves to an SDK library.
//
// See bugs/always_specify_parameter_names_false_positive_dart_core_positional_only_methods.md
library;

import 'package:saropa_lints/src/rules/code_quality/always_specify_parameter_names_rule.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('always_specify_parameter_names', () {
    test(
      'does NOT flag String.substring (dart:core, positional-only)',
      () async {
        final codes = await reportedRuleCodes(
          AlwaysSpecifyParameterNamesRule(),
          '''
void demo(String stmt) {
  final String preview = stmt.substring(0, 10);
}
''',
        );
        expect(codes, isNot(contains('always_specify_parameter_names')));
      },
    );

    test(
      'does NOT flag Pattern.replaceAll (dart:core, positional-only)',
      () async {
        final codes = await reportedRuleCodes(
          AlwaysSpecifyParameterNamesRule(),
          '''
void demo(String stmt) {
  final String escaped = stmt.replaceAll('"', '""');
}
''',
        );
        expect(codes, isNot(contains('always_specify_parameter_names')));
      },
    );

    test('still flags a user-defined function with 2+ named-capable positional '
        'params of the same type', () async {
      final codes = await reportedRuleCodes(
        AlwaysSpecifyParameterNamesRule(),
        '''
void createUser(String firstName, String lastName) {}

void demo() {
  createUser('Smith', 'John');
}
''',
      );
      expect(codes, contains('always_specify_parameter_names'));
    });
  });
}
