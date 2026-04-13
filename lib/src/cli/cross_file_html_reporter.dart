import 'dart:io';

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

/// Writes cross-file analysis results as self-contained HTML under [outputDir].
void reportToHtml(CrossFileResult result, String outputDir) {
  final dir = Directory(outputDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final u = result.unusedFiles;
  final c = result.circularDependencies;
  final fileCount = result.stats['fileCount'] as int? ?? 0;
  final totalImports = result.stats['totalImports'] as int? ?? 0;

  File('$outputDir/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Cross-file analysis report</title>
  <style>
    body { font-family: system-ui, sans-serif; margin: 1rem 2rem; }
    h1 { margin-bottom: 0.5rem; }
    .summary { color: #666; margin-bottom: 1.5rem; }
    ul { line-height: 1.6; }
    a { color: #0066cc; }
    code { background: #f0f0f0; padding: 0.1em 0.3em; border-radius: 3px; }
  </style>
</head>
<body>
  <h1>Cross-file analysis report</h1>
  <p class="summary">Unused files: ${u.length} | Circular dependencies: ${c.length} | Files: $fileCount | Total imports: $totalImports</p>
  <ul>
    <li><a href="unused-files.html">Unused files (${u.length})</a></li>
    <li><a href="circular-deps.html">Circular dependencies (${c.length})</a></li>
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
  <style>
    body { font-family: system-ui, sans-serif; margin: 1rem 2rem; }
    a { color: #0066cc; }
    code { background: #f0f0f0; padding: 0.1em 0.3em; border-radius: 3px; }
    ul { line-height: 1.6; }
  </style>
</head>
<body>
  <h1>Unused files</h1>
  <p><a href="index.html">Back to summary</a></p>
  $unusedRows
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
  <style>
    body { font-family: system-ui, sans-serif; margin: 1rem 2rem; }
    a { color: #0066cc; }
    code { background: #f0f0f0; padding: 0.1em 0.3em; border-radius: 3px; }
    ul { line-height: 1.6; }
  </style>
</head>
<body>
  <h1>Circular dependencies</h1>
  <p><a href="index.html">Back to summary</a></p>
  $cycleRows
</body>
</html>
''');
}

String _escape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
