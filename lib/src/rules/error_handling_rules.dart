// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Error handling lint rules for Flutter/Dart applications.
///
/// These rules help identify improper error handling patterns that can
/// lead to silent failures, lost stack traces, or poor user experience.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when catch block swallows exception without logging.
///
/// Alias: empty_catch, silent_catch, no_empty_catch_block
///
/// Empty catch blocks hide errors and make debugging difficult.
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e) {
///   // Silent failure
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   logger.error('Failed to fetch data', e, stackTrace);
///   rethrow;
/// }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for attention.
class AvoidSwallowingExceptionsRule extends SaropaLintRule {
  const AvoidSwallowingExceptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_swallowing_exceptions',
    problemMessage: 'Catch block swallows exception without handling.',
    correctionMessage: 'Log the error, rethrow, or handle it properly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final Block body = node.body;

      // Check if catch body is empty or only has comments
      if (body.statements.isEmpty) {
        reporter.atNode(node, code);
        return;
      }

      // Check if exception variable is used
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final String exceptionName = exceptionParam.name.lexeme;
      bool exceptionUsed = false;

      body.visitChildren(
        _IdentifierUsageVisitor(exceptionName, () {
          exceptionUsed = true;
        }),
      );

      if (!exceptionUsed) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackCommentForSwallowedExceptionFix()];
}

class _AddHackCommentForSwallowedExceptionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for unhandled exception',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: handle or log this exception\n    ',
        );
      });
    });
  }
}

class _IdentifierUsageVisitor extends RecursiveAstVisitor<void> {
  _IdentifierUsageVisitor(this.name, this.onFound);

  final String name;
  final void Function() onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) {
      onFound();
    }
    super.visitSimpleIdentifier(node);
  }
}

/// Warns when stack trace is lost in catch block.
///
/// Alias: preserve_stack_trace, lost_stack_trace, capture_stack_trace
///
/// Losing stack trace makes debugging production issues nearly impossible.
///
/// **BAD:**
/// ```dart
/// try {
///   await riskyOperation();
/// } catch (e) {
///   throw CustomException(e.toString());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await riskyOperation();
/// } catch (e, stackTrace) {
///   throw CustomException(e.toString(), stackTrace);
/// }
/// ```
///
/// **Quick fix available:** Adds a stack trace parameter to the catch clause.
class AvoidLosingStackTraceRule extends SaropaLintRule {
  const AvoidLosingStackTraceRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_losing_stack_trace',
    problemMessage: 'Stack trace is lost when rethrowing.',
    correctionMessage:
        'Capture stack trace parameter and pass it to Error.throwWithStackTrace or include in new exception.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      // Check if stack trace is captured
      final CatchClauseParameter? stackTraceParam = node.stackTraceParameter;

      // Find throw statements in catch body
      bool hasThrow = false;
      bool hasRethrow = false;

      node.body.visitChildren(
        _ThrowVisitor(
          onThrow: () => hasThrow = true,
          onRethrow: () => hasRethrow = true,
        ),
      );

      // If throwing new exception without stack trace param, warn
      if (hasThrow && !hasRethrow && stackTraceParam == null) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddStackTraceParameterFix()];
}

class _AddStackTraceParameterFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.stackTraceParameter != null) return;

      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add stackTrace parameter',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert ", stackTrace" after the exception parameter
        builder.addSimpleInsertion(
          exceptionParam.end,
          ', stackTrace',
        );
      });
    });
  }
}

class _ThrowVisitor extends RecursiveAstVisitor<void> {
  _ThrowVisitor({required this.onThrow, required this.onRethrow});

  final void Function() onThrow;
  final void Function() onRethrow;

  @override
  void visitThrowExpression(ThrowExpression node) {
    onThrow();
    super.visitThrowExpression(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    onRethrow();
    super.visitRethrowExpression(node);
  }
}

/// Warns when Future errors are not handled.
///
/// Alias: unhandled_future, fire_and_forget_future, add_catch_error
///
/// Unhandled Future errors crash the app or go unnoticed. When a Future
/// is "fire and forget" (called without awaiting), any errors it throws
/// go to the global error handler or are silently lost.
///
/// **BAD:**
/// ```dart
/// void initState() {
///   super.initState();
///   loadData(); // Future not awaited or caught - errors are lost!
/// }
/// ```
///
/// ## Fix Options (in order of preference)
///
/// ### Option 1: Add `.catchError()` (RECOMMENDED)
///
/// This ensures errors are caught and logged, so you know when something fails.
///
/// ```dart
/// void initState() {
///   super.initState();
///   loadData().catchError((Object e, StackTrace s) {
///     debugException(e, s);
///     return null; // Return type must match Future's type
///   });
/// }
/// ```
///
/// ### Option 2: Wrap in try/catch with async helper
///
/// Useful when you need more complex error handling logic.
///
/// ```dart
/// void initState() {
///   super.initState();
///   _initAsync();
/// }
///
/// Future<void> _initAsync() async {
///   try {
///     await loadData();
///   } catch (e, s) {
///     debugException(e, s);
///   }
/// }
/// ```
///
/// ### Option 3: Use `unawaited()` (NOT RECOMMENDED)
///
/// This suppresses the warning but does NOT handle errors - they still go
/// to the global error handler or are lost silently. Only use this when
/// you genuinely don't care if the operation fails.
///
/// ```dart
/// import 'dart:async';
///
/// void initState() {
///   super.initState();
///   unawaited(loadData()); // Errors still lost - just silences the lint
/// }
/// ```
///
/// ## Why `.catchError()` is preferred over `unawaited()`
///
/// | Approach | On Error | Debugging |
/// |----------|----------|-----------|
/// | `.catchError()` | Error logged, you know it failed | Easy |
/// | `unawaited()` | Silent failure, error lost | Impossible |
///
/// `unawaited()` is essentially saying "I don't care if this fails" - which
/// is rarely the actual intent. It just suppresses the lint without fixing
/// the underlying issue of unhandled errors.
///
/// **Quick fix available:** Adds `.catchError()` with `debugPrint`.
class RequireFutureErrorHandlingRule extends SaropaLintRule {
  const RequireFutureErrorHandlingRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_future_error_handling',
    problemMessage: 'Future called without error handling.',
    correctionMessage:
        'Add .catchError() to log errors (recommended), or wrap in try/catch with await.',
    // WARNING is appropriate now that we use actual type checking instead of
    // name-based heuristics - if staticType is Future, it really is a Future.
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;

      // Check if it's a method call that returns Future
      if (expr is MethodInvocation) {
        // Use actual type checking instead of name heuristics
        final type = expr.staticType;
        if (type == null || !type.isDartAsyncFuture) return;

        // Skip if chained with error handling
        if (_hasErrorHandling(expr)) return;

        // Check if in try block
        if (!_isInTryBlock(node)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  bool _hasErrorHandling(MethodInvocation node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation) {
        final String name = current.methodName.name;
        if (name == 'catchError' ||
            name == 'onError' ||
            name == 'whenComplete') {
          return true;
        }
      }
      if (current is AwaitExpression) {
        return true; // Await will propagate to enclosing try/catch
      }
      current = current.parent;
    }
    return false;
  }

  bool _isInTryBlock(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddCatchErrorFix()];
}

class _AddCatchErrorFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: "Add .catchError() handler",
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert .catchError() before the semicolon
        builder.addSimpleInsertion(
          expr.end,
          ".catchError((Object e, StackTrace s) {\n"
          "      debugPrint('\$e\\n\$s');\n"
          "    })",
        );
      });
    });
  }
}

/// Warns when using generic Exception instead of specific types.
///
/// Alias: specific_exception, no_generic_exception, typed_exception
///
/// Generic exceptions provide less context for error handling.
///
/// **BAD:**
/// ```dart
/// throw Exception('Something went wrong');
/// ```
///
/// **GOOD:**
/// ```dart
/// throw NetworkException('Failed to connect to server');
/// ```
class AvoidGenericExceptionsRule extends SaropaLintRule {
  const AvoidGenericExceptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_generic_exceptions',
    problemMessage: 'Avoid throwing generic Exception.',
    correctionMessage: 'Create and throw a specific exception type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      final Expression thrown = node.expression;

      if (thrown is InstanceCreationExpression) {
        final String? typeName = thrown.constructorName.type.element?.name;
        if (typeName == 'Exception' || typeName == 'Error') {
          reporter.atNode(thrown, code);
        }
      }
    });
  }
}

/// Warns when error messages don't include context.
///
/// Alias: descriptive_error, error_message_context, detailed_exception
///
/// Error messages without context are hard to debug.
///
/// **BAD:**
/// ```dart
/// throw Exception('Failed');
/// ```
///
/// **GOOD:**
/// ```dart
/// throw Exception('Failed to load user $userId: $reason');
/// ```
class RequireErrorContextRule extends SaropaLintRule {
  const RequireErrorContextRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_error_context',
    problemMessage: 'Error message lacks context.',
    correctionMessage:
        'Include relevant context like IDs, state, or operation details.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const int _minMessageLength = 20;

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      final Expression thrown = node.expression;

      if (thrown is InstanceCreationExpression) {
        // Check first argument (usually the message)
        if (thrown.argumentList.arguments.isEmpty) {
          reporter.atNode(thrown, code);
          return;
        }

        final Expression firstArg = thrown.argumentList.arguments.first;
        if (firstArg is SimpleStringLiteral) {
          // Check if message is too short
          if (firstArg.value.length < _minMessageLength) {
            reporter.atNode(thrown, code);
          }
        }
      }
    });
  }
}

/// Warns when Result pattern is not used for expected failures.
///
/// Alias: use_result_type, either_pattern, result_vs_exception
///
/// Functions that can fail should return Result instead of throwing.
///
/// **BAD:**
/// ```dart
/// Future<User> getUser(String id) async {
///   final response = await api.get('/users/$id');
///   if (response.statusCode != 200) {
///     throw UserNotFoundException(id);
///   }
///   return User.fromJson(response.body);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<Result<User, UserError>> getUser(String id) async {
///   final response = await api.get('/users/$id');
///   if (response.statusCode != 200) {
///     return Failure(UserError.notFound(id));
///   }
///   return Success(User.fromJson(response.body));
/// }
/// ```
class PreferResultPatternRule extends SaropaLintRule {
  const PreferResultPatternRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_result_pattern',
    problemMessage: 'Consider using Result pattern for expected failures.',
    correctionMessage:
        'Return Result<T, E> instead of throwing for recoverable errors.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkForExpectedThrows(node.functionExpression.body, node, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkForExpectedThrows(node.body, node, reporter);
    });
  }

  void _checkForExpectedThrows(
    FunctionBody body,
    AstNode reportNode,
    SaropaDiagnosticReporter reporter,
  ) {
    int throwCount = 0;

    body.visitChildren(_ThrowCountVisitor(() => throwCount++));

    // If function has multiple throws, suggest Result pattern
    if (throwCount >= 2) {
      reporter.atNode(reportNode, code);
    }
  }
}

class _ThrowCountVisitor extends RecursiveAstVisitor<void> {
  _ThrowCountVisitor(this.onThrow);

  final void Function() onThrow;

  @override
  void visitThrowExpression(ThrowExpression node) {
    onThrow();
    super.visitThrowExpression(node);
  }
}

/// Warns when async function doesn't handle errors internally.
///
/// Alias: document_throws, async_error_handling, throws_annotation
///
/// Async functions should either handle errors or document that they throw.
///
/// **BAD:**
/// ```dart
/// Future<void> processData() async {
///   final data = await fetchData();
///   await saveData(data);
///   // Errors propagate silently
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// /// Throws [NetworkException] if fetch fails.
/// /// Throws [StorageException] if save fails.
/// Future<void> processData() async {
///   final data = await fetchData();
///   await saveData(data);
/// }
/// ```
class RequireAsyncErrorDocumentationRule extends SaropaLintRule {
  const RequireAsyncErrorDocumentationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_async_error_documentation',
    problemMessage:
        'Async function with await should document or handle errors.',
    correctionMessage:
        'Add try/catch or document thrown exceptions with /// Throws.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.body.isAsynchronous) return;

      // Check if has await expressions
      bool hasAwait = false;
      bool hasTryCatch = false;

      node.body.visitChildren(
        _AsyncAnalysisVisitor(
          onAwait: () => hasAwait = true,
          onTryCatch: () => hasTryCatch = true,
        ),
      );

      if (!hasAwait) return;
      if (hasTryCatch) return;

      // Check if documented with Throws
      final Comment? comment = node.documentationComment;
      if (comment != null) {
        final String docText = comment.toSource();
        if (docText.contains('Throws') || docText.contains('@throws')) {
          return;
        }
      }

      reporter.atNode(node, code);
    });
  }
}

class _AsyncAnalysisVisitor extends RecursiveAstVisitor<void> {
  _AsyncAnalysisVisitor({required this.onAwait, required this.onTryCatch});

  final void Function() onAwait;
  final void Function() onTryCatch;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onAwait();
    super.visitAwaitExpression(node);
  }

  @override
  void visitTryStatement(TryStatement node) {
    onTryCatch();
    super.visitTryStatement(node);
  }
}

/// Warns when try statements are nested.
///
/// Alias: nested_try_catch, flatten_try_catch, extract_try_block
///
/// Nested try-catch blocks make code harder to read and maintain.
/// Consider extracting nested logic into separate functions.
///
/// **BAD:**
/// ```dart
/// try {
///   try {
///     await riskyOperation();
///   } catch (e) {
///     // Handle inner error
///   }
/// } catch (e) {
///   // Handle outer error
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await _safeRiskyOperation();
/// } catch (e) {
///   // Handle error
/// }
///
/// Future<void> _safeRiskyOperation() async {
///   try {
///     await riskyOperation();
///   } catch (e) {
///     // Handle or transform error
///     rethrow;
///   }
/// }
/// ```
class AvoidNestedTryStatementsRule extends SaropaLintRule {
  const AvoidNestedTryStatementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_try_statements',
    problemMessage: 'Avoid nested try statements.',
    correctionMessage: 'Extract inner try-catch into a separate function.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      // Check if this try is nested inside another try
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is TryStatement) {
          reporter.atNode(node, code);
          return;
        }
        // Stop at function/method boundaries
        if (parent is FunctionExpression || parent is MethodDeclaration) {
          break;
        }
        parent = parent.parent;
      }
    });
  }
}

/// Warns when error boundary widget is missing.
///
/// Alias: app_error_boundary, error_widget, crash_handler
///
/// Apps should have error boundaries to prevent crashes from propagating.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   home: MyHomePage(), // Errors crash the app
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   builder: (context, child) => ErrorBoundary(child: child!),
///   home: MyHomePage(),
/// )
/// ```
class RequireErrorBoundaryRule extends SaropaLintRule {
  const RequireErrorBoundaryRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_error_boundary',
    problemMessage: 'App should have an error boundary.',
    correctionMessage:
        'Wrap app content in an ErrorBoundary widget or use builder with error handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'MaterialApp' &&
          constructorName != 'CupertinoApp') {
        return;
      }

      // Check for builder argument
      bool hasBuilder = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'builder') {
          hasBuilder = true;
          break;
        }
      }

      if (!hasBuilder) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when Future lacks error handling.
///
/// Alias: catch_future_errors, future_error_handler, handle_future_exception
///
/// Unhandled Future errors can crash the app or cause silent failures.
/// Always use catchError, try-catch, or onError handling.
///
/// **BAD:**
/// ```dart
/// fetchData(); // Fire-and-forget without error handling
/// await fetchData(); // Without try-catch
/// ```
///
/// **GOOD:**
/// ```dart
/// fetchData().catchError((e) => handleError(e));
/// try {
///   await fetchData();
/// } catch (e) {
///   handleError(e);
/// }
/// unawaited(fetchData().catchError(handleError));
/// ```
class AvoidUncaughtFutureErrorsRule extends SaropaLintRule {
  const AvoidUncaughtFutureErrorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_uncaught_future_errors',
    problemMessage: 'Future without error handling may crash app.',
    correctionMessage: 'Add .catchError(), try-catch, or handle with onError.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((ExpressionStatement node) {
      final Expression expression = node.expression;

      // Check for fire-and-forget Future calls
      if (expression is MethodInvocation) {
        final String? returnType = expression.staticType?.toString();
        if (returnType != null &&
            (returnType.startsWith('Future') ||
                returnType.startsWith('Future<'))) {
          // Check if it has .catchError or .onError
          if (!_hasCatchError(expression)) {
            reporter.atNode(expression, code);
          }
        }
      }

      // Check for await without try-catch
      if (expression is AwaitExpression) {
        if (!_isInsideTryCatch(node)) {
          reporter.atNode(expression, code);
        }
      }
    });
  }

  bool _hasCatchError(MethodInvocation node) {
    final String methodName = node.methodName.name;
    if (methodName == 'catchError' || methodName == 'onError') {
      return true;
    }
    // Check if it's chained .catchError
    final Expression? target = node.target;
    if (target is MethodInvocation) {
      return _hasCatchError(target);
    }
    return false;
  }

  bool _isInsideTryCatch(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is TryStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
