// ignore_for_file: depend_on_referenced_packages

/// Reads resolved package versions from [pubspec.lock] for rule-pack semver gates.
library;

import 'dart:developer' as developer;
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

/// Parses `pubspec.lock` body into package name → `dependency:` kind.
///
/// The kind is the raw lock value with surrounding quotes stripped:
/// `direct main`, `direct dev`, `direct overridden`, or `transitive`.
/// Older lockfiles emit a bare `direct`; that is preserved verbatim.
/// Returns empty map when `packages:` is missing. Ignores malformed lines.
///
/// Separate from [parsePubspecLockPackageVersions] so the existing
/// version-only callers keep their map shape; this resolver runs over a small
/// file, so a second pass is cheaper than reshaping the public version map.
Map<String, String> parsePubspecLockDependencyKinds(String content) {
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
    // A top-level key (e.g. `sdks:`) ends the packages block.
    if (!line.startsWith(' ') && line.contains(':')) {
      break;
    }
    final pkgMatch = RegExp(r'^  ([a-zA-Z0-9_-]+):\s*$').firstMatch(line);
    if (pkgMatch != null) {
      currentPkg = pkgMatch.group(1)!;
      continue;
    }
    // `dependency:` value may be quoted ("direct main") or bare (transitive).
    final dep = RegExp(
      r'^    dependency:\s+"?([^"\n]+?)"?\s*$',
    ).firstMatch(line);
    if (dep != null && currentPkg != null) {
      out[currentPkg] = dep.group(1)!.trim();
    }
  }
  return out;
}

String? _cachedRoot;
int? _cachedMtime = -1;
Map<String, String>? _cachedVersions;

String? _cachedKindRoot;
int? _cachedKindMtime = -1;
Map<String, String>? _cachedKinds;

/// Clears cached lockfile parse (e.g. after tests mutate files).
void clearPubspecLockResolverCacheForTests() {
  _cachedRoot = null;
  _cachedMtime = -1;
  _cachedVersions = null;
  _cachedKindRoot = null;
  _cachedKindMtime = -1;
  _cachedKinds = null;
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
  } on Object catch (e, st) {
    // Fix: avoid_swallowing_exceptions — parse failures are non-fatal (caller
    // falls back to pubspec.yaml version ranges), but log so silent failures
    // are observable during development.
    developer.log(
      'resolveLockedVersions: read/parse pubspec.lock failed',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// All `dependency:` kinds from [projectRoot]/pubspec.lock, or null if missing.
///
/// Cached per project root by lockfile mtime, mirroring
/// [readResolvedPackageVersions].
Map<String, String>? readDependencyKinds(String projectRoot) {
  if (projectRoot.isEmpty) return null;
  final lockPath = p.join(projectRoot, 'pubspec.lock');
  final file = File(lockPath);
  if (!file.existsSync()) {
    if (_cachedKindRoot == projectRoot) {
      _cachedKindRoot = null;
      _cachedKindMtime = -1;
      _cachedKinds = null;
    }
    return null;
  }

  final mtime = file.lastModifiedSync().millisecondsSinceEpoch;
  if (_cachedKindRoot == projectRoot &&
      _cachedKindMtime == mtime &&
      _cachedKinds != null) {
    return _cachedKinds;
  }
  try {
    final map = parsePubspecLockDependencyKinds(file.readAsStringSync());
    _cachedKindRoot = projectRoot;
    _cachedKindMtime = mtime;
    _cachedKinds = map;
    return map;
  } on Object catch (e, st) {
    // Non-fatal: a missing/garbled kind only loses the direct-vs-transitive
    // distinction, so callers fall back to treating the dep as present.
    developer.log(
      'readDependencyKinds: read/parse pubspec.lock failed',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// Whether [packageName] is a DIRECT dependency in [projectRoot]/pubspec.lock.
///
/// True for `direct main`, `direct dev`, `direct overridden`, and the legacy
/// bare `direct`; false for `transitive`. Returns null when the lockfile or the
/// package entry is absent — callers decide whether "unknown" should suggest a
/// pack (§7.3 default: direct-only suggestions, so treat null as not-direct).
bool? isDirectDependency(String projectRoot, String packageName) {
  final kinds = readDependencyKinds(projectRoot);
  final kind = kinds?[packageName];
  if (kind == null) return null;
  return kind.startsWith('direct');
}
