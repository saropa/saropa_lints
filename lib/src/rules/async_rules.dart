// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when calling .ignore() on a Future.
///
/// Alias: no_future_ignore, future_ignore_error, silent_future_discard
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureIgnoreRule extends SaropaLintRule {
  const AvoidFutureIgnoreRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_future_ignore',
    problemMessage:
        'Future.ignore() silently discards errors. Failures will go unnoticed.',
    correctionMessage:
        'Use await to handle, unawaited() if intentional, or add .catchError().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'ignore') return;

      // Check if this is likely called on a Future
      final Expression? target = node.target;
      if (target == null) return;

      // Check the static type if available
      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForFutureIgnoreFix()];
}

/// Warns when calling toString() or using string interpolation on a Future.
///
/// Alias: no_future_tostring, future_to_string, await_before_tostring
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureToStringRule extends SaropaLintRule {
  const AvoidFutureToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_future_tostring',
    problemMessage:
        "Future.toString() returns 'Instance of Future', not the resolved value.",
    correctionMessage:
        'Use await to get the value first: (await future).toString().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      final Expression? target = node.target;
      if (target == null) return;

      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node, code);
        }
      }
    });

    context.registry.addInterpolationExpression((InterpolationExpression node) {
      final Expression expr = node.expression;
      final DartType? type = expr.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForFutureToStringFix()];
}

/// Warns when `Future<Future<T>>` is used (nested futures).
///
/// Alias: nested_future, future_future, flatten_future
///
/// Example of **bad** code:
/// ```dart
/// Future<Future<int>> nestedFuture() async { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> simpleFuture() async { ... }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNestedFuturesRule extends SaropaLintRule {
  const AvoidNestedFuturesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_futures',
    problemMessage: 'Avoid nested Future types (Future<Future<T>>).',
    correctionMessage: 'Flatten to Future<T> or use async/await properly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (node.name.lexeme == 'Future') {
        final TypeArgumentList? typeArgs = node.typeArguments;
        if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
          final TypeAnnotation innerType = typeArgs.arguments.first;
          if (innerType is NamedType && innerType.name.lexeme == 'Future') {
            reporter.atNode(node, code);
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForNestedFuturesFix()];
}

/// Warns when `Stream<Future<T>>` or `Future<Stream<T>>` is used.
///
/// Alias: stream_future_mix, nested_stream_future, flatten_stream
///
/// Example of **bad** code:
/// ```dart
/// Stream<Future<int>> streamOfFutures() { ... }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Stream<int> directStream() async* { ... }
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidNestedStreamsAndFuturesRule extends SaropaLintRule {
  const AvoidNestedStreamsAndFuturesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_nested_streams_and_futures',
    problemMessage: 'Avoid mixing Stream and Future in nested types.',
    correctionMessage: 'Use async*/await patterns instead of nested types.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((NamedType node) {
      final String outerType = node.name.lexeme;
      if (outerType != 'Stream' && outerType != 'Future') return;

      final TypeArgumentList? typeArgs = node.typeArguments;
      if (typeArgs == null || typeArgs.arguments.isEmpty) return;

      final TypeAnnotation innerType = typeArgs.arguments.first;
      if (innerType is! NamedType) return;

      final String innerTypeName = innerType.name.lexeme;

      // Skip Future<Future> - already handled by AvoidNestedFuturesRule
      if (outerType == 'Future' && innerTypeName == 'Future') return;

      // Only flag Stream<Future>, Future<Stream>, Stream<Stream>
      if (innerTypeName == 'Stream' || innerTypeName == 'Future') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForNestedStreamsAndFuturesFix()];
}

/// Warns when an async function is passed where a sync function is expected.
///
/// Alias: async_callback_in_sync, async_where_sync_expected, ignored_future_return
///
/// Passing an async function to a parameter expecting a synchronous function
/// can lead to unexpected behavior where the returned Future is ignored.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidPassingAsyncWhenSyncExpectedRule extends SaropaLintRule {
  const AvoidPassingAsyncWhenSyncExpectedRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_passing_async_when_sync_expected',
    problemMessage: 'Async function passed where sync function expected.',
    correctionMessage: 'Ensure the caller handles the returned Future.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Methods known to NOT handle async callbacks properly.
  /// These expect synchronous functions and will ignore returned Futures.
  static const Set<String> _syncOnlyMethods = <String>{
    'forEach', // List.forEach ignores Future returns
    'map', // Iterable.map doesn't await
    'where', // Iterable.where doesn't await
    'any', // Iterable.any doesn't await
    'every', // Iterable.every doesn't await
    'reduce', // Iterable.reduce doesn't await
    'fold', // Iterable.fold doesn't await
    'sort', // List.sort doesn't await
    'removeWhere', // List.removeWhere doesn't await
    'retainWhere', // List.retainWhere doesn't await
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Check if function is async
      if (!node.body.isAsynchronous) return;

      final AstNode? parent = node.parent;
      // Check if passed as argument
      if (parent is! ArgumentList) return;

      final AstNode? grandparent = parent.parent;

      // Only flag methods known to ignore Future returns
      if (grandparent is MethodInvocation) {
        final String methodName = grandparent.methodName.name;
        if (_syncOnlyMethods.contains(methodName)) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForAsyncWhenSyncExpectedFix()];
}

/// Warns when async is used but no await is present in the function body.
///
/// Alias: unnecessary_async, async_without_await, remove_async
///
/// Example of **bad** code:
/// ```dart
/// Future<int> getValue() async {
///   return 42;  // No await needed
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() {
///   return Future.value(42);
/// }
/// // Or if await is actually needed:
/// Future<int> getValue() async {
///   return await someAsyncOp();
/// }
/// ```
class AvoidRedundantAsyncRule extends SaropaLintRule {
  const AvoidRedundantAsyncRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_async',
    problemMessage: 'Async function does not use await.',
    correctionMessage: 'Remove async keyword or add await expression.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncBody(node.functionExpression.body, node, reporter);
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkAsyncBody(node.body, node, reporter);
    });
  }

  void _checkAsyncBody(
      FunctionBody body, AstNode node, SaropaDiagnosticReporter reporter) {
    // Only check async functions (not async*)
    if (body.isAsynchronous && !body.isGenerator) {
      // Check if body contains any await expressions
      final bool hasAwait = _containsAwait(body);
      if (!hasAwait) {
        reporter.atNode(node, code);
      }
    }
  }

  bool _containsAwait(AstNode node) {
    bool found = false;
    node.visitChildren(
      _AwaitFinder((AwaitExpression _) {
        found = true;
      }),
    );
    return found;
  }
}

class _AwaitFinder extends RecursiveAstVisitor<void> {
  _AwaitFinder(this.onFound);

  final void Function(AwaitExpression) onFound;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onFound(node);
    super.visitAwaitExpression(node);
  }
}

/// Warns when a Stream is converted to String via toString().
///
/// Alias: no_stream_tostring, stream_to_string, stream_tolist_instead
///
/// Example of **bad** code:
/// ```dart
/// print(myStream.toString());
/// ```
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidStreamToStringRule extends SaropaLintRule {
  const AvoidStreamToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  // cspell:ignore tostring
  static const LintCode _code = LintCode(
    name: 'avoid_stream_tostring',
    problemMessage: 'Stream.toString() returns unhelpful output.',
    correctionMessage: 'Use stream.toList() or iterate over the stream.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Use staticType instead of string matching to avoid false positives
      // on variables like "upstream", "streamlined", etc.
      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Stream')) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForStreamToStringFix()];
}

/// Warns when .listen() result is not assigned to a variable.
///
/// Alias: require_stream_subscription_cancel
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidUnassignedStreamSubscriptionsRule extends SaropaLintRule {
  const AvoidUnassignedStreamSubscriptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_stream_subscriptions',
    problemMessage:
        'Stream subscription not assigned. Cannot cancel it, causing memory leaks.',
    correctionMessage:
        'Assign to variable: final sub = stream.listen(...); then sub.cancel() in dispose.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if the target is a Stream
      final Expression? target = node.target;
      if (target == null) return;

      final DartType? type = target.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!typeName.startsWith('Stream')) return;

      // Check if result is assigned
      final AstNode? parent = node.parent;
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression) return;
      if (parent is ReturnStatement) return;

      // Check if it's an expression statement (not assigned)
      if (parent is ExpressionStatement) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForUnassignedSubscriptionFix()];
}

/// Warns when .then() is used instead of async/await in async functions.
///
/// Alias: use_async_await, then_to_await, avoid_then_chain
///
/// Using async/await is generally more readable than .then() chains.
/// Only flags .then() when used inside an async function where await
/// could be used instead.
class PreferAsyncAwaitRule extends SaropaLintRule {
  const PreferAsyncAwaitRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_async_await',
    problemMessage: "Prefer 'async/await' over '.then()' in async functions.",
    correctionMessage: 'Refactor to use async/await syntax.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'then') return;

      // Only flag if inside an async function where await could be used
      final FunctionBody? enclosingBody = _findEnclosingFunctionBody(node);
      if (enclosingBody == null) return;
      if (!enclosingBody.isAsynchronous) return;

      reporter.atNode(node.methodName, code);
    });
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }
}

/// Warns when await is used inline instead of assigning to a variable first.
///
/// Alias: inline_await, extract_await, await_variable
class PreferAssigningAwaitExpressionsRule extends SaropaLintRule {
  const PreferAssigningAwaitExpressionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_assigning_await_expressions',
    problemMessage:
        'Inline await expression. Harder to debug and inspect intermediate values.',
    correctionMessage:
        'Extract to variable: final result = await fetch(); then use result.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final AstNode? parent = node.parent;

      // OK if direct child of variable declaration or assignment
      if (parent is VariableDeclaration) return;
      if (parent is AssignmentExpression && parent.rightHandSide == node) {
        return;
      }

      // OK if direct child of return or expression statement
      if (parent is ReturnStatement) return;
      if (parent is ExpressionStatement) return;

      // OK if in a list/set/map literal at top level
      if (parent is ListLiteral ||
          parent is SetOrMapLiteral ||
          parent is MapLiteralEntry) {
        return;
      }

      // Warn on await used as argument or nested in expression
      if (parent is ArgumentList ||
          parent is MethodInvocation ||
          parent is BinaryExpression ||
          parent is ConditionalExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Future.delayed doesn't have a comment explaining why.
///
/// Alias: document_future_delayed, explain_delay, delay_comment
///
/// Delays should be documented to explain their purpose.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// await Future.delayed(Duration(seconds: 2));
/// ```
///
/// #### GOOD:
/// ```dart
/// // Wait for animation to complete
/// await Future.delayed(Duration(seconds: 2));
/// ```
class PreferCommentingFutureDelayedRule extends SaropaLintRule {
  const PreferCommentingFutureDelayedRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_commenting_future_delayed',
    problemMessage: 'Future.delayed should have a comment explaining why.',
    correctionMessage: 'Add a comment before the delay explaining its purpose.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Future.delayed
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Future') return;
      if (node.methodName.name != 'delayed') return;

      // Check preceding comments attached to the token
      // This is the reliable way to check for comments in Dart AST
      final Token firstToken = node.beginToken;
      final bool hasComment = firstToken.precedingComments != null;

      if (!hasComment) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Future-returning functions have incorrect return type annotations.
///
/// Alias: async_return_type, future_return_type, explicit_future_type
class PreferCorrectFutureReturnTypeRule extends SaropaLintRule {
  const PreferCorrectFutureReturnTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_future_return_type',
    problemMessage: 'Async function should have Future return type annotation.',
    correctionMessage: 'Add explicit Future<T> return type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncFunction(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkAsyncFunction(node.body, node.returnType, node.name, reporter);
    });
  }

  void _checkAsyncFunction(
    FunctionBody body,
    TypeAnnotation? returnType,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (!body.isAsynchronous) return;
    if (body.star != null) return; // async* is Stream

    if (returnType == null) {
      reporter.atToken(nameToken, code);
      return;
    }

    final String typeStr = returnType.toSource();
    if (!typeStr.startsWith('Future')) {
      reporter.atNode(returnType, code);
    }
  }
}

/// Warns when Stream-returning functions have incorrect return type annotations.
///
/// Alias: async_star_return_type, stream_return_type, explicit_stream_type
class PreferCorrectStreamReturnTypeRule extends SaropaLintRule {
  const PreferCorrectStreamReturnTypeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_correct_stream_return_type',
    problemMessage:
        'Async* function should have Stream return type annotation.',
    correctionMessage: 'Add explicit Stream<T> return type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncStarFunction(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkAsyncStarFunction(node.body, node.returnType, node.name, reporter);
    });
  }

  void _checkAsyncStarFunction(
    FunctionBody body,
    TypeAnnotation? returnType,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (!body.isAsynchronous) return;
    if (body.star == null) return; // Must be async*

    if (returnType == null) {
      reporter.atToken(nameToken, code);
      return;
    }

    final String typeStr = returnType.toSource();
    if (!typeStr.startsWith('Stream')) {
      reporter.atNode(returnType, code);
    }
  }
}

/// Warns when Future.value() is called without explicit type argument.
class PreferSpecifyingFutureValueTypeRule extends SaropaLintRule {
  const PreferSpecifyingFutureValueTypeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_specifying_future_value_type',
    problemMessage: 'Specify type argument for Future.value().',
    correctionMessage: 'Add explicit type: Future<Type>.value(...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final NamedType type = constructorName.type;

      // Check for Future.value constructor
      if (type.name.lexeme != 'Future') return;
      if (constructorName.name?.name != 'value') return;

      // Check if type arguments are specified
      if (type.typeArguments == null) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a Future is returned without await in an async function.
///
/// In async functions, returning a Future without await can cause issues
/// with error handling and stack traces.
///
/// Example of **bad** code:
/// ```dart
/// Future<int> getValue() async {
///   return fetchData();  // Missing await
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// Future<int> getValue() async {
///   return await fetchData();
/// }
/// // Or if not async:
/// Future<int> getValue() {
///   return fetchData();
/// }
/// ```
///
/// **Quick fix available:** Adds `await` before the returned expression.
class PreferReturnAwaitRule extends SaropaLintRule {
  const PreferReturnAwaitRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_return_await',
    problemMessage:
        'Return await in async functions for proper error handling.',
    correctionMessage: 'Add await before the returned Future.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      final Expression? expression = node.expression;
      if (expression == null) return;

      // Skip if already awaited
      if (expression is AwaitExpression) return;

      // Check if inside async function
      final AstNode? functionBody = _findEnclosingFunctionBody(node);
      if (functionBody is! FunctionBody) return;
      if (!functionBody.isAsynchronous) return;
      if (functionBody.isGenerator) return; // async* uses yield

      // Check if the return type is a Future
      final DartType? returnType = expression.staticType;
      if (returnType == null) return;

      final String typeName = returnType.getDisplayString();
      if (typeName.startsWith('Future<') || typeName == 'Future<dynamic>') {
        reporter.atNode(node, code);
      }
    });
  }

  AstNode? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddAwaitFix()];
}

class _AddAwaitFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final Expression? expression = node.expression;
      if (expression == null) return;
      if (expression is AwaitExpression) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add await',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(expression.offset, 'await ');
      });
    });
  }
}

class _AddHackForFutureIgnoreFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for Future.ignore()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: handle this Future properly with await or unawaited()\n',
        );
      });
    });
  }
}

class _AddHackForFutureToStringFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for Future.toString()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: await the Future before converting to string\n',
        );
      });
    });
  }
}

class _AddHackForNestedFuturesFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for nested Future',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: flatten nested Future */ ',
        );
      });
    });
  }
}

class _AddHackForNestedStreamsAndFuturesFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for nested Stream/Future',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: avoid mixing Stream and Future */ ',
        );
      });
    });
  }
}

class _AddHackForAsyncWhenSyncExpectedFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for async callback',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* TODO: async callback - ensure caller handles Future */ ',
        );
      });
    });
  }
}

class _AddHackForStreamToStringFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for Stream.toString()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: use stream.toList() or iterate instead of toString()\n',
        );
      });
    });
  }
}

class _AddHackForUnassignedSubscriptionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add TODO comment for unassigned subscription',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// TODO: assign subscription to cancel later\n',
        );
      });
    });
  }
}

/// Warns when `VoidCallback` is used for a callback that likely performs
/// async operations.
///
/// ## Why This Matters
///
/// `VoidCallback` is defined as `void Function()`. When you pass an async
/// function to a `VoidCallback`, Dart allows it but **silently discards the
/// returned Future**. This causes several problems:
///
/// 1. **Lost errors**: Exceptions thrown in the async callback are swallowed
/// 2. **Race conditions**: The caller can't wait for completion
/// 3. **Unpredictable state**: UI may update before the operation finishes
///
/// ## How Detection Works
///
/// This rule flags `VoidCallback` fields and parameters whose names suggest
/// async behavior:
///
/// - **Data operations**: onSubmit, onSave, onLoad, onFetch, onRefresh, onSync
/// - **Network operations**: onLogin, onLogout, onSend, onRequest
/// - **Database operations**: onDelete, onUpdate, onInsert, onCreate
/// - **File operations**: onExport, onImport, onBackup, onRestore
/// - **Processing**: onProcess, onValidate, onConfirm, onComplete
///
/// Prefixed variants (e.g., `onSubmitForm`, `onDeleteUser`) are also detected.
///
/// ## Example
///
/// ### BAD:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final VoidCallback? onSubmit;  // Future silently discarded!
///   final VoidCallback? onDelete;  // Errors will be swallowed!
///
///   void _handleTap() {
///     onSubmit?.call();  // Can't await, can't catch errors
///     showSuccessMessage();  // May run before submit completes!
///   }
/// }
/// ```
///
/// ### GOOD:
/// ```dart
/// class MyWidget extends StatelessWidget {
///   final Future<void> Function()? onSubmit;  // Explicit async signature
///   final Future<void> Function()? onDelete;  // Caller can await
///
///   Future<void> _handleTap() async {
///     await onSubmit?.call();  // Properly awaited
///     showSuccessMessage();     // Runs after submit completes
///   }
/// }
/// ```
///
/// ## Why `Future<void> Function()` Instead of `AsyncCallback`?
///
/// While Flutter provides `AsyncCallback` in `package:flutter/foundation.dart`
/// (also available via `widgets.dart`/`material.dart`), we recommend the
/// explicit `Future<void> Function()` form because:

/// 1. **No Flutter-specific type dependency** — works in pure Dart and Flutter
///    projects alike without importing Flutter foundation types
/// 2. **Self-documenting** - the signature is immediately clear
/// 3. **Consistent** - matches how parameterized async callbacks are written:
///    ```dart
///    final Future<void> Function(String id)? onDeleteItem;  // With params
///    final Future<void> Function()? onRefresh;               // Without params
///    ```
///
/// ## Quick Fix
///
/// This rule provides an automatic fix that replaces:
/// - `VoidCallback` → `Future<void> Function()`
/// - `VoidCallback?` → `Future<void> Function()?`
class PreferAsyncCallbackRule extends SaropaLintRule {
  const PreferAsyncCallbackRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_async_callback',
    problemMessage:
        'VoidCallback discards Futures silently. Errors will be swallowed and '
        'callers cannot await completion.',
    correctionMessage:
        'Use Future<void> Function() to allow proper async handling.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  bool get skipFixtureFiles => false;

  /// Callback names that strongly suggest async behavior.
  static const Set<String> _asyncSuggestingNames = <String>{
    // Data operations
    'onSubmit',
    'onSave',
    'onLoad',
    'onFetch',
    'onRefresh',
    'onSync',
    'onUpload',
    'onDownload',

    // Network operations
    'onSend',
    'onRequest',
    'onLogin',
    'onLogout',
    'onSignIn',
    'onSignOut',
    'onAuthenticate',
    'onRegister',

    // Database operations
    'onDelete',
    'onUpdate',
    'onInsert',
    'onCreate',

    // File operations
    'onExport',
    'onImport',
    'onBackup',
    'onRestore',

    // Processing
    'onProcess',
    'onValidate',
    'onConfirm',
    'onComplete',
    'onFinish',
  };

  /// Prefixes that suggest async behavior when combined with other words.
  ///
  /// Example: `onSubmitForm`, `onDeleteUser`, `onProcessPayment`.
  /// These are checked with camelCase validation (next char must be uppercase).
  static const Set<String> _asyncSuggestingPrefixes = <String>{
    'onSubmit',
    'onSave',
    'onLoad',
    'onFetch',
    'onRefresh',
    'onSync',
    'onUpload',
    'onDownload',
    'onSend',
    'onDelete',
    'onUpdate',
    'onInsert',
    'onCreate',
    'onLogin',
    'onLogout',
    'onSignIn',
    'onSignOut',
    'onExport',
    'onImport',
    'onBackup',
    'onRestore',
    'onProcess',
    'onValidate',
    'onConfirm',
  };

  bool _isAsyncSuggestingName(String name) {
    // Direct match
    if (_asyncSuggestingNames.contains(name)) return true;

    // Check if name starts with an async-suggesting prefix
    // (e.g., onSubmitForm, onSaveData, onLoadUser)
    for (final String prefix in _asyncSuggestingPrefixes) {
      if (name.startsWith(prefix) && name.length > prefix.length) {
        // Check that next char is uppercase (proper camelCase)
        final String nextChar = name[prefix.length];
        if (nextChar == nextChar.toUpperCase() &&
            nextChar != nextChar.toLowerCase()) {
          return true;
        }
      }
    }

    return false;
  }

  bool _isVoidCallback(TypeAnnotation? type) {
    if (type == null) return false;
    final String typeStr = type.toSource();
    return typeStr == 'VoidCallback' || typeStr == 'VoidCallback?';
  }

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    // Check field declarations
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      final VariableDeclarationList fields = node.fields;
      final TypeAnnotation? type = fields.type;

      if (!_isVoidCallback(type)) return;

      for (final VariableDeclaration variable in fields.variables) {
        final String name = variable.name.lexeme;
        if (_isAsyncSuggestingName(name)) {
          reporter.atNode(type!, code);
          break; // Only report once per declaration
        }
      }
    });

    // Check parameter declarations (in constructors and functions)
    context.registry.addSimpleFormalParameter((SimpleFormalParameter node) {
      final TypeAnnotation? type = node.type;
      if (!_isVoidCallback(type)) return;

      final Token? nameToken = node.name;
      if (nameToken == null) return;

      final String name = nameToken.lexeme;
      if (_isAsyncSuggestingName(name)) {
        reporter.atNode(type!, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ChangeToFutureVoidFunctionFix()];
}

/// Quick fix that replaces `VoidCallback` with `Future<void> Function()`.
///
/// This fix is applied when the lint detects a VoidCallback used for a
/// callback name that suggests async behavior (e.g., onSubmit, onDelete).
class _ChangeToFutureVoidFunctionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String source = node.toSource();
      if (source != 'VoidCallback' && source != 'VoidCallback?') return;

      final bool isNullable = source.endsWith('?');
      final String replacement =
          isNullable ? 'Future<void> Function()?' : 'Future<void> Function()';

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to Future<void> Function()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }
}

/// Enforces using explicit Future-returning callbacks instead of AsyncCallback.
class PreferFutureVoidFunctionOverAsyncCallbackRule extends SaropaLintRule {
  const PreferFutureVoidFunctionOverAsyncCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  static const LintCode _code = LintCode(
    name: 'prefer_future_void_function_over_async_callback',
    problemMessage:
        'Prefer explicit Future<void> Function() instead of AsyncCallback.',
    correctionMessage:
        'Use Future<void> Function() to avoid Flutter-specific type dependencies.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedType((NamedType node) {
      final String source = node.toSource();
      if (source == 'AsyncCallback' || source == 'AsyncCallback?') {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() =>
      <Fix>[_ReplaceAsyncCallbackWithFutureVoidFunctionFix()];
}

class _ReplaceAsyncCallbackWithFutureVoidFunctionFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedType((NamedType node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final String source = node.toSource();
      if (source != 'AsyncCallback' && source != 'AsyncCallback?') return;

      final bool isNullable = source.endsWith('?');
      final String replacement =
          isNullable ? 'Future<void> Function()?' : 'Future<void> Function()';

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Change to Future<void> Function()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.sourceRange, replacement);
      });
    });
  }
}

/// Warns when Navigator.pop or context is used after await in a dialog callback.
///
/// After an async operation in a dialog, the dialog may have been dismissed
/// or the context may no longer be valid. Using context after await can crash.
///
/// **BAD:**
/// ```dart
/// onPressed: () async {
///   await saveData();
///   Navigator.pop(context);  // Context may be invalid!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// onPressed: () async {
///   await saveData();
///   if (context.mounted) {
///     Navigator.pop(context);
///   }
/// }
/// ```
class AvoidDialogContextAfterAsyncRule extends SaropaLintRule {
  const AvoidDialogContextAfterAsyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_dialog_context_after_async',
    problemMessage: 'Navigator.pop after await may use invalid context.',
    correctionMessage: 'Check context.mounted before using Navigator.pop.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Navigator.pop or Navigator.of(context).pop
      final String methodName = node.methodName.name;
      if (methodName != 'pop' && methodName != 'maybePop') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Navigator')) return;

      // Check if there's an await before this in the same function
      final FunctionBody? body = _findEnclosingFunctionBody(node);
      if (body == null) return;
      if (!body.isAsynchronous) return;

      // Check if there's an await expression before this node
      final bool hasAwaitBefore = _hasAwaitBefore(body, node);
      if (!hasAwaitBefore) return;

      // Check if there's a mounted check between the await and this
      final bool hasMountedCheck = _hasMountedCheckBefore(body, node);
      if (hasMountedCheck) return;

      reporter.atNode(node, code);
    });
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasAwaitBefore(FunctionBody body, AstNode target) {
    bool foundAwait = false;
    bool reachedTarget = false;

    body.visitChildren(_AwaitBeforeChecker((AwaitExpression awaitNode) {
      if (reachedTarget) return;
      if (awaitNode.offset < target.offset) {
        foundAwait = true;
      }
    }, () {
      reachedTarget = true;
    }, target));

    return foundAwait;
  }

  bool _hasMountedCheckBefore(FunctionBody body, AstNode target) {
    final String bodySource = body.toSource();
    final int targetOffset = target.offset - body.offset;

    // Check for mounted check patterns before the target
    final String beforeTarget = bodySource.substring(0, targetOffset);
    return beforeTarget.contains('.mounted') ||
        beforeTarget.contains('context.mounted') ||
        beforeTarget.contains('!mounted') ||
        beforeTarget.contains('if (mounted)') ||
        beforeTarget.contains('if (!mounted)');
  }
}

class _AwaitBeforeChecker extends RecursiveAstVisitor<void> {
  _AwaitBeforeChecker(this.onAwait, this.onReachTarget, this.target);

  final void Function(AwaitExpression) onAwait;
  final void Function() onReachTarget;
  final AstNode target;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onAwait(node);
    super.visitAwaitExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node == target) {
      onReachTarget();
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when setState or context is accessed after await without mounted check.
///
/// After an async gap, the widget may have been disposed. Calling setState
/// or using context without checking mounted will cause errors.
///
/// **BAD:**
/// ```dart
/// Future<void> _loadData() async {
///   final data = await fetchData();
///   setState(() => _data = data);  // Widget may be unmounted!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> _loadData() async {
///   final data = await fetchData();
///   if (mounted) {
///     setState(() => _data = data);
///   }
/// }
/// ```
class CheckMountedAfterAsyncRule extends SaropaLintRule {
  const CheckMountedAfterAsyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'check_mounted_after_async',
    problemMessage:
        'setState or context used after await without mounted check.',
    correctionMessage:
        'Add if (mounted) check before using setState or context.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for setState or context-using methods
      if (methodName != 'setState' &&
          methodName != 'showDialog' &&
          methodName != 'showModalBottomSheet' &&
          methodName != 'showSnackBar') {
        return;
      }

      // Find enclosing async function
      final FunctionBody? body = _findEnclosingFunctionBody(node);
      if (body == null) return;
      if (!body.isAsynchronous) return;

      // Check if there's an await before this
      if (!_hasAwaitBefore(body, node)) return;

      // Check for mounted check
      if (_hasMountedGuard(body, node)) return;

      reporter.atNode(node, code);
    });
  }

  FunctionBody? _findEnclosingFunctionBody(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is FunctionBody) return current;
      current = current.parent;
    }
    return null;
  }

  bool _hasAwaitBefore(FunctionBody body, AstNode target) {
    final String bodySource = body.toSource();
    final int targetOffset = target.offset - body.offset;
    final String beforeTarget = bodySource.substring(0, targetOffset);
    return beforeTarget.contains('await ');
  }

  bool _hasMountedGuard(FunctionBody body, AstNode target) {
    // Check if the target is inside an if statement checking mounted
    AstNode? current = target.parent;
    while (current != null && current != body) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (condition.contains('mounted')) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }
}

/// Warns when WebSocket message is handled without validation.
///
/// WebSocket messages from external sources should be validated
/// before processing to prevent security issues and crashes.
///
/// **BAD:**
/// ```dart
/// socket.listen((message) {
///   final data = jsonDecode(message);
///   processData(data['value']);  // No validation!
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// socket.listen((message) {
///   try {
///     final data = jsonDecode(message);
///     if (data is Map && data.containsKey('value')) {
///       processData(data['value']);
///     }
///   } catch (e) {
///     handleError(e);
///   }
/// });
/// ```
class RequireWebsocketMessageValidationRule extends SaropaLintRule {
  const RequireWebsocketMessageValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_websocket_message_validation',
    problemMessage: 'WebSocket message should be validated before processing.',
    correctionMessage:
        'Add try-catch and type checking for WebSocket messages.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for WebSocketChannel stream listen
      if (node.methodName.name != 'listen') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check for WebSocket-related patterns
      final String targetSource = target.toSource();
      if (!targetSource.contains('socket') &&
          !targetSource.contains('Socket') &&
          !targetSource.contains('channel') &&
          !targetSource.contains('Channel')) {
        return;
      }

      // Check the callback body for validation
      final ArgumentList args = node.argumentList;
      if (args.arguments.isEmpty) return;

      final Expression firstArg = args.arguments.first;
      if (firstArg is! FunctionExpression) return;

      final FunctionBody body = firstArg.body;
      final String bodySource = body.toSource();

      // Check for validation patterns
      final bool hasValidation = bodySource.contains('try') ||
          bodySource.contains('catch') ||
          bodySource.contains('is Map') ||
          bodySource.contains('is List') ||
          bodySource.contains('containsKey') ||
          bodySource.contains('?[') ||
          bodySource.contains('?.') ||
          bodySource.contains('if (');

      if (!hasValidation) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when feature flag is checked without a default/fallback value.
///
/// Feature flags may not be available (network issues, not loaded yet).
/// Always provide a default value for graceful degradation.
///
/// **BAD:**
/// ```dart
/// if (remoteConfig.getBool('new_feature')) {
///   // May throw if config not loaded!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// final isEnabled = remoteConfig.getBool('new_feature') ?? false;
/// if (isEnabled) {
///   // Safe with default
/// }
/// ```
class RequireFeatureFlagDefaultRule extends SaropaLintRule {
  const RequireFeatureFlagDefaultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_feature_flag_default',
    problemMessage: 'Feature flag should have a default/fallback value.',
    correctionMessage:
        'Use ?? operator or provide default in getBool/getString.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for RemoteConfig get methods
      final String methodName = node.methodName.name;
      if (!methodName.startsWith('get')) return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('remoteConfig') &&
          !targetSource.contains('RemoteConfig') &&
          !targetSource.contains('featureFlag') &&
          !targetSource.contains('FeatureFlag')) {
        return;
      }

      // Check if there's a null-aware operator or default
      final AstNode? parent = node.parent;

      // OK if used with ?? operator
      if (parent is BinaryExpression &&
          parent.operator.type == TokenType.QUESTION_QUESTION) {
        return;
      }

      // OK if passed to a parameter with default
      if (parent is NamedExpression) return;

      // OK if assigned to a variable with default
      if (parent is VariableDeclaration) return;

      reporter.atNode(node, code);
    });
  }
}

/// Warns when DateTime is stored without converting to UTC.
///
/// Storing local DateTime values causes inconsistency across time zones.
/// Always convert to UTC before storage and back to local for display.
///
/// **BAD:**
/// ```dart
/// await db.insert({'timestamp': DateTime.now().toIso8601String()});
/// ```
///
/// **GOOD:**
/// ```dart
/// await db.insert({'timestamp': DateTime.now().toUtc().toIso8601String()});
/// ```
class PreferUtcForStorageRule extends SaropaLintRule {
  const PreferUtcForStorageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_utc_for_storage',
    problemMessage: 'DateTime should be converted to UTC before storage.',
    correctionMessage: 'Call .toUtc() before storing DateTime values.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for toIso8601String or millisecondsSinceEpoch
      final String methodName = node.methodName.name;
      if (methodName != 'toIso8601String' &&
          methodName != 'toString' &&
          !methodName.contains('milliseconds') &&
          !methodName.contains('microseconds')) {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      // Check if called on DateTime
      final DartType? type = target.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!typeName.startsWith('DateTime')) return;

      // Check if already UTC
      final String targetSource = target.toSource();
      if (targetSource.contains('.toUtc()') || targetSource.contains('.utc')) {
        return;
      }

      // Check if inside a storage-related context
      AstNode? current = node.parent;
      while (current != null) {
        final String source = current.toSource().toLowerCase();
        if (source.contains('insert') ||
            source.contains('update') ||
            source.contains('save') ||
            source.contains('store') ||
            source.contains('write') ||
            source.contains('put') ||
            source.contains('set')) {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when location request is made without a timeout.
///
/// Location requests can hang indefinitely if GPS is unavailable.
/// Always specify a timeout to prevent blocking the UI.
///
/// **BAD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition();
/// ```
///
/// **GOOD:**
/// ```dart
/// final position = await Geolocator.getCurrentPosition(
///   timeLimit: Duration(seconds: 10),
/// );
/// ```
class RequireLocationTimeoutRule extends SaropaLintRule {
  const RequireLocationTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_location_timeout',
    problemMessage: 'Location request should have a timeout.',
    correctionMessage:
        'Add timeLimit or timeout parameter to location request.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for location-related methods
      final String methodName = node.methodName.name;
      if (!methodName.contains('Position') &&
          !methodName.contains('Location') &&
          !methodName.contains('location') &&
          methodName != 'getCurrentPosition' &&
          methodName != 'getLastKnownPosition' &&
          methodName != 'getLocation') {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Geolocator') &&
          !targetSource.contains('Location') &&
          !targetSource.contains('location')) {
        return;
      }

      // Check for timeout parameter
      bool hasTimeout = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'timeLimit' || name == 'timeout' || name == 'duration') {
            hasTimeout = true;
            break;
          }
        }
      }

      if (!hasTimeout) {
        reporter.atNode(node, code);
      }
    });
  }
}

// =============================================================================
// Part 5 Rules: Stream/Future Rules
// =============================================================================

/// Warns when StreamController is created inside build() method.
///
/// Creating streams in build causes them to be recreated on every rebuild,
/// leading to memory leaks and lost events.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final controller = StreamController<int>(); // Recreated every build!
///   return StreamBuilder(stream: controller.stream, ...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final StreamController<int> _controller;
///
/// void initState() {
///   super.initState();
///   _controller = StreamController<int>();
/// }
/// ```
class AvoidStreamInBuildRule extends SaropaLintRule {
  const AvoidStreamInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'avoid_stream_in_build',
    problemMessage:
        'StreamController created in build(). Will be recreated on every rebuild.',
    correctionMessage:
        'Create StreamController in initState() and store as field.',
    errorSeverity: DiagnosticSeverity.ERROR,
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
      if (!typeName.contains('StreamController')) return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node, code);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when StreamController is not closed in dispose().
///
/// StreamControllers must be closed to prevent memory leaks and
/// allow garbage collection.
///
/// **BAD:**
/// ```dart
/// final _controller = StreamController<int>();
/// // dispose() never closes it!
/// ```
///
/// **GOOD:**
/// ```dart
/// void dispose() {
///   _controller.close();
///   super.dispose();
/// }
/// ```
class RequireStreamControllerCloseRule extends SaropaLintRule {
  const RequireStreamControllerCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  static const LintCode _code = LintCode(
    name: 'require_stream_controller_close',
    problemMessage:
        'StreamController field without close() in dispose. Memory leak.',
    correctionMessage: 'Call controller.close() in dispose() method.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      // Find StreamController fields
      final List<VariableDeclaration> controllers = <VariableDeclaration>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeStr = member.fields.type?.toSource();
          if (typeStr != null && typeStr.contains('StreamController')) {
            for (final variable in member.fields.variables) {
              controllers.add(variable);
            }
          }
        }
      }

      if (controllers.isEmpty) return;

      // Check for dispose method with close() calls
      bool hasClose = false;

      for (final member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          final String? bodySource = member.body.toSource();
          if (bodySource != null && bodySource.contains('.close()')) {
            hasClose = true;
            break;
          }
        }
      }

      if (!hasClose) {
        for (final controller in controllers) {
          reporter.atNode(controller, code);
        }
      }
    });
  }
}

/// Warns when multiple listeners are added to a non-broadcast stream.
///
/// Regular streams can only have one listener. Adding multiple causes an error.
///
/// **BAD:**
/// ```dart
/// final stream = controller.stream;
/// stream.listen((data) => handleA(data));
/// stream.listen((data) => handleB(data)); // Error!
/// ```
///
/// **GOOD:**
/// ```dart
/// final stream = controller.stream.asBroadcastStream();
/// stream.listen((data) => handleA(data));
/// stream.listen((data) => handleB(data)); // OK
/// ```
class AvoidMultipleStreamListenersRule extends SaropaLintRule {
  const AvoidMultipleStreamListenersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_multiple_stream_listeners',
    problemMessage:
        'Multiple listen() on same stream. Non-broadcast streams only allow one listener.',
    correctionMessage: 'Use .asBroadcastStream() or share subscriptions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
      // Track stream.listen calls by target
      final Map<String, List<MethodInvocation>> listenCalls =
          <String, List<MethodInvocation>>{};

      _findListenCalls(node, (MethodInvocation call, String targetId) {
        listenCalls.putIfAbsent(targetId, () => <MethodInvocation>[]).add(call);
      });

      // Report streams with multiple listeners
      for (final entry in listenCalls.entries) {
        if (entry.value.length > 1) {
          // Report on second and subsequent listeners
          for (int i = 1; i < entry.value.length; i++) {
            reporter.atNode(entry.value[i], code);
          }
        }
      }
    });
  }

  void _findListenCalls(
    AstNode node,
    void Function(MethodInvocation, String) callback,
  ) {
    if (node is MethodInvocation && node.methodName.name == 'listen') {
      final Expression? target = node.target;
      if (target != null) {
        // Use target source as identifier
        callback(node, target.toSource());
      }
    }

    for (final child in node.childEntities) {
      if (child is AstNode) {
        _findListenCalls(child, callback);
      }
    }
  }
}

/// Warns when stream.listen() is called without onError handler.
///
/// Streams can emit errors. Unhandled errors cause uncaught exceptions.
///
/// **BAD:**
/// ```dart
/// stream.listen((data) => print(data));
/// ```
///
/// **GOOD:**
/// ```dart
/// stream.listen(
///   (data) => print(data),
///   onError: (error) => handleError(error),
/// );
/// ```
class RequireStreamErrorHandlingRule extends SaropaLintRule {
  const RequireStreamErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_stream_error_handling',
    problemMessage:
        'Stream.listen() without onError handler. Errors will be uncaught.',
    correctionMessage: 'Add onError callback to handle stream errors.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is a stream
      final Expression? target = node.target;
      if (target == null) return;

      final String? typeName = target.staticType?.element?.name;
      // Check type or source for stream indicators
      final String targetSource = target.toSource().toLowerCase();
      if (typeName != 'Stream' &&
          !targetSource.contains('stream') &&
          !targetSource.contains('controller')) {
        return;
      }

      // Check for onError parameter
      bool hasOnError = false;

      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onError') {
          hasOnError = true;
          break;
        }
      }

      if (!hasOnError) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when long-running Futures don't have a timeout.
///
/// Futures without timeouts can hang indefinitely, causing poor UX.
///
/// **BAD:**
/// ```dart
/// final result = await expensiveOperation();
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await expensiveOperation()
///     .timeout(Duration(seconds: 30));
/// ```
class RequireFutureTimeoutRule extends SaropaLintRule {
  const RequireFutureTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_future_timeout',
    problemMessage:
        'Long-running Future without timeout. May hang indefinitely.',
    correctionMessage: 'Add .timeout(Duration(...)) to prevent hanging.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // Methods that typically involve network or I/O
  static const Set<String> _longRunningMethods = <String>{
    'download',
    'upload',
    'fetch',
    'load',
    'sync',
    'process',
    'compute',
    'analyze',
    'convert',
    'export',
    'import',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAwaitExpression((AwaitExpression node) {
      final Expression expr = node.expression;
      if (expr is! MethodInvocation) return;

      final String methodName = expr.methodName.name.toLowerCase();

      // Check if method name suggests long-running operation
      bool isLongRunning = false;
      for (final pattern in _longRunningMethods) {
        if (methodName.contains(pattern)) {
          isLongRunning = true;
          break;
        }
      }

      if (!isLongRunning) return;

      // Check if .timeout() is called
      AstNode? parent = node.parent;
      while (parent != null) {
        if (parent is MethodInvocation && parent.methodName.name == 'timeout') {
          return; // Has timeout
        }
        if (parent is Statement) break;
        parent = parent.parent;
      }

      reporter.atNode(node, code);
    });
  }
}

/// Warns when Future.wait is used without error handling for partial failures.
///
/// When one Future in Future.wait fails, all results are lost by default.
/// Use eagerError: false to get partial results on failure.
///
/// **BAD:**
/// ```dart
/// final results = await Future.wait([
///   fetchUser(),
///   fetchPosts(),
///   fetchComments(),
/// ]);
/// ```
///
/// **GOOD:**
/// ```dart
/// final results = await Future.wait([
///   fetchUser(),
///   fetchPosts(),
///   fetchComments(),
/// ], eagerError: false);
/// ```
///
/// **ALSO GOOD:**
/// ```dart
/// // Handle each future individually
/// final results = await Future.wait([
///   fetchUser().catchError((_) => null),
///   fetchPosts().catchError((_) => []),
///   fetchComments().catchError((_) => []),
/// ]);
/// ```
class RequireFutureWaitErrorHandlingRule extends SaropaLintRule {
  const RequireFutureWaitErrorHandlingRule() : super(code: _code);

  /// Error handling - partial results lost on failure.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_future_wait_error_handling',
    problemMessage:
        'Future.wait without eagerError: false. Partial results lost on failure.',
    correctionMessage:
        'Add eagerError: false or wrap individual futures with catchError.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Future') return;

      if (node.methodName.name != 'wait') return;

      // Check for eagerError parameter
      bool hasEagerError = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'eagerError') {
          hasEagerError = true;
          break;
        }
      }

      if (!hasEagerError) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Stream is listened to without onDone handler.
///
/// Streams should handle completion to clean up resources
/// and update UI state appropriately.
///
/// **BAD:**
/// ```dart
/// stream.listen((data) {
///   updateUI(data);
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// stream.listen(
///   (data) => updateUI(data),
///   onDone: () => showCompleted(),
///   onError: (e) => showError(e),
/// );
/// ```
class RequireStreamOnDoneRule extends SaropaLintRule {
  const RequireStreamOnDoneRule() : super(code: _code);

  /// Resource cleanup and UX issue.
  @override
  LintImpact get impact => LintImpact.low;

  static const LintCode _code = LintCode(
    name: 'require_stream_on_done',
    problemMessage:
        'Stream.listen without onDone. Completion state not handled.',
    correctionMessage: 'Add onDone callback to handle stream completion.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is a stream
      final targetType = node.target?.staticType;
      if (targetType == null) return;

      final typeName = targetType.getDisplayString();
      if (!typeName.contains('Stream')) return;

      // Check for onDone parameter
      bool hasOnDone = false;
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onDone') {
          hasOnDone = true;
          break;
        }
      }

      if (!hasOnDone) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Completer is created but never completed in error paths.
///
/// Uncomopleted Completers can cause futures to hang forever.
/// Always complete with error in catch blocks.
///
/// **BAD:**
/// ```dart
/// Future<String> fetch() {
///   final completer = Completer<String>();
///   try {
///     completer.complete(await api.get());
///   } catch (e) {
///     // Completer never completed!
///   }
///   return completer.future;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String> fetch() {
///   final completer = Completer<String>();
///   try {
///     completer.complete(await api.get());
///   } catch (e) {
///     completer.completeError(e);
///   }
///   return completer.future;
/// }
/// ```
class RequireCompleterErrorHandlingRule extends SaropaLintRule {
  const RequireCompleterErrorHandlingRule() : super(code: _code);

  /// Bug - futures may hang indefinitely.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_completer_error_handling',
    problemMessage:
        'Completer in try-catch without completeError. May hang on error.',
    correctionMessage: 'Add completer.completeError(e) in catch block.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((node) {
      final typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Completer') return;

      // Find enclosing method
      AstNode? current = node.parent;
      MethodDeclaration? enclosingMethod;

      while (current != null) {
        if (current is MethodDeclaration) {
          enclosingMethod = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingMethod == null) return;

      final methodSource = enclosingMethod.toSource();

      // Check if method has try-catch
      if (!methodSource.contains('try') || !methodSource.contains('catch')) {
        return;
      }

      // Check if completeError is called
      if (!methodSource.contains('completeError')) {
        reporter.atNode(node, code);
      }
    });
  }
}
