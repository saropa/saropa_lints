import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:saropa_lints/src/project_context.dart';

/// Runs cross-file analysis: builds import graph and returns unused files,
/// circular dependencies, and stats.
///
/// [excludeGlobs] is accepted for API consistency but not yet applied;
/// the import graph currently includes all Dart files under lib/.
Future<CrossFileResult> runCrossFileAnalysis({
  required String projectPath,
  List<String> excludeGlobs = const [],
}) async {
  await ImportGraphCache.buildFromDirectory(projectPath);

  final allPaths = ImportGraphCache.getFilePaths();
  final unusedFiles = <String>[];
  for (final path in allPaths) {
    final importers = ImportGraphCache.getImporters(path);
    if (importers.isEmpty) {
      unusedFiles.add(path);
    }
  }
  unusedFiles.sort();

  final seenCycles = <String>{};
  final circularDependencies = <List<String>>[];
  for (final path in allPaths) {
    final cycles = ImportGraphCache.detectCircularImports(path);
    for (final cycle in cycles) {
      final key = cycle.join('|');
      if (seenCycles.add(key)) {
        circularDependencies.add(cycle);
      }
    }
  }

  final stats = ImportGraphCache.getStats();
  return CrossFileResult(
    unusedFiles: unusedFiles,
    circularDependencies: circularDependencies,
    stats: stats,
  );
}
