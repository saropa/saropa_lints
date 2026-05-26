/// Optional `.saropa_health.yaml` config: an allowlist for known false positives
/// plus shared excludes. Heuristic findings (dead files/symbols, islands,
/// assets) WILL have false positives; without a "known, ignore" mechanism the
/// report cries wolf and gets abandoned. This is the suppression layer.
///
/// Example:
/// ```yaml
/// exclude:
///   - "lib/generated/**"
/// ignore:
///   dead_files:   [lib/legacy/orphan.dart]
///   dead_symbols: [lib/config_loader.dart]   # ignore this file's dead symbols
///   islands:      [_legacyBoot]              # ignore by symbol name
///   assets:       [assets/keep_me.png]
/// ```
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Parsed config. All collections default empty, so "no config file" behaves
/// exactly as before.
class HealthConfig {
  const HealthConfig({
    this.excludeGlobs = const [],
    this.ignoreDeadFiles = const {},
    this.ignoreDeadSymbols = const {},
    this.ignoreIslands = const {},
    this.ignoreAssets = const {},
  });

  final List<String> excludeGlobs;
  final Set<String> ignoreDeadFiles;
  final Set<String> ignoreDeadSymbols;
  final Set<String> ignoreIslands;
  final Set<String> ignoreAssets;

  static const empty = HealthConfig();

  /// Removes allowlisted entries from a dead-file set.
  Set<String> filterDeadFiles(Set<String> files) =>
      files.where((f) => !ignoreDeadFiles.contains(f)).toSet();

  /// Drops allowlisted files from the dead-symbol counts.
  Map<String, int> filterDeadSymbols(Map<String, int> counts) => {
    for (final e in counts.entries)
      if (!ignoreDeadSymbols.contains(e.key)) e.key: e.value,
  };

  /// Removes allowlisted symbol names from per-file island findings, dropping
  /// files that become empty.
  Map<String, List<String>> filterIslands(Map<String, List<String>> islands) {
    final result = <String, List<String>>{};
    for (final entry in islands.entries) {
      final kept = entry.value
          .where((name) => !ignoreIslands.contains(name))
          .toList();
      if (kept.isNotEmpty) result[entry.key] = kept;
    }
    return result;
  }

  bool isAssetIgnored(String path) => ignoreAssets.contains(path);
}

/// Loads `.saropa_health.yaml` from [projectPath] (or [configPath] override).
/// Returns [HealthConfig.empty] when absent or malformed.
HealthConfig loadHealthConfig(String projectPath, {String? configPath}) {
  final file = File(configPath ?? p.join(projectPath, '.saropa_health.yaml'));
  if (!file.existsSync()) return HealthConfig.empty;
  final doc = loadYaml(file.readAsStringSync());
  if (doc is! YamlMap) return HealthConfig.empty;
  final ignore = doc['ignore'];
  final ignoreMap = ignore is YamlMap ? ignore : const {};
  return HealthConfig(
    excludeGlobs: _strings(doc['exclude']),
    ignoreDeadFiles: _strings(ignoreMap['dead_files']).toSet(),
    ignoreDeadSymbols: _strings(ignoreMap['dead_symbols']).toSet(),
    ignoreIslands: _strings(ignoreMap['islands']).toSet(),
    ignoreAssets: _strings(ignoreMap['assets']).toSet(),
  );
}

List<String> _strings(Object? node) {
  if (node is! YamlList) return const [];
  return [for (final item in node) item.toString()];
}
