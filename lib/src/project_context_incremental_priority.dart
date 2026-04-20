part of 'project_context.dart';

// =============================================================================
// INCREMENTAL ANALYSIS TRACKER (Performance Optimization)
// =============================================================================
//
// Tracks which files have been fully analyzed with no violations, allowing
// us to skip re-analysis until the file changes. This is especially valuable
// for large projects where most files pass all rules.
//
// **DISK PERSISTENCE**: Cache survives IDE restarts by saving to
// `.dart_tool/saropa_lints_cache.json`. This prevents re-analyzing the entire
// project on every IDE restart.
// =============================================================================

/// Tracks clean files for incremental analysis optimization.
///
/// A "clean" file is one that passed all enabled rules with no violations.
/// Clean files can be skipped entirely on subsequent analysis runs until
/// either the file changes or the rule set changes.
///
/// **Persistence**: Call [loadFromDisk] at startup and [saveToDisk] periodically
/// to survive IDE restarts. Cache is stored in `.dart_tool/saropa_lints_cache.json`.
class IncrementalAnalysisTracker {
  IncrementalAnalysisTracker._();

  // Map of file path -> (content hash, set of passed rule names)
  static final Map<String, _FileAnalysisState> _state = {};

  // Hash of the current rule configuration (tier + enabled rules)
  static int? _ruleConfigHash;

  // Project root for disk cache location
  static String? _projectRoot;

  // Track if cache is dirty (needs saving)
  static bool _isDirty = false;

  // Counter for auto-save throttling
  static int _changesSinceLastSave = 0;
  static const int _autoSaveThreshold = 50; // Save after 50 changes

  /// Cache file name (stored in .dart_tool/)
  static const String _cacheFileName = 'saropa_lints_cache.json';

  /// Set the project root for disk cache location.
  ///
  /// Call this once when initializing the linter.
  static void setProjectRoot(String projectRoot) {
    if (_projectRoot != projectRoot) {
      _projectRoot = projectRoot;
      // Try to load existing cache
      loadFromDisk();
    }
  }

  /// Set the current rule configuration hash.
  ///
  /// Call this when rules are loaded. If the hash changes, all cached
  /// analysis results are invalidated.
  static void setRuleConfig(int configHash) {
    if (_ruleConfigHash != configHash) {
      _state.clear();
      _ruleConfigHash = configHash;
      _isDirty = true;
      // Don't auto-save here - config change might be temporary
    }
  }

  /// Disable incremental caching entirely.
  ///
  /// Cache is DISABLED BY DEFAULT due to bugs causing stale "passed" entries.
  /// Set SAROPA_LINTS_ENABLE_CACHE=true to re-enable (not recommended).
  static final bool _cacheDisabled =
      !(const bool.fromEnvironment('SAROPA_LINTS_ENABLE_CACHE') ||
          const String.fromEnvironment('SAROPA_LINTS_ENABLE_CACHE') == 'true');

  /// Check if a rule can be skipped for this file.
  ///
  /// Returns `true` if:
  /// - The file's content hash matches the cached hash
  /// - The rule previously passed on this file
  static bool canSkipRule(String filePath, String content, String ruleName) {
    // Allow complete cache bypass for debugging
    if (_cacheDisabled) return false;

    // Normalize path separators for cross-platform consistency
    final normalizedPath = normalizePath(filePath);
    final state = _state[normalizedPath];
    if (state == null) return false;

    // Check if file changed
    final currentHash = content.hashCode;
    if (state.contentHash != currentHash) {
      // File changed - invalidate
      _state.remove(normalizedPath);
      _isDirty = true;
      return false;
    }

    return state.passedRules.contains(ruleName);
  }

  /// Record that a rule passed on a file.
  static void recordRulePassed(
    String filePath,
    String content,
    String ruleName,
  ) {
    // Skip recording if cache is disabled
    if (_cacheDisabled) return;

    // Normalize path separators for cross-platform consistency
    final normalizedPath = normalizePath(filePath);
    final hash = content.hashCode;
    final state = _state.putIfAbsent(
      normalizedPath,
      () => _FileAnalysisState(contentHash: hash),
    );

    // Update hash if changed
    if (state.contentHash != hash) {
      state.contentHash = hash;
      state.passedRules.clear();
    }

    final wasAdded = state.passedRules.add(ruleName);
    if (wasAdded) {
      _isDirty = true;
      _changesSinceLastSave++;

      // Auto-save periodically to avoid losing too much work
      if (_changesSinceLastSave >= _autoSaveThreshold) {
        saveToDisk();
      }
    }
  }

  /// Check if a file is completely clean (all rules passed).
  static bool isFileClean(String filePath, int totalRuleCount) {
    final normalizedPath = normalizePath(filePath);
    final state = _state[normalizedPath];
    return state != null && state.passedRules.length >= totalRuleCount;
  }

  /// Clear all tracking data.
  static void clearCache() {
    _state.clear();
    _ruleConfigHash = null;
    _isDirty = true;
    saveToDisk(); // Persist the clear
  }

  // ===========================================================================
  // DISK PERSISTENCE
  // ===========================================================================

  /// Get the cache file path.
  static String? get _cacheFilePath {
    // Copy static field into local so promotion applies
    // (avoid_nullable_interpolation otherwise flags the interpolation).
    final root = _projectRoot;
    if (root == null) return null;
    return '$root/.dart_tool/$_cacheFileName';
  }

  /// Load cache from disk.
  ///
  /// Call this once at startup. Silently fails if no cache exists.
  static void loadFromDisk() {
    // Skip loading if cache is disabled
    if (_cacheDisabled) return;

    final path = _cacheFilePath;
    if (path == null) return;

    try {
      final file = File(path);
      if (!file.existsSync()) return;

      final content = file.readAsStringSync();
      final json = _parseJson(content);
      if (json == null) return;

      // Check version compatibility
      final version = json['version'] as int?;
      if (version != 1) {
        // Incompatible version - discard
        file.deleteSync();
        return;
      }

      // Check config hash - if different, cache is invalid
      final savedConfigHash = json['configHash'] as int?;
      if (savedConfigHash != null && _ruleConfigHash != null) {
        if (savedConfigHash != _ruleConfigHash) {
          // Config changed - discard cache
          return;
        }
      }

      // Load file states
      final files = json['files'] as Map<String, dynamic>?;
      if (files == null) return;

      _state.clear();
      for (final entry in files.entries) {
        final fileData = entry.value as Map<String, dynamic>?;
        if (fileData == null) continue;

        final contentHash = fileData['hash'] as int?;
        final rules = fileData['rules'] as List<dynamic>?;

        if (contentHash != null && rules != null) {
          _state[entry.key] = _FileAnalysisState(contentHash: contentHash)
            ..passedRules.addAll(rules.cast<String>());
        }
      }

      _isDirty = false;
      _changesSinceLastSave = 0;
    } on FormatException catch (e, st) {
      developer.log(
        'loadFromDisk cache parse failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Invalid cache file - ignore
    } on IOException catch (e, st) {
      developer.log(
        'loadFromDisk cache read failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Cannot read cache - ignore
    }
  }

  /// Save cache to disk.
  ///
  /// Call this periodically or when analysis completes.
  static void saveToDisk() {
    // Skip saving if cache is disabled
    if (_cacheDisabled) return;
    if (!_isDirty) return;

    final path = _cacheFilePath;
    if (path == null) return;

    try {
      final json = <String, dynamic>{
        'version': 1,
        'configHash': _ruleConfigHash,
        // Fix: prefer_utc_for_storage — state file is persisted and restored
        // across sessions/machines; UTC avoids timezone-shift confusion.
        'savedAt': DateTime.now().toUtc().toIso8601String(),
        'files': <String, dynamic>{
          for (final entry in _state.entries)
            entry.key: <String, dynamic>{
              'hash': entry.value.contentHash,
              'rules': entry.value.passedRules.toList(),
            },
        },
      };

      // Ensure .dart_tool directory exists. Use a non-null local copy of the
      // static nullable field (avoid_nullable_interpolation).
      final projectRoot = _projectRoot ?? '.';
      final dartToolDir = Directory('$projectRoot/.dart_tool');
      if (!dartToolDir.existsSync()) {
        dartToolDir.createSync(recursive: true);
      }

      // Write atomically (write to temp, then rename)
      final tempPath = '$path.tmp';
      final tempFile = File(tempPath);
      tempFile.writeAsStringSync(_toJson(json));
      tempFile.renameSync(path);

      _isDirty = false;
      _changesSinceLastSave = 0;
    } on IOException catch (e, st) {
      developer.log(
        'saveToDisk cache write failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Cannot write cache - ignore
    }
  }

  /// Parse JSON safely.
  static Map<String, dynamic>? _parseJson(String content) {
    try {
      // Simple JSON parsing without importing dart:convert in header
      // Uses a minimal approach for the cache format
      final trimmed = content.trim();
      if (!trimmed.startsWith('{')) return null;

      // For simplicity, we'll use a basic approach
      // In production, you'd want proper JSON parsing
      return _simpleJsonParse(trimmed);
    } on FormatException {
      return null;
    }
  }

  /// Simple JSON parser for cache format.
  static Map<String, dynamic>? _simpleJsonParse(String json) {
    // This is a simplified parser for our specific cache format
    // For robustness, consider using dart:convert
    try {
      // Remove outer braces and parse key-value pairs
      // This is intentionally simple - real impl would use dart:convert
      final result = <String, dynamic>{};

      // Match "key": value patterns
      final versionMatch = RegExp(r'"version":\s*(\d+)').firstMatch(json);
      final versionGroup = versionMatch?.group(1);
      if (versionGroup != null) {
        result['version'] = int.parse(versionGroup);
      }

      final configHashMatch = RegExp(
        r'"configHash":\s*(-?\d+)',
      ).firstMatch(json);
      final configHashGroup = configHashMatch?.group(1);
      if (configHashGroup != null) {
        result['configHash'] = int.parse(configHashGroup);
      }

      // Parse files section - this is complex, so we'll use a regex approach
      final filesMatch = RegExp(
        r'"files":\s*\{([^}]*(?:\{[^}]*\}[^}]*)*)\}',
      ).firstMatch(json);
      final filesContent = filesMatch?.group(1);
      if (filesContent != null) {
        final files = <String, dynamic>{};

        // Match each file entry: "path": {"hash": N, "rules": [...]}
        final filePattern = RegExp(
          r'"([^"]+)":\s*\{\s*"hash":\s*(-?\d+),\s*"rules":\s*\[([^\]]*)\]\s*\}',
        );

        final rulePattern = RegExp(r'"([^"]+)"');
        for (final match in filePattern.allMatches(filesContent)) {
          final pathPart = match.group(1);
          final hashGroup = match.group(2);
          final rulesStrPart = match.group(3);
          if (pathPart == null || hashGroup == null || rulesStrPart == null) {
            continue;
          }
          final path = pathPart;
          final hash = int.parse(hashGroup);
          final rulesStr = rulesStrPart;

          // Parse rules array
          final rules = <String>[];
          for (final ruleMatch in rulePattern.allMatches(rulesStr)) {
            final g = ruleMatch.group(1);
            if (g != null) rules.add(g);
          }

          files[path] = <String, dynamic>{'hash': hash, 'rules': rules};
        }

        result['files'] = files;
      }

      return result;
    } on FormatException {
      return null;
    }
  }

  /// Convert to JSON string.
  static String _toJson(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    _writeJson(buffer, data, 0);
    return buffer.toString();
  }

  static void _writeJson(StringBuffer buffer, dynamic value, int indent) {
    final spaces = '  ' * indent;
    final nextSpaces = '  ' * (indent + 1);

    if (value == null) {
      buffer.write('null');
    } else if (value is bool) {
      buffer.write(value.toString());
    } else if (value is num) {
      buffer.write(value.toString());
    } else if (value is String) {
      // Escape special characters
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r')
          .replaceAll('\t', '\\t');
      buffer.write('"$escaped"');
    } else if (value is List) {
      if (value.isEmpty) {
        buffer.write('[]');
      } else {
        buffer.writeln('[');
        for (var i = 0; i < value.length; i++) {
          buffer.write(nextSpaces);
          _writeJson(buffer, value[i], indent + 1);
          if (i < value.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$spaces]');
      }
    } else if (value is Map) {
      if (value.isEmpty) {
        buffer.write('{}');
      } else {
        buffer.writeln('{');
        final entries = value.entries.toList();
        for (var i = 0; i < entries.length; i++) {
          final entry = entries[i];
          buffer.write('$nextSpaces"${entry.key}": ');
          _writeJson(buffer, entry.value, indent + 1);
          if (i < entries.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$spaces}');
      }
    }
  }

  /// Get statistics about the cache.
  static Map<String, dynamic> getStats() {
    var totalRules = 0;
    for (final state in _state.values) {
      totalRules += state.passedRules.length;
    }

    return {
      'files': _state.length,
      'totalPassedRules': totalRules,
      'isDirty': _isDirty,
      'changesSinceLastSave': _changesSinceLastSave,
      'hasProjectRoot': _projectRoot != null,
    };
  }
}

class _FileAnalysisState {
  _FileAnalysisState({required this.contentHash});

  int contentHash;
  final Set<String> passedRules = {};
}

// =============================================================================
// RULE PRIORITY QUEUE (Performance Optimization)
// =============================================================================
//
// Sorts rules by cost so cheaper rules run first. This enables "fail fast"
// behavior - if a cheap rule finds violations, we can skip expensive rules
// in certain scenarios. Even without skipping, running cheap rules first
// provides faster initial feedback to developers.
// =============================================================================

/// Manages rule execution order for optimal performance.
///
/// Principles:
/// 1. Cheap rules first - provides faster initial feedback
/// 2. Fail-fast grouping - group related rules so failures skip related checks
/// 3. Content-aware ordering - reorder based on what patterns matched
class RulePriorityQueue {
  RulePriorityQueue._();

  static final Map<String, int> _rulePriority = {};

  /// Build priority index from rules.
  ///
  /// Priority is based on:
  /// 1. RuleCost (trivial=0, low=100, medium=200, high=300, extreme=400)
  /// 2. Pattern specificity (more patterns = lower priority)
  /// 3. Historical performance (TODO: track actual execution times)
  static void build(Iterable<RulePriorityInfo> rules) {
    _rulePriority.clear();

    for (final rule in rules) {
      final basePriority = _costToPriority(rule.cost);
      final patternAdjustment = (rule.patternCount) * 5;

      _rulePriority[rule.name] = basePriority + patternAdjustment;
    }
  }

  static int _costToPriority(RuleCost cost) {
    return switch (cost) {
      RuleCost.trivial => 0,
      RuleCost.low => 100,
      RuleCost.medium => 200,
      RuleCost.high => 300,
      RuleCost.extreme => 400,
    };
  }

  /// Sort rules by priority (lowest priority number runs first).
  static List<T> sortByPriority<T>(List<T> rules, String Function(T) getName) {
    return [...rules]..sort((a, b) {
      final pa = _rulePriority[getName(a)] ?? 200;
      final pb = _rulePriority[getName(b)] ?? 200;
      return pa.compareTo(pb);
    });
  }

  /// Get priority for a rule (lower = runs first).
  static int getPriority(String ruleName) {
    return _rulePriority[ruleName] ?? 200;
  }

  /// Clear the priority index.
  static void clear() {
    _rulePriority.clear();
  }
}

/// Information for building rule priority.
class RulePriorityInfo {
  const RulePriorityInfo({
    required this.name,
    required this.cost,
    required this.patternCount,
  });

  final String name;
  final RuleCost cost;
  final int patternCount;
}

// =============================================================================
// CONTENT REGION INDEX (Performance Optimization)
// =============================================================================
//
// Indexes content into regions (imports, class declarations, function bodies)
// so rules can scan only relevant portions. A rule checking imports doesn't
// need to scan function bodies, and vice versa.
// =============================================================================

/// Pre-indexed content regions for targeted scanning.
class ContentRegions {
  const ContentRegions({
    required this.importRegion,
    required this.classDeclarations,
    required this.topLevelCode,
    required this.hasMain,
  });

  /// Lines containing import/export statements.
  final String importRegion;

  /// Class declaration headers (just the "class X extends Y" parts).
  final List<String> classDeclarations;

  /// Top-level code outside of classes.
  final String topLevelCode;

  /// Whether file has a main() function.
  final bool hasMain;
}

/// Indexes file content into regions for targeted rule scanning.
class ContentRegionIndex {
  ContentRegionIndex._();

  static final Map<String, ContentRegions> _cache = {};

  /// Get indexed regions for a file.
  static ContentRegions get(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    return _cache.putIfAbsent(normalizedPath, () => _index(content));
  }

  static ContentRegions _index(String content) {
    final lines = content.split('\n');
    final importLines = <String>[];
    final classDeclarations = <String>[];
    final topLevelLines = <String>[];

    var hasMain = false;
    var inClassBody = false;
    var braceDepth = 0;

    for (final line in lines) {
      final trimmed = line.trimLeft();

      // Track import region
      if (trimmed.startsWith('import ') || trimmed.startsWith('export ')) {
        importLines.add(line);
        continue;
      }

      // Track main function
      if (trimmed.contains('void main(') || trimmed.contains('main()')) {
        hasMain = true;
      }

      // Track class declarations
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ') ||
          trimmed.startsWith('mixin ') ||
          trimmed.startsWith('extension ')) {
        classDeclarations.add(trimmed.split('{').first.trim());
        inClassBody = true;
        braceDepth = 1;
        continue;
      }

      // Track brace depth for class body detection
      if (inClassBody) {
        braceDepth += '{'.allMatches(line).length;
        braceDepth -= '}'.allMatches(line).length;
        if (braceDepth <= 0) {
          inClassBody = false;
        }
      } else {
        topLevelLines.add(line);
      }
    }

    return ContentRegions(
      importRegion: importLines.join('\n'),
      classDeclarations: classDeclarations,
      topLevelCode: topLevelLines.join('\n'),
      hasMain: hasMain,
    );
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
  }

  /// Clear all cached regions.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
