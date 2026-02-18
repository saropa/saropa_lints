// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';

import '../saropa_lint_rule.dart';
import '../fixes/async/avoid_redundant_async_fix.dart';
import '../fixes/async/change_to_future_void_function_fix.dart';
import '../fixes/async/replace_async_callback_with_future_void_function_fix.dart';
import '../fixes/async/add_to_utc_fix.dart';

/// Warns when calling .ignore() on a Future.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: no_future_ignore, future_ignore_error, silent_future_discard
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureIgnoreRule extends SaropaLintRule {
  AvoidFutureIgnoreRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_future_ignore',
    '[avoid_future_ignore] Calling Future.ignore() discards all errors and exceptions from the Future, causing failures to go unnoticed. This can result in silent bugs, missed exceptions, and unreliable app behavior, especially in production where error reporting is critical. {v6}',
    correctionMessage:
        'Use await to handle the Future, unawaited() if you intentionally ignore it, or add .catchError() to log or handle errors. Never ignore errors in production code.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'ignore') return;

      // Check if this is likely called on a Future
      final Expression? target = node.target;
      if (target == null) return;

      // Check the static type if available
      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when calling toString() or using string interpolation on a Future.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Alias: no_future_tostring, future_to_string, await_before_tostring
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidFutureToStringRule extends SaropaLintRule {
  AvoidFutureToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_future_tostring',
    "[avoid_future_tostring] Future.toString() returns 'Instance of Future', not the resolved value. Logs show useless output, error messages fail to include actual data, and debugging async code becomes nearly impossible. {v7}",
    correctionMessage:
        'Use await to get the resolved value first: (await future).toString(). Only call toString() after the Future has completed to log meaningful information.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      final Expression? target = node.target;
      if (target == null) return;

      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node);
        }
      }
    });

    context.addInterpolationExpression((InterpolationExpression node) {
      final Expression expr = node.expression;
      final DartType? type = expr.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Future')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when `Future<Future<T>>` is used (nested futures).
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidNestedFuturesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nested_futures',
    '[avoid_nested_futures] Future<Future<T>> detected. Outer Future resolves to inner Future, not value - requires double await. Consequence: This pattern makes code harder to read, maintain, and debug, and can introduce subtle async bugs and runtime errors. {v4}',
    correctionMessage:
        'Flatten to Future<T>. If returning async result, just return it directly without wrapping.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      if (node.name.lexeme == 'Future') {
        final TypeArgumentList? typeArgs = node.typeArguments;
        if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
          final TypeAnnotation innerType = typeArgs.arguments.first;
          if (innerType is NamedType && innerType.name.lexeme == 'Future') {
            reporter.atNode(node);
          }
        }
      }
    });
  }
}

/// Warns when `Stream<Future<T>>` or `Future<Stream<T>>` is used.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  AvoidNestedStreamsAndFuturesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_nested_streams_and_futures',
    '[avoid_nested_streams_and_futures] Stream<Future<T>> or Future<Stream<T>> detected. Complex to consume - each item needs await or stream needs await. This increases cognitive load and can lead to memory leaks, unclosed stream subscriptions, or missed events. {v4}',
    correctionMessage:
        'Flatten the nested type by using an async* generator function or Stream.asyncMap() to produce a simpler type.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when an async function is passed where a sync function is expected.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Alias: async_callback_in_sync, async_where_sync_expected, ignored_future_return
///
/// Passing an async function to a parameter expecting a synchronous function
/// can lead to unexpected behavior where the returned Future is ignored.
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidPassingAsyncWhenSyncExpectedRule extends SaropaLintRule {
  AvoidPassingAsyncWhenSyncExpectedRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.test};

  static const LintCode _code = LintCode(
    'avoid_passing_async_when_sync_expected',
    '[avoid_passing_async_when_sync_expected] Async callback passed to a sync-only method such as forEach, map, or where. The returned Future is silently discarded, which means any errors thrown inside the callback are lost and never reported. This makes debugging extremely difficult and can hide critical failures in your application logic. {v4}',
    correctionMessage:
        'Use Future.wait() with map(), or for-loop with await, instead of forEach/where/etc.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionExpression((FunctionExpression node) {
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
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when async is used but no await is present in the function body.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v7
///
/// Alias: unnecessary_async, async_without_await, remove_async, require_await_in_async
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
  AvoidRedundantAsyncRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            AvoidRedundantAsyncFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'avoid_redundant_async',
    '[avoid_redundant_async] Declaring a function async without using await adds unnecessary Future wrapping and microtask scheduling overhead. This can make code harder to read, debug, and maintain, and may introduce subtle timing bugs. {v7}',
    correctionMessage:
        'Remove the async keyword if not needed, or add await if asynchronous behavior is required. Keep code clean and efficient.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncBody(node.functionExpression.body, node, reporter);
    });

    context.addMethodDeclaration((MethodDeclaration node) {
      _checkAsyncBody(node.body, node, reporter);
    });
  }

  void _checkAsyncBody(
    FunctionBody body,
    AstNode node,
    SaropaDiagnosticReporter reporter,
  ) {
    // Only check async functions (not async*)
    if (body.isAsynchronous && !body.isGenerator) {
      // Check if body contains any await expressions
      final bool hasAwait = _containsAwait(body);
      if (!hasAwait) {
        reporter.atNode(node);
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

// cspell:ignore tolist

/// Warns when a Stream is converted to String via toString().
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
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
  AvoidStreamToStringRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  // cspell:ignore tostring
  static const LintCode _code = LintCode(
    'avoid_stream_tostring',
    "[avoid_stream_tostring] Calling toString() on a Stream returns only the type name (e.g., 'Instance of Stream'), not the actual stream data. This leads to data loss and can mislead developers or users expecting meaningful output. {v5}",
    correctionMessage:
        'Use await stream.toList() to collect all values, or listen() to process stream data. Never rely on toString() for stream contents.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'toString') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Use staticType instead of string matching to avoid false positives
      // on variables like "upstream", "streamlined", etc.
      final DartType? type = target.staticType;
      if (type != null) {
        final String typeName = type.getDisplayString();
        if (typeName.startsWith('Stream')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when .listen() result is not assigned to a variable.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: require_stream_subscription_cancel
///
/// **Quick fix available:** Adds a comment to flag for manual review.
class AvoidUnassignedStreamSubscriptionsRule extends SaropaLintRule {
  AvoidUnassignedStreamSubscriptionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unassigned_stream_subscriptions',
    '[avoid_unassigned_stream_subscriptions] Stream subscription created by listen() is not assigned to a variable. Without a reference to the StreamSubscription, you cannot cancel it during dispose, which causes memory leaks, prevents garbage collection, and allows callbacks to fire after the StatefulWidget has been destroyed and unmounted from the widget tree. {v5}',
    correctionMessage:
        'Assign to variable: final sub = stream.listen(...); then sub.cancel() in dispose.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when .then() is used instead of async/await in async functions.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: use_async_await, then_to_await, avoid_then_chain
///
/// Using async/await is generally more readable than .then() chains.
/// Only flags .then() when used inside an async function where await
/// could be used instead.
class PreferAsyncAwaitRule extends SaropaLintRule {
  PreferAsyncAwaitRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_async_await',
    "[prefer_async_await] Using .then() inside an async function can hide errors in nested callbacks and makes code harder to debug, trace, and maintain. This can lead to missed exceptions and subtle bugs in complex async flows. {v6}",
    correctionMessage:
        'Refactor to use async/await syntax for clearer error handling and more readable code.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: prefer_await_completion, inline_await, extract_await, await_variable
class PreferAssigningAwaitExpressionsRule extends SaropaLintRule {
  PreferAssigningAwaitExpressionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_assigning_await_expressions',
    '[prefer_assigning_await_expressions] Inline await expression. Harder to debug and inspect intermediate values. Consequence: Extracting to a variable improves readability, makes debugging easier, and helps catch errors sooner. {v5}',
    correctionMessage:
        'Extract the await expression to a named variable: final result = await fetch(); then use result in subsequent code.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAwaitExpression((AwaitExpression node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Future.delayed doesn't have a comment explaining why.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
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
  PreferCommentingFutureDelayedRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_commenting_future_delayed',
    '[prefer_commenting_future_delayed] Unexplained delay is a code smell '
        'that often hides race conditions or timing bugs. {v4}',
    correctionMessage: 'Add a comment before the delay explaining its purpose.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Future-returning functions have incorrect return type annotations.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: async_return_type, future_return_type, explicit_future_type
class PreferCorrectFutureReturnTypeRule extends SaropaLintRule {
  PreferCorrectFutureReturnTypeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'prefer_correct_future_return_type',
    '[prefer_correct_future_return_type] Missing Future return type causes '
        'callers to handle dynamic, losing type safety and IDE support. {v3}',
    correctionMessage: 'Add explicit Future<T> return type.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncFunction(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
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
      reporter.atToken(nameToken);
      return;
    }

    final String typeStr = returnType.toSource();
    if (!typeStr.startsWith('Future')) {
      reporter.atNode(returnType);
    }
  }
}

/// Warns when Stream-returning functions have incorrect return type annotations.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: async_star_return_type, stream_return_type, explicit_stream_type
class PreferCorrectStreamReturnTypeRule extends SaropaLintRule {
  PreferCorrectStreamReturnTypeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_correct_stream_return_type',
    '[prefer_correct_stream_return_type] Missing Stream return type causes '
        'listeners to receive dynamic, losing type safety and IDE support. {v5}',
    correctionMessage: 'Add explicit Stream<T> return type.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkAsyncStarFunction(
        node.functionExpression.body,
        node.returnType,
        node.name,
        reporter,
      );
    });

    context.addMethodDeclaration((MethodDeclaration node) {
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
      reporter.atToken(nameToken);
      return;
    }

    final String typeStr = returnType.toSource();
    if (!typeStr.startsWith('Stream')) {
      reporter.atNode(returnType);
    }
  }
}

/// Warns when Future.value() is called without explicit type argument.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
class PreferSpecifyingFutureValueTypeRule extends SaropaLintRule {
  PreferSpecifyingFutureValueTypeRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_specifying_future_value_type',
    '[prefer_specifying_future_value_type] Calling Future.value() without specifying a type returns Future<dynamic>, which loses compile-time safety. This can lead to type errors, runtime bugs, and code that is harder to maintain and refactor. {v5}',
    correctionMessage:
        'Always specify the value type explicitly: Future<Type>.value(...). This improves type safety and code clarity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final ConstructorName constructorName = node.constructorName;
      final NamedType type = constructorName.type;

      // Check for Future.value constructor
      if (type.name.lexeme != 'Future') return;
      if (constructorName.name?.name != 'value') return;

      // Check if type arguments are specified
      if (type.typeArguments == null) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a Future is returned without await in an async function.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
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
  PreferReturnAwaitRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'prefer_return_await',
    '[prefer_return_await] Returning a Future directly from an async function skips error propagation and stack trace preservation, making debugging harder. This can hide the source of exceptions and complicate error handling. {v6}',
    correctionMessage:
        'Use return await to ensure errors are properly propagated and stack traces are preserved in async functions.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addReturnStatement((ReturnStatement node) {
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
        reporter.atNode(node);
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
///
/// Since: v1.4.0 | Updated: v4.13.0 | Rule version: v4
///
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
  PreferAsyncCallbackRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            ChangeToFutureVoidFunctionFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'prefer_async_callback',
    '[prefer_async_callback] VoidCallback discards Futures silently. Errors will be swallowed and '
        'callers cannot await completion. {v4}',
    correctionMessage:
        'Use Future<void> Function() to allow proper async handling.',
    severity: DiagnosticSeverity.INFO,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check field declarations
    context.addFieldDeclaration((FieldDeclaration node) {
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
    context.addSimpleFormalParameter((SimpleFormalParameter node) {
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
}

/// Quick fix that replaces `VoidCallback` with `Future<void> Function()`.
///
/// This fix is applied when the lint detects a VoidCallback used for a
/// callback name that suggests async behavior (e.g., onSubmit, onDelete).

/// Enforces using explicit Future-returning callbacks instead of AsyncCallback.
///
/// Since: v1.7.5 | Updated: v4.13.0 | Rule version: v3
class PreferFutureVoidFunctionOverAsyncCallbackRule extends SaropaLintRule {
  PreferFutureVoidFunctionOverAsyncCallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            ReplaceAsyncCallbackWithFutureVoidFunctionFix(context: context),
      ];

  static const LintCode _code = LintCode(
    'prefer_future_void_function_over_async_callback',
    '[prefer_future_void_function_over_async_callback] Prefer explicit Future<void> Function() instead of AsyncCallback. Enforces using explicit Future-returning callbacks instead of AsyncCallback. {v3}',
    correctionMessage:
        'Use Future<void> Function() instead of AsyncCallback to keep the signature framework-agnostic and self-documenting.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedType((NamedType node) {
      final String source = node.toSource();
      if (source == 'AsyncCallback' || source == 'AsyncCallback?') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Navigator.pop or context is used after await in a dialog callback.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v5
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
  AvoidDialogContextAfterAsyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_dialog_context_after_async',
    '[avoid_dialog_context_after_async] If you call Navigator.pop() or use BuildContext after an await, the widget may have been disposed, causing a "Looking up deactivated widget" crash. This leads to app instability and poor user experience. {v5}',
    correctionMessage:
        'Always check if (context.mounted) before using BuildContext or Navigator.pop() after an await to prevent crashes.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for Navigator.pop or Navigator.of(context).pop
      final String methodName = node.methodName.name;
      if (methodName != 'pop' && methodName != 'maybePop') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Navigator' &&
          !targetSource.startsWith('Navigator.')) {
        return;
      }

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

      reporter.atNode(node);
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

    body.visitChildren(
      _AwaitBeforeChecker(
        (AwaitExpression awaitNode) {
          if (reachedTarget) return;
          if (awaitNode.offset < target.offset) {
            foundAwait = true;
          }
        },
        () {
          reachedTarget = true;
        },
        target,
      ),
    );

    return foundAwait;
  }

  bool _hasMountedCheckBefore(FunctionBody body, AstNode target) {
    final String bodySource = body.toSource();
    final int targetOffset = target.offset - body.offset;

    // Ensure we don't exceed the string bounds - toSource() may produce
    // a different length string than the original source
    if (targetOffset <= 0 || targetOffset > bodySource.length) {
      // Search the entire body if offset is out of bounds
      return bodySource.contains('.mounted') ||
          bodySource.contains('context.mounted') ||
          bodySource.contains('!mounted') ||
          bodySource.contains('if (mounted)') ||
          bodySource.contains('if (!mounted)');
    }

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
/// Since: v4.0.1 | Updated: v4.14.4 | Rule version: v5
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
///
/// **GOOD (early-return guard):**
/// ```dart
/// Future<void> _loadData() async {
///   final data = await fetchData();
///   if (!mounted) return;
///   setState(() => _data = data);
/// }
/// ```
class CheckMountedAfterAsyncRule extends SaropaLintRule {
  CheckMountedAfterAsyncRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'check_mounted_after_async',
    '[check_mounted_after_async] setState() after await without mounted check. '
        'State may be disposed during async gap, causing "setState() called after dispose()" crash. {v5}',
    correctionMessage:
        'Add if (mounted) { setState(...) } or if (!mounted) return; before the call.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
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

    body.visitChildren(
      _AwaitBeforeChecker(
        (AwaitExpression awaitNode) {
          if (reachedTarget) return;
          if (awaitNode.offset < target.offset) {
            // Skip the target's own await (e.g., `await showDialog(...)`)
            if (awaitNode.expression == target) return;
            foundAwait = true;
          }
        },
        () {
          reachedTarget = true;
        },
        target,
      ),
    );

    return foundAwait;
  }

  bool _hasMountedGuard(FunctionBody body, AstNode target) {
    // Check 1: Is the target inside a wrapping if-mounted block?
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

    // Check 2: Is there an early-return mounted guard before the target?
    // Walk up from target to find each enclosing block, checking for guards
    // at each level (handles nested blocks like if-statements).
    AstNode? node = target;
    while (node != null && node != body) {
      final AstNode? parent = node.parent;
      if (parent is Block) {
        if (_hasEarlyReturnGuardInBlock(parent, node)) {
          return true;
        }
      }
      node = parent;
    }

    return false;
  }

  /// Checks if [block] contains an early-return mounted guard before [target].
  /// An early-return guard is: `if (!mounted) return;` or similar.
  /// The guard is only valid if there is no await between it and the target.
  bool _hasEarlyReturnGuardInBlock(Block block, AstNode target) {
    for (final Statement statement in block.statements) {
      // Stop when we reach or pass the target statement
      if (statement.offset >= target.offset) break;

      if (statement is! IfStatement) continue;

      final String condition = statement.expression.toSource();
      if (!condition.contains('mounted')) continue;
      if (!_containsEarlyExit(statement.thenStatement)) continue;

      // Guard found — check no await exists between guard and target
      if (!_hasAwaitInRange(block, statement.end, target.offset)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if the statement unconditionally exits (return/throw).
  bool _containsEarlyExit(Statement statement) {
    if (statement is ReturnStatement) return true;
    if (statement is ExpressionStatement &&
        statement.expression is ThrowExpression) {
      return true;
    }
    if (statement is Block) {
      return statement.statements.any(
        (Statement s) =>
            s is ReturnStatement ||
            (s is ExpressionStatement && s.expression is ThrowExpression),
      );
    }
    return false;
  }

  /// Returns true if any await expression exists in [body] between
  /// [startOffset] and [endOffset].
  bool _hasAwaitInRange(AstNode body, int startOffset, int endOffset) {
    bool found = false;
    body.visitChildren(
      _AwaitRangeChecker((AwaitExpression awaitNode) {
        if (found) return;
        if (awaitNode.offset >= startOffset && awaitNode.offset < endOffset) {
          found = true;
        }
      }),
    );
    return found;
  }
}

/// Visitor that finds await expressions and calls a callback for each.
class _AwaitRangeChecker extends RecursiveAstVisitor<void> {
  _AwaitRangeChecker(this.onAwait);

  final void Function(AwaitExpression) onAwait;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    onAwait(node);
    super.visitAwaitExpression(node);
  }
}

/// Warns when WebSocket message is handled without validation.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireWebsocketMessageValidationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_websocket_message_validation',
    '[require_websocket_message_validation] Unvalidated WebSocket messages '
        'crash when malformed data arrives, or enable injection attacks. {v3}',
    correctionMessage:
        'Add try-catch and type checking for WebSocket messages.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for WebSocketChannel stream listen
      if (node.methodName.name != 'listen') return;

      final Expression? target = node.target;
      if (target == null) return;

      // Check for WebSocket-related patterns
      final String targetSource = target.toSource();
      if (!targetSource.endsWith('socket') &&
          !targetSource.endsWith('Socket') &&
          !targetSource.endsWith('channel') &&
          !targetSource.endsWith('Channel')) {
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
      final bool hasValidation =
          bodySource.contains('try') ||
          bodySource.contains('catch') ||
          bodySource.contains('is Map') ||
          bodySource.contains('is List') ||
          bodySource.contains('containsKey') ||
          bodySource.contains('?[') ||
          bodySource.contains('?.') ||
          bodySource.contains('if (');

      if (!hasValidation) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when feature flag is checked without a default/fallback value.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireFeatureFlagDefaultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_feature_flag_default',
    '[require_feature_flag_default] Missing default causes null/zero when '
        'remote config fetch fails, breaking expected feature behavior. {v3}',
    correctionMessage:
        'Use ?? operator or provide default in getBool/getString.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when DateTime is stored or serialized without converting to UTC.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Local DateTime values contain timezone offset information that becomes
/// invalid when restored in a different timezone. A timestamp saved as
/// "2024-01-15T14:30:00" in New York will be interpreted as 2:30 PM local
/// time when read in London, causing a 5-hour discrepancy. This affects
/// database storage, JSON serialization, SharedPreferences, and any
/// persistence mechanism.
///
/// The rule detects DateTime serialization methods (`toIso8601String()`,
/// `millisecondsSinceEpoch`, `microsecondsSinceEpoch`) when used inside
/// storage contexts (database operations, JSON serialization, caching).
///
/// **Quick fix available:** Inserts `.toUtc()` before the serialization call.
///
/// **BAD:**
/// ```dart
/// // Database storage
/// await db.insert({'timestamp': DateTime.now().toIso8601String()});
///
/// // JSON serialization
/// Map<String, dynamic> toJson() => {'created': createdAt.toIso8601String()};
///
/// // SharedPreferences
/// prefs.setString('lastSync', DateTime.now().toIso8601String());
/// ```
///
/// **GOOD:**
/// ```dart
/// // Database storage - UTC for consistency
/// await db.insert({'timestamp': DateTime.now().toUtc().toIso8601String()});
///
/// // JSON serialization - UTC for API exchange
/// Map<String, dynamic> toJson() => {'created': createdAt.toUtc().toIso8601String()};
///
/// // SharedPreferences - UTC for cross-device sync
/// prefs.setString('lastSync', DateTime.now().toUtc().toIso8601String());
/// ```
class PreferUtcForStorageRule extends SaropaLintRule {
  PreferUtcForStorageRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
        ({required CorrectionProducerContext context}) =>
            AddToUtcFix(context: context),
      ];

  // No applicableFileTypes override: DateTime storage patterns appear in models,
  // services, repositories, widgets, and utilities. Early-exit guards on method
  // name and type provide efficient filtering without missing real violations.

  static const LintCode _code = LintCode(
    'prefer_utc_for_storage',
    '[prefer_utc_for_storage] Local time stored without UTC conversion '
        'causes incorrect values when restored in different timezones. {v4}',
    correctionMessage: 'Call .toUtc() before storing DateTime values.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Storage and serialization patterns that indicate DateTime persistence.
  // Uses word boundaries (\b) to avoid false positives like 'edgeInsets',
  // 'offset', 'subset', etc.
  //
  // Categories:
  // - Database ops: insert, update, save, store, write, put
  // - Serialization: toJson, toMap, serialize, encode
  // - Caching: cache, persist
  // - Key-value storage: .setItem, .setString, .setData (requires dot prefix
  //   to avoid matching unrelated 'set' methods like setState)
  static final List<RegExp> _storagePatterns = <RegExp>[
    // Database operations
    RegExp(r'\binsert\w*\s*\(', caseSensitive: false),
    RegExp(r'\bupdate\w*\s*\(', caseSensitive: false),
    RegExp(r'\bsave\w*\s*\(', caseSensitive: false),
    RegExp(r'\bstore\w*\s*\(', caseSensitive: false),
    RegExp(r'\bwrite\w*\s*\(', caseSensitive: false),
    RegExp(r'\bput\w*\s*\(', caseSensitive: false),
    // Serialization methods
    RegExp(r'\btoJson\w*\s*\(', caseSensitive: false),
    RegExp(r'\btoMap\w*\s*\(', caseSensitive: false),
    RegExp(r'\bserialize\w*\s*\(', caseSensitive: false),
    RegExp(r'\bencode\w*\s*\(', caseSensitive: false),
    // Caching and persistence
    RegExp(r'\bcache\w*\s*\(', caseSensitive: false),
    RegExp(r'\bpersist\w*\s*\(', caseSensitive: false),
    // Key-value storage APIs (SharedPreferences, localStorage, etc.)
    // Requires dot prefix to avoid matching setState, setRange, etc.
    RegExp(r'\.set\w*\s*\(', caseSensitive: false),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Check for DateTime serialization methods commonly used for storage.
      // Excludes toString() - it's rarely used for actual storage and mostly
      // appears in logging/debugging, which would generate false positives.
      final String methodName = node.methodName.name;
      if (methodName != 'toIso8601String' &&
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
        final String source = current.toSource();
        for (final pattern in _storagePatterns) {
          if (pattern.hasMatch(source)) {
            reporter.atNode(node);
            return;
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Quick fix for [PreferUtcForStorageRule] that inserts `.toUtc()` before
/// the serialization method call.

/// Warns when location request is made without a timeout.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireLocationTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_location_timeout',
    '[require_location_timeout] Location request without timeout can hang '
        'indefinitely if GPS is unavailable, freezing the app. {v3}',
    correctionMessage:
        'Add timeLimit or timeout parameter to location request.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Methods that actually request GPS coordinates.
  static const Set<String> _gpsRequestMethods = {
    'getCurrentPosition',
    'getLastKnownPosition',
    'getLocation',
    'getPositionStream',
    'requestPosition',
  };

  /// Classes that own GPS-requesting methods.
  static const Set<String> _gpsRequestTargets = {
    'Geolocator',
    'Location', // from location package
  };

  /// Named args that indicate a timeout is configured.
  static const Set<String> _timeoutArgNames = {
    'timeLimit',
    'timeout',
    'duration',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_gpsRequestMethods.contains(methodName)) return;

      final Expression? target = node.target;
      if (target == null) return;

      // Match exact class name, not substrings
      final String targetName = _extractTargetName(target);
      if (!_gpsRequestTargets.contains(targetName)) return;

      // Check for timeout in direct arguments
      if (_hasTimeoutArg(node)) return;

      // Check for chained .timeout() on the returned Future
      if (_hasChainedTimeout(node)) return;

      reporter.atNode(node);
    });
  }

  /// Extracts the simple class/identifier name from the call target,
  /// ignoring instance chains like `widget.geolocator`.
  static String _extractTargetName(Expression target) {
    if (target is SimpleIdentifier) return target.name;
    if (target is PrefixedIdentifier) return target.identifier.name;
    if (target is PropertyAccess) return target.propertyName.name;
    return '';
  }

  /// Checks if any named argument is a timeout parameter.
  static bool _hasTimeoutArg(MethodInvocation node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression &&
          _timeoutArgNames.contains(arg.name.label.name)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if `.timeout()` is chained anywhere on the returned Future.
  ///
  /// Handles patterns like:
  /// - `call().timeout(...)`
  /// - `call().then(...).timeout(...)`
  /// - `call().catchError(...).timeout(...)`
  static bool _hasChainedTimeout(MethodInvocation node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodInvocation && current.methodName.name == 'timeout') {
        return true;
      }
      // Walk through chained method calls and property accesses
      if (current is MethodInvocation || current is PropertyAccess) {
        current = current.parent;
        continue;
      }
      // Stop at expression boundaries
      break;
    }
    return false;
  }
}

// =============================================================================
// Part 5 Rules: Stream/Future Rules
// =============================================================================

/// Warns when StreamController is created inside build() method.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidStreamInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_stream_in_build',
    "[avoid_stream_in_build] Creating a Stream or StreamController inside a widget's build() method causes a new stream instance to be created on every rebuild of that widget. This leads to multiple overlapping subscriptions, memory leaks, and lost or duplicated events, making the widget's state unpredictable and difficult to debug. Always manage streams as persistent fields in the State class, not as local variables in build(). See https://docs.flutter.dev/cookbook/networking/web-sockets#using-streambuilder. {v2}",
    correctionMessage:
        'Move all Stream and StreamController creation out of the build() method and into the State class, typically initializing them in initState() and disposing them in dispose(). This ensures a single, consistent stream lifecycle per widget instance and prevents memory leaks or event loss. See https://docs.flutter.dev/cookbook/networking/web-sockets#using-streambuilder for recommended patterns.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'StreamController') return;

      // Check if inside build method
      AstNode? current = node.parent;
      while (current != null) {
        if (current is MethodDeclaration && current.name.lexeme == 'build') {
          reporter.atNode(node);
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when StreamController is not closed in dispose().
///
/// Since: v4.7.4 | Updated: v4.13.0 | Rule version: v5
///
/// StreamControllers must be closed to prevent memory leaks and
/// allow garbage collection.
///
/// For exact `StreamController` types, requires `.close()` call.
/// For wrapper types (e.g., `IsarStreamController`), accepts either
/// `.close()` or `.dispose()` since wrapper classes typically close
/// their internal StreamController in their dispose method.
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
///
/// **GOOD (wrapper class):**
/// ```dart
/// late IsarStreamController<T> _controller;
/// void dispose() {
///   _controller.dispose(); // Wrapper's dispose() closes internal stream
///   super.dispose();
/// }
/// ```
///
/// **Quick fix available:** Adds `controller.close()` call to dispose/close method.
class RequireStreamControllerCloseRule extends SaropaLintRule {
  RequireStreamControllerCloseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_stream_controller_close',
    '[require_stream_controller_close] Failing to close a StreamController in the dispose() method leaves the stream open, causing memory leaks, connection handle exhaustion, and potential app crashes. Unclosed streams can accumulate events and listeners, degrading performance and making debugging difficult. Proper closure is essential for robust, production-quality Flutter apps. {v5}',
    correctionMessage:
        'Call controller.close() in dispose() before super.dispose(). For wrapper types (e.g., IsarStreamController), calling wrapper.dispose() is also acceptable if the wrapper internally closes its StreamController.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Find StreamController fields, tracking if they are exact types or
      // wrappers. Record format: (variable, isExactStreamControllerType)
      final List<(VariableDeclaration, bool)> controllers =
          <(VariableDeclaration, bool)>[];

      for (final member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeStr = member.fields.type?.toSource();
          if (typeStr != null &&
              (typeStr.startsWith('StreamController') ||
                  typeStr.startsWith('StreamController?'))) {
            final bool isExactType =
                typeStr == 'StreamController' ||
                typeStr.startsWith('StreamController<') ||
                typeStr.startsWith('StreamController?');
            for (final variable in member.fields.variables) {
              controllers.add((variable, isExactType));
            }
          }
        }
      }

      if (controllers.isEmpty) return;

      // Check for dispose() or close() methods with close()/dispose() calls.
      // Helper classes may use close() instead of dispose().
      bool hasClose = false;
      bool hasDispose = false;

      for (final member in node.members) {
        if (member is MethodDeclaration) {
          final methodName = member.name.lexeme;
          if (methodName == 'dispose' || methodName == 'close') {
            final String? bodySource = member.body.toSource();
            if (bodySource != null) {
              hasClose = hasClose || bodySource.contains('.close()');
              hasDispose = hasDispose || bodySource.contains('.dispose()');
            }
          }
        }
      }

      for (final (controller, isExactType) in controllers) {
        if (isExactType) {
          // Exact StreamController requires .close()
          if (!hasClose) {
            reporter.atNode(controller);
          }
        } else {
          // Wrapper type (e.g., IsarStreamController) accepts .close() OR
          // .dispose() since wrappers typically close internally
          if (!hasClose && !hasDispose) {
            reporter.atNode(controller);
          }
        }
      }
    });
  }
}

/// Quick fix that adds `.close()` call to the dispose/close method.

/// Warns when multiple listeners are added to a non-broadcast stream.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  AvoidMultipleStreamListenersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_multiple_stream_listeners',
    '[avoid_multiple_stream_listeners] Multiple listen() calls detected on the same non-broadcast stream. Single-subscription streams only allow one active listener at a time. Adding a second listener throws a StateError at runtime, which crashes your app and makes the stream connection unusable for all subscribers. {v2}',
    correctionMessage:
        'Convert the stream to a broadcast stream using .asBroadcastStream(), or ensure only one listener is attached.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireStreamErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_stream_error_handling',
    '[require_stream_error_handling] Stream.listen() is called without providing an onError callback or wrapping the stream in a try-catch. Unhandled stream errors propagate as uncaught exceptions, which crash your app in production and terminate the stream connection permanently, preventing any further data from being received. {v2}',
    correctionMessage:
        'Add an onError callback to your stream.listen() to handle errors gracefully and prevent crashes.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when long-running Futures don't have a timeout.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
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
  RequireFutureTimeoutRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_future_timeout',
    '[require_future_timeout] Executing a long-running Future (such as network or I/O operations) without a timeout can cause your app to hang indefinitely if the operation never completes. This can freeze the UI and degrade user experience. {v3}',
    correctionMessage:
        'Always add .timeout(Duration(...)) to long-running Futures to ensure your app remains responsive and can handle failures gracefully.',
    severity: DiagnosticSeverity.WARNING,
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
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addAwaitExpression((AwaitExpression node) {
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

      reporter.atNode(node);
    });
  }
}

/// Warns when Future.wait is used without error handling for partial failures.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireFutureWaitErrorHandlingRule() : super(code: _code);

  /// Error handling - partial results lost on failure.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_future_wait_error_handling',
    '[require_future_wait_error_handling] Future.wait without eagerError: false. Partial results lost on failure. When one Future in Future.wait fails, all results are lost by default. Use eagerError: false to get partial results on failure. {v2}',
    correctionMessage:
        'Add eagerError: false or wrap individual futures with catchError. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Stream is listened to without onDone handler.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v2
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
  RequireStreamOnDoneRule() : super(code: _code);

  /// Resource cleanup and UX issue.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'require_stream_on_done',
    '[require_stream_on_done] Stream.listen() is called without an onDone handler. When the stream completes, you will not be notified, which can lead to missed cleanup or UI updates. {v2}',
    correctionMessage:
        'Add an onDone callback to handle stream completion and perform necessary cleanup or state updates.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if target is a stream
      final targetType = node.target?.staticType;
      if (targetType == null) return;

      final typeName = targetType.getDisplayString();
      if (!typeName.startsWith('Stream<') && typeName != 'Stream') return;

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
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Uncompleted Completers can cause futures to hang forever.
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
  RequireCompleterErrorHandlingRule() : super(code: _code);

  /// Bug - futures may hang indefinitely.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_completer_error_handling',
    '[require_completer_error_handling] Using a Completer in a try-catch block without calling completeError in the catch block can cause the Future to hang forever if an error occurs. This leads to memory leaks, dangling stream subscriptions, and unclosed connection handles that degrade app stability over time. {v3}',
    correctionMessage:
        'Always call completer.completeError(e) in the catch block to ensure the Future completes with an error and does not hang.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
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
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when stream.listen() is called in a field initializer without
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v4
///
/// storing the subscription for later cancellation.
///
/// Stream subscriptions in field initializers are particularly dangerous
/// because they execute before initState() where cleanup setup typically
/// happens. The subscription must be stored to be canceled in dispose().
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   // Subscription created but never stored - cannot be canceled!
///   final _ = someStream.listen((data) => print(data));
///
///   // Or assigned to void
///   void _init() {
///     myStream.listen((data) => doSomething(data)); // Lost reference!
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   StreamSubscription<Data>? _subscription;
///
///   @override
///   void initState() {
///     super.initState();
///     _subscription = myStream.listen((data) => doSomething(data));
///   }
///
///   @override
///   void dispose() {
///     _subscription?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class AvoidStreamSubscriptionInFieldRule extends SaropaLintRule {
  AvoidStreamSubscriptionInFieldRule() : super(code: _code);

  /// Critical - memory leaks and callbacks after disposal.
  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.high;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_stream_subscription_in_field',
    '[avoid_stream_subscription_in_field] If a StreamSubscription is stored as a field in a State class but not properly canceled in dispose(), the subscription will continue to receive events even after the widget is removed from the widget tree. This can cause memory leaks, unexpected UI updates, and subtle bugs, especially in dynamic lists or navigation flows where widgets are frequently created and destroyed. Always cancel subscriptions in the correct State object’s dispose() method. See https://docs.flutter.dev/perf/memory#dispose-resources. {v4}',
    correctionMessage:
        'In every State class that owns a StreamSubscription field, call subscription.cancel() in the dispose() method before calling super.dispose(). This ensures the subscription is cleaned up when the widget is removed, preventing leaks and unwanted callbacks. See https://docs.flutter.dev/perf/memory#dispose-resources for more information.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      // Check if the target is a Stream
      final Expression? target = node.target;
      if (target == null) return;

      final DartType? type = target.staticType;
      if (type == null) return;

      final String typeName = type.getDisplayString();
      if (!typeName.startsWith('Stream')) return;

      // Check if this is in a field initializer context
      // Field initializers are problematic because they run before initState
      AstNode? current = node.parent;

      while (current != null) {
        // If we find an assignment to a proper StreamSubscription field, it's OK
        if (current is VariableDeclaration) {
          final AstNode? fieldParent = current.parent?.parent;
          if (fieldParent is FieldDeclaration) {
            final String? fieldType = fieldParent.fields.type?.toSource();
            // If the field type is StreamSubscription, this is proper storage
            if (fieldType != null && fieldType.contains('StreamSubscription')) {
              return;
            }
            // If stored to a non-subscription field (like _ or void), it's bad
            reporter.atNode(node);
            return;
          }
        }

        // If assigned to a variable that IS StreamSubscription, it's OK
        if (current is AssignmentExpression) {
          final Expression leftSide = current.leftHandSide;
          if (leftSide is SimpleIdentifier) {
            // Check if the left side is a StreamSubscription field
            final String leftSource = leftSide.name;
            if (leftSource.contains('subscription') ||
                leftSource.contains('Subscription')) {
              return; // Likely storing properly
            }
          }
          // Check static type of left side
          final DartType? leftType = leftSide.staticType;
          if (leftType != null) {
            final String leftTypeName = leftType.getDisplayString();
            if (leftTypeName.contains('StreamSubscription')) {
              return;
            }
          }
        }

        // If assigned to a local variable declaration, check its type
        if (current is VariableDeclarationStatement) {
          final String? declType = current.variables.type?.toSource();
          if (declType != null && declType.contains('StreamSubscription')) {
            return;
          }
        }

        // Stop at method or class level
        if (current is MethodDeclaration ||
            current is FunctionDeclaration ||
            current is ClassDeclaration) {
          break;
        }

        current = current.parent;
      }

      // Check if inside an expression statement (bare listen call)
      current = node.parent;
      while (current != null) {
        if (current is ExpressionStatement) {
          // This is a bare stream.listen() call without assignment
          reporter.atNode(node);
          return;
        }
        if (current is VariableDeclaration ||
            current is AssignmentExpression ||
            current is ReturnStatement) {
          // Being assigned or returned, check if it's to a subscription type
          break;
        }
        if (current is Block || current is MethodDeclaration) {
          break;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when .then() is used inside an async function.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: then_in_async, prefer_await_over_then
///
/// Using .then() inside an async function mixes two async patterns.
/// Prefer await for cleaner, more readable code.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   fetchData().then((data) {
///     processData(data);
///   });
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   processData(data);
/// }
/// ```
class AvoidFutureThenInAsyncRule extends SaropaLintRule {
  AvoidFutureThenInAsyncRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_future_then_in_async',
    '[avoid_future_then_in_async] Using .then() inside async function. Prefer await for consistency. Using .then() inside an async function mixes two async patterns. Prefer await for cleaner, more readable code. {v2}',
    correctionMessage:
        'Use await instead of .then() for cleaner async code. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'then') return;

      // Check if we're inside an async function
      AstNode? current = node.parent;
      while (current != null) {
        if (current is FunctionExpression) {
          if (current.body.isAsynchronous) {
            reporter.atNode(node.methodName, code);
          }
          return;
        }
        if (current is MethodDeclaration) {
          if (current.body is BlockFunctionBody) {
            final BlockFunctionBody body = current.body as BlockFunctionBody;
            if (body.isAsynchronous) {
              reporter.atNode(node.methodName, code);
            }
          }
          return;
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when a Future is not awaited and not explicitly marked.
///
/// Since: v2.3.10 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: unawaited_future, missing_await, fire_and_forget
///
/// Unawaited Futures lose their errors and can cause unexpected behavior.
/// Either await the Future or use unawaited() to explicitly mark it.
///
/// **BAD:**
/// ```dart
/// void doSomething() {
///   saveData(); // Future returned but not awaited
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> doSomething() async {
///   await saveData();
/// }
///
/// // Or if intentionally fire-and-forget:
/// void doSomething() {
///   unawaited(saveData());
/// }
/// ```
///
/// **ALLOWED (safe fire-and-forget patterns):**
/// ```dart
/// // StreamSubscription.cancel() in dispose() - can't await in sync method
/// @override
/// void dispose() {
///   _subscription?.cancel(); // OK - disposal cleanup
///   super.dispose();
/// }
///
/// // Future chains with .catchError() - errors are handled
/// _scrollController.animateTo(100).catchError((e) {
///   debugPrint('Animation failed: $e');
/// }); // OK - error is handled
///
/// // Future.ignore() - explicitly ignored
/// someAsyncOperation().ignore(); // OK - explicitly fire-and-forget
/// ```
class AvoidUnawaitedFutureRule extends SaropaLintRule {
  AvoidUnawaitedFutureRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.high;

  static const LintCode _code = LintCode(
    'avoid_unawaited_future',
    '[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}',
    correctionMessage:
        'Always use await or unawaited() to explicitly handle Futures and ensure errors are not lost.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
      final Expression expr = node.expression;

      // Check if this is a method invocation that returns a Future
      if (expr is MethodInvocation) {
        final DartType? returnType = expr.staticType;
        if (returnType != null) {
          final String typeName = returnType.getDisplayString();
          if (typeName.startsWith('Future<') || typeName == 'Future') {
            // Skip if wrapped in unawaited()
            final AstNode? parent = node.parent;
            if (parent is! MethodInvocation ||
                parent.methodName.name != 'unawaited') {
              // Skip safe patterns: subscription.cancel() in dispose(),
              // or chains ending with .catchError()/.ignore()
              if (_isSafeFireAndForget(expr, node)) {
                return;
              }
              reporter.atNode(expr);
            }
          }
        }
      }

      // Also check function invocations
      if (expr is FunctionExpressionInvocation) {
        final DartType? returnType = expr.staticType;
        if (returnType != null) {
          final String typeName = returnType.getDisplayString();
          if (typeName.startsWith('Future<') || typeName == 'Future') {
            reporter.atNode(expr);
          }
        }
      }
    });
  }

  /// Returns true for patterns where unawaited futures are intentional and safe.
  bool _isSafeFireAndForget(MethodInvocation expr, ExpressionStatement node) {
    // Lifecycle methods are sync; subscription cleanup doesn't need await
    if (_isSubscriptionCancelInLifecycle(expr, node)) {
      return true;
    }

    // StreamController.close() in onDone callbacks - callback is void Function()
    if (_isControllerCloseInOnDone(expr, node)) {
      return true;
    }

    // .catchError()/.ignore() means errors are already handled
    if (_hasCatchErrorOrIgnore(expr)) {
      return true;
    }

    return false;
  }

  /// StreamSubscription.cancel() in lifecycle methods is safe.
  ///
  /// These methods handle cleanup where awaiting cancel() is unnecessary:
  /// - `dispose()` - widget is dying anyway
  /// - `didUpdateWidget()` - canceling old subscription before creating new one
  /// - `deactivate()` - widget being removed from tree
  bool _isSubscriptionCancelInLifecycle(
    MethodInvocation expr,
    ExpressionStatement node,
  ) {
    if (expr.methodName.name != 'cancel') {
      return false;
    }

    // Verify target is a StreamSubscription
    final Expression? target = expr.target;
    if (target != null) {
      final DartType? targetType = target.staticType;
      if (targetType != null) {
        final String targetTypeName = targetType.getDisplayString();
        if (!targetTypeName.contains('StreamSubscription')) {
          return false;
        }
      }
    }

    // Walk up AST to find enclosing method
    AstNode? current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration) {
        final String name = current.name.lexeme;
        return name == 'dispose' ||
            name == 'didUpdateWidget' ||
            name == 'deactivate';
      }
      current = current.parent;
    }
    return false;
  }

  /// StreamController.close() in onDone/onError callbacks is safe.
  ///
  /// The `onDone` parameter of `Stream.listen()` is `void Function()`, so
  /// you cannot await inside it. Closing the controller here is standard
  /// cleanup for transformed streams.
  bool _isControllerCloseInOnDone(
    MethodInvocation expr,
    ExpressionStatement node,
  ) {
    if (expr.methodName.name != 'close') {
      return false;
    }

    // Verify target is a StreamController
    final Expression? target = expr.target;
    if (target != null) {
      final DartType? targetType = target.staticType;
      if (targetType != null) {
        final String targetTypeName = targetType.getDisplayString();
        if (!targetTypeName.startsWith('StreamController')) {
          return false;
        }
      }
    }

    // Walk up AST to find if we're in an onDone/onError named parameter
    AstNode? current = node.parent;
    while (current != null) {
      if (current is NamedExpression) {
        final String paramName = current.name.label.name;
        return paramName == 'onDone' || paramName == 'onError';
      }
      // Stop searching if we hit a method or function declaration
      if (current is MethodDeclaration || current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return false;
  }

  /// .catchError() handles errors; .ignore() explicitly discards the future.
  bool _hasCatchErrorOrIgnore(MethodInvocation expr) {
    final String methodName = expr.methodName.name;
    return methodName == 'catchError' || methodName == 'ignore';
  }
}

// =============================================================================
// ROADMAP_NEXT: Phase 2 - Async Performance Rules
// =============================================================================

/// Warns when sequential awaits could use Future.wait for parallelism.
///
/// Since: v2.5.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: future_wait, parallel_await, concurrent_futures
///
/// When multiple independent async operations are awaited sequentially,
/// they run one after another. Using `Future.wait` allows them to run
/// in parallel, improving performance.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final users = await fetchUsers();       // Waits ~100ms
///   final products = await fetchProducts(); // Waits another ~100ms
///   final orders = await fetchOrders();     // Waits another ~100ms
///   // Total: ~300ms
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final results = await Future.wait([
///     fetchUsers(),
///     fetchProducts(),
///     fetchOrders(),
///   ]);
///   final users = results[0];
///   final products = results[1];
///   final orders = results[2];
///   // Total: ~100ms (parallel)
/// }
///
/// // Or with records (Dart 3):
/// Future<void> loadData() async {
///   final (users, products, orders) = await (
///     fetchUsers(),
///     fetchProducts(),
///     fetchOrders(),
///   ).wait;
/// }
/// ```
///
/// **Note:** Only applies when futures are independent. If one depends on
/// the result of another, sequential awaits are correct.
class PreferFutureWaitRule extends SaropaLintRule {
  PreferFutureWaitRule() : super(code: _code);

  /// Performance improvement. Can significantly speed up data loading.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_future_wait',
    '[prefer_future_wait] Sequential awaits could run in parallel with Future.wait. {v2}',
    correctionMessage:
        'Use Future.wait([future1, future2]) to run independent futures '
        'concurrently, or (future1, future2).wait in Dart 3.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Minimum number of sequential awaits to trigger the warning.
  static const int _minSequentialAwaits = 2;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlockFunctionBody((BlockFunctionBody body) {
      // Check if function is async
      if (body.keyword?.keyword != Keyword.ASYNC) return;

      final block = body.block;
      _checkBlockForSequentialAwaits(block, reporter);
    });
  }

  void _checkBlockForSequentialAwaits(
    Block block,
    SaropaDiagnosticReporter reporter,
  ) {
    final List<Statement> statements = block.statements;
    final List<VariableDeclarationStatement> sequentialAwaits = [];
    final Set<String> usedVariables = <String>{};

    for (int i = 0; i < statements.length; i++) {
      final statement = statements[i];

      if (statement is VariableDeclarationStatement) {
        final variables = statement.variables.variables;
        if (variables.length == 1) {
          final variable = variables.first;
          final initializer = variable.initializer;

          if (initializer is AwaitExpression) {
            // Check if this await uses any previously declared variables
            final usedVars = _getUsedVariables(initializer);
            final dependsOnPrevious = usedVars.any(
              (v) => usedVariables.contains(v),
            );

            if (dependsOnPrevious) {
              // This await depends on a previous result, break the chain
              _reportIfEnough(sequentialAwaits, reporter);
              sequentialAwaits.clear();
            }

            sequentialAwaits.add(statement);
            usedVariables.add(variable.name.lexeme);
            continue;
          }
        }
      }

      // Non-await statement encountered, check the chain so far
      _reportIfEnough(sequentialAwaits, reporter);
      sequentialAwaits.clear();
    }

    // Check any remaining awaits at the end
    _reportIfEnough(sequentialAwaits, reporter);
  }

  void _reportIfEnough(
    List<VariableDeclarationStatement> awaits,
    SaropaDiagnosticReporter reporter,
  ) {
    if (awaits.length >= _minSequentialAwaits) {
      // Report on the second await (to indicate this is part of a sequence)
      reporter.atNode(awaits[1], code);
    }
  }

  Set<String> _getUsedVariables(Expression expression) {
    final Set<String> variables = <String>{};
    expression.accept(_VariableCollector(variables));
    return variables;
  }
}

class _VariableCollector extends RecursiveAstVisitor<void> {
  _VariableCollector(this.variables);

  final Set<String> variables;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Only collect identifiers that look like local variables
    // (not method names, not type names)
    final parent = node.parent;
    if (parent is MethodInvocation && parent.methodName == node) {
      // This is a method name, not a variable
      return;
    }
    if (parent is NamedType) {
      // This is a type name
      return;
    }

    variables.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}

// =============================================================================
// NEW ROADMAP STAR RULES - Stream & Async Rules
// =============================================================================

/// Warns when Stream is listened multiple times without .distinct().
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v3
///
/// Use .distinct() to skip consecutive duplicate values and avoid
/// unnecessary processing or rebuilds.
///
/// **BAD:**
/// ```dart
/// stream.listen((value) {
///   setState(() => _value = value); // Rebuilds even if value unchanged
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// stream.distinct().listen((value) {
///   setState(() => _value = value); // Only rebuilds on actual changes
/// });
/// ```
class PreferStreamDistinctRule extends SaropaLintRule {
  PreferStreamDistinctRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_stream_distinct',
    '[prefer_stream_distinct] Stream.listen() without .distinct() may '
        'process duplicate values unnecessarily. {v3}',
    correctionMessage:
        'Add .distinct() before .listen() to skip duplicate consecutive values.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'listen') return;

      final targetType = node.target?.staticType;
      if (targetType == null) return;
      if (targetType is! InterfaceType) return;

      // Verify this is actually a Stream type
      if (targetType.element.name != 'Stream') return;

      // Skip Stream<void> and Stream<Null> — .distinct() would suppress
      // all events after the first since every value is equal.
      if (_hasVoidOrNullTypeArg(targetType)) return;

      // Walk the full method chain to find .distinct() at any position
      if (_chainHasDistinct(node.target)) return;

      // Check if this is inside a setState callback (UI context)
      if (_hasSetStateInListener(node)) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true if [type] has a single type argument that is void or Null.
  bool _hasVoidOrNullTypeArg(InterfaceType type) {
    final typeArgs = type.typeArguments;
    if (typeArgs.length != 1) return false;
    final arg = typeArgs.first;
    return arg is VoidType || arg.isDartCoreNull;
  }

  /// Walks the method invocation chain to find .distinct() at any position.
  bool _chainHasDistinct(Expression? target) {
    Expression? current = target;
    while (current is MethodInvocation) {
      if (current.methodName.name == 'distinct') return true;
      current = current.target;
    }
    return false;
  }

  bool _hasSetStateInListener(MethodInvocation listenNode) {
    final args = listenNode.argumentList.arguments;
    if (args.isEmpty) return false;

    final callback = args.first;
    if (callback is FunctionExpression) {
      final body = callback.body.toSource();
      return body.contains('setState');
    }
    return false;
  }
}

/// Warns when single-subscription Stream needs multiple listeners.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Use .asBroadcastStream() when you need multiple listeners on a Stream.
///
/// **BAD:**
/// ```dart
/// final stream = controller.stream;
/// stream.listen((data) => print(data));
/// stream.listen((data) => log(data)); // Error: Stream already listened!
/// ```
///
/// **GOOD:**
/// ```dart
/// final stream = controller.stream.asBroadcastStream();
/// stream.listen((data) => print(data));
/// stream.listen((data) => log(data)); // Works!
/// ```
class PreferBroadcastStreamRule extends SaropaLintRule {
  PreferBroadcastStreamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_broadcast_stream',
    '[prefer_broadcast_stream] Stream from StreamController is single-subscription. '
        'Multiple listeners will cause an error. {v2}',
    correctionMessage:
        'Use .asBroadcastStream() or StreamController.broadcast().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Track streams that are accessed multiple times
    context.addCompilationUnit((CompilationUnit unit) {
      final streamAccesses = <String, List<AstNode>>{};

      unit.visitChildren(
        _StreamAccessVisitor((name, node) {
          streamAccesses.putIfAbsent(name, () => []).add(node);
        }),
      );

      // Report streams accessed more than once
      for (final entry in streamAccesses.entries) {
        if (entry.value.length > 1) {
          // Only report if no asBroadcastStream in the chain
          final hasConversion = entry.value.any((node) {
            if (node is MethodInvocation) {
              return node.toSource().contains('asBroadcastStream');
            }
            return false;
          });

          if (!hasConversion) {
            reporter.atNode(entry.value.first, code);
          }
        }
      }
    });
  }
}

class _StreamAccessVisitor extends RecursiveAstVisitor<void> {
  _StreamAccessVisitor(this.onAccess);

  final void Function(String name, AstNode node) onAccess;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'listen') {
      final target = node.target;
      if (target is SimpleIdentifier) {
        onAccess(target.name, node);
      } else if (target is PrefixedIdentifier) {
        onAccess(target.toSource(), node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when Future is created inside build() method.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Creating futures in build() can cause repeated async calls on every rebuild.
/// Create futures in initState() and store the result.
///
/// **BAD:**
/// ```dart
/// Widget build(BuildContext context) {
///   final future = fetchData(); // Called on every rebuild!
///   return FutureBuilder(future: future, ...);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// late final Future<Data> _dataFuture;
///
/// @override
/// void initState() {
///   super.initState();
///   _dataFuture = fetchData();
/// }
///
/// Widget build(BuildContext context) {
///   return FutureBuilder(future: _dataFuture, ...);
/// }
/// ```
class AvoidFutureInBuildRule extends SaropaLintRule {
  AvoidFutureInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_future_in_build',
    '[avoid_future_in_build] Creating Future in build() causes repeated '
        'async calls on every rebuild. {v2}',
    correctionMessage:
        'Create the Future in initState() and store it in a field.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      // Check if this is a widget's build method
      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;
      if (!_isWidgetClass(classDecl)) return;

      // Look for async function calls in build
      node.body.visitChildren(
        _FutureCreationVisitor((asyncNode) {
          reporter.atNode(asyncNode);
        }),
      );
    });
  }

  bool _isWidgetClass(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final superName = extendsClause.superclass.name.lexeme;
    return superName == 'StatelessWidget' ||
        superName == 'StatefulWidget' ||
        superName.contains('State');
  }
}

class _FutureCreationVisitor extends RecursiveAstVisitor<void> {
  _FutureCreationVisitor(this.onFutureCreated);

  final void Function(AstNode) onFutureCreated;

  static const Set<String> _asyncMethodPrefixes = <String>{
    'fetch',
    'load',
    'get',
    'retrieve',
    'download',
    'upload',
    'request',
  };

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check for common async method patterns
    final methodName = node.methodName.name.toLowerCase();
    if (_asyncMethodPrefixes.any((p) => methodName.startsWith(p))) {
      // Check if this is assigned to a FutureBuilder
      final parent = node.parent;
      if (parent is NamedExpression && parent.name.label.name == 'future') {
        onFutureCreated(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Warns when setState is called after await without mounted check.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// After an await, the widget may have been disposed. Always check mounted
/// before calling setState.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   setState(() => _data = data); // Widget may be disposed!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final data = await fetchData();
///   if (!mounted) return;
///   setState(() => _data = data);
/// }
/// ```
class RequireMountedCheckAfterAwaitRule extends SaropaLintRule {
  RequireMountedCheckAfterAwaitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_mounted_check_after_await',
    '[require_mounted_check_after_await] setState called after await '
        'without mounted check. Widget may have been disposed. {v2}',
    correctionMessage:
        'Add "if (!mounted) return;" before setState after await.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (!node.body.isAsynchronous) return;

      // Check if in a State class
      final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDecl == null) return;

      final extendsClause = classDecl.extendsClause;
      if (extendsClause == null) return;

      final superclass = extendsClause.superclass;
      if (superclass.name.lexeme != 'State') return;
      if (superclass.typeArguments == null) return;

      // Analyze the method body
      node.body.visitChildren(_MountedCheckVisitor(reporter, code));
    });
  }
}

class _MountedCheckVisitor extends RecursiveAstVisitor<void> {
  _MountedCheckVisitor(this.reporter, this.code);

  final SaropaDiagnosticReporter reporter;
  final LintCode code;
  bool _sawAwait = false;
  bool _hasMountedCheck = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _sawAwait = true;
    _hasMountedCheck = false;
    super.visitAwaitExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    final condition = node.expression.toSource();
    if (condition.contains('mounted')) {
      _hasMountedCheck = true;
    }
    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'setState' && _sawAwait && !_hasMountedCheck) {
      if (!_hasAncestorMountedCheck(node)) {
        reporter.atNode(node);
      }
    }
    super.visitMethodInvocation(node);
  }

  bool _hasAncestorMountedCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        if (current.expression.toSource().contains('mounted')) {
          return true;
        }
      }
      if (current is FunctionExpression || current is MethodDeclaration) break;
      current = current.parent;
    }
    return false;
  }
}

/// Warns when build() method is marked async.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// Build methods should never be async. Use FutureBuilder or AsyncBuilder
/// for async data.
///
/// **BAD:**
/// ```dart
/// @override
/// Future<Widget> build(BuildContext context) async {
///   final data = await fetchData();
///   return Text(data);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   return FutureBuilder(
///     future: _dataFuture,
///     builder: (context, snapshot) => Text(snapshot.data ?? 'Loading'),
///   );
/// }
/// ```
class AvoidAsyncInBuildRule extends SaropaLintRule {
  AvoidAsyncInBuildRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_async_in_build',
    '[avoid_async_in_build] Build method should never be async. '
        'This will cause rendering issues. {v2}',
    correctionMessage: 'Use FutureBuilder or fetch data in initState instead.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'build') return;

      if (node.body.isAsynchronous) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when async operations should use FutureBuilder in initState pattern.
///
/// Since: v4.1.4 | Updated: v4.13.0 | Rule version: v2
///
/// For widgets that need async initialization, use the initState + FutureBuilder
/// pattern for proper loading states.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   String? _data;
///
///   @override
///   void initState() {
///     super.initState();
///     fetchData().then((data) {
///       setState(() => _data = data);
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late final Future<String> _dataFuture;
///
///   @override
///   void initState() {
///     super.initState();
///     _dataFuture = fetchData();
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return FutureBuilder(
///       future: _dataFuture,
///       builder: (context, snapshot) => ...
///     );
///   }
/// }
/// ```
class PreferAsyncInitStateRule extends SaropaLintRule {
  PreferAsyncInitStateRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_async_init_state',
    '[prefer_async_init_state] Using .then().setState() pattern in initState. '
        'Store the Future in a field and use FutureBuilder to manage loading states declaratively. {v2}',
    correctionMessage:
        'Store the Future in a field and use FutureBuilder in build().',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      if (node.name.lexeme != 'initState') return;

      // Look for .then() calls with setState
      node.body.visitChildren(
        _ThenSetStateVisitor((thenNode) {
          reporter.atNode(thenNode);
        }),
      );
    });
  }
}

class _ThenSetStateVisitor extends RecursiveAstVisitor<void> {
  _ThenSetStateVisitor(this.onFound);

  final void Function(AstNode) onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'then') {
      // Check if the callback contains setState
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final callback = args.first;
        if (callback is FunctionExpression) {
          if (callback.body.toSource().contains('setState')) {
            onFound(node);
          }
        }
      }
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// require_network_status_check
// =============================================================================

/// Check connectivity before making requests that will obviously fail.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Making network requests without checking connectivity results in
/// confusing timeout errors instead of appropriate offline UI.
///
/// **BAD:**
/// ```dart
/// Future<void> fetchData() async {
///   final response = await http.get(Uri.parse(url));
///   // May timeout with confusing error if offline
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> fetchData() async {
///   final connectivity = await Connectivity().checkConnectivity();
///   if (connectivity == ConnectivityResult.none) {
///     throw OfflineException('No internet connection');
///   }
///   final response = await http.get(Uri.parse(url));
/// }
/// ```
class RequireNetworkStatusCheckRule extends SaropaLintRule {
  RequireNetworkStatusCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_network_status_check',
    '[require_network_status_check] `[HEURISTIC]` Network call without '
        'connectivity check. Verify network status before making requests to avoid silent failures. {v2}',
    correctionMessage:
        'Check Connectivity().checkConnectivity() before making requests.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      // Only check async methods
      if (!node.body.isAsynchronous) return;

      final bodySource = node.body.toSource();

      // Check for network calls
      final hasNetworkCall =
          bodySource.contains('http.get') ||
          bodySource.contains('http.post') ||
          bodySource.contains('http.put') ||
          bodySource.contains('http.delete') ||
          bodySource.contains('Dio()') ||
          bodySource.contains('.get(') ||
          bodySource.contains('.post(') ||
          bodySource.contains('ApiClient') ||
          bodySource.contains('fetchData');

      if (!hasNetworkCall) return;

      // Check for connectivity check
      final hasConnectivityCheck =
          bodySource.contains('Connectivity') ||
          bodySource.contains('checkConnectivity') ||
          bodySource.contains('ConnectivityResult') ||
          bodySource.contains('isConnected') ||
          bodySource.contains('hasConnection') ||
          bodySource.contains('networkStatus');

      if (!hasConnectivityCheck) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_sync_on_every_change
// =============================================================================

/// Syncing each keystroke wastes battery and bandwidth.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Batch changes and sync on intervals or app background instead of
/// syncing after every small change.
///
/// **BAD:**
/// ```dart
/// TextField(
///   onChanged: (value) async {
///     await api.saveNote(value); // Syncs on every keystroke!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// TextField(
///   onChanged: (value) {
///     _pendingValue = value;
///     _debouncer.run(() => api.saveNote(_pendingValue));
///   },
/// )
/// // Or sync when user stops typing or leaves screen
/// ```
class AvoidSyncOnEveryChangeRule extends SaropaLintRule {
  AvoidSyncOnEveryChangeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_sync_on_every_change',
    '[avoid_sync_on_every_change] `[HEURISTIC]` API call in onChanged '
        'callback may fire on every keystroke. Add a debounce timer to batch rapid inputs before syncing. {v2}',
    correctionMessage:
        'Use a debouncer or batch changes before syncing to server.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'TextField' &&
          constructorName != 'TextFormField') {
        return;
      }

      // Check onChanged callback
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'onChanged') {
          final callback = arg.expression;
          final callbackSource = callback.toSource();

          // Check for API/network calls in onChanged
          if (callbackSource.contains('await') ||
              callbackSource.contains('.post') ||
              callbackSource.contains('.put') ||
              callbackSource.contains('.save') ||
              callbackSource.contains('.update') ||
              callbackSource.contains('api.') ||
              callbackSource.contains('Api.')) {
            // Check if debounced
            if (!callbackSource.contains('debounce') &&
                !callbackSource.contains('Debouncer') &&
                !callbackSource.contains('throttle') &&
                !callbackSource.contains('Timer')) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// require_pending_changes_indicator
// =============================================================================

/// Users should see when local changes haven't synced.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Show "Saving..." or pending count to set user expectations about
/// sync status.
///
/// **BAD:**
/// ```dart
/// // Silent save with no indication
/// void save() {
///   _pendingChanges.add(change);
///   _syncLater();
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void save() {
///   _pendingChanges.add(change);
///   notifyListeners(); // Shows pending indicator
///   _syncLater();
/// }
///
/// // In UI:
/// if (pendingCount > 0) Text('Saving $pendingCount changes...')
/// ```
class RequirePendingChangesIndicatorRule extends SaropaLintRule {
  RequirePendingChangesIndicatorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_pending_changes_indicator',
    '[require_pending_changes_indicator] `[HEURISTIC]` Pending changes '
        'collection without UI notification. Users cannot see sync status. {v2}',
    correctionMessage:
        'Call notifyListeners() or setState() when pending changes update.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      final bodySource = node.body.toSource();

      // Check for pending changes pattern
      final hasPendingPattern =
          bodySource.contains('_pending') ||
          bodySource.contains('pending.add') ||
          bodySource.contains('_queue.add') ||
          bodySource.contains('_unsaved') ||
          bodySource.contains('_dirty');

      if (!hasPendingPattern) return;

      // Check for notification
      final hasNotification =
          bodySource.contains('notifyListeners') ||
          bodySource.contains('setState') ||
          bodySource.contains('emit(') ||
          bodySource.contains('add(') || // Stream add
          bodySource.contains('state =');

      if (!hasNotification) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_stream_sync_events
// =============================================================================

/// Warns when synchronous events are added to a stream.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: stream_sync_add, async_stream_events
///
/// Adding events synchronously to a stream can cause issues if listeners
/// aren't yet attached or if the stream is paused. Use scheduleMicrotask
/// or Future.microtask for the first event.
///
/// **BAD:**
/// ```dart
/// StreamController<int> _controller;
///
/// void init() {
///   _controller = StreamController<int>();
///   _controller.add(0); // Sync add - listeners may miss this!
///   return _controller.stream;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// StreamController<int> _controller;
///
/// void init() {
///   _controller = StreamController<int>();
///   // Give listeners time to attach
///   scheduleMicrotask(() => _controller.add(0));
///   return _controller.stream;
/// }
///
/// // Or use sync: true if you intend synchronous delivery
/// _controller = StreamController<int>.broadcast(sync: true);
/// ```
class AvoidStreamSyncEventsRule extends SaropaLintRule {
  AvoidStreamSyncEventsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_stream_sync_events',
    '[avoid_stream_sync_events] Stream event added synchronously right '
        'after controller creation. Listeners may not be attached yet. {v2}',
    correctionMessage:
        'Use scheduleMicrotask() or Future.microtask() to delay first event, '
        'or use StreamController(sync: true) if synchronous delivery is intended.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for stream add methods
      if (methodName != 'add' && methodName != 'addError') return;

      // Check if target is a StreamController
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('controller') &&
          !targetSource.contains('stream')) {
        return;
      }

      // Check if this is immediately after controller creation
      AstNode? current = node.parent;
      FunctionBody? functionBody;

      while (current != null) {
        if (current is FunctionBody) {
          functionBody = current;
          break;
        }
        current = current.parent;
      }

      if (functionBody == null) return;

      final String bodySource = functionBody.toSource();
      final int nodeOffset = node.offset;
      final int bodyOffset = functionBody.offset;

      // Check if StreamController is created in this function
      if (!bodySource.contains('StreamController(') &&
          !bodySource.contains('StreamController<')) {
        return;
      }

      // Check if the add is close to the controller creation (within a few statements)
      final String beforeAdd = bodySource.substring(0, nodeOffset - bodyOffset);

      // Check for microtask wrapping
      if (beforeAdd.contains('scheduleMicrotask') ||
          beforeAdd.contains('Future.microtask') ||
          beforeAdd.contains('Timer.run') ||
          bodySource.contains('sync: true')) {
        return; // Properly handled
      }

      // Check if StreamController creation is within last 200 chars (rough heuristic)
      final int controllerIndex = beforeAdd.lastIndexOf('StreamController');
      if (controllerIndex != -1 && (beforeAdd.length - controllerIndex) < 200) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_sequential_awaits
// =============================================================================

/// Warns when multiple independent awaits are performed sequentially.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: parallel_await, concurrent_futures
///
/// Sequential awaits for independent operations waste time. Use Future.wait
/// for concurrent execution when operations don't depend on each other.
///
/// **BAD:**
/// ```dart
/// Future<void> loadData() async {
///   final users = await fetchUsers();      // Takes 2 seconds
///   final products = await fetchProducts(); // Takes 2 seconds
///   final orders = await fetchOrders();     // Takes 2 seconds
///   // Total: 6 seconds
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> loadData() async {
///   final results = await Future.wait([
///     fetchUsers(),
///     fetchProducts(),
///     fetchOrders(),
///   ]);
///   final users = results[0];
///   final products = results[1];
///   final orders = results[2];
///   // Total: 2 seconds (max of all three)
/// }
///
/// // Or with record destructuring (Dart 3+):
/// final (users, products, orders) = await (
///   fetchUsers(),
///   fetchProducts(),
///   fetchOrders(),
/// ).wait;
/// ```
class AvoidSequentialAwaitsRule extends SaropaLintRule {
  AvoidSequentialAwaitsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_sequential_awaits',
    '[avoid_sequential_awaits] Multiple sequential awaits on independent '
        'operations. Total time is sum of all; could run in parallel. {v2}',
    correctionMessage:
        'Use Future.wait([...]) to run independent futures concurrently.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionBody((FunctionBody body) {
      if (body is! BlockFunctionBody) return;

      // Find all await expressions in the body
      final List<AwaitExpression> awaits = <AwaitExpression>[];
      body.accept(_AwaitCollector(awaits));

      if (awaits.length < 3) return; // Need at least 3 sequential awaits

      // Check for sequential awaits that don't depend on each other
      for (int i = 0; i < awaits.length - 2; i++) {
        final AwaitExpression first = awaits[i];
        final AwaitExpression second = awaits[i + 1];
        final AwaitExpression third = awaits[i + 2];

        // Check if they are in sequential statements
        if (!_areSequentialStatements(first, second, third)) continue;

        // Check if they look independent (don't use each other's results)
        if (_areIndependentAwaits(first, second, third, body)) {
          reporter.atNode(second);
          break; // Only report once per function
        }
      }
    });
  }

  bool _areSequentialStatements(
    AwaitExpression first,
    AwaitExpression second,
    AwaitExpression third,
  ) {
    // Check if all three are direct children of expression statements
    // in the same block
    final firstStmt = first.thisOrAncestorOfType<Statement>();
    final secondStmt = second.thisOrAncestorOfType<Statement>();
    final thirdStmt = third.thisOrAncestorOfType<Statement>();

    if (firstStmt == null || secondStmt == null || thirdStmt == null) {
      return false;
    }

    // Check they're in the same block
    final firstBlock = firstStmt.parent;
    final secondBlock = secondStmt.parent;
    final thirdBlock = thirdStmt.parent;

    return firstBlock == secondBlock && secondBlock == thirdBlock;
  }

  bool _areIndependentAwaits(
    AwaitExpression first,
    AwaitExpression second,
    AwaitExpression third,
    FunctionBody body,
  ) {
    // Get variable names assigned from first two awaits
    final Set<String> assignedVars = <String>{};

    for (final await in [first, second]) {
      AstNode? parent = await.parent;
      while (parent != null) {
        if (parent is VariableDeclaration) {
          assignedVars.add(parent.name.lexeme);
          break;
        }
        if (parent is AssignmentExpression &&
            parent.leftHandSide is SimpleIdentifier) {
          assignedVars.add((parent.leftHandSide as SimpleIdentifier).name);
          break;
        }
        if (parent is Statement) break;
        parent = parent.parent;
      }
    }

    // Check if second and third await expressions use first's result
    final String secondSource = second.expression.toSource();
    final String thirdSource = third.expression.toSource();

    for (final varName in assignedVars) {
      if (secondSource.contains(varName) || thirdSource.contains(varName)) {
        return false; // Not independent - uses result of previous await
      }
    }

    return true;
  }
}

class _AwaitCollector extends RecursiveAstVisitor<void> {
  _AwaitCollector(this.awaits);

  final List<AwaitExpression> awaits;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    awaits.add(node);
    super.visitAwaitExpression(node);
  }
}
