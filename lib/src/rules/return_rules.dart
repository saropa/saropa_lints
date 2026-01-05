// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Warns when returning a cascade expression.
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
class AvoidReturningCascadesRule extends DartLintRule {
  const AvoidReturningCascadesRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_returning_cascades',
    problemMessage: 'Avoid returning cascade expressions.',
    correctionMessage: 'Separate the cascade from the return statement.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      final Expression? expression = node.expression;
      if (expression is CascadeExpression) {
        reporter.atNode(node, code);
      }
    });
  }
}

/// Warns when a function explicitly returns `void`.
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
class AvoidReturningVoidRule extends DartLintRule {
  const AvoidReturningVoidRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_returning_void',
    problemMessage: 'Avoid explicitly returning void.',
    correctionMessage: 'Remove the return statement or use return without a value.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addReturnStatement((ReturnStatement node) {
      final Expression? expression = node.expression;
      if (expression == null) return;

      // Check for 'return;' which is fine
      // We're looking for 'return <void expression>'
      if (expression is MethodInvocation) {
        // Check if the method returns void
        final DartType? returnType = expression.staticType;
        if (returnType != null && returnType is VoidType) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

/// Warns on unnecessary return statement at end of void function.
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
class AvoidUnnecessaryReturnRule extends DartLintRule {
  const AvoidUnnecessaryReturnRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_return',
    problemMessage: 'Unnecessary return statement at end of void function.',
    correctionMessage: 'Remove the redundant return statement.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkFunction(node.body, node.returnType, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkFunction(
        node.functionExpression.body,
        node.returnType,
        reporter,
      );
    });
  }

  void _checkFunction(
    FunctionBody body,
    TypeAnnotation? returnType,
    ErrorReporter reporter,
  ) {
    // Only check void functions
    if (returnType is! NamedType) return;
    if (returnType.name2.lexeme != 'void') return;

    if (body is! BlockFunctionBody) return;

    final NodeList<Statement> statements = body.block.statements;
    if (statements.isEmpty) return;

    final Statement lastStatement = statements.last;

    // Check if last statement is a bare return
    if (lastStatement is ReturnStatement && lastStatement.expression == null) {
      reporter.atNode(lastStatement, code);
    }
  }
}

/// Warns when a variable is declared and immediately returned.
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
class PreferImmediateReturnRule extends DartLintRule {
  const PreferImmediateReturnRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_immediate_return',
    problemMessage: 'Variable is declared and immediately returned.',
    correctionMessage: 'Return the expression directly instead of storing in a variable.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addBlock((Block node) {
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
        reporter.atNode(secondLast, code);
      }
    });
  }
}

/// Warns when arrow function could be used instead of block.
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
class PreferReturningShorthandsRule extends DartLintRule {
  const PreferReturningShorthandsRule() : super(code: _code);

  static const LintCode _code = LintCode(
    name: 'prefer_returning_shorthands',
    problemMessage: 'Use arrow syntax for simple return statements.',
    correctionMessage: 'Convert to expression body with =>.',
    errorSeverity: ErrorSeverity.INFO,
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkBody(node.body, node.name, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkBody(node.functionExpression.body, node.name, reporter);
    });
  }

  void _checkBody(FunctionBody body, Token nameToken, ErrorReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    if (block.statements.length != 1) return;

    final Statement stmt = block.statements.first;
    if (stmt is ReturnStatement && stmt.expression != null) {
      // Single return statement - could use arrow
      reporter.atToken(nameToken, code);
    }
  }
}
