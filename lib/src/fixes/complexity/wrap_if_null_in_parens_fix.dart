// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Wrap ?? expression in parentheses when followed by cascade.
///
/// Matches [AvoidCascadeAfterIfNullRule]. Transforms "a ?? b..c()" to "(a ?? b)..c()".
class WrapIfNullInParensFix extends SaropaFixProducer {
  WrapIfNullInParensFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapIfNullInParens',
    50,
    'Wrap ?? expression in parentheses',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final cascade = node is CascadeExpression
        ? node
        : node.thisOrAncestorOfType<CascadeExpression>();
    if (cascade == null) return;

    final target = cascade.target;
    final fullSource = cascade.toSource();
    final targetSource = target.toSource();
    if (!fullSource.startsWith(targetSource)) return;

    final rest = fullSource.substring(targetSource.length);
    final replacement = '($targetSource)$rest';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(cascade.offset, cascade.length),
        replacement,
      );
    });
  }
}
