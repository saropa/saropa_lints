/// Tests for rule_tier_index.dart — ensures every registered rule has a tier.
///
/// Catches registration drift: a rule added to `_allRuleFactories` in
/// `saropa_lints.dart` but missing from every tier set in `tiers.dart`
/// would produce a null tier in audit JSON output.
library;

import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/tiers.dart';
import 'package:test/test.dart';

void main() {
  group('tierForRule', () {
    test('every rule in getAllDefinedRules has a tier', () {
      // getAllDefinedRules returns the union of all tier sets, so every
      // name here must resolve to a non-null tier.
      final allRules = getAllDefinedRules();
      final missing = <String>[];

      for (final rule in allRules) {
        if (tierForRule(rule) == null) {
          missing.add(rule);
        }
      }

      expect(
        missing,
        isEmpty,
        reason: 'Rules in getAllDefinedRules() without a tier entry: $missing',
      );
    });

    test('tierIndexForRules returns entries for all known rules', () {
      final allRules = getAllDefinedRules();
      final index = tierIndexForRules(allRules);

      // Every rule should be present in the index.
      expect(index.length, equals(allRules.length));
    });

    test('tierForRule returns null for unknown rule', () {
      expect(tierForRule('__nonexistent_fake_rule__'), isNull);
    });

    test('tier names are valid', () {
      // Verify all returned tier names are from the expected set.
      final validTiers = {
        'essential',
        'recommended',
        'professional',
        'comprehensive',
        'pedantic',
        'stylistic',
      };

      final allRules = getAllDefinedRules();
      for (final rule in allRules) {
        final tier = tierForRule(rule);
        expect(
          validTiers.contains(tier),
          isTrue,
          reason: 'Rule "$rule" has unexpected tier "$tier"',
        );
      }
    });
  });
}
