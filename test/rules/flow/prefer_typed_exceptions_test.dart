import 'dart:io';

import 'package:saropa_lints/src/rules/flow/prefer_typed_exceptions_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show TestRelevance;
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Tests for the `prefer_typed_exceptions` lint rule.
///
/// Test fixture: example/lib/exception/prefer_typed_exceptions_fixture.dart
///
/// The detection groups below run the rule for real through
/// `resolved_rule_harness.dart`. Before they existed this file asserted only
/// metadata and that the fixture file was present on disk, so the detection
/// body was never executed by any test: inverting the `isDartCoreString`
/// check, deleting the `StringLiteral` branch, or failing to register the
/// `addThrowExpression` callback would all have passed CI silently. The
/// fixture's `// expect_lint:` markers are text-only and enforce nothing.
void main() {
  group('PreferTypedExceptionsRule - Rule Instantiation', () {
    test('PreferTypedExceptionsRule', () {
      final rule = PreferTypedExceptionsRule();
      expect(rule.code.lowerCaseName, 'prefer_typed_exceptions');
      expect(rule.code.problemMessage, contains('[prefer_typed_exceptions]'));
      // Problem Message Requirement (CLAUDE.md): message must exceed 200
      // chars. Was previously asserted at >50, which would not catch a
      // future edit that shrank the message below the documented standard.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });

    // Proposal Edge Case 3 required the test-file exemption to be verified
    // rather than assumed. The rule does not override `testRelevance`, so it
    // inherits SaropaLintRule's default TestRelevance.never (skip test
    // files) -- this pins that inheritance so a future override can't
    // silently change the behavior without a test failing.
    test('inherits TestRelevance.never (skips test files by default)', () {
      final rule = PreferTypedExceptionsRule();
      expect(rule.testRelevance, TestRelevance.never);
    });
  });

  group('PreferTypedExceptionsRule - Fixture Verification', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/exception/prefer_typed_exceptions_fixture.dart',
      );

      expect(file.existsSync(), isTrue);
    });
  });

  // BAD cases: these mirror the four violating methods in the fixture, one
  // test each, so a regression names the exact shape that broke rather than
  // failing a single aggregate assertion.
  group('PreferTypedExceptionsRule - detection fires on bare String throws', () {
    test('flags a bare string literal throw (validateLiteral)', () async {
      // Covers the `thrown is StringLiteral` branch with a SimpleStringLiteral.
      const code = '''
void validate(int age) {
  if (age < 0) {
    throw 'Age cannot be negative';
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isTrue);
    });

    test('flags an interpolated string throw (validateInterpolated)', () async {
      // A StringInterpolation is also a StringLiteral, so this must be caught
      // by the node-kind branch WITHOUT relying on type resolution. Raw string
      // so the `$age` interpolation reaches the fixture verbatim.
      const code = r'''
void validate(int age) {
  if (age < 0) {
    throw 'Age cannot be negative: $age';
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isTrue);
    });

    test('flags a String-typed variable throw (validateVariable)', () async {
      // Non-literal: only `staticType.isDartCoreString` can distinguish this
      // from a legitimate typed exception, so this is the test that proves the
      // type-resolution branch is wired and not inverted.
      const code = '''
void validate(int age) {
  if (age < 0) {
    final String message = 'Age cannot be negative';
    throw message;
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isTrue);
    });

    test(
      'flags a String-returning call throw (validateBuiltMessage)',
      () async {
        // Second type-resolution shape: the thrown expression is a
        // MethodInvocation whose return type is String.
        const code = r'''
String buildMessage(int age) => 'Age cannot be negative: $age';

void validate(int age) {
  if (age < 0) {
    throw buildMessage(age);
  }
}
''';
        final codes = await reportedRuleCodes(
          PreferTypedExceptionsRule(),
          code,
        );
        expect(codes.contains('prefer_typed_exceptions'), isTrue);
      },
    );

    test('flags a bare String throw inside a closure body', () async {
      // The visitor is registered per ThrowExpression node, so nesting depth
      // should be irrelevant -- but that was previously unverified. Pins that
      // a throw inside a callback is still reached.
      const code = '''
void validateAll(List<int> ages) {
  ages.forEach((int age) {
    if (age < 0) {
      throw 'Age cannot be negative';
    }
  });
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isTrue);
    });

    test('flags a bare String throw in an arrow (expression) body', () async {
      // `throw` used as an expression rather than a statement -- still a
      // ThrowExpression node, so it must fire here too.
      const code = '''
String requireName(String? name) => name ?? (throw 'Name is required');
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isTrue);
    });
  });

  // GOOD cases: near-misses that must stay silent. The ArgumentError /
  // StateError / UnimplementedError cases are the load-bearing ones -- the
  // rule deliberately does NOT walk the Exception/Error hierarchy, and these
  // tests are what would fail if someone "improved" it by adding hierarchy
  // checks, which is exactly the false-positive class the design avoids.
  group('PreferTypedExceptionsRule - detection stays silent on good code', () {
    test('does NOT flag a project-defined typed exception', () async {
      const code = '''
class InvalidAgeException implements Exception {
  const InvalidAgeException(this.message);
  final String message;
}

void validate(int age) {
  if (age < 0) {
    throw const InvalidAgeException('Age cannot be negative');
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag ArgumentError (String-argument near-miss)', () async {
      // The thrown expression's static type is ArgumentError, not String, even
      // though its sole argument is a string literal. If the rule ever started
      // inspecting arguments or walking the Error hierarchy this would fire.
      const code = '''
void validate(int age) {
  if (age < 0) {
    throw ArgumentError('Age cannot be negative');
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag StateError (String-argument near-miss)', () async {
      const code = '''
void commit(bool isOpen) {
  if (!isOpen) {
    throw StateError('Transaction is not open');
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag UnimplementedError', () async {
      const code = '''
int computeTotal() {
  throw UnimplementedError('computeTotal is not implemented yet');
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag a generic Exception(...) call', () async {
      // Owned by `avoid_generic_exceptions`; double-reporting the same line
      // under two rule names is the outcome this assertion prevents.
      const code = '''
void validate(int age) {
  if (age < 0) {
    throw Exception('Age cannot be negative');
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag rethrow', () async {
      // `rethrow` is a RethrowExpression, not a ThrowExpression -- the
      // callback should never even see it.
      const code = '''
class InvalidAgeException implements Exception {
  const InvalidAgeException(this.message);
  final String message;
}

void run() {
  try {
    throw const InvalidAgeException('boom');
  } on InvalidAgeException {
    rethrow;
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });

    test('does NOT flag a dynamic variable holding a String', () async {
      // Documented known limitation, pinned as CURRENT behavior rather than a
      // desired one: the static type is `dynamic`, so `isDartCoreString` is
      // false and the throw is missed. Inherent to static-type-only detection;
      // "fixing" it would require flow analysis the rule deliberately avoids.
      const code = '''
void validate(int age) {
  if (age < 0) {
    final dynamic message = 'Age cannot be negative';
    throw message;
  }
}
''';
      final codes = await reportedRuleCodes(PreferTypedExceptionsRule(), code);
      expect(codes.contains('prefer_typed_exceptions'), isFalse);
    });
  });
}
