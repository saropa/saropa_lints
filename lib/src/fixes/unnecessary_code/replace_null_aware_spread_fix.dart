// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace ...? with ...
class ReplaceNullAwareSpreadFix extends SaropaFixProducer {
  ReplaceNullAwareSpreadFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceNullAwareSpreadFix',
    50,
    'Replace ...? with ...',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final target = node is SpreadElement
        ? node
        : node.thisOrAncestorOfType<SpreadElement>();
    if (target == null || !target.isNullAware) return;

    // SpreadElement source is like "...? list" or "...?list"
    final source = target.toSource();
    if (!source.startsWith('...?')) return;

    final replacement = '...' + source.substring(3);
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(target.offset, target.length),
        replacement,
      );
    });
  }
}
