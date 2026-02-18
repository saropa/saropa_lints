// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Use isEmpty or isNotEmpty
class UseIsEmptyOrIsNotEmptyFix extends SaropaFixProducer {
  UseIsEmptyOrIsNotEmptyFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.useIsEmptyOrIsNotEmptyFix',
    50,
    'Use isEmpty or isNotEmpty',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (target == null) return;

    // Replace x.length == 0 with x.isEmpty, x.length != 0 with x.isNotEmpty
    final left = target.leftOperand;
    final right = target.rightOperand;
    final op = target.operator.type;

    // Pattern: collection.length == 0 or collection.length > 0
    Expression? lengthAccess;
    if (left is PropertyAccess && left.propertyName.name == 'length') {
      lengthAccess = left.target;
    } else if (left is PrefixedIdentifier && left.identifier.name == 'length') {
      lengthAccess = left.prefix;
    }
    if (lengthAccess == null) return;

    // Determine isEmpty or isNotEmpty based on operator
    final String property;
    if (op == TokenType.EQ_EQ && right is IntegerLiteral && right.value == 0) {
      property = 'isEmpty';
    } else if (op == TokenType.BANG_EQ && right is IntegerLiteral && right.value == 0) {
      property = 'isNotEmpty';
    } else if (op == TokenType.GT && right is IntegerLiteral && right.value == 0) {
      property = 'isNotEmpty';
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        '${lengthAccess!.toSource()}.$property',
      );
    });
  }
}
