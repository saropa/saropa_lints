// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Set of widget names that extend `Flex` — `Expanded` is only valid
/// inside these containers.
const Set<String> _flexAncestors = {'Row', 'Column', 'Flex'};

/// Wraps a bare `Text(...)` widget in `Expanded(child: ...)`.
///
/// Only offered when the `Text` is inside a `Row`, `Column`, or `Flex`
/// ancestor — `Expanded` requires a `Flex` parent at runtime, so wrapping
/// outside one would produce a "Incorrect use of ParentDataWidget" crash.
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
    final InstanceCreationExpression? textWidget = node
        .thisOrAncestorOfType<InstanceCreationExpression>();
    if (textWidget == null) return;

    // Only wrap if the Text widget's constructor is actually "Text".
    final String constructorName = textWidget.constructorName.type.name.lexeme;
    if (constructorName != 'Text') return;

    // Guard: only offer Expanded when inside a Flex ancestor (Row/Column/Flex).
    // Expanded outside a Flex crashes at runtime with ParentDataWidget error.
    if (!_hasFlexAncestor(textWidget)) return;

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

  /// Walks the AST upward to check for a Row/Column/Flex ancestor.
  static bool _hasFlexAncestor(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is InstanceCreationExpression) {
        final String name = current.constructorName.type.name.lexeme;
        if (_flexAncestors.contains(name)) return true;
      }
      current = current.parent;
    }
    return false;
  }
}

/// Adds `maxLines: 2` to a `Text(...)` widget as a safe overflow fallback.
///
/// Offered when the `Text` is NOT inside a Flex ancestor, so `Expanded`
/// wrapping would be invalid. A `maxLines` cap prevents unbounded vertical
/// growth while keeping text readable (unlike ellipsis on line 1).
class AddMaxLinesToTextFix extends SaropaFixProducer {
  AddMaxLinesToTextFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addMaxLinesToText',
    40,
    'Add maxLines to limit text overflow',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Walk up to the enclosing InstanceCreationExpression.
    final InstanceCreationExpression? textWidget = node
        .thisOrAncestorOfType<InstanceCreationExpression>();
    if (textWidget == null) return;

    final String constructorName = textWidget.constructorName.type.name.lexeme;
    if (constructorName != 'Text') return;

    // Only offer maxLines when NOT inside a Flex — Expanded is better there.
    if (WrapTextInExpandedFix._hasFlexAncestor(textWidget)) return;

    // Insert ", maxLines: 2" before the closing paren of the argument list.
    final int insertOffset = textWidget.argumentList.rightParenthesis.offset;

    // Check if there are existing arguments to determine comma placement.
    final bool hasArgs = textWidget.argumentList.arguments.isNotEmpty;
    final String insertion = hasArgs ? ', maxLines: 2' : 'maxLines: 2';

    await builder.addDartFileEdit(file, (editBuilder) {
      editBuilder.addSimpleInsertion(insertOffset, insertion);
    });
  }
}
