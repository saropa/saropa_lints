// Unit tests for [IgnoreUtils]: analyzer-backed detection of `// ignore:` / `// ignore_for_file:`.
// Covers directive placement, trailing comma lists, duplicate codes, and interaction with AST nodes.
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/analyzer_compat.dart';
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

    // Token-attached // ignore: (leading same line or end-of-line before the node).
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

      test('does not match a longer rule name as a substring', () {
        // Regression: a bare `text.contains(ruleName)` let an ignore for the
        // more specific `my_rule_extended` wrongly suppress `my_rule`, because
        // `my_rule` is a substring of it. Whole-word matching must reject it,
        // matching isIgnoredForFile's `\b`-anchored behavior.
        final unit = _parseCode('''
void test() {
  // ignore: my_rule_extended
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
    });

    // Leading `// ignore:` honored for diagnostics reported on a declaration's
    // NAME token (`reporter.atToken(node.nameToken)`). The directive attaches to
    // the declaration's first token on its line (e.g. `class`), never the
    // mid-line name token, so `hasIgnoreCommentOnToken(nameToken)` never sees it.
    // See plans/history/2026.06/2026.06.04/infra_ignore_comment_not_honored_attoken_declaration_name.md.
    group('hasLeadingIgnoreCommentBeforeToken', () {
      bool check(String code, {String rule = 'my_rule', int index = 0}) {
        final unit = _parseCode(code);
        final decl = _findAll<ClassDeclaration>(unit)[index];
        return IgnoreUtils.hasLeadingIgnoreCommentBeforeToken(
          decl.nameToken,
          rule,
          unit.lineInfo,
        );
      }

      test('detects leading ignore directly above the declaration', () {
        expect(
          check('''
// ignore: my_rule
class FooState {}
'''),
          isTrue,
        );
      });

      test(
        'detects leading ignore on a declaration at the very top of file',
        () {
          // Regression guard for the synthetic start-of-file token (offset -1):
          // its clamped line-1 location must not mislabel a line-1 ignore as
          // trailing. See _isCommentAtLineStart.
          expect(check('// ignore: my_rule\nclass FooState {}\n'), isTrue);
        },
      );

      test(
        'detects leading ignore directly above a doc-commented declaration',
        () {
          // Standard ordering: doc block, then the ignore adjacent to the
          // declaration. Keying off the name token's line (not node.offset, which
          // points at the /// line) is what makes this resolve.
          expect(
            check('''
/// Doc line one.
/// Doc line two.
// ignore: my_rule
class FooState {}
'''),
            isTrue,
          );
        },
      );

      test('honors hyphenated rule name', () {
        expect(
          check('''
// ignore: my-rule
class FooState {}
'''),
          isTrue,
        );
      });

      test('detects leading ignore on a mid-file declaration', () {
        expect(
          check('''
import 'dart:core';

void helper() {}

// ignore: my_rule
class FooState {}
'''),
          isTrue,
        );
      });

      test('does NOT suppress when ignore sits above an annotation block', () {
        // The diagnostic is reported on the name line; the analyzer suppresses
        // only the line immediately below the directive, so an ignore above the
        // `@` (two lines up from the name) must not suppress.
        expect(
          check('''
// ignore: my_rule
@deprecated
class FooState {}
'''),
          isFalse,
        );
      });

      test('does NOT suppress when ignore is two lines up (doc between)', () {
        expect(
          check('''
// ignore: my_rule
/// Doc line.
class FooState {}
'''),
          isFalse,
        );
      });

      test('does NOT suppress for a different rule name', () {
        expect(
          check('''
// ignore: other_rule
class FooState {}
'''),
          isFalse,
        );
      });

      test('does NOT suppress when ignore names a longer rule (substring)', () {
        // The directive targets `my_rule_extended`; substring matching would
        // let it wrongly suppress the shorter `my_rule`. Whole-word matching
        // must reject it.
        expect(
          check('''
// ignore: my_rule_extended
class FooState {}
''', rule: 'my_rule'),
          isFalse,
        );
      });

      test('does NOT suppress with no ignore comment (control)', () {
        expect(check('class FooState {}\n'), isFalse);
      });

      test('does NOT treat a trailing ignore on prior code as leading', () {
        expect(
          check('''
final x = 1; // ignore: my_rule
class FooState {}
'''),
          isFalse,
        );
      });

      test('returns false when lineInfo is null', () {
        final unit = _parseCode('''
// ignore: my_rule
class FooState {}
''');
        final decl = _findFirst<ClassDeclaration>(unit)!;
        expect(
          IgnoreUtils.hasLeadingIgnoreCommentBeforeToken(
            decl.nameToken,
            'my_rule',
            null,
          ),
          isFalse,
        );
      });
    });

    // Line-level ignores near statements, args, catch, chains, and declarations.
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

      // Regression for infra_ignore_comment_shadowed_by_doc_comment:
      // an AnnotatedNode's beginToken is the /// doc-comment token, whose own
      // precedingComments is null, so a // ignore: directly above the
      // declaration (attached to firstTokenAfterCommentAndMetadata) was never
      // inspected. The reported node here is the map literal (a child), so the
      // suppression flows through the ancestor walk up to the FieldDeclaration.
      group('// ignore: below a /// doc comment', () {
        test('suppresses child-node diagnostic on doc-commented field', () {
          final unit = _parseCode('''
class A {
  /// Doc line one.
  /// Doc line two.
  // ignore: my_rule
  static const Map<int, int> caseWithDoc = <int, int>{
    1: 10,
  };
}
''');
          final mapLiteral = _findFirst<SetOrMapLiteral>(unit)!;
          expect(IgnoreUtils.hasIgnoreComment(mapLiteral, 'my_rule'), isTrue);
        });

        test('still suppresses when no doc comment (regression guard)', () {
          final unit = _parseCode('''
class A {
  // ignore: my_rule
  static const Map<int, int> caseNoDoc = <int, int>{
    1: 10,
  };
}
''');
          final mapLiteral = _findFirst<SetOrMapLiteral>(unit)!;
          expect(IgnoreUtils.hasIgnoreComment(mapLiteral, 'my_rule'), isTrue);
        });

        test('does not over-fire: doc comment but no // ignore:', () {
          final unit = _parseCode('''
class A {
  /// Doc line one.
  /// Doc line two.
  static const Map<int, int> caseDocNoIgnore = <int, int>{
    1: 10,
  };
}
''');
          final mapLiteral = _findFirst<SetOrMapLiteral>(unit)!;
          expect(IgnoreUtils.hasIgnoreComment(mapLiteral, 'my_rule'), isFalse);
        });

        test(
          'still suppresses on an annotated declaration with NO doc comment',
          () {
            // Regression guard: with an inline annotation and no doc comment,
            // the FieldDeclaration's beginToken is the @ metadata token, which
            // holds the // ignore: in its precedingComments. The post-doc token
            // (static) does NOT — so a fix that probed only
            // firstTokenAfterCommentAndMetadata would regress this case. Both
            // tokens must be checked.
            final unit = _parseCode('''
class A {
  // ignore: my_rule
  @Deprecated('x') static const Map<int, int> m = <int, int>{1: 10};
}
''');
            final mapLiteral = _findFirst<SetOrMapLiteral>(unit)!;
            expect(IgnoreUtils.hasIgnoreComment(mapLiteral, 'my_rule'), isTrue);
          },
        );

        test('works for a doc-commented top-level variable (not field)', () {
          final unit = _parseCode('''
/// Doc for a top-level map.
// ignore: my_rule
const Map<int, int> topLevel = <int, int>{
  1: 10,
};
''');
          final mapLiteral = _findFirst<SetOrMapLiteral>(unit)!;
          expect(IgnoreUtils.hasIgnoreComment(mapLiteral, 'my_rule'), isTrue);
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

      // Regression for infra_scan_ignore_comment_mid_ternary_operand_not_honored:
      // a standalone `// ignore:` on its own line between a ternary's operands
      // attaches to the `?`/`:` operator token, not to the flagged operand. The
      // node/ancestor walk only probes ancestor beginTokens, so the suppression
      // was silently dropped for a node reported under a `?`/`:` branch.
      group('ConditionalExpression operands (ternary branches)', () {
        // Resolves the `MediaQuery.sizeOf(context).width` PropertyAccess used as
        // the flagged ternary operand across the cases below.
        PropertyAccess widthAccess(CompilationUnit unit) =>
            _findAll<PropertyAccess>(
              unit,
            ).firstWhere((p) => p.propertyName.name == 'width');

        test('honors standalone ignore above the else operand', () {
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? a
      // ignore: my_rule
      : MediaQuery.sizeOf(context).width;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isTrue,
          );
        });

        test('honors standalone ignore above the then operand', () {
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      // ignore: my_rule
      ? MediaQuery.sizeOf(context).width
      : a;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isTrue,
          );
        });

        test('honors hyphenated standalone ignore above the else operand', () {
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? a
      // ignore: my-rule
      : MediaQuery.sizeOf(context).width;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isTrue,
          );
        });

        test('still honors a trailing ignore on the operand line', () {
          // Regression guard: the trailing same-line form already worked via
          // the trailing-comment checks; this fix must not break it.
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? a
      : MediaQuery.sizeOf(context).width; // ignore: my_rule
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isTrue,
          );
        });

        test('honors standalone ignore above a parenthesized else operand', () {
          // Unwrapping parens: the comment hangs off `:`, the flagged node
          // starts after `(`, so offsets differ — the unwrap branch must match.
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? a
      // ignore: my_rule
      : (MediaQuery.sizeOf(context).width);
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isTrue,
          );
        });

        test('does NOT leak an else-operand ignore onto the then operand', () {
          // Placement must stay precise: an ignore above the `:` branch must not
          // suppress a diagnostic reported on the `?` branch.
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? MediaQuery.sizeOf(context).width
      // ignore: my_rule
      : a;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isFalse,
          );
        });

        test('does NOT suppress for an unrelated rule name', () {
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite
      ? a
      // ignore: other_rule
      : MediaQuery.sizeOf(context).width;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isFalse,
          );
        });

        test('does NOT suppress with no ignore comment (control)', () {
          final unit = _parseCode('''
double pick(bool finite, double a) {
  return finite ? a : MediaQuery.sizeOf(context).width;
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(widthAccess(unit), 'my_rule'),
            isFalse,
          );
        });
      });

      // Regression for infra_ignore_directives_not_honored_for_custom_rules:
      // a diagnostic reported on a node nested deep inside a multi-line
      // statement (e.g. avoid_recursive_calls flags the inner self-call, which
      // sits on a later line than the `return` keyword) must still honor a
      // leading `// ignore:` written above the statement. The ancestor walk
      // previously compared every ancestor against the leaf's start line, so
      // the directive above the statement never matched once the leaf and the
      // statement were on different lines.
      group('leading ignore above a multi-line enclosing statement', () {
        // The flagged self-call sits two lines below the `// ignore:`, on a
        // different line than the `return` it is nested under.
        MethodInvocation selfCall(CompilationUnit unit) =>
            _findAll<MethodInvocation>(
              unit,
            ).firstWhere((m) => m.methodName.name == 'recurse');

        test(
          'suppresses a node on a deeper line than the ignore directive',
          () {
            final unit = _parseCode('''
int recurse(int n) {
  // ignore: my_rule
  return n *
      recurse(n - 1);
}
''');
            expect(
              IgnoreUtils.hasIgnoreComment(selfCall(unit), 'my_rule'),
              isTrue,
            );
          },
        );

        test('still honors the directive when the node shares its line', () {
          final unit = _parseCode('''
int recurse(int n) {
  // ignore: my_rule
  return n * recurse(n - 1);
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(selfCall(unit), 'my_rule'),
            isTrue,
          );
        });

        test('does NOT suppress without the directive (control)', () {
          final unit = _parseCode('''
int recurse(int n) {
  return n *
      recurse(n - 1);
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(selfCall(unit), 'my_rule'),
            isFalse,
          );
        });

        test('does NOT suppress for an unrelated rule name', () {
          final unit = _parseCode('''
int recurse(int n) {
  // ignore: other_rule
  return n *
      recurse(n - 1);
}
''');
          expect(
            IgnoreUtils.hasIgnoreComment(selfCall(unit), 'my_rule'),
            isFalse,
          );
        });
      });
    });
  });
}
