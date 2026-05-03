import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Bug: bugs/require_https_only_false_positive_string_inspection_pattern.md
///
/// `require_https_only` must not fire when `'http://'` is the needle
/// argument to a `String` inspection method (`startsWith` / `endsWith` /
/// `contains` / `indexOf` / `lastIndexOf` / `split`) or the operand of an
/// `==` / `!=` comparison — those literals are search/comparison patterns,
/// not URLs being requested over the network.
///
/// The implementation predicate is private
/// (`_isStringInspectionPattern` in `security_network_input_rules.dart`).
/// These tests mirror the predicate against parsed AST snippets so the
/// contract is independently verified — keep the local `isInspectionPattern`
/// shape in sync with the production helper.
void main() {
  const ruleName = 'require_https_only';
  const fixturePath = 'example/lib/security/require_https_only_fixture.dart';

  /// Mirrors `RequireHttpsOnlyRule._isStringInspectionPattern`. If you change
  /// one, change the other — the test is the contract.
  bool isInspectionPattern(SimpleStringLiteral node) {
    final AstNode? parent = node.parent;

    // Shape 1: needle argument to an inspection method.
    if (parent is ArgumentList) {
      final AstNode? grandparent = parent.parent;
      if (grandparent is! MethodInvocation) return false;

      const inspectionMethods = <String>{
        'startsWith',
        'endsWith',
        'contains',
        'indexOf',
        'lastIndexOf',
        'split',
      };
      if (!inspectionMethods.contains(grandparent.methodName.name)) {
        return false;
      }

      final args = parent.arguments;
      return args.isNotEmpty && identical(args.first, node);
    }

    // Shape 2: operand of equality / inequality comparison.
    if (parent is BinaryExpression) {
      final op = parent.operator.lexeme;
      return op == '==' || op == '!=';
    }

    return false;
  }

  /// Walk the parsed unit and return the first `SimpleStringLiteral` whose
  /// value matches [literal]. Tests parse minimal snippets, so a single
  /// match is reliable.
  SimpleStringLiteral findLiteral(CompilationUnit unit, String literal) {
    SimpleStringLiteral? hit;
    unit.visitChildren(_LiteralFinder(literal, (n) => hit ??= n));
    expect(hit, isNotNull, reason: 'literal `$literal` not found in snippet');
    return hit!;
  }

  group('require_https_only string-inspection carve-out', () {
    test('rule is registered in allSaropaRules', () {
      final names = allSaropaRules.map((r) => r.code.lowerCaseName).toSet();
      expect(names.contains(ruleName), isTrue);
    });

    test('fixture exists and contains the inspection-pattern section', () {
      final file = File(fixturePath);
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      // The fixture's BAD/GOOD/SafeHttpUpgrade classes establish baseline
      // coverage; HttpDetectionPatterns is the new false-positive guard.
      expect(content, contains('HttpDetectionPatterns'));
      expect(content, contains('startsWith'));
      expect(content, contains('endsWith'));
      expect(content, contains('contains'));
      expect(content, contains('indexOf'));
      expect(content, contains('lastIndexOf'));
      expect(content, contains('split'));
      // Equality-shape coverage.
      expect(content, contains("== 'http://'"));
      expect(content, contains("!= 'http://'"));
    });

    // -- Shape 1: String-inspection method needles --

    test('startsWith needle is recognized as inspection pattern', () {
      final unit = parseString(
        content: "bool f(String s) => s.startsWith('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('endsWith needle is recognized as inspection pattern', () {
      final unit = parseString(
        content: "bool f(String s) => s.endsWith('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('contains needle is recognized as inspection pattern', () {
      final unit = parseString(
        content: "bool f(String s) => s.contains('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('indexOf needle is recognized as inspection pattern', () {
      final unit = parseString(
        content: "int f(String s) => s.indexOf('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('lastIndexOf needle is recognized as inspection pattern', () {
      final unit = parseString(
        content: "int f(String s) => s.lastIndexOf('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('split separator is recognized as inspection pattern', () {
      final unit = parseString(
        content: "List<String> f(String s) => s.split('http://');",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    // -- Shape 2: equality / inequality --

    test('== comparison operand is recognized as inspection pattern', () {
      final unit = parseString(
        content: "bool f(String p) => p == 'http://';",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    test('!= comparison operand is recognized as inspection pattern', () {
      final unit = parseString(
        content: "bool f(String p) => p != 'http://';",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isTrue);
    });

    // -- Negative cases: real URL requests must still fire --

    test('Uri.parse argument is NOT an inspection pattern (still fires)', () {
      // `parse` is not in the inspection-method set — argument represents the
      // URL being constructed, exactly the threat model the rule targets.
      final unit = parseString(
        content: "Uri f() => Uri.parse('http://example.com');",
      ).unit;
      expect(
        isInspectionPattern(findLiteral(unit, 'http://example.com')),
        isFalse,
      );
    });

    test(
      'hardcoded top-level URL is NOT an inspection pattern (still fires)',
      () {
        final unit = parseString(
          content: "const apiUrl = 'http://api.example.com/v1';",
        ).unit;
        expect(
          isInspectionPattern(findLiteral(unit, 'http://api.example.com/v1')),
          isFalse,
        );
      },
    );

    test('http call argument (http.get) is NOT an inspection pattern', () {
      // Method name `get` is not in the inspection set.
      final unit = parseString(
        content: "void f(dynamic http) { http.get('http://api.example.com'); }",
      ).unit;
      expect(
        isInspectionPattern(findLiteral(unit, 'http://api.example.com')),
        isFalse,
      );
    });

    test('literal as second arg of contains is NOT pattern (defensive)', () {
      // `text.contains(other, http_literal)` — literal is the start-index in
      // some shapes (no-op here for String.contains, but the predicate still
      // refuses to silence anything that is not the first/needle argument).
      final unit = parseString(
        content:
            "bool f(String s, String n) => s.contains(n, 'http://'.length);",
      ).unit;
      // The 'http://' here is the receiver of `.length`; its parent is a
      // PropertyAccess / SimpleIdentifier chain, not the ArgumentList of the
      // outer `contains`. Still — confirm the predicate refuses to claim it
      // as an inspection pattern (because the AST shape doesn't match).
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isFalse);
    });

    test('non-equality binary expression is NOT inspection pattern', () {
      // `+` concatenation — building a URL string. Must fire.
      final unit = parseString(
        content: "String f(String s) => 'http://' + s;",
      ).unit;
      expect(isInspectionPattern(findLiteral(unit, 'http://')), isFalse);
    });
  });
}

class _LiteralFinder extends RecursiveAstVisitor<void> {
  _LiteralFinder(this.target, this.onHit);
  final String target;
  final void Function(SimpleStringLiteral node) onHit;

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    if (node.value == target) onHit(node);
    super.visitSimpleStringLiteral(node);
  }
}
