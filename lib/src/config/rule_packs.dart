// ignore_for_file: always_specify_types

/// Rule pack ids → rule codes enabled when the pack is listed under
/// `plugins.saropa_lints.rule_packs.enabled` in analysis_options.yaml.
///
/// **Config merge order:** The native plugin loads severity overrides and
/// `diagnostics:` first; then [mergeRulePacksIntoEnabled] merges pack rule codes
/// into [SaropaLintRule.enabledRules]. Codes in [SaropaLintRule.disabledRules]
/// (explicit `false`) are skipped so user opt-out wins over pack opt-in.
///
/// **Semver gates:** Packs listed in [kRulePackDependencyGates] only merge when
/// [mergeRulePacksIntoEnabled] receives a [resolvedVersions] map and the
/// resolved version of [RulePackDependencyGate.dependency] satisfies
/// [RulePackDependencyGate.constraint]. If the lockfile is missing or the
/// dependency is absent, gated packs do not merge (conservative).
///
/// **VS Code / extension:** Regenerate `extension/src/rulePacks/rulePackDefinitions.ts`
/// with `dart run tool/generate_rule_pack_registry.dart` after changing package rules.
///
/// **Maintainers (generated registry):** Rule codes for each package family are emitted
/// into `rule_pack_codes_generated.dart` from `lib/src/rules/packages/*_rules.dart`.
/// A rule that must appear in more than one pack (but lives in a single `*_rules.dart`
/// file) is listed in `kCompositeRulePackIds` in `tool/rule_pack_audit.dart`; the same
/// tool applies that map when auditing. Run `dart run tool/rule_pack_audit.dart` after
/// registry or package-rule edits to catch drift before CI.
///
/// **Overlapping rules across packs:** [mergeRulePacksIntoEnabled] returns
/// only codes newly added to [enabled]. Re-merge subtracts that set before
/// applying the next pack list; if two enabled packs share a rule and it is
/// removed from one pack only, toggling YAML may require an analyzer restart
/// for a correct effective set. Prefer disjoint pack membership.
library;

import 'package:pub_semver/pub_semver.dart';

import 'package:saropa_lints/src/config/rule_pack_codes_generated.dart';

/// Optional semver gate: pack merges only when [dependency] resolves to a
/// version allowed by [constraint] (pub semver syntax, e.g. `>=1.19.0`).
class RulePackDependencyGate {
  const RulePackDependencyGate({
    required this.dependency,
    required this.constraint,
  });

  final String dependency;
  final String constraint;
}

/// Packs that require a resolved lockfile version (Phase 3 resolver).
const Map<String, RulePackDependencyGate> kRulePackDependencyGates = {
  // Example semver-gated pack: rules apply only when package `collection`
  // resolves to >=1.19.0 (matches common migration guidance for collection APIs).
  'collection_compat': RulePackDependencyGate(
    dependency: 'collection',
    constraint: '>=1.19.0',
  ),
};

/// Returns true when [packId] has no gate, or [resolvedVersions] satisfies the gate.
bool packPassesDependencyGate(
  String packId,
  Map<String, String>? resolvedVersions,
) {
  final gate = kRulePackDependencyGates[packId];
  if (gate == null) return true;
  if (resolvedVersions == null || resolvedVersions.isEmpty) return false;
  final raw = resolvedVersions[gate.dependency];
  if (raw == null || raw.isEmpty) return false;
  try {
    final version = Version.parse(raw);
    final constraint = VersionConstraint.parse(gate.constraint);
    return constraint.allows(version);
  } catch (_) {
    return false;
  }
}

/// Returns rule codes for [packId], or empty if unknown.
Set<String> ruleCodesForPack(String packId) {
  final codes = kRulePackRuleCodes[packId];
  return codes == null ? <String>{} : Set<String>.from(codes);
}

/// All known pack ids.
Set<String> get knownRulePackIds => kRulePackRuleCodes.keys.toSet();

/// `pubspec.yaml` dependency keys (any line `  name:`) that suggest a pack.
/// Keys match [kRulePackRuleCodes]. The `package_specific` pack may use an empty set.
const Map<String, Set<String>> kRulePackPubspecMarkers = {
  ...kRulePackPubspecMarkersGenerated,
  'collection_compat': {'collection'},
};

/// True when [pubspecYamlContent] declares any [kRulePackPubspecMarkers] entry.
bool isRulePackSuggestedByPubspec(String packId, String pubspecYamlContent) {
  final markers = kRulePackPubspecMarkers[packId];
  if (markers == null) return false;
  for (final name in markers) {
    final re = RegExp(r'^\s+' + RegExp.escape(name) + r'\s*:', multiLine: true);
    if (re.hasMatch(pubspecYamlContent)) return true;
  }
  return false;
}

/// Suggested by pubspec and semver gate passes (or pack has no gate).
bool isRulePackApplicable(
  String packId,
  String pubspecYamlContent,
  Map<String, String>? lockVersions,
) {
  if (!isRulePackSuggestedByPubspec(packId, pubspecYamlContent)) return false;
  return packPassesDependencyGate(packId, lockVersions);
}

/// Adds rule codes from [packIds] into [enabled], skipping any code whose
/// lowercase name appears in [disabled] (diagnostics/severity disables).
///
/// Skips packs that fail [packPassesDependencyGate] when a gate exists.
///
/// Returns the set of rule codes added from packs (for subtract-before-remerge).
Set<String> mergeRulePacksIntoEnabled(
  Set<String> enabled,
  Set<String>? disabled,
  Iterable<String> packIds, {
  Map<String, String>? resolvedVersions,
}) {
  final contributed = <String>{};
  final disabledLc = <String>{
    for (final d in disabled ?? const <String>{}) d.toLowerCase(),
  };
  for (final packId in packIds) {
    if (!packPassesDependencyGate(packId, resolvedVersions)) continue;
    for (final code in ruleCodesForPack(packId)) {
      if (disabledLc.contains(code.toLowerCase())) continue;
      if (enabled.add(code)) contributed.add(code);
    }
  }
  return contributed;
}

/// Canonical registry: pack id → rule codes (generated from `lib/src/rules/packages/`).
const Map<String, Set<String>> kRulePackRuleCodes = {
  ...kRulePackRuleCodesGenerated,
  'collection_compat': {'avoid_collection_methods_with_unrelated_types'},
};
