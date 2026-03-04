// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add trailing comma before closing delimiter.
///
/// Matches [PreferTrailingCommaRule].
class AddTrailingCommaFix extends SaropaFixProducer {
  AddTrailingCommaFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addTrailingComma',
    50,
    'Add trailing comma',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final listLit = node.thisOrAncestorOfType<ListLiteral>();
    final setMap = node.thisOrAncestorOfType<SetOrMapLiteral>();
    final argList = node.thisOrAncestorOfType<ArgumentList>();
    final paramList = node.thisOrAncestorOfType<FormalParameterList>();

    final int insertOffset;
    if (listLit != null) {
      insertOffset = listLit.rightBracket.offset;
    } else if (setMap != null) {
      insertOffset = setMap.rightBracket.offset;
    } else if (argList != null) {
      insertOffset = argList.rightParenthesis.offset;
    } else if (paramList != null) {
      insertOffset = paramList.rightParenthesis.offset;
    } else {
      return;
    }

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(insertOffset, ',');
    });
  }
}
