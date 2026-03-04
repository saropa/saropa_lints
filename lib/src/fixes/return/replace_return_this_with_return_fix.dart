// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace "return this;" with "return;".
///
/// Matches [AvoidReturningThisRule]. Caller may need to change method return type to void.
class ReplaceReturnThisWithReturnFix extends ReplaceNodeFix {
  ReplaceReturnThisWithReturnFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceReturnThisWithReturn',
    50,
    'Replace return this with return',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    return 'return;';
  }
}
