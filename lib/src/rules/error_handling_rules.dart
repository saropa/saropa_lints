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
/// Alias: avoid_empty_catch, empty_catch, silent_catch, no_empty_catch_block
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
        message: 'Add HACK comment for unhandled exception',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: handle or log this exception\n    ',
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

/// Warns when fire-and-forget Future lacks error handling.
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
/// **Quick fix available:** Adds `.catchError()` with `debugPrint`.
class AvoidUncaughtFutureErrorsRule extends SaropaLintRule {
  const AvoidUncaughtFutureErrorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_uncaught_future_errors',
    problemMessage: 'Future without error handling may crash app.',
    correctionMessage:
        'Add try-catch to the function, use .ignore(), or add .catchError().',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Collect all functions/methods with try-catch in their body.
    // CompilationUnit is visited first in pre-order traversal, so this
    // callback fires BEFORE addExpressionStatement callbacks.
    final Set<String> functionsWithTryCatch = <String>{};

    context.registry.addCompilationUnit((CompilationUnit unit) {
      _collectFunctionsWithTryCatch(unit, functionsWithTryCatch);
    });

    context.registry.addExpressionStatement((ExpressionStatement node) {
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
            reporter.atNode(expression, code);
          }
        }
      }
    });
  }

  /// Collects all function and method names that have try-catch in their body.
  void _collectFunctionsWithTryCatch(
    CompilationUnit unit,
    Set<String> result,
  ) {
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

  @override
  List<Fix> getFixes() => <Fix>[_AddCatchErrorToFutureFix()];
}

class _AddCatchErrorToFutureFix extends DartFix {
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

/// Warns when print() is used for error logging in catch blocks.
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
  const AvoidPrintErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_print_error',
    problemMessage:
        'Using print() for error logging. Errors may be lost in production.',
    correctionMessage:
        'Use a proper logging framework like logger, crashlytics, or sentry.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final String exceptionName = exceptionParam.name.lexeme;

      // Visit the catch body to find print calls using the exception
      node.body.visitChildren(
        _PrintErrorVisitor(
          exceptionName: exceptionName,
          onPrintError: (AstNode printNode) {
            reporter.atNode(printNode, code);
          },
        ),
      );
    });
  }
}

class _PrintErrorVisitor extends RecursiveAstVisitor<void> {
  _PrintErrorVisitor({
    required this.exceptionName,
    required this.onPrintError,
  });

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

/// Warns when catching generic Exception or Object without specific type.
///
/// Alias: catch_all, generic_catch, broad_exception_catch
///
/// Catching Exception or Object catches everything, including errors that
/// should crash the app. Catch specific exception types instead.
///
/// **BAD:**
/// ```dart
/// try {
///   await fetchData();
/// } catch (e) {
///   // Catches everything including programmer errors
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   await fetchData();
/// } on HttpException catch (e) {
///   // Handle network errors
/// } on FormatException catch (e) {
///   // Handle parsing errors
/// }
/// ```
class AvoidCatchAllRule extends SaropaLintRule {
  const AvoidCatchAllRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_catch_all',
    problemMessage:
        'Catching generic exception. This catches everything including bugs.',
    correctionMessage: 'Catch specific exception types (HttpException, etc.).',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      // Check if it's a generic catch (no exception type specified)
      final TypeAnnotation? exceptionType = node.exceptionType;

      if (exceptionType == null) {
        // catch (e) without type
        reporter.atNode(node, code);
        return;
      }

      // Check if catching Exception or Object
      if (exceptionType is NamedType) {
        final String typeName = exceptionType.name.lexeme;
        if (typeName == 'Exception' ||
            typeName == 'Object' ||
            typeName == 'dynamic') {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

// =============================================================================
// NEW RULES v2.3.11
// =============================================================================

/// Warns when constructors throw exceptions.
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
  const AvoidExceptionInConstructorRule() : super(code: _code);

  /// Exceptions in constructors are hard to handle properly.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_exception_in_constructor',
    problemMessage:
        'Throwing in constructor. Use factory or static method for fallible operations.',
    correctionMessage:
        'Use factory constructor, static method, or return null for invalid input.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      // Check if inside a constructor
      AstNode? current = node.parent;
      while (current != null) {
        if (current is ConstructorDeclaration) {
          // Allow in factory constructors
          if (current.factoryKeyword != null) return;
          reporter.atNode(node, code);
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

/// Warns when cache keys use non-deterministic values.
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
class RequireCacheKeyDeterminismRule extends SaropaLintRule {
  const RequireCacheKeyDeterminismRule() : super(code: _code);

  /// Non-deterministic cache keys cause cache misses and memory bloat.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_cache_key_determinism',
    problemMessage:
        'Cache key may be non-deterministic. Use stable identifiers for cache keys.',
    correctionMessage:
        'Use deterministic values like IDs or stable hashes for cache keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Patterns that indicate non-deterministic values.
  static const Set<String> _nonDeterministicPatterns = <String>{
    'DateTime.now',
    'Random',
    'hashCode',
    'identityHashCode',
    'uuid',
    'generateId',
    'Uuid().v4',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      final String varName = node.name.lexeme.toLowerCase();

      // Check if variable name suggests a cache key
      if (!varName.contains('key') && !varName.contains('cache')) return;

      final Expression? initializer = node.initializer;
      if (initializer == null) return;

      final String source = initializer.toSource();

      for (final String pattern in _nonDeterministicPatterns) {
        if (source.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

/// Warns when permission denials aren't handled with settings redirect.
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
  const RequirePermissionPermanentDenialHandlingRule() : super(code: _code);

  /// Users stuck on permission denied screen is poor UX.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_permission_permanent_denial_handling',
    problemMessage: 'Permission request without permanent denial handling.',
    correctionMessage:
        'Check isPermanentlyDenied and call openAppSettings() to guide users.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node, code);
      }
    });
  }
}
