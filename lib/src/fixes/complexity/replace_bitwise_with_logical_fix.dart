// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace bitwise `&`/`|` with logical `&&`/`||`.
class ReplaceBitwiseWithLogicalFix extends SaropaFixProducer {
  ReplaceBitwiseWithLogicalFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceBitwiseWithLogical',
    50,
    'Replace with logical operator',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final binary = node is BinaryExpression
        ? node
        : node.thisOrAncestorOfType<BinaryExpression>();
    if (binary == null) return;

    final op = binary.operator;
    final String replacement;
    if (op.type == TokenType.AMPERSAND) {
      replacement = '&&';
    } else if (op.type == TokenType.BAR) {
      replacement = '||';
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(op.offset, op.length),
        replacement,
      );
    });
  }
}
