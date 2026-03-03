// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove redundant else clause.
///
/// Matches [AvoidRedundantElseRule]. Deletes from "else" through the else body.
///
/// **For developers:** Requires [IfStatement] with elseKeyword and elseStatement; single range deletion.
class RemoveRedundantElseFix extends SaropaFixProducer {
  RemoveRedundantElseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeRedundantElseFix',
    50,
    'Remove redundant else',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ifStatement = node.thisOrAncestorOfType<IfStatement>();
    if (ifStatement == null) return;

    final Token? elseKeyword = ifStatement.elseKeyword;
    final Statement? elseStatement = ifStatement.elseStatement;
    if (elseKeyword == null || elseStatement == null) return;

    final int start = elseKeyword.offset;
    final int end = elseStatement.end;

    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(start, end - start));
    });
  }
}
