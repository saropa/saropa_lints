// False-positive regression tests for two flow lint rules, executed against a
// FULLY RESOLVED unit so element/library checks are exercised the way they run
// in production. Metadata-only instantiation tests cannot catch these because
// the bugs are in element-resolution branches.
library;

import 'package:saropa_lints/src/rules/flow/control_flow_rules.dart';
import 'package:saropa_lints/src/rules/flow/error_handling_rules.dart';
import 'package:saropa_lints/src/rules/flow/exception_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

void main() {
  group('handle_throwing_invocations — over-broad dart:io catch-all', () {
    // BUG: the final clause `return uri.startsWith('dart:io') || ...` flagged
    // ANY dart:io element whose simple name happened to be in the thrower set,
    // regardless of whether it was one of the documented read*/write* sync I/O
    // calls. `SystemEncoding.decode` (the `systemEncoding` const in dart:io) is
    // named `decode` but is NOT a documented throwing I/O call.
    test(
      'does NOT flag systemEncoding.decode (dart:io, not a read/write)',
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
      },
    );

    // The documented positive cases must still fire after collapsing the OR.
    test(
      'still flags File.readAsStringSync (documented dart:io thrower)',
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
      },
    );

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

  group('avoid_throw_in_catch_block — Error.throwWithStackTrace exemption', () {
    // BUG: the rule flagged EVERY ThrowExpression inside a catch block,
    // including `throw Error.throwWithStackTrace(...)` — dart:core's own
    // documented mechanism for throwing a new error while explicitly
    // preserving the caught StackTrace, and exactly what this rule's own
    // correctionMessage recommends.
    test('does NOT flag throw Error.throwWithStackTrace(...)', () async {
      const code = '''
void main() {
  try {
    something();
  } catch (e, stackTrace) {
    throw Error.throwWithStackTrace(StateError('failed: \$e'), stackTrace);
  }
}

void something() {}
''';
      final codes = await reportedRuleCodes(AvoidThrowInCatchBlockRule(), code);
      expect(
        codes.contains('avoid_throw_in_catch_block'),
        isFalse,
        reason:
            'Error.throwWithStackTrace already preserves the original stack '
            'trace; it is the rule\'s own suggested fix and must not itself '
            'be flagged.',
      );
    });

    test('does NOT flag rethrow (control)', () async {
      const code = '''
void main() {
  try {
    something();
  } catch (e) {
    rethrow;
  }
}

void something() {}
''';
      final codes = await reportedRuleCodes(AvoidThrowInCatchBlockRule(), code);
      expect(codes.contains('avoid_throw_in_catch_block'), isFalse);
    });

    // The documented bad case must still fire after adding the exemption.
    test('still flags a plain throw with no stack-trace forwarding', () async {
      const code = '''
void main() {
  try {
    something();
  } catch (e) {
    throw Exception('failed');
  }
}

void something() {}
''';
      final codes = await reportedRuleCodes(AvoidThrowInCatchBlockRule(), code);
      expect(codes.contains('avoid_throw_in_catch_block'), isTrue);
    });

    // A same-named `throwWithStackTrace` on an unrelated class must still be
    // flagged — the exemption is keyed to dart:core's Error.
    test(
      'still flags a look-alike throwWithStackTrace on a custom class',
      () async {
        const code = '''
class Error {
  static Never throwWithStackTrace(Object error, StackTrace stackTrace) {
    throw error;
  }
}

void main() {
  try {
    something();
  } catch (e, stackTrace) {
    throw Error.throwWithStackTrace(e!, stackTrace);
  }
}

void something() {}
''';
        final codes = await reportedRuleCodes(
          AvoidThrowInCatchBlockRule(),
          code,
        );
        expect(codes.contains('avoid_throw_in_catch_block'), isTrue);
      },
    );

    // BUG (follow-up): the resolved-element check alone under-exempted the
    // scan CLI's default syntactic (unresolved) pass — `saropa_lints scan`
    // parses without full type resolution, so `methodName.element` is null
    // there and the false positive persisted for that path.
    test('syntactic (unresolved) mode does NOT flag '
        'throw Error.throwWithStackTrace(...)', () {
      const code = '''
void main() {
  try {
    something();
  } catch (e, stackTrace) {
    throw Error.throwWithStackTrace(StateError('failed: \$e'), stackTrace);
  }
}

void something() {}
''';
      final codes = reportedRuleCodesSyntactic(
        AvoidThrowInCatchBlockRule(),
        code,
      );
      expect(
        codes.contains('avoid_throw_in_catch_block'),
        isFalse,
        reason:
            'With no resolved element (the scan CLI\'s default syntactic '
            'pass), the rule must fall back to the syntactic match on '
            'Error.throwWithStackTrace rather than reporting.',
      );
    });

    // Regression floor for the syntactic path: a plain throw must still be
    // flagged even with no type resolution available.
    test('syntactic (unresolved) mode still flags a plain throw', () {
      const code = '''
void main() {
  try {
    something();
  } catch (e) {
    throw Exception('failed');
  }
}

void something() {}
''';
      final codes = reportedRuleCodesSyntactic(
        AvoidThrowInCatchBlockRule(),
        code,
      );
      expect(codes.contains('avoid_throw_in_catch_block'), isTrue);
    });

    // BUG (follow-up): an import-prefixed `core.Error.throwWithStackTrace`
    // was still flagged because the target-extraction only accepted a bare
    // SimpleIdentifier (`Error`), rejecting PrefixedIdentifier targets
    // outright before element resolution ever got a chance to confirm it.
    test('does NOT flag throw core.Error.throwWithStackTrace(...) '
        '(prefixed dart:core import)', () async {
      const code = '''
import 'dart:core' as core;

void main() {
  try {
    something();
  } catch (e, stackTrace) {
    throw core.Error.throwWithStackTrace(StateError('failed: \$e'), stackTrace);
  }
}

void something() {}
''';
      final codes = await reportedRuleCodes(AvoidThrowInCatchBlockRule(), code);
      expect(codes.contains('avoid_throw_in_catch_block'), isFalse);
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

    test(
      'does NOT flag a const-bool identifier toggle (only literals fire)',
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
        expect(
          codes.contains('avoid_conditions_with_boolean_literals'),
          isFalse,
        );
      },
    );
  });

  // BUG: avoid_throw_objects_without_tostring fired on
  // `throw Error.throwWithStackTrace(obj, stack)` even when obj's class has a
  // useful toString(). The call returns Never, so the rule was reading Never's
  // type instead of the first argument's. The fix resolves the first argument
  // and also accepts a toString() inherited from any non-Object superclass.
  group(
    'avoid_throw_objects_without_tostring — throwWithStackTrace operand',
    () {
      test(
        'does NOT flag a class with toString() thrown via throwWithStackTrace',
        () async {
          const code = '''
final class BatchError implements Exception {
  BatchError(this.cause);
  final Object cause;
  @override
  String toString() => 'Batch failed: \$cause';
}

void apply() {
  try {
    _run();
  } on Object catch (error, stack) {
    throw Error.throwWithStackTrace(BatchError(error), stack);
  }
}

void _run() {}
''';
          final codes = await reportedRuleCodes(
            AvoidThrowObjectsWithoutToStringRule(),
            code,
          );
          expect(
            codes.contains('avoid_throw_objects_without_tostring'),
            isFalse,
          );
        },
      );

      test('does NOT flag a class with toString() thrown directly', () async {
        const code = '''
final class BatchError implements Exception {
  BatchError(this.cause);
  final Object cause;
  @override
  String toString() => 'Batch failed: \$cause';
}

void apply() {
  throw BatchError('boom');
}
''';
        final codes = await reportedRuleCodes(
          AvoidThrowObjectsWithoutToStringRule(),
          code,
        );
        expect(codes.contains('avoid_throw_objects_without_tostring'), isFalse);
      });

      test('does NOT flag a class inheriting toString() from a base', () async {
        const code = '''
class Base {
  @override
  String toString() => 'base detail';
}

class Derived extends Base {}

void apply() {
  throw Derived();
}
''';
        final codes = await reportedRuleCodes(
          AvoidThrowObjectsWithoutToStringRule(),
          code,
        );
        expect(codes.contains('avoid_throw_objects_without_tostring'), isFalse);
      });

      test(
        'still flags a class without toString() via throwWithStackTrace',
        () async {
          const code = '''
class NoToString implements Exception {}

void apply() {
  try {
    _run();
  } on Object catch (error, stack) {
    throw Error.throwWithStackTrace(NoToString(), stack);
  }
}

void _run() {}
''';
          final codes = await reportedRuleCodes(
            AvoidThrowObjectsWithoutToStringRule(),
            code,
          );
          expect(
            codes.contains('avoid_throw_objects_without_tostring'),
            isTrue,
          );
        },
      );

      test('still flags a class without toString() thrown directly', () async {
        const code = '''
class PlainBad {}

void apply() {
  throw PlainBad();
}
''';
        final codes = await reportedRuleCodes(
          AvoidThrowObjectsWithoutToStringRule(),
          code,
        );
        expect(codes.contains('avoid_throw_objects_without_tostring'), isTrue);
      });
    },
  );
}
