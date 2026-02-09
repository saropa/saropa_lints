// ignore_for_file: avoid_print

import 'dart:convert' show json, JsonEncoder;

import 'package:saropa_lints/src/report/analysis_reporter.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Data from a single isolate's analysis batch.
///
/// Serialized to JSON and written to `reports/.batches/` so that
/// [ReportConsolidator] can merge data across isolate restarts.
class BatchData {
  const BatchData({
    required this.sessionId,
    required this.isolateId,
    required this.updatedAt,
    required this.config,
    required this.analyzedFiles,
    required this.issuesByFile,
    required this.issuesByRule,
    required this.ruleSeverities,
    required this.severityCounts,
    required this.violations,
  });

  static const int _formatVersion = 1;

  final String sessionId;
  final String isolateId;
  final DateTime updatedAt;
  final ReportConfig? config;
  final List<String> analyzedFiles;
  final Map<String, int> issuesByFile;
  final Map<String, int> issuesByRule;
  final Map<String, String> ruleSeverities;
  final SeverityCounts severityCounts;
  final Map<LintImpact, List<ViolationRecord>> violations;

  /// Serialize to JSON string.
  String toJsonString() {
    final map = <String, Object?>{
      'v': _formatVersion,
      's': sessionId,
      'i': isolateId,
      'u': updatedAt.toIso8601String(),
      'af': analyzedFiles,
      'ibf': issuesByFile,
      'ibr': issuesByRule,
      'rs': ruleSeverities,
      'sc': _severityCountsToJson(severityCounts),
      'vl': _violationsToJson(violations),
    };
    if (config != null) {
      map['cfg'] = _configToJson(config!);
    }
    return const JsonEncoder().convert(map);
  }

  /// Deserialize from JSON string. Returns null if invalid.
  static BatchData? fromJsonString(String source) {
    try {
      final map = json.decode(source) as Map<String, dynamic>;
      if (map['v'] != _formatVersion) return null;

      return BatchData(
        sessionId: map['s'] as String,
        isolateId: map['i'] as String,
        updatedAt: DateTime.parse(map['u'] as String),
        config: _configFromJson(map['cfg']),
        analyzedFiles: _stringList(map['af']),
        issuesByFile: _intMap(map['ibf']),
        issuesByRule: _intMap(map['ibr']),
        ruleSeverities: _stringMap(map['rs']),
        severityCounts: _severityCountsFromJson(map['sc']),
        violations: _violationsFromJson(map['vl']),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Simple severity count tuple for serialization.
class SeverityCounts {
  const SeverityCounts({
    required this.error,
    required this.warning,
    required this.info,
  });

  final int error;
  final int warning;
  final int info;
}

// ─────────────────────────────────────────────────────────────────────────────
// JSON helpers — kept as top-level functions to avoid bloating BatchData.
// ─────────────────────────────────────────────────────────────────────────────

Map<String, Object> _severityCountsToJson(SeverityCounts sc) =>
    {'e': sc.error, 'w': sc.warning, 'i': sc.info};

SeverityCounts _severityCountsFromJson(dynamic raw) {
  final m = raw as Map<String, dynamic>? ?? {};
  return SeverityCounts(
    error: m['e'] as int? ?? 0,
    warning: m['w'] as int? ?? 0,
    info: m['i'] as int? ?? 0,
  );
}

Map<String, List<Map<String, Object>>> _violationsToJson(
  Map<LintImpact, List<ViolationRecord>> violations,
) {
  final result = <String, List<Map<String, Object>>>{};
  for (final impact in LintImpact.values) {
    final list = violations[impact];
    if (list == null || list.isEmpty) continue;
    result[impact.name] = list
        .map((v) => <String, Object>{
              'r': v.rule,
              'f': v.file,
              'l': v.line,
              'm': v.message,
              if (v.correction != null) 'c2': v.correction!,
            })
        .toList();
  }
  return result;
}

Map<LintImpact, List<ViolationRecord>> _violationsFromJson(dynamic raw) {
  final result = <LintImpact, List<ViolationRecord>>{};
  if (raw is! Map<String, dynamic>) return result;

  for (final impact in LintImpact.values) {
    final list = raw[impact.name] as List<dynamic>?;
    if (list == null || list.isEmpty) continue;

    result[impact] = list
        .cast<Map<String, dynamic>>()
        .map((m) => ViolationRecord(
              rule: m['r'] as String,
              file: m['f'] as String,
              line: m['l'] as int,
              message: m['m'] as String,
              correction: m['c2'] as String?,
            ))
        .toList();
  }
  return result;
}

Map<String, Object> _configToJson(ReportConfig c) => <String, Object>{
      'version': c.version,
      'tier': c.effectiveTier,
      'ruleCount': c.enabledRuleCount,
      'rules': c.enabledRuleNames,
      'ePlatforms': c.enabledPlatforms,
      'dPlatforms': c.disabledPlatforms,
      'ePackages': c.enabledPackages,
      'dPackages': c.disabledPackages,
      'exclusions': c.userExclusions,
      'maxIssues': c.maxIssues,
      'output': c.outputMode,
    };

ReportConfig? _configFromJson(dynamic raw) {
  if (raw is! Map<String, dynamic>) return null;
  return ReportConfig(
    version: raw['version'] as String? ?? 'unknown',
    effectiveTier: raw['tier'] as String? ?? 'unknown',
    enabledRuleCount: raw['ruleCount'] as int? ?? 0,
    enabledRuleNames: _stringList(raw['rules']),
    enabledPlatforms: _stringList(raw['ePlatforms']),
    disabledPlatforms: _stringList(raw['dPlatforms']),
    enabledPackages: _stringList(raw['ePackages']),
    disabledPackages: _stringList(raw['dPackages']),
    userExclusions: _stringList(raw['exclusions']),
    maxIssues: raw['maxIssues'] as int? ?? 0,
    outputMode: raw['output'] as String? ?? 'both',
  );
}

List<String> _stringList(dynamic raw) =>
    (raw as List<dynamic>?)?.cast<String>() ?? [];

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};
  return raw.map((k, v) => MapEntry(k, v as int));
}

Map<String, String> _stringMap(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};
  return raw.map((k, v) => MapEntry(k, v as String));
}
