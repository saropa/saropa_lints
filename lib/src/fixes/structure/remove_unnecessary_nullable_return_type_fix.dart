// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary nullable return type (T? → T).
///
/// Matches [AvoidUnnecessaryNullableReturnTypeRule].
class RemoveUnnecessaryNullableReturnTypeFix extends ReplaceNodeFix {
  RemoveUnnecessaryNullableReturnTypeFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryNullableReturnType',
    50,
    'Remove unnecessary nullable return type',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! NamedType) return node.toSource();
    final question = node.question;
    if (question == null) return node.toSource();
    final typeName = node.name.lexeme;
    final typeArgs = node.typeArguments;
    final argsSource = typeArgs?.toSource() ?? '';
    return '$typeName$argsSource';
  }
}
