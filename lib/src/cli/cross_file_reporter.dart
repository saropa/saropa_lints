// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Options for cross-file `unused-symbols` analysis.
class UnusedSymbolsOptions {
  const UnusedSymbolsOptions({
    this.includePrivate = false,
    this.excludePublicApi = false,
    this.forceHeuristic = false,
  });

  final bool includePrivate;

  final bool excludePublicApi;

  /// When true, skip analyzer-backed semantic resolution and use the regex
  /// heuristic only.
  final bool forceHeuristic;
}

/// Result shape for cross-file analysis (unused files, circular deps,
/// missing mirror tests, stats).
class CrossFileResult {
  const CrossFileResult({
    required this.unusedFiles,
    required this.circularDependencies,
    required this.missingMirrorTests,
    required this.stats,
    required this.featureDependencies,
    required this.crossFeatureImports,
    required this.deadImports,
    this.unusedSymbols = const <String, List<String>>{},
    this.includedPaths = const {},
  });

  final List<String> unusedFiles;
  final List<List<String>> circularDependencies;

  /// `lib/foo/bar.dart` with no `test/foo/bar_test.dart` at the project root.
  final List<String> missingMirrorTests;

  final Map<String, dynamic> stats;

  /// Feature-level adjacency list for `lib/features/<name>/...` imports.
  /// Key = source feature, value = sorted list of target features.
  final Map<String, List<String>> featureDependencies;

  /// Relative import edges crossing feature boundaries.
  /// Example: `lib/features/a/x.dart -> lib/features/b/y.dart`.
  final List<String> crossFeatureImports;
  final Map<String, List<String>> deadImports;

  /// Unused top-level symbols grouped by defining file path.
  final Map<String, List<String>> unusedSymbols;

  /// All file paths that survived exclude filtering. Empty when no excludes
  /// were applied (callers should fall back to the full graph in that case).
  final Set<String> includedPaths;
}

/// Formats cross-file analysis results as text or JSON.
///
/// Usage:
/// ```dart
/// CrossFileReporter.report(result, format: 'text', sink: stdout);
/// CrossFileReporter.report(result, format: 'json', sink: stdout);
/// ```
class CrossFileReporter {
  CrossFileReporter._();

  /// Output format: `text` (default) or `json`.
  /// [sink] defaults to [stdout] when null.
  static void report(
    CrossFileResult result, {
    String format = 'text',
    StringSink? sink,
  }) {
    final out = sink ?? stdout;
    switch (format) {
      case 'json':
        _reportJson(result, out);
        break;
      case 'text':
      default:
        _reportText(result, out);
    }
  }

  static void _reportText(CrossFileResult result, StringSink sink) {
    final u = result.unusedFiles;
    sink.writeln('Unused Files (${u.length} found):');
    if (u.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final f in u) {
        sink.writeln('  $f');
      }
    }
    sink.writeln('');

    final m = result.missingMirrorTests;
    sink.writeln('Lib sources without mirror test (${m.length} found):');
    if (m.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final f in m) {
        sink.writeln('  $f');
      }
    }
    sink.writeln('');

    final c = result.circularDependencies;
    sink.writeln('Circular Dependencies (${c.length} found):');
    if (c.isEmpty) {
      sink.writeln('  (none)');
    } else {
      for (final cycle in c) {
        sink.writeln('  ${cycle.join(' -> ')}');
      }
    }
    sink.writeln('');

    if (result.stats.isNotEmpty) {
      sink.writeln('Import graph stats:');
      sink.writeln('  fileCount: ${result.stats['fileCount'] ?? 0}');
      sink.writeln('  totalImports: ${result.stats['totalImports'] ?? 0}');
    }
    sink.writeln('');

    final featureDeps = result.featureDependencies;
    final crossImports = result.crossFeatureImports;
    sink.writeln(
      'Feature Dependencies (${featureDeps.length} feature(s), ${crossImports.length} cross-feature import(s)):',
    );
    if (featureDeps.isEmpty) {
      sink.writeln('  (none)');
      return;
    }
    final sortedFeatures = featureDeps.keys.toList()..sort();
    for (final feature in sortedFeatures) {
      final targets = featureDeps[feature] ?? const <String>[];
      if (targets.isEmpty) continue;
      sink.writeln('  $feature -> ${targets.join(', ')}');
    }
    sink.writeln('');
    sink.writeln('Feature dependency matrix (from \\ to):');
    _writeFeatureDependencyMatrix(sink: sink, featureDeps: featureDeps);

    sink.writeln('');
    if (crossImports.isNotEmpty) {
      sink.writeln('Cross-feature imports:');
      for (final edge in crossImports) {
        sink.writeln('  $edge');
      }
      sink.writeln('');
    }

    final deadImports = result.deadImports;
    final deadImportCount = deadImports.values.fold<int>(
      0,
      (sum, values) => sum + values.length,
    );
    sink.writeln('Dead Imports ($deadImportCount found):');
    if (deadImportCount == 0) {
      sink.writeln('  (none)');
    } else {
      final files = deadImports.keys.toList()..sort();
      for (final file in files) {
        final imports = deadImports[file] ?? const <String>[];
        if (imports.isEmpty) continue;
        sink.writeln('  $file');
        for (final imp in imports) {
          sink.writeln('    - $imp');
        }
      }
    }
    sink.writeln('');

    final unusedSymbols = result.unusedSymbols;
    final totalUnused = unusedSymbols.values.fold<int>(
      0,
      (sum, symbols) => sum + symbols.length,
    );
    sink.writeln('Unused Symbols ($totalUnused found):');
    if (totalUnused == 0) {
      sink.writeln('  (none)');
      return;
    }
    final files = unusedSymbols.keys.toList()..sort();
    for (final file in files) {
      final symbols = unusedSymbols[file] ?? const <String>[];
      if (symbols.isEmpty) continue;
      sink.writeln('  $file');
      for (final symbol in symbols) {
        sink.writeln('    - $symbol');
      }
    }
  }

  static void _reportJson(CrossFileResult result, StringSink sink) {
    final map = <String, dynamic>{
      'unusedFiles': result.unusedFiles,
      'circularDependencies': result.circularDependencies,
      'missingMirrorTests': result.missingMirrorTests,
      'featureDependencies': result.featureDependencies,
      'crossFeatureImports': result.crossFeatureImports,
      'deadImports': result.deadImports,
      'unusedSymbols': result.unusedSymbols,
      if (result.stats.isNotEmpty) 'stats': result.stats,
    };
    sink.writeln(const JsonEncoder.withIndent('  ').convert(map));
  }

  static void _writeFeatureDependencyMatrix({
    required StringSink sink,
    required Map<String, List<String>> featureDeps,
  }) {
    final allFeatures = <String>{
      ...featureDeps.keys,
      for (final targets in featureDeps.values) ...targets,
    }.toList()..sort();
    if (allFeatures.isEmpty) {
      sink.writeln('  (none)');
      return;
    }
    const colWidth = 12;
    final header = StringBuffer(''.padRight(colWidth));
    for (final col in allFeatures) {
      header.write(_trimLabel(col).padRight(colWidth));
    }
    sink.writeln('  ${header.toString().trimRight()}');
    for (final from in allFeatures) {
      final row = StringBuffer(_trimLabel(from).padRight(colWidth));
      final targets = featureDeps[from]?.toSet() ?? const <String>{};
      for (final to in allFeatures) {
        if (from == to) {
          row.write('-'.padRight(colWidth));
        } else {
          row.write((targets.contains(to) ? 'X' : '.').padRight(colWidth));
        }
      }
      sink.writeln('  ${row.toString().trimRight()}');
    }
  }

  static String _trimLabel(String value) {
    if (value.length <= 10) return value;
    return '${value.split('').take(9).join()}~';
  }
}
