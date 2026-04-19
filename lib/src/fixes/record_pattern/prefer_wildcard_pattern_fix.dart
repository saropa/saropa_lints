// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Replace an obviously-unused pattern variable (names like
/// `unused`, `ignore`, `ignored`, `unusedX`, `ignoreY`) with the `_`
/// wildcard pattern.
///
/// Matches [PreferWildcardPatternRule].
class PreferWildcardPatternFix extends SaropaFixProducer {
  PreferWildcardPatternFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferWildcardPattern',
    50,
    'Replace unused pattern variable with _',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    final DeclaredVariablePattern? pattern = node is DeclaredVariablePattern
        ? node
        : node.thisOrAncestorOfType<DeclaredVariablePattern>();
    if (pattern == null) return;

    final Token nameToken = pattern.name;
    if (nameToken.lexeme == '_') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(nameToken.offset, nameToken.length),
        '_',
      );
    });
  }
}
