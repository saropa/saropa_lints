// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Change to onUserInteraction
class ChangeToOnUserInteractionFix extends SaropaFixProducer {
  ChangeToOnUserInteractionFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.changeToOnUserInteractionFix',
    50,
    'Change to onUserInteraction',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is PrefixedIdentifier
        ? node
        : node.thisOrAncestorOfType<PrefixedIdentifier>();
    if (target == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        'AutovalidateMode.onUserInteraction',
      );
    });
  }
}
