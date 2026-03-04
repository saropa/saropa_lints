// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace .values.firstWhere((e) => e.name == x) with .values.byName(x).
///
/// Matches [PreferEnumsByNameRule].
class ReplaceFirstWhereWithByNameFix extends SaropaFixProducer {
  ReplaceFirstWhereWithByNameFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceFirstWhereWithByName',
    50,
    'Use .byName() instead of .firstWhere()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final MethodInvocation? invocation = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (invocation == null || invocation.methodName.name != 'firstWhere') {
      return;
    }

    final Expression? target = invocation.target;
    if (target is! PropertyAccess || target.propertyName.name != 'values') {
      return;
    }

    final NodeList<Expression> args = invocation.argumentList.arguments;
    if (args.isEmpty) return;

    final Expression firstArg = args.first;
    if (firstArg is! FunctionExpression) return;

    final FunctionBody body = firstArg.body;
    if (body is! ExpressionFunctionBody) return;

    final Expression expr = body.expression;
    if (expr is! BinaryExpression || expr.operator.lexeme != '==') return;

    final Expression left = expr.leftOperand;
    final Expression right = expr.rightOperand;
    final String? valueSrc = _nameComparisonValue(left, right);
    if (valueSrc == null) return;

    final String receiverSrc = target.toSource();
    final String replacement = '$receiverSrc.byName($valueSrc)';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(invocation.offset, invocation.length),
        replacement,
      );
    });
  }

  /// Returns the source of the value side (string or expr) in e.name == value.
  String? _nameComparisonValue(Expression left, Expression right) {
    if (_isNameAccess(left)) {
      return right.toSource();
    }
    if (_isNameAccess(right)) {
      return left.toSource();
    }
    return null;
  }

  bool _isNameAccess(Expression expr) {
    if (expr is PrefixedIdentifier) {
      return expr.identifier.name == 'name';
    }
    if (expr is PropertyAccess) {
      return expr.propertyName.name == 'name';
    }
    return false;
  }
}
