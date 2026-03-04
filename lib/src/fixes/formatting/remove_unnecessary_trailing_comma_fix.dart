// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Remove unnecessary trailing comma (e.g. in single-element list).
///
/// Matches [UnnecessaryTrailingCommaRule].
class RemoveUnnecessaryTrailingCommaFix extends SaropaFixProducer {
  RemoveUnnecessaryTrailingCommaFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.removeUnnecessaryTrailingComma',
    50,
    'Remove unnecessary trailing comma',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) {
    final node = coveringNode;
    if (node == null) return Future.value();

    final listLit = node.thisOrAncestorOfType<ListLiteral>();
    final setMap = node.thisOrAncestorOfType<SetOrMapLiteral>();
    if (listLit != null) {
      return _removeFromLiteral(
        listLit,
        listLit.elements,
        listLit.rightBracket,
        builder,
      );
    }
    if (setMap != null) {
      return _removeFromLiteral(
        setMap,
        setMap.elements,
        setMap.rightBracket,
        builder,
      );
    }
    return Future.value();
  }

  Future<void> _removeFromLiteral(
    AstNode literal,
    List<CollectionElement> elements,
    Token rightBracket,
    ChangeBuilder builder,
  ) async {
    if (elements.length != 1) return;

    final element = elements[0];
    if (element is! Expression) return;

    Token? token = element.endToken.next;
    while (token != null && token.type != TokenType.COMMA) {
      if (token == rightBracket) return;
      token = token.next;
    }
    if (token == null || token.type != TokenType.COMMA) return;

    final commaToken = token;
    await builder.addDartFileEdit(file, (b) {
      b.addDeletion(SourceRange(commaToken.offset, commaToken.length));
    });
  }
}
