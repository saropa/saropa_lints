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

  // Rethrowing a caught error is not a bare-String throw -- must not fire.
  void rethrowCaught() {
    try {
      throw const InvalidAgeException('boom');
    } on InvalidAgeException {
      rethrow;
    }
  }
}
