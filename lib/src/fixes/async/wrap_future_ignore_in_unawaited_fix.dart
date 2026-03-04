// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace Future.ignore() with unawaited(future).
///
/// Matches [AvoidFutureIgnoreRule].
class WrapFutureIgnoreInUnawaitedFix extends ReplaceNodeFix {
  WrapFutureIgnoreInUnawaitedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapFutureIgnoreInUnawaited',
    50,
    'Replace with unawaited()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is MethodInvocation &&
        node.methodName.name == 'ignore' &&
        node.target != null) {
      return 'unawaited(${node.target!.toSource()})';
    }
    return node.toSource();
  }
}
