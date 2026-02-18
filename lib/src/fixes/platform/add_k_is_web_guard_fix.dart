// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add kIsWeb guard
class AddKIsWebGuardFix extends SaropaFixProducer {
  AddKIsWebGuardFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addKIsWebGuardFix',
    50,
    'Add kIsWeb guard',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Find the PrefixedIdentifier (Platform.isXxx)
    final target = node is PrefixedIdentifier
        ? node
        : node.thisOrAncestorOfType<PrefixedIdentifier>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(target.offset, '!kIsWeb && ');
    });
  }
}
