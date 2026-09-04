// Regression/behavior tests for no_direct_iterable_access.
//
// The rule is not yet wired into the global tier registry (a separate
// process handles the three-way registration centrally to avoid merge
// conflicts across parallel rule-authoring agents). This test therefore
// exercises the rule class directly via the resolved-rule harness, which
// runs a single rule against inline source without depending on
// lib/saropa_lints.dart or lib/src/tiers.dart.
library;

import 'package:saropa_lints/src/rules/data/no_direct_iterable_access_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('no_direct_iterable_access', () {
    test('fires on direct index access with a literal index', () async {
      final codes = await reportedRuleCodes(
        NoDirectIterableAccessRule(),
        '''
String firstItemLabel(List<String> items) {
  return items[0];
}
''',
      );
      expect(codes, contains('no_direct_iterable_access'));
    });

    test('fires on direct index access with a variable index', () async {
      final codes = await reportedRuleCodes(
        NoDirectIterableAccessRule(),
        '''
int elementAt(List<int> values, int offset) {
  return values[offset];
}
''',
      );
      expect(codes, contains('no_direct_iterable_access'));
    });

    test('does NOT fire on Map bracket access (edge case 4)', () async {
      final codes = await reportedRuleCodes(
        NoDirectIterableAccessRule(),
        '''
String? lookup(Map<String, String> map, String key) {
  return map[key];
}
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when guarded by an explicit index < list.length check '
      '(edge case 1)',
      () async {
        final codes = await reportedRuleCodes(
          NoDirectIterableAccessRule(),
          '''
int? guardedElementAt(List<int> values, int index) {
  if (index < values.length) {
    return values[index];
  }
  return null;
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire inside a for loop whose condition bounds the loop '
      'variable (edge case 2)',
      () async {
        final codes = await reportedRuleCodes(
          NoDirectIterableAccessRule(),
          '''
void printAll(List<String> items) {
  for (var i = 0; i < items.length; i++) {
    print(items[i]);
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );

    test(
      'does NOT fire on a constant index into a constant list literal '
      '(edge case 3)',
      () async {
        final codes = await reportedRuleCodes(
          NoDirectIterableAccessRule(),
          '''
const int constantSecond = [1, 2, 3][1];
''',
        );
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on a bounds-safe accessor (control)', () async {
      final codes = await reportedRuleCodes(
        NoDirectIterableAccessRule(),
        '''
String firstItemLabelSafe(List<String> items) {
  return items.firstOrNull ?? '';
}
''',
      );
      expect(codes, isEmpty);
    });

    test(
      'fires on out-of-loop index access even when a similarly named '
      'variable is bounds-checked elsewhere (no false negative from a '
      'mismatched guard)',
      () async {
        final codes = await reportedRuleCodes(
          NoDirectIterableAccessRule(),
          '''
int unguarded(List<int> values, List<int> other, int index) {
  if (index < other.length) {
    // Guard is on `other`, not `values` — must still fire.
    return values[index];
  }
  return 0;
}
''',
        );
        expect(codes, contains('no_direct_iterable_access'));
      },
    );
  });
}
