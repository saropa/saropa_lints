/// Incremental cache for the EXPENSIVE part of the scan (the AST parse behind
/// complexity / maintainability / doc-coverage), keyed by a stable content hash.
/// A warm rescan reuses the cached metrics for unchanged files and only reparses
/// what changed. Size/LOC is always recomputed (cheap) so it is never stale.
library;

import 'dart:convert';
// ignore: avoid_platform_specific_imports — CLI-only file, never runs on web
import 'dart:io';

import 'metrics_model.dart';

/// One file's cached parse result.
class CacheEntry {
  const CacheEntry({
    required this.hash,
    required this.complexity,
    required this.maintainability,
    required this.maintainabilityRaw,
    required this.docCoverage,
  });

  final int hash;
  final FileComplexity complexity;
  final double maintainability;
  final double maintainabilityRaw;
  final double? docCoverage;

  Map<String, Object?> toJson() => {
    'hash': hash,
    'complexity': complexity.toJson(),
    'mi': maintainability,
    'miRaw': maintainabilityRaw,
    if (docCoverage != null) 'docCoverage': docCoverage,
  };

  /// Deserializes a cache entry; tolerates missing/wrong-typed fields so a
  /// corrupt cache entry degrades to defaults instead of throwing.
  factory CacheEntry.fromJson(Map<String, Object?> j) {
    final rawHash = j['hash'];
    final rawComplexity = j['complexity'];
    return CacheEntry(
      hash: rawHash is num ? rawHash.toInt() : 0,
      complexity: rawComplexity is Map
          ? FileComplexity.fromJson(rawComplexity.cast<String, Object?>())
          : FileComplexity.zero,
      maintainability: (j['mi'] as num?)?.toDouble() ?? 0,
      maintainabilityRaw: (j['miRaw'] as num?)?.toDouble() ?? 0,
      docCoverage: (j['docCoverage'] as num?)?.toDouble(),
    );
  }
}

/// Stable 32-bit FNV-1a hash of [content]. Unlike `String.hashCode` this is
/// stable across runs, so it is safe to persist in the cache file.
int stableHash(String content) {
  var hash = 0x811c9dc5;
  for (final unit in content.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Loads the cache map (path → entry) from [cachePath], or empty when absent or
/// unreadable (a corrupt cache must never break a scan).
Map<String, CacheEntry> loadComplexityCache(String cachePath) {
  final file = File(cachePath);
  if (!file.existsSync()) return <String, CacheEntry>{};
  try {
    // Safe decode: if the JSON is not a map the cache is corrupt
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) return <String, CacheEntry>{};
    // Build map entry-by-entry so we can promote the value type safely
    final result = <String, CacheEntry>{};
    for (final e in decoded.entries) {
      final v = e.value;
      if (v is Map) {
        result[e.key] = CacheEntry.fromJson(v.cast<String, Object?>());
      }
    }
    return result;
    // ignore: require_catch_logging
  } on Object {
    // Malformed cache — next scan rebuilds it; not worth logging since
    // the user may have hand-deleted or truncated the file.
    return <String, CacheEntry>{};
  }
}

/// Writes the cache map to [cachePath].
void saveComplexityCache(String cachePath, Map<String, CacheEntry> cache) {
  File(cachePath).writeAsStringSync(
    jsonEncode({for (final e in cache.entries) e.key: e.value.toJson()}),
  );
}
