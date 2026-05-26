/// Incremental cache for the EXPENSIVE part of the scan (the AST parse behind
/// complexity / maintainability / doc-coverage), keyed by a stable content hash.
/// A warm rescan reuses the cached metrics for unchanged files and only reparses
/// what changed. Size/LOC is always recomputed (cheap) so it is never stale.
library;

import 'dart:convert';
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

  factory CacheEntry.fromJson(Map<String, Object?> j) => CacheEntry(
    hash: (j['hash'] as num).toInt(),
    complexity: FileComplexity.fromJson(
      (j['complexity'] as Map).cast<String, Object?>(),
    ),
    maintainability: (j['mi'] as num?)?.toDouble() ?? 0,
    maintainabilityRaw: (j['miRaw'] as num?)?.toDouble() ?? 0,
    docCoverage: (j['docCoverage'] as num?)?.toDouble(),
  );
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
  if (!file.existsSync()) return {};
  try {
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return {
      for (final e in decoded.entries)
        e.key: CacheEntry.fromJson((e.value as Map).cast<String, Object?>()),
    };
  } on Object {
    return {}; // ignore malformed cache; next scan rebuilds it
  }
}

/// Writes the cache map to [cachePath].
void saveComplexityCache(String cachePath, Map<String, CacheEntry> cache) {
  File(cachePath).writeAsStringSync(
    jsonEncode({for (final e in cache.entries) e.key: e.value.toJson()}),
  );
}
