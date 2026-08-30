// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Wraps a bare `Text(...)` widget in `Expanded(child: ...)`.
///
/// Preferred over adding `TextOverflow.ellipsis` because wrapping preserves
/// text visibility — the text reflows instead of being truncated. Addresses
/// the AI-agent anti-pattern of blindly hiding text behind ellipsis (#320).
class WrapTextInExpandedFix extends SaropaFixProducer {
  WrapTextInExpandedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.wrapTextInExpanded',
    50,
    'Wrap in Expanded to keep text visible',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The diagnostic is reported atNode(constructorName), so walk up
    // to the enclosing InstanceCreationExpression (the full Text(...)).
    final InstanceCreationExpression? textWidget =
        node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (textWidget == null) return;

    // Only wrap if the Text widget's constructor is actually "Text".
    final String constructorName =
        textWidget.constructorName.type.name.lexeme;
    if (constructorName != 'Text') return;

    // Build the replacement: Expanded(child: <original Text(...)>)
    final String original = textWidget.toSource();
    final String wrapped = 'Expanded(child: $original)';

    await builder.addDartFileEdit(file, (editBuilder) {
      editBuilder.addSimpleReplacement(
        SourceRange(textWidget.offset, textWidget.length),
        wrapped,
      );
    });
  }
}
