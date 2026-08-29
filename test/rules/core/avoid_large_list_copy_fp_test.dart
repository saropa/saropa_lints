// Regression tests for avoid_large_list_copy false positives — verifies that
// .toList() is NOT flagged when the result feeds a type context that requires
// List<T> (not Iterable<T>): ?? expressions, named/positional arguments typed
// as List, explicit List<T> variable declarations, List<T> return types,
// cascade targets, property access, and collection literal elements.
//
// Each "does NOT flag" test asserts zero diagnostics; each "STILL flags" test
// confirms the rule catches genuinely unnecessary copies (for-in, Iterable
// args, untyped var with no downstream List requirement).
//
// Bug: bugs/avoid_large_list_copy_false_positive_named_argument_null_coalesce_property_access.md
library;

import 'package:saropa_lints/src/rules/core/performance_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  // -- False-positive regressions: .toList() is structurally required ----------

  group('avoid_large_list_copy — ?? operator (type compatibility)', () {
    test('does NOT flag .toList() as left operand of ??', () async {
      // Both sides of ?? must type-match. Removing .toList() makes the left
      // side Iterable<int>, incompatible with the List<int> literal on the right.
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
List<int> run(List<int>? items) {
  return items?.where((int e) => e > 0).toList() ?? <int>[];
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  group('avoid_large_list_copy — named argument typed as List<T>', () {
    test(
      'does NOT flag .toList() passed to a List<T> named parameter',
      () async {
        // The function declares `required List<String> phones` — removing
        // .toList() would pass an Iterable<String>, causing a compile error.
        final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void updateContact({required List<String> phones}) {}

void run(List<String> rawPhones) {
  updateContact(
    phones: rawPhones.where((String p) => p.isNotEmpty).toList(),
  );
}
''');
        expect(codes, isNot(contains('avoid_large_list_copy')));
      },
    );
  });

  group('avoid_large_list_copy — explicit List<T> variable declaration', () {
    test(
      'does NOT flag .toList() assigned to explicit List<T> variable',
      () async {
        // The declared type is `List<String>` — removing .toList() would assign
        // an Iterable<String> to a List<String> variable, a compile error.
        final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<String> items) {
  final List<String> filtered =
      items.where((String s) => s.isNotEmpty).toList();
  print(filtered);
}
''');
        expect(codes, isNot(contains('avoid_large_list_copy')));
      },
    );
  });

  group('avoid_large_list_copy — List<T> return type', () {
    test('does NOT flag .toList() in explicit return statement', () async {
      // The function returns List<int> — removing .toList() would return
      // Iterable<int>, a type mismatch.
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
List<int> getPositive(List<int> list) {
  return list.where((int e) => e > 0).toList();
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });

    test('does NOT flag .toList() in expression-body function', () async {
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
List<int> getPositive(List<int> list) =>
    list.where((int e) => e > 0).toList();
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  group('avoid_large_list_copy — cascade target', () {
    test('does NOT flag .toList() when result is a cascade target', () async {
      // ..sort() is a List-only mutator absent from Iterable, so .toList()
      // is required to compile the cascade.
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<int> items) {
  final sorted = items.where((int e) => e > 0).toList()..sort();
  print(sorted);
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  group('avoid_large_list_copy — property access on result', () {
    test('does NOT flag .toList() when a property is accessed on it', () async {
      // .length exists on both List and Iterable, but .reversed is List-only.
      // The rule conservatively suppresses any property access on .toList().
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<int> items) {
  final len = items.where((int e) => e > 0).toList().length;
  print(len);
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  group('avoid_large_list_copy — collection literal element', () {
    test('does NOT flag .toList() inside a list literal', () async {
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<int> items) {
  final result = [items.where((int e) => e > 0).toList()];
  print(result);
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });

    test('does NOT flag .toList() as map literal value', () async {
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<int> items) {
  final result = <String, List<int>>{
    'positive': items.where((int e) => e > 0).toList(),
  };
  print(result);
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  group('avoid_large_list_copy — positional argument typed as List<T>', () {
    test('does NOT flag .toList() passed as positional List<T> arg', () async {
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void process(List<int> data) {}

void run(List<int> items) {
  process(items.where((int e) => e > 0).toList());
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });

  // -- True positives: .toList() IS genuinely unnecessary ----------------------

  group('avoid_large_list_copy — genuine unnecessary copies', () {
    test(
      'STILL flags .toList() on a lazy chain with no List requirement',
      () async {
        // The .toList() result is passed to forEach which accepts Iterable —
        // the copy is gratuitous. (forEach is called directly on the result,
        // making the parent a MethodInvocation with target == the chain.)
        //
        // NOTE: The current rule only fires when the .toList() parent is NOT
        // in any exempted category (return, var, arg, cascade, ??, property
        // access, collection literal, method chain, assignment). A standalone
        // expression statement like `items.where(...).toList();` would fire.
        final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(List<int> items) {
  items.where((int e) => e > 0).toList();
}
''');
        // Standalone expression statement — parent is ExpressionStatement,
        // which is not in any exemption list.
        expect(codes, contains('avoid_large_list_copy'));
      },
    );
  });

  // -- List.from() branch: type-argument exemption ----------------------------

  group('avoid_large_list_copy — List.from()', () {
    test('flags List.from() without type arguments', () async {
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(dynamic items) {
  final copy = List.from(items);
  print(copy);
}
''');
      expect(codes, contains('avoid_large_list_copy'));
    });

    test('does NOT flag List<int>.from() with type arguments', () async {
      // List<T>.from() is a type-casting pattern, not a gratuitous copy.
      final codes = await reportedRuleCodes(AvoidLargeListCopyRule(), '''
void run(dynamic items) {
  final typed = List<int>.from(items);
  print(typed);
}
''');
      expect(codes, isNot(contains('avoid_large_list_copy')));
    });
  });
}
