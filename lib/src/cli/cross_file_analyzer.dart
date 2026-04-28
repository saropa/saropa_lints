import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/cli/cross_file_reporter.dart';
import 'package:saropa_lints/src/cli/cross_file_unused_symbols_semantic.dart';
import 'package:saropa_lints/src/project_context.dart';
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Runs cross-file analysis: builds import graph and returns unused files,
/// circular dependencies, [missingMirrorTests], and stats.
///
/// [excludeGlobs] filters out matching paths from results. Glob patterns
/// are matched against paths relative to [projectPath] (e.g. `**/*.g.dart`).
Future<CrossFileResult> runCrossFileAnalysis({
  required String projectPath,
  List<String> excludeGlobs = const [],
  UnusedSymbolsOptions? unusedSymbolsOptions,
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

  final pathsToScan = excludeGlobs.isEmpty ? allPaths.toSet() : includedPaths;
  final missingMirrorTests = _libSourcesMissingMirrorTests(
    projectPath: projectPath,
    pathsToScan: pathsToScan,
  );

  final stats = ImportGraphCache.getStats();
  final featureResult = _analyzeFeatureDependencies(
    projectPath: projectPath,
    includedPaths: includedPaths,
  );
  final deadImports = _analyzeDeadImports(
    projectPath: projectPath,
    includedPaths: includedPaths,
  );
  final unusedSymbols = unusedSymbolsOptions == null
      ? const <String, List<String>>{}
      : await _unusedSymbolsForOptions(
          projectPath: projectPath,
          includedPaths: includedPaths,
          options: unusedSymbolsOptions,
        );
  return CrossFileResult(
    unusedFiles: unusedFiles,
    circularDependencies: circularDependencies,
    missingMirrorTests: missingMirrorTests,
    stats: stats,
    featureDependencies: featureResult.featureDependencies,
    crossFeatureImports: featureResult.crossFeatureImports,
    deadImports: deadImports,
    unusedSymbols: unusedSymbols,
    // Only populate when excludes are active; empty signals "use full graph".
    includedPaths: excludeGlobs.isEmpty ? const {} : includedPaths,
  );
}

Future<Map<String, List<String>>> _unusedSymbolsForOptions({
  required String projectPath,
  required Set<String> includedPaths,
  required UnusedSymbolsOptions options,
}) async {
  if (options.forceHeuristic) {
    return _analyzeUnusedTopLevelSymbolsHeuristic(
      projectPath: projectPath,
      includedPaths: includedPaths,
      options: options,
    );
  }
  try {
    return await analyzeUnusedTopLevelSymbolsSemantic(
      projectPath: projectPath,
      includedPaths: includedPaths,
      options: options,
    );
  } on Object catch (e) {
    stderr.writeln(
      'unused-symbols: semantic analysis failed, using heuristic. $e',
    );
    return _analyzeUnusedTopLevelSymbolsHeuristic(
      projectPath: projectPath,
      includedPaths: includedPaths,
      options: options,
    );
  }
}

Map<String, List<String>> _analyzeDeadImports({
  required String projectPath,
  required Set<String> includedPaths,
}) {
  final root = p.normalize(projectPath).replaceAll('\\', '/');
  final result = <String, List<String>>{};
  final exportNameResolver = _LocalExportNameResolver(includedPaths: includedPaths);

  final dartFiles = includedPaths.where((path) => path.endsWith('.dart'));
  final importPattern = RegExp(
    r'''^\s*import\s+['"]([^'"]+)['"]\s*([^;]*);''',
    multiLine: true,
  );

  for (final filePath in dartFiles) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    final usageContent = content.replaceAll(
      RegExp(r'^\s*import\s+[^;]+;\s*', multiLine: true),
      '',
    );
    final deadForFile = <String>[];

    for (final match in importPattern.allMatches(content)) {
      final uri = match.group(1);
      final tail = match.group(2) ?? '';
      if (uri == null) continue;
      if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;

      final importedPath = p.normalize(p.join(p.dirname(filePath), uri)).replaceAll('\\', '/');
      if (!includedPaths.contains(importedPath)) continue;
      final importedFile = File(importedPath);
      if (!importedFile.existsSync()) continue;

      final importSpec = _parseImportTail(tail);
      final exportedNames = _collectTopLevelExportedNamesWithLocalReexports(
        filePath: importedPath,
        resolver: exportNameResolver,
      );
      if (exportedNames.isEmpty) continue;
      final visibleNames = _applyImportCombinators(
        exportedNames: exportedNames,
        shownNames: importSpec.shownNames,
        hiddenNames: importSpec.hiddenNames,
      );
      if (visibleNames.isEmpty) {
        deadForFile.add(uri);
        continue;
      }

      var used = false;
      if (importSpec.isDeferred && importSpec.alias != null) {
        final deferredLoadPattern = RegExp(
          '\\b${RegExp.escape(importSpec.alias!)}\\s*\\.\\s*loadLibrary\\s*\\(',
        );
        if (deferredLoadPattern.hasMatch(usageContent)) {
          used = true;
        }
      }
      for (final name in visibleNames) {
        if (used) break;
        final token = importSpec.alias == null
            ? RegExp('\\b${RegExp.escape(name)}\\b')
            : RegExp(
                '\\b${RegExp.escape(importSpec.alias!)}\\s*\\.\\s*${RegExp.escape(name)}\\b',
              );
        // Heuristic: if identifier appears in importer in the expected form,
        // treat the import as used.
        if (token.hasMatch(usageContent)) {
          used = true;
          break;
        }
      }
      if (!used) deadForFile.add(uri);
    }

    if (deadForFile.isNotEmpty) {
      deadForFile.sort();
      result[_relativePath(root, filePath)] = deadForFile;
    }
  }

  return result;
}

Set<String> _collectTopLevelExportedNamesWithLocalReexports({
  required String filePath,
  required _LocalExportNameResolver resolver,
}) {
  return resolver.collect(filePath);
}

class _LocalExportNameResolver {
  _LocalExportNameResolver({required this.includedPaths});

  final Set<String> includedPaths;
  final Map<String, Set<String>> _cache = <String, Set<String>>{};

  Set<String> collect(String filePath, {Set<String>? visiting}) {
    final cached = _cache[filePath];
    if (cached != null) return cached;
    final seen = <String>{...?visiting};
    if (!seen.add(filePath)) return const <String>{};

    final file = File(filePath);
    if (!file.existsSync()) {
      seen.remove(filePath);
      return const <String>{};
    }
    final content = file.readAsStringSync();
    final names = _collectTopLevelExportedNames(content);

    final exportPattern = RegExp(r'''^\s*export\s+['"]([^'"]+)['"]''', multiLine: true);
    for (final match in exportPattern.allMatches(content)) {
      final uri = match.group(1);
      if (uri == null) continue;
      if (uri.startsWith('dart:') || uri.startsWith('package:')) continue;
      final target = p.normalize(p.join(p.dirname(filePath), uri)).replaceAll('\\', '/');
      if (!includedPaths.contains(target)) continue;
      names.addAll(collect(target, visiting: seen));
    }

    seen.remove(filePath);
    _cache[filePath] = names;
    return names;
  }
}

Set<String> _applyImportCombinators({
  required Set<String> exportedNames,
  required Set<String> shownNames,
  required Set<String> hiddenNames,
}) {
  final result = shownNames.isEmpty
      ? <String>{...exportedNames}
      : exportedNames.where(shownNames.contains).toSet();
  result.removeAll(hiddenNames);
  return result;
}

_ImportTailSpec _parseImportTail(String tail) {
  String? alias;
  final shown = <String>{};
  final hidden = <String>{};
  final isDeferred = RegExp(r'\bdeferred\b').hasMatch(tail);

  final asMatch = RegExp(r'\bas\s+([A-Za-z_]\w*)\b').firstMatch(tail);
  if (asMatch != null) {
    alias = asMatch.group(1);
  }

  void collect(String keyword, Set<String> target) {
    final pattern = StringBuffer()
      ..write(r'\b')
      ..write(RegExp.escape(keyword))
      ..write(r'\s+([^;]+?)(?=\b(?:show|hide|as)\b|$)');
    final match = RegExp(
      pattern.toString(),
    ).firstMatch(tail);
    if (match == null) return;
    final raw = match.group(1);
    if (raw == null) return;
    final tokens = raw.split(',');
    for (final token in tokens) {
      final name = token.trim();
      if (name.isEmpty) continue;
      if (RegExp(r'^[A-Za-z_]\w*$').hasMatch(name)) {
        target.add(name);
      }
    }
  }

  collect('show', shown);
  collect('hide', hidden);
  return _ImportTailSpec(
    alias: alias,
    shownNames: shown,
    hiddenNames: hidden,
    isDeferred: isDeferred,
  );
}

class _ImportTailSpec {
  const _ImportTailSpec({
    required this.alias,
    required this.shownNames,
    required this.hiddenNames,
    required this.isDeferred,
  });

  final String? alias;
  final Set<String> shownNames;
  final Set<String> hiddenNames;
  final bool isDeferred;
}

Set<String> _collectTopLevelExportedNames(String content) {
  final names = <String>{};
  final classLike = RegExp(
    r'^\s*(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_]\w*)',
    multiLine: true,
  );
  final funcLike = RegExp(
    r'^\s*(?:[A-Za-z_<>\?\[\],\s]+\s+)?([A-Za-z_]\w*)\s*\([^;\n]*\)\s*(?:\{|=>)',
    multiLine: true,
  );
  final varLike = RegExp(
    r'^\s*(?:final|const|var|[A-Za-z_<>\?\[\],\s]+)\s+([A-Za-z_]\w*)\s*=',
    multiLine: true,
  );

  for (final m in classLike.allMatches(content)) {
    final name = m.group(1);
    if (name != null && !name.startsWith('_')) names.add(name);
  }
  for (final m in funcLike.allMatches(content)) {
    final name = m.group(1);
    if (name == null) continue;
    if (name.startsWith('_')) continue;
    if (name == 'main' || name == 'if' || name == 'for' || name == 'while' || name == 'switch') {
      continue;
    }
    names.add(name);
  }
  for (final m in varLike.allMatches(content)) {
    final name = m.group(1);
    if (name != null && !name.startsWith('_')) names.add(name);
  }
  return names;
}

Map<String, List<String>> _analyzeUnusedTopLevelSymbolsHeuristic({
  required String projectPath,
  required Set<String> includedPaths,
  required UnusedSymbolsOptions options,
}) {
  final root = p.normalize(projectPath).replaceAll('\\', '/');
  final symbolsByFile = <String, List<String>>{};
  final fileContents = <String, String>{};
  final exportedLibFiles = <String>{};

  final candidateFiles = includedPaths.where((path) => path.endsWith('.dart'));
  for (final filePath in candidateFiles) {
    final file = File(filePath);
    if (!file.existsSync()) continue;
    final content = file.readAsStringSync();
    fileContents[filePath] = content;

    final rel = _relativePath(root, filePath);
    if (rel.startsWith('lib/') && !_isGeneratedDart(rel)) {
      _collectTopLevelSymbols(
        content: content,
        includePrivate: options.includePrivate,
        into: symbolsByFile.putIfAbsent(filePath, () => <String>[]),
      );
      if (content.contains(RegExp(r'^\s*export\s+', multiLine: true))) {
        exportedLibFiles.add(filePath);
      }
    }
  }

  if (symbolsByFile.isEmpty) return const <String, List<String>>{};

  final exportsByFile = <String, Set<String>>{};
  for (final filePath in symbolsByFile.keys) {
    final content = fileContents[filePath] ?? '';
    final exports = <String>{};
    for (final m in RegExp(r'''export\s+['"]([^'"]+)['"]''').allMatches(content)) {
      final raw = m.group(1);
      if (raw == null) continue;
      if (raw.startsWith('dart:') || raw.startsWith('package:')) continue;
      final resolved = p.normalize(p.join(p.dirname(filePath), raw)).replaceAll('\\', '/');
      exports.add(resolved);
    }
    exportsByFile[filePath] = exports;
  }

  final publicApiFiles = <String>{...exportedLibFiles};
  for (final file in exportedLibFiles) {
    publicApiFiles.addAll(exportsByFile[file] ?? const <String>{});
  }

  final usageIndex = <String, String>{};
  for (final entry in fileContents.entries) {
    usageIndex[entry.key] = entry.value;
  }

  final unusedByFile = <String, List<String>>{};
  for (final entry in symbolsByFile.entries) {
    final filePath = entry.key;
    if (options.excludePublicApi && publicApiFiles.contains(filePath)) {
      continue;
    }
    final symbols = entry.value.toSet().toList()..sort();
    final unused = <String>[];
    for (final symbol in symbols) {
      if (_isSymbolUsedElsewhere(symbol, filePath, usageIndex)) continue;
      unused.add(symbol);
    }
    if (unused.isNotEmpty) {
      unusedByFile[_relativePath(root, filePath)] = unused;
    }
  }

  return unusedByFile;
}

String _relativePath(String rootPosix, String absolutePath) {
  final normalized = p.normalize(absolutePath).replaceAll('\\', '/');
  if (!normalized.startsWith(rootPosix)) return normalized;
  return normalized.afterIndex(rootPosix.length).replaceFirst(RegExp('^/'), '');
}

bool _isGeneratedDart(String relativePath) {
  final lower = relativePath.toLowerCase();
  return lower.endsWith('.g.dart') ||
      lower.endsWith('.freezed.dart') ||
      lower.endsWith('.gr.dart') ||
      lower.contains('/generated/');
}

void _collectTopLevelSymbols({
  required String content,
  required bool includePrivate,
  required List<String> into,
}) {
  const retainedAnnotations = <String>{
    'visibleForTesting',
    'protected',
    'override',
  };
  final names = <String>{};
  final classLike = RegExp(
    r'^\s*(?:class|enum|mixin|extension|typedef)\s+([A-Za-z_]\w*)',
    multiLine: true,
  );
  for (final m in classLike.allMatches(content)) {
    final name = m.group(1);
    if (name == null) continue;
    if (_hasRetainedAnnotation(content, m.start, retainedAnnotations)) continue;
    if (!includePrivate && name.startsWith('_')) continue;
    names.add(name);
  }

  final functionLike = RegExp(
    r'^\s*(?:[A-Za-z_<>\?\[\],\s]+\s+)?([A-Za-z_]\w*)\s*\([^;\n]*\)\s*(?:\{|=>)',
    multiLine: true,
  );
  for (final m in functionLike.allMatches(content)) {
    final name = m.group(1);
    if (name == null) continue;
    if (name == 'main' || name == 'if' || name == 'for' || name == 'while' || name == 'switch') {
      continue;
    }
    if (_hasRetainedAnnotation(content, m.start, retainedAnnotations)) continue;
    if (!includePrivate && name.startsWith('_')) continue;
    names.add(name);
  }

  final varLike = RegExp(
    r'^\s*(?:final|const|var|[A-Za-z_<>\?\[\],\s]+)\s+([A-Za-z_]\w*)\s*=',
    multiLine: true,
  );
  for (final m in varLike.allMatches(content)) {
    final name = m.group(1);
    if (name == null) continue;
    if (_hasRetainedAnnotation(content, m.start, retainedAnnotations)) continue;
    if (!includePrivate && name.startsWith('_')) continue;
    names.add(name);
  }

  into
    ..clear()
    ..addAll(names.toList()..sort());
}

bool _hasRetainedAnnotation(
  String content,
  int declarationStart,
  Set<String> retainedAnnotations,
) {
  final prefixStart = declarationStart - 240;
  final safeStart = prefixStart < 0 ? 0 : prefixStart;
  final window = content.slice(safeStart, declarationStart);
  final annotationMatch = RegExp(r'@([A-Za-z_]\w*)').allMatches(window);
  for (final match in annotationMatch) {
    final raw = match.group(1);
    if (raw == null) continue;
    if (retainedAnnotations.contains(raw)) return true;
  }
  return false;
}

bool _isSymbolUsedElsewhere(
  String symbol,
  String definingFile,
  Map<String, String> fileContents,
) {
  final token = RegExp('\\b${RegExp.escape(symbol)}\\b');
  for (final entry in fileContents.entries) {
    if (entry.key == definingFile) continue;
    if (token.hasMatch(entry.value)) return true;
  }
  return false;
}

_FeatureDepsResult _analyzeFeatureDependencies({
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
  return _FeatureDepsResult(
    featureDependencies: sortedMap,
    crossFeatureImports: sortedEdges,
  );
}

class _FeatureDepsResult {
  const _FeatureDepsResult({
    required this.featureDependencies,
    required this.crossFeatureImports,
  });

  final Map<String, List<String>> featureDependencies;
  final List<String> crossFeatureImports;
}

/// Each entry is a `lib/.../*.dart` file with no matching `test/.../*_test.dart`
/// (same relative path under [projectPath], `_test` before `.dart`).
///
/// Skips `main.dart`, generated-style names (`.g.dart`, etc.), and paths under
/// `lib/generated/` — a conservative 1:1 `lib` → `test` mirror convention.
List<String> _libSourcesMissingMirrorTests({
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
