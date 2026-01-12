// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

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
class AvoidReturningCascadesRule extends SaropaLintRule {
  const AvoidReturningCascadesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_returning_cascades',
    problemMessage: '[avoid_returning_cascades] Avoid returning cascade expressions.',
    correctionMessage: 'Separate the cascade from the return statement.',
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
class AvoidReturningVoidRule extends SaropaLintRule {
  const AvoidReturningVoidRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_returning_void',
    problemMessage: '[avoid_returning_void] Avoid explicitly returning void.',
    correctionMessage:
        'Remove the return statement or use return without a value.',
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
///
/// **Quick fix available:** Removes the unnecessary return.
class AvoidUnnecessaryReturnRule extends SaropaLintRule {
  const AvoidUnnecessaryReturnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_unnecessary_return',
    problemMessage: '[avoid_unnecessary_return] Unnecessary return statement at end of void function.',
    correctionMessage: 'Remove the redundant return statement.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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
      reporter.atNode(lastStatement, code);
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveUnnecessaryReturnFix()];
}

class _RemoveUnnecessaryReturnFix extends DartFix {
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
      if (node.expression != null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Remove unnecessary return',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Delete the entire statement including trailing newline if present
        builder.addDeletion(SourceRange(node.offset, node.length));
      });
    });
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
///
/// **Quick fix available:** Inlines the expression into the return statement.
class PreferImmediateReturnRule extends SaropaLintRule {
  const PreferImmediateReturnRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_immediate_return',
    problemMessage: '[prefer_immediate_return] Variable is declared and immediately returned.',
    correctionMessage:
        'Return the expression directly instead of storing in a variable.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
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

  @override
  List<Fix> getFixes() => <Fix>[_InlineImmediateReturnFix()];
}

class _InlineImmediateReturnFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addBlock((Block node) {
      final List<Statement> statements = node.statements;
      if (statements.length < 2) return;

      final Statement secondLast = statements[statements.length - 2];
      final Statement last = statements[statements.length - 1];

      if (secondLast is! VariableDeclarationStatement) return;
      if (!secondLast.sourceRange.intersects(analysisError.sourceRange)) return;
      if (last is! ReturnStatement) return;

      final VariableDeclarationList declList = secondLast.variables;
      if (declList.variables.length != 1) return;

      final VariableDeclaration decl = declList.variables.first;
      final Expression? initializer = decl.initializer;
      if (initializer == null) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Return expression directly',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Replace both statements with a single return
        builder.addSimpleReplacement(
          SourceRange(secondLast.offset, last.end - secondLast.offset),
          'return ${initializer.toSource()};',
        );
      });
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
///
/// **Quick fix available:** Converts to expression body with =>.
class PreferReturningShorthandsRule extends SaropaLintRule {
  const PreferReturningShorthandsRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'prefer_returning_shorthands',
    problemMessage: '[prefer_returning_shorthands] Use arrow syntax for simple return statements.',
    correctionMessage: 'Convert to expression body with =>.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      _checkBody(node.body, node.name, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      _checkBody(node.functionExpression.body, node.name, reporter);
    });
  }

  void _checkBody(
      FunctionBody body, Token nameToken, SaropaDiagnosticReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    if (block.statements.length != 1) return;

    final Statement stmt = block.statements.first;
    if (stmt is ReturnStatement && stmt.expression != null) {
      // Single return statement - could use arrow
      reporter.atToken(nameToken, code);
    }
  }

  @override
  List<Fix> getFixes() => <Fix>[_ConvertToArrowSyntaxFix()];
}

class _ConvertToArrowSyntaxFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((MethodDeclaration node) {
      if (!node.name.sourceRange.intersects(analysisError.sourceRange)) return;
      _applyFix(node.body, reporter);
    });

    context.registry.addFunctionDeclaration((FunctionDeclaration node) {
      if (!node.name.sourceRange.intersects(analysisError.sourceRange)) return;
      _applyFix(node.functionExpression.body, reporter);
    });
  }

  void _applyFix(FunctionBody body, ChangeReporter reporter) {
    if (body is! BlockFunctionBody) return;

    final Block block = body.block;
    if (block.statements.length != 1) return;

    final Statement stmt = block.statements.first;
    if (stmt is! ReturnStatement || stmt.expression == null) return;

    final Expression expr = stmt.expression!;

    final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
      message: 'Convert to arrow syntax',
      priority: 1,
    );

    changeBuilder.addDartFileEdit((builder) {
      // Replace the entire body (from { to }) with => expression;
      builder.addSimpleReplacement(
        SourceRange(body.offset, body.length),
        '=> ${expr.toSource()};',
      );
    });
  }
}
