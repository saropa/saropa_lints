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
          CommentPatterns.isLikelyCode('GOOD: Preferred approach'),
          isFalse,
        );
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

      // Regression tests for reported false positives
      test('inline prose: this is non-null, other is null', () {
        expect(
          CommentPatterns.isLikelyCode('this is non-null, other is null'),
          isFalse,
        );
      });

      test('section header: Iterable extensions', () {
        expect(CommentPatterns.isLikelyCode('Iterable extensions'), isFalse);
      });

      test('section header: List extensions', () {
        expect(CommentPatterns.isLikelyCode('List extensions'), isFalse);
      });

      test('section header: Map extensions and utilities', () {
        expect(
          CommentPatterns.isLikelyCode('Map extensions and utilities'),
          isFalse,
        );
      });

      test('section header: String extensions and utilities', () {
        expect(
          CommentPatterns.isLikelyCode('String extensions and utilities'),
          isFalse,
        );
      });

      test('prose: this is smaller', () {
        expect(CommentPatterns.isLikelyCode('this is smaller'), isFalse);
      });

      test('prose: Map the list of enum values to a list', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Map the list of enum values to a list of their names as strings',
          ),
          isFalse,
        );
      });

      test('prose: new set with the same elements as this iterable', () {
        expect(
          CommentPatterns.isLikelyCode(
            'new set with the same elements as this iterable',
          ),
          isFalse,
        );
      });

      test('prose: Use expand() method to flatten the 2D list', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Use expand() method to flatten the 2D list and create a',
          ),
          isFalse,
        );
      });

      test('prose: Iterate over each row in the matrix', () {
        expect(
          CommentPatterns.isLikelyCode('Iterate over each row in the matrix'),
          isFalse,
        );
      });

      test('prose: Sort the list of names in alphabetical order', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Sort the list of names in alphabetical order',
          ),
          isFalse,
        );
      });
    });

    group('should still detect actual code after tightening', () {
      test('this.name = value', () {
        expect(CommentPatterns.isLikelyCode('this.name = value'), isTrue);
      });

      test('super.dispose()', () {
        expect(CommentPatterns.isLikelyCode('super.dispose()'), isTrue);
      });

      test('new MyClass()', () {
        expect(CommentPatterns.isLikelyCode('new MyClass()'), isTrue);
      });

      test('else {', () {
        expect(CommentPatterns.isLikelyCode('else {'), isTrue);
      });

      test('String name;', () {
        expect(CommentPatterns.isLikelyCode('String name;'), isTrue);
      });

      test('int value = 5;', () {
        expect(CommentPatterns.isLikelyCode('int value = 5;'), isTrue);
      });

      test('return null;', () {
        expect(CommentPatterns.isLikelyCode('return null;'), isTrue);
      });

      test('list.sort()', () {
        expect(CommentPatterns.isLikelyCode('list.sort()'), isTrue);
      });

      // Strong code indicators should bypass prose guard
      test('for (int i in list) — not prose despite for/in', () {
        expect(CommentPatterns.isLikelyCode('for (int i in list)'), isTrue);
      });

      test('if (value != null) return;', () {
        expect(
          CommentPatterns.isLikelyCode('if (value != null) return;'),
          isTrue,
        );
      });

      test('final result = getValue();', () {
        expect(
          CommentPatterns.isLikelyCode('final result = getValue();'),
          isTrue,
        );
      });
    });
  });

  group('CommentPatterns.isSpecialMarker', () {
    test('should detect TODO markers', () {
      expect(CommentPatterns.isSpecialMarker('TODO: fix this'), isTrue);
    });

    test('should detect FIXME markers', () {
      expect(
        CommentPatterns.isSpecialMarker('FIXME: handle edge case'),
        isTrue,
      );
    });

    test('should detect ignore directives', () {
      expect(
        CommentPatterns.isSpecialMarker('ignore: unused_variable'),
        isTrue,
      );
    });

    test('should detect ignore_for_file directives', () {
      expect(
        CommentPatterns.isSpecialMarker('ignore_for_file: avoid_print'),
        isTrue,
      );
    });

    test('should detect expect_lint directives', () {
      expect(CommentPatterns.isSpecialMarker('expect_lint: my_rule'), isTrue);
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
