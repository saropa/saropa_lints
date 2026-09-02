/// Reverse-lookup indexes: rule name → tier, rule name → category.
///
/// Built lazily from the tier sets in `tiers.dart` and the generated
/// category map in `rule_category_map.dart`. Used by the audit CLI to
/// enrich each diagnostic with its tier and category in the JSON output.
library;

import '../tiers.dart';
import 'rule_category_map.dart';

/// Canonical tier names in cumulative order (most inclusive tier wins when
/// a rule appears in multiple tiers).
const _tierSets = <String, Set<String>>{
  'essential': essentialRules,
  'recommended': recommendedOnlyRules,
  'professional': professionalOnlyRules,
  'comprehensive': comprehensiveOnlyRules,
  'pedantic': pedanticOnlyRules,
  'stylistic': stylisticRules,
};

/// Lazily-built reverse map: rule name → lowest (most inclusive) tier.
///
/// Essential < Recommended < Professional < Comprehensive < Pedantic;
/// stylistic is orthogonal. When a rule appears in both a numbered tier
/// and stylistic, the numbered tier wins so the user sees the tier that
/// actually gates the rule.
Map<String, String>? _tierIndex;

/// Returns the tier name for [ruleName], or `null` if the rule is not
/// registered in any tier set.
String? tierForRule(String ruleName) {
  // Build on first access; the tier sets are compile-time constants so
  // this is safe to cache for the process lifetime.
  _tierIndex ??= _buildTierIndex();
  return _tierIndex![ruleName];
}

/// Builds the reverse tier index. Iterate in cumulative order so that a
/// rule in both `essential` and `recommended` maps to `essential`.
Map<String, String> _buildTierIndex() {
  final index = <String, String>{};
  for (final entry in _tierSets.entries) {
    for (final rule in entry.value) {
      // First-writer wins: lower tiers are iterated first.
      index.putIfAbsent(rule, () => entry.key);
    }
  }
  return index;
}

/// Returns the tier name for every rule in [ruleNames], keyed by rule name.
/// Rules not in any tier are omitted from the result.
Map<String, String> tierIndexForRules(Set<String> ruleNames) {
  final result = <String, String>{};
  for (final name in ruleNames) {
    final tier = tierForRule(name);
    if (tier != null) result[name] = tier;
  }
  return result;
}

/// Returns the category slug for [ruleName] (e.g. `core`, `security`,
/// `packages`), derived from the source file's parent directory.
/// Returns `null` if the rule is not in the generated category map.
String? categoryForRule(String ruleName) => ruleCategoryMap[ruleName];

/// Returns the category for every rule in [ruleNames], keyed by rule name.
/// Rules not in the category map are omitted from the result.
Map<String, String> categoryIndexForRules(Set<String> ruleNames) {
  final result = <String, String>{};
  for (final name in ruleNames) {
    final cat = categoryForRule(name);
    if (cat != null) result[name] = cat;
  }
  return result;
}
