// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add `@useResult` annotation before a method declaration.
///
/// Matches [MissingUseResultAnnotationRule].
class AddUseResultFix extends SaropaFixProducer {
  AddUseResultFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addUseResult',
    50,
    'Add @useResult annotation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    final indent = getLineIndent(method);

    // Insert `@useResult\n<indent>` before the method declaration.
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(method.offset, '@useResult\n$indent');
    });
  }
}
