import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/ignore_utils.dart';
import 'package:saropa_lints/src/rules/code_quality_rules.dart';
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

    group('isIgnoredForFile', () {
      test('detects ignore_for_file with underscore format', () {
        const content = '''
// ignore_for_file: require_https_over_http
import 'dart:core';
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('detects ignore_for_file with hyphen format', () {
        const content = '''
// ignore_for_file: require-https-over-http
import 'dart:core';
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('detects rule when trailing comment follows directive', () {
        const content = '''
// ignore_for_file: require_https_over_http // we report http insecure links here
import 'dart:core';
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('detects rule among comma-separated list', () {
        const content = '''
// ignore_for_file: rule_a, require_https_over_http, rule_b
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('returns false when no ignore_for_file present', () {
        const content = '''
import 'dart:core';
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isFalse,
        );
      });

      test('returns false for different rule name', () {
        const content = '''
// ignore_for_file: other_rule
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isFalse,
        );
      });

      test('does not match partial rule name as substring', () {
        const content = '''
// ignore_for_file: require_https_over_http_v2
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isFalse,
        );
      });

      test('does not match rule name that is a prefix', () {
        const content = '''
// ignore_for_file: require_https
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isFalse,
        );
      });

      test('handles multiple ignore_for_file directives', () {
        const content = '''
// ignore_for_file: rule_a
// ignore_for_file: require_https_over_http
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
        expect(IgnoreUtils.isIgnoredForFile(content, 'rule_a'), isTrue);
      });

      test('handles extra whitespace in directive', () {
        const content = '''
//   ignore_for_file:   require_https_over_http
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('detects directive in middle of file', () {
        const content = '''
import 'dart:core';
// ignore_for_file: require_https_over_http
void main() {}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isTrue,
        );
      });

      test('ignores line-level ignore directive', () {
        const content = '''
void main() {
  // ignore: require_https_over_http
  final x = 'http://example.com';
}
''';
        expect(
          IgnoreUtils.isIgnoredForFile(content, 'require_https_over_http'),
          isFalse,
        );
      });
    });

    group('trailingCommentOnIgnore', () {
      test('matches ignore_for_file with trailing comment', () {
        const line =
            '// ignore_for_file: require_https_over_http // reason here';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });

      test('matches ignore with trailing comment', () {
        const line =
            '// ignore: avoid_platform_channel_on_web // no web support';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });

      test('does not match ignore_for_file without trailing comment', () {
        const line = '// ignore_for_file: require_https_over_http';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isFalse);
      });

      test('does not match ignore without trailing comment', () {
        const line = '// ignore: my_rule';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isFalse);
      });

      test('does not match comma-separated rules without comment', () {
        const line = '// ignore_for_file: rule_a, rule_b';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isFalse);
      });

      test('matches when trailing comment follows comma-separated rules', () {
        const line = '// ignore_for_file: rule_a, rule_b // some reason';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });

      test('does not match plain comment', () {
        const line = '// this is just a normal comment';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isFalse);
      });

      test('matches ignore with dash separator', () {
        const line = '// ignore: my_rule - no web support needed';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });

      test('matches ignore_for_file with dash separator', () {
        const line =
            '// ignore_for_file: require_https_over_http - reports http links';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });

      test('does not match hyphenated rule name without separator', () {
        const line = '// ignore: avoid-print';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isFalse);
      });

      test('matches dash separator with hyphenated rule name', () {
        const line = '// ignore: avoid-print - not needed in production';
        expect(IgnoreUtils.trailingCommentOnIgnore.hasMatch(line), isTrue);
      });
    });

    group('splitParts', () {
      test('splits ignore_for_file directive and trailing comment', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore_for_file: my_rule // reason here',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore_for_file: my_rule');
        expect(result.trailing, '// reason here');
      });

      test('splits ignore directive and trailing comment', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore: my_rule // no web support',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore: my_rule');
        expect(result.trailing, '// no web support');
      });

      test('splits with comma-separated rules', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore_for_file: rule_a, rule_b // some reason',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore_for_file: rule_a, rule_b');
        expect(result.trailing, '// some reason');
      });

      test('returns null when no trailing comment', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore_for_file: my_rule',
        );
        expect(result, isNull);
      });

      test('returns null when no colon', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// just a comment',
        );
        expect(result, isNull);
      });

      test('splits ignore directive with dash separator', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore: my_rule - no web support needed',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore: my_rule');
        expect(result.trailing, '// no web support needed');
      });

      test('splits ignore_for_file with dash separator', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore_for_file: rule_a - reports http links',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore_for_file: rule_a');
        expect(result.trailing, '// reports http links');
      });

      test('splits hyphenated rule name with dash separator', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore: avoid-print - not needed here',
        );
        expect(result, isNotNull);
        expect(result!.directive, '// ignore: avoid-print');
        expect(result.trailing, '// not needed here');
      });

      test('returns null for hyphenated rule name without separator', () {
        final result = AvoidIgnoreTrailingCommentRule.splitParts(
          '// ignore: avoid-print',
        );
        expect(result, isNull);
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
        expect(IgnoreUtils.hasIgnoreCommentOnToken(null, 'my_rule'), isFalse);
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

      group('chained method calls (mid-chain comments)', () {
        test('detects comment before method in chain', () {
          final unit = _parseCode('''
void test() {
  final result = obj
      // ignore: my_rule
      .doIt();
}
class C { C doIt() => this; }
final obj = C();
''');
          final invocations = _findAll<MethodInvocation>(unit);
          final doIt = invocations.firstWhere(
            (m) => m.methodName.name == 'doIt',
          );
          expect(IgnoreUtils.hasIgnoreComment(doIt, 'my_rule'), isTrue);
        });

        test('detects hyphen format in chain', () {
          final unit = _parseCode('''
void test() {
  final result = obj
      // ignore: my-rule
      .doIt();
}
class C { C doIt() => this; }
final obj = C();
''');
          final invocations = _findAll<MethodInvocation>(unit);
          final doIt = invocations.firstWhere(
            (m) => m.methodName.name == 'doIt',
          );
          expect(IgnoreUtils.hasIgnoreComment(doIt, 'my_rule'), isTrue);
        });

        test('does not affect other methods in chain', () {
          final unit = _parseCode('''
void test() {
  final result = obj
      // ignore: my_rule
      .methodA()
      .methodB();
}
class C { C methodA() => this; C methodB() => this; }
final obj = C();
''');
          final invocations = _findAll<MethodInvocation>(unit);
          final methodB = invocations.firstWhere(
            (m) => m.methodName.name == 'methodB',
          );
          expect(IgnoreUtils.hasIgnoreComment(methodB, 'my_rule'), isFalse);
        });
      });

      group('chained property access (mid-chain comments)', () {
        test('detects comment before property in chain', () {
          // Use method call result as target to ensure PropertyAccess node
          final unit = _parseCode('''
void test() {
  final result = getObj()
      // ignore: my_rule
      .prop;
}
class C { final String prop = 'v'; }
C getObj() => C();
''');
          final accesses = _findAll<PropertyAccess>(unit);
          final prop = accesses.firstWhere(
            (p) => p.propertyName.name == 'prop',
          );
          expect(IgnoreUtils.hasIgnoreComment(prop, 'my_rule'), isTrue);
        });
      });
    });
  });
}
