// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Rename unused parameter with trailing underscore.
class PreferTrailingUnderscoreForUnusedFix extends SaropaFixProducer {
  PreferTrailingUnderscoreForUnusedFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferTrailingUnderscoreForUnusedFix',
    50,
    'Add trailing underscore to unused parameter',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Diagnostic is at param.name token; coveringNode may be identifier or param.
    final param = node is FormalParameter
        ? node
        : node.thisOrAncestorOfType<FormalParameter>();
    if (param == null) return;

    final Token? nameToken = param.name;
    if (nameToken == null) return;

    final String name = nameToken.lexeme;
    if (name.endsWith('_')) return;

    final String replacement = '${name}_';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(nameToken.offset, nameToken.length),
        replacement,
      );
    });
  }
}
