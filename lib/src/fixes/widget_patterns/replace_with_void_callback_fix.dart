// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace with VoidCallback
class ReplaceWithVoidCallbackFix extends SaropaFixProducer {
  ReplaceWithVoidCallbackFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceWithVoidCallbackFix',
    50,
    'Replace with VoidCallback',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is GenericFunctionType
        ? node
        : node.thisOrAncestorOfType<GenericFunctionType>();
    if (target == null) return;

    // Replace void Function() with VoidCallback
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        'VoidCallback',
      );
    });
  }
}
