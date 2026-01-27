// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC ERROR HANDLING & TESTING STYLE RULES
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for error handling and testing patterns.
// ============================================================================

// =============================================================================
// ERROR HANDLING RULES
// =============================================================================

/// Warns when generic Exception is thrown instead of specific type.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of specific exceptions:**
/// - Better error handling granularity
/// - Clearer API contract
/// - Can catch specific errors
///
/// **Cons (why some teams prefer generic):**
/// - Simpler code
/// - Less boilerplate
/// - Exception is often enough
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// throw Exception('User not found');
/// ```
///
/// #### GOOD:
/// ```dart
/// throw UserNotFoundException('User not found');
/// ```
class PreferSpecificExceptionsRule extends SaropaLintRule {
  const PreferSpecificExceptionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_specific_exceptions',
    problemMessage:
        '[prefer_specific_exceptions] Throw specific exception types instead of generic Exception.',
    correctionMessage:
        'Create a custom exception class so callers can catch specific failures and provide targeted error recovery.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      final expr = node.expression;
      if (expr is InstanceCreationExpression) {
        final typeName = expr.constructorName.type.element?.name;
        if (typeName == 'Exception') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when specific exceptions are used instead of generic (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of generic exception:**
/// - Simpler code
/// - Less class boilerplate
/// - Often sufficient
///
/// **Cons (why some teams prefer specific):**
/// - Less granular error handling
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// throw UserNotFoundException('User not found');
/// ```
///
/// #### GOOD:
/// ```dart
/// throw Exception('User not found');
/// ```
class PreferGenericExceptionRule extends SaropaLintRule {
  const PreferGenericExceptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  /// Alias: prefer_generic_exception_type
  static const LintCode _code = LintCode(
    name: 'prefer_generic_exception',
    problemMessage:
        '[prefer_generic_exception] Custom exception classes add boilerplate without proportional benefit. Use generic Exception to keep error handling simple.',
    correctionMessage:
        'Replace the custom exception with Exception to reduce class boilerplate while still conveying the error message.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((node) {
      final expr = node.expression;
      if (expr is InstanceCreationExpression) {
        final typeName = expr.constructorName.type.element?.name;
        // Flag custom exceptions (not Exception, Error, or standard ones)
        if (typeName != null &&
            typeName != 'Exception' &&
            typeName != 'Error' &&
            typeName != 'ArgumentError' &&
            typeName != 'StateError' &&
            typeName != 'FormatException' &&
            typeName.endsWith('Exception')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns when custom exception classes don't end with Exception suffix.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Exception suffix:**
/// - Clear naming convention
/// - Easy to identify exception types
/// - Consistent with Dart style
///
/// **Cons (why some teams prefer Error suffix):**
/// - Error suffix is sometimes preferred
/// - Shorter names
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class UserNotFound implements Exception {}
/// ```
///
/// #### GOOD:
/// ```dart
/// class UserNotFoundException implements Exception {}
/// ```
class PreferExceptionSuffixRule extends SaropaLintRule {
  const PreferExceptionSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_exception_suffix',
    problemMessage:
        '[prefer_exception_suffix] Exception classes missing the "Exception" suffix are harder to identify as throwable types during code review and IDE search.',
    correctionMessage:
        'Rename the class to end with "Exception" so it is immediately recognizable as a throwable type in code and search results.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      // Check if class implements Exception
      final implementsClause = node.implementsClause;
      if (implementsClause == null) return;

      bool implementsException = false;
      for (final type in implementsClause.interfaces) {
        if (type.element?.name == 'Exception') {
          implementsException = true;
          break;
        }
      }

      if (!implementsException) return;

      final className = node.name.lexeme;
      if (!className.endsWith('Exception') && !className.endsWith('Error')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Error suffix is preferred over Exception (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Error suffix:**
/// - Shorter than Exception
/// - Some teams prefer Error convention
///
/// **Cons (why some teams prefer Exception):**
/// - Exception is more common in Dart
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// class UserNotFoundException implements Exception {}
/// ```
///
/// #### GOOD:
/// ```dart
/// class UserNotFoundError implements Exception {}
/// ```
class PreferErrorSuffixRule extends SaropaLintRule {
  const PreferErrorSuffixRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_error_suffix',
    problemMessage:
        '[prefer_error_suffix] The "Exception" suffix is verbose and inconsistent with Dart core types like StateError and ArgumentError. Use "Error" for brevity.',
    correctionMessage:
        'Rename the class to end with "Error" instead of "Exception" to align with Dart core naming conventions and reduce verbosity.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final implementsClause = node.implementsClause;
      if (implementsClause == null) return;

      bool implementsException = false;
      for (final type in implementsClause.interfaces) {
        if (type.element?.name == 'Exception') {
          implementsException = true;
          break;
        }
      }

      if (!implementsException) return;

      final className = node.name.lexeme;
      if (className.endsWith('Exception')) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when `on SpecificException` is preferred over bare `catch (e)`.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of on clause:**
/// - Type-safe exception handling
/// - Clear about what's being caught
/// - Won't catch unexpected errors
///
/// **Cons (why some teams prefer catch):**
/// - Simpler syntax
/// - Catches everything
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// try {
///   fetchData();
/// } catch (e) {
///   handleError(e);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// try {
///   fetchData();
/// } on NetworkException catch (e) {
///   handleNetworkError(e);
/// } on FormatException catch (e) {
///   handleFormatError(e);
/// }
/// ```
class PreferOnOverCatchRule extends SaropaLintRule {
  const PreferOnOverCatchRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_on_over_catch',
    problemMessage:
        '[prefer_on_over_catch] Use "on ExceptionType" instead of bare "catch".',
    correctionMessage:
        'Add an "on ExceptionType" clause to catch only expected failures and let unexpected errors propagate to the caller.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((node) {
      // Flag catch clauses without on type
      if (node.exceptionType == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when bare catch is preferred over on clause (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of bare catch:**
/// - Simpler syntax
/// - Catches everything - no missed exceptions
/// - Less boilerplate
///
/// **Cons (why some teams prefer on):**
/// - May catch unexpected errors
/// - Less type-safe
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// try {
///   fetchData();
/// } on NetworkException catch (e) {
///   handleError(e);
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// try {
///   fetchData();
/// } catch (e) {
///   handleError(e);
/// }
/// ```
class PreferCatchOverOnRule extends SaropaLintRule {
  const PreferCatchOverOnRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_catch_over_on',
    problemMessage:
        '[prefer_catch_over_on] Typed "on" clauses add complexity and risk missing unexpected exception types. A bare catch ensures no failure goes unhandled.',
    correctionMessage:
        'Replace the "on ExceptionType" clause with a bare "catch (e)" to simplify error handling and ensure all exceptions are caught.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((node) {
      // Flag catch clauses with on type
      if (node.exceptionType != null) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// TESTING STYLE RULES
// =============================================================================

/// Warns when tests don't use Given/When/Then or Arrange/Act/Assert comments.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of test structure comments:**
/// - Clear test organization
/// - Easy to understand test phases
/// - Consistent test style
///
/// **Cons (why some teams prefer self-documenting):**
/// - Extra comment noise
/// - Self-documenting code is better
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('user login', () {
///   final user = User('test@example.com');
///   final result = authService.login(user);
///   expect(result.isSuccess, true);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('user login', () {
///   // Arrange
///   final user = User('test@example.com');
///
///   // Act
///   final result = authService.login(user);
///
///   // Assert
///   expect(result.isSuccess, true);
/// });
/// ```
class PreferGivenWhenThenCommentsRule extends SaropaLintRule {
  const PreferGivenWhenThenCommentsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_given_when_then_comments',
    problemMessage:
        '[prefer_given_when_then_comments] Use Arrange/Act/Assert or Given/When/Then comments in tests.',
    correctionMessage:
        'Add "// Arrange", "// Act", "// Assert" (or Given/When/Then) comments to delineate setup, execution, and verification phases.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Only check test files
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.length < 2) return;

      final callback = args[1];
      if (callback is! FunctionExpression) return;

      final body = callback.body;
      if (body is! BlockFunctionBody) return;

      // Check if body contains AAA or GWT comments
      final source = resolver.source.contents.data;
      final bodySource = source.substring(body.offset, body.end);

      final hasStructure = bodySource.contains('// Arrange') ||
          bodySource.contains('// Act') ||
          bodySource.contains('// Assert') ||
          bodySource.contains('// Given') ||
          bodySource.contains('// When') ||
          bodySource.contains('// Then');

      // Only flag if there are multiple statements (complex enough to warrant structure)
      if (!hasStructure && body.block.statements.length >= 3) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when AAA/GWT comments are used (prefer self-documenting tests).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of self-documenting tests:**
/// - No comment noise
/// - Code speaks for itself
/// - Cleaner test files
///
/// **Cons (why some teams prefer comments):**
/// - Less explicit structure
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('user login', () {
///   // Arrange
///   final user = User('test@example.com');
///   // Act
///   final result = authService.login(user);
///   // Assert
///   expect(result.isSuccess, true);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('user login', () {
///   final user = User('test@example.com');
///   final result = authService.login(user);
///   expect(result.isSuccess, true);
/// });
/// ```
class PreferSelfDocumentingTestsRule extends SaropaLintRule {
  const PreferSelfDocumentingTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_self_documenting_tests',
    problemMessage:
        '[prefer_self_documenting_tests] Structure comments like Arrange/Act/Assert add noise to well-written tests. Self-documenting code with clear variable names and assertions is more maintainable.',
    correctionMessage:
        'Remove the structure comments and use descriptive variable names and focused assertions to make the test self-documenting.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.length < 2) return;

      final callback = args[1];
      if (callback is! FunctionExpression) return;

      final body = callback.body;
      if (body is! BlockFunctionBody) return;

      final source = resolver.source.contents.data;
      final bodySource = source.substring(body.offset, body.end);

      final hasStructure = bodySource.contains('// Arrange') ||
          bodySource.contains('// Act') ||
          bodySource.contains('// Assert') ||
          bodySource.contains('// Given') ||
          bodySource.contains('// When') ||
          bodySource.contains('// Then');

      if (hasStructure) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when expect() is not used in tests (using assert instead).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of expect():**
/// - Better error messages
/// - Rich matcher support
/// - Idiomatic test style
///
/// **Cons (why some teams use assert):**
/// - assert() is built-in
/// - Simpler syntax
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('calculation', () {
///   final result = calculate(2, 3);
///   assert(result == 5);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('calculation', () {
///   final result = calculate(2, 3);
///   expect(result, equals(5));
/// });
/// ```
class PreferExpectOverAssertInTestsRule extends SaropaLintRule {
  const PreferExpectOverAssertInTestsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_expect_over_assert_in_tests',
    problemMessage:
        '[prefer_expect_over_assert_in_tests] Use expect() instead of assert() in tests.',
    correctionMessage:
        'Use expect() for assertions in tests. Example: expect(user.name, "John"). This provides better error messages and matchers than assert.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addAssertStatement((node) {
      reporter.atNode(node, code);
    });
  }
}

/// Warns when tests have multiple logical assertions.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of single assertion:**
/// - Clear test failure reason
/// - One behavior per test
/// - Easier to understand
///
/// **Cons (why some teams prefer multiple):**
/// - Fewer test functions
/// - Related assertions together
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('user properties', () {
///   final user = User('John', 25);
///   expect(user.name, 'John');
///   expect(user.age, 25);
///   expect(user.isAdult, true);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('user has correct name', () {
///   final user = User('John', 25);
///   expect(user.name, 'John');
/// });
///
/// test('user has correct age', () {
///   final user = User('John', 25);
///   expect(user.age, 25);
/// });
/// ```
class PreferSingleExpectationPerTestRule extends SaropaLintRule {
  const PreferSingleExpectationPerTestRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_single_expectation_per_test',
    problemMessage:
        '[prefer_single_expectation_per_test] Tests should have a single logical assertion.',
    correctionMessage:
        'Split into multiple focused tests, each verifying one behavior, so failures pinpoint exactly which expectation broke.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.length < 2) return;

      final callback = args[1];
      if (callback is! FunctionExpression) return;

      final body = callback.body;
      if (body is! BlockFunctionBody) return;

      // Count expect calls
      int expectCount = 0;
      for (final stmt in body.block.statements) {
        _countExpects(stmt, (count) => expectCount += count);
      }

      if (expectCount > 1) {
        reporter.atNode(node, code);
      }
    });
  }

  void _countExpects(Statement stmt, void Function(int) addCount) {
    if (stmt is ExpressionStatement) {
      final expr = stmt.expression;
      if (expr is MethodInvocation && expr.methodName.name == 'expect') {
        addCount(1);
      }
    } else if (stmt is Block) {
      for (final s in stmt.statements) {
        _countExpects(s, addCount);
      }
    }
  }
}

/// Warns when tests should have multiple grouped expectations (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of grouped expectations:**
/// - Fewer test functions
/// - Related assertions together
/// - Less test boilerplate
///
/// **Cons (why some teams prefer single):**
/// - Less clear failure reason
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('user has correct name', () {
///   final user = User('John', 25);
///   expect(user.name, 'John');
/// });
///
/// test('user has correct age', () {
///   final user = User('John', 25);
///   expect(user.age, 25);
/// });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('user properties', () {
///   final user = User('John', 25);
///   expect(user.name, 'John');
///   expect(user.age, 25);
/// });
/// ```
class PreferGroupedExpectationsRule extends SaropaLintRule {
  const PreferGroupedExpectationsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    name: 'prefer_grouped_expectations',
    problemMessage:
        '[prefer_grouped_expectations] Isolating every assertion into its own test duplicates setup logic and inflates the test suite. Group related assertions to reduce boilerplate.',
    correctionMessage:
        'Combine related assertions into a single test to share setup logic, reduce duplication, and keep the test suite concise.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.length < 2) return;

      final callback = args[1];
      if (callback is! FunctionExpression) return;

      final body = callback.body;
      if (body is! BlockFunctionBody) return;

      // Count expect calls
      int expectCount = 0;
      for (final stmt in body.block.statements) {
        _countExpects(stmt, (count) => expectCount += count);
      }

      // Flag if only one expect (could potentially be grouped)
      if (expectCount == 1 && body.block.statements.length >= 2) {
        reporter.atNode(node, code);
      }
    });
  }

  void _countExpects(Statement stmt, void Function(int) addCount) {
    if (stmt is ExpressionStatement) {
      final expr = stmt.expression;
      if (expr is MethodInvocation && expr.methodName.name == 'expect') {
        addCount(1);
      }
    } else if (stmt is Block) {
      for (final s in stmt.statements) {
        _countExpects(s, addCount);
      }
    }
  }
}

/// Warns when test names don't follow "should X when Y" pattern.
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of should/when pattern:**
/// - Consistent naming
/// - Clear behavior description
/// - BDD-style
///
/// **Cons (why some teams prefer descriptive):**
/// - Rigid format
/// - May not fit all tests
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('login success', () { ... });
/// test('invalid email', () { ... });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('should return success when credentials are valid', () { ... });
/// test('should throw error when email is invalid', () { ... });
/// ```
class PreferTestNameShouldWhenRule extends SaropaLintRule {
  const PreferTestNameShouldWhenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_test_name_should_when',
    problemMessage:
        '[prefer_test_name_should_when] Test names should follow "should X when Y" pattern.',
    correctionMessage: 'Use: test("should [behavior] when [condition]", ...)',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final nameArg = args.first;
      if (nameArg is! SimpleStringLiteral) return;

      final testName = nameArg.value.toLowerCase();

      // Check for should/when pattern
      if (!testName.contains('should') || !testName.contains('when')) {
        reporter.atNode(nameArg, code);
      }
    });
  }
}

/// Warns when descriptive test names are preferred over should/when (opposite).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of descriptive names:**
/// - Flexible format
/// - Natural language
/// - Fits various test styles
///
/// **Cons (why some teams prefer should/when):**
/// - Less consistent
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// test('should return success when credentials are valid', () { ... });
/// ```
///
/// #### GOOD:
/// ```dart
/// test('login success with valid credentials', () { ... });
/// test('valid user can authenticate', () { ... });
/// ```
class PreferTestNameDescriptiveRule extends SaropaLintRule {
  const PreferTestNameDescriptiveRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_test_name_descriptive',
    problemMessage:
        '[prefer_test_name_descriptive] Test name is not descriptive. Rigid patterns make test failures harder to diagnose and understand.',
    correctionMessage:
        'Use natural, descriptive test names that explain the behavior being tested. Example: test("user can authenticate with valid credentials").',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    if (!resolver.source.fullName.contains('_test.dart')) return;

    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'test') return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final nameArg = args.first;
      if (nameArg is! SimpleStringLiteral) return;

      final testName = nameArg.value.toLowerCase();

      // Flag should/when pattern
      if (testName.contains('should') && testName.contains('when')) {
        reporter.atNode(nameArg, code);
      }
    });
  }
}
