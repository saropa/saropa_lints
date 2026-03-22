// ignore_for_file: depend_on_referenced_packages

/// Reads resolved package versions from [pubspec.lock] for rule-pack semver gates.
library;

import 'dart:io' show File;

import 'package:path/path.dart' as p;

/// Parses `pubspec.lock` body into package name → version (hosted/path/git entries).
///
/// Returns empty map when `packages:` is missing. Ignores malformed lines.
Map<String, String> parsePubspecLockPackageVersions(String content) {
  final out = <String, String>{};
  if (content.isEmpty) return out;
  final lines = content.split(RegExp(r'\r\n?|\n'));
  var inPackages = false;
  String? currentPkg;
  for (final line in lines) {
    if (!inPackages) {
      if (line.trim() == 'packages:') inPackages = true;
      continue;
    }
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!line.startsWith(' ') && line.contains(':')) {
      break;
    }
    final pkgMatch = RegExp(r'^  ([a-zA-Z0-9_-]+):\s*$').firstMatch(line);
    if (pkgMatch != null) {
      currentPkg = pkgMatch.group(1)!;
      continue;
    }
    final quoted = RegExp(r'^    version:\s+"([^"]+)"\s*$').firstMatch(line);
    if (quoted != null && currentPkg != null) {
      out[currentPkg] = quoted.group(1)!;
      continue;
    }
    final bare = RegExp(r'^    version:\s+(\S+)\s*$').firstMatch(line);
    if (bare != null && currentPkg != null) {
      out[currentPkg] = bare.group(1)!;
    }
  }
  return out;
}

String? _cachedRoot;
int? _cachedMtime = -1;
Map<String, String>? _cachedVersions;

/// Clears cached lockfile parse (e.g. after tests mutate files).
void clearPubspecLockResolverCacheForTests() {
  _cachedRoot = null;
  _cachedMtime = -1;
  _cachedVersions = null;
}

/// Resolved version for [packageName] in [projectRoot], or null if unknown.
///
/// Uses [pubspec.lock] mtime cache per project root.
String? readResolvedPackageVersion(String projectRoot, String packageName) {
  final map = readResolvedPackageVersions(projectRoot);
  return map?[packageName];
}

/// All resolved versions from [projectRoot]/pubspec.lock, or null if file missing.
Map<String, String>? readResolvedPackageVersions(String projectRoot) {
  if (projectRoot.isEmpty) return null;
  final lockPath = p.join(projectRoot, 'pubspec.lock');
  final file = File(lockPath);
  if (!file.existsSync()) {
    if (_cachedRoot == projectRoot) {
      _cachedRoot = null;
      _cachedMtime = -1;
      _cachedVersions = null;
    }
    return null;
  }
  final mtime = file.lastModifiedSync().millisecondsSinceEpoch;
  if (_cachedRoot == projectRoot &&
      _cachedMtime == mtime &&
      _cachedVersions != null) {
    return _cachedVersions;
  }
  try {
    final text = file.readAsStringSync();
    final map = parsePubspecLockPackageVersions(text);
    _cachedRoot = projectRoot;
    _cachedMtime = mtime;
    _cachedVersions = map;
    return map;
  } catch (_) {
    return null;
  }
}
