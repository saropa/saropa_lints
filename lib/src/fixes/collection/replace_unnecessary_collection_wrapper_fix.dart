// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary List.of/Set.of wrapper (e.g. List.of([1,2]) → [1,2]).
///
/// Matches [AvoidUnnecessaryCollectionsRule].
class ReplaceUnnecessaryCollectionWrapperFix extends ReplaceNodeFix {
  ReplaceUnnecessaryCollectionWrapperFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceUnnecessaryCollectionWrapper',
    50,
    'Use collection literal directly',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! MethodInvocation) return node.toSource();
    final args = node.argumentList.arguments;
    if (args.length != 1) return node.toSource();
    final arg = args.first;
    if (arg is! ListLiteral && arg is! SetOrMapLiteral) return node.toSource();
    return arg.toSource();
  }
}
