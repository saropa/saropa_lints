/// Loads optional cross-file CLI defaults from the project's
/// `analysis_options.yaml`.
///
/// Precedence when merging excludes: YAML defaults first, then values from
/// the command line (`--exclude` repetitions).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Project-level defaults for [`CrossFile`] CLI invocation.
///
/// Supported shape (YAML):
/// ```yaml
/// saropa_lints_cross_file:
///   excludes:
///     - "**/*.g.dart"
///   heuristic_dead_imports: true
///   heuristic_unused_symbols: true
/// ```
class CrossFileProjectCliOptions {
  const CrossFileProjectCliOptions({
    this.excludeGlobs = const [],
    this.heuristicDeadImports,
    this.heuristicUnusedSymbols,
    this.includePrivateSymbols,
    this.excludePublicApi,
  });

  final List<String> excludeGlobs;
  final bool? heuristicDeadImports;
  final bool? heuristicUnusedSymbols;
  final bool? includePrivateSymbols;
  final bool? excludePublicApi;

  /// Parses [analysis_options.yaml] at [projectPath] root only.
  static CrossFileProjectCliOptions load(String projectPath) {
    final file = File(p.join(projectPath, 'analysis_options.yaml'));
    if (!file.existsSync()) {
      return const CrossFileProjectCliOptions();
    }
    try {
      final doc = loadYaml(file.readAsStringSync());
      if (doc is! Map) {
        return const CrossFileProjectCliOptions();
      }
      final root = doc.cast<Object?, Object?>();
      final sectionDyn = root['saropa_lints_cross_file'];
      if (sectionDyn == null || sectionDyn is! Map) {
        return const CrossFileProjectCliOptions();
      }
      final map = Map<Object?, Object?>.from(sectionDyn);
      final excludes = _stringList(map['excludes'] ?? map['exclude']);
      return CrossFileProjectCliOptions(
        excludeGlobs: excludes,
        heuristicDeadImports: _bool(map['heuristic_dead_imports']),
        heuristicUnusedSymbols: _bool(map['heuristic_unused_symbols']),
        includePrivateSymbols: _bool(map['include_private_symbols']),
        excludePublicApi: _bool(map['exclude_public_api']),
      );
    } on Object catch (_) {
      return const CrossFileProjectCliOptions();
    }
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static List<String> _stringList(Object? value) {
    if (value == null) {
      return [];
    }
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? [] : [t];
    }
    if (value is YamlList || value is List) {
      final out = <String>[];
      for (final entry in List<Object?>.from(value as List)) {
        if (entry is String && entry.trim().isNotEmpty) {
          out.add(entry.trim());
        }
      }
      return out;
    }
    return [];
  }
}
