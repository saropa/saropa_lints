// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';

/// Quick fix: Rename constant to SCREAMING_SNAKE_CASE.
class ConvertToScreamingCaseFix extends SaropaFixProducer {
  ConvertToScreamingCaseFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.convertToScreamingCase',
    50,
    'Convert to SCREAMING_SNAKE_CASE',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // The diagnostic is reported at the variable name token
    final varDecl = node is VariableDeclaration
        ? node
        : node.thisOrAncestorOfType<VariableDeclaration>();
    if (varDecl == null) return;

    final name = varDecl.name.lexeme;
    final screaming = _toScreamingSnakeCase(name);
    if (screaming == name) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(
        SourceRange(varDecl.name.offset, varDecl.name.length),
        screaming,
      );
    });
  }

  static String _toScreamingSnakeCase(String name) {
    final buffer = StringBuffer();
    for (var i = 0; i < name.length; i++) {
      final char = name[i];
      if (i > 0 && char == char.toUpperCase() && char != '_') {
        final prevChar = name[i - 1];
        if (prevChar == prevChar.toLowerCase() && prevChar != '_') {
          buffer.write('_');
        }
      }
      buffer.write(char.toUpperCase());
    }
    return buffer.toString();
  }
}
