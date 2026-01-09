// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

/// Warns when calling .ignore() on a Future.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureIgnoreRule extends SaropaLintRule {
  const AvoidFutureIgnoreRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_future_ignore',
    problemMessage: 'Future.ignore() silently discards errors. Failures will go unnoticed.',
    correctionMessage: 'Use await to handle, unawaited() if intentional, or add .catchError().',
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
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureToStringRule extends SaropaLintRule {
  const AvoidFutureToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_future_tostring',
    problemMessage: "Future.toString() returns 'Instance of Future', not the resolved value.",
    correctionMessage: 'Use await to get the value first: (await future).toString().',
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

  void _checkAsyncBody(FunctionBody body, AstNode node, SaropaDiagnosticReporter reporter) {
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
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidUnassignedStreamSubscriptionsRule extends SaropaLintRule {
  const AvoidUnassignedStreamSubscriptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_stream_subscriptions',
    problemMessage: 'Stream subscription not assigned. Cannot cancel it, causing memory leaks.',
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
class PreferAssigningAwaitExpressionsRule extends SaropaLintRule {
  const PreferAssigningAwaitExpressionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_assigning_await_expressions',
    problemMessage: 'Inline await expression. Harder to debug and inspect intermediate values.',
    correctionMessage: 'Extract to variable: final result = await fetch(); then use result.',
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
      if (parent is ListLiteral || parent is SetOrMapLiteral || parent is MapLiteralEntry) {
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
class PreferCorrectStreamReturnTypeRule extends SaropaLintRule {
  const PreferCorrectStreamReturnTypeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'prefer_correct_stream_return_type',
    problemMessage: 'Async* function should have Stream return type annotation.',
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
    context.registry.addInstanceCreationExpression((InstanceCreationExpression node) {
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
    problemMessage: 'Return await in async functions for proper error handling.',
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
    problemMessage: 'VoidCallback discards Futures silently. Errors will be swallowed and '
        'callers cannot await completion.',
    correctionMessage: 'Use Future<void> Function() to allow proper async handling.',
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
        if (nextChar == nextChar.toUpperCase() && nextChar != nextChar.toLowerCase()) {
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
    problemMessage: 'Prefer explicit Future<void> Function() instead of AsyncCallback.',
    correctionMessage: 'Use Future<void> Function() to avoid Flutter-specific type dependencies.',
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
  List<Fix> getFixes() => <Fix>[_ReplaceAsyncCallbackWithFutureVoidFunctionFix()];
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
