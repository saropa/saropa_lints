import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/project_context.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Cross-file helpers for the saropa_lints CLI when scanning a consumer project.
///
/// Covers: directed edges between feature folders under `lib/features/`,
/// conservative `lib` → `test` mirror coverage checks, and glob patterns for
/// path filters. These utilities intentionally avoid full package resolution;
/// they operate on normalized paths and data from [ImportGraphCache].
///
/// Aggregated feature-to-feature dependency graph for a single project scan.
///
/// [featureDependencies] maps a feature folder name (first segment after
/// `lib/features/`) to distinct other features it imports across the scan set.
/// [crossFeatureImports] lists human-readable `importer -> imported` edges using
/// project-relative paths for diagnostics and summaries.
class FeatureDepsResult {
  const FeatureDepsResult({
    required this.featureDependencies,
    required this.crossFeatureImports,
  });

  /// Sorted map: feature name → sorted list of depended-on feature names.
  final Map<String, List<String>> featureDependencies;

  /// Sorted list of `relativeImporter -> relativeImported` cross-feature edges.
  final List<String> crossFeatureImports;
}

/// Builds a cross-feature import graph for paths under `lib/features/<name>/`.
///
/// [projectPath] is normalized to POSIX-style separators internally so feature
/// detection is stable on Windows hosts. Only imports where both endpoints are
/// in [includedPaths] contribute; same-feature imports and imports outside
/// `lib/features/` are ignored. Output collections are sorted for stable diffs.
FeatureDepsResult analyzeFeatureDependencies({
  required String projectPath,
  required Set<String> includedPaths,
}) {
  final root = p.normalize(projectPath).replaceAll('\\', '/');
  // Directed edges: fromFeature → set(toFeature); sets dedupe parallel imports.
  final featureDeps = <String, Set<String>>{};
  // One string per cross-feature edge for CLI reporting.
  final crossImports = <String>{};

  /// Returns the first path segment under `lib/features/` or null if absent.
  String? featureNameFor(String absolutePath) {
    final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
    final marker = '$root/lib/features/';
    if (!normalized.startsWith(marker)) return null;
    final rest = normalized.afterIndex(marker.length);
    final parts = rest.split('/');
    if (parts.isEmpty) return null;
    final feature = parts.first.trim();
    return feature.isEmpty ? null : feature;
  }

  /// Strips [root] prefix when present; otherwise returns a normalized path.
  String toRelative(String absolutePath) {
    final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
    if (!normalized.startsWith(root)) return normalized;
    return normalized.afterIndex(root.length).replaceFirst(RegExp('^/'), '');
  }

  // Outer: every scanned file that lives inside a feature folder.
  for (final importer in includedPaths) {
    final fromFeature = featureNameFor(importer);
    if (fromFeature == null) continue;
    final imports = ImportGraphCache.getImports(importer);
    // Inner: resolved import targets that are also in the active scan set.
    for (final imported in imports) {
      if (!includedPaths.contains(imported)) continue;
      final toFeature = featureNameFor(imported);
      // Skip non-feature targets and intra-feature imports (allowed by design).
      if (toFeature == null || toFeature == fromFeature) continue;
      featureDeps.putIfAbsent(fromFeature, () => <String>{}).add(toFeature);
      crossImports.add('${toRelative(importer)} -> ${toRelative(imported)}');
    }
  }

  // Materialize stable, sorted structures for deterministic CLI output.
  final sortedMap = <String, List<String>>{};
  final keys = featureDeps.keys.toList()..sort();
  for (final key in keys) {
    final targets = featureDeps[key]!.toList()..sort();
    sortedMap[key] = targets;
  }

  final sortedEdges = crossImports.toList()..sort();
  return FeatureDepsResult(
    featureDependencies: sortedMap,
    crossFeatureImports: sortedEdges,
  );
}

/// Each entry is a `lib/.../*.dart` file with no matching `test/.../*_test.dart`
/// (same relative path under [projectPath], `_test` before `.dart`).
///
/// Skips `main.dart`, generated-style names (`.g.dart`, etc.), and paths under
/// `lib/generated/` — a conservative 1:1 `lib` → `test` mirror convention.
List<String> libSourcesMissingMirrorTests({
  required String projectPath,
  required Set<String> pathsToScan,
}) {
  final root = p.normalize(projectPath);
  final rootPosix = root.replaceAll('\\', '/');
  final missing = <String>[];

  for (final absolute in pathsToScan) {
    if (!absolute.endsWith('.dart')) continue;
    final absPosix = p.normalize(absolute).replaceAll('\\', '/');
    final libPrefix = '$rootPosix/lib/';
    if (!absPosix.startsWith(libPrefix)) continue;

    final afterLib = absPosix.afterPrefix(libPrefix);
    if (afterLib.isEmpty) continue;
    final lower = afterLib.toLowerCase();
    if (lower.endsWith('.g.dart') ||
        lower.endsWith('.freezed.dart') ||
        lower.endsWith('.gr.dart')) {
      continue;
    }
    if (lower.contains('/generated/')) continue;
    if (afterLib == 'main.dart') continue;

    final expectedSuffix =
        '${afterLib.slice(0, afterLib.length - 5)}_test.dart';
    // Mirror path convention: lib/foo/bar.dart -> test/foo/bar_test.dart
    final expectedPosix = '$rootPosix/test/$expectedSuffix';
    final expectedPath = expectedPosix.replaceAll('/', p.separator);
    if (!File(expectedPath).existsSync()) {
      missing.add(absolute);
    }
  }
  missing.sort();
  return missing;
}

/// Converts a simple glob pattern to a [RegExp].
///
/// Supports `*` (any non-separator chars), `**` (any chars including `/`),
/// and `?` (single char). All other regex-special characters are escaped.
RegExp globToRegExp(String glob) {
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
  // Full-string anchor prevents partial-path accidental matches.
  buf.write(r'$');
  return RegExp(buf.toString());
}
