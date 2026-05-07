// Module overview (comment coverage pass).
// comment-coverage: module overview (batch).
//
// CLI helpers for saropa_lints command-line entrypoints and scans.
//
// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
// and tiers in `lib/src/tiers.dart` where applicable; see
// `plans/COMMENT_COVERAGE_PLAN.md`.

part of 'cross_file_html_reporter.dart';

String _htmlTrimLabel(String value) {
  if (value.length <= 10) return value;
  return '${value.split('').take(9).join()}~';
}

/// HTML table for the feature dependency matrix (same logic as text matrix in [CrossFileReporter]).
String _featureMatrixTableHtml(Map<String, List<String>> featureDeps) {
  final allFeatures = <String>{
    ...featureDeps.keys,
    for (final targets in featureDeps.values) ...targets,
  }.toList()..sort();
  if (allFeatures.isEmpty) {
    return '<p>None.</p>';
  }
  final th = allFeatures
      .map((f) => '<th scope="col">${_escape(_htmlTrimLabel(f))}</th>')
      .join();
  final rows = <String>[];
  for (final from in allFeatures) {
    final targets = featureDeps[from]?.toSet() ?? const <String>{};
    final cells = <String>[];
    for (final to in allFeatures) {
      if (from == to) {
        cells.add('<td>—</td>');
      } else {
        cells.add('<td>${targets.contains(to) ? 'X' : '·'}</td>');
      }
    }
    rows.add(
      '<tr><th scope="row">${_escape(_htmlTrimLabel(from))}</th>${cells.join()}</tr>',
    );
  }
  return '<table class="matrix" role="grid" aria-label="Feature dependency matrix"><thead><tr><th></th>$th</tr></thead><tbody>${rows.join()}</tbody></table><p class="summary">X = import from row feature to column feature. — = same feature.</p>';
}

String _buildFeatureDepsPage({
  required String headHtml,
  required Map<String, List<String>> featureDependencies,
  required List<String> crossFeatureImports,
}) {
  final adjacency = StringBuffer();
  final sortedFeatures = featureDependencies.keys.toList()..sort();
  var anyEdge = false;
  for (final feature in sortedFeatures) {
    final targets = featureDependencies[feature] ?? const <String>[];
    if (targets.isEmpty) continue;
    anyEdge = true;
    final targetHtml = targets
        .map((t) => '<code>${_escape(t)}</code>')
        .join(', ');
    adjacency.writeln(
      '<li><code>${_escape(feature)}</code> → $targetHtml</li>',
    );
  }
  final adjacencyBlock = anyEdge
      ? '<ul>${adjacency.toString()}</ul>'
      : '<p>None (no feature → feature edges; check <code>lib/features/</code> layout or <code>feature-deps</code> options).</p>';

  final crossBlock = crossFeatureImports.isEmpty
      ? '<p>None.</p>'
      : '<ul>${crossFeatureImports.map((e) => '<li><code>${_escape(e)}</code></li>').join()}</ul>';

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Feature dependencies</title>
$headHtml
</head>
<body>
  <h1>Feature dependencies</h1>
  <p><a href="index.html">Back to summary</a></p>
  <h2>Adjacency</h2>
  $adjacencyBlock
  <h2>Matrix (from → to)</h2>
  ${_featureMatrixTableHtml(featureDependencies)}
  <h2>Cross-feature import edges</h2>
  <p class="summary">Per-file import paths crossing feature directory boundaries.</p>
  $crossBlock
</body>
</html>
''';
}
