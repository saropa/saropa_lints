// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace "return null;" with "return;" in void functions.
///
/// Matches [AvoidReturningNullForVoidRule].
///
/// **For developers:** [ReplaceNodeFix]; replacement is always "return;" (full statement replaced).
class ReplaceReturnNullWithReturnFix extends ReplaceNodeFix {
  ReplaceReturnNullWithReturnFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceReturnNullWithReturnFix',
    50,
    'Replace return null with return',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    return 'return;';
  }
}
