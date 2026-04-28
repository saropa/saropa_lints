/// Canonical vocabulary for rule metadata tags.
///
/// Keep this list additive and stable so external consumers can rely on it.
const Set<String> knownRuleTags = <String>{
  'accessibility',
  'architecture',
  'async',
  'bad-practice',
  'config',
  'convention',
  'crypto',
  'dart-core',
  'dart-io',
  'desktop',
  'design',
  'disposal',
  'documentation',
  'flutter',
  'i18n',
  'maintainability',
  'network',
  'packages',
  'performance',
  'pitfall',
  'platform',
  'reliability',
  'review-required',
  'security',
  'state-management',
  'storage',
  'suspicious',
  'testing',
  'type-safety',
  'ui',
};

const Map<String, String> _ruleTagAliases = <String, String>{
  // Preserve one canonical spelling in exports/filters.
  'a11y': 'accessibility',
};

/// Returns the canonical form of [tag].
///
/// Unknown tags are preserved as lower-case to avoid dropping user metadata.
String canonicalizeRuleTag(String tag) {
  final normalized = tag.trim().toLowerCase();
  return _ruleTagAliases[normalized] ?? normalized;
}

/// Canonicalizes, de-duplicates, and sorts tags for stable output.
List<String> normalizeRuleTags(Iterable<String> tags) {
  final canonical = tags.map(canonicalizeRuleTag).where((t) => t.isNotEmpty);
  final unique = canonical.toSet().toList()..sort();
  return unique;
}

/// Whether [tag] is part of the curated canonical vocabulary.
bool isKnownRuleTag(String tag) =>
    knownRuleTags.contains(canonicalizeRuleTag(tag));
