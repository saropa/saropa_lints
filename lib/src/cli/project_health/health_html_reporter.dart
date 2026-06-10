/// Generates a self-contained interactive HTML report for the Saropa Project Map
/// dashboard: a size treemap, a churn×complexity scatter (the signature view),
/// and a 🔥 hot-spot table. Data is embedded as JSON; charts use Apache ECharts.
///
/// The standalone CLI report loads ECharts from a CDN (open it in a browser).
/// The extension webview must instead vendor the ECharts script for offline use
/// — that swap happens in the extension integration, not here.
library;

import 'dart:convert';

import 'folder_tree.dart';
import 'health_aggregator.dart';
import 'health_html_template.dart';
import 'hotspot_ranking.dart';
import 'perf_gravity.dart';

/// Builds the full HTML document string from a populated [agg] and ranked [spots].
///
/// [featureGravity] is the per-feature performance rollup (empty unless the
/// `--performance` section ran); when non-empty the document renders a
/// "Performance gravity" panel.
String buildHealthHtml(
  HealthAggregator agg,
  List<Hotspot> spots, {
  required String projectPath,
  required DateTime generatedAt,
  List<FeatureGravity> featureGravity = const [],
}) {
  final data = <String, Object?>{
    'projectPath': projectPath,
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'totals': {
      'fileCount': agg.fileCount,
      'loc': agg.totalLoc,
      'bytes': agg.totalBytes,
      'deadFiles': agg.deadFileCount,
      'hotspots': spots.where((s) => s.fire > 0).length,
    },
    // Hierarchical folder tree — ECharts treemap drills down by folder.
    'folderTree': buildFolderTree(agg.folders()),
    'scatter': [
      for (final f in agg.topByCognitive().take(120))
        if (f.churn != null)
          {
            'name': f.path,
            'churn': f.churn,
            'cognitive': f.complexity?.maxCognitive ?? 0,
            'loc': f.loc,
          },
    ],
    'hotspots': [
      for (final s in spots.take(50))
        {
          'path': s.file.path,
          'fire': s.fire,
          'loc': s.file.loc,
          'cognitive': s.file.complexity?.maxCognitive,
          'mi': s.file.maintainability,
          'churn': s.file.churn,
          'reasons': s.reasons,
        },
    ],
    // Per-feature performance gravity (empty array → panel hides itself).
    'featureGravity': [for (final f in featureGravity) f.toJson()],
  };
  return renderHealthDocument(jsonEncode(data));
}
