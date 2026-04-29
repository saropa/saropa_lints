import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

/// JSON snapshot format version written by `cross_file snapshot` and read by
/// [ProjectContext.crossFileSnapshotForPath] (see `project_context_cross_file.dart`).
const crossFileSnapshotFormatVersion = 1;

/// Writes [result] to [outputPath] (parent dirs created). Intended path:
/// `reports/.saropa_lints/cross_file_snapshot.json` under the project root.
void writeCrossFileSnapshot({
  required CrossFileResult result,
  required String outputPath,
  required String projectPath,
}) {
  final map = <String, dynamic>{
    'version': crossFileSnapshotFormatVersion,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'projectPath': p.normalize(projectPath).replaceAll('\\', '/'),
    'unusedFiles': result.unusedFiles,
    'circularDependencies': result.circularDependencies,
    'missingMirrorTests': result.missingMirrorTests,
    'featureDependencies': result.featureDependencies,
    'crossFeatureImports': result.crossFeatureImports,
    'deadImports': result.deadImports,
    'unusedSymbols': result.unusedSymbols,
    if (result.stats.isNotEmpty) 'stats': result.stats,
  };
  final file = File(outputPath);
  final parent = file.parent;
  if (!parent.existsSync()) {
    parent.createSync(recursive: true);
  }
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(map));
}
