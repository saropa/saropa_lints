// Resolved-analyzer regression test for `prefer_static_method`'s bare
// (unprefixed) instance-member access detection
// (see plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md).
//
// The rule previously only recognized an explicit `this.` prefix, so a
// method that reads a field or calls another method via a bare identifier
// (the dominant Dart style) was wrongly flagged as "could be static." This
// pins the fixed detection — including three false-negative regressions
// found while implementing the fix:
//   1. an instance-state-free method calling `.fold(...)` on a LOCAL
//      variable must still lint (`fold`'s element resolves to `List`, an
//      InterfaceElement, even though the receiver isn't `this`);
//   2. same for cascading on a LOCAL variable (cascade sections parse with
//      `target == null`, the same AST shape as a bare call);
//   3. a bare field WRITE (`_field = x`, `_field += x`, `_field++`,
//      `++_field`) must NOT lint — `SimpleIdentifier.element` only resolves
//      a read, so a pure write has a null `.element` and was invisible
//      until the assignment/increment's own `writeElement` was consulted.
// — as a permanent golden-file-style guard against any of these reopening.
library;

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('prefer_static_method — bare instance-member access', () {
    test('does NOT flag a bare field read', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int readBare() => _count;
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });

    test('does NOT flag a bare field WRITE '
        '(regression: SimpleIdentifier.element is null for a pure write '
        'target, unlike a read — must fall back to writeElement)', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  void writeBare() {
    _count = 5;
  }
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });

    test(
      'does NOT flag a bare field increment/decrement/compound-assign',
      () async {
        final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  void incGood() {
    _count++;
  }

  void decGood() {
    --_count;
  }

  void compoundGood() {
    _count += 1;
  }
}
''');
        expect(codes, isNot(contains('prefer_static_method')));
      },
    );

    test('does NOT flag a bare instance-method call', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int _helper() => _count;

  int callsBare() => _helper();
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });

    test('does NOT flag a bare field read inside a nested closure', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int Function() closureGood() {
    return () => _count;
  }
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });

    test('still flags a method with no instance-state access', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int add(int a, int b) => a + b;
}
''');
      expect(codes, contains('prefer_static_method'));
    });

    test('still flags a method whose only calls are on a LOCAL variable '
        '(regression: values.fold(...) resolves to List, an InterfaceElement, '
        'even though the receiver is not `this`)', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int computeLocal(int x, int y) {
    final List<int> values = <int>[x, y];
    return values.fold(0, (int a, int b) => a + b);
  }
}
''');
      expect(codes, contains('prefer_static_method'));
    });

    test('still flags a method whose only calls are cascaded on a LOCAL '
        'variable (regression: cascade sections also parse with '
        'target == null, same AST shape as a bare call)', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  int cascadeLocal(int x, int y) {
    final List<int> values = <int>[]..add(x)..add(y);
    return values.length;
  }
}
''');
      expect(codes, contains('prefer_static_method'));
    });

    test('does NOT flag a cascade on `this`', () async {
      // `_helper` itself must also read instance state here, or its own
      // (correct) true-positive diagnostic would contaminate this
      // assertion — it is scoped to the whole snippet, not just resetGood.
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  void resetGood() {
    this
      .._count = 0
      .._helper();
  }

  void _helper() {
    _count = 0;
  }
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });

    test('does NOT flag explicit this.field access', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Counter {
  int _count = 0;

  void resetGood() {
    this._count = 0;
  }
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });
  });
}
