// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Prefix unused parameter with underscore.
class PrefixUnusedParameterFix extends SaropaFixProducer {
  PrefixUnusedParameterFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.prefixUnusedParameterFix',
    50,
    'Prefix parameter with underscore',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final param = node is FormalParameter
        ? node
        : node.thisOrAncestorOfType<FormalParameter>();
    if (param == null) return;

    final Token? nameToken = param.name;
    if (nameToken == null || nameToken.lexeme.startsWith('_')) return;

    final String replacement = '_${nameToken.lexeme}';
    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(nameToken.offset, nameToken.length),
        replacement,
      );
    });
  }
}
