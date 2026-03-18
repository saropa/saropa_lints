import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

/// Baseline format for cross-file results (JSON).
///
/// ```json
/// {
///   "version": 1,
///   "generated": "2026-03-17T12:00:00.000Z",
///   "unusedFiles": ["lib/foo.dart"],
///   "circularDependencies": [["lib/a.dart", "lib/b.dart", "lib/a.dart"]]
/// }
/// ```
class CrossFileBaseline {
  CrossFileBaseline({
    required this.unusedFiles,
    required this.circularDependencies,
    DateTime? generated,
  }) : generated = generated ?? DateTime.now();

  static const int version = 1;

  final DateTime generated;
  final List<String> unusedFiles;
  final List<List<String>> circularDependencies;

  static CrossFileBaseline? load(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>?;
      return fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  static CrossFileBaseline fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CrossFileBaseline(unusedFiles: [], circularDependencies: []);
    }
    final u = json['unusedFiles'];
    final unusedFiles = u is List
        ? u.map((e) => e is String ? e : e.toString()).toList()
        : <String>[];
    final c = json['circularDependencies'];
    final circularDependencies = c is List
        ? c
            .map((e) => e is List
                ? e.map((f) => f is String ? f : f.toString()).toList()
                : <String>[])
            .toList()
        : <List<String>>[];
    final g = json['generated'];
    final generated = g is String ? DateTime.tryParse(g) : null;
    return CrossFileBaseline(
      unusedFiles: unusedFiles,
      circularDependencies: circularDependencies,
      generated: generated,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'generated': generated.toUtc().toIso8601String(),
        'unusedFiles': unusedFiles,
        'circularDependencies': circularDependencies,
      };

  void save(String path) {
    File(path).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(toJson()),
    );
  }

  /// True if [current] has no new violations compared to this baseline.
  /// New = unused file or cycle present in current but not in baseline.
  static bool hasNewViolations(
      CrossFileResult current, CrossFileBaseline? base) {
    if (base == null) {
      return current.unusedFiles.isNotEmpty ||
          current.circularDependencies.isNotEmpty;
    }
    final newUnused =
        current.unusedFiles.toSet().difference(base.unusedFiles.toSet());
    if (newUnused.isNotEmpty) return true;
    final baseCycleKeys = base.circularDependencies.map(_cycleKey).toSet();
    for (final cycle in current.circularDependencies) {
      if (!baseCycleKeys.contains(_cycleKey(cycle))) return true;
    }
    return false;
  }

  static String _cycleKey(List<String> cycle) {
    final sorted = cycle.toSet().toList()..sort();
    return sorted.join('|');
  }
}
