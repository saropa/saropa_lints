// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces a `Row` constructor name with `Wrap` (same arguments).
class ReplaceRowConstructorWithWrapFix extends SaropaFixProducer {
  ReplaceRowConstructorWithWrapFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.replaceRowConstructorWithWrapFix',
    50,
    'Replace Row with Wrap',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final typeName = ctorName.type.name;
    if (typeName.lexeme != 'Row') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(typeName.offset, typeName.length),
        'Wrap',
      );
    });
  }
}
