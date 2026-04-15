// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add `abstract final` modifiers before the class keyword.
///
/// Matches [PreferAbstractFinalStaticClassRule].
class AddAbstractFinalFix extends SaropaFixProducer {
  AddAbstractFinalFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addAbstractFinal',
    50,
    'Add abstract final modifiers',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final classDecl = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDecl == null) return;

    // Insert `abstract final ` before the `class` keyword.
    final classKeyword = classDecl.classKeyword;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleInsertion(classKeyword.offset, 'abstract final ');
    });
  }
}
