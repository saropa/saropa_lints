// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace "return null;" with "return Future.value(null);" in Future functions.
///
/// Matches [AvoidReturningNullForFutureRule].
class ReplaceReturnNullWithFutureValueFix extends ReplaceNodeFix {
  ReplaceReturnNullWithFutureValueFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceReturnNullWithFutureValue',
    50,
    'Replace with Future.value(null)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    return 'return Future.value(null);';
  }
}
