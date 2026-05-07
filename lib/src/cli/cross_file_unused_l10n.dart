// Cross-file **unused l10n** helper: compares ARB message keys against `lib/` + `test/` Dart text.
// Discovery order: explicit `--arb-dir`, `l10n.yaml` `arb-dir`, then `lib/l10n` and `l10n/`.
// Matching is regex word-boundary on the raw key string (fast, heuristic; may miss dynamic lookups).
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// ARB keys that do not appear as Dart identifiers in project sources.
class UnusedL10nResult {
  const UnusedL10nResult({required this.arbPaths, required this.unusedKeys});

  final List<String> arbPaths;
  final List<String> unusedKeys;

  bool get hasUnused => unusedKeys.isNotEmpty;
}

/// Scans [projectPath] for ARB keys vs `\bkey\b` usage in `lib/` and `test/`.
Future<UnusedL10nResult> analyzeUnusedL10n({
  required String projectPath,
  String? arbDirOverride,
}) async {
  final arbPaths = _discoverArbPaths(projectPath, arbDirOverride);
  if (arbPaths.isEmpty) {
    return const UnusedL10nResult(arbPaths: [], unusedKeys: []);
  }

  final keys = <String>{};
  for (final arbPath in arbPaths) {
    keys.addAll(_readArbKeys(arbPath));
  }

  final sources = _readDartSources(projectPath);
  final unused = <String>[];
  for (final key in keys) {
    if (!_isPlausibleL10nKey(key)) continue;
    final pattern = RegExp('\\b${RegExp.escape(key)}\\b');
    var used = false;
    for (final content in sources.values) {
      if (pattern.hasMatch(content)) {
        used = true;
        break;
      }
    }
    if (!used) unused.add(key);
  }
  unused.sort();
  return UnusedL10nResult(
    arbPaths: arbPaths.map((e) => p.relative(e, from: projectPath)).toList(),
    unusedKeys: unused,
  );
}

/// Resolves `.arb` paths from an override, `l10n.yaml`, or conventional folders under [projectPath].
List<String> _discoverArbPaths(String projectPath, String? override) {
  if (override != null && override.isNotEmpty) {
    final dir = Directory(p.normalize(p.join(projectPath, override)));
    if (dir.existsSync()) {
      return dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .map((f) => f.path)
          .toList();
    }
  }
  final l10nYaml = File(p.join(projectPath, 'l10n.yaml'));
  if (l10nYaml.existsSync()) {
    try {
      final doc = loadYaml(l10nYaml.readAsStringSync());
      if (doc is YamlMap) {
        final arbDir = doc['arb-dir'] ?? doc['arb_dir'];
        if (arbDir is String) {
          return _discoverArbPaths(projectPath, arbDir);
        }
      }
    } on Object catch (e) {
      stderr.writeln('cross_file unused-l10n: skipped malformed l10n.yaml: $e');
    }
  }
  final candidates = [
    Directory(p.join(projectPath, 'lib', 'l10n')),
    Directory(p.join(projectPath, 'l10n')),
  ];
  final out = <String>[];
  for (final dir in candidates) {
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.arb')) out.add(e.path);
    }
  }
  return out;
}

/// Returns user message keys from an ARB JSON map (skips `@meta` entries and malformed files).
Set<String> _readArbKeys(String arbPath) {
  final text = File(arbPath).readAsStringSync();
  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    stderr.writeln('cross_file unused-l10n: malformed JSON in $arbPath: $e');
    return const {};
  }
  if (decoded is! Map) return const {};
  final keys = <String>{};
  for (final entry in decoded.entries) {
    final k = entry.key;
    if (k is! String || k.startsWith('@')) continue;
    keys.add(k);
  }
  return keys;
}

/// Loads non-generated Dart sources under `lib/` and `test/` keyed by absolute path.
Map<String, String> _readDartSources(String projectPath) {
  final out = <String, String>{};
  for (final sub in ['lib', 'test']) {
    final dir = Directory(p.join(projectPath, sub));
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final lower = e.path.toLowerCase();
      if (lower.endsWith('.g.dart') ||
          lower.endsWith('.freezed.dart') ||
          lower.endsWith('.gr.dart')) {
        continue;
      }
      out[e.path] = e.readAsStringSync();
    }
  }
  return out;
}

/// Filters ARB keys to simple identifier shapes so metadata keys do not dominate noise.
bool _isPlausibleL10nKey(String key) {
  if (key.isEmpty) return false;
  return RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key);
}
