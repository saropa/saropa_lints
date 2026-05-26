/// Dead-weight overlay: composes the existing cross_file engine (unused files +
/// unused top-level symbols) into per-file signals keyed by project-relative
/// posix path, so the size map can be colored by deadness and dead files become
/// a hot-spot axis. Does NOT reimplement detection — reuses cross_file.
library;

import 'package:path/path.dart' as p;

import '../cross_file_analyzer.dart';
import '../cross_file_reporter.dart';

/// Per-file dead-weight signals for the whole project.
class DeadWeight {
  const DeadWeight({
    required this.unusedFiles,
    required this.deadSymbolCounts,
    this.cycles = const [],
  });

  /// Project-relative posix paths with no importers.
  final Set<String> unusedFiles;

  /// Project-relative posix path → count of unreferenced top-level symbols.
  final Map<String, int> deadSymbolCounts;

  /// Circular import cycles (each a list of ABSOLUTE file paths, as the import
  /// graph reports them — kept absolute so cut-suggestion can query fan-in).
  final List<List<String>> cycles;

  bool isUnused(String relPath) => unusedFiles.contains(relPath);
  int deadSymbolsFor(String relPath) => deadSymbolCounts[relPath] ?? 0;
}

/// Runs cross-file analysis under [projectPath]. Unused symbols are heavier
/// (semantic resolution), so they are opt-in via [includeSymbols].
Future<DeadWeight> loadDeadWeight({
  required String projectPath,
  List<String> excludeGlobs = const [],
  bool includeSymbols = false,
}) async {
  final result = await runCrossFileAnalysis(
    projectPath: projectPath,
    excludeGlobs: excludeGlobs,
    unusedSymbolsOptions: includeSymbols ? const UnusedSymbolsOptions() : null,
  );

  final unused = <String>{
    for (final abs in result.unusedFiles) _toRel(abs, projectPath),
  };
  final counts = <String, int>{
    for (final entry in result.unusedSymbols.entries)
      _toRel(entry.key, projectPath): entry.value.length,
  };
  return DeadWeight(
    unusedFiles: unused,
    deadSymbolCounts: counts,
    cycles: result.circularDependencies,
  );
}

String _toRel(String path, String projectPath) {
  final normalized = path.replaceAll('\\', '/');
  if (p.isAbsolute(normalized)) {
    return p.relative(normalized, from: projectPath).replaceAll('\\', '/');
  }
  return normalized;
}
