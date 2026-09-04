// Regression/behavior tests for avoid_futureor_return_type.
//
// The rule is not yet wired into the global tier registry (a separate
// process handles the three-way registration centrally to avoid merge
// conflicts across parallel rule-authoring agents). This test therefore
// exercises the rule class directly via the resolved-rule harness, which
// runs a single rule against inline source without depending on
// lib/saropa_lints.dart or lib/src/tiers.dart.
library;

import 'package:saropa_lints/src/rules/core/avoid_futureor_return_type_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_futureor_return_type', () {
    test('fires on a top-level function returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
import 'dart:async';

FutureOr<int> getValue() => 42;
''',
      );
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('fires on a method returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
import 'dart:async';

class Repository {
  FutureOr<String> fetchName() => 'saropa';
}
''',
      );
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('fires on a getter returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
import 'dart:async';

class Repository {
  FutureOr<int> get cachedCount => 3;
}
''',
      );
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('does NOT fire on a plain Future<T> return type', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
Future<int> getValue() async => 42;
''',
      );
      expect(codes, isEmpty);
    });

    test('does NOT fire on a plain sync return type (control)', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
int getValueSync() => 42;
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire on an overriding method — the FutureOr signature is '
      'inherited from the base declaration, which is flagged instead',
      () async {
        final codes = await reportedRuleCodes(
          AvoidFutureorReturnTypeRule(),
          '''
import 'dart:async';

abstract class Base {
  FutureOr<int> compute();
}

class Impl extends Base {
  @override
  FutureOr<int> compute() => 1;
}
''',
        );
        final diags = await runRuleResolved(
          AvoidFutureorReturnTypeRule(),
          '''
import 'dart:async';

abstract class Base {
  FutureOr<int> compute();
}

class Impl extends Base {
  @override
  FutureOr<int> compute() => 1;
}
''',
        );
        // The base declaration (line 4) is flagged; the override (line 9) is not.
        expect(codes, contains('avoid_futureor_return_type'));
        expect(diags.map((d) => d.line), contains(4));
        expect(diags.map((d) => d.line), isNot(contains(9)));
      },
    );

    test('does NOT fire on a setter (no meaningful return type)', () async {
      final codes = await reportedRuleCodes(
        AvoidFutureorReturnTypeRule(),
        '''
class Holder {
  set value(int v) {}
}
''',
      );
      expect(codes, isEmpty);
    });
  });
}
