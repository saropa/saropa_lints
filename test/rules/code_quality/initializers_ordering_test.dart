// Oracle-backed tests for `initializers_ordering`.
//
// Verifies the rule flags a constructor initializer list whose field
// assignments are ordered differently from the field-declaration order in
// the enclosing class or enum body, and stays silent on: matching order,
// asserts interleaved between correctly-ordered assignments, super()/this()
// redirect calls, lists with fewer than two field-initializer entries, and a
// `this.x` shorthand parameter mixed with correctly-ordered explicit
// entries (also confirms the shorthand field's position does not shield an
// out-of-order pair among the remaining explicit entries).
library;

import 'package:saropa_lints/src/rules/code_quality/initializers_ordering_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _rule = 'initializers_ordering';

void main() {
  group('initializers_ordering', () {
    test('LINT: two-field initializer list out of declaration order', () async {
      const String code = '''
class Point {
  Point(int a, int b) : y = b, x = a;
  final int x;
  final int y;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, contains(_rule));
    });

    test('LINT: regression partway through a three-field list', () async {
      const String code = '''
class ThreeFields {
  ThreeFields(int a, int b, int c) : a = a, c = c, b = b;
  final int a;
  final int b;
  final int c;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, contains(_rule));
    });

    test('NO lint: initializer list matches declaration order', () async {
      const String code = '''
class Point {
  Point(int a, int b) : x = a, y = b;
  final int x;
  final int y;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: assert() interleaved between correctly-ordered fields', () async {
      const String code = '''
class AssertBetween {
  AssertBetween(int a, int b)
      : assert(a >= 0),
        x = a,
        assert(b >= 0),
        y = b;
  final int x;
  final int y;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: super() redirect excluded from ordering comparison', () async {
      const String code = '''
class Base {
  Base(this.label);
  final String label;
}

class RedirectingSuper extends Base {
  RedirectingSuper(int a, int b, String label)
      : x = a,
        y = b,
        super(label);
  final int x;
  final int y;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test('NO lint: single field initializer has nothing to compare', () async {
      const String code = '''
class SingleInitializer {
  SingleInitializer(int a) : x = a;
  final int x;
  final int y = 0;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, isNot(contains(_rule)));
    });

    test(
      'NO lint: this.x shorthand plus correctly-ordered explicit entries',
      () async {
        const String code = '''
class ThisShorthandOk {
  ThisShorthandOk(this.x, int b, int c) : y = b, z = c;
  final int x;
  final int y;
  final int z;
}
''';
        final codes = await reportedRuleCodes(
          InitializersOrderingRule(),
          code,
        );
        expect(codes, isNot(contains(_rule)));
      },
    );

    test(
      'LINT: this.x shorthand does not shield out-of-order explicit entries',
      () async {
        const String code = '''
class ThisShorthandBad {
  ThisShorthandBad(this.x, int b, int c) : z = c, y = b;
  final int x;
  final int y;
  final int z;
}
''';
        final codes = await reportedRuleCodes(
          InitializersOrderingRule(),
          code,
        );
        expect(codes, contains(_rule));
      },
    );

    test('LINT: enum const constructor out of declaration order', () async {
      const String code = '''
enum EnumBad {
  a(1, 'one'),
  b(2, 'two');

  const EnumBad(int code, String label) : label = label, code = code;
  final int code;
  final String label;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, contains(_rule));
    });

    test('NO lint: enum const constructor matches declaration order', () async {
      const String code = '''
enum EnumOk {
  a(1, 'one'),
  b(2, 'two');

  const EnumOk(int code, String label) : code = code, label = label;
  final int code;
  final String label;
}
''';
      final codes = await reportedRuleCodes(InitializersOrderingRule(), code);
      expect(codes, isNot(contains(_rule)));
    });
  });
}
