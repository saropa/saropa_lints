// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add final modifier
class PreferFinalClassFix extends SaropaFixProducer {
  PreferFinalClassFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferFinalClassFix',
    4000,
    'Add final modifier',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is ClassDeclaration
        ? node
        : node.thisOrAncestorOfType<ClassDeclaration>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.classKeyword.offset, 'final ');
    });
  }
}
