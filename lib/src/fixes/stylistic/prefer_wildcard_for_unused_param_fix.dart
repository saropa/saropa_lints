// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Rename an unused positional parameter to `_` (Dart 3.7+
/// wildcard). Matches [PreferWildcardForUnusedParamRule].
///
/// Multiple `_` parameters in the same function are permitted under Dart 3.7+
/// wildcard semantics, so the fix is safe even when the function already has
/// other wildcards.
class PreferWildcardForUnusedParamFix extends SaropaFixProducer {
  PreferWildcardForUnusedParamFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.preferWildcardForUnusedParam',
    50,
    'Replace unused parameter name with _',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final AstNode? node = coveringNode;
    if (node == null) return;

    // Diagnostic is at param.name token; coveringNode may be the identifier or
    // the parameter itself. Walk up to find the FormalParameter.
    final FormalParameter? param = node is FormalParameter
        ? node
        : node.thisOrAncestorOfType<FormalParameter>();
    if (param == null) return;

    final Token? nameToken = param.name;
    if (nameToken == null) return;
    if (nameToken.lexeme == '_') return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(nameToken.offset, nameToken.length),
        '_',
      );
    });
  }
}
