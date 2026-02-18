// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add const keyword
class PreferDeclaringConstConstructorFix extends SaropaFixProducer {
  PreferDeclaringConstConstructorFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferDeclaringConstConstructorFix',
    4000,
    'Add const keyword',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ConstructorDeclaration
        ? node
        : node.thisOrAncestorOfType<ConstructorDeclaration>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, 'const ');
    });
  }
}
