/// Rule metadata cache and tier utility functions.
library;

import 'package:saropa_lints/saropa_lints.dart'
    show RuleStatus, RuleTier, SaropaLintRule, allSaropaRules;
// ignore: implementation_imports
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'package:saropa_lints/src/string_slice_utils.dart';

// ---------------------------------------------------------------------------
// Tier utilities
// ---------------------------------------------------------------------------

/// Maps [RuleTier] enum to its string name.
String tierToString(RuleTier tier) {
  return switch (tier) {
    RuleTier.essential => 'essential',
    RuleTier.recommended => 'recommended',
    RuleTier.professional => 'professional',
    RuleTier.comprehensive => 'comprehensive',
    RuleTier.pedantic => 'pedantic',
    RuleTier.stylistic => 'stylistic',
  };
}

/// Returns the tier order index (lower = stricter requirements).
int tierIndex(RuleTier tier) {
  return switch (tier) {
    RuleTier.essential => 0,
    RuleTier.recommended => 1,
    RuleTier.professional => 2,
    RuleTier.comprehensive => 3,
    RuleTier.pedantic => 4,
    RuleTier.stylistic =>
      -1, // Stylistic is opt-in, not part of tier progression
  };
}

/// Gets tier from tiers.dart sets (single source of truth).
RuleTier getTierFromSets(String ruleName) {
  if (tiers.stylisticRules.contains(ruleName)) return RuleTier.stylistic;
  if (tiers.essentialRules.contains(ruleName)) return RuleTier.essential;
  if (tiers.pedanticOnlyRules.contains(ruleName)) return RuleTier.pedantic;

  if (tiers.comprehensiveOnlyRules.contains(ruleName)) {
    return RuleTier.comprehensive;
  }

  if (tiers.professionalOnlyRules.contains(ruleName)) {
    return RuleTier.professional;
  }

  if (tiers.recommendedOnlyRules.contains(ruleName)) {
    return RuleTier.recommended;
  }

  return RuleTier.professional;
}

// ---------------------------------------------------------------------------
// Rule metadata
// ---------------------------------------------------------------------------

/// Metadata for a single rule.
class RuleMetadata {
  const RuleMetadata({
    required this.name,
    required this.problemMessage,
    required this.correctionMessage,
    required this.severity,
    required this.tier,
    required this.ruleStatus,
    required this.hasFix,
    required this.relatedRules,
    required this.conflictingRules,
    required this.supersedesRules,
    this.exampleBad,
    this.exampleGood,
  });

  final String name;
  final String problemMessage;
  final String correctionMessage;
  final String severity; // 'ERROR', 'WARNING', 'INFO'
  final RuleTier tier;
  final RuleStatus ruleStatus;

  /// Whether this rule provides a quick fix in the IDE.
  final bool hasFix;

  /// Curated related rules from rule metadata.
  final List<String> relatedRules;

  /// Curated conflicting/opposite rules from rule metadata.
  final List<String> conflictingRules;

  /// Curated migration map: this rule supersedes older rule names.
  final List<String> supersedesRules;

  /// Short BAD example for CLI walkthrough (null if not provided).
  final String? exampleBad;

  /// Short GOOD example for CLI walkthrough (null if not provided).
  final String? exampleGood;
}

/// Cache for rule metadata (built once from allSaropaRules).
Map<String, RuleMetadata>? _ruleMetadataCache;

/// Builds and returns rule metadata from rule classes.
Map<String, RuleMetadata> getRuleMetadata() {
  var cache = _ruleMetadataCache;
  if (cache != null) return cache;

  cache = <String, RuleMetadata>{};
  _ruleMetadataCache = cache;
  for (final SaropaLintRule rule in allSaropaRules) {
    final String ruleName = rule.code.lowerCaseName;
    final String message = rule.code.problemMessage;
    final String correction = rule.code.correctionMessage ?? '';
    final severity = rule.code.severity.name.toUpperCase();
    final RuleTier tier = getTierFromSets(ruleName);

    cache[ruleName] = RuleMetadata(
      name: ruleName,
      problemMessage: message,
      correctionMessage: correction,
      severity: severity,
      tier: tier,
      ruleStatus: rule.ruleStatus,
      hasFix: rule.fixGenerators.isNotEmpty,
      relatedRules: rule.relatedRules,
      conflictingRules: rule.conflictingRules,
      supersedesRules: rule.supersedesRules,
      exampleBad: rule.exampleBad,
      exampleGood: rule.exampleGood,
    );
  }

  return cache;
}

/// Gets the lifecycle status for a rule.
RuleStatus getRuleStatusFromMetadata(String ruleName) {
  return getRuleMetadata()[ruleName]?.ruleStatus ?? RuleStatus.ready;
}

/// Returns the subset of [enabled] whose lifecycle status is beta or deprecated.
///
/// Beta and deprecated rules are excluded from generated tier output unless the
/// user explicitly opts in via a persistent override — beta rules may carry more
/// false positives or change behavior, and deprecated rules are slated for
/// removal, so neither belongs in a fresh config a user did not hand-pick. Both
/// config-generation paths must apply this identically: the interactive
/// `init_runner` and the headless `runWriteConfig` (the path the VS Code
/// extension and CI use). Centralized here so the two cannot drift — a beta rule
/// that slips through one path but not the other is exactly the bug this removes.
Set<String> lifecycleFilteredRules(Set<String> enabled) {
  return <String>{
    for (final rule in enabled)
      if (getRuleStatusFromMetadata(rule) case RuleStatus.beta ||
          RuleStatus.deprecated)
        rule,
  };
}

/// Gets the problem message for a rule (for YAML comment).
String getProblemMessage(String ruleName) {
  final metadata = getRuleMetadata()[ruleName];
  if (metadata == null) return '';
  return stripRulePrefix(metadata.problemMessage);
}

/// Gets a combined description for a rule (problem + correction).
///
/// Used in the stylistic section of analysis_options_custom.yaml where
/// users need enough context to decide whether to enable each rule.
String getStylisticDescription(String ruleName) {
  final metadata = getRuleMetadata()[ruleName];
  if (metadata == null) return '';

  final problem = stripRulePrefix(metadata.problemMessage);
  final correction = stripRulePrefix(metadata.correctionMessage);

  if (correction.isEmpty) return problem;

  // If correction just restates the problem, skip it
  if (problem.contains(correction) || correction.contains(problem)) {
    return problem.length >= correction.length ? problem : correction;
  }

  return '$problem $correction';
}

/// Remove rule name prefix if present (e.g., "`[rule_name]` ...").
String stripRulePrefix(String msg) {
  final prefixMatch = RegExp(r'^\[[\w_]+\]\s*').firstMatch(msg);
  if (prefixMatch != null) return msg.afterIndex(prefixMatch.end);
  return msg;
}

/// Gets the severity for a rule.
String getRuleSeverity(String ruleName) {
  return getRuleMetadata()[ruleName]?.severity ?? 'INFO';
}

/// Gets the tier for a rule.
RuleTier getRuleTierFromMetadata(String ruleName) {
  return getRuleMetadata()[ruleName]?.tier ?? RuleTier.professional;
}

/// Gets related rules for a rule.
List<String> getRelatedRules(String ruleName) {
  return getRuleMetadata()[ruleName]?.relatedRules ?? const <String>[];
}

/// Gets conflicting rules for a rule.
List<String> getConflictingRules(String ruleName) {
  return getRuleMetadata()[ruleName]?.conflictingRules ?? const <String>[];
}

/// Gets superseded rules for a rule.
List<String> getSupersedesRules(String ruleName) {
  return getRuleMetadata()[ruleName]?.supersedesRules ?? const <String>[];
}
