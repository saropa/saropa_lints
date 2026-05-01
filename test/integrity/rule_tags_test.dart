import 'package:saropa_lints/src/rule_tags.dart';
import 'package:test/test.dart';

// rule_tags: canonical tag strings for OWASP / category groupings.

void main() {
  group('rule tags', () {
    test('canonicalizeRuleTag normalizes aliases', () {
      expect(canonicalizeRuleTag('a11y'), 'accessibility');
      expect(canonicalizeRuleTag('  A11Y  '), 'accessibility');
    });

    test('normalizeRuleTags de-duplicates and sorts canonical tags', () {
      final normalized = normalizeRuleTags(<String>[
        'security',
        'a11y',
        'accessibility',
        'SECURITY',
      ]);

      expect(normalized, <String>['accessibility', 'security']);
    });

    test('isKnownRuleTag checks canonical tag set', () {
      expect(isKnownRuleTag('a11y'), isTrue);
      expect(isKnownRuleTag('accessibility'), isTrue);
      expect(isKnownRuleTag('made-up-tag'), isFalse);
    });
  });
}
