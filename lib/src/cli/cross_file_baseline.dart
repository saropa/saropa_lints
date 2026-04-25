import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:saropa_lints/src/cli/cross_file_reporter.dart';

/// Baseline format for cross-file results (JSON).
///
/// ```json
/// {
///   "version": 2,
///   "generated": "2026-03-17T12:00:00.000Z",
///   "unusedFiles": ["lib/foo.dart"],
///   "circularDependencies": [["lib/a.dart", "lib/b.dart", "lib/a.dart"]],
///   "missingMirrorTests": ["lib/foo.dart"]
/// }
/// ```
class CrossFileBaseline {
  CrossFileBaseline({
    required this.unusedFiles,
    required this.circularDependencies,
    List<String>? missingMirrorTests,
    DateTime? generated,
  }) : generated = generated ?? DateTime.now(),
       missingMirrorTests = missingMirrorTests ?? const [];

  static const int version = 2;

  final DateTime generated;
  final List<String> unusedFiles;
  final List<List<String>> circularDependencies;

  /// See [CrossFileResult.missingMirrorTests].
  final List<String> missingMirrorTests;

  static CrossFileBaseline? load(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      if (content.isEmpty) return null;
      final decoded = jsonDecode(content) as Map<String, dynamic>?;
      return fromJson(decoded);
    } on Object catch (e, st) {
      // Fix: avoid_swallowing_exceptions — baseline load failure is non-fatal
      // (caller falls back to a fresh baseline), but we log so the failure is
      // visible in developer tooling rather than silently hidden.
      developer.log(
        'CrossFileBaseline.load: read/parse failed for $path',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  static CrossFileBaseline fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return CrossFileBaseline(
        unusedFiles: [],
        circularDependencies: [],
        missingMirrorTests: [],
      );
    }
    final u = json['unusedFiles'];
    final unusedFiles = u is List
        ? u.map((e) => e is String ? e : e.toString()).toList()
        : <String>[];
    final c = json['circularDependencies'];
    final circularDependencies = c is List
        ? c
              .map(
                (e) => e is List
                    ? e.map((f) => f is String ? f : f.toString()).toList()
                    : <String>[],
              )
              .toList()
        : <List<String>>[];
    final mt = json['missingMirrorTests'];
    final missingMirrorTests = mt is List
        ? mt.map((e) => e is String ? e : e.toString()).toList()
        : <String>[];
    final g = json['generated'];
    final generated = g is String ? DateTime.tryParse(g) : null;
    return CrossFileBaseline(
      unusedFiles: unusedFiles,
      circularDependencies: circularDependencies,
      missingMirrorTests: missingMirrorTests,
      generated: generated,
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'generated': generated.toUtc().toIso8601String(),
    'unusedFiles': unusedFiles,
    'circularDependencies': circularDependencies,
    'missingMirrorTests': missingMirrorTests,
  };

  void save(String path) {
    File(
      path,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(toJson()));
  }

  /// True if [current] has no new violations compared to this baseline.
  /// New = unused file, missing mirror test, or cycle present in current but
  /// not in baseline.
  static bool hasNewViolations(
    CrossFileResult current,
    CrossFileBaseline? base,
  ) {
    if (base == null) {
      return current.unusedFiles.isNotEmpty ||
          current.circularDependencies.isNotEmpty ||
          current.missingMirrorTests.isNotEmpty;
    }
    final newUnused = current.unusedFiles.toSet().difference(
      base.unusedFiles.toSet(),
    );
    if (newUnused.isNotEmpty) return true;
    final newMissing = current.missingMirrorTests.toSet().difference(
      base.missingMirrorTests.toSet(),
    );
    if (newMissing.isNotEmpty) return true;
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
