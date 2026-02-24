import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:test/test.dart';

/// Mirrors the production [_countCodeLinesInTokenRange] from structure_rules.dart
/// so we can unit-test the counting logic in isolation.
int countCodeLinesInTokenRange(
  LineInfo lineInfo,
  Token beginToken, {
  Token? endToken,
}) {
  final Set<int> codeLines = <int>{};
  Token? token = beginToken;

  while (token != null && !token.isEof) {
    final int startLine = lineInfo.getLocation(token.offset).lineNumber;
    codeLines.add(startLine);

    if (token.length > 1) {
      final int endLine = lineInfo.getLocation(token.end - 1).lineNumber;
      for (int line = startLine + 1; line <= endLine; line++) {
        codeLines.add(line);
      }
    }

    if (endToken != null && token == endToken) break;
    token = token.next;
  }

  return codeLines.length;
}

CompilationUnit _parse(String code) => parseString(content: code).unit;

/// Finds the first [FunctionBody] in parsed code.
FunctionBody? _findFirstBody(CompilationUnit unit) {
  FunctionBody? result;
  unit.accept(_BodyFinder((body) => result ??= body));
  return result;
}

class _BodyFinder extends RecursiveAstVisitor<void> {
  _BodyFinder(this._onFound);
  final void Function(FunctionBody) _onFound;

  @override
  void visitBlockFunctionBody(BlockFunctionBody node) {
    _onFound(node);
    super.visitBlockFunctionBody(node);
  }

  @override
  void visitExpressionFunctionBody(ExpressionFunctionBody node) {
    _onFound(node);
    super.visitExpressionFunctionBody(node);
  }
}

void main() {
  group('Code line counting - file level', () {
    test('counts only code lines, not comments or blanks', () {
      final unit = _parse('''
/// A dartdoc comment
// A regular comment

void foo() {
  var x = 1;
}
''');
      final count = countCodeLinesInTokenRange(unit.lineInfo, unit.beginToken);
      // Only lines with code tokens: void foo() {, var x = 1;, }
      expect(count, equals(3));
    });

    test('multi-line string counts all its lines', () {
      final unit = _parse('''
var s = \'''
line one
line two
\''';
''');
      final count = countCodeLinesInTokenRange(unit.lineInfo, unit.beginToken);
      // var, s, =, multi-line string (4 lines), ;
      // Lines: var s = ''' (1), line one (2), line two (3), ''' (4), ; is on line 4
      expect(count, greaterThanOrEqualTo(4));
    });

    test('empty file returns zero', () {
      final unit = _parse('');
      final count = countCodeLinesInTokenRange(unit.lineInfo, unit.beginToken);
      expect(count, equals(0));
    });

    test('file with only comments returns zero', () {
      final unit = _parse('''
// comment one
// comment two
/// dartdoc
/* block comment */
''');
      final count = countCodeLinesInTokenRange(unit.lineInfo, unit.beginToken);
      expect(count, equals(0));
    });
  });

  group('Code line counting - function body', () {
    test('excludes comments inside function body', () {
      final unit = _parse('''
void foo() {
  // This is a comment
  /// This is dartdoc
  var x = 1;
  // Another comment
  var y = 2;
}
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // Code lines: { (1), var x = 1; (2), var y = 2; (3), } (4)
      expect(count, equals(4));
    });

    test('heavily commented function counts only code lines', () {
      final unit = _parse('''
void heavilyDocumented() {
  // ============================================
  // Section 1: Setup
  // ============================================
  // This section handles initialization of the
  // core data structures needed for processing.
  // It ensures all invariants are maintained.
  var a = 1;

  // ============================================
  // Section 2: Processing
  // ============================================
  // This section performs the main computation.
  // It iterates over the input data and applies
  // the transformation rules defined above.
  // Each step is carefully validated.
  var b = 2;

  // ============================================
  // Section 3: Cleanup
  // ============================================
  // Final cleanup and resource deallocation.
  // All temporary buffers are released here.
  var c = 3;
}
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // Code lines: { (1), var a = 1; (2), var b = 2; (3), var c = 3; (4), } (5)
      expect(count, equals(5));
    });

    test('function with zero comments counts all code lines', () {
      final unit = _parse('''
void noComments() {
  var a = 1;
  var b = 2;
  var c = 3;
  var d = 4;
}
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // { + 4 var lines + }
      expect(count, equals(6));
    });

    test('false positive: dartdoc-heavy function stays under threshold', () {
      // Simulate a function with 10 code lines but 50+ comment lines.
      // The old counting method would report 60+ lines; the new one should
      // report only 10 code lines.
      final commentBlock = List.generate(
        50,
        (i) => '  /// Documentation line $i explaining important details.',
      ).join('\n');

      final code =
          '''
void wellDocumented() {
$commentBlock
  var a = 1;
  var b = 2;
  var c = 3;
  var d = 4;
  var e = 5;
  var f = 6;
  var g = 7;
  var h = 8;
}
''';
      final unit = _parse(code);
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // Code lines: { + 8 var lines + } = 10
      // Total lines in body would be 60+ but code lines should be 10
      expect(count, equals(10));
    });

    test('expression body counts correctly', () {
      final unit = _parse('''
int add(int a, int b) => a + b;
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // => a + b; is one line
      expect(count, equals(1));
    });

    test('block comments inside function are excluded', () {
      final unit = _parse('''
void foo() {
  /*
   * A multi-line
   * block comment
   * spanning several lines
   */
  var x = 1;
}
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // Code lines: { (1), var x = 1; (2), } (3)
      expect(count, equals(3));
    });

    test('inline comment on code line still counts that line', () {
      final unit = _parse('''
void foo() {
  var x = 1; // inline comment
  var y = 2; // another comment
}
''');
      final body = _findFirstBody(unit)!;
      final count = countCodeLinesInTokenRange(
        unit.lineInfo,
        body.beginToken,
        endToken: body.endToken,
      );
      // { (1), var x = 1; (2), var y = 2; (3), } (4)
      // Inline comments don't add extra lines since code is on the same line
      expect(count, equals(4));
    });
  });
}
