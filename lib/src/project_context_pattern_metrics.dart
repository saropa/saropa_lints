part of 'project_context.dart';

// =============================================================================
// RULE COST CLASSIFICATION (Performance Optimization)
// =============================================================================
//
// Each rule declares its own cost via the `cost` getter in SaropaLintRule.
// Fast rules run first, slow rules run last.
// =============================================================================

/// Estimated cost of running a rule.
///
/// Rules override the `cost` getter in SaropaLintRule to declare their cost.
/// The framework sorts rules by cost before execution.
enum RuleCost {
  /// Very fast rules (simple pattern matching)
  /// Examples: check for specific method name, check for parameter
  trivial,

  /// Fast rules (single AST node inspection)
  /// Examples: check constructor parameters, check method signature
  low,

  /// Medium cost rules (traverse part of AST) - DEFAULT
  /// Examples: check method body, check class members
  medium,

  /// High cost rules (traverse full AST or type resolution)
  /// Examples: check for circular dependencies, complex type analysis
  high,

  /// Very expensive rules (cross-file analysis simulation)
  /// Examples: check imports across project, dependency graph
  extreme,
}

// =============================================================================
// COMBINED PATTERN INDEX (Performance Optimization)
// =============================================================================
//
// Instead of each rule scanning for its patterns individually, we build a
// combined index once and scan the file content ONCE to determine which rules
// can skip. This reduces O(rules × patterns × content) to O(patterns × content).
//
// For 1400+ rules with an average of 2 patterns each, this is a 1400x speedup
// for the pattern-matching phase.
// =============================================================================

/// Builds and manages a combined pattern index for fast rule filtering.
///
/// Usage:
/// ```dart
/// // Build index from all enabled rules (once at startup)
/// PatternIndex.build(enabledRules);
///
/// // For each file, scan once to get matching rules
/// final matchingRules = PatternIndex.getMatchingRules(content);
///
/// // Only run rules that match
/// for (final rule in matchingRules) { ... }
/// ```
class PatternIndex {
  PatternIndex._();

  // Map of pattern -> set of rule names that require it
  static final Map<String, Set<String>> _patternToRules = {};

  // Set of rules with no patterns (always run)
  static final Set<String> _rulesWithNoPatterns = {};

  // Cached list of all patterns for fast iteration
  static List<String>? _allPatterns;

  // LRU cache of bloom filters for recently analyzed content
  static final LruCache<int, BloomFilter> _bloomCache = LruCache(maxSize: 200);

  /// Build the pattern index from enabled rules.
  ///
  /// Call this once when the plugin initializes with the filtered rule list.
  /// Rules that declare `requiredPatterns` will be indexed; rules without
  /// patterns are tracked separately and always run.
  static void build(Iterable<RulePatternInfo> rules) {
    _patternToRules.clear();
    _rulesWithNoPatterns.clear();
    _allPatterns = null;

    for (final rule in rules) {
      final patterns = rule.patterns;
      if (patterns == null || patterns.isEmpty) {
        _rulesWithNoPatterns.add(rule.name);
      } else {
        for (final pattern in patterns) {
          _patternToRules.putIfAbsent(pattern, () => {}).add(rule.name);
        }
      }
    }

    _allPatterns = _patternToRules.keys.toList();
  }

  /// Get the set of rule names that should run on this content.
  ///
  /// Uses a bloom filter for O(1) pre-screening of patterns, then
  /// confirms matches with actual string search. Returns rules that either:
  /// - Have no patterns (always run)
  /// - Have at least one matching pattern in the content
  static Set<String> getMatchingRules(String content) {
    final matching = <String>{..._rulesWithNoPatterns};

    final patterns = _allPatterns;
    if (patterns == null || patterns.isEmpty) {
      return matching;
    }

    // Get or create bloom filter for this content
    final contentHash = content.hashCode;
    var bloom = _bloomCache.get(contentHash);
    if (bloom == null) {
      bloom = BloomFilter();
      bloom.addAllTokens(content);
      _bloomCache.put(contentHash, bloom);
    }

    // Use bloom filter for fast pre-screening, then confirm with contains()
    for (final pattern in patterns) {
      // Bloom filter: O(1) check - if false, definitely not present
      if (!bloom.mightContain(pattern)) continue;

      // Bloom filter said "maybe" - confirm with actual search
      if (content.contains(pattern)) {
        final rules = _patternToRules[pattern];
        if (rules != null) {
          matching.addAll(rules);
        }
      }
    }

    return matching;
  }

  /// Check if a specific rule should run based on pattern matching.
  ///
  /// Uses bloom filter for O(1) pre-screening when available.
  /// Returns true if the rule has no patterns OR has a matching pattern.
  static bool shouldRuleRun(String ruleName, String content) {
    if (_rulesWithNoPatterns.contains(ruleName)) return true;

    // Get or create bloom filter for this content
    final contentHash = content.hashCode;
    var bloom = _bloomCache.get(contentHash);
    if (bloom == null) {
      bloom = BloomFilter();
      bloom.addAllTokens(content);
      _bloomCache.put(contentHash, bloom);
    }

    // Find patterns for this rule, using bloom filter pre-screening
    for (final entry in _patternToRules.entries) {
      if (entry.value.contains(ruleName)) {
        // Bloom filter: O(1) check
        if (!bloom.mightContain(entry.key)) continue;
        // Confirm with actual search
        if (content.contains(entry.key)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check if the index is built.
  static bool get isBuilt => _allPatterns != null;

  /// Clear the index (useful for testing).
  static void clear() {
    _patternToRules.clear();
    _rulesWithNoPatterns.clear();
    _allPatterns = null;
  }
}

/// Information about a rule's patterns for index building.
class RulePatternInfo {
  const RulePatternInfo({required this.name, required this.patterns});

  final String name;
  final Set<String>? patterns;
}

// =============================================================================
// FILE METRICS CACHE (Performance Optimization)
// =============================================================================
//
// Caches computed file metrics (line count, complexity indicators, etc.)
// to avoid re-computing them for each rule. Many rules check similar metrics.
// =============================================================================

/// Cached metrics about a file's content.
///
/// Computed once per file and reused across all rules.
class FileMetrics {
  const FileMetrics({
    required this.lineCount,
    required this.characterCount,
    required this.importCount,
    required this.classCount,
    required this.functionCount,
    required this.hasAsyncCode,
    required this.hasWidgets,
    required this.hasFlutterImport,
    required this.hasBlocImport,
    required this.hasProviderImport,
    required this.hasRiverpodImport,
  });

  final int lineCount;
  final int characterCount;
  final int importCount;
  final int classCount;
  final int functionCount;
  final bool hasAsyncCode;
  final bool hasWidgets;

  /// Whether file imports package:flutter/
  final bool hasFlutterImport;

  /// Whether file imports package:bloc/ or package:flutter_bloc/
  final bool hasBlocImport;

  /// Whether file imports package:provider/
  final bool hasProviderImport;

  /// Whether file imports package:riverpod/ or package:flutter_riverpod/
  final bool hasRiverpodImport;

  /// Fast complexity estimation without full AST parsing.
  bool get isLikelyComplex =>
      lineCount > 200 || classCount > 3 || functionCount > 10;

  /// Check if file is tiny (likely a model, enum, or simple utility).
  bool get isTiny => lineCount < 20 && classCount <= 1;
}

/// Computes and caches file metrics for fast access.
class FileMetricsCache {
  FileMetricsCache._();

  static final Map<String, FileMetrics> _cache = {};

  /// Get metrics for a file, computing if not cached.
  static FileMetrics get(String filePath, String content) {
    final normalizedPath = normalizePath(filePath);
    return _cache.putIfAbsent(normalizedPath, () => _compute(content));
  }

  /// Compute metrics from content (fast regex-based, not AST).
  static FileMetrics _compute(String content) {
    // Line count: count newlines
    var lineCount = 1;
    var importCount = 0;
    var classCount = 0;
    var functionCount = 0;

    final lines = content.split('\n');
    lineCount = lines.length;

    final functionPattern = RegExp(r'^\s*\w+\s+\w+\s*\(');
    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ')) importCount++;
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ')) {
        classCount++;
      }
      if (trimmed.contains(' Function') || functionPattern.hasMatch(line)) {
        functionCount++;
      }
    }

    // Package import detection (single pass through content)
    final hasFlutterImport = content.contains('package:flutter/');
    final hasBlocImport =
        content.contains('package:bloc/') ||
        content.contains('package:flutter_bloc/');
    final hasProviderImport = content.contains('package:provider/');
    final hasRiverpodImport =
        content.contains('package:riverpod/') ||
        content.contains('package:flutter_riverpod/') ||
        content.contains('package:hooks_riverpod/');

    return FileMetrics(
      lineCount: lineCount,
      characterCount: content.length,
      importCount: importCount,
      classCount: classCount,
      functionCount: functionCount,
      hasAsyncCode: content.contains('async') || content.contains('Future'),
      hasWidgets: content.contains('Widget') || content.contains('State<'),
      hasFlutterImport: hasFlutterImport,
      hasBlocImport: hasBlocImport,
      hasProviderImport: hasProviderImport,
      hasRiverpodImport: hasRiverpodImport,
    );
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _cache.remove(normalizedPath);
  }

  /// Clear all cached metrics.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// SMART CONTENT FILTER (Performance Optimization)
// =============================================================================
//
// Uses multiple quick heuristics to skip rules that definitely won't apply.
// This is faster than AST parsing and catches obvious mismatches.
// =============================================================================

/// Quick content-based filtering to skip rules early.
///
/// Combines multiple heuristics for maximum filtering before AST parsing:
/// - Required patterns (string contains)
/// - Minimum/maximum line counts
/// - Required keywords (class, async, etc.)
/// - File type indicators
class SmartContentFilter {
  SmartContentFilter._();

  /// Check if a rule should potentially run based on content heuristics.
  ///
  /// Returns `false` if the rule definitely won't find anything.
  /// Returns `true` if the rule might find violations (needs AST check).
  ///
  /// **WARNING**: [maximumLines] skips analysis on large files. Only use
  /// for rules with O(n²) complexity. Large files often need linting most!
  static bool mightApply({
    required String content,
    required String filePath,
    Set<String>? requiredPatterns,
    int minimumLines = 0,
    int maximumLines = 0,
    Set<String>? requiredKeywords,
    bool isAsyncRequired = false,
    bool isWidgetsRequired = false,
  }) {
    final metrics = FileMetricsCache.get(filePath, content);

    // Check minimum line count (skip tiny files for complex rules)
    if (minimumLines > 0 && metrics.lineCount < minimumLines) return false;

    // Check maximum line count (DANGEROUS - skips analysis!)
    if (maximumLines > 0 && metrics.lineCount > maximumLines) return false;

    // Check async requirement
    if (isAsyncRequired && !metrics.hasAsyncCode) return false;

    // Check widget requirement
    if (isWidgetsRequired && !metrics.hasWidgets) return false;

    // Check required patterns (any must match)
    if (requiredPatterns != null && requiredPatterns.isNotEmpty) {
      if (!requiredPatterns.any((p) => content.contains(p))) return false;
    }

    // Check required keywords (all must match)
    if (requiredKeywords != null && requiredKeywords.isNotEmpty) {
      if (!requiredKeywords.every((k) => content.contains(k))) return false;
    }

    return true;
  }
}
