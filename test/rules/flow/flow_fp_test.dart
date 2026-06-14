// False-positive regression tests for two flow lint rules, executed against a
// FULLY RESOLVED unit so element/library checks are exercised the way they run
// in production. Metadata-only instantiation tests cannot catch these because
// the bugs are in element-resolution branches.
library;

import 'package:saropa_lints/src/rules/flow/control_flow_rules.dart';
import 'package:saropa_lints/src/rules/flow/error_handling_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('handle_throwing_invocations — over-broad dart:io catch-all', () {
    // BUG: the final clause `return uri.startsWith('dart:io') || ...` flagged
    // ANY dart:io element whose simple name happened to be in the thrower set,
    // regardless of whether it was one of the documented read*/write* sync I/O
    // calls. `SystemEncoding.decode` (the `systemEncoding` const in dart:io) is
    // named `decode` but is NOT a documented throwing I/O call.
    test('does NOT flag systemEncoding.decode (dart:io, not a read/write)',
        () async {
      const code = '''
import 'dart:io';

void main() {
  final List<int> bytes = <int>[104, 105];
  final String s = systemEncoding.decode(bytes);
  print(s);
}
''';
      final codes = await reportedRuleCodes(
        HandleThrowingInvocationsRule(),
        code,
      );
      expect(
        codes.contains('handle_throwing_invocations'),
        isFalse,
        reason:
            'systemEncoding.decode is a dart:io element named `decode` but is '
            'not a documented read/write throwing call; the catch-all OR must '
            'not flag it.',
      );
    });

    // The documented positive cases must still fire after collapsing the OR.
    test('still flags File.readAsStringSync (documented dart:io thrower)',
        () async {
      const code = '''
import 'dart:io';

void main() {
  final String s = File('config.json').readAsStringSync();
  print(s);
}
''';
      final codes = await reportedRuleCodes(
        HandleThrowingInvocationsRule(),
        code,
      );
      expect(codes.contains('handle_throwing_invocations'), isTrue);
    });

    test('still flags int.parse (documented dart:core thrower)', () async {
      const code = '''
void main() {
  final int n = int.parse('123');
  print(n);
}
''';
      final codes = await reportedRuleCodes(
        HandleThrowingInvocationsRule(),
        code,
      );
      expect(codes.contains('handle_throwing_invocations'), isTrue);
    });

    test('still flags jsonDecode (documented dart:convert thrower)', () async {
      const code = '''
import 'dart:convert';

void main() {
  final Object? v = jsonDecode('{}');
  print(v);
}
''';
      final codes = await reportedRuleCodes(
        HandleThrowingInvocationsRule(),
        code,
      );
      expect(codes.contains('handle_throwing_invocations'), isTrue);
    });

    test('does NOT flag any call inside try/catch', () async {
      const code = '''
void main() {
  try {
    final int n = int.parse('123');
    print(n);
  } catch (_) {}
}
''';
      final codes = await reportedRuleCodes(
        HandleThrowingInvocationsRule(),
        code,
      );
      expect(codes.contains('handle_throwing_invocations'), isFalse);
    });
  });

  // VERDICT: NON-ISSUE. The rule flags any &&/|| with a boolean-literal
  // operand. The flagged concern was intentional debug toggles like
  // `if (enabled && false)`. But `&& false` IS dead code by definition — it is
  // exactly the always-false shape the rule documents and offers a fix for
  // (`x && false` -> `false`). An intentional toggle written with a boolean
  // literal is syntactically indistinguishable from an accidental logic error;
  // narrowing on const-ness would also silence genuine bugs where a const
  // literal masks intended logic. The INFO-level nudge is therefore defensible
  // and left UNCHANGED. These tests pin the current (intended) behavior.
  group('avoid_conditions_with_boolean_literals — behavior is intended', () {
    test('flags x || true (always-true dead code)', () async {
      const code = '''
void main() {
  final bool x = DateTime.now().isUtc;
  if (x || true) {
    print('always');
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidConditionsWithBooleanLiteralsRule(),
        code,
      );
      expect(codes.contains('avoid_conditions_with_boolean_literals'), isTrue);
    });

    test('does NOT flag a const-bool identifier toggle (only literals fire)',
        () async {
      const code = '''
void main() {
  const bool enabled = false;
  final bool other = DateTime.now().isUtc;
  if (enabled || other) {
    print('toggle');
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidConditionsWithBooleanLiteralsRule(),
        code,
      );
      // The rule only fires when an operand is a literal `true`/`false` token,
      // NOT a const identifier that holds a boolean. The flagged
      // `const enabled = false; if (enabled || other)` example therefore never
      // fires — additional evidence the rule is already narrow and the
      // intentional-toggle concern is a non-issue.
      expect(codes.contains('avoid_conditions_with_boolean_literals'), isFalse);
    });
  });
}
