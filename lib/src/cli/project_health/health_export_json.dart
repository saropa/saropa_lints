/// Assembles the bounded Project Health summary report (JSON).
///
/// The summary holds only aggregates (totals, folder rollups, top-N files) —
/// per-file detail lives in the on-disk NDJSON shards, not here, so the summary
/// size is bounded by folder count, not file count. [schemaVersion] lets
/// downstream consumers (the webview, AI agents) pin the shape.
library;

import 'health_aggregator.dart';

/// Current health-report schema version. Bump on any breaking shape change.
const int healthSchemaVersion = 1;

/// Builds the summary report map from a populated [agg].
///
/// [sections] names which scanners contributed (e.g. `['size']`) so consumers
/// never mistake a partial scan for a complete one.
Map<String, Object?> buildHealthReport(
  HealthAggregator agg, {
  required String projectPath,
  required DateTime generatedAt,
  List<String> sections = const ['size'],
}) {
  return {
    'schemaVersion': healthSchemaVersion,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'projectPath': projectPath,
    'sections': sections,
    'totals': {
      'fileCount': agg.fileCount,
      'bytes': agg.totalBytes,
      'loc': agg.totalLoc,
      'codeLoc': agg.totalCodeLoc,
      'commentLoc': agg.totalCommentLoc,
      'blankLoc': agg.totalBlankLoc,
    },
    'folders': [for (final f in agg.folders()) f.toJson()],
    'topFiles': {
      'byLoc': [for (final f in agg.topByLoc()) f.toJson()],
      'byBytes': [for (final f in agg.topByBytes()) f.toJson()],
      // Refactoring-ROI: the prioritized "fix first" ranking.
      'byRoi': [for (final f in agg.topByRoi()) f.toJson()],
      if (sections.contains('complexity')) ...{
        'byCognitive': [for (final f in agg.topByCognitive()) f.toJson()],
        'worstMaintainability': [
          for (final f in agg.worstMaintainability()) f.toJson(),
        ],
      },
      if (sections.contains('deadweight'))
        'deadFiles': [for (final f in agg.deadFiles()) f.toJson()],
      if (sections.contains('git'))
        'byChurn': [for (final f in agg.topByChurn()) f.toJson()],
      if (sections.contains('coverage'))
        'lowestCoverage': [for (final f in agg.lowestCoverage()) f.toJson()],
    },
  };
}
