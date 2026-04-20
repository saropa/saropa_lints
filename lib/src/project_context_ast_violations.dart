part of 'project_context.dart';

// AST NODE TYPE REGISTRY (Performance Optimization)
// =============================================================================
//
// Groups rules by which AST node types they visit. Instead of each rule
// registering its own visitor callbacks, we batch all rules that care about
// the same node type and invoke them together. This reduces the overhead of
// AST traversal significantly.
// =============================================================================

/// Types of AST nodes that rules commonly care about.
enum AstNodeCategory {
  /// Import/export declarations
  imports,

  /// Class declarations (class, mixin, extension)
  classDecl,

  /// Method/function declarations
  functions,

  /// Variable/field declarations
  variables,

  /// Constructor declarations
  constructors,

  /// Method invocations (calls)
  invocations,

  /// Literal expressions (strings, numbers, lists, maps)
  literals,

  /// Control flow (if, for, while, switch)
  controlFlow,

  /// Try/catch/finally blocks
  errorHandling,

  /// Async-related (async, await, Future)
  asyncCode,

  /// Annotations/metadata
  annotations,

  /// Full compilation unit (whole file)
  compilationUnit,
}

/// Tracks which rules care about which AST node types.
///
/// This allows the framework to batch rule invocations by node type,
/// reducing AST traversal overhead.
class AstNodeTypeRegistry {
  AstNodeTypeRegistry._();

  static final Map<AstNodeCategory, Set<String>> _categoryToRules = {};
  static final Map<String, Set<AstNodeCategory>> _ruleToCategories = {};

  /// Register which categories a rule cares about.
  static void register(String ruleName, Set<AstNodeCategory> categories) {
    _ruleToCategories[ruleName] = categories;

    for (final category in categories) {
      _categoryToRules.putIfAbsent(category, () => {}).add(ruleName);
    }
  }

  /// Get all rules that care about a specific node category.
  static Set<String> getRulesForCategory(AstNodeCategory category) {
    return _categoryToRules[category] ?? {};
  }

  /// Get all categories a rule cares about.
  static Set<AstNodeCategory> getCategoriesForRule(String ruleName) {
    return _ruleToCategories[ruleName] ?? {};
  }

  /// Check if a rule cares about a specific category.
  static bool ruleCaresAbout(String ruleName, AstNodeCategory category) {
    return _ruleToCategories[ruleName]?.contains(category) ?? false;
  }

  /// Check if ANY enabled rule cares about a category.
  ///
  /// If no rules care about a category, we can skip that part of AST traversal.
  static bool anyCareAbout(AstNodeCategory category) {
    final rules = _categoryToRules[category];
    return rules != null && rules.isNotEmpty;
  }

  /// Clear all registrations.
  static void clear() {
    _categoryToRules.clear();
    _ruleToCategories.clear();
  }
}

// =============================================================================
// VIOLATION BATCH REPORTER (Performance Optimization)
// =============================================================================
//
// Batches violation reports to reduce I/O overhead. Instead of reporting
// each violation immediately, we collect them and flush in batches.
// =============================================================================

/// Batches violations for more efficient reporting.
class ViolationBatch {
  ViolationBatch._();

  static final List<_BatchedViolation> _pending = [];
  static const int _batchSize = 50;

  /// Queue a violation for batched reporting.
  static void add({
    required String filePath,
    required String ruleName,
    required int offset,
    required int length,
    required String message,
    required String? correction,
  }) {
    _pending.add(
      _BatchedViolation(
        filePath: filePath,
        ruleName: ruleName,
        offset: offset,
        length: length,
        message: message,
        correction: correction,
      ),
    );

    // Auto-flush when batch is full
    if (_pending.length >= _batchSize) {
      flush();
    }
  }

  /// Flush all pending violations.
  ///
  /// Call this at the end of each file analysis or when switching files.
  static List<_BatchedViolation> flush() {
    if (_pending.isEmpty) return [];

    final batch = List<_BatchedViolation>.from(_pending);
    _pending.clear();
    return batch;
  }

  /// Get count of pending violations.
  static int get pendingCount => _pending.length;

  /// Clear all pending without reporting.
  static void clear() {
    _pending.clear();
  }
}

class _BatchedViolation {
  const _BatchedViolation({
    required this.filePath,
    required this.ruleName,
    required this.offset,
    required this.length,
    required this.message,
    required this.correction,
  });

  final String filePath;
  final String ruleName;
  final int offset;
  final int length;
  final String message;
  final String? correction;
}

// =============================================================================
// CONTENT FINGERPRINT (Performance Optimization)
// =============================================================================
//
// Creates a quick "fingerprint" of file content for fast similarity detection.
// Files with identical fingerprints are very likely to have the same violations.
// This enables caching analysis results across similar files.
// =============================================================================

/// Fast content fingerprint for quick similarity detection.
///
/// Two files with the same fingerprint are likely to have similar structure,
/// even if their content differs in details. This enables:
/// - Caching analysis results across similar files
/// - Quick "skip if similar file was clean" optimization
class ContentFingerprint {
  ContentFingerprint._();

  static final Map<String, int> _cache = {};

  /// Compute fingerprint for content.
  ///
  /// The fingerprint captures structural characteristics:
  /// - Import count
  /// - Class count
  /// - Whether it has async code
  /// - Whether it has widgets
  /// - Approximate size bucket
  static int compute(String filePath, String content) {
    return _cache.putIfAbsent(filePath, () => _computeFingerprint(content));
  }

  static int _computeFingerprint(String content) {
    final lines = content.split('\n');
    final lineCount = lines.length;

    // Count structural elements
    var importCount = 0;
    var classCount = 0;
    var hasAsync = false;
    var hasWidget = false;

    for (final line in lines) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('import ')) importCount++;
      if (trimmed.startsWith('class ') ||
          trimmed.startsWith('abstract class ')) {
        classCount++;
      }
      if (!hasAsync && (line.contains('async') || line.contains('Future'))) {
        hasAsync = true;
      }
      if (!hasWidget && (line.contains('Widget') || line.contains('State<'))) {
        hasWidget = true;
      }
    }

    // Create fingerprint from characteristics
    // Size bucket: 0=tiny(<50), 1=small(<200), 2=medium(<500), 3=large(<1000), 4=huge
    final sizeBucket = lineCount < 50
        ? 0
        : lineCount < 200
        ? 1
        : lineCount < 500
        ? 2
        : lineCount < 1000
        ? 3
        : 4;

    return Object.hash(
      importCount.clamp(0, 20), // Cap at 20 imports
      classCount.clamp(0, 10), // Cap at 10 classes
      hasAsync,
      hasWidget,
      sizeBucket,
    );
  }

  /// Check if two files have the same fingerprint.
  static bool areSimilar(
    String path1,
    String content1,
    String path2,
    String content2,
  ) {
    return compute(path1, content1) == compute(path2, content2);
  }

  /// Invalidate cached fingerprint.
  static void invalidate(String filePath) {
    _cache.remove(filePath);
  }

  /// Clear all cached fingerprints.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
// RULE DEPENDENCY GRAPH (Performance Optimization)
// =============================================================================
//
// Tracks dependencies between rules. If rule A depends on rule B, and B finds
// violations, we might want to skip A (since the code needs fixing anyway).
// This enables "fail fast" optimization chains.
// =============================================================================

/// Tracks rule dependencies for fail-fast optimization.
///
/// Some rules are naturally dependent:
/// - If `avoid_mutable_global_variables` fires, skip `prefer_const` checks
/// - If `missing_dispose` fires, skip `dispose_order` checks
///
/// This allows skipping downstream rules when upstream rules find issues.
class RuleDependencyGraph {
  RuleDependencyGraph._();

  // Map of rule -> rules that depend on it
  static final Map<String, Set<String>> _dependents = {};

  // Map of rule -> rules it depends on
  static final Map<String, Set<String>> _dependencies = {};

  /// Declare that [dependent] depends on [prerequisite].
  ///
  /// If [prerequisite] finds violations, [dependent] can be skipped.
  static void addDependency(String dependent, String prerequisite) {
    _dependencies.putIfAbsent(dependent, () => {}).add(prerequisite);
    _dependents.putIfAbsent(prerequisite, () => {}).add(dependent);
  }

  /// Get rules that should be skipped if [rule] found violations.
  static Set<String> getDependents(String rule) {
    return _dependents[rule] ?? {};
  }

  /// Get prerequisites for a rule.
  static Set<String> getPrerequisites(String rule) {
    return _dependencies[rule] ?? {};
  }

  /// Check if [rule] should be skipped based on prerequisite violations.
  static bool shouldSkip(String rule, Set<String> rulesWithViolations) {
    final prereqs = _dependencies[rule];
    if (prereqs == null || prereqs.isEmpty) return false;

    // Skip if ANY prerequisite has violations
    return prereqs.any((p) => rulesWithViolations.contains(p));
  }

  /// Clear all dependencies.
  static void clear() {
    _dependents.clear();
    _dependencies.clear();
  }
}

// =============================================================================
// RULE EXECUTION STATS (Performance Optimization)
// =============================================================================
//
// Tracks historical execution statistics for rules. This data enables:
// - Dynamic priority adjustment (slow rules get deprioritized)
// - Skip analysis of rules that rarely find anything
// - Identify rules that need optimization
// =============================================================================

/// Tracks rule execution statistics over time.
///
/// Used for dynamic optimization decisions based on actual performance data.
class RuleExecutionStats {
  RuleExecutionStats._();

  static final Map<String, _RuleStats> _stats = {};

  /// Record a rule execution.
  static void record({
    required String ruleName,
    required Duration elapsed,
    required bool foundViolations,
  }) {
    final stats = _stats.putIfAbsent(ruleName, () => _RuleStats());
    stats.executionCount++;
    stats.totalTime += elapsed;
    if (foundViolations) stats.violationCount++;
  }

  /// Get average execution time for a rule.
  static Duration getAverageTime(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount == 0) {
      return Duration.zero;
    }
    return stats.totalTime ~/ stats.executionCount;
  }

  /// Get violation rate for a rule (0.0 to 1.0).
  static double getViolationRate(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount == 0) return 0.0;
    return stats.violationCount / stats.executionCount;
  }

  /// Check if a rule rarely finds violations (candidate for lazy execution).
  ///
  /// A rule with <5% hit rate over 100+ executions is rarely useful.
  static bool rarelyFindsViolations(String ruleName) {
    final stats = _stats[ruleName];
    if (stats == null || stats.executionCount < 100) return false;
    return getViolationRate(ruleName) < 0.05;
  }

  /// Check if a rule is slow (>50ms average).
  static bool isSlow(String ruleName) {
    return getAverageTime(ruleName).inMilliseconds > 50;
  }

  /// Get all slow rules for optimization review.
  static List<String> getSlowRules() {
    return _stats.entries
        .where((e) => e.value.executionCount > 10)
        .where(
          (e) =>
              (e.value.totalTime ~/ e.value.executionCount).inMilliseconds > 50,
        )
        .map((e) => e.key)
        .toList();
  }

  /// Clear all stats.
  static void clearStats() {
    _stats.clear();
  }
}

class _RuleStats {
  int executionCount = 0;
  int violationCount = 0;
  Duration totalTime = Duration.zero;
}

// =============================================================================
// LAZY PATTERN COMPILER (Performance Optimization)
// =============================================================================
//
// Compiles regex patterns lazily on first use. Many rules have patterns that
// are never actually needed (if early filtering skips the rule). This avoids
// paying the regex compilation cost upfront.
// =============================================================================

/// Lazily compiled regex patterns.
///
/// Regex compilation is expensive. This class defers compilation until
/// the pattern is actually used, avoiding unnecessary work for rules
/// that get skipped by early filtering.
class LazyPattern {
  LazyPattern(this._pattern);

  final String _pattern;
  RegExp? _compiled;

  /// Get the compiled regex (compiles on first access).
  RegExp get regex => _compiled ??= RegExp(_pattern);

  /// Check if pattern matches (compiles lazily).
  bool hasMatch(String input) => regex.hasMatch(input);

  /// Find all matches (compiles lazily).
  Iterable<RegExpMatch> allMatches(String input) => regex.allMatches(input);

  /// Check if already compiled.
  bool get isCompiled => _compiled != null;
}

/// Cache of lazily compiled patterns.
///
/// Fix: avoid_unbounded_cache_growth — the pattern set is bounded by the
/// static regex literals rules compile from (hundreds, not millions), but
/// [_maxEntries] adds a hard ceiling that evicts the whole cache on overflow
/// so runaway string inputs cannot grow the map indefinitely.
class LazyPatternCache {
  LazyPatternCache._();

  static const int _maxEntries = 2048;
  static final Map<String, LazyPattern> _cache = {};

  /// Get a lazily compiled pattern.
  static LazyPattern get(String pattern) {
    if (_cache.length >= _maxEntries && !_cache.containsKey(pattern)) {
      // Bounded: clear everything when we hit the ceiling rather than add
      // a new entry unchecked. Callers re-populate from known regex literals.
      _cache.clear();
    }
    return _cache.putIfAbsent(pattern, () => LazyPattern(pattern));
  }

  /// Pre-compile patterns that are known to be frequently used.
  static void precompile(Iterable<String> patterns) {
    for (final pattern in patterns) {
      // Fix: avoid_unnecessary_statements — bind the eager compilation side
      // effect to a variable so its purpose (forcing .regex construction) is
      // explicit rather than a bare property read.
      final _ = get(pattern).regex;
    }
  }

  /// Get count of compiled patterns.
  static int get compiledCount =>
      _cache.values.where((p) => p.isCompiled).length;

  /// Clear the cache.
  static void clearCache() {
    _cache.clear();
  }
}

// =============================================================================
