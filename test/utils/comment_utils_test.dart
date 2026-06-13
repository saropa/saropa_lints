import 'package:saropa_lints/src/comment_utils.dart';
import 'package:test/test.dart';

/// Unit tests for [CommentPatterns] heuristics.
///
/// These tests verify the shared detection logic used by:
/// - `prefer_no_commented_out_code` (flags code, skips prose)
/// - `prefer_capitalized_comment_start` (flags prose, skips code)
///
/// Test fixtures for integration testing:
/// - example/lib/stylistic/prefer_no_commented_out_code_fixture.dart
/// - example/lib/naming_style/prefer_capitalized_comment_start_fixture.dart
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

      // Regression: prose with parenthetical ranges and English semicolons
      test('prose with parenthetical range and semicolon', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Speed slider (0.25×–4×) is local to this tab;',
          ),
          isFalse,
        );
      });

      test('prose with parenthetical note and semicolon', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Widget handles tap events (see docs); delegates to parent.',
          ),
          isFalse,
        );
      });

      test('prose with parenthetical and trailing semicolon', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Default timeout is 30s (configurable via settings); zero disables.',
          ),
          isFalse,
        );
      });

      test('prose with parenthetical alternatives and semicolon', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Parse results (JSON or XML) are cached; expired entries evicted.',
          ),
          isFalse,
        );
      });

      test('prose with only a trailing semicolon', () {
        expect(
          CommentPatterns.isLikelyCode(
            'The overlay covers the viewport; tapping dismisses it.',
          ),
          isFalse,
        );
      });

      test('prose with only parentheses (no semicolon)', () {
        expect(
          CommentPatterns.isLikelyCode(
            'Speed slider (0.25 to 4) is local to this tab.',
          ),
          isFalse,
        );
      });

      // Regression: a single identifier-shaped word ending a wrapped prose
      // sentence with a period (e.g. the last physical line of a block comment)
      // is sentence punctuation, not member access. A trailing dot with nothing
      // after it is never valid Dart.
      test('single word + sentence period: result.', () {
        expect(CommentPatterns.isLikelyCode('result.'), isFalse);
      });

      test('single word + sentence period: value.', () {
        expect(CommentPatterns.isLikelyCode('value.'), isFalse);
      });

      test('single word + sentence period: done.', () {
        expect(CommentPatterns.isLikelyCode('done.'), isFalse);
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

      // Regression guards: the dot branch still matches real member access
      // (a selector follows the dot), so tightening it for prose tails like
      // `result.` does not let true member access slip through.
      test('foo.bar — member access', () {
        expect(CommentPatterns.isLikelyCode('foo.bar'), isTrue);
      });

      test('list.add(item) — method call', () {
        expect(CommentPatterns.isLikelyCode('list.add(item)'), isTrue);
      });

      test('obj.field = x — field assignment', () {
        expect(CommentPatterns.isLikelyCode('obj.field = x'), isTrue);
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

  // Block-level prose detection: a single wrapped line that names a real API
  // method is identical to member access in isolation; the contiguous comment
  // block is what reveals it as prose.
  group('CommentPatterns.isLikelyProse', () {
    test('null/empty is not prose', () {
      expect(CommentPatterns.isLikelyProse(null), isFalse);
      expect(CommentPatterns.isLikelyProse(''), isFalse);
    });

    test('joined wrapped block referencing an API reads as prose', () {
      // The reproducer block from jwt_structure_utils.dart, joined.
      const String joined =
          "base64url omits '=' padding, but base64Url.decode requires the "
          'length to be a multiple of four — restore the stripped padding '
          'before decoding. The outer `% block` keeps this at 0 when the '
          'length is already aligned; `block - 0` would otherwise append a '
          "spurious full '====' block and make base64Url.decode reject an "
          'otherwise-valid token.';
      expect(CommentPatterns.isLikelyProse(joined), isTrue);
    });

    test('an isolated API-reference line is NOT seen as prose', () {
      // One function word ("an") and no strong indicators: below the per-line
      // threshold, which is exactly why block-level evaluation is needed.
      expect(
        CommentPatterns.isLikelyProse(
          'base64Url.decode reject an otherwise-valid token.',
        ),
        isFalse,
      );
    });
  });

  group('CommentPatterns.hasStrongCodeIndicators', () {
    test('null/empty has no strong indicators', () {
      expect(CommentPatterns.hasStrongCodeIndicators(null), isFalse);
      expect(CommentPatterns.hasStrongCodeIndicators(''), isFalse);
    });

    test('call with parens is strong code', () {
      expect(CommentPatterns.hasStrongCodeIndicators('foo.bar();'), isTrue);
    });

    test('arrow and braces are strong code', () {
      expect(CommentPatterns.hasStrongCodeIndicators('(a) => a + 1'), isTrue);
      expect(CommentPatterns.hasStrongCodeIndicators('class X {'), isTrue);
    });

    test('in-prose API reference is NOT strong code', () {
      // No parens/arrow/braces, so it cannot rescue itself from a prose block.
      expect(
        CommentPatterns.hasStrongCodeIndicators(
          'base64Url.decode reject the token.',
        ),
        isFalse,
      );
    });
  });

  group('CommentPatterns.isWrappedProseFragment', () {
    test('null/empty is not a prose fragment', () {
      expect(CommentPatterns.isWrappedProseFragment(null), isFalse);
      expect(CommentPatterns.isWrappedProseFragment(''), isFalse);
    });

    test('lowercase continuation citing a call mid-sentence is a fragment', () {
      // The reproducer middle line: lowercase start + function words ("this",
      // "in"), even though it names formatNumberLocale(...). Must be vetoed so
      // the strong-code carve-out does not re-flag it inside a prose block.
      expect(
        CommentPatterns.isWrappedProseFragment(
          'this, formatNumberLocale(x, decimalPlaces: 25) crashed '
          '(formatDouble in',
        ),
        isTrue,
      );
    });

    test('lowercase line with an unbalanced trailing paren is a fragment', () {
      expect(
        CommentPatterns.isWrappedProseFragment(
          'an empty result (rare in practice but observed in the',
        ),
        isTrue,
      );
    });

    test('genuine dead-code statement is NOT a fragment', () {
      // Starts lowercase ("return") but carries no function words, so it stays
      // flagged as dead code under a prose lead-in.
      expect(
        CommentPatterns.isWrappedProseFragment('return cache.get(key);'),
        isFalse,
      );
    });

    test('lowercase statement with no function words is NOT a fragment', () {
      expect(
        CommentPatterns.isWrappedProseFragment('final result = getValue();'),
        isFalse,
      );
    });

    test('capitalized sentence start is NOT a fragment', () {
      // Sentence-initial lines do not begin with a lowercase continuation word.
      expect(
        CommentPatterns.isWrappedProseFragment(
          'Without this, formatNumberLocale(x) crashed in the helper.',
        ),
        isFalse,
      );
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
