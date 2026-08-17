// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../common/replace_node_fix.dart';
import '../../native/saropa_fix.dart';

/// Quick fix: replace `Container(width: w, height: h)` with
/// `SizedBox(width: w, height: h)`.
///
/// The rule only fires when Container has only width/height/child/key args,
/// so the fix is a simple constructor rename — all arguments carry over.
class PreferSizedBoxOverContainerFix extends ReplaceNodeFix {
  PreferSizedBoxOverContainerFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferSizedBoxOverContainer',
    50,
    'Replace Container with SizedBox',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  String computeReplacement(AstNode node) {
    if (node is! InstanceCreationExpression) return node.toSource();

    final source = node.toSource();

    // Preserve const keyword if present
    final constPrefix = node.keyword?.lexeme == 'const' ? 'const ' : '';

    // Extract arguments source
    final argsSource = node.argumentList.toSource();

    return '${constPrefix}SizedBox$argsSource';
  }
}
