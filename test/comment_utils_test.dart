import 'package:saropa_lints/src/comment_utils.dart';
import 'package:test/test.dart';

/// Unit tests for [CommentPatterns] heuristics.
///
/// These tests verify the shared detection logic used by:
/// - `prefer_no_commented_out_code` (flags code, skips prose)
/// - `prefer_capitalized_comment_start` (flags prose, skips code)
///
/// Test fixtures for integration testing:
/// - example_style/lib/stylistic/prefer_no_commented_out_code_fixture.dart
/// - example_style/lib/stylistic/prefer_capitalized_comment_start_fixture.dart
void main() {
  group('CommentPatterns.isLikelyCode', () {
    group('should detect commented-out code', () {
      test('method calls: foo.bar()', () {
        expect(CommentPatterns.isLikelyCode('foo.bar()'), isTrue);
      });

      test('function calls: doSomething()', () {
        expect(CommentPatterns.isLikelyCode('doSomething()'), isTrue);
      });

      test('assignments: x = 5', () {
        expect(CommentPatterns.isLikelyCode('x = 5'), isTrue);
      });

      test('control flow: if (condition) {', () {
        expect(CommentPatterns.isLikelyCode('if (condition) {'), isTrue);
      });

      test('declarations: final x = 5', () {
        expect(CommentPatterns.isLikelyCode('final x = 5'), isTrue);
      });

      test('imports: import \'package:foo/foo.dart\'', () {
        expect(
          CommentPatterns.isLikelyCode("import 'package:foo/foo.dart'"),
          isTrue,
        );
      });

      test('annotations: @override', () {
        expect(CommentPatterns.isLikelyCode('@override'), isTrue);
      });

      test('semicolons: statement;', () {
        expect(CommentPatterns.isLikelyCode('statement;'), isTrue);
      });

      test('arrow functions: =>', () {
        expect(CommentPatterns.isLikelyCode('(a, b) => a + b'), isTrue);
      });

      test('block delimiters: }', () {
        expect(CommentPatterns.isLikelyCode('}'), isTrue);
      });
    });

    group('should NOT detect prose comments', () {
      test('regular prose: This is a comment', () {
        expect(CommentPatterns.isLikelyCode('This is a comment'), isFalse);
      });

      test('prose labels with colon: OK: This is fine', () {
        expect(CommentPatterns.isLikelyCode('OK: This is fine'), isFalse);
      });

      test('prose labels with colon: BAD: Do not do this', () {
        expect(CommentPatterns.isLikelyCode('BAD: Do not do this'), isFalse);
      });

      test('prose labels with colon: GOOD: Preferred approach', () {
        expect(
            CommentPatterns.isLikelyCode('GOOD: Preferred approach'), isFalse);
      });

      test('prose labels with colon: LINT: Description', () {
        expect(CommentPatterns.isLikelyCode('LINT: Description'), isFalse);
      });

      test('prose with keyword: null is before non-null', () {
        expect(
          CommentPatterns.isLikelyCode('null is before non-null'),
          isFalse,
        );
      });

      test('prose with keyword: return when done', () {
        expect(CommentPatterns.isLikelyCode('return when done'), isFalse);
      });

      test('prose with keyword: true means success', () {
        expect(CommentPatterns.isLikelyCode('true means success'), isFalse);
      });

      test('empty content', () {
        expect(CommentPatterns.isLikelyCode(''), isFalse);
      });
    });
  });

  group('CommentPatterns.isSpecialMarker', () {
    test('should detect TODO markers', () {
      expect(CommentPatterns.isSpecialMarker('TODO: fix this'), isTrue);
    });

    test('should detect FIXME markers', () {
      expect(
          CommentPatterns.isSpecialMarker('FIXME: handle edge case'), isTrue);
    });

    test('should detect ignore directives', () {
      expect(
          CommentPatterns.isSpecialMarker('ignore: unused_variable'), isTrue);
    });

    test('should detect ignore_for_file directives', () {
      expect(
        CommentPatterns.isSpecialMarker('ignore_for_file: avoid_print'),
        isTrue,
      );
    });

    test('should detect expect_lint directives', () {
      expect(
        CommentPatterns.isSpecialMarker('expect_lint: my_rule'),
        isTrue,
      );
    });

    test('should detect cspell directives', () {
      expect(
        CommentPatterns.isSpecialMarker('cspell: disable-next-line'),
        isTrue,
      );
    });

    test('should NOT detect regular prose', () {
      expect(CommentPatterns.isSpecialMarker('This is regular prose'), isFalse);
    });

    test('should be case insensitive', () {
      expect(CommentPatterns.isSpecialMarker('todo: fix later'), isTrue);
    });
  });
}
