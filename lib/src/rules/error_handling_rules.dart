// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Error handling lint rules for Flutter/Dart applications.
///
/// These rules help identify improper error handling patterns that can
/// lead to silent failures, lost stack traces, or poor user experience.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart' show Token;
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when catch block swallows exception without logging.
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
  const AvoidSwallowingExceptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_swallowing_exceptions',
    problemMessage:
        '[avoid_swallowing_exceptions] Catch block swallows exception without handling.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_losing_stack_trace',
    problemMessage:
        '[avoid_losing_stack_trace] Rethrowing without stack trace makes debugging impossible - original error location is lost.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_generic_exceptions',
    problemMessage:
        '[avoid_generic_exceptions] Generic Exception prevents callers from '
        'handling specific error cases, forcing catch-all blocks.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_error_context',
    problemMessage:
        '[require_error_context] Error message without IDs or state makes debugging production issues extremely difficult.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_result_pattern',
    problemMessage:
        '[prefer_result_pattern] Throwing for validation errors forces try-catch everywhere and obscures control flow.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_async_error_documentation',
    problemMessage:
        '[require_async_error_documentation] Async function with await should document or handle errors.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_try_statements',
    problemMessage:
        '[avoid_nested_try_statements] Avoid nested try statements.',
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_error_boundary',
    problemMessage:
        '[require_error_boundary] Unhandled widget errors crash the entire '
        'app instead of showing a fallback UI.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_uncaught_future_errors',
    problemMessage:
        '[avoid_uncaught_future_errors] Future without error handling may crash app.',
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_print_error',
    problemMessage:
        '[avoid_print_error] Using print() for error logging. Errors may be lost in production.',
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

/// Warns when using bare catch without an on clause.
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
  const AvoidCatchAllRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_catch_all',
    problemMessage:
        '[avoid_catch_all] Bare catch hides error types, silently swallowing OutOfMemoryError and other critical failures.',
    correctionMessage:
        'Use "on Object catch" for comprehensive handling, or specific types '
        'like HttpException.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final TypeAnnotation? exceptionType = node.exceptionType;

      if (exceptionType == null) {
        // catch (e) without type - implicit catch-all, may be accidental
        reporter.atNode(node, _code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddOnObjectToBareCatchFix()];
}

class _AddOnObjectToBareCatchFix extends DartFix {
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
      if (node.exceptionType != null) return;

      final Token? catchKeyword = node.catchKeyword;
      if (catchKeyword == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add "on Object" for comprehensive error handling',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(catchKeyword.offset, 'on Object ');
      });
    });
  }
}

/// Warns when `on Exception catch` is used without `on Object catch` fallback.
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
  const AvoidCatchExceptionAloneRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_catch_exception_alone',
    problemMessage:
        '[avoid_catch_exception_alone] on Exception catch misses Error types (StateError, TypeError, etc.).',
    correctionMessage:
        'Use "on Object catch" to catch all throwables, or add an '
        '"on Object catch" fallback to handle Error types.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
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
            reporter.atNode(node, _code);
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

  @override
  List<Fix> getFixes() => <Fix>[_ChangeExceptionToObjectFix()];
}

class _ChangeExceptionToObjectFix extends DartFix {
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

      final TypeAnnotation? exceptionType = node.exceptionType;
      if (exceptionType is! NamedType) return;
      if (exceptionType.name2.lexeme != 'Exception') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to "on Object" to catch Error types too',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          exceptionType.sourceRange,
          'Object',
        );
      });
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

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_exception_in_constructor',
    problemMessage:
        '[avoid_exception_in_constructor] Throwing in constructor. Use factory or static method for fallible operations.',
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

  @override
  List<Fix> getFixes() => <Fix>[_AddHackCommentForConstructorThrowFix()];
}

/// Quick fix: Adds a `HACK` comment suggesting factory constructor conversion.
class _AddHackCommentForConstructorThrowFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addThrowExpression((ThrowExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for factory conversion',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Move validation to factory constructor or static method\n      ',
        );
      });
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
///
/// **Quick fix available:** Adds a `HACK` comment for manual key review.
class RequireCacheKeyDeterminismRule extends SaropaLintRule {
  const RequireCacheKeyDeterminismRule() : super(code: _code);

  /// Non-deterministic cache keys cause cache misses and memory bloat.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_cache_key_determinism',
    problemMessage:
        '[require_cache_key_determinism] Cache key using DateTime.now/Random causes cache misses and duplicated data on every access. Consequence: This leads to wasted resources, poor performance, and unpredictable app behavior.',
    correctionMessage:
        'Use deterministic values like IDs or stable hashes for cache keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check 1: Variables ending with 'key'
    context.registry.addVariableDeclaration((VariableDeclaration node) {
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
    context.registry.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(keyArg, code);
      }
    });
  }

  /// Returns true for generic method names that need receiver context validation.
  bool _isGenericMethodName(String methodName) {
    return const <String>{'get', 'put', 'delete', 'read', 'write', 'remove'}
        .contains(methodName);
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

  /// Recursively checks for non-deterministic values, skipping debug-only parameters.
  void _checkForNonDeterministicValues(
    Expression expression,
    AstNode reportNode,
    SaropaDiagnosticReporter reporter,
  ) {
    // For constructor/method calls, check arguments but skip debug-only params
    if (expression is InstanceCreationExpression) {
      for (final Expression arg in expression.argumentList.arguments) {
        if (arg is NamedExpression) {
          // Skip debug-only parameters like debugLabel
          if (_debugOnlyParameters.contains(arg.name.label.name)) {
            continue;
          }
          // Check the value of non-debug parameters
          if (_containsNonDeterministicValue(arg.expression)) {
            reporter.atNode(reportNode, code);
            return;
          }
        } else {
          // Positional argument
          if (_containsNonDeterministicValue(arg)) {
            reporter.atNode(reportNode, code);
            return;
          }
        }
      }
      return;
    }

    if (expression is MethodInvocation) {
      for (final Expression arg in expression.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (_debugOnlyParameters.contains(arg.name.label.name)) {
            continue;
          }
          if (_containsNonDeterministicValue(arg.expression)) {
            reporter.atNode(reportNode, code);
            return;
          }
        } else {
          if (_containsNonDeterministicValue(arg)) {
            reporter.atNode(reportNode, code);
            return;
          }
        }
      }
      return;
    }

    // For other expressions, check the whole source
    if (_containsNonDeterministicValue(expression)) {
      reporter.atNode(reportNode, code);
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

  @override
  List<Fix> getFixes() =>
      <Fix>[_AddHackCommentForNonDeterministicCacheKeyFix()];
}

class _AddHackCommentForNonDeterministicCacheKeyFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for cache key review',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Replace non-deterministic value with stable identifier (e.g., userId, itemId)\n    ',
        );
      });
    });

    // Also handle method invocation arguments (API-based detection)
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK comment for cache key review',
        priority: 2,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Cache key may be non-deterministic - use stable identifier\n    ',
        );
      });
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

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_permission_permanent_denial_handling',
    problemMessage:
        '[require_permission_permanent_denial_handling] Permission request without permanent denial handling.',
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

  // No quick fix - permanent denial handling requires app-specific UI flow
}

// =============================================================================
// require_notification_action_handling
// =============================================================================

/// Notification actions need handlers.
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
  const RequireNotificationActionHandlingRule() : super(code: _code);

  /// Broken notification actions frustrate users.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_notification_action_handling',
    problemMessage:
        '[require_notification_action_handling] Notification actions without handler cause button taps to do nothing, frustrating users.',
    correctionMessage:
        'Ensure onDidReceiveNotificationResponse handles action IDs.',
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
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// require_finally_cleanup
// =============================================================================

/// Use finally for guaranteed cleanup, not just in catch.
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
  const RequireFinallyCleanupRule() : super(code: _code);

  /// Resource leaks from missed cleanup.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_finally_cleanup',
    problemMessage:
        '[require_finally_cleanup] Cleanup in catch block. Use finally for guaranteed cleanup.',
    correctionMessage: 'Move cleanup code to finally block.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addTryStatement((TryStatement node) {
      // Skip if already has finally
      if (node.finallyBlock != null) return;

      // Check catch clauses for cleanup calls
      for (final CatchClause catchClause in node.catchClauses) {
        final String catchSource = catchClause.body.toSource();
        for (final String method in _cleanupMethods) {
          if (catchSource.contains('.$method(') ||
              catchSource.contains('.$method;')) {
            reporter.atNode(catchClause, code);
            return;
          }
        }
      }
    });
  }
}

/// Warns when caught errors are not logged.
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
  const RequireErrorLoggingRule() : super(code: _code);

  /// Unlogged errors make debugging production issues nearly impossible.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_error_logging',
    problemMessage:
        '[require_error_logging] Caught error is not logged. Silent failures make debugging impossible.',
    correctionMessage:
        'Log the error using logger, debugPrint, print, or a crash reporting service.',
    errorSeverity: DiagnosticSeverity.INFO,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addCatchClause((CatchClause node) {
      final Block body = node.body;

      // Skip empty catch blocks - handled by AvoidSwallowingExceptionsRule
      if (body.statements.isEmpty) return;

      // Check if the exception variable exists and is used in logging
      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) {
        // No exception variable captured - can't log it
        reporter.atNode(node, code);
        return;
      }

      // Check if any logging method is called in the catch body
      if (!_hasLoggingCall(body)) {
        reporter.atNode(node, code);
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

  @override
  List<Fix> getFixes() => <Fix>[_AddDebugPrintForErrorFix()];
}

class _AddDebugPrintForErrorFix extends DartFix {
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

      final CatchClauseParameter? exceptionParam = node.exceptionParameter;
      if (exceptionParam == null) return;

      final String exceptionName = exceptionParam.name.lexeme;
      final CatchClauseParameter? stackParam = node.stackTraceParameter;
      final String stackName = stackParam?.name.lexeme ?? 'stackTrace';

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add debugPrint for error logging',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Insert debugPrint at the start of the catch body
        final int insertOffset = node.body.leftBracket.end;

        final String logStatement = stackParam != null
            ? "\n      debugPrint('Error: \$$exceptionName\\n\$$stackName');"
            : "\n      debugPrint('Error: \$$exceptionName');";

        builder.addSimpleInsertion(insertOffset, logStatement);
      });
    });
  }
}

// =============================================================================
// require_app_startup_error_handling
// =============================================================================

/// Warns when main() or runApp() doesn't have error handling.
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
  const RequireAppStartupErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  bool get requiresMainFunction => true;

  static const LintCode _code = LintCode(
    name: 'require_app_startup_error_handling',
    problemMessage:
        '[require_app_startup_error_handling] runApp() without error handling. '
        'Uncaught errors will crash the app silently without reporting.',
    correctionMessage:
        'Wrap in runZonedGuarded and set FlutterError.onError for error reporting.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
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

      reporter.atNode(node, code);
    });
  }
}

// =============================================================================
// avoid_assert_in_production
// =============================================================================

/// Warns when assert is used for validation that should work in production.
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
  const AvoidAssertInProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_assert_in_production',
    problemMessage:
        '[avoid_assert_in_production] assert() is removed in release builds. '
        'This validation will not run in production, potentially causing bugs.',
    correctionMessage:
        'Use if-throw for validation that must work in release mode.',
    errorSeverity: DiagnosticSeverity.WARNING,
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
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAssertStatement((AssertStatement node) {
      final String condition = node.condition.toSource().toLowerCase();

      // Check if this assert is doing important validation
      for (final String keyword in _validationKeywords) {
        if (condition.contains(keyword)) {
          reporter.atNode(node, code);
          return;
        }
      }

      // Check for null checks that should be real validation
      if (condition.contains('!= null') || condition.contains('is!')) {
        reporter.atNode(node, code);
      }
    });
  }
}
