// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import '../../native/saropa_fix.dart';

/// Inserts `super.onInit()` / `super.onReady()` at the start of the method
/// body, or `super.onClose()` before the closing brace of [onClose].
class InsertGetxSuperLifecycleCallFix extends SaropaFixProducer {
  InsertGetxSuperLifecycleCallFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.insertGetxSuperLifecycleCallFix',
    50,
    'Insert super lifecycle call',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final method = node is MethodDeclaration
        ? node
        : node?.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    final name = method.name.lexeme;
    if (name != 'onInit' && name != 'onReady' && name != 'onClose') return;

    final body = method.body;
    if (body is! BlockFunctionBody) return;
    final block = body.block;
    final statements = block.statements;
    final indent = getLineIndent(method);

    if (statements.isEmpty) {
      final insertOffset = block.leftBracket.end;
      final call = name == 'onClose' ? 'super.onClose();' : 'super.$name();';
      final insertion = '\n$indent$call\n$indent';
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(insertOffset, insertion);
      });
      return;
    }

    if (name == 'onClose') {
      final insertOffset = block.rightBracket.offset;
      final insertion = '$indent super.onClose();\n';
      await builder.addDartFileEdit(file, (builder) {
        builder.addSimpleInsertion(insertOffset, insertion);
      });
      return;
    }

    final first = statements.first;
    final insertOffset = first.offset;
    final insertion = '$indent super.$name();\n';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
