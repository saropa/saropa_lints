/// Scans for dead assets/fonts/data files: entries declared in `pubspec.yaml`
/// (`flutter: assets:` / `fonts:`) that are never referenced in `lib/`+`test/`,
/// or that no longer exist on disk.
///
/// Reference detection is a heuristic (path / basename substring match), so a
/// dynamically-constructed asset path can produce a false "unreferenced" — the
/// finding is report-only and must be verified before deleting.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// One flagged asset. [kind] is `unreferenced` (declared, never used in code) or
/// `missing` (declared, absent on disk).
class AssetFinding {
  const AssetFinding(this.path, this.kind);
  final String path;
  final String kind;

  Map<String, Object?> toJson() => {'path': path, 'kind': kind};
}

/// Returns dead-asset findings for the project at [projectPath].
List<AssetFinding> scanUnusedAssets(String projectPath) {
  final pubspec = File(p.join(projectPath, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return const [];
  final doc = loadYaml(pubspec.readAsStringSync());
  if (doc is! YamlMap || doc['flutter'] is! YamlMap) return const [];
  final flutter = doc['flutter'] as YamlMap;

  final declared = <String>{};
  _collectAssets(flutter['assets'], projectPath, declared);
  _collectFonts(flutter['fonts'], declared);
  if (declared.isEmpty) return const [];

  final referenced = _referencedAssets(projectPath, declared);
  final findings = <AssetFinding>[];
  for (final asset in declared) {
    if (!File(p.join(projectPath, asset)).existsSync()) {
      findings.add(AssetFinding(asset, 'missing'));
    } else if (!referenced.contains(asset)) {
      findings.add(AssetFinding(asset, 'unreferenced'));
    }
  }
  findings.sort((a, b) => a.path.compareTo(b.path));
  return findings;
}

/// Expands `assets:` entries — directory entries (trailing `/`) expand to the
/// files they contain so each can be checked individually.
void _collectAssets(Object? assets, String projectPath, Set<String> out) {
  if (assets is! YamlList) return;
  for (final entry in assets) {
    final value = entry.toString();
    if (value.endsWith('/')) {
      final dir = Directory(p.join(projectPath, value));
      if (!dir.existsSync()) continue;
      for (final f in dir.listSync()) {
        if (f is File) {
          out.add(p.relative(f.path, from: projectPath).replaceAll('\\', '/'));
        }
      }
    } else {
      out.add(value);
    }
  }
}

void _collectFonts(Object? fonts, Set<String> out) {
  if (fonts is! YamlList) return;
  for (final family in fonts) {
    if (family is! YamlMap || family['fonts'] is! YamlList) continue;
    for (final font in family['fonts'] as YamlList) {
      if (font is YamlMap && font['asset'] != null) {
        out.add(font['asset'].toString());
      }
    }
  }
}

/// One pass over `lib/`+`test/` Dart sources, marking each declared asset whose
/// path or basename appears. One file is in memory at a time (no all-files cache).
Set<String> _referencedAssets(String projectPath, Set<String> declared) {
  final referenced = <String>{};
  for (final dir in const ['lib', 'test']) {
    final root = Directory(p.join(projectPath, dir));
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final asset in declared) {
        if (referenced.contains(asset)) continue;
        if (content.contains(asset) || content.contains(p.basename(asset))) {
          referenced.add(asset);
        }
      }
    }
  }
  return referenced;
}
