import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/project_context.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

class FeatureDepsResult {
  const FeatureDepsResult({
    required this.featureDependencies,
    required this.crossFeatureImports,
  });

  final Map<String, List<String>> featureDependencies;
  final List<String> crossFeatureImports;
}

FeatureDepsResult analyzeFeatureDependencies({
  required String projectPath,
  required Set<String> includedPaths,
}) {
  final root = p.normalize(projectPath).replaceAll('\\', '/');
  final featureDeps = <String, Set<String>>{};
  final crossImports = <String>{};

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

  String toRelative(String absolutePath) {
    final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
    if (!normalized.startsWith(root)) return normalized;
    return normalized.afterIndex(root.length).replaceFirst(RegExp('^/'), '');
  }

  for (final importer in includedPaths) {
    final fromFeature = featureNameFor(importer);
    if (fromFeature == null) continue;
    final imports = ImportGraphCache.getImports(importer);
    for (final imported in imports) {
      if (!includedPaths.contains(imported)) continue;
      final toFeature = featureNameFor(imported);
      if (toFeature == null || toFeature == fromFeature) continue;
      featureDeps.putIfAbsent(fromFeature, () => <String>{}).add(toFeature);
      crossImports.add('${toRelative(importer)} -> ${toRelative(imported)}');
    }
  }

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
