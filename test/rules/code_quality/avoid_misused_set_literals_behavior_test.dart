// Behavioral test for AvoidMisusedSetLiteralsRule: verifies the rule fires
// only on empty `{}` literals with NO written `Map` annotation AND no other
// typing context — the resolved type is structurally dart:core `Map` with
// both type arguments `dynamic`, Dart's hardcoded default when nothing else
// disambiguates the literal (e.g. `var x = {};`) — and stays silent when
// EITHER the enclosing variable has a written `Map` annotation (even a raw
// `Map`, or a typedef alias for one, or a nullable `Map<dynamic, dynamic>?`)
// OR the literal sits in any position that supplies a real context type
// (argument, named argument, default value, return, map-value slot, index
// assignment, `??` operand, ...).
//
// See bugs/avoid_misused_set_literals_false_positive_explicit_map_declared_type.md
// for the false-positive report this test guards against, and its Finish
// Report for why the fix combines a written-Map-annotation check with a
// structural (not display-string) check of the literal's resolved type.
//
// Uses the resolved rule harness so type resolution (usesTypeResolution=true)
// is available — matching the real analyzer pipeline.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('AvoidMisusedSetLiteralsRule behavior', () {
    late AvoidMisusedSetLiteralsRule rule;

    setUp(() {
      rule = AvoidMisusedSetLiteralsRule();
    });

    // --- True positives: the rule MUST fire ---

    test('fires on `var x = {};` with no declared type', () async {
      final diags = await runRuleResolved(rule, '''
void f() {
  var x = {};
  print(x);
}
''');
      expect(diags, hasLength(1));
      expect(diags.first.ruleName, 'avoid_misused_set_literals');
    });

    test('fires on dynamic-typed field assigned `{}`', () async {
      final diags = await runRuleResolved(rule, '''
class C {
  dynamic field;
  void f() {
    field = {};
  }
}
''');
      expect(diags, hasLength(1));
    });

    // --- True negatives: the rule must NOT fire ---

    test(
      'silent on `final Map<K, V> x = {};` (explicit declared Map type)',
      () async {
        // Exact reproducer shape from the bug report: the declared type
        // already resolves `{}` unambiguously as a Map.
        final diags = await runRuleResolved(rule, '''
class Example {
  final Map<String, int> cache = {};
}
''');
        expect(
          diags,
          isEmpty,
          reason:
              'explicit declared Map<K, V> type makes {} unambiguous - not a misuse',
        );
      },
    );

    test('silent on local `final Map<K, V> x = {};`', () async {
      final diags = await runRuleResolved(rule, '''
void f() {
  final Map<String, int> cache = {};
  print(cache);
}
''');
      expect(diags, isEmpty);
    });

    test('silent on explicit declared `Set<T> x = {};`', () async {
      final diags = await runRuleResolved(rule, '''
class Example {
  final Set<String> tags = {};
}
''');
      expect(diags, isEmpty);
    });

    test(
      'silent on assignment to a field declared with an explicit type',
      () async {
        // Context type from the field's declared type, not the assignment
        // site — the fix's declared-type lookup must cover this too.
        final diags = await runRuleResolved(rule, '''
class Example {
  Map<String, int> field = <String, int>{};

  void reset() {
    field = {};
  }
}
''');
        expect(diags, isEmpty);
      },
    );

    test(
      'silent on explicit type-argument literal `<String, int>{}`',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  var map = <String, int>{};
  print(map);
}
''');
        expect(diags, isEmpty);
      },
    );

    test('silent on non-empty set literal', () async {
      final diags = await runRuleResolved(rule, '''
void f() {
  var items = {1, 2, 3};
  print(items);
}
''');
      expect(diags, isEmpty);
    });

    // --- Position-agnostic coverage (Opus review follow-up) ---
    //
    // The fix reads `node.staticType` directly rather than walking specific
    // AST parent shapes, so every position below that supplies a context
    // type must be silent without any special-casing.

    test('silent on `{}` passed as a positional argument', () async {
      final diags = await runRuleResolved(rule, '''
void g(Map<String, int> m) {}
void f() {
  g({});
}
''');
      expect(diags, isEmpty, reason: 'parameter type is the context type');
    });

    test('silent on `{}` passed as a named argument', () async {
      final diags = await runRuleResolved(rule, '''
void n({required Map<String, int> headers}) {}
void f() {
  n(headers: {});
}
''');
      expect(diags, isEmpty);
    });

    test('silent on `{}` as a parameter default value', () async {
      final diags = await runRuleResolved(rule, '''
void f({Map<String, int> m = const {}}) {}
''');
      expect(diags, isEmpty);
    });

    test('silent on `return {};` from a Map-returning function', () async {
      final diags = await runRuleResolved(rule, '''
Map<String, int> f() {
  return {};
}
''');
      expect(diags, isEmpty);
    });

    test(
      'silent on nested `{}` as a value inside an explicitly typed map',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  final Map<String, Map<String, int>> outer = {'a': {}};
  print(outer);
}
''');
        expect(
          diags,
          isEmpty,
          reason: "inner {} context type comes from outer's value type",
        );
      },
    );

    test('silent on `mm[\'k\'] = {};` index assignment', () async {
      final diags = await runRuleResolved(rule, '''
void f(Map<String, Map<String, int>> mm) {
  mm['k'] = {};
}
''');
      expect(diags, isEmpty);
    });

    test('silent on `{}` as the right operand of `??`', () async {
      final diags = await runRuleResolved(rule, '''
void f(Map<String, int>? maybe) {
  Map<String, int> m = maybe ?? {};
  print(m);
}
''');
      expect(diags, isEmpty);
    });

    test(
      'silent on explicit `Iterable<int> d = {};` (resolves as Set)',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  Iterable<int> d = {};
  print(d);
}
''');
        expect(
          diags,
          isEmpty,
          reason: 'Iterable context resolves {} as an explicit Set<int>',
        );
      },
    );

    // --- Written `Map` annotation always answers "did you mean Set?"
    // (2nd Opus review follow-up) ---
    //
    // A written `Map` annotation on the enclosing variable disambiguates
    // `{}` for the reader even when it resolves structurally to
    // `Map<dynamic, dynamic>` (raw `Map`, or a typedef alias for one, or
    // a nullable `Map<dynamic, dynamic>?`) — the diagnostic's own text
    // ("without type annotation") would be factually wrong to fire there.
    // `dynamic`/`Object`, which are not `Map` annotations, must still fire.

    test('silent on `final Map raw = {};` (raw Map annotation)', () async {
      final diags = await runRuleResolved(rule, '''
void f() {
  final Map raw = {};
  print(raw);
}
''');
      expect(
        diags,
        isEmpty,
        reason:
            'a written (even raw) Map annotation already answers '
            '"did you mean Set?"',
      );
    });

    test(
      'silent on `final Raw r = {};` where `Raw` is a typedef for `Map<dynamic, dynamic>`',
      () async {
        final diags = await runRuleResolved(rule, '''
typedef Raw = Map<dynamic, dynamic>;

void f() {
  final Raw r = {};
  print(r);
}
''');
        expect(
          diags,
          isEmpty,
          reason: 'the element type resolves the typedef structurally to Map',
        );
      },
    );

    test(
      'silent on `Map<dynamic, dynamic>? m = {};` (nullable Map annotation)',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  Map<dynamic, dynamic>? m = {};
  print(m);
}
''');
        expect(diags, isEmpty);
      },
    );

    test(
      'fires on `dynamic d = {};` (dynamic is not a Map annotation)',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  dynamic d = {};
  print(d);
}
''');
        expect(diags, hasLength(1));
      },
    );

    test(
      'fires on `Object o = {};` (Object is not a Map annotation)',
      () async {
        final diags = await runRuleResolved(rule, '''
void f() {
  Object o = {};
  print(o);
}
''');
        expect(diags, hasLength(1));
      },
    );
  });
}
