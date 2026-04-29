import 'dart:io';

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

part 'cross_file_html_reporter_part.dart';

/// CSS file written next to the HTML pages (light + dark via `prefers-color-scheme`).
String _reportCssContent() {
  return r'''
:root {
  --bg: #fff;
  --fg: #111;
  --muted: #666;
  --link: #0066cc;
  --code-bg: #f0f0f0;
  --border: #ccc;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #1a1a1a;
    --fg: #e8e8e8;
    --muted: #a0a0a0;
    --link: #6bb3ff;
    --code-bg: #2d2d2d;
    --border: #444;
  }
}
body { font-family: system-ui, sans-serif; margin: 1rem 2rem; background: var(--bg); color: var(--fg); }
h1 { margin-bottom: 0.5rem; }
h2 { font-size: 1.1rem; margin-top: 1.25rem; }
.summary { color: var(--muted); margin-bottom: 1.5rem; }
ul { line-height: 1.6; }
a { color: var(--link); }
code { background: var(--code-bg); padding: 0.1em 0.3em; border-radius: 3px; }
table.matrix { border-collapse: collapse; margin: 1rem 0; font-size: 0.9rem; }
table.matrix th, table.matrix td { border: 1px solid var(--border); padding: 0.25em 0.4em; text-align: center; }
table.matrix th { background: var(--code-bg); }
table.matrix th[scope=row] { text-align: left; }
''';
}

const _stylesheetLink = '  <link rel="stylesheet" href="report.css">';

/// Writes `report.css` and HTML under [outputDir] (index, section pages, and
/// `feature-deps.html` from the part file).
void reportToHtml(CrossFileResult result, String outputDir) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final u = result.unusedFiles;
  final c = result.circularDependencies;
  final m = result.missingMirrorTests;
  final fileCount = result.stats['fileCount'] as int? ?? 0;
  final totalImports = result.stats['totalImports'] as int? ?? 0;
  final featureDeps = result.featureDependencies;
  final crossFeature = result.crossFeatureImports;
  final featureCount = featureDeps.length;
  final crossCount = crossFeature.length;

  File('$outputDir/report.css').writeAsStringSync(_reportCssContent());

  File('$outputDir/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Cross-file analysis report</title>
$_stylesheetLink
</head>
<body>
  <h1>Cross-file analysis report</h1>
  <p class="summary">Unused files: ${u.length} | Missing mirror tests: ${m.length} | Circular dependencies: ${c.length} | Feature entries: $featureCount | Cross-feature imports: $crossCount | Files: $fileCount | Total imports: $totalImports</p>
  <ul>
    <li><a href="unused-files.html">Unused files (${u.length})</a></li>
    <li><a href="missing-mirror-tests.html">Lib sources without mirror test (${m.length})</a></li>
    <li><a href="circular-deps.html">Circular dependencies (${c.length})</a></li>
    <li><a href="feature-deps.html">Feature dependencies ($featureCount features, $crossCount cross-feature import(s))</a></li>
  </ul>
</body>
</html>
''');

  final unusedRows = u.isEmpty
      ? '<p>None.</p>'
      : '<ul>${u.map((f) => '<li><code>${_escape(f)}</code></li>').join()}</ul>';
  File('$outputDir/unused-files.html').writeAsStringSync('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Unused files</title>
$_stylesheetLink
</head>
<body>
  <h1>Unused files</h1>
  <p><a href="index.html">Back to summary</a></p>
  $unusedRows
</body>
</html>
''');

  final missingRows = m.isEmpty
      ? '<p>None.</p>'
      : '<ul>${m.map((f) => '<li><code>${_escape(f)}</code></li>').join()}</ul>';
  File('$outputDir/missing-mirror-tests.html').writeAsStringSync('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lib sources without mirror test</title>
$_stylesheetLink
</head>
<body>
  <h1>Lib sources without mirror test</h1>
  <p>Expected <code>lib/foo.dart</code> → <code>test/foo_test.dart</code> (same relative path).</p>
  <p><a href="index.html">Back to summary</a></p>
  $missingRows
</body>
</html>
''');

  final cycleRows = c.isEmpty
      ? '<p>None.</p>'
      : '<ul>${c.map((cycle) => '<li><code>${cycle.map(_escape).join(' → ')}</code></li>').join()}</ul>';
  File('$outputDir/circular-deps.html').writeAsStringSync('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Circular dependencies</title>
$_stylesheetLink
</head>
<body>
  <h1>Circular dependencies</h1>
  <p><a href="index.html">Back to summary</a></p>
  $cycleRows
</body>
</html>
''');

  final featurePage = _buildFeatureDepsPage(
    headHtml: _stylesheetLink,
    featureDependencies: featureDeps,
    crossFeatureImports: crossFeature,
  );
  File('$outputDir/feature-deps.html').writeAsStringSync(featurePage);
}

String _escape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
