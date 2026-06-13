import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/stylistic/prefer_us_english_spelling_rule.dart';
import 'package:saropa_lints/src/rules/data/uk_to_us_spellings.dart';

/// Tests for the prefer_us_english_spelling rule.
///
/// Test fixture: example/lib/stylistic/prefer_us_english_spelling_fixture.dart
/// (detection behavior is verified with the scan CLI; unit tests pin the rule's
/// registration metadata and the generated data map it depends on).
void main() {
  group('PreferUsEnglishSpellingRule - instantiation', () {
    test('code metadata is well-formed', () {
      final rule = PreferUsEnglishSpellingRule();
      expect(rule.code.lowerCaseName, 'prefer_us_english_spelling');
      expect(
        rule.code.problemMessage,
        contains('[prefer_us_english_spelling]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('kUkToUsSpellings generated map', () {
    test('contains representative coverage entries', () {
      // Sanity-check that the generated map was wired in and carries the
      // expected British -> American mappings. The Python parity test guards
      // that this file stays in sync with the canonical dictionary.
      expect(kUkToUsSpellings['colour'], 'color');
      expect(kUkToUsSpellings['dialogue'], 'dialog');
      expect(kUkToUsSpellings['initialise'], 'initialize');
      expect(kUkToUsSpellings['realise'], 'realize');
    });

    test('omits the ambiguous American noun plurals', () {
      // analyses / paralyses are correct American plurals; the canonical
      // dictionary drops them, so the generated map must not carry them.
      expect(kUkToUsSpellings.containsKey('analyses'), isFalse);
      expect(kUkToUsSpellings.containsKey('paralyses'), isFalse);
    });
  });
}
