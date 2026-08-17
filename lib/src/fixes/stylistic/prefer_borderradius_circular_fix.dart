// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: replace `BorderRadius.all(Radius.circular(r))` with
/// `BorderRadius.circular(r)`.
///
/// The rule reports at the InstanceCreationExpression for BorderRadius.all().
/// This fix extracts the inner radius value and rewrites the constructor call.
class PreferBorderRadiusCircularFix extends ReplaceNodeFix {
  PreferBorderRadiusCircularFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferBorderRadiusCircular',
    50,
    'Use BorderRadius.circular(r)',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! InstanceCreationExpression) return node.toSource();

    // Extract the Radius.circular(r) argument
    final args = node.argumentList.arguments;
    if (args.length != 1) return node.toSource();

    final inner = args.first;
    if (inner is! InstanceCreationExpression) return node.toSource();

    // Extract the radius value from Radius.circular(r)
    final innerArgs = inner.argumentList.arguments;
    if (innerArgs.length != 1) return node.toSource();

    final radiusValue = innerArgs.first.toSource();

    // Preserve const keyword if present
    final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';

    return '${constPrefix}BorderRadius.circular($radiusValue)';
  }
}
