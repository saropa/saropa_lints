// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Replaces `SliverChildListDelegate([...])` with a [SliverChildBuilderDelegate]
/// that indexes into the same widget expressions.
class ReplaceSliverChildListDelegateWithBuilderDelegateFix
    extends SaropaFixProducer {
  ReplaceSliverChildListDelegateWithBuilderDelegateFix({
    required super.context,
  });

  static const _fixKind = FixKind(
    'saropa.fix.replaceSliverChildListDelegateWithBuilderDelegateFix',
    50,
    'Use SliverChildBuilderDelegate',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    final ConstructorName? ctorName = node is ConstructorName
        ? node
        : node?.thisOrAncestorOfType<ConstructorName>();
    if (ctorName == null) return;

    final parent = ctorName.parent;
    if (parent is! InstanceCreationExpression) return;
    final ice = parent;
    if (ice.constructorName.type.name.lexeme != 'SliverChildListDelegate') {
      return;
    }

    final args = ice.argumentList.arguments;
    if (args.isEmpty) return;
    final first = args.first;
    if (first is! ListLiteral) return;
    final elements = <Expression>[];
    for (final el in first.elements) {
      if (el is! Expression) return;
      elements.add(el);
    }
    if (elements.isEmpty) return;

    final buf = StringBuffer('SliverChildBuilderDelegate((context, index) => ');
    buf.write('[');
    for (var i = 0; i < elements.length; i++) {
      if (i > 0) buf.write(', ');
      buf.write(elements[i].toSource());
    }
    buf.write('][index], childCount: ${elements.length})');

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(ice.offset, ice.length),
        buf.toString(),
      );
    });
  }
}
