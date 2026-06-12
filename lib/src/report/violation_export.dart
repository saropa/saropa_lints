// ignore_for_file: avoid_print

import 'dart:convert' show JsonEncoder;
import 'dart:developer' as developer;
import 'dart:io' show Directory, File, stderr;

import 'package:path/path.dart' as path;
import 'package:saropa_lints/saropa_lints.dart'
    show getRulesFromRegistry, rulesWithFixes;
import 'package:saropa_lints/src/baseline/baseline_manager.dart';
import 'package:saropa_lints/src/report/analysis_reporter.dart';
import 'package:saropa_lints/src/report/diagnostic_statistics.dart';
import 'package:saropa_lints/src/report/import_graph_tracker.dart';
import 'package:saropa_lints/src/report/health_score_constants.dart';
import 'package:saropa_lints/src/report/report_consolidator.dart';
import 'package:saropa_lints/src/rule_tags.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Writes a structured JSON export of all lint violations.
///
/// This file is consumed by Saropa Log Capture to cross-reference
/// runtime errors with static analysis findings. The export is written
/// to `reports/.saropa_lints/violations.json` and overwritten on each
/// analysis run.
///
/// See `bugs/discussion/log_capture_integration.md` for the full spec.
class ViolationExporter {
  ViolationExporter._();

  static const String _dirName = '.saropa_lints';
  static const String _fileName = 'violations.json';
  static const String _schemaVersion = '1.0';

  /// Write the structured JSON export alongside the markdown report.
  ///
  /// [projectRoot] is the absolute project root path.
  /// [sessionId] is the current analysis session identifier.
  /// [data] is the consolidated analysis data from all isolates.
  /// [owaspLookup] maps rule names to their OWASP mappings.
  static void write({
    required String projectRoot,
    required String sessionId,
    required ConsolidatedData data,
    required Map<String, OwaspMapping> owaspLookup,
  }) {
    try {
      final json = _buildJson(
        projectRoot: projectRoot,
        sessionId: sessionId,
        data: data,
        owaspLookup: owaspLookup,
      );

      final encoded = const JsonEncoder.withIndent('  ').convert(json);

      _writeAtomic(projectRoot, encoded);
      _writeConsumerContract(projectRoot);
    } on Object catch (e) {
      stderr.writeln('[saropa_lints] Could not write violation export: $e');
    }
  }

  static const String _consumerContractFileName = 'consumer_contract.json';

  static const List<String> _tierIds = <String>[
    'essential',
    'recommended',
    'professional',
    'comprehensive',
    'pedantic',
    'stylistic',
  ];

  /// Write consumer_contract.json (schemaVersion, healthScore, tierRuleSets) for consumers that do not use the extension.
  static void _writeConsumerContract(String projectRoot) {
    try {
      final tierRuleSets = <String, Object>{};
      for (final tierId in _tierIds) {
        final rules = tiers.getRulesForTier(tierId).toList()..sort();
        tierRuleSets[tierId] = rules;
      }
      final relatedRulesByRule = _buildRelatedRulesByRule(
        tiers.getAllDefinedRules(),
      );
      final conflictingRulesByRule = _buildConflictingRulesByRule(
        tiers.getAllDefinedRules(),
      );
      final supersedesRulesByRule = _buildSupersedesRulesByRule(
        tiers.getAllDefinedRules(),
      );
      final json = <String, Object>{
        'schemaVersion': _schemaVersion,
        'healthScore': <String, Object>{
          'impactWeights': Map<String, num>.from(healthScoreImpactWeights),
          'decayRate': healthScoreDecayRate,
        },
        'tierRuleSets': tierRuleSets,
        'relatedRulesByRule': relatedRulesByRule,
        'conflictingRulesByRule': conflictingRulesByRule,
        'supersedesRulesByRule': supersedesRulesByRule,
      };
      final encoded = const JsonEncoder.withIndent('  ').convert(json);
      _writeAtomicFile(projectRoot, _consumerContractFileName, encoded);
    } on Object catch (e) {
      stderr.writeln(
        '[saropa_lints] Could not write consumer_contract.json: $e',
      );
    }
  }

  /// Writes [content] to [fileName] under reports/.saropa_lints/ using temp-file-then-rename for atomicity.
  /// Shared by violations.json and consumer_contract.json; fallback to direct write on rename failure.
  static void _writeAtomicFile(
    String projectRoot,
    String fileName,
    String content,
  ) {
    final base = path.normalize(projectRoot);
    final dirPath = path.join(base, 'reports', _dirName);
    if (!path.isWithin(base, dirPath)) return;

    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final targetPath = path.join(dir.path, fileName);
    final tmpPath = '$targetPath.tmp';
    final tmpFile = File(tmpPath);
    final targetFile = File(targetPath);

    try {
      tmpFile.writeAsStringSync(content);
      if (targetFile.existsSync()) {
        targetFile.deleteSync();
      }
      tmpFile.renameSync(targetPath);
    } catch (e, st) {
      developer.log(
        'ViolationExporter._writeAtomicFile failed: $fileName',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      try {
        targetFile.writeAsStringSync(content);
      } catch (e2, st2) {
        developer.log(
          'ViolationExporter._writeAtomicFile fallback failed: $fileName',
          name: 'saropa_lints',
          error: e2,
          stackTrace: st2,
        );
        stderr.writeln('[saropa_lints] Could not write $fileName: $e2');
      }
      try {
        if (tmpFile.existsSync()) tmpFile.deleteSync();
      } on Object catch (e) {
        // Fix: avoid_swallowing_exceptions — best-effort temp cleanup; log to
        // stderr instead of silently dropping so stale temp files become
        // diagnosable during development.
        stderr.writeln(
          '[saropa_lints] Could not delete temp file ${tmpFile.path}: $e',
        );
      }
    }
  }

  /// Build the full JSON structure for the export.
  static Map<String, Object> _buildJson({
    required String projectRoot,
    required String sessionId,
    required ConsolidatedData data,
    required Map<String, OwaspMapping> owaspLookup,
  }) {
    final config = data.config;
    final ruleMetadata = _buildRuleMetadataLookup(
      config: config,
      violations: data.violations,
    );

    return <String, Object>{
      'schema': _schemaVersion,
      if (config != null) 'version': config.version,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'sessionId': sessionId,
      'config': _buildConfig(config, ruleMetadata),
      'summary': _buildSummary(data, projectRoot, ruleMetadata),
      'violations': _buildViolations(
        projectRoot: projectRoot,
        violations: data.violations,
        ruleSeverities: data.ruleSeverities,
        owaspLookup: owaspLookup,
        ruleMetadata: ruleMetadata,
      ),
    };
  }

  /// Build the config section.
  static Map<String, Object> _buildConfig(
    ReportConfig? config,
    Map<String, _RuleMetadataSnapshot> ruleMetadata,
  ) {
    if (config == null) {
      return <String, Object>{
        'tier': 'unknown',
        'ruleMetadataByRule': _ruleMetadataLookupToJson(ruleMetadata),
      };
    }

    // Extension triage UI uses this to separate stylistic (opt-in) rules.
    final stylisticList = tiers.stylisticRules.toList()..sort();
    // Extension uses this to disable "Apply fix" for rules without fixes.
    final fixList = rulesWithFixes.toList()..sort();
    final relatedRulesByRule = _buildRelatedRulesByRule(
      config.enabledRuleNames,
    );
    final conflictingRulesByRule = _buildConflictingRulesByRule(
      config.enabledRuleNames,
    );
    final supersedesRulesByRule = _buildSupersedesRulesByRule(
      config.enabledRuleNames,
    );
    return <String, Object>{
      'tier': config.effectiveTier,
      'enabledRuleCount': config.enabledRuleCount,
      'enabledRuleCountNote': 'After tier selection and user overrides',
      'enabledRuleNames': config.enabledRuleNames,
      'stylisticRuleNames': stylisticList,
      'rulesWithFixes': fixList,
      'ruleMetadataByRule': _ruleMetadataLookupToJson(ruleMetadata),
      'relatedRulesByRule': relatedRulesByRule,
      'conflictingRulesByRule': conflictingRulesByRule,
      'supersedesRulesByRule': supersedesRulesByRule,
      'enabledPlatforms': config.enabledPlatforms,
      'disabledPlatforms': config.disabledPlatforms,
      'enabledPackages': config.enabledPackages,
      'disabledPackages': config.disabledPackages,
      'userExclusions': config.userExclusions,
      'maxIssues': config.maxIssues,
      'maxIssuesNote':
          'IDE Problems tab cap only; this export contains all violations',
      'outputMode': config.outputMode,
    };
  }

  static Map<String, List<String>> _buildRelatedRulesByRule(
    Iterable<String> ruleNames,
  ) {
    return _buildRuleAdjacencyMap(
      ruleNames,
      referencesOf: (rule) => rule.relatedRules,
    );
  }

  static Map<String, List<String>> _buildConflictingRulesByRule(
    Iterable<String> ruleNames,
  ) {
    return _buildRuleAdjacencyMap(
      ruleNames,
      referencesOf: (rule) => rule.conflictingRules,
    );
  }

  static Map<String, List<String>> _buildSupersedesRulesByRule(
    Iterable<String> ruleNames,
  ) {
    return _buildRuleAdjacencyMap(
      ruleNames,
      referencesOf: (rule) => rule.supersedesRules,
    );
  }

  static Map<String, List<String>> _buildRuleAdjacencyMap(
    Iterable<String> ruleNames, {
    required Iterable<String> Function(SaropaLintRule rule) referencesOf,
  }) {
    final ruleNameList = ruleNames.toList();
    if (ruleNameList.isEmpty) return const <String, List<String>>{};

    final enabledSet = ruleNameList.toSet();
    final byRule = <String, List<String>>{};
    final rules = getRulesFromRegistry(enabledSet);

    for (final rule in rules) {
      final source = rule.code.lowerCaseName;
      if (source.isEmpty) continue;
      final references = referencesOf(rule);
      if (references.isEmpty) continue;

      final normalized = <String>{};
      for (final referenced in references) {
        final name = referenced.trim();
        if (name.isEmpty || name == source) continue;
        normalized.add(name);
      }
      if (normalized.isEmpty) continue;

      final sorted = normalized.toList()..sort();
      byRule[source] = sorted;
    }

    return byRule;
  }

  /// Build the summary section with aggregate counts.
  static Map<String, Object> _buildSummary(
    ConsolidatedData data,
    String projectRoot,
    Map<String, _RuleMetadataSnapshot> ruleMetadata,
  ) {
    final diagnosticStats = DiagnosticStatisticsEvaluator.evaluate(
      projectRoot: projectRoot,
      issuesByRule: data.issuesByRule,
    );

    final metadataBreakdown = _buildIssueBreakdownByMetadata(
      issuesByRule: data.issuesByRule,
      ruleMetadata: ruleMetadata,
    );

    return <String, Object>{
      'filesAnalyzed': data.filesAnalyzed,
      // Total discovered project files (the health-score denominator basis).
      // Lets the extension distinguish a full sweep from a partial one and
      // avoid showing a false 0% computed over a tiny incremental sample.
      // Omitted when discovery did not run, so consumers fall back to the
      // legacy behavior of trusting whatever filesAnalyzed reports.
      if (ProgressTracker.expectedFileCount > 0)
        'filesExpected': ProgressTracker.expectedFileCount,
      'filesWithIssues': data.filesWithIssues,
      'totalViolations': data.total,
      'batchCount': data.batchCount,
      'bySeverity': <String, int>{
        'error': data.errorCount,
        'warning': data.warningCount,
        'info': data.infoCount,
      },
      'byImpact': <String, int>{
        for (final impact in LintImpact.values)
          impact.name: data.impactCounts[impact] ?? 0,
      },
      'issuesByFile': _relativizeFileKeys(data.issuesByFile, projectRoot),
      'issuesByRule': data.issuesByRule,
      'byRuleType': metadataBreakdown.byRuleType,
      'byRuleStatus': metadataBreakdown.byRuleStatus,
      'ruleSeverities': _lowercaseSeverities(data.ruleSeverities),
      'newCode': _buildNewCodeSummary(data, metadataBreakdown),
      'thresholds': _buildThresholdSummary(diagnosticStats.thresholds),
      'baselineDiff': _buildBaselineDiffSummary(diagnosticStats.baseline),
      // Suppression tracking: counts of diagnostics silenced by ignore
      // comments or baseline, broken down by kind, rule, and file.
      // Consumed by the extension Overview tree and available for CI.
      // Uses consolidated data from BatchData merge so multi-isolate
      // counts are accurate.
      'suppressions': _buildSuppressionSummary(data, projectRoot),
    };
  }

  static Map<String, Object> _buildThresholdSummary(
    ThresholdEvaluation thresholds,
  ) {
    final warnings = thresholds.warnings
        .map(
          (b) => <String, Object>{
            'rule': b.rule,
            'count': b.count,
            'threshold': b.threshold,
          },
        )
        .toList(growable: false);
    final failures = thresholds.failures
        .map(
          (b) => <String, Object>{
            'rule': b.rule,
            'count': b.count,
            'threshold': b.threshold,
          },
        )
        .toList(growable: false);

    return <String, Object>{
      'configured': DiagnosticStatisticsConfig.hasThresholds,
      'status': failures.isNotEmpty
          ? 'fail'
          : warnings.isNotEmpty
          ? 'warn'
          : 'pass',
      'warnings': warnings,
      'failures': failures,
    };
  }

  static Map<String, Object> _buildNewCodeSummary(
    ConsolidatedData data,
    _MetadataIssueBreakdown metadataBreakdown,
  ) {
    final baselineConfig = BaselineManager.config;
    final baselineDate = baselineConfig?.date;
    if (baselineDate == null) {
      return const <String, Object>{'configured': false, 'strategy': 'date'};
    }

    final hasAdditionalFilters =
        (baselineConfig?.file != null) ||
        (baselineConfig?.paths.isNotEmpty ?? false) ||
        (baselineConfig?.onlyImpacts.isNotEmpty ?? false);

    return <String, Object>{
      'configured': true,
      'strategy': 'date',
      'since': _formatDateOnly(baselineDate),
      // V1 scope: classify within reported diagnostics only; this keeps output
      // deterministic without introducing a second analysis pass.
      'countsSource': 'reportedViolations',
      'totalViolations': data.total,
      'byImpact': <String, int>{
        for (final impact in LintImpact.values)
          impact.name: data.impactCounts[impact] ?? 0,
      },
      'byRuleType': metadataBreakdown.byRuleType,
      'byRuleStatus': metadataBreakdown.byRuleStatus,
      if (hasAdditionalFilters)
        'note':
            'Additional baseline filters are active (file/paths/onlyImpacts); '
            'newCode metrics are still based on reported violations.',
    };
  }

  static String _formatDateOnly(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  static Map<String, Object> _buildBaselineDiffSummary(BaselineDiff baseline) {
    return <String, Object>{
      'enabled': baseline.enabled,
      if (baseline.baselinePath != null) 'baselinePath': baseline.baselinePath!,
      'baselineFound': baseline.baselineFound,
      'baselineTotalViolations': baseline.baselineTotal,
      'totalNewViolations': baseline.totalNewViolations,
      'newViolationsByRule': baseline.byRule,
    };
  }

  /// Build the suppressions summary from consolidated cross-isolate data.
  ///
  /// Includes total count, breakdown by kind (ignore / ignoreForFile /
  /// baseline), per-rule counts, and per-file counts with relativized paths.
  static Map<String, Object> _buildSuppressionSummary(
    ConsolidatedData data,
    String projectRoot,
  ) {
    final records = data.suppressions;

    // Counts by kind
    var ignoreCount = 0;
    var ignoreForFileCount = 0;
    var baselineCount = 0;
    final byRule = <String, int>{};
    final byFile = <String, int>{};

    for (final s in records) {
      switch (s.kind) {
        case SuppressionKind.ignore:
          ignoreCount++;
        case SuppressionKind.ignoreForFile:
          ignoreForFileCount++;
        case SuppressionKind.baseline:
          baselineCount++;
      }
      byRule[s.rule] = (byRule[s.rule] ?? 0) + 1;
      // File paths in consolidated records are already normalized to
      // project-relative form by _mergeSuppressions, but relativize
      // again for safety (idempotent).
      final relFile = toRelativePath(s.file, projectRoot);
      byFile[relFile] = (byFile[relFile] ?? 0) + 1;
    }

    return <String, Object>{
      'total': records.length,
      'byKind': <String, int>{
        'ignore': ignoreCount,
        'ignoreForFile': ignoreForFileCount,
        'baseline': baselineCount,
      },
      'byRule': byRule,
      'byFile': byFile,
    };
  }

  /// Lowercase all severity values for consistency with violation entries.
  static Map<String, String> _lowercaseSeverities(
    Map<String, String> severities,
  ) {
    return <String, String>{
      for (final entry in severities.entries)
        entry.key: entry.value.toLowerCase(),
    };
  }

  static _MetadataIssueBreakdown _buildIssueBreakdownByMetadata({
    required Map<String, int> issuesByRule,
    required Map<String, _RuleMetadataSnapshot> ruleMetadata,
  }) {
    final byRuleType = <String, int>{};
    final byRuleStatus = <String, int>{};

    for (final entry in issuesByRule.entries) {
      final count = entry.value;
      final metadata = ruleMetadata[entry.key];
      final ruleType = metadata?.ruleType ?? 'unspecified';
      final ruleStatus = metadata?.ruleStatus ?? 'ready';
      byRuleType[ruleType] = (byRuleType[ruleType] ?? 0) + count;
      byRuleStatus[ruleStatus] = (byRuleStatus[ruleStatus] ?? 0) + count;
    }

    return _MetadataIssueBreakdown(
      byRuleType: byRuleType,
      byRuleStatus: byRuleStatus,
    );
  }

  /// Relativize file path keys for cross-machine compatibility.
  static Map<String, int> _relativizeFileKeys(
    Map<String, int> issuesByFile,
    String projectRoot,
  ) {
    return <String, int>{
      for (final entry in issuesByFile.entries)
        toRelativePath(entry.key, projectRoot): entry.value,
    };
  }

  /// Build the sorted violations list.
  ///
  /// Ordering: impact (critical first) → file (alpha, case-insensitive)
  /// → line (ascending).
  static List<Map<String, Object>> _buildViolations({
    required String projectRoot,
    required Map<LintImpact, List<ViolationRecord>> violations,
    required Map<String, String> ruleSeverities,
    required Map<String, OwaspMapping> owaspLookup,
    required Map<String, _RuleMetadataSnapshot> ruleMetadata,
  }) {
    final result = <_SortableViolation>[];

    for (final impact in LintImpact.values) {
      final list = violations[impact];
      if (list == null) continue;

      for (final v in list) {
        final priority = ImportGraphTracker.getPriority(v.file, impact);
        result.add(
          _SortableViolation(
            record: v,
            impact: impact,
            relativePath: toRelativePath(v.file, projectRoot),
            severity: ruleSeverities[v.rule]?.toLowerCase() ?? 'info',
            owasp: owaspLookup[v.rule],
            metadata: ruleMetadata[v.rule],
            priority: priority,
          ),
        );
      }
    }

    result.sort(_compareViolations);

    return result.map(_violationToJson).toList();
  }

  /// Compare violations for sorting: FIX PRIORITY score (desc) → impact → file → line.
  static int _compareViolations(_SortableViolation a, _SortableViolation b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;

    final impactCmp = a.impact.index.compareTo(b.impact.index);
    if (impactCmp != 0) return impactCmp;

    final fileCmp = a.relativePath.toLowerCase().compareTo(
      b.relativePath.toLowerCase(),
    );
    if (fileCmp != 0) return fileCmp;

    return a.record.line.compareTo(b.record.line);
  }

  /// Convert a sortable violation to its JSON representation.
  static Map<String, Object> _violationToJson(_SortableViolation v) {
    return <String, Object>{
      'file': v.relativePath,
      'line': v.record.line,
      'rule': v.record.rule,
      'message': v.record.message,
      if (v.record.correction != null) 'correction': v.record.correction!,
      'severity': v.severity,
      'impact': v.impact.name,
      'priority': v.priority,
      'owasp': _owaspToJson(v.owasp),
      'metadata': _ruleMetadataToJson(v.metadata),
    };
  }

  /// Build the `ruleMetadataByRule` JSON map for an arbitrary rule set,
  /// independent of any analysis run.
  ///
  /// The live-analysis export ([_buildRuleMetadataLookup]) only snapshots the
  /// rules that were enabled or triggered. The VS Code extension needs the SAME
  /// per-rule metadata for EVERY rule up front — it enriches live analyzer
  /// diagnostics (which carry no metadata) so the Issues-panel rule-type/status
  /// filters and security-hotspot review work without first running an export.
  /// Routing both through `_RuleMetadataSnapshot` keeps the bundled catalog
  /// byte-identical to what an export would emit for the same rule, so the two
  /// data sources can never drift.
  static Map<String, Object?> buildRuleMetadataCatalog(
    Iterable<SaropaLintRule> rules,
  ) {
    final lookup = <String, _RuleMetadataSnapshot>{
      for (final rule in rules)
        rule.code.lowerCaseName: _RuleMetadataSnapshot.fromRule(rule),
    };
    return _ruleMetadataLookupToJson(lookup);
  }

  static Map<String, _RuleMetadataSnapshot> _buildRuleMetadataLookup({
    required ReportConfig? config,
    required Map<LintImpact, List<ViolationRecord>> violations,
  }) {
    final ruleNames = <String>{};
    if (config != null) {
      ruleNames.addAll(config.enabledRuleNames);
    }
    for (final entries in violations.values) {
      for (final violation in entries) {
        ruleNames.add(violation.rule);
      }
    }
    if (ruleNames.isEmpty) {
      return const <String, _RuleMetadataSnapshot>{};
    }

    final rules = getRulesFromRegistry(ruleNames);
    return <String, _RuleMetadataSnapshot>{
      for (final rule in rules)
        rule.code.lowerCaseName: _RuleMetadataSnapshot.fromRule(rule),
    };
  }

  static Map<String, Object?> _ruleMetadataLookupToJson(
    Map<String, _RuleMetadataSnapshot> metadata,
  ) {
    final sortedEntries = metadata.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return <String, Object?>{
      for (final entry in sortedEntries) entry.key: entry.value.toJson(),
    };
  }

  static Map<String, Object?> _ruleMetadataToJson(
    _RuleMetadataSnapshot? metadata,
  ) {
    if (metadata == null) {
      return const <String, Object?>{
        'ruleType': null,
        'ruleStatus': 'ready',
        'cweIds': <int>[],
        'certIds': <String>[],
        'tags': <String>[],
        'accuracyTarget': null,
      };
    }
    return metadata.toJson();
  }

  static Map<String, Object>? _accuracyTargetToJson(AccuracyTarget? target) {
    if (target == null) return null;
    return <String, Object>{
      'expectZeroFalsePositives': target.expectZeroFalsePositives,
      if (target.minTruePositiveRate != null)
        'minTruePositiveRate': target.minTruePositiveRate!,
      if (target.description != null) 'description': target.description!,
    };
  }

  /// Convert OWASP mapping to JSON with lowercase IDs.
  static Map<String, List<String>> _owaspToJson(OwaspMapping? mapping) {
    if (mapping == null || mapping.isEmpty) {
      return <String, List<String>>{'mobile': <String>[], 'web': <String>[]};
    }

    return <String, List<String>>{
      'mobile': mapping.mobile.map((m) => m.id.toLowerCase()).toList(),
      'web': mapping.web.map((w) => w.id.toLowerCase()).toList(),
    };
  }

  /// Write the file atomically: write to temp, delete old, rename.
  ///
  /// On Windows, `File.rename()` fails if the target exists, so we
  /// delete the target first. If any step fails, fall back to a
  /// direct write.
  static void _writeAtomic(String projectRoot, String content) {
    _writeAtomicFile(projectRoot, _fileName, content);
  }
}

/// Convert an absolute path to a relative forward-slash path.
///
/// Strips [projectRoot] prefix and normalizes all separators to `/`.
/// Used by both the markdown report and the structured JSON export.
String toRelativePath(String filePath, String projectRoot) {
  final root = projectRoot.replaceAll('\\', '/');
  final file = filePath.replaceAll('\\', '/');
  if (file.startsWith('$root/')) {
    return file.afterIndex(root.length + 1);
  }

  return file;
}

/// Internal holder for sorting violations before JSON serialization.
class _SortableViolation {
  const _SortableViolation({
    required this.record,
    required this.impact,
    required this.relativePath,
    required this.severity,
    required this.owasp,
    required this.metadata,
    required this.priority,
  });

  final ViolationRecord record;
  final LintImpact impact;
  final String relativePath;
  final String severity;
  final OwaspMapping? owasp;
  final _RuleMetadataSnapshot? metadata;

  /// Same combined score as report `FIX PRIORITY` ([ImportGraphTracker.getPriority]).
  final double priority;
}

class _RuleMetadataSnapshot {
  const _RuleMetadataSnapshot({
    required this.ruleType,
    required this.ruleStatus,
    required this.requiresReview,
    required this.defaultReviewState,
    required this.cweIds,
    required this.certIds,
    required this.tags,
    required this.accuracyTarget,
  });

  factory _RuleMetadataSnapshot.fromRule(SaropaLintRule rule) {
    final cwe = rule.cweIds.toList()..sort();
    final cert = rule.certIds.toList()..sort();
    final tags = normalizeRuleTags(rule.tags);
    final requiresReview =
        rule.ruleType == RuleType.securityHotspot ||
        tags.contains('review-required');
    return _RuleMetadataSnapshot(
      ruleType: rule.ruleType?.name,
      ruleStatus: rule.ruleStatus.name,
      requiresReview: requiresReview,
      defaultReviewState: requiresReview ? 'open' : null,
      cweIds: cwe,
      certIds: cert,
      tags: tags,
      accuracyTarget: ViolationExporter._accuracyTargetToJson(
        rule.accuracyTarget,
      ),
    );
  }

  final String? ruleType;
  final String ruleStatus;
  final bool requiresReview;
  final String? defaultReviewState;
  final List<int> cweIds;
  final List<String> certIds;
  final List<String> tags;
  final Map<String, Object?>? accuracyTarget;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ruleType': ruleType,
      'ruleStatus': ruleStatus,
      'requiresReview': requiresReview,
      'defaultReviewState': defaultReviewState,
      'cweIds': cweIds,
      'certIds': certIds,
      'tags': tags,
      'accuracyTarget': accuracyTarget,
    };
  }
}

class _MetadataIssueBreakdown {
  const _MetadataIssueBreakdown({
    required this.byRuleType,
    required this.byRuleStatus,
  });

  final Map<String, int> byRuleType;
  final Map<String, int> byRuleStatus;
}
