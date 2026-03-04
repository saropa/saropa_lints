// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Add explicit type to empty set/map literal.
///
/// Matches [AvoidMisusedSetLiteralsRule]. Replaces `{}` with
/// `<Type>{}` for Set or `<K, V>{}` for Map using the inferred type.
class AddSetOrMapTypeArgumentFix extends SaropaFixProducer {
  AddSetOrMapTypeArgumentFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.addSetOrMapTypeArgument',
    50,
    'Add explicit type to {}',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final SetOrMapLiteral? literal = node is SetOrMapLiteral
        ? node
        : node.thisOrAncestorOfType<SetOrMapLiteral>();
    if (literal == null || literal.elements.isNotEmpty) return;

    final type = literal.staticType;
    if (type == null) return;

    final String typeStr = type.getDisplayString();
    if (!typeStr.startsWith('Map<') && !typeStr.startsWith('Set<')) return;

    final String replacement = '$typeStr{}';

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(literal.offset, literal.length),
        replacement,
      );
    });
  }
}
