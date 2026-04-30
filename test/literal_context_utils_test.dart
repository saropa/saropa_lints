import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/literal_context_utils.dart';
import 'package:test/test.dart';

void main() {
  group('expressionContainsRawStringLiteral', () {
    test('is true for raw SimpleStringLiteral', () {
      final init = _initializerOf("void f() { var _ = r'\\s' + a; }");
      final bin = init as BinaryExpression;
      expect(expressionContainsRawStringLiteral(bin.leftOperand), isTrue);
      expect(expressionContainsRawStringLiteral(bin.rightOperand), isFalse);
    });

    test('is true for raw string on the right', () {
      final init = _initializerOf("void f() { var _ = a + r'\\s*'; }");
      final bin = init as BinaryExpression;
      expect(expressionContainsRawStringLiteral(bin.leftOperand), isFalse);
      expect(expressionContainsRawStringLiteral(bin.rightOperand), isTrue);
    });

    test('is false for non-raw string literal with variable', () {
      final init = _initializerOf("void f() { var _ = 'Hi ' + a; }");
      final bin = init as BinaryExpression;
      expect(expressionContainsRawStringLiteral(bin.leftOperand), isFalse);
    });

    test('is true when AdjacentStrings include a raw part', () {
      final init = _initializerOf("void f() { var _ = r'a' r'b' + c; }");
      final bin = init as BinaryExpression;
      expect(expressionContainsRawStringLiteral(bin.leftOperand), isTrue);
    });
  });
}

/// First variable initializer in [snippet] (single-statement `void f()` body).
Expression _initializerOf(String snippet) {
  final unit = parseString(content: snippet).unit;
  final f = unit.declarations.first as FunctionDeclaration;
  final body = f.functionExpression.body;
  if (body is! BlockFunctionBody) {
    throw StateError('Expected block body');
  }
  final stmt = body.block.statements.first as VariableDeclarationStatement;
  final v = stmt.variables.variables.first;
  final init = v.initializer;
  if (init == null) {
    throw StateError('Expected initializer');
  }
  return init;
}
