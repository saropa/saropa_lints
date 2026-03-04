// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Use enum dot shorthand (MyEnum.value → .value).
///
/// Matches [PreferDotShorthandRule].
class PreferDotShorthandFix extends ReplaceNodeFix {
  PreferDotShorthandFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDotShorthand',
    50,
    'Use enum dot shorthand',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! PrefixedIdentifier) return node.toSource();
    return '.${node.identifier.name}';
  }
}
