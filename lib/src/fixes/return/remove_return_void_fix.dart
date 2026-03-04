// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace "return voidCall();" with "voidCall();".
///
/// Matches [AvoidReturningVoidRule].
class RemoveReturnVoidFix extends ReplaceNodeFix {
  RemoveReturnVoidFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeReturnVoid',
    50,
    'Remove return from void expression',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is ReturnStatement && node.expression != null) {
      return '${node.expression!.toSource()};';
    }
    return node.toSource();
  }
}
