// ignore_for_file: depend_on_referenced_packages

/// Rule semantics for policies, reporting, and future quality gates.
///
/// **Tag convention:** Some security rules add `'review-required'` in
/// `SaropaLintRule.tags` when the finding may be intentional (hotspot); see
/// [RuleType.securityHotspot].
///
/// **CWE IDs:** Numeric IDs refer to [MITRE CWE](https://cwe.mitre.org/).
library;

/// Semantic type of a lint rule for policies, reporting, and quality gates.
///
/// - [bug]: Reliability; fix required; target zero false positives.
/// - [vulnerability]: Security flaw; fix required; target high true positive rate.
/// - [codeSmell]: Maintainability; fix recommended; target zero false positives.
/// - [securityHotspot]: Security-sensitive; review required (may be safe); target
///   high "resolved after review" rate.
enum RuleType {
  bug,
  vulnerability,
  codeSmell,
  securityHotspot,
}

/// Lifecycle status of a rule.
///
/// - [ready]: Stable; recommended for production use.
/// - [beta]: Under evaluation; may have more false positives or behavior changes.
/// - [deprecated]: No longer recommended; will be removed in a future version.
enum RuleStatus {
  ready,
  beta,
  deprecated,
}

/// Optional accuracy target for a rule (for documentation and tooling).
///
/// Does not enforce; used by reports and rule-audit scripts. Wording in docs
/// should be "target" not "guarantee"; we aim for these goals, not prove them.
class AccuracyTarget {
  const AccuracyTarget({
    this.expectZeroFalsePositives = false,
    this.minTruePositiveRate,
    this.description,
  });

  /// When true, the rule aims for zero false positives (e.g. bug, code smell).
  final bool expectZeroFalsePositives;

  /// Minimum true positive rate (e.g. 0.8 for 80%). Used for vulnerability
  /// and security hotspot rules where some FPs are acceptable if TP rate is high.
  final double? minTruePositiveRate;

  /// Optional human-readable description of the target.
  final String? description;
}
