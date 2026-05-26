/// Per-function complexity scanner over PARSED (unresolved) AST.
///
/// Parsed AST keeps memory flat at scale — no element model is built or kept.
/// Computes cyclomatic + cognitive complexity, local-variable count, parameter
/// count, max boolean-condition density, nesting depth, and exit points.
library;

import 'dart:math' as math;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';

import 'metrics_model.dart';

/// Parses [content] and returns one [FunctionMetric] per top-level function and
/// method. Nested closures/local functions fold into their enclosing function
/// (cognitive complexity is meant to accumulate nesting), so they are not
/// reported separately. Returns empty on unparseable input rather than throwing.
List<FunctionMetric> scanComplexity(String content) => scanComplexityUnit(
  parseString(content: content, throwIfDiagnostics: false).unit,
);

/// Like [scanComplexity] but reuses an already-parsed [unit] so callers that
/// need several metrics from one file parse it only once.
List<FunctionMetric> scanComplexityUnit(CompilationUnit unit) {
  final scanner = _UnitScanner(unit.lineInfo);
  unit.visitChildren(scanner);
  return scanner.functions;
}

/// Walks the unit, recording one metric per method / top-level function. Does
/// not descend into a recorded function's body (nested functions fold in).
class _UnitScanner extends RecursiveAstVisitor<void> {
  _UnitScanner(this._lineInfo);

  final LineInfo _lineInfo;
  final List<FunctionMetric> functions = [];

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _record(node.name.lexeme, node.parameters, node.body);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _record(
      node.name.lexeme,
      node.functionExpression.parameters,
      node.functionExpression.body,
    );
  }

  void _record(String name, FormalParameterList? params, FunctionBody body) {
    final m = _BodyMetrics()..analyze(body);
    functions.add(
      FunctionMetric(
        name: name,
        lineStart: _lineInfo.getLocation(body.offset).lineNumber,
        lineEnd: _lineInfo.getLocation(body.end).lineNumber,
        cyclomatic: m.cyclomatic,
        cognitive: m.cognitive,
        variableCount: m.variables,
        parameterCount: params?.parameters.length ?? 0,
        maxBooleanTerms: m.maxBooleanTerms,
        nesting: m.maxNesting,
        exitPoints: m.exits,
      ),
    );
    // Intentionally NOT calling super: a recorded function's nested functions
    // fold into its metrics rather than being reported on their own.
  }
}

/// Accumulates metrics for a single function body, tracking nesting depth so
/// cognitive complexity weights deeply-nested branches more heavily.
class _BodyMetrics extends RecursiveAstVisitor<void> {
  int cyclomatic = 1; // McCabe: decision points + 1
  int cognitive = 0;
  int variables = 0;
  int exits = 0;
  int maxBooleanTerms = 0;
  int maxNesting = 0;
  int _depth = 0;

  void analyze(FunctionBody body) => body.visitChildren(this);

  void _branch(AstNode node, Expression? condition) {
    cyclomatic++;
    cognitive += 1 + _depth;
    if (condition != null) {
      maxBooleanTerms = math.max(maxBooleanTerms, _countLogicalOps(condition));
    }
    _depth++;
    maxNesting = math.max(maxNesting, _depth);
    node.visitChildren(this);
    _depth--;
  }

  @override
  void visitIfStatement(IfStatement node) {
    // "else" (a real else, not else-if) adds a readability cost without nesting.
    if (node.elseStatement != null && node.elseStatement is! IfStatement) {
      cognitive += 1;
    }
    _branch(node, node.expression);
  }

  @override
  void visitForStatement(ForStatement node) => _branch(node, null);

  @override
  void visitWhileStatement(WhileStatement node) =>
      _branch(node, node.condition);

  @override
  void visitDoStatement(DoStatement node) => _branch(node, node.condition);

  @override
  void visitSwitchStatement(SwitchStatement node) =>
      _branch(node, node.expression);

  @override
  void visitSwitchCase(SwitchCase node) {
    cyclomatic++;
    node.visitChildren(this);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    cyclomatic++;
    node.visitChildren(this);
  }

  @override
  void visitCatchClause(CatchClause node) => _branch(node, null);

  @override
  void visitConditionalExpression(ConditionalExpression node) =>
      _branch(node, node.condition);

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') {
      cyclomatic++;
      cognitive++; // logical operators add flat cost (SonarSource convention)
    }
    node.visitChildren(this);
  }

  @override
  void visitFunctionExpression(FunctionExpression node) {
    // A nested closure deepens nesting for cognitive purposes.
    _depth++;
    maxNesting = math.max(maxNesting, _depth);
    node.visitChildren(this);
    _depth--;
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    variables++;
    node.visitChildren(this);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    exits++;
    node.visitChildren(this);
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    exits++;
    node.visitChildren(this);
  }
}

/// Counts `&&`, `||`, and `!` operators in [e] — a proxy for how hard a single
/// boolean condition is to read.
int _countLogicalOps(Expression e) {
  final counter = _LogicalOpCounter();
  e.accept(counter);
  return counter.count;
}

class _LogicalOpCounter extends RecursiveAstVisitor<void> {
  int count = 0;

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final op = node.operator.lexeme;
    if (op == '&&' || op == '||') count++;
    node.visitChildren(this);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    if (node.operator.lexeme == '!') count++;
    node.visitChildren(this);
  }
}
