// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace List.from/Set.from/etc. with .of().
///
/// Matches [PreferIterableOfRule].
class ReplaceFromWithOfFix extends SaropaFixProducer {
  ReplaceFromWithOfFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceFromWithOf',
    50,
    'Use .of() instead of .from()',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final InstanceCreationExpression? creation =
        node is InstanceCreationExpression
        ? node
        : node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    final SimpleIdentifier? id = creation.constructorName.name;
    if (id == null || id.name != 'from') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(id.offset, id.length), 'of');
    });
  }
}
