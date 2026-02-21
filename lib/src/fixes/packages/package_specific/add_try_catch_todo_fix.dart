// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Wrap in try-catch
class AddTryCatchTodoFix extends SaropaFixProducer {
  AddTryCatchTodoFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addTryCatchTodoFix',
    50,
    'Wrap in try-catch',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find enclosing ExpressionStatement to wrap
    final stmt = node is ExpressionStatement
        ? node
        : node.thisOrAncestorOfType<ExpressionStatement>();
    if (stmt == null) return;

    final indent = getLineIndent(stmt);
    final source = stmt.toSource();

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(stmt.offset, stmt.length),
        'try {\n$indent  $source\n$indent} catch (e) {\n'
        "$indent  // TODO: handle error\n$indent}",
      );
    });
  }
}
