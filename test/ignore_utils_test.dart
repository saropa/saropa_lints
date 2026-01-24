import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/ignore_utils.dart';
import 'package:test/test.dart';

/// Helper to parse Dart code and return the compilation unit.
CompilationUnit _parseCode(String code) {
  final result = parseString(content: code);
  return result.unit;
}

/// Finds the first node of type T in the compilation unit.
T? _findFirst<T extends AstNode>(CompilationUnit unit) {
  T? found;
  final visitor = _FindVisitor<T>((node) {
    found ??= node;
  });
  unit.accept(visitor);
  return found;
}

/// Finds all nodes of type T in the compilation unit.
List<T> _findAll<T extends AstNode>(CompilationUnit unit) {
  final found = <T>[];
  final visitor = _FindVisitor<T>((node) {
    found.add(node);
  });
  unit.accept(visitor);
  return found;
}

class _FindVisitor<T extends AstNode> extends GeneralizingAstVisitor<void> {
  _FindVisitor(this.onFound);

  final void Function(T) onFound;

  @override
  void visitNode(AstNode node) {
    if (node is T) {
      onFound(node);
    }
    super.visitNode(node);
  }
}

void main() {
  group('IgnoreUtils', () {
    group('toHyphenated', () {
      test('converts underscores to hyphens', () {
        expect(IgnoreUtils.toHyphenated('avoid_print'), 'avoid-print');
      });

      test('handles multiple underscores', () {
        expect(
          IgnoreUtils.toHyphenated('no_empty_block_body'),
          'no-empty-block-body',
        );
      });

      test('returns same string when no underscores', () {
        expect(IgnoreUtils.toHyphenated('simple'), 'simple');
      });
    });

    group('hasIgnoreCommentOnToken', () {
      test('detects ignore comment with underscore format', () {
        final unit = _parseCode('''
void test() {
  // ignore: my_rule
  print('hello');
}
''');
        final printInvocation = _findFirst<MethodInvocation>(unit)!;
        expect(
          IgnoreUtils.hasIgnoreCommentOnToken(
            printInvocation.beginToken,
            'my_rule',
          ),
          isTrue,
        );
      });

      test('detects ignore comment with hyphen format', () {
        final unit = _parseCode('''
void test() {
  // ignore: my-rule
  print('hello');
}
''');
        final printInvocation = _findFirst<MethodInvocation>(unit)!;
        expect(
          IgnoreUtils.hasIgnoreCommentOnToken(
            printInvocation.beginToken,
            'my_rule',
          ),
          isTrue,
        );
      });

      test('returns false when no ignore comment', () {
        final unit = _parseCode('''
void test() {
  print('hello');
}
''');
        final printInvocation = _findFirst<MethodInvocation>(unit)!;
        expect(
          IgnoreUtils.hasIgnoreCommentOnToken(
            printInvocation.beginToken,
            'my_rule',
          ),
          isFalse,
        );
      });

      test('returns false for different rule name', () {
        final unit = _parseCode('''
void test() {
  // ignore: other_rule
  print('hello');
}
''');
        final printInvocation = _findFirst<MethodInvocation>(unit)!;
        expect(
          IgnoreUtils.hasIgnoreCommentOnToken(
            printInvocation.beginToken,
            'my_rule',
          ),
          isFalse,
        );
      });

      test('handles null token', () {
        expect(
          IgnoreUtils.hasIgnoreCommentOnToken(null, 'my_rule'),
          isFalse,
        );
      });
    });

    group('hasIgnoreComment', () {
      group('leading comments', () {
        test('detects comment directly before node', () {
          final unit = _parseCode('''
void test() {
  // ignore: my_rule
  print('hello');
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isTrue,
          );
        });

        test('detects comment on parent expression', () {
          final unit = _parseCode('''
void test() {
  // ignore: no_empty_block
  stream.listen((_) {});
}
''');
          // Find the empty block (second block, which is the callback body)
          final blocks = _findAll<Block>(unit);
          final emptyBlock = blocks.firstWhere(
            (b) => b.statements.isEmpty && b.parent is BlockFunctionBody,
            orElse: () => blocks.last,
          );
          expect(
            IgnoreUtils.hasIgnoreComment(emptyBlock, 'no_empty_block'),
            isTrue,
          );
        });
      });

      group('trailing comments on statements', () {
        test('detects trailing comment on same line as statement', () {
          final unit = _parseCode('''
void test() {
  print('hello'); // ignore: my_rule
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isTrue,
          );
        });

        test('detects trailing comment with hyphen format', () {
          final unit = _parseCode('''
void test() {
  print('hello'); // ignore: my-rule
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isTrue,
          );
        });
      });

      group('trailing comments on constructor arguments', () {
        test('detects trailing comment on named parameter value', () {
          final unit = _parseCode('''
void test() {
  final item = WebsiteItem(
    url: 'http://example.com', // ignore: require_https
    label: 'Test',
  );
}

class WebsiteItem {
  WebsiteItem({required this.url, required this.label});
  final String url;
  final String label;
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final urlString = strings.firstWhere(
            (s) => s.value == 'http://example.com',
          );
          expect(
            IgnoreUtils.hasIgnoreComment(urlString, 'require_https'),
            isTrue,
          );
        });

        test('does not affect other arguments in same constructor', () {
          final unit = _parseCode('''
void test() {
  final item = WebsiteItem(
    url: 'http://example.com', // ignore: require_https
    label: 'Test',
  );
}

class WebsiteItem {
  WebsiteItem({required this.url, required this.label});
  final String url;
  final String label;
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final labelString = strings.firstWhere((s) => s.value == 'Test');
          expect(
            IgnoreUtils.hasIgnoreComment(labelString, 'require_https'),
            isFalse,
          );
        });
      });

      group('trailing comments on list items', () {
        test('detects trailing comment on list element', () {
          final unit = _parseCode('''
void test() {
  final items = [
    'http://example.com', // ignore: require_https
    'https://safe.com',
  ];
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final httpString = strings.firstWhere(
            (s) => s.value == 'http://example.com',
          );
          expect(
            IgnoreUtils.hasIgnoreComment(httpString, 'require_https'),
            isTrue,
          );
        });

        test('does not affect other list items', () {
          final unit = _parseCode('''
void test() {
  final items = [
    'http://example.com', // ignore: require_https
    'https://safe.com',
  ];
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final safeString = strings.firstWhere(
            (s) => s.value == 'https://safe.com',
          );
          expect(
            IgnoreUtils.hasIgnoreComment(safeString, 'require_https'),
            isFalse,
          );
        });
      });

      group('CatchClause special handling', () {
        test('detects comment before catch clause', () {
          final unit = _parseCode('''
void test() {
  try {
    doSomething();
  // ignore: avoid_empty_catch
  } on Exception catch (e) {
    // empty
  }
}

void doSomething() {}
''');
          final catchClause = _findFirst<CatchClause>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(catchClause, 'avoid_empty_catch'),
            isTrue,
          );
        });
      });

      group('edge cases', () {
        test('returns false when no comments present', () {
          final unit = _parseCode('''
void test() {
  print('hello');
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isFalse,
          );
        });

        test('returns false for unrelated rule name', () {
          final unit = _parseCode('''
void test() {
  // ignore: other_rule
  print('hello'); // ignore: another_rule
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isFalse,
          );
        });

        test('handles multiple ignore comments', () {
          final unit = _parseCode('''
void test() {
  // ignore: rule_one, rule_two
  print('hello');
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'rule_one'),
            isTrue,
          );
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'rule_two'),
            isTrue,
          );
        });

        test('stops at statement boundary for parent walk', () {
          final unit = _parseCode('''
void test() {
  if (true) {
    // This comment is inside a nested block
    print('hello');
  }
}
''');
          final printInvocation = _findFirst<MethodInvocation>(unit)!;
          // The ignore comment is not on the print statement
          expect(
            IgnoreUtils.hasIgnoreComment(printInvocation, 'my_rule'),
            isFalse,
          );
        });
      });

      group('variable declarations', () {
        test('detects trailing comment on variable declaration', () {
          final unit = _parseCode('''
void test() {
  final url = 'http://example.com'; // ignore: require_https
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final urlString = strings.first;
          expect(
            IgnoreUtils.hasIgnoreComment(urlString, 'require_https'),
            isTrue,
          );
        });
      });

      group('field declarations', () {
        test('detects trailing comment on field declaration', () {
          final unit = _parseCode('''
class Config {
  final url = 'http://example.com'; // ignore: require_https
}
''');
          final strings = _findAll<SimpleStringLiteral>(unit);
          final urlString = strings.first;
          expect(
            IgnoreUtils.hasIgnoreComment(urlString, 'require_https'),
            isTrue,
          );
        });
      });
    });
  });
}
