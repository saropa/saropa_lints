part of 'project_context.dart';

// =============================================================================
// CONSOLIDATED VISITOR DISPATCH (Performance Optimization #3)
// =============================================================================
//
// Instead of each rule registering its own visitor callbacks (causing multiple
// AST traversals), we create a dispatch system where:
// 1. Rules register which AST node types they care about
// 2. A single traversal visits each node once
// 3. The dispatcher invokes all interested rules for each node
//
// This reduces O(rules × nodes) to O(nodes) for traversal overhead.
// =============================================================================

/// Callback type for consolidated node visitors.
typedef NodeVisitCallback = void Function(dynamic node, String filePath);

/// Manages consolidated AST visitor dispatch.
///
/// Usage:
/// ```dart
/// // Register rules at startup
/// ConsolidatedVisitorDispatch.register(
///   ruleName: 'avoid_print',
///   nodeTypes: {AstNodeCategory.invocations},
///   callback: (node, path) => checkPrint(node),
/// );
///
/// // During analysis, dispatch to all rules
/// ConsolidatedVisitorDispatch.dispatch(
///   category: AstNodeCategory.invocations,
///   node: methodInvocation,
///   filePath: currentFile,
/// );
/// ```
class ConsolidatedVisitorDispatch {
  ConsolidatedVisitorDispatch._();

  // Map of node category -> list of (ruleName, callback)
  static final Map<AstNodeCategory, List<_RegisteredCallback>> _callbacks = {};

  // Track which rules are registered
  static final Set<String> _registeredRules = {};

  /// Register a rule's callback for specific node types.
  static void register({
    required String ruleName,
    required Set<AstNodeCategory> nodeTypes,
    required NodeVisitCallback callback,
  }) {
    if (_registeredRules.contains(ruleName)) return; // Already registered
    _registeredRules.add(ruleName);

    for (final category in nodeTypes) {
      _callbacks
          .putIfAbsent(category, () => [])
          .add(_RegisteredCallback(ruleName: ruleName, callback: callback));
    }
  }

  /// Dispatch a node to all interested rules.
  ///
  /// Returns the number of callbacks invoked.
  static int dispatch({
    required AstNodeCategory category,
    required dynamic node,
    required String filePath,
  }) {
    final callbacks = _callbacks[category];
    if (callbacks == null || callbacks.isEmpty) return 0;

    var count = 0;
    for (final cb in callbacks) {
      // Check if rule should run on this file (via batch executor)
      if (RuleBatchExecutor.shouldRuleRunOnFile(cb.ruleName, filePath)) {
        cb.callback(node, filePath);
        count++;
      }
    }
    return count;
  }

  /// Check if any rules are registered for a category.
  static bool hasCallbacksFor(AstNodeCategory category) {
    final callbacks = _callbacks[category];
    return callbacks != null && callbacks.isNotEmpty;
  }

  /// Get count of registered rules.
  static int get registeredRuleCount => _registeredRules.length;

  /// Get count of callbacks per category.
  static Map<AstNodeCategory, int> get callbackCounts {
    return {
      for (final entry in _callbacks.entries) entry.key: entry.value.length,
    };
  }

  /// Clear all registrations.
  static void clear() {
    _callbacks.clear();
    _registeredRules.clear();
  }
}

class _RegisteredCallback {
  const _RegisteredCallback({required this.ruleName, required this.callback});

  final String ruleName;
  final NodeVisitCallback callback;
}

// =============================================================================
// BASELINE-AWARE EARLY EXIT (Performance Optimization #4)
// =============================================================================
//
// If ALL potential violations in a file are already baselined (suppressed),
// we can skip running the rule entirely. This requires:
// 1. Pre-computing which rules have baselined violations per file
// 2. Checking if a rule's violations would all be suppressed
// =============================================================================

/// Tracks baselined violations for early exit optimization.
///
/// If all of a rule's potential violations in a file are baselined,
/// we can skip running the rule entirely.
class BaselineAwareEarlyExit {
  BaselineAwareEarlyExit._();

  // Map of file path -> set of rules with ALL violations baselined
  static final Map<String, Set<String>> _fullyBaselinedRules = {};

  // Map of file path -> map of rule name -> count of baselined violations
  static final Map<String, Map<String, int>> _baselinedViolationCounts = {};

  /// Record that a violation is baselined.
  static void recordBaselinedViolation(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _baselinedViolationCounts
        .putIfAbsent(normalizedPath, () => {})
        .update(ruleName, (c) => c + 1, ifAbsent: () => 1);
  }

  /// Mark a rule as fully baselined for a file.
  ///
  /// Call this when you determine that ALL violations of a rule in a file
  /// are covered by baseline (e.g., path-based baseline covers entire file).
  static void markFullyBaselined(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    _fullyBaselinedRules.putIfAbsent(normalizedPath, () => {}).add(ruleName);
  }

  /// Check if a rule can be skipped for a file due to baseline.
  ///
  /// Returns true if the rule is fully baselined for this file.
  static bool canSkipRule(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _fullyBaselinedRules[normalizedPath]?.contains(ruleName) ?? false;
  }

  /// Get count of baselined violations for a rule in a file.
  static int getBaselinedCount(String filePath, String ruleName) {
    final normalizedPath = normalizePath(filePath);
    return _baselinedViolationCounts[normalizedPath]?[ruleName] ?? 0;
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    final normalizedPath = normalizePath(filePath);
    _fullyBaselinedRules.remove(normalizedPath);
    _baselinedViolationCounts.remove(normalizedPath);
  }

  /// Clear all cached data.
  static void clearCache() {
    _fullyBaselinedRules.clear();
    _baselinedViolationCounts.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalBaselined = 0;
    for (final counts in _baselinedViolationCounts.values) {
      for (final count in counts.values) {
        totalBaselined += count;
      }
    }

    return {
      'filesWithBaselinedRules': _fullyBaselinedRules.length,
      'totalBaselinedViolations': totalBaselined,
    };
  }
}

// =============================================================================
// DIFF-BASED ANALYSIS (Performance Optimization #5)
// =============================================================================
//
// Only re-analyze changed regions of a file. If only lines 50-60 changed,
// rules that don't touch those lines can be skipped. This requires:
// 1. Tracking which lines changed between analysis runs
// 2. Mapping AST nodes to line ranges
// 3. Skipping rules whose scope doesn't overlap with changes
// =============================================================================

/// Represents a range of lines in a file.
class LineRange {
  const LineRange(this.start, this.end);

  final int start;
  final int end;

  /// Check if this range overlaps with another.
  bool overlaps(LineRange other) {
    return start <= other.end && end >= other.start;
  }

  /// Check if this range contains a specific line.
  bool containsLine(int line) {
    return line >= start && line <= end;
  }

  /// Merge with another range (returns union).
  LineRange merge(LineRange other) {
    return LineRange(
      start < other.start ? start : other.start,
      end > other.end ? end : other.end,
    );
  }

  @override
  String toString() => '$start-$end';
}

/// Tracks changed regions for diff-based analysis.
///
/// Usage:
/// ```dart
/// // Record changes when file is modified
/// DiffBasedAnalysis.recordChanges(filePath, [LineRange(50, 60)]);
///
/// // Check if a rule needs to run based on its scope
/// if (!DiffBasedAnalysis.needsAnalysis(filePath, ruleScope)) {
///   return; // Skip - changes don't affect this rule's scope
/// }
/// ```
class DiffBasedAnalysis {
  DiffBasedAnalysis._();

  // Map of file path -> list of changed line ranges
  static final Map<String, List<LineRange>> _changedRegions = {};

  // Map of file path -> previous content (for diff computation)
  static final Map<String, String> _previousContent = {};

  /// Record changed regions in a file.
  static void recordChanges(String filePath, List<LineRange> changes) {
    if (changes.isEmpty) {
      _changedRegions.remove(filePath);
    } else {
      _changedRegions[filePath] = _mergeOverlapping(changes);
    }
  }

  /// Compute changes between previous and current content.
  ///
  /// Returns list of changed line ranges. Updates internal cache.
  static List<LineRange> computeChanges(
    String filePath,
    String currentContent,
  ) {
    final previous = _previousContent[filePath];
    _previousContent[filePath] = currentContent;

    if (previous == null) {
      // First time seeing this file - consider all lines changed
      final lineCount = '\n'.allMatches(currentContent).length + 1;
      final changes = [LineRange(1, lineCount)];
      _changedRegions[filePath] = changes;
      return changes;
    }

    if (previous == currentContent) {
      // No changes
      _changedRegions.remove(filePath);
      return [];
    }

    // Compute diff (simple line-by-line comparison)
    final changes = _computeLineDiff(previous, currentContent);
    if (changes.isNotEmpty) {
      _changedRegions[filePath] = changes;
    } else {
      _changedRegions.remove(filePath);
    }
    return changes;
  }

  /// Check if a rule needs to run based on its scope.
  ///
  /// [ruleScope] is the line range that the rule checks.
  /// Returns true if the rule's scope overlaps with any changed region.
  static bool needsAnalysis(String filePath, LineRange ruleScope) {
    final changes = _changedRegions[filePath];
    if (changes == null || changes.isEmpty) {
      return false; // No changes recorded
    }

    return changes.any((change) => change.overlaps(ruleScope));
  }

  /// Check if any part of the file changed.
  static bool hasChanges(String filePath) {
    final changes = _changedRegions[filePath];
    return changes != null && changes.isNotEmpty;
  }

  /// Get changed regions for a file.
  static List<LineRange> getChangedRegions(String filePath) {
    return _changedRegions[filePath] ?? [];
  }

  /// Invalidate cache for a file.
  static void invalidate(String filePath) {
    _changedRegions.remove(filePath);
    _previousContent.remove(filePath);
  }

  /// Clear all cached data.
  static void clearCache() {
    _changedRegions.clear();
    _previousContent.clear();
  }

  /// Merge overlapping ranges into consolidated ranges.
  static List<LineRange> _mergeOverlapping(List<LineRange> ranges) {
    if (ranges.isEmpty) return [];
    if (ranges.length == 1) return ranges;

    // Sort by start line
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final firstSorted = sorted.firstOrNull;
    if (firstSorted == null) return [];

    final merged = <LineRange>[firstSorted];
    for (var i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = merged.lastOrNull;
      if (last == null) continue;

      if (current.start <= last.end + 1) {
        merged[merged.length - 1] = last.merge(current);
      } else {
        merged.add(current);
      }
    }

    return merged;
  }

  /// Simple line-by-line diff computation.
  static List<LineRange> _computeLineDiff(String previous, String current) {
    final prevLines = previous.split('\n');
    final currLines = current.split('\n');
    final changes = <LineRange>[];

    var changeStart = -1;
    final maxLines = prevLines.length > currLines.length
        ? prevLines.length
        : currLines.length;

    for (var i = 0; i < maxLines; i++) {
      final prevLine = i < prevLines.length ? prevLines[i] : null;
      final currLine = i < currLines.length ? currLines[i] : null;

      final isDifferent = prevLine != currLine;

      if (isDifferent && changeStart < 0) {
        changeStart = i + 1; // Lines are 1-indexed
      } else if (!isDifferent && changeStart >= 0) {
        changes.add(LineRange(changeStart, i)); // End at previous line
        changeStart = -1;
      }
    }

    // Handle trailing change
    if (changeStart >= 0) {
      changes.add(LineRange(changeStart, maxLines));
    }

    return _mergeOverlapping(changes);
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalChangedLines = 0;
    for (final ranges in _changedRegions.values) {
      for (final range in ranges) {
        totalChangedLines += range.end - range.start + 1;
      }
    }

    return {
      'filesWithChanges': _changedRegions.length,
      'totalChangedLines': totalChangedLines,
      'cachedFiles': _previousContent.length,
    };
  }
}

// =============================================================================
// IMPORT GRAPH CACHE (Performance Optimization #9)
// =============================================================================
//
// Caches the import graph for a project to avoid re-parsing imports for each
// file. This is especially valuable for rules that need to check transitive
// dependencies or detect circular imports.
// =============================================================================

/// Represents import relationships in a project.
