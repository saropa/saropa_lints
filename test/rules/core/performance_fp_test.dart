// Regression tests for two performance-rule false positives, verified against
// resolved source via the oracle harness:
//
//  1. prefer_cached_getter flagged ANY property/prefixed-identifier read seen
//     more than once (keyed by toSource), with no notion of "expensive" — a
//     plain field read twice, an enum `.value`, etc. all fired even though the
//     rule's name/message is about EXPENSIVE getters. The fix only flags
//     repeated reads that resolve to an explicitly-declared (non-synthetic)
//     `get` accessor; a field's implicit getter is synthetic and free.
//
//  2. avoid_string_concatenation_loop's `+=` branch flagged `x += y` based only
//     on a variable-NAME heuristic (name contains result/output/buffer/message)
//     with no operand-type check — so numeric `total += count` (var named to
//     match) was falsely flagged as O(n^2) string concat. The fix requires the
//     `+=` target to actually be a String via staticType, like the `+` branch.
library;

import 'package:saropa_lints/src/rules/core/performance_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('prefer_cached_getter', () {
    test('does NOT flag a plain field read twice (synthetic getter, free)',
        () async {
      final codes = await reportedRuleCodes(PreferCachedGetterRule(), '''
class Holder {
  final int count = 0;
}

class C {
  final Holder widget = Holder();

  int run() {
    // `widget.count` is a plain field read — its getter is synthetic and free,
    // so repeating it must NOT be flagged as an expensive recompute.
    return widget.count + widget.count;
  }
}
''');
      expect(codes, isNot(contains('prefer_cached_getter')));
    });

    test('does NOT flag a plain field read twice via PropertyAccess', () async {
      // `(this.holder).count` parses as a PropertyAccess (not PrefixedIdentifier),
      // exercising the other collector branch. `count` is still a plain field
      // (synthetic getter), so it must not be flagged.
      final codes = await reportedRuleCodes(PreferCachedGetterRule(), '''
class Holder {
  final int count = 0;
}

class C {
  final Holder holder = Holder();

  int run() {
    return (this.holder).count + (this.holder).count;
  }
}
''');
      expect(codes, isNot(contains('prefer_cached_getter')));
    });

    test('STILL flags a real declared getter read twice', () async {
      final diags = await runRuleResolved(PreferCachedGetterRule(), '''
class Holder {
  int get expensiveCalculation {
    var sum = 0;
    for (var i = 0; i < 1000; i++) {
      sum += i;
    }
    return sum;
  }
}

class C {
  final Holder widget = Holder();

  int run() {
    final a = widget.expensiveCalculation;
    final b = widget.expensiveCalculation;
    return a + b;
  }
}
''');
      expect(diags.map((d) => d.ruleName), contains('prefer_cached_getter'));
    });
  });

  group('avoid_string_concatenation_loop', () {
    test('does NOT flag numeric += on a result-named var in a loop', () async {
      final codes =
          await reportedRuleCodes(AvoidStringConcatenationLoopRule(), '''
int sum(List<int> items) {
  var result = 0; // name matches the old heuristic but type is int
  for (final n in items) {
    result += n;
  }
  return result;
}
''');
      expect(codes, isNot(contains('avoid_string_concatenation_loop')));
    });

    test('does NOT flag numeric += on a total var in a loop', () async {
      final codes =
          await reportedRuleCodes(AvoidStringConcatenationLoopRule(), '''
int run(List<int> items) {
  var message = 0; // 'message' matches old heuristic; type is int
  for (final n in items) {
    message += n;
  }
  return message;
}
''');
      expect(codes, isNot(contains('avoid_string_concatenation_loop')));
    });

    test('STILL flags genuine String += in a loop', () async {
      final codes =
          await reportedRuleCodes(AvoidStringConcatenationLoopRule(), '''
String build(List<String> items) {
  var result = '';
  for (final s in items) {
    result += s;
  }
  return result;
}
''');
      expect(codes, contains('avoid_string_concatenation_loop'));
    });
  });
}
