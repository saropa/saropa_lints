// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';

import '../saropa_lint_rule.dart';
import '../fixes/return/remove_unnecessary_return_fix.dart';
import '../fixes/return/inline_immediate_return_fix.dart';

/// Resolves the declared return type from a [FunctionBody]'s parent.
DartType? getReturnTypeFromBody(FunctionBody body) {
  final AstNode? parent = body.parent;
  if (parent is MethodDeclaration) return parent.returnType?.type;
  if (parent is FunctionDeclaration) return parent.returnType?.type;
  if (parent is FunctionExpression) {
    final grandparent = parent.parent;
    if (grandparent is FunctionDeclaration) {
      return grandparent.returnType?.type;
    }
  }

  return null;
}

/// Warns when returning a cascade expression.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Example of **bad** code:
/// ```dart
/// return list..add(1)..add(2);
/// ```
///
/// Example of **good** code:
/// ```dart
/// list..add(1)..add(2);
/// return list;
/// ```
class AvoidReturningCascadesRule extends SaropaLintRule {
  AvoidReturningCascadesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_returning_cascades',
    '[avoid_returning_cascades] Return statement contains a cascade expression (..operator), which obscures the actual return value and can confuse readers about whether the returned object is the cascade target or the result of the last cascade operation. Separating the cascade from the return makes the control flow explicit and easier to debug. {v4}',
    correctionMessage:
        'Assign the cascade result to a variable first, then return the variable on a separate line.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addReturnStatement((ReturnStatement node) {
      final Expression? expression = node.expression;
      if (expression is CascadeExpression) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when a function explicitly returns `void`.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Returning void is unnecessary and can be confusing.
///
/// Example of **bad** code:
/// ```dart
/// void doSomething() {
///   return;  // unnecessary
/// }
/// void doOther() {
///   return void;  // confusing
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void doSomething() {
///   // Just don't return
/// }
/// ```
class AvoidReturningVoidRule extends SaropaLintRule {
  AvoidReturningVoidRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_returning_void',
    '[avoid_returning_void] Explicit void return is redundant and can mask accidental side-effect returns. '
        'Writing return at the end of a void function adds visual noise without changing behavior, and in rare cases may hide a mistaken attempt to return a value from a void-typed function. {v6}',
    correctionMessage:
        'Remove the explicit return statement entirely, since void functions implicitly return at the end of their body. '
        'If you need early exit, use a bare return without a value. If you intended to return a result, change the function return type to match.',
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

      // Check for 'return;' which is fine
      // We're looking for 'return <void expression>'
      if (expression is MethodInvocation) {
        // Check if the method returns void
        final DartType? returnType = expression.staticType;
        if (returnType != null && returnType is VoidType) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns on unnecessary return statement at end of void function.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// A return statement with no value at the end of a void function is redundant.
///
/// Example of **bad** code:
/// ```dart
/// void doSomething() {
///   print('hello');
///   return;  // Unnecessary
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void doSomething() {
///   print('hello');
/// }
/// ```
///
/// **Quick fix available:** Removes the unnecessary return.
class AvoidUnnecessaryReturnRule extends SaropaLintRule {
  AvoidUnnecessaryReturnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        RemoveUnnecessaryReturnFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_unnecessary_return',
    '[avoid_unnecessary_return] Unnecessary return statement at end of void function. This return pattern causes unexpected control flow and makes function behavior harder to predict. {v5}',
    correctionMessage:
        'Remove the redundant return statement. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkFunction(node.body, node.returnType, reporter);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunction(node.functionExpression.body, node.returnType, reporter);
    });
  }

  void _checkFunction(
    FunctionBody body,
    TypeAnnotation? returnType,
    SaropaDiagnosticReporter reporter,
  ) {
    // Only check void functions
    if (returnType is! NamedType) return;
    if (returnType.name.lexeme != 'void') return;

    if (body is! BlockFunctionBody) return;

    final NodeList<Statement> statements = body.block.statements;
    if (statements.isEmpty) return;

    final Statement lastStatement = statements.last;

    // Check if last statement is a bare return
    if (lastStatement is ReturnStatement && lastStatement.expression == null) {
      reporter.atNode(lastStatement);
    }
  }
}

/// Warns when a variable is declared and immediately returned.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v6
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Example of **bad** code:
/// ```dart
/// String getName() {
///   final name = computeName();
///   return name;
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// String getName() {
///   return computeName();
/// }
/// ```
///
/// **Quick fix available:** Inlines the expression into the return statement.
class PreferImmediateReturnRule extends SaropaLintRule {
  PreferImmediateReturnRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        InlineImmediateReturnFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_immediate_return',
    '[prefer_immediate_return] Returning an expression directly instead of assigning to a variable first is a stylistic preference. Both produce the same compiled output. Enable via the stylistic tier. {v6}',
    correctionMessage:
        'Return the expression directly instead of storing in a variable. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBlock((Block node) {
      final List<Statement> statements = node.statements;
      if (statements.length < 2) return;

      // Check the last two statements
      final Statement secondLast = statements[statements.length - 2];
      final Statement last = statements[statements.length - 1];

      // Second last should be a variable declaration
      if (secondLast is! VariableDeclarationStatement) return;

      // Last should be a return statement
      if (last is! ReturnStatement) return;

      final ReturnStatement returnStmt = last;
      final Expression? returnExpr = returnStmt.expression;
      if (returnExpr is! SimpleIdentifier) return;

      // Check if the returned variable is the one just declared
      final VariableDeclarationList declList = secondLast.variables;
      if (declList.variables.length != 1) return;

      final VariableDeclaration decl = declList.variables.first;
      if (decl.name.lexeme == returnExpr.name && decl.initializer != null) {
        reporter.atNode(secondLast);
      }
    });
  }
}

/// Warns when arrow function could be used instead of block.
///
/// Since: v1.5.1 | Updated: v4.13.0 | Rule version: v5
///
/// **Stylistic rule (opt-in only).** No performance or correctness benefit.
///
/// Simple return statements should use arrow syntax.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// int getValue() {
///   return 42;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// int getValue() => 42;
/// ```
///
/// **Quick fix available:** Converts to expression body with =>.
class PreferReturningShorthandsRule extends SaropaLintRule {
  PreferReturningShorthandsRule() : super(code: _code);

  /// Stylistic preference only. No performance or correctness benefit.
  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_returning_shorthands',
    '[prefer_returning_shorthands] Simplifying return expressions to shorter forms is a code style preference. Both produce equivalent compiled output with no performance impact. Enable via the stylistic tier. {v5}',
    correctionMessage:
        'Convert to expression body with =>. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodDeclaration((MethodDeclaration node) {
      _checkBody(node.body, node.name, reporter);
    });

    context.addFunctionDeclaration((FunctionDeclaration node) {
      _checkBody(node.functionExpression.body, node.name, reporter);
    });
  }

  void _checkBody(
    FunctionBody body,
    Token nameToken,
    SaropaDiagnosticReporter reporter,
  ) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    if (block.statements.length != 1) return;

    final Statement stmt = block.statements.first;
    if (stmt is ReturnStatement && stmt.expression != null) {
      // Single return statement - could use arrow
      reporter.atToken(nameToken);
    }
  }
}

/// Warns when returning `null` from a function with `void` return type.
///
/// Since: v5.1.0 | Rule version: v1
///
/// In Dart, `void` functions don't need to return anything. Returning `null`
/// explicitly is redundant and suggests the developer may have the wrong
/// return type.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// void doWork() {
///   print('done');
///   return null;
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// void doWork() {
///   print('done');
///   return;
/// }
/// ```
class AvoidReturningNullForVoidRule extends SaropaLintRule {
  AvoidReturningNullForVoidRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_returning_null_for_void',
    '[avoid_returning_null_for_void] Returning null from a void function is '
        'redundant and misleading. Void functions should either use a bare '
        'return statement or simply let execution fall through. An explicit '
        'return null suggests the caller expects a value, which contradicts '
        'the void return type and confuses readers. {v1}',
    correctionMessage:
        'Replace "return null;" with "return;" or remove the return '
        'statement entirely.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addReturnStatement((ReturnStatement node) {
      final Expression? expr = node.expression;
      if (expr is! NullLiteral) return;

      final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
      if (body == null) return;

      final DartType? returnType = getReturnTypeFromBody(body);
      if (returnType == null) return;
      if (returnType is! VoidType) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when returning `null` from a non-async `Future` function.
///
/// Since: v5.1.0 | Rule version: v1
///
/// Returning `null` from a non-async function that returns `Future<T>` can
/// cause a NullPointerException at runtime if T is non-nullable.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// Future<String> fetchName() {
///   return null; // Runtime NPE when awaited
/// }
/// ```
///
/// #### GOOD:
/// ```dart
/// Future<String> fetchName() {
///   return Future.value('default');
/// }
/// // or:
/// Future<String> fetchName() async {
///   return 'default';
/// }
/// ```
class AvoidReturningNullForFutureRule extends SaropaLintRule {
  AvoidReturningNullForFutureRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_returning_null_for_future',
    '[avoid_returning_null_for_future] Returning null from a synchronous '
        'function declared to return Future<T> where T is non-nullable causes '
        'a runtime null error when the future is awaited. Use Future.value() '
        'to wrap the default, or make the function async to let Dart handle '
        'the future wrapping automatically. {v1}',
    correctionMessage:
        'Wrap the value with Future.value() or make the function async.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addReturnStatement((ReturnStatement node) {
      final Expression? expr = node.expression;
      if (expr is! NullLiteral) return;

      final FunctionBody? body = node.thisOrAncestorOfType<FunctionBody>();
      if (body == null) return;

      // Only flag synchronous functions — async functions handle null fine
      if (body.isAsynchronous) return;

      final DartType? returnType = getReturnTypeFromBody(body);
      if (returnType == null) return;
      if (!returnType.isDartAsyncFuture) return;

      reporter.atNode(node);
    });
  }
}
