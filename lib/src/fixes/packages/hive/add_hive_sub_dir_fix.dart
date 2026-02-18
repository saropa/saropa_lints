// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';

import '../../../native/saropa_fix.dart';

/// Quick fix: Add subdirectory parameter
class AddHiveSubDirFix extends SaropaFixProducer {
  AddHiveSubDirFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addHiveSubDirFix',
    50,
    'Add subdirectory parameter',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is MethodInvocation
        ? node
        : node.thisOrAncestorOfType<MethodInvocation>();
    if (target == null) return;

    // Add subDir argument to existing argument list
    final args = target.argumentList;
    final rightParen = args.rightParenthesis;

    final prefix = args.arguments.isEmpty ? '' : ', ';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleInsertion(
        rightParen.offset,
        "${prefix}subDirectory: 'hive_data'",
      );
    });
  }
}
