// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when calling .ignore() on a Future.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureIgnoreRule extends DartLintRule {
  const AvoidFutureIgnoreRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_future_ignore',
    problemMessage: 'Avoid using .ignore() on Futures.',
    correctionMessage:
        'Handle the Future properly with await, then, or unawaited().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidFutureToStringRule extends DartLintRule {
  const AvoidFutureToStringRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_future_tostring',
    problemMessage: 'Avoid calling toString() on a Future.',
    correctionMessage: 'Await the Future before converting to string.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidNestedFuturesRule extends DartLintRule {
  const AvoidNestedFuturesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nested_futures',
    problemMessage: 'Avoid nested Future types (Future<Future<T>>).',
    correctionMessage: 'Flatten to Future<T> or use async/await properly.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidNestedStreamsAndFuturesRule extends DartLintRule {
  const AvoidNestedStreamsAndFuturesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_nested_streams_and_futures',
    problemMessage: 'Avoid mixing Stream and Future in nested types.',
    correctionMessage: 'Use async*/await patterns instead of nested types.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class AvoidPassingAsyncWhenSyncExpectedRule extends DartLintRule {
  const AvoidPassingAsyncWhenSyncExpectedRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_passing_async_when_sync_expected',
    problemMessage: 'Async function passed where sync function expected.',
    correctionMessage: 'Ensure the caller handles the returned Future.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFunctionExpression((FunctionExpression node) {
      // Check if function is async
      if (node.body.isAsynchronous) {
        final AstNode? parent = node.parent;
        // Check if passed as argument
        if (parent is ArgumentList) {
          final AstNode? grandparent = parent.parent;
          if (grandparent is MethodInvocation ||
              grandparent is InstanceCreationExpression) {
            // Warn when async callback is passed as argument
            // Full implementation would check if parameter type expects Future
            reporter.atNode(node, code);
          }
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
class AvoidRedundantAsyncRule extends DartLintRule {
  const AvoidRedundantAsyncRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_redundant_async',
    problemMessage: 'Async function does not use await.',
    correctionMessage: 'Remove async keyword or add await expression.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
      FunctionBody body, AstNode node, DiagnosticReporter reporter) {
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
class AvoidStreamToStringRule extends DartLintRule {
  const AvoidStreamToStringRule() : super(code: _code);

  // cspell:ignore tostring
  static const LintCode _code = LintCode(
    name: 'avoid_stream_tostring',
    problemMessage: 'Stream.toString() returns unhelpful output.',
    correctionMessage: 'Use stream.toList() or iterate over the stream.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      // Check if target looks like a Stream
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (targetSource.contains('stream')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddHackForStreamToStringFix()];
}

/// Warns when .listen() result is not assigned to a variable.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidUnassignedStreamSubscriptionsRule extends DartLintRule {
  const AvoidUnassignedStreamSubscriptionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unassigned_stream_subscriptions',
    problemMessage: 'Stream subscription should be assigned to a variable.',
    correctionMessage: 'Assign the subscription to cancel it later.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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

/// Warns when .then() is used instead of async/await.
///
/// Using async/await is generally more readable than .then() chains.
class PreferAsyncAwaitRule extends DartLintRule {
  const PreferAsyncAwaitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_async_await',
    problemMessage: "Prefer 'async/await' over '.then()'.",
    correctionMessage: 'Refactor to use async/await syntax.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name == 'then') {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when await is used inline instead of assigning to a variable first.
class PreferAssigningAwaitExpressionsRule extends DartLintRule {
  const PreferAssigningAwaitExpressionsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_assigning_await_expressions',
    problemMessage: 'Prefer assigning await expressions to variables.',
    correctionMessage:
        'Assign the await expression to a variable before using it.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferCommentingFutureDelayedRule extends DartLintRule {
  const PreferCommentingFutureDelayedRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_commenting_future_delayed',
    problemMessage: 'Future.delayed should have a comment explaining why.',
    correctionMessage: 'Add a comment before the delay explaining its purpose.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for Future.delayed
      final Expression? target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Future') return;
      if (node.methodName.name != 'delayed') return;

      // Check if there's a comment before this statement
      final Token firstToken = node.beginToken;
      Token? prevToken = firstToken.previous;

      // Look for preceding comment
      bool hasComment = false;
      while (prevToken != null) {
        if (prevToken.type == TokenType.SINGLE_LINE_COMMENT ||
            prevToken.type == TokenType.MULTI_LINE_COMMENT) {
          hasComment = true;
          break;
        }
        // Stop if we hit a non-comment, non-whitespace token
        if (prevToken.type != TokenType.EOF) {
          break;
        }
        prevToken = prevToken.previous;
      }

      // Check preceding comments attached to the token
      CommentToken? comment = firstToken.precedingComments;
      while (comment != null) {
        hasComment = true;
        comment = comment.next as CommentToken?;
      }

      if (!hasComment) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when Future-returning functions have incorrect return type annotations.
class PreferCorrectFutureReturnTypeRule extends DartLintRule {
  const PreferCorrectFutureReturnTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_future_return_type',
    problemMessage: 'Async function should have Future return type annotation.',
    correctionMessage: 'Add explicit Future<T> return type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
    DiagnosticReporter reporter,
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
class PreferCorrectStreamReturnTypeRule extends DartLintRule {
  const PreferCorrectStreamReturnTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_correct_stream_return_type',
    problemMessage:
        'Async* function should have Stream return type annotation.',
    correctionMessage: 'Add explicit Stream<T> return type.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
    DiagnosticReporter reporter,
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
class PreferSpecifyingFutureValueTypeRule extends DartLintRule {
  const PreferSpecifyingFutureValueTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_specifying_future_value_type',
    problemMessage: 'Specify type argument for Future.value().',
    correctionMessage: 'Add explicit type: Future<Type>.value(...).',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
class PreferReturnAwaitRule extends DartLintRule {
  const PreferReturnAwaitRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_return_await',
    problemMessage:
        'Return await in async functions for proper error handling.',
    correctionMessage: 'Add await before the returned Future.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
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
        message: 'Add HACK comment for Future.ignore()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: handle this Future properly with await or unawaited()\n',
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
        message: 'Add HACK comment for Future.toString()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: await the Future before converting to string\n',
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
        message: 'Add HACK comment for nested Future',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: flatten nested Future */ ',
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
        message: 'Add HACK comment for nested Stream/Future',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: avoid mixing Stream and Future */ ',
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
        message: 'Add HACK comment for async callback',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '/* HACK: async callback - ensure caller handles Future */ ',
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
        message: 'Add HACK comment for Stream.toString()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: use stream.toList() or iterate instead of toString()\n',
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
        message: 'Add HACK comment for unassigned subscription',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: assign subscription to cancel later\n',
        );
      });
    });
  }
}
