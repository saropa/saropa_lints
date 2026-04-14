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
    this.rawImportsByFile = const <String, List<String>>{},
    this.suppressions = const <SuppressionRecord>[],
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

  /// Raw `import` / `export` URI strings per analyzed file path (absolute
  /// or project-relative). Serialized as `ig` for cross-isolate merge.
  final Map<String, List<String>> rawImportsByFile;

  /// Suppression records from this isolate's analysis pass.
  /// Serialized as `sup` for cross-isolate merge.
  final List<SuppressionRecord> suppressions;

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
    if (rawImportsByFile.isNotEmpty) {
      map['ig'] = rawImportsByFile;
    }
    if (suppressions.isNotEmpty) {
      map['sup'] = _suppressionsToJson(suppressions);
    }
    return const JsonEncoder().convert(map);
  }

  /// Deserialize from JSON string. Returns null if invalid.
  static BatchData? fromJsonString(String source) {
    try {
      final decoded = json.decode(source);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['v'] != _formatVersion) return null;

      final s = map['s'];
      final i = map['i'];
      final u = map['u'];
      if (s is! String || i is! String || u is! String) return null;

      // Use tryParse — u comes from serialized JSON that may be corrupted.
      final updatedAt = DateTime.tryParse(u);
      if (updatedAt == null) return null;

      return BatchData(
        sessionId: s,
        isolateId: i,
        updatedAt: updatedAt,
        config: _configFromJson(map['cfg']),
        analyzedFiles: _stringList(map['af']),
        issuesByFile: _intMap(map['ibf']),
        issuesByRule: _intMap(map['ibr']),
        ruleSeverities: _stringMap(map['rs']),
        severityCounts: _severityCountsFromJson(map['sc']),
        violations: _violationsFromJson(map['vl']),
        rawImportsByFile: _stringListMap(map['ig']),
        suppressions: _suppressionsFromJson(map['sup']),
      );
    } on FormatException {
      return null;
    } on TypeError {
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

Map<String, Object> _severityCountsToJson(SeverityCounts sc) => {
  'e': sc.error,
  'w': sc.warning,
  'i': sc.info,
};

SeverityCounts _severityCountsFromJson(dynamic raw) {
  final m = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
  final e = m['e'];
  final w = m['w'];
  final i = m['i'];
  return SeverityCounts(
    error: e is int ? e : 0,
    warning: w is int ? w : 0,
    info: i is int ? i : 0,
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
        .map(
          (v) => <String, Object>{
            'r': v.rule,
            'f': v.file,
            'l': v.line,
            'm': v.message,
            if (v.correction != null) 'c2': v.correction!,
          },
        )
        .toList();
  }

  return result;
}

Map<LintImpact, List<ViolationRecord>> _violationsFromJson(dynamic raw) {
  final result = <LintImpact, List<ViolationRecord>>{};
  if (raw is! Map<String, dynamic>) return result;

  for (final impact in LintImpact.values) {
    final listRaw = raw[impact.name];
    final list = listRaw is List<dynamic> ? listRaw : null;
    if (list == null || list.isEmpty) continue;

    result[impact] = list.cast<Map<String, dynamic>>().map((m) {
      final r = m['r'];
      final f = m['f'];
      final l = m['l'];
      final msg = m['m'];
      final c2 = m['c2'];
      if (r is! String || f is! String || l is! int || msg is! String) {
        throw FormatException('Invalid violation record', m.toString());
      }
      return ViolationRecord(
        rule: r,
        file: f,
        line: l,
        message: msg,
        correction: c2 is String ? c2 : null,
      );
    }).toList();
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
  final v = raw['version'];
  final t = raw['tier'];
  final rc = raw['ruleCount'];
  final mi = raw['maxIssues'];
  final out = raw['output'];
  return ReportConfig(
    version: v is String ? v : 'unknown',
    effectiveTier: t is String ? t : 'unknown',
    enabledRuleCount: rc is int ? rc : 0,
    enabledRuleNames: _stringList(raw['rules']),
    enabledPlatforms: _stringList(raw['ePlatforms']),
    disabledPlatforms: _stringList(raw['dPlatforms']),
    enabledPackages: _stringList(raw['ePackages']),
    disabledPackages: _stringList(raw['dPackages']),
    userExclusions: _stringList(raw['exclusions']),
    maxIssues: mi is int ? mi : 0,
    outputMode: out is String ? out : 'both',
  );
}

List<String> _stringList(dynamic raw) {
  if (raw is! List<dynamic>) return [];
  return raw.cast<String>();
}

Map<String, int> _intMap(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};
  return raw.map((k, v) => MapEntry(k, v is int ? v : 0));
}

Map<String, String> _stringMap(dynamic raw) {
  if (raw is! Map<String, dynamic>) return {};
  return raw.map((k, v) => MapEntry(k, v is String ? v : ''));
}

Map<String, List<String>> _stringListMap(dynamic raw) {
  if (raw == null || raw is! Map) return {};
  final out = <String, List<String>>{};
  raw.forEach((key, value) {
    if (key is! String) return;
    if (value is List) {
      out[key] = value.map((e) => e.toString()).toList();
    }
  });
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Suppression record serialization — compact keys to minimize batch file size.
// ─────────────────────────────────────────────────────────────────────────────

List<Map<String, Object>> _suppressionsToJson(List<SuppressionRecord> records) {
  return records
      .map(
        (s) => <String, Object>{
          'r': s.rule,
          'f': s.file,
          'l': s.line,
          'k': s.kind.name,
        },
      )
      .toList();
}

List<SuppressionRecord> _suppressionsFromJson(dynamic raw) {
  if (raw is! List<dynamic>) return const <SuppressionRecord>[];
  final result = <SuppressionRecord>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final r = item['r'];
    final f = item['f'];
    final l = item['l'];
    final k = item['k'];
    if (r is! String || f is! String || l is! int || k is! String) continue;

    // Parse the kind string back to the enum. Skip unknown values so
    // forward-compatible if new kinds are added later.
    final kind = SuppressionKind.values.cast<SuppressionKind?>().firstWhere(
      (v) => v?.name == k,
      orElse: () => null,
    );
    if (kind == null) continue;

    result.add(SuppressionRecord(rule: r, file: f, line: l, kind: kind));
  }
  return result;
}
