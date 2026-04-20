import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:saropa_lints/src/project_context.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Runs cross-file analysis: builds import graph and returns unused files,
/// circular dependencies, and stats.
///
/// [excludeGlobs] filters out matching paths from results. Glob patterns
/// are matched against paths relative to [projectPath] (e.g. `**/*.g.dart`).
Future<CrossFileResult> runCrossFileAnalysis({
  required String projectPath,
  List<String> excludeGlobs = const [],
}) async {
  await ImportGraphCache.buildFromDirectory(projectPath);

  final allPaths = ImportGraphCache.getFilePaths();

  // Build compiled glob matchers once, then reuse for every path.
  final excludeRegExps = excludeGlobs
      .map(_globToRegExp)
      .toList(growable: false);

  // Helper: true if [filePath] matches any --exclude pattern.
  bool isExcluded(String filePath) {
    if (excludeRegExps.isEmpty) return false;
    // Match against the path relative to projectPath so that globs
    // like "lib/generated/**" work as expected.
    final normalized = filePath.replaceAll('\\', '/');
    final root = projectPath.replaceAll('\\', '/');
    final relative = normalized.startsWith(root)
        ? normalized.afterIndex(root.length).replaceFirst(RegExp('^/'), '')
        : p.basename(normalized);
    return excludeRegExps.any((re) => re.hasMatch(relative));
  }

  // Compute the set of included paths once so callers (e.g. graph command)
  // can reuse the same filter without re-implementing glob logic.
  final includedPaths = <String>{};
  for (final path in allPaths) {
    if (!isExcluded(path)) includedPaths.add(path);
  }

  final unusedFiles = <String>[];
  for (final path in includedPaths) {
    final importers = ImportGraphCache.getImporters(path);
    if (importers.isEmpty) {
      unusedFiles.add(path);
    }
  }
  unusedFiles.sort();

  final seenCycles = <String>{};
  final circularDependencies = <List<String>>[];
  for (final path in includedPaths) {
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
    // Only populate when excludes are active; empty signals "use full graph".
    includedPaths: excludeGlobs.isEmpty ? const {} : includedPaths,
  );
}

/// Converts a simple glob pattern to a [RegExp].
///
/// Supports `*` (any non-separator chars), `**` (any chars including `/`),
/// and `?` (single char). All other regex-special characters are escaped.
RegExp _globToRegExp(String glob) {
  final buf = StringBuffer('^');
  for (var i = 0; i < glob.length; i++) {
    final ch = glob[i];
    if (ch == '*') {
      // Check for **
      if (i + 1 < glob.length && glob[i + 1] == '*') {
        // ** matches everything including path separators
        buf.write('.*');
        i++; // skip second *
        // Skip trailing slash after ** (e.g. **/)
        if (i + 1 < glob.length && glob[i + 1] == '/') i++;
      } else {
        // * matches everything except /
        buf.write('[^/]*');
      }
    } else if (ch == '?') {
      buf.write('[^/]');
    } else if (r'\.+^${}()|[]'.contains(ch)) {
      // Escape regex-special character
      buf.write('\\$ch');
    } else {
      buf.write(ch);
    }
  }
  buf.write(r'$');
  return RegExp(buf.toString());
}
