/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `element_identifier_utils_test` (element identifier utils).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/element_identifier_utils.dart';
import 'package:test/test.dart';

// element_identifier_utils: AST identifier to element without full resolution.

void main() {
  group('elementFromAstIdentifier', () {
    test('returns null for null id', () {
      expect(elementFromAstIdentifier(null), isNull);
    });

    test('returns null for parseString identifier without resolution', () {
      final unit = parseString(content: 'void f() { x; }').unit;
      final fun = unit.declarations.first as FunctionDeclaration;
      final body = fun.functionExpression.body as BlockFunctionBody;
      final stmt = body.block.statements.first as ExpressionStatement;
      final ref = stmt.expression as SimpleIdentifier;
      expect(elementFromAstIdentifier(ref), isNull);
    });

    test('accepts logFailures without throwing on unresolved node', () {
      final unit = parseString(content: 'void f() { x; }').unit;
      final fun = unit.declarations.first as FunctionDeclaration;
      final body = fun.functionExpression.body as BlockFunctionBody;
      final stmt = body.block.statements.first as ExpressionStatement;
      final ref = stmt.expression as SimpleIdentifier;
      expect(elementFromAstIdentifier(ref, logFailures: true), isNull);
    });
  });
}
