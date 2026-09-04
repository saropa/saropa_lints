// Regression/behavior tests for no_direct_iterable_access.
//
// The rule IS registered — see lib/src/rules/all_rules.dart (export),
// lib/saropa_lints.dart `_allRuleFactories` (NoDirectIterableAccessRule.new),
// and lib/src/tiers.dart (professionalOnlyRules). This test exercises the
// rule class directly via the resolved-rule harness, which runs a single
// rule against inline source without depending on those registration files,
// so it stays fast and isolated regardless of registration state.
library;

import 'package:saropa_lints/src/rules/data/no_direct_iterable_access_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('no_direct_iterable_access', () {
    test('fires on direct index access with a literal index', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
String firstItemLabel(List<String> items) {
  return items[0];
}
''');
      expect(codes, contains('no_direct_iterable_access'));
    });

    test('fires on direct index access with a variable index', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int elementAt(List<int> values, int offset) {
  return values[offset];
}
''');
      expect(codes, contains('no_direct_iterable_access'));
    });

    test('does NOT fire on Map bracket access (edge case 4)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
String? lookup(Map<String, String> map, String key) {
  return map[key];
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire when guarded by an explicit index < list.length check '
        '(edge case 1)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int? guardedElementAt(List<int> values, int index) {
  if (index < values.length) {
    return values[index];
  }
  return null;
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire inside a for loop whose condition bounds the loop '
        'variable (edge case 2)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
void printAll(List<String> items) {
  for (var i = 0; i < items.length; i++) {
    print(items[i]);
  }
}
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a constant index into a constant list literal '
        '(edge case 3)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
const int constantSecond = [1, 2, 3][1];
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a bounds-safe accessor (control)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
String firstItemLabelSafe(List<String> items) {
  return items.firstOrNull ?? '';
}
''');
      expect(codes, isEmpty);
    });

    test('fires on out-of-loop index access even when a similarly named '
        'variable is bounds-checked elsewhere (no false negative from a '
        'mismatched guard)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int unguarded(List<int> values, List<int> other, int index) {
  if (index < other.length) {
    // Guard is on `other`, not `values` — must still fire.
    return values[index];
  }
  return 0;
}
''');
      expect(codes, contains('no_direct_iterable_access'));
    });

    // Issue 1/2: `<=` is not a sufficient bounds guard — `index ==
    // values.length` still throws, so this must still fire.
    test(
      'fires when the only guard uses <= (off-by-one, still unsafe)',
      () async {
        final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int offByOne(List<int> values, int index) {
  if (index <= values.length) {
    return values[index];
  }
  return -1;
}
''');
        expect(codes, contains('no_direct_iterable_access'));
      },
    );

    // Issue 5: reversed comparison operand order, `list.length > index`,
    // is the same guard as `index < list.length`.
    test(
      'does NOT fire when guarded by the reversed list.length > index form',
      () async {
        final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int? guardedElementAt(List<int> values, int index) {
  if (values.length > index) {
    return values[index];
  }
  return null;
}
''');
        expect(codes, isEmpty);
      },
    );

    // Issue 3: the early-return guard-clause idiom — the access sits after,
    // not inside, the guarding `if`.
    test(
      'does NOT fire when guarded by an early-return guard clause',
      () async {
        final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int elementAt(List<int> values, int index) {
  if (index >= values.length) return -1;
  return values[index];
}
''');
        expect(codes, isEmpty);
      },
    );

    // Issue 4: an `else`-branch guard — the access runs only when the
    // unsafe condition was false.
    test('does NOT fire when guarded by an else-branch check', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int elementAt(List<int> values, int index) {
  if (index >= values.length) {
    return -1;
  } else {
    return values[index];
  }
}
''');
      expect(codes, isEmpty);
    });

    // Opportunity: RangeError.checkValidIndex is dart:core's own
    // recommended explicit-validation idiom and should be recognized as a
    // guard.
    test('does NOT fire when guarded by RangeError.checkValidIndex', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int elementAt(List<int> values, int index) {
  RangeError.checkValidIndex(index, values);
  return values[index];
}
''');
      expect(codes, isEmpty);
    });

    // Concern: ForElement (collection-for) was previously unhandled and
    // false-positived on the identical bounded-loop idiom used inside a
    // list literal.
    test('does NOT fire inside a collection-literal for element bounded by '
        'the same condition as ForStatement', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
List<String> copyAll(List<String> items) {
  return [for (var i = 0; i < items.length; i++) items[i]];
}
''');
      expect(codes, isEmpty);
    });

    // FP 1 (critical): `isNotEmpty` is a getter access, never a
    // BinaryExpression, so the old BinaryExpression-only guard predicates
    // never saw it — the single most common bounds-guard idiom in Dart
    // false-positived.
    test('does NOT fire when guarded by isNotEmpty for a [0] access', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int? firstOrDefault(List<int> values) {
  if (values.isNotEmpty) {
    return values[0];
  }
  return null;
}
''');
      expect(codes, isEmpty);
    });

    // FP 1, early-return half: `if (values.isEmpty) return -1;` proves the
    // list is non-empty for every statement after it.
    test('does NOT fire when guarded by an isEmpty early return', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int firstOrDefault(List<int> values) {
  if (values.isEmpty) return -1;
  return values[0];
}
''');
      expect(codes, isEmpty);
    });

    // Near-miss guard rail for the emptiness fix: isNotEmpty only proves
    // length >= 1, so it does NOT make an arbitrary index safe. Accepting it
    // there would suppress a real RangeError.
    test(
      'STILL fires when isNotEmpty guards a non-zero/variable index',
      () async {
        final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int? nth(List<int> values, int index) {
  if (values.isNotEmpty) {
    return values[index];
  }
  return null;
}
''');
        expect(codes, contains('no_direct_iterable_access'));
      },
    );

    // FP 2 (high): ternaries were never walked — only IfStatement/IfElement
    // ancestors were. The expression-bodied guard is idiomatic Dart.
    test('does NOT fire on an isEmpty ternary guard (else branch)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int firstOrDefault(List<int> v) => v.isEmpty ? -1 : v[0];
''');
      expect(codes, isEmpty);
    });

    // FP 2, then-branch half: the comparison form of the same ternary.
    test('does NOT fire on a length > 0 ternary guard (then branch)', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int firstOrDefault(List<int> v) => v.length > 0 ? v[0] : -1;
''');
      expect(codes, isEmpty);
    });

    // Near-miss guard rail for the ternary fix: the branches must not be
    // swapped. Here the access sits in the branch taken when the list IS
    // empty, so it is a genuine crash and must still fire.
    test('STILL fires when the ternary branches are inverted', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
int firstOrDefault(List<int> v) => v.isEmpty ? v[0] : -1;
''');
      expect(codes, contains('no_direct_iterable_access'));
    });

    // FP 3 (high): only ForStatement/ForElement were inspected, so the
    // standard hand-rolled cursor loop false-positived.
    test('does NOT fire inside a while loop bounded by list.length', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
void printAll(List<String> items) {
  var i = 0;
  while (i < items.length) {
    print(items[i]);
    i++;
  }
}
''');
      expect(codes, isEmpty);
    });

    // FP 3, do-while half — accepted deliberately (see the rule's caveat
    // comment: the first iteration is technically unchecked, but a written
    // bound expresses intent and this is a zero-false-positive rule).
    test('does NOT fire inside a do-while bounded by list.length', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
void printAll(List<String> items) {
  var i = 0;
  do {
    print(items[i]);
    i++;
  } while (i < items.length);
}
''');
      expect(codes, isEmpty);
    });

    // Near-miss guard rail for the while fix: a while loop bounded by a
    // DIFFERENT list proves nothing about this access.
    test('STILL fires in a while loop bounded by a different list', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
void printAll(List<String> items, List<String> other) {
  var i = 0;
  while (i < other.length) {
    print(items[i]);
    i++;
  }
}
''');
      expect(codes, contains('no_direct_iterable_access'));
    });

    // Concern: typed-data lists throw the identical RangeError on
    // out-of-bounds `[]` but previously fell outside the exact
    // `isDartCoreList` check.
    test('fires on typed-data list (Uint8List) direct index access', () async {
      final codes = await reportedRuleCodes(NoDirectIterableAccessRule(), '''
import 'dart:typed_data';

int firstByte(Uint8List bytes) {
  return bytes[0];
}
''');
      expect(codes, contains('no_direct_iterable_access'));
    });
  });
}
