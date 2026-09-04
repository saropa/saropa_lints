// Fixture for the `prefer_typed_exceptions` rule: flags a `throw` statement
// that throws a bare `String` (literal or String-typed expression) instead
// of a typed `Exception`/`Error` subclass. Scoped only to the bare-`String`
// case -- `throw Exception(...)` is a related but distinct smell covered by
// `avoid_generic_exceptions`.
//
// Test-file exemption (proposal Edge Case 3): this rule does not override
// `testRelevance`, so it inherits SaropaLintRule's default
// TestRelevance.never and skips *_test.dart files automatically -- verified
// by test/rules/flow/prefer_typed_exceptions_test.dart, not just assumed.

/// A project-defined exception with a real type callers can branch on.
class InvalidAgeException implements Exception {
  const InvalidAgeException(this.message);
  final String message;
}

class PreferTypedExceptionsBad {
  // expect_lint: prefer_typed_exceptions
  void validateLiteral(int age) {
    if (age < 0) {
      throw 'Age cannot be negative';
    }
  }

  // Interpolated string literal is still a StringLiteral node -- the
  // rule's literal-case branch covers this without needing type resolution.
  // expect_lint: prefer_typed_exceptions
  void validateInterpolated(int age) {
    if (age < 0) {
      throw 'Age cannot be negative: $age';
    }
  }

  // Non-literal case: a String-typed local variable thrown directly. Only
  // the resolved static type (not the AST node kind) distinguishes this
  // from a legitimate typed exception.
  // expect_lint: prefer_typed_exceptions
  void validateVariable(int age) {
    if (age < 0) {
      final String message = 'Age cannot be negative';
      throw message;
    }
  }

  // Non-literal case: a function returning String, thrown directly.
  // expect_lint: prefer_typed_exceptions
  void validateBuiltMessage(int age) {
    if (age < 0) {
      throw _buildMessage(age);
    }
  }

  // Nesting depth is irrelevant: the visitor is registered per
  // ThrowExpression node, so a throw inside a callback body is reached the
  // same as one in a method body. Previously unverified -- pinned here and in
  // test/rules/flow/prefer_typed_exceptions_test.dart.
  void validateInClosure(List<int> ages) {
    ages.forEach((int age) {
      if (age < 0) {
        // expect_lint: prefer_typed_exceptions
        throw 'Age cannot be negative';
      }
    });
  }

  // `throw` used as an EXPRESSION (arrow body / `??` right operand) rather
  // than as a statement. Still a ThrowExpression node, so it must fire.
  // expect_lint: prefer_typed_exceptions
  String requireName(String? name) => name ?? (throw 'Name is required');

  String _buildMessage(int age) => 'Age cannot be negative: $age';
}

class PreferTypedExceptionsGood {
  // Throwing a typed exception instance is exactly what the rule wants --
  // must not be flagged.
  void validateTyped(int age) {
    if (age < 0) {
      throw const InvalidAgeException('Age cannot be negative');
    }
  }

  // Generic `Exception(...)`/`Error(...)` calls are a related but distinct
  // smell owned by `avoid_generic_exceptions`; this rule targets only bare
  // String throws, so it must NOT double-report here.
  void validateGeneric(int age) {
    if (age < 0) {
      throw Exception('Age cannot be negative');
    }
  }

  // HIGHEST-VALUE NEAR-MISS. The rule deliberately does NOT walk the
  // Exception/Error hierarchy -- it only asks "is the thrown expression a
  // StringLiteral, or is its static type String?". ArgumentError's static
  // type is ArgumentError, so it is exempt STRUCTURALLY, not by an explicit
  // allow-list. These cases exist so that design decision is verifiable from
  // the fixture rather than only inferable from the rule source: a future
  // "improvement" that added hierarchy inspection, or that started looking at
  // the String ARGUMENT instead of the thrown expression's own type, would
  // start flagging these and reintroduce exactly the false-positive class the
  // current scoping avoids.
  void validateArgument(int age) {
    if (age < 0) {
      throw ArgumentError('Age cannot be negative');
    }
  }

  void commit({required bool isOpen}) {
    if (!isOpen) {
      throw StateError('Transaction is not open');
    }
  }

  int computeTotal() {
    throw UnimplementedError('computeTotal is not implemented yet');
  }

  // KNOWN LIMITATION, pinned as current behavior (not a desired one): the
  // declared type is `dynamic`, so `staticType.isDartCoreString` is false and
  // this bare-String throw is MISSED. Inherent to static-type-only detection;
  // catching it would need value/flow analysis the rule deliberately avoids.
  // Intentionally carries no expect_lint marker.
  void validateDynamic(int age) {
    if (age < 0) {
      final dynamic message = 'Age cannot be negative';
      throw message;
    }
  }

  // Rethrowing a caught error is not a bare-String throw -- must not fire.
  void rethrowCaught() {
    try {
      throw const InvalidAgeException('boom');
    } on InvalidAgeException {
      rethrow;
    }
  }
}
