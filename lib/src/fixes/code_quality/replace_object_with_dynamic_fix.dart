// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Replace type Object with dynamic.
///
/// Matches [NoObjectDeclarationRule].
class ReplaceObjectWithDynamicFix extends ReplaceNodeFix {
  ReplaceObjectWithDynamicFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceObjectWithDynamic',
    50,
    'Replace Object with dynamic',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    return 'dynamic';
  }
}
