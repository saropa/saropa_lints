// Oracle-backed regression tests for `avoid_recursive_calls`.
//
// Guards the base-case fix for the false positive where the rule flagged every
// direct self-call, including correct, idiomatic recursion with a terminating
// base case (guard-clause-then-recurse, divide-and-conquer, ternary base case,
// and loop-bounded structural walks of finite data). The rule must report only
// recursion with no detected base case. See
// bugs/avoid_recursive_calls_false_positive_bounded_structural_recursion.md.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _rule = 'avoid_recursive_calls';

void main() {
  group('avoid_recursive_calls base-case guard', () {
    test('LINT: unguarded expression-body self-call', () async {
      const String code = '''
int badFactorial(int n) => n * badFactorial(n - 1);
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, contains(_rule));
    });

    test('LINT: unguarded block-body self-call', () async {
      const String code = '''
int badFactorial(int n) {
  return n * badFactorial(n - 1);
}
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, contains(_rule));
    });

    test('NO lint: guard clause returns before recursing', () async {
      const String code = '''
int goodFactorial(int n) {
  if (n <= 1) return 1;
  return n * goodFactorial(n - 1);
}
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: ternary whose other branch is the base case', () async {
      const String code = '''
int goodFactorial(int n) => n <= 1 ? 1 : n * goodFactorial(n - 1);
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: bounded JSON walk with type-check base cases', () async {
      const String code = '''
Object? normalizeJsonValue(Object? value) {
  if (value == null || value is bool || value is num) return value;
  if (value is String) return value;
  if (value is List) {
    return value
        .map((e) => normalizeJsonValue(e as Object?))
        .toList(growable: false);
  }
  if (value is Map) {
    final out = <String, Object?>{};
    for (final e in value.entries) {
      out['\${e.key}'] = normalizeJsonValue(e.value as Object?);
    }
    return out;
  }
  return '[unsupported]';
}
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: tree walk recurses only inside a loop', () async {
      const String code = '''
class TreeNode {
  TreeNode(this.children);
  final List<TreeNode> children;
}

int countNodes(TreeNode node) {
  int total = 1;
  for (final TreeNode child in node.children) {
    total += countNodes(child);
  }
  return total;
}
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: divide-and-conquer with a size guard', () async {
      const String code = '''
void quicksortRange(List<int> data, int lo, int hi) {
  if (lo >= hi) return;
  final int mid = (lo + hi) ~/ 2;
  quicksortRange(data, lo, mid);
  quicksortRange(data, mid + 1, hi);
}
''';
      final codes = await reportedRuleCodes(AvoidRecursiveCallsRule(), code);
      expect(codes, isNot(contains(_rule)));
    });
  });
}
