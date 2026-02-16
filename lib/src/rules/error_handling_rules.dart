// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Error handling lint rules for Flutter/Dart applications.
///
/// These rules help identify improper error handling patterns that can
/// lead to silent failures, lost stack traces, or poor user experience.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../saropa_lint_rule.dart';

/// Warns when catch block swallows exception without logging.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: avoid_empty_catch, empty_catch, no_empty_catch_block
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
  AvoidSwallowingExceptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_swallowing_exceptions',
    '[avoid_swallowing_exceptions] Catch block swallows exception without logging, rethrowing, or handling it. Silent failures hide production bugs, break monitoring and alerting systems, and make it impossible to diagnose issues reported by users. Every caught exception must be acknowledged. {v5}',
    correctionMessage:
        'Log the error, rethrow, or handle it with a user-visible message or recovery action. Example: catch (e, st) { logger.error("Operation failed", e, st); rethrow; }',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final Block body = node.body;

      // Check if catch body is empty or only has comments
      if (body.statements.isEmpty) {
        reporter.atNode(node);
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
        reporter.atNode(node);
      }
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
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
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
  AvoidLosingStackTraceRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_losing_stack_trace',
    '[avoid_losing_stack_trace] Rethrowing without preserving the stack trace loses the original error location and call chain. Production debugging becomes impossible because crash reports show only the rethrow site, not where the error actually originated. Always capture and forward the full stack trace. {v2}',
    correctionMessage:
        'Capture the stack trace parameter and use Error.throwWithStackTrace or include it in the new exception. Example: catch (e, st) { Error.throwWithStackTrace(CustomError(e), st); }',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
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
        reporter.atNode(node);
      }
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

/// Warns when using generic Exception instead of specific types.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidGenericExceptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_generic_exceptions',
    '[avoid_generic_exceptions] Generic Exception thrown instead of a specific error type. This prevents callers from distinguishing between different failure modes, forces broad catch-all blocks, and makes error traceability across services impossible. Specific exception types enable targeted recovery and clearer crash reports. {v4}',
    correctionMessage:
        'Create and throw a specific exception type for each error case. Example: throw UserNotFoundException(userId) instead of throw Exception("not found").',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      final Expression thrown = node.expression;

      if (thrown is InstanceCreationExpression) {
        final String? typeName = thrown.constructorName.type.element?.name;
        if (typeName == 'Exception' || typeName == 'Error') {
          reporter.atNode(thrown);
        }
      }
    });
  }
}

/// Warns when error messages don't include context.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireErrorContextRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_error_context',
    '[require_error_context] Error message is missing contextual details such as entity IDs, operation names, or relevant state. Without this context, production crash reports and logs become impossible to correlate with specific user actions, and debugging requires reproducing the exact conditions that caused the failure. {v5}',
    correctionMessage:
        'Include relevant context in error messages such as IDs, state, or operation details. Example: throw Exception("Failed to load user \$userId: \$reason").',
    severity: DiagnosticSeverity.INFO,
  );

  static const int _minMessageLength = 20;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      final Expression thrown = node.expression;

      if (thrown is InstanceCreationExpression) {
        // Check first argument (usually the message)
        if (thrown.argumentList.arguments.isEmpty) {
          reporter.atNode(thrown);
          return;
        }

        final Expression firstArg = thrown.argumentList.arguments.first;
        if (firstArg is SimpleStringLiteral) {
          // Check if message is too short
          if (firstArg.value.length < _minMessageLength) {
            reporter.atNode(thrown);
          }
        }
      }
    });
  }
}

/// Warns when Result pattern is not used for expected failures.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  PreferResultPatternRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_result_pattern',
    '[prefer_result_pattern] Throwing exceptions for recoverable errors like validation failures forces try-catch blocks at every call site and obscures control flow. This makes error handling inconsistent, increases boilerplate, and causes callers to miss failure cases entirely when they forget to add try-catch. {v5}',
    correctionMessage:
        'Return Result<T, E> or a sealed class for recoverable errors instead of throwing exceptions. Example: return Result.error(ValidationError("invalid email")).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkForExpectedThrows(node.functionExpression.body, node, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
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
      reporter.atNode(reportNode);
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  RequireAsyncErrorDocumentationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_async_error_documentation',
    '[require_async_error_documentation] Async function with await expressions does not document thrown exceptions or handle errors internally. Unhandled async errors propagate as uncaught Future failures that can crash the app, produce silent data loss, or leave the UI in an inconsistent state with no recovery path. {v5}',
    correctionMessage:
        'Add try-catch to handle errors, or document thrown exceptions with /// Throws [ExceptionType]. Example: /// Throws [NetworkException] if the request fails.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
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

      reporter.atNode(node);
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
/// Since: v4.1.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidNestedTryStatementsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nested_try_statements',
    '[avoid_nested_try_statements] Nested try statements found. Deeply nested error handling is hard to read and maintain. Nested try-catch blocks make code harder to read and maintain. Extract nested logic into separate functions. {v2}',
    correctionMessage:
        'Extract inner try-catch into a separate function or refactor to flatten error handling. Example: move inner try to a helper method.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      // Check if this try is nested inside another try
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is TryStatement) {
          reporter.atNode(node);
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
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
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
  RequireErrorBoundaryRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_error_boundary',
    '[require_error_boundary] Top-level MaterialApp or CupertinoApp is missing an error boundary in its build tree. Without a dedicated error handler, uncaught exceptions will crash the entire application, leaving users with a blank or frozen screen and no recovery path. All production apps must provide a visible fallback UI for unexpected errors. {v2}',
    correctionMessage:
        'Add a builder parameter to your MaterialApp or CupertinoApp that wraps the child tree in an ErrorBoundary. Example: builder: (context, child) => ErrorBoundary(child: child!).',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
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

/// Warns when fire-and-forget Future lacks error handling.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: require_future_error_handling, catch_future_errors, future_error_handler,
/// handle_future_exception, unhandled_future, fire_and_forget_future, add_catch_error
///
/// When a Future is called without awaiting ("fire and forget"), any errors
/// it throws go to the global error handler or are silently lost. This rule
/// detects unawaited Futures that lack error handling.
///
/// Note: Awaited futures are NOT flagged because `await` propagates errors
/// to the enclosing async function's Future - that's proper Dart error handling.
///
/// ## BAD - Unhandled fire-and-forget
/// ```dart
/// void initState() {
///   super.initState();
///   loadData(); // Future errors are lost!
/// }
///
/// void _onTap() {
///   _pageController.nextPage(...); // Errors silently ignored
/// }
/// ```
///
/// ## GOOD - Handle or explicitly acknowledge
/// ```dart
/// // Option 1: Add try-catch to the async function (RECOMMENDED)
/// // If the function has internal try-catch, this lint won't flag calls to it.
/// Future<void> _loadData() async {
///   try {
///     await fetchFromApi();
///   } on Exception catch (e, s) {
///     debugException(e, s);
///   }
/// }
///
/// // Option 2: Use .ignore() for intentional fire-and-forget
/// // Best for SDK methods like PageController, AnimationController, etc.
/// _pageController.nextPage(...).ignore();
/// _animationController.forward().ignore();
///
/// // Option 3: Use unawaited() from dart:async
/// // Explicit acknowledgment that you don't care about the result or errors.
/// unawaited(analytics.logEvent('button_pressed'));
///
/// // Option 4: Add .catchError() at the call site
/// loadData().catchError((e, s) {
///   debugPrint('$e\n$s');
///   return null;
/// });
/// ```
///
/// ## When to use .ignore() vs unawaited()
/// - `.ignore()` - Preferred for method chains, cleaner syntax
/// - `unawaited()` - From `dart:async`, wraps the entire expression
///
/// Both explicitly acknowledge that you're intentionally ignoring the Future.
///
/// ## Exceptions (not flagged)
/// - Futures with `.catchError()` chained
/// - Futures with `.then(onError: ...)` callback
/// - Futures with `.ignore()` chained - explicit acknowledgment
/// - Futures wrapped in `unawaited()` - explicit acknowledgment
/// - Safe fire-and-forget methods: `cancel()`, `close()`, `dispose()`, `drain()`
/// - Analytics methods: `logEvent()`, `trackEvent()`, `setCurrentScreen()`
/// - Cache operations: `prefetch()`, `preload()`, `warmCache()`, `invalidate()`
/// - Futures inside `dispose()` methods - synchronous context can't await
/// - Futures already inside a try block
/// - Functions defined in the same file that have try-catch in their body
///
/// ## Limitation: Cross-file analysis
/// This rule can only detect try-catch in functions defined in the **same file**.
/// If you call a method from another file that has internal error handling (e.g.,
/// propagating errors via `StreamController.addError()`), this rule cannot detect
/// that. Use `// ignore: avoid_uncaught_future_errors` with an explanatory comment
/// or `.ignore()` for these cases.
///
/// **Quick fixes available:**
/// - Add `.catchError()` with `debugPrint`
/// - Add `// ignore:` comment
class AvoidUncaughtFutureErrorsRule extends SaropaLintRule {
  AvoidUncaughtFutureErrorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_uncaught_future_errors',
    '[avoid_uncaught_future_errors] Fire-and-forget Future called without error handling. Any exception thrown by this Future is silently lost or crashes the app via the global error handler. Without .catchError(), try-catch, or .ignore(), async failures become invisible in production and extremely difficult to diagnose from crash logs. {v5}',
    correctionMessage:
        'Add try-catch inside the async function, chain .catchError() at the call site, or use .ignore() to explicitly acknowledge fire-and-forget. Example: loadData().catchError((e) => log(e));',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Methods that are safe to call without awaiting or catching errors.
  /// These either don't throw, handle errors internally, or are explicitly
  /// fire-and-forget by design (analytics, logging, cache warming).
  static const Set<String> _safeFireAndForgetMethods = <String>{
    // Resource cleanup - safe per Dart docs
    'cancel',
    'close',
    'dispose',
    'drain',

    // Analytics/Logging - typically have internal error handling
    'logEvent',
    'trackEvent',
    'sendAnalytics',
    'recordEvent',
    'log',

    // Cache operations - failure is non-critical
    'prefetch',
    'preload',
    'warmCache',
    'invalidate',
    'evict',

    // Firebase Analytics - has internal error handling
    'setCurrentScreen',
    'setUserId',
    'setUserProperty',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Collect all functions/methods with try-catch in their body.
    // CompilationUnit is visited first in pre-order traversal, so this
    // callback fires BEFORE addExpressionStatement callbacks.
    final Set<String> functionsWithTryCatch = <String>{};

    context.addCompilationUnit((CompilationUnit unit) {
      _collectFunctionsWithTryCatch(unit, functionsWithTryCatch);
    });

    context.addExpressionStatement((ExpressionStatement node) {
      final Expression expression = node.expression;

      // Only check for fire-and-forget Future calls (unawaited futures)
      // We do NOT flag awaited futures because await propagates errors to the
      // enclosing async function's Future - that's proper Dart error handling.
      if (expression is MethodInvocation) {
        final type = expression.staticType;
        if (type != null && type.isDartAsyncFuture) {
          // Skip if inside dispose() method - it's synchronous and can't await
          if (_isInsideDisposeMethod(node)) {
            return;
          }

          // Skip if inside a try block - errors will be caught
          if (_isInTryBlock(node)) {
            return;
          }

          // Skip safe fire-and-forget methods like cancel() and close()
          final String methodName = expression.methodName.name;
          if (_safeFireAndForgetMethods.contains(methodName)) {
            return;
          }

          // Skip if the called function has internal try-catch error handling
          if (functionsWithTryCatch.contains(methodName)) {
            return;
          }

          // Check if it has error handling (.catchError, .then(onError:), unawaited)
          if (!_hasErrorHandling(expression)) {
            reporter.atNode(expression);
          }
        }
      }
    });
  }

  /// Collects all function and method names that have try-catch in their body.
  void _collectFunctionsWithTryCatch(CompilationUnit unit, Set<String> result) {
    for (final CompilationUnitMember declaration in unit.declarations) {
      if (declaration is FunctionDeclaration) {
        if (_bodyHasTryCatch(declaration.functionExpression.body)) {
          result.add(declaration.name.lexeme);
        }
      } else if (declaration is ClassDeclaration) {
        for (final ClassMember member in declaration.members) {
          if (member is MethodDeclaration) {
            if (_bodyHasTryCatch(member.body)) {
              result.add(member.name.lexeme);
            }
          }
        }
      } else if (declaration is MixinDeclaration) {
        for (final ClassMember member in declaration.members) {
          if (member is MethodDeclaration) {
            if (_bodyHasTryCatch(member.body)) {
              result.add(member.name.lexeme);
            }
          }
        }
      } else if (declaration is ExtensionDeclaration) {
        for (final ClassMember member in declaration.members) {
          if (member is MethodDeclaration) {
            if (_bodyHasTryCatch(member.body)) {
              result.add(member.name.lexeme);
            }
          }
        }
      }
    }
  }

  /// Checks if a function body contains a try-catch statement.
  bool _bodyHasTryCatch(FunctionBody body) {
    if (body is BlockFunctionBody) {
      final Block block = body.block;
      for (final Statement statement in block.statements) {
        if (statement is TryStatement) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if the node is inside a dispose() method.
  /// dispose() is synchronous and cannot await futures.
  bool _isInsideDisposeMethod(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'dispose';
      }
      current = current.parent;
    }
    return false;
  }

  /// Check if the Future has error handling via .catchError(), .then(onError:),
  /// .ignore(), or is wrapped in unawaited().
  bool _hasErrorHandling(MethodInvocation node) {
    final String methodName = node.methodName.name;

    // .catchError() - explicit error handler
    if (methodName == 'catchError') {
      return true;
    }

    // .then() with onError parameter - error handler in callback
    if (methodName == 'then') {
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onError') {
          return true;
        }
      }
    }

    // unawaited() wrapper - developer explicitly acknowledges fire-and-forget
    if (methodName == 'unawaited') {
      return true;
    }

    // .ignore() - some packages use this for intentional fire-and-forget
    if (methodName == 'ignore') {
      return true;
    }

    // Check if it's chained with error handling
    final Expression? target = node.target;
    if (target is MethodInvocation) {
      return _hasErrorHandling(target);
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
}

/// Warns when print() is used for error logging in catch blocks.
///
/// Since: v2.3.9 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: no_print_error, print_error, use_logger
///
/// Using print() for error logging is not appropriate for production apps.
/// Errors should be logged through proper logging infrastructure.
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e) {
///   print(e);
///   print('Error: $e');
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   logger.error('Failed to fetch', error: e, stackTrace: stackTrace);
///   // Or use crashlytics, sentry, etc.
/// }
/// ```
class AvoidPrintErrorRule extends SaropaLintRule {
  AvoidPrintErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_print_error',
    '[avoid_print_error] Using print() for error logging in a catch block. In production, print() output is not captured by crash reporting services like Crashlytics or Sentry, making errors invisible to monitoring dashboards. Errors logged only via print() are effectively lost and cannot trigger alerts or be tracked over time. {v2}',
    correctionMessage:
        'Use a structured logging framework like logger, Crashlytics, or Sentry to capture errors with full stack traces. Example: logger.e("Fetch failed", error: e, stackTrace: st);',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final String exceptionName = exceptionParam.name.lexeme;

      // Visit the catch body to find print calls using the exception
      node.body.visitChildren(
        _PrintErrorVisitor(
          exceptionName: exceptionName,
          onPrintError: (AstNode printNode) {
            reporter.atNode(printNode);
          },
        ),
      );
    });
  }
}

class _PrintErrorVisitor extends RecursiveAstVisitor<void> {
  _PrintErrorVisitor({required this.exceptionName, required this.onPrintError});

  final String exceptionName;
  final void Function(AstNode) onPrintError;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for print() or debugPrint() calls
    final String methodName = node.methodName.name;
    if (methodName != 'print' && methodName != 'debugPrint') {
      super.visitMethodInvocation(node);
      return;
    }

    // Check if the exception variable is used in the print call
    if (node.argumentList.arguments.isNotEmpty) {
      final Expression arg = node.argumentList.arguments.first;
      if (_usesException(arg)) {
        onPrintError(node);
      }
    }

    super.visitMethodInvocation(node);
  }

  bool _usesException(Expression expr) {
    if (expr is SimpleIdentifier) {
      return expr.name == exceptionName;
    }
    if (expr is StringInterpolation) {
      for (final InterpolationElement element in expr.elements) {
        if (element is InterpolationExpression) {
          if (_usesException(element.expression)) {
            return true;
          }
        }
      }
    }
    if (expr is BinaryExpression) {
      return _usesException(expr.leftOperand) ||
          _usesException(expr.rightOperand);
    }
    if (expr is MethodInvocation && expr.target != null) {
      return _usesException(expr.target!);
    }
    return false;
  }
}

/// Warns when using bare catch without an on clause.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: catch_all, generic_catch, broad_exception_catch, no_bare_catch
///
/// Bare catch blocks (`catch (e)` without `on` clause) catch everything
/// implicitly, which may be accidental. Use explicit types to show intent.
///
/// See also: [AvoidCatchExceptionAloneRule] which flags `on Exception catch`
/// without an `on Object catch` fallback.
///
/// Dart's throwable hierarchy:
/// ```
/// Object (base of everything - use this to catch all)
/// ├── Exception (recoverable errors)
/// │   ├── FormatException, IOException, HttpException, etc.
/// └── Error (programming bugs - NOT caught by "on Exception"!)
///     ├── StateError, TypeError, RangeError, AssertionError, etc.
/// ```
///
/// **BAD - Bare catch:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e) {
///   // Implicit catch-all - may be accidental
/// }
/// ```
///
/// **GOOD - Specific handling:**
/// ```dart
/// try {
///   await fetchData();
/// } on HttpException catch (e) {
///   // Handle network errors
/// } on FormatException catch (e) {
///   // Handle parsing errors
/// }
/// ```
///
/// **GOOD - Comprehensive handling with on Object:**
/// ```dart
/// try {
///   await fetchData();
/// } on Object catch (e, stack) {
///   // Catches EVERYTHING including Error types
///   debugException(e, stack);
/// }
/// ```
///
/// Note: `on dynamic catch` is a syntax error in Dart - use `on Object catch`.
///
/// **Quick fix available:** Adds `on Object` before bare catch.
class AvoidCatchAllRule extends SaropaLintRule {
  AvoidCatchAllRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_catch_all',
    '[avoid_catch_all] Bare catch clause without an on-type hides the specific error type being caught and silently swallows critical failures like OutOfMemoryError and StackOverflowError. This can mask fatal programming bugs, making them impossible to detect in crash reports or monitoring systems. {v3}',
    correctionMessage:
        'Use "on Object catch (e, st)" for comprehensive error handling, or catch specific types like HttpException. Example: on Object catch (e, st) { logger.error(e, st); }',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;

      if (exceptionType == null) {
        // catch (e) without type - implicit catch-all, may be accidental
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when `on Exception catch` is used without `on Object catch` fallback.
///
/// Since: v2.4.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: exception_without_fallback, catch_exception_alone,
/// prefer_object_over_exception
///
/// `on Exception catch` only catches `Exception` subclasses, silently missing
/// all `Error` types (StateError, TypeError, RangeError, AssertionError, etc.).
/// This is dangerous because programming errors crash without logging!
///
/// This rule allows `on Exception catch` if there's also an `on Object catch`
/// fallback in the same try statement to catch Error types.
///
/// See also: [AvoidCatchAllRule] which flags bare `catch (e)` blocks.
///
/// Dart's throwable hierarchy:
/// ```
/// Object (base of everything - use this to catch all)
/// ├── Exception (recoverable errors)
/// │   ├── FormatException, IOException, HttpException, etc.
/// └── Error (programming bugs - NOT caught by "on Exception"!)
///     ├── StateError, TypeError, RangeError, AssertionError, etc.
/// ```
///
/// **BAD - on Exception alone (misses Error types!):**
/// ```dart
/// try {
///   await fetchData();
/// } on Exception catch (e) {
///   // DANGER: StateError, TypeError, RangeError will crash without logging!
/// }
/// ```
///
/// **GOOD - on Object catches everything:**
/// ```dart
/// try {
///   await fetchData();
/// } on Object catch (e, stack) {
///   // Catches EVERYTHING including Error types
///   debugException(e, stack);
/// }
/// ```
///
/// **GOOD - on Exception with on Object fallback:**
/// ```dart
/// try {
///   await fetchData();
/// } on Exception catch (e) {
///   // Handle recoverable exceptions one way
/// } on Object catch (e, stack) {
///   // Catch Error types (programming bugs) another way
///   debugException(e, stack);
/// }
/// ```
///
/// **Quick fix available:** Changes `Exception` to `Object`.
class AvoidCatchExceptionAloneRule extends SaropaLintRule {
  AvoidCatchExceptionAloneRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_catch_exception_alone',
    '[avoid_catch_exception_alone] Using "on Exception catch" without an "on Object catch" fallback silently misses all Error types including StateError, TypeError, and RangeError. These programming errors will crash the app without being logged or reported, making production debugging extremely difficult. {v2}',
    correctionMessage:
        'Use "on Object catch" to catch all throwables, or add an "on Object catch" fallback after your Exception handler. Example: on Object catch (e, st) { logger.error(e, st); }',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;
      if (exceptionType == null) {
        return; // Bare catch handled by AvoidCatchAllRule
      }

      // Check if catching Exception (misses Error types)
      if (exceptionType is NamedType) {
        final String typeName = exceptionType.name2.lexeme;
        if (typeName == 'Exception') {
          // Check if there's a fallback catch-all in the same try statement
          if (!_hasObjectCatchFallback(node)) {
            reporter.atNode(node);
          }
        }
      }
    });
  }

  /// Checks if the try statement containing this catch clause has an
  /// `on Object catch` fallback that would catch Error types.
  bool _hasObjectCatchFallback(CatchClause node) {
    // Find the parent TryStatement
    final AstNode? parent = node.parent;
    if (parent is! TryStatement) return false;

    // Check all catch clauses in this try statement
    for (final CatchClause clause in parent.catchClauses) {
      final TypeAnnotation? type = clause.exceptionType;

      // Bare catch (no type) catches everything - but this is bad practice
      // so we don't count it as a valid fallback
      // if (type == null) return true;

      // on Object catch catches everything
      if (type is NamedType && type.name2.lexeme == 'Object') {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when constructors throw exceptions.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: constructor_throw, no_throw_constructor, factory_for_errors
///
/// Throwing in constructors makes error handling difficult because the
/// object is never fully constructed. Use factory constructors or
/// static methods for operations that can fail.
///
/// **BAD:**
/// ```dart
/// class User {
///   User(String email) {
///     if (!isValidEmail(email)) {
///       throw ArgumentError('Invalid email'); // Hard to handle!
///     }
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class User {
///   User._(this.email);
///   final String email;
///
///   static User? tryCreate(String email) {
///     if (!isValidEmail(email)) return null;
///     return User._(email);
///   }
/// }
/// ```
class AvoidExceptionInConstructorRule extends SaropaLintRule {
  AvoidExceptionInConstructorRule() : super(code: _code);

  /// Exceptions in constructors are hard to handle properly.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_exception_in_constructor',
    '[avoid_exception_in_constructor] Throwing in a constructor creates a partially constructed object that can leak resources and leave dependent fields uninitialized. Callers cannot easily recover because the constructor has already failed midway through initialization. {v3}',
    correctionMessage:
        'Use a factory constructor, static tryCreate() method, or return null for invalid input. Example: static User? tryCreate(String email) { if (!valid) return null; }',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addThrowExpression((ThrowExpression node) {
      // Check if inside a constructor
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ConstructorDeclaration) {
          // Allow in factory constructors
          if (current.factoryKeyword != null) return;
          reporter.atNode(node);
          return;
        }
        // Stop at method/function boundary
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Quick fix: Adds a `HACK` comment suggesting factory constructor conversion.

/// Warns when cache keys use non-deterministic values.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: cache_key_stable, deterministic_cache, cache_key_pure
///
/// Cache keys must produce the same value for the same input. Using
/// DateTime.now(), random values, or object hashCodes causes cache misses.
///
/// **BAD:**
/// ```dart
/// final key = 'user_${DateTime.now().millisecondsSinceEpoch}';
/// final key = 'item_${hashCode}'; // hashCode changes between runs
/// ```
///
/// **GOOD:**
/// ```dart
/// final key = 'user_$userId';
/// final key = 'item_${item.id}';
/// ```
///
/// **Quick fix available:** Adds a `HACK` comment for manual key review.
class RequireCacheKeyDeterminismRule extends SaropaLintRule {
  RequireCacheKeyDeterminismRule() : super(code: _code);

  /// Non-deterministic cache keys cause cache misses and memory bloat.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_cache_key_determinism',
    '[require_cache_key_determinism] Cache key uses non-deterministic values (e.g., DateTime.now, Random, hashCode, or UUID). This causes cache misses, duplicated resources, and unpredictable behavior. Cache keys must uniquely and consistently identify the same resource for the same input. Using unstable values breaks cache integrity and wastes memory. {v4}',
    correctionMessage:
        'Construct cache keys only from stable, deterministic values such as unique IDs, query parameters, or content hashes. Never use timestamps, random numbers, or object hashCodes. Example: cacheKey = "user_\$userId" or hash(queryParams).',
    severity: DiagnosticSeverity.ERROR,
  );

  /// Regex patterns that indicate non-deterministic values.
  /// Uses word boundaries to avoid false positives on variable names.
  /// Per CONTRIBUTING.md: Never use substring matching on variable names.
  static final List<RegExp> _nonDeterministicPatterns = <RegExp>[
    // Exact API calls - very safe patterns
    RegExp(r'DateTime\.now\b'), // DateTime.now() or DateTime.now(
    RegExp(r'\bRandom\s*\('), // Random() or Random(seed)
    RegExp(r'\bidentityHashCode\s*\('), // identityHashCode(obj)
    // Property access .hashCode - must have dot prefix to avoid myHashCode
    RegExp(r'\.hashCode\b'), // obj.hashCode but not myHashCode
    // Uuid patterns - constructor or static methods only
    RegExp(r'\bUuid\s*\('), // Uuid() constructor
    RegExp(r'\bUuid\.v[1-8]\b'), // Uuid.v1(), Uuid.v4(), etc.
    RegExp(r'\.v4\s*\('), // someUuid.v4() instance method
  ];

  // FIX: Skip debug-only parameters when checking for non-deterministic values.
  // Flutter's debugLabel (used by GlobalKey, AnimationController, FocusNode, etc.)
  // is purely for DevTools/toString() output and does NOT affect key identity or
  // caching behavior. Non-deterministic values like DateTime.now() are acceptable
  // in these parameters since they're never used for actual cache key comparisons.
  // See: https://api.flutter.dev/flutter/widgets/LabeledGlobalKey-class.html
  static const Set<String> _debugOnlyParameters = <String>{
    'debugLabel',
    'debugName',
  };

  // FIX: Exclude metadata parameters that store timestamps or expiry info about
  // cache entries. These fields record when an entry was created/modified/expires
  // but do NOT participate in cache key identity, lookup, or uniqueness.
  // Non-deterministic values like DateTime.now() are expected here.
  static const Set<String> _metadataParameters = <String>{
    'createdAt',
    'updatedAt',
    'modifiedAt',
    'lastAccessed',
    'lastModified',
    'timestamp',
    'expiresAt',
    'expiry',
    'ttl',
  };

  // FIX: Exclude Flutter Key types entirely - they're widget identity keys, NOT
  // cache keys. Variables like `_key = GlobalKey(...)` should not trigger this
  // rule even though the name contains "key".
  static const Set<String> _flutterKeyTypes = <String>{
    'GlobalKey',
    'ValueKey',
    'ObjectKey',
    'UniqueKey',
    'Key',
    'LocalKey',
    'PageStorageKey',
  };

  // API-based detection: Common caching method names where first argument is a key.
  // Maps method name -> parameter name (null = first positional argument).
  static const Map<String, String?> _cachingMethods = <String, String?>{
    // SharedPreferences
    'getString': null,
    'setString': null,
    'getInt': null,
    'setInt': null,
    'getBool': null,
    'setBool': null,
    'getDouble': null,
    'setDouble': null,
    'getStringList': null,
    'setStringList': null,
    'containsKey': null,
    'remove': null,
    // Hive
    'get': null,
    'put': null,
    'delete': null,
    // GetStorage
    'read': null,
    'write': null,
    'hasData': null,
    // flutter_secure_storage (uses named 'key' parameter)
    // Generic cache patterns
    'getFromCache': null,
    'saveToCache': null,
    'removeFromCache': null,
    'getCached': null,
    'setCached': null,
  };

  // Method receivers that indicate caching context (case-insensitive check).
  // Only check 'get'/'put'/'delete' when called on these receiver types.
  static const Set<String> _cacheReceiverPatterns = <String>{
    'cache',
    'storage',
    'prefs',
    'preferences',
    'store',
    'box', // Hive
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check 1: Variables ending with 'key'
    context.addVariableDeclaration((VariableDeclaration node) {
      final String varName = node.name.lexeme.toLowerCase();

      // Only check variables that end with 'key' - this avoids false positives like
      // 'monkey', 'keyboard', 'newCacheEntry'. Matches: key, cacheKey, userKey, _key
      if (!varName.endsWith('key')) return;

      final Expression? initializer = node.initializer;
      if (initializer == null) return;

      // Skip Flutter Key types - they're widget identity keys, not cache keys
      if (initializer is InstanceCreationExpression) {
        final String typeName = initializer.constructorName.type.name.lexeme;
        if (_flutterKeyTypes.contains(typeName)) return;
      }

      // Check for non-deterministic patterns, but skip debug-only parameters
      _checkForNonDeterministicValues(initializer, node, reporter);
    });

    // Check 2: API-based detection - monitor calls to known caching methods
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Skip if not a known caching method
      if (!_cachingMethods.containsKey(methodName)) return;

      // For generic methods like 'get', 'put', 'delete', verify receiver looks like a cache
      if (_isGenericMethodName(methodName)) {
        if (!_hasCacheReceiver(node)) return;
      }

      // Extract the key argument
      final Expression? keyArg = _extractKeyArgument(node);
      if (keyArg == null) return;

      // Check if key contains non-deterministic values
      if (_containsNonDeterministicValue(keyArg)) {
        reporter.atNode(keyArg);
      }
    });
  }

  /// Returns true for generic method names that need receiver context validation.
  bool _isGenericMethodName(String methodName) {
    return const <String>{
      'get',
      'put',
      'delete',
      'read',
      'write',
      'remove',
    }.contains(methodName);
  }

  /// Checks if the method receiver suggests a caching context.
  bool _hasCacheReceiver(MethodInvocation node) {
    final Expression? target = node.target;
    if (target == null) return false;

    final String targetSource = target.toSource().toLowerCase();
    for (final String pattern in _cacheReceiverPatterns) {
      if (targetSource.contains(pattern)) return true;
    }
    return false;
  }

  /// Extracts the key argument from a caching method call.
  Expression? _extractKeyArgument(MethodInvocation node) {
    final ArgumentList args = node.argumentList;
    if (args.arguments.isEmpty) return null;

    // Check for named 'key' parameter first
    for (final Expression arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == 'key') {
        return arg.expression;
      }
    }

    // Otherwise, first positional argument is the key
    final Expression firstArg = args.arguments.first;
    if (firstArg is! NamedExpression) {
      return firstArg;
    }

    return null;
  }

  /// Recursively checks for non-deterministic values, skipping debug-only
  /// and metadata parameters.
  void _checkForNonDeterministicValues(
    Expression expression,
    AstNode reportNode,
    SaropaDiagnosticReporter reporter,
  ) {
    // For constructor/method calls, check arguments but skip excluded params
    if (expression is InstanceCreationExpression) {
      _checkArgumentList(expression.argumentList, reporter);
      return;
    }

    if (expression is MethodInvocation) {
      _checkArgumentList(expression.argumentList, reporter);
      return;
    }

    // For other expressions, check the whole source
    if (_containsNonDeterministicValue(expression)) {
      reporter.atNode(reportNode);
    }
  }

  /// Checks each argument in [argList] for non-deterministic values.
  /// Skips debug-only and metadata parameters. Reports at the specific
  /// offending argument for precise diagnostics.
  void _checkArgumentList(
    ArgumentList argList,
    SaropaDiagnosticReporter reporter,
  ) {
    for (final Expression arg in argList.arguments) {
      if (arg is NamedExpression) {
        final String paramName = arg.name.label.name;
        if (_debugOnlyParameters.contains(paramName)) continue;
        if (_metadataParameters.contains(paramName)) continue;
        if (_containsNonDeterministicValue(arg.expression)) {
          reporter.atNode(arg);
          return;
        }
      } else {
        // Positional argument
        if (_containsNonDeterministicValue(arg)) {
          reporter.atNode(arg);
          return;
        }
      }
    }
  }

  /// Checks if an expression contains non-deterministic values.
  bool _containsNonDeterministicValue(Expression expression) {
    final String source = expression.toSource();
    for (final RegExp pattern in _nonDeterministicPatterns) {
      if (pattern.hasMatch(source)) {
        return true;
      }
    }
    return false;
  }
}

/// Warns when permission denials aren't handled with settings redirect.
///
/// Since: v2.3.11 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: permission_settings, permanent_denial_handling
///
/// When permissions are permanently denied, apps should guide users to
/// settings instead of repeatedly requesting. Check for isPermanentlyDenied.
///
/// **BAD:**
/// ```dart
/// final status = await Permission.camera.request();
/// if (status.isDenied) {
///   // Just give up or keep asking
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final status = await Permission.camera.request();
/// if (status.isPermanentlyDenied) {
///   await openAppSettings(); // Guide user to enable manually
/// }
/// ```
class RequirePermissionPermanentDenialHandlingRule extends SaropaLintRule {
  RequirePermissionPermanentDenialHandlingRule() : super(code: _code);

  /// Users stuck on permission denied screen is poor UX.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_permission_permanent_denial_handling',
    '[require_permission_permanent_denial_handling] Permission request does not handle permanent denial. Users who permanently deny a permission are stuck with no way to re-enable it from within the app, causing frustration and feature abandonment. {v3}',
    correctionMessage:
        'Check isPermanentlyDenied and call openAppSettings() to guide users to re-enable the permission. Example: if (status.isPermanentlyDenied) await openAppSettings();',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'request') return;

      // Check if it's a Permission.X.request() call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Permission.')) return;

      // Look for isPermanentlyDenied check in surrounding code
      AstNode? current = node.parent;
      FunctionBody? enclosingBody;

      while (current != null) {
        if (current is FunctionBody) {
          enclosingBody = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingBody == null) return;

      final String bodySource = enclosingBody.toSource();
      if (!bodySource.contains('isPermanentlyDenied') &&
          !bodySource.contains('openAppSettings')) {
        reporter.atNode(node);
      }
    });
  }

  // No quick fix - permanent denial handling requires app-specific UI flow
}

// =============================================================================
// require_notification_action_handling
// =============================================================================

/// Notification actions need handlers.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Adding actions to notifications without handling taps leads to
/// broken user experience.
///
/// **BAD:**
/// ```dart
/// NotificationDetails(
///   android: AndroidNotificationDetails(
///     actions: [AndroidNotificationAction('reply', 'Reply')],
///     // No action handler!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Set up action handler
/// onDidReceiveNotificationResponse: (response) {
///   if (response.actionId == 'reply') handleReply();
/// }
/// ```
class RequireNotificationActionHandlingRule extends SaropaLintRule {
  RequireNotificationActionHandlingRule() : super(code: _code);

  /// Broken notification actions frustrate users.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_notification_action_handling',
    '[require_notification_action_handling] Notification with action buttons lacks an onDidReceiveNotificationResponse handler. Users who tap notification action buttons will see no response, breaking the expected interaction flow and frustrating users who may abandon the feature or uninstall the app entirely. {v2}',
    correctionMessage:
        'Add onDidReceiveNotificationResponse to handle each action ID. Example: onDidReceiveNotificationResponse: (details) { if (details.actionId == "reply") handleReply(); }',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AndroidNotificationDetails' &&
          typeName != 'DarwinNotificationDetails') {
        return;
      }

      // Check for actions parameter
      final ArgumentList args = node.argumentList;
      bool hasActions = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'actions') {
          hasActions = true;
          break;
        }
      }

      if (hasActions) {
        // Check if there's a handler in the file
        // This is a simple heuristic - flag to remind developers
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// require_finally_cleanup
// =============================================================================

/// Use finally for guaranteed cleanup, not just in catch.
///
/// Since: v2.6.0 | Updated: v4.13.0 | Rule version: v2
///
/// Cleanup code in catch blocks doesn't run for all exception types
/// or when no exception occurs. Use finally for guaranteed cleanup.
///
/// **BAD:**
/// ```dart
/// try {
///   file = await File(path).open();
///   await processFile(file);
/// } catch (e) {
///   await file?.close();  // May not run!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   file = await File(path).open();
///   await processFile(file);
/// } finally {
///   await file?.close();  // Always runs
/// }
/// ```
class RequireFinallyCleanupRule extends SaropaLintRule {
  RequireFinallyCleanupRule() : super(code: _code);

  /// Resource leaks from missed cleanup.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_finally_cleanup',
    '[require_finally_cleanup] Cleanup code such as close(), dispose(), or cancel() is placed in a catch block instead of a finally block. This means cleanup only runs when an exception occurs, causing resource leaks of file handles, database connections, or stream subscriptions during normal execution when no error is thrown. {v2}',
    correctionMessage:
        'Move cleanup code to a finally block to guarantee it always runs regardless of success or failure. Example: try { file = open(); } finally { file?.close(); }',
    severity: DiagnosticSeverity.INFO,
  );

  /// Methods that suggest cleanup operations.
  static const Set<String> _cleanupMethods = <String>{
    'close',
    'dispose',
    'cancel',
    'release',
    'unlock',
    'destroy',
    'cleanup',
    'shutdown',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addTryStatement((TryStatement node) {
      // Skip if already has finally
      if (node.finallyBlock != null) return;

      // Check catch clauses for cleanup calls
      for (final CatchClause catchClause in node.catchClauses) {
        final String catchSource = catchClause.body.toSource();
        for (final String method in _cleanupMethods) {
          if (catchSource.contains('.$method(') ||
              catchSource.contains('.$method;')) {
            reporter.atNode(catchClause);
            return;
          }
        }
      }
    });
  }
}

/// Warns when caught errors are not logged.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: log_caught_errors, error_logging, catch_without_log
///
/// Caught errors should be logged for debugging and monitoring.
/// Silent catch blocks make it impossible to diagnose issues in production.
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e) {
///   // Error silently ignored - no logging!
///   showErrorDialog();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   logger.error('Failed to fetch data', e, stackTrace);
///   showErrorDialog();
/// }
///
/// // Or with debugPrint for development:
/// try {
///   await fetchData();
/// } catch (e, stackTrace) {
///   debugPrint('Error: $e\n$stackTrace');
///   showErrorDialog();
/// }
/// ```
///
/// **Quick fix available:** Adds a debugPrint statement for the error.
class RequireErrorLoggingRule extends SaropaLintRule {
  RequireErrorLoggingRule() : super(code: _code);

  /// Unlogged errors make debugging production issues nearly impossible.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_error_logging',
    '[require_error_logging] Caught error is not logged to any logging framework or crash reporting service. Silent catch blocks make production debugging impossible because errors leave no trace in logs, crash reports, or monitoring dashboards. Without logging, you cannot detect, alert on, or diagnose failures reported by users. {v2}',
    correctionMessage:
        'Log the error using a structured logger, debugPrint, or a crash reporting service like Crashlytics. Example: logger.error("Fetch failed", error: e, stackTrace: st);',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Method/function names that indicate logging is happening.
  static const Set<String> _loggingMethods = <String>{
    // Standard logging
    'log',
    'print',
    'debugPrint',
    'debugPrintStack',

    // Common logger methods
    'error',
    'warning',
    'warn',
    'info',
    'debug',
    'severe',
    'shout',
    'fine',
    'finer',
    'finest',

    // Crash reporting services
    'recordError',
    'recordFlutterError',
    'captureException',
    'captureMessage',
    'logError',
    'logException',
    'reportError',
    'report',

    // Firebase Crashlytics
    'recordFlutterFatalError',

    // Sentry
    'captureEvent',

    // Custom debug helpers
    'debugException',
    'logDebug',
    'logWarning',
    'logInfo',
  };

  /// Receiver names that indicate a logger object.
  static const Set<String> _loggerReceivers = <String>{
    'logger',
    'log',
    'Logger',
    'Crashlytics',
    'crashlytics',
    'FirebaseCrashlytics',
    'Sentry',
    'sentry',
    'analytics',
    'Analytics',
    'debugger',
    'console',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCatchClause((CatchClause node) {
      final Block body = node.body;

      // Skip empty catch blocks - handled by AvoidSwallowingExceptionsRule
      if (body.statements.isEmpty) return;

      // Check if the exception variable exists and is used in logging
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) {
        // No exception variable captured - can't log it
        reporter.atNode(node);
        return;
      }

      // Check if any logging method is called in the catch body
      if (!_hasLoggingCall(body)) {
        reporter.atNode(node);
      }
    });
  }

  /// Checks if the block contains any logging method calls.
  bool _hasLoggingCall(Block body) {
    final String bodySource = body.toSource();

    // Quick check: does the body contain any known logging method names?
    for (final String method in _loggingMethods) {
      // Check for method call pattern: methodName( or .methodName(
      if (bodySource.contains('$method(') || bodySource.contains('.$method(')) {
        return true;
      }
    }

    // Check for logger receiver patterns: logger.something(
    for (final String receiver in _loggerReceivers) {
      if (bodySource.contains('$receiver.')) {
        return true;
      }
    }

    // Check for rethrow - error will be logged upstream
    if (bodySource.contains('rethrow')) {
      return true;
    }

    // Check for throw - error is being transformed and passed up
    if (bodySource.contains('throw ')) {
      return true;
    }

    return false;
  }
}

// =============================================================================
// require_app_startup_error_handling
// =============================================================================

/// Warns when main() or runApp() doesn't have error handling.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: app_startup_errors, runapp_try_catch
///
/// Unhandled errors in app startup can cause silent crashes. Wrap runApp in
/// runZonedGuarded or set FlutterError.onError for proper error reporting.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyApp()); // Unhandled errors crash silently
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   runZonedGuarded(
///     () {
///       WidgetsFlutterBinding.ensureInitialized();
///       FlutterError.onError = (details) {
///         FlutterError.presentError(details);
///         reportToCrashlytics(details);
///       };
///       runApp(MyApp());
///     },
///     (error, stack) {
///       reportToCrashlytics(error, stack);
///     },
///   );
/// }
/// ```
class RequireAppStartupErrorHandlingRule extends SaropaLintRule {
  RequireAppStartupErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresMainFunction => true;

  static const LintCode _code = LintCode(
    'require_app_startup_error_handling',
    '[require_app_startup_error_handling] runApp() is called without runZonedGuarded or FlutterError.onError. Uncaught errors during app startup will crash the application silently with no crash report sent to monitoring services. Users see a blank or frozen screen with no diagnostic information available to the development team. {v2}',
    correctionMessage:
        'Wrap runApp() in runZonedGuarded and set FlutterError.onError to capture all errors. Example: runZonedGuarded(() { runApp(MyApp()); }, (e, st) { reportToCrashlytics(e, st); });',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      // Only check main function
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Check for runApp call
      if (!bodySource.contains('runApp(')) return;

      // Check for error handling patterns
      if (bodySource.contains('runZonedGuarded') ||
          bodySource.contains('FlutterError.onError') ||
          bodySource.contains('PlatformDispatcher.instance.onError') ||
          bodySource.contains('try') ||
          bodySource.contains('Zone.current.handleUncaughtError') ||
          bodySource.contains('Isolate.current.addErrorListener')) {
        return; // Has error handling
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_assert_in_production
// =============================================================================

/// Warns when assert is used for validation that should work in production.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: assert_production, no_assert_validation
///
/// assert() is removed in release builds. Don't use it for input validation
/// or security checks that must run in production.
///
/// **BAD:**
/// ```dart
/// void processPayment(double amount) {
///   assert(amount > 0); // Silently passes in release mode!
///   processTransaction(amount);
/// }
///
/// void setUserRole(String role) {
///   assert(allowedRoles.contains(role)); // Security bypass in production!
///   user.role = role;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processPayment(double amount) {
///   if (amount <= 0) {
///     throw ArgumentError('Amount must be positive');
///   }
///   processTransaction(amount);
/// }
///
/// void setUserRole(String role) {
///   if (!allowedRoles.contains(role)) {
///     throw SecurityException('Invalid role: $role');
///   }
///   user.role = role;
/// }
/// ```
class AvoidAssertInProductionRule extends SaropaLintRule {
  AvoidAssertInProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_assert_in_production',
    '[avoid_assert_in_production] assert() is compiled out of release builds by the Dart compiler. Any validation, input checking, or security enforcement using assert() will silently stop running in production, allowing invalid data, unauthorized access, or corrupted state to pass through unchecked. {v2}',
    correctionMessage:
        'Use if-throw for validation that must work in release mode. Example: if (amount <= 0) throw ArgumentError("Amount must be positive: \$amount");',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Keywords that suggest the assert is doing important validation
  static const Set<String> _validationKeywords = <String>{
    'null',
    'empty',
    'valid',
    'authorized',
    'allowed',
    'permission',
    'role',
    'admin',
    'user',
    'password',
    'token',
    'input',
    'param',
    'arg',
    'length',
    'size',
    'count',
    'amount',
    'price',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAssertStatement((AssertStatement node) {
      final String condition = node.condition.toSource().toLowerCase();

      // Check if this assert is doing important validation
      for (final String keyword in _validationKeywords) {
        if (condition.contains(keyword)) {
          reporter.atNode(node);
          return;
        }
      }

      // Check for null checks that should be real validation
      if (condition.contains('!= null') || condition.contains('is!')) {
        reporter.atNode(node);
      }
    });
  }
}
