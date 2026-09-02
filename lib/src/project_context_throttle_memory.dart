// Module overview (comment coverage pass).
// comment-coverage: module overview (batch).
//
// Core saropa_lints library implementation (utilities, context, or rules support).
//
// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
// and tiers in `lib/src/tiers.dart` where applicable; see `plans/PLAN_comment_coverage.md`.

part of 'project_context.dart';

class ThrottledAnalysis {
  ThrottledAnalysis._();

  // Map of file path -> last edit timestamp
  static final Map<String, DateTime> _lastEdit = {};

  // Map of file path -> last analysis timestamp
  static final Map<String, DateTime> _lastAnalysis = {};

  // Debounce duration (wait this long after last edit before analyzing)
  static Duration _debounceDelay = const Duration(milliseconds: 300);

  // Minimum interval between analyses for the same file
  static Duration _minAnalysisInterval = const Duration(milliseconds: 500);

  // Files currently being analyzed
  static final Set<String> _analyzing = {};

  /// Configure throttling parameters.
  static void configure({
    Duration? debounceDelay,
    Duration? minAnalysisInterval,
  }) {
    if (debounceDelay != null) _debounceDelay = debounceDelay;
    if (minAnalysisInterval != null) _minAnalysisInterval = minAnalysisInterval;
  }

  /// Record that a file was edited.
  static void recordEdit(String filePath) {
    _lastEdit[filePath] = DateTime.now();
  }

  /// Check if we should analyze a file now.
  ///
  /// Returns false if:
  /// - User edited recently (still typing)
  /// - Analysis ran recently (throttled)
  /// - Analysis is currently running
  static bool shouldAnalyze(String filePath) {
    final now = DateTime.now();

    // Check if currently analyzing
    if (_analyzing.contains(filePath)) {
      return false;
    }

    // Check debounce (wait for user to stop typing)
    final lastEdit = _lastEdit[filePath];
    if (lastEdit != null) {
      final elapsed = now.difference(lastEdit);
      if (elapsed < _debounceDelay) {
        return false;
      }
    }

    // Check minimum analysis interval
    final lastAnalysis = _lastAnalysis[filePath];
    if (lastAnalysis != null) {
      final elapsed = now.difference(lastAnalysis);
      if (elapsed < _minAnalysisInterval) {
        return false;
      }
    }

    return true;
  }

  /// Mark that analysis is starting.
  static void startAnalysis(String filePath) {
    _analyzing.add(filePath);
    _lastAnalysis[filePath] = DateTime.now();
  }

  /// Mark that analysis is complete.
  static void endAnalysis(String filePath) {
    _analyzing.remove(filePath);
  }

  /// Get time until next analysis is allowed.
  static Duration getTimeUntilAnalysis(String filePath) {
    final now = DateTime.now();
    var waitTime = Duration.zero;

    // Check debounce
    final lastEdit = _lastEdit[filePath];
    if (lastEdit != null) {
      final debounceEnd = lastEdit.add(_debounceDelay);
      if (debounceEnd.isAfter(now)) {
        waitTime = debounceEnd.difference(now);
      }
    }

    // Check throttle
    final lastAnalysis = _lastAnalysis[filePath];
    if (lastAnalysis != null) {
      final throttleEnd = lastAnalysis.add(_minAnalysisInterval);
      if (throttleEnd.isAfter(now)) {
        final throttleWait = throttleEnd.difference(now);
        if (throttleWait > waitTime) {
          waitTime = throttleWait;
        }
      }
    }

    return waitTime;
  }

  /// Clear throttle state for a file.
  static void clear(String filePath) {
    _lastEdit.remove(filePath);
    _lastAnalysis.remove(filePath);
    _analyzing.remove(filePath);
  }

  /// Clear all throttle state.
  static void clearAll() {
    _lastEdit.clear();
    _lastAnalysis.clear();
    _analyzing.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'trackedFiles': _lastEdit.length,
      'analyzingFiles': _analyzing.length,
      'debounceDelayMs': _debounceDelay.inMilliseconds,
      'minIntervalMs': _minAnalysisInterval.inMilliseconds,
    };
  }
}

// =============================================================================
// BACKGROUND SPECULATIVE ANALYSIS (Performance Optimization)
// =============================================================================
//
// Speculatively pre-analyzes files likely to be opened next.
// When a user opens file A, we can predict they might open file B
// (e.g., test file for implementation, or files in same directory).
// =============================================================================

/// Speculatively pre-analyzes likely-to-be-opened files.
///
/// Usage:
/// ```dart
/// // When user opens a file
/// final predictions = SpeculativeAnalysis.predictNextFiles(filePath);
/// for (final predicted in predictions) {
///   SpeculativeAnalysis.schedulePreAnalysis(predicted);
/// }
///
/// // Check if a file was pre-analyzed
/// if (SpeculativeAnalysis.isPreAnalyzed(filePath)) {
///   // Use cached results
/// }
/// ```
class SpeculativeAnalysis {
  SpeculativeAnalysis._();

  // Files that have been pre-analyzed
  static final Set<String> _preAnalyzed = {};

  // Queue of files to pre-analyze
  static final List<String> _queue = [];

  // Map of file -> associated files (for predictions)
  static final Map<String, Set<String>> _associations = {};

  // History of recently opened files
  static final List<String> _openHistory = [];
  static const int _maxHistory = 20;

  // Maximum files to pre-analyze in background
  static const int _maxPreAnalyze = 5;

  /// Predict which files might be opened next.
  ///
  /// Predictions based on:
  /// - Test file for implementation (or vice versa)
  /// - Files in same directory
  /// - Files imported by current file
  /// - Historical patterns
  static List<String> predictNextFiles(String currentFile) {
    final predictions = <String>{};
    final normalizedPath = currentFile.replaceAll('\\', '/');

    // Predict test file
    if (!normalizedPath.contains('_test.dart')) {
      final testPath = normalizedPath.replaceFirst('.dart', '_test.dart');
      if (testPath != normalizedPath) predictions.add(testPath);
    } else {
      // Predict implementation file
      final implPath = normalizedPath.replaceFirst('_test.dart', '.dart');
      if (implPath != normalizedPath) predictions.add(implPath);
    }

    // Add associated files
    final associated = _associations[currentFile];
    if (associated != null) {
      predictions.addAll(associated.take(3));
    }

    // Add imports (from ImportGraphCache if available)
    final imports = ImportGraphCache.getImports(currentFile);
    for (final imp in imports.take(2)) {
      if (!imp.startsWith('dart:') && !imp.startsWith('package:')) {
        predictions.add(imp);
      }
    }

    return predictions.take(_maxPreAnalyze).toList();
  }

  /// Record that a file was opened (for learning associations).
  static void recordFileOpened(String filePath) {
    // Update history
    _openHistory.remove(filePath);
    _openHistory.insert(0, filePath);
    if (_openHistory.length > _maxHistory) {
      _openHistory.removeLast();
    }

    // Learn associations (files opened in sequence)
    if (_openHistory.length >= 2) {
      final previous = _openHistory[1];
      _associations.putIfAbsent(previous, () => {}).add(filePath);
      _associations.putIfAbsent(filePath, () => {}).add(previous);
    }
  }

  /// Schedule a file for background pre-analysis.
  static void schedulePreAnalysis(String filePath) {
    if (_preAnalyzed.contains(filePath)) return;
    if (_queue.contains(filePath)) return;

    _queue.add(filePath);

    // Trim queue if too long
    while (_queue.length > _maxPreAnalyze * 2) {
      _queue.removeAt(0);
    }
  }

  /// Get next file to pre-analyze (if any).
  static String? getNextToAnalyze() {
    while (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      if (!_preAnalyzed.contains(next)) {
        return next;
      }
    }
    return null;
  }

  /// Mark a file as pre-analyzed.
  static void markPreAnalyzed(String filePath) {
    _preAnalyzed.add(filePath);
  }

  /// Check if a file was pre-analyzed.
  static bool isPreAnalyzed(String filePath) {
    return _preAnalyzed.contains(filePath);
  }

  /// Invalidate pre-analysis (e.g., when file changes).
  static void invalidate(String filePath) {
    _preAnalyzed.remove(filePath);
  }

  /// Clear all state.
  static void clearAll() {
    _preAnalyzed.clear();
    _queue.clear();
    _associations.clear();
    _openHistory.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'preAnalyzedFiles': _preAnalyzed.length,
      'queuedFiles': _queue.length,
      'associations': _associations.length,
      'historySize': _openHistory.length,
    };
  }
}

// =============================================================================
// RULE GROUP EXECUTION (Performance Optimization)
// =============================================================================
//
// Groups related rules for batch execution. Rules in the same group share
// setup/teardown costs and can share intermediate results.
// =============================================================================

/// Defines a group of related rules that can share execution context.
class RuleGroup {
  const RuleGroup({
    required this.name,
    required this.rules,
    this.sharedPatterns = const {},
    this.sharedCategories = const {},
    this.priority = 100,
  });

  /// Group name (e.g., 'flutter_widgets', 'async_rules').
  final String name;

  /// Rule names in this group.
  final Set<String> rules;

  /// Patterns that all rules in this group might need.
  final Set<String> sharedPatterns;

  /// AST node categories that rules in this group visit.
  final Set<AstNodeCategory> sharedCategories;

  /// Priority for group execution order (lower = runs first).
  final int priority;
}

/// Manages rule group execution for optimal performance.
///
/// Usage:
/// ```dart
/// // Register groups at startup
/// RuleGroupExecutor.registerGroup(RuleGroup(
///   name: 'async_rules',
///   rules: {'avoid_slow_async_io', 'unawaited_futures', ...},
///   sharedPatterns: {'async', 'await', 'Future'},
/// ));
///
/// // Get groups applicable to a file
/// final groups = RuleGroupExecutor.getApplicableGroups(filePath, content);
///
/// // Execute groups in order
/// for (final group in groups) {
///   RuleGroupExecutor.startGroup(group.name, filePath);
///   // Execute rules in group...
///   RuleGroupExecutor.endGroup(group.name, filePath);
/// }
/// ```
class RuleGroupExecutor {
  RuleGroupExecutor._();

  // Registered groups
  static final Map<String, RuleGroup> _groups = {};

  // Map of rule name -> group name
  static final Map<String, String> _ruleToGroup = {};

  // Shared context per group execution
  static final Map<String, Map<String, dynamic>> _groupContext = {};

  // Track active group executions
  static final Map<String, DateTime> _activeGroups = {};

  /// Register a rule group.
  static void registerGroup(RuleGroup group) {
    _groups[group.name] = group;
    for (final rule in group.rules) {
      _ruleToGroup[rule] = group.name;
    }
  }

  /// Get the group a rule belongs to (if any).
  static String? getGroupForRule(String ruleName) {
    return _ruleToGroup[ruleName];
  }

  /// Get all groups applicable to a file.
  ///
  /// A group is applicable if any of its shared patterns match the content.
  static List<RuleGroup> getApplicableGroups(String filePath, String content) {
    final applicable = <RuleGroup>[];

    for (final group in _groups.values) {
      // Check if any shared patterns match
      if (group.sharedPatterns.isEmpty ||
          group.sharedPatterns.any((p) => content.contains(p))) {
        applicable.add(group);
      }
    }

    // Sort by priority
    applicable.sort((a, b) => a.priority.compareTo(b.priority));
    return applicable;
  }

  /// Start executing a group on a file.
  ///
  /// Sets up shared context for rules in the group.
  static void startGroup(String groupName, String filePath) {
    final key = '$groupName:$filePath';
    _activeGroups[key] = DateTime.now();
    _groupContext[key] = {};
  }

  /// End group execution.
  static void endGroup(String groupName, String filePath) {
    final key = '$groupName:$filePath';
    _activeGroups.remove(key);
    _groupContext.remove(key);
  }

  /// Store shared data in group context.
  static void setGroupData(
    String groupName,
    String filePath,
    String key,
    dynamic value,
  ) {
    final contextKey = '$groupName:$filePath';
    _groupContext[contextKey]?[key] = value;
  }

  /// Get shared data from group context.
  static T? getGroupData<T>(String groupName, String filePath, String key) {
    final contextKey = '$groupName:$filePath';
    return _groupContext[contextKey]?[key] as T?;
  }

  /// Check if a group is currently active for a file.
  static bool isGroupActive(String groupName, String filePath) {
    return _activeGroups.containsKey('$groupName:$filePath');
  }

  /// Get all registered groups.
  static List<RuleGroup> get allGroups => _groups.values.toList();

  /// Clear all registrations.
  static void clear() {
    _groups.clear();
    _ruleToGroup.clear();
    _groupContext.clear();
    _activeGroups.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'registeredGroups': _groups.length,
      'totalRulesInGroups': _ruleToGroup.length,
      'activeGroupExecutions': _activeGroups.length,
    };
  }
}

// =============================================================================
// STRING INTERNING POOL (Performance Optimization)
// =============================================================================
//
// Interns frequently used strings to reduce memory allocation.
// Many rules use the same strings repeatedly (e.g., 'StatelessWidget',
// 'BuildContext'). Interning ensures only one copy exists in memory.
// =============================================================================

/// Interns strings for memory efficiency.
///
/// Usage:
/// ```dart
/// // Intern a string
/// final className = StringInterner.intern('StatelessWidget');
///
/// // Later comparisons use == instead of string comparison
/// if (identical(otherClassName, StringInterner.intern('StatelessWidget'))) {
///   // Same string instance
/// }
///
/// // Pre-intern known common strings at startup
/// StringInterner.preIntern(['StatelessWidget', 'StatefulWidget', ...]);
/// ```
class StringInterner {
  StringInterner._();

  // The intern pool
  static final Map<String, String> _pool = {};

  // Common Dart/Flutter strings to pre-intern
  static const List<String> _commonStrings = [
    // Flutter widgets
    'StatelessWidget',
    'StatefulWidget',
    'State',
    'BuildContext',
    'Widget',
    'Key',
    // Common types
    'String',
    'int',
    'double',
    'bool',
    'List',
    'Map',
    'Set',
    'Future',
    'Stream',
    'void',
    'dynamic',
    'Object',
    'Null',
    // Common modifiers
    'async',
    'await',
    'const',
    'final',
    'static',
    'late',
    'required',
    'override',
    // Common patterns
    'dispose',
    'initState',
    'build',
    'setState',
    'mounted',
  ];

  /// Intern a string, returning the canonical instance.
  static String intern(String s) {
    return _pool.putIfAbsent(s, () => s);
  }

  /// Pre-intern a list of strings.
  static void preIntern(Iterable<String> strings) {
    for (final s in strings) {
      _pool.putIfAbsent(s, () => s);
    }
  }

  /// Pre-intern common Dart/Flutter strings.
  static void preInternCommon() {
    preIntern(_commonStrings);
  }

  /// Check if a string is already interned.
  static bool isInterned(String s) {
    return _pool.containsKey(s);
  }

  /// Get the interned version if it exists, otherwise null.
  static String? getInterned(String s) {
    return _pool[s];
  }

  /// Compare two strings using interned equality.
  ///
  /// Returns true if both strings intern to the same instance.
  static bool equals(String a, String b) {
    return identical(intern(a), intern(b));
  }

  /// Clear the intern pool.
  ///
  /// Call this to free memory, but be careful as existing
  /// references to interned strings will still work.
  static void clear() {
    _pool.clear();
  }

  /// Get pool size.
  static int get poolSize => _pool.length;

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalChars = 0;
    for (final s in _pool.keys) {
      totalChars += s.length;
    }

    return {
      'poolSize': _pool.length,
      'totalCharacters': totalChars,
      'estimatedMemorySaved': totalChars * 2, // Approximate bytes saved
    };
  }
}

// =============================================================================
// HOT PATH PROFILING (Performance Optimization)
// =============================================================================
//
// Instruments hot paths for performance profiling. Helps identify
// which rules and operations take the most time.
// =============================================================================

/// Records a profiling measurement.
class ProfilingEntry {
  const ProfilingEntry({
    required this.name,
    required this.duration,
    required this.timestamp,
    this.metadata,
  });

  final String name;
  final Duration duration;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}

/// Profiles hot paths for performance analysis.
///
/// Usage:
/// ```dart
/// // Profile a rule execution
/// final stopwatch = HotPathProfiler.startProfile('avoid_print');
/// // ... execute rule ...
/// HotPathProfiler.endProfile('avoid_print', stopwatch);
///
/// // Get profiling report
/// final report = HotPathProfiler.getReport();
/// for (final entry in report.slowest) {
///   print('${entry.name}: ${entry.averageDuration}ms');
/// }
/// ```
class HotPathProfiler {
  HotPathProfiler._();

  // Whether profiling is enabled
  static bool _isEnabled = false;

  // Map of name -> list of durations
  static final Map<String, List<Duration>> _measurements = {};

  // Recent profiling entries (for detailed analysis)
  static final List<ProfilingEntry> _recentEntries = [];
  static const int _maxRecentEntries = 1000;

  // Threshold for "slow" operations
  static Duration _slowThreshold = const Duration(milliseconds: 50);

  /// Enable profiling.
  static void enable() {
    _isEnabled = true;
  }

  /// Disable profiling.
  static void disable() {
    _isEnabled = false;
  }

  /// Check if profiling is enabled.
  static bool get isEnabled => _isEnabled;

  /// Configure slow threshold.
  static void setSlowThreshold(Duration threshold) {
    _slowThreshold = threshold;
  }

  /// Start profiling an operation.
  ///
  /// Returns a Stopwatch that should be passed to [endProfile].
  static Stopwatch startProfile(String name) {
    final stopwatch = Stopwatch();
    if (_isEnabled) {
      stopwatch.start();
    }
    return stopwatch;
  }

  /// End profiling and record the measurement.
  static void endProfile(
    String name,
    Stopwatch stopwatch, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_isEnabled) return;

    stopwatch.stop();
    final duration = stopwatch.elapsed;

    // Record measurement
    _measurements.putIfAbsent(name, () => []).add(duration);

    // Record entry
    final entry = ProfilingEntry(
      name: name,
      duration: duration,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    _recentEntries.add(entry);

    // Trim old entries
    while (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeAt(0);
    }
  }

  /// Record a measurement directly (for cases where stopwatch isn't used).
  static void recordMeasurement(
    String name,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    if (!_isEnabled) return;

    _measurements.putIfAbsent(name, () => []).add(duration);

    _recentEntries.add(
      ProfilingEntry(
        name: name,
        duration: duration,
        timestamp: DateTime.now(),
        metadata: metadata,
      ),
    );

    while (_recentEntries.length > _maxRecentEntries) {
      _recentEntries.removeAt(0);
    }
  }

  /// Get average duration for an operation.
  static Duration getAverageDuration(String name) {
    final measurements = _measurements[name];
    if (measurements == null || measurements.isEmpty) {
      return Duration.zero;
    }

    var total = Duration.zero;
    for (final m in measurements) {
      total += m;
    }
    return total ~/ measurements.length;
  }

  /// Get all slow operations (above threshold).
  static List<String> getSlowOperations() {
    final slow = <String>[];
    for (final entry in _measurements.entries) {
      final avg = getAverageDuration(entry.key);
      if (avg >= _slowThreshold) {
        slow.add(entry.key);
      }
    }
    return slow;
  }

  /// Get slowest N operations.
  static List<MapEntry<String, Duration>> getSlowest(int n) {
    final averages = <MapEntry<String, Duration>>[];
    for (final name in _measurements.keys) {
      averages.add(MapEntry(name, getAverageDuration(name)));
    }
    averages.sort((a, b) => b.value.compareTo(a.value));
    return averages.take(n).toList();
  }

  /// Get recent entries for detailed analysis.
  static List<ProfilingEntry> getRecentEntries({
    String? filterName,
    Duration? minDuration,
  }) {
    var entries = _recentEntries.toList();

    if (filterName != null) {
      entries = entries.where((e) => e.name == filterName).toList();
    }

    if (minDuration != null) {
      entries = entries.where((e) => e.duration >= minDuration).toList();
    }

    return entries;
  }

  /// Clear all measurements.
  static void clear() {
    _measurements.clear();
    _recentEntries.clear();
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    var totalMeasurements = 0;
    for (final m in _measurements.values) {
      totalMeasurements += m.length;
    }

    final slowOperations = getSlowOperations();
    final slowest = getSlowest(5);

    return {
      'enabled': _isEnabled,
      'operationsTracked': _measurements.length,
      'totalMeasurements': totalMeasurements,
      'recentEntries': _recentEntries.length,
      'slowOperationCount': slowOperations.length,
      'slowestOperations': slowest
          .map((e) => '${e.key}: ${e.value.inMilliseconds}ms')
          .toList(),
    };
  }
}

// =============================================================================
// LRU CACHE WITH SIZE LIMITS (Performance Optimization)
// =============================================================================
//
// Generic LRU (Least Recently Used) cache with configurable size limits.
// When the cache exceeds its maximum size, the least recently accessed
// entries are evicted. This prevents unbounded memory growth.
// =============================================================================

/// A node in the LRU doubly-linked list.
class _LruNode<K, V> {
  _LruNode(this.key, this.value);

  final K key;
  V value;
  _LruNode<K, V>? prev;
  _LruNode<K, V>? next;

  /// Re-points `this` to the head of a doubly-linked list. Fix for
  /// avoid_parameter_mutation: callers relinking a node now invoke a method
  /// on the node itself rather than mutating a parameter externally.
  void linkAsHead(_LruNode<K, V>? currentHead) {
    // Explicit `this.` so the lint engine sees instance-field mutation.
    prev = null;
    next = currentHead;
  }
}

/// Generic LRU cache with size limits.
///
/// Usage:
/// ```dart
/// final cache = LruCache<String, FileMetrics>(maxSize: 1000);
/// cache.put('file.dart', metrics);
/// final metrics = cache.get('file.dart'); // Moves to front
/// ```
class LruCache<K, V> {
  LruCache({required this.maxSize}) : assert(maxSize > 0);

  final int maxSize;
  final Map<K, _LruNode<K, V>> _map = {};
  _LruNode<K, V>? _head;
  _LruNode<K, V>? _tail;

  /// Get a value, moving it to the front (most recently used).
  V? get(K key) {
    final node = _map[key];
    if (node == null) return null;

    _moveToFront(node);
    return node.value;
  }

  /// Check if key exists without affecting LRU order.
  bool containsKey(K key) => _map.containsKey(key);

  /// Put a value, evicting old entries if needed.
  void put(K key, V value) {
    final existing = _map[key];
    if (existing != null) {
      existing.value = value;
      _moveToFront(existing);
      return;
    }

    // Create new node
    final node = _LruNode(key, value);
    _map[key] = node;
    _addToFront(node);

    // Evict if over capacity
    while (_map.length > maxSize) {
      _evictLru();
    }
  }

  /// Get or create a value using the factory.
  V putIfAbsent(K key, V Function() factory) {
    final existing = get(key);
    if (existing != null) return existing;

    final value = factory();
    put(key, value);
    return value;
  }

  /// Remove a specific key.
  V? remove(K key) {
    final node = _map.remove(key);
    if (node == null) return null;

    _removeNode(node);
    return node.value;
  }

  /// Clear all entries.
  void clear() {
    _map.clear();
    _head = null;
    _tail = null;
  }

  /// Current size.
  int get length => _map.length;

  /// All keys (most recent first).
  Iterable<K> get keys sync* {
    var node = _head;
    while (node != null) {
      yield node.key;
      node = node.next;
    }
  }

  /// All values (most recent first).
  Iterable<V> get values sync* {
    var node = _head;
    while (node != null) {
      yield node.value;
      node = node.next;
    }
  }

  void _moveToFront(_LruNode<K, V> node) {
    if (node == _head) return;

    _removeNode(node);
    _addToFront(node);
  }

  void _addToFront(_LruNode<K, V> node) {
    // Fix: avoid_parameter_mutation — delegate node-internal pointer updates
    // to _LruNode.linkAsHead so the node mutates its own state rather than
    // this method mutating a caller-supplied parameter.
    node.linkAsHead(_head);

    if (_head != null) {
      _head!.prev = node;
    }
    _head = node;

    if (_tail == null) {
      _tail = node;
    }
  }

  void _removeNode(_LruNode<K, V> node) {
    if (node.prev != null) {
      node.prev!.next = node.next;
    } else {
      _head = node.next;
    }

    if (node.next != null) {
      node.next!.prev = node.prev;
    } else {
      _tail = node.prev;
    }
  }

  void _evictLru() {
    final t = _tail;
    if (t == null) return;
    _map.remove(t.key);
    _removeNode(t);
  }
}

// =============================================================================
// MEMORY PRESSURE HANDLING (Performance Optimization)
// =============================================================================
//
// Monitors memory usage and clears caches when under pressure.
// This prevents the analysis process from running out of memory
// on large projects with many files.
// =============================================================================

/// Handles memory pressure by clearing caches.
///
/// Usage:
/// ```dart
/// // Register caches to be cleared under pressure
/// MemoryPressureHandler.registerCache('fileMetrics', FileMetricsCache.clearCache);
///
/// // Check periodically (e.g., every 100 files)
/// MemoryPressureHandler.checkAndRelieve();
///
/// // Or set up automatic threshold-based clearing
/// MemoryPressureHandler.enableAutoRelief(thresholdMb: 500);
/// ```
class MemoryPressureHandler {
  MemoryPressureHandler._();

  // Registered cache clear functions with priority (lower = clear first)
  static final Map<String, _CacheRegistration> _caches = {};

  // External memory estimators — named callbacks that return estimated bytes
  // for data structures in other libraries (e.g. ImpactTracker,
  // SuppressionTracker) that can't be accessed directly due to import
  // direction. Keyed by name to support idempotent re-registration.
  static final Map<String, int Function()> _externalEstimators = {};

  // Configuration
  static int _thresholdMb = 512; // Default 512MB threshold
  static bool _autoReliefEnabled = false;
  static int _checkIntervalFiles = 50; // Check every N files
  static int _filesProcessed = 0;

  // Statistics
  static int _relieveCount = 0;
  static DateTime? _lastRelieve;

  // ─────────────────────────────────────────────────────────────────────────
  // Hard RSS safety valve
  // ─────────────────────────────────────────────────────────────────────────
  // The soft auto-relief above estimates memory from the plugin's OWN cache
  // sizes — it has no visibility into the analyzer's resolved element/AST model,
  // which is where the bulk of analysis-server memory lives on large projects.
  // This valve reads the REAL process RSS (ProcessInfo.currentRss) and, when it
  // crosses a hard cap, trips a flag that makes every rule callback a no-op
  // (see SaropaContext._wrapCallback). Rule callbacks are the plugin's only
  // ongoing work and the trigger for lazy cross-library element resolution
  // (allSupertypes / .library reaches), so halting them caps the plugin's
  // contribution and stops the server being driven to an OOM/hang. Recovers
  // automatically once RSS falls back below the cap (hysteresis).

  /// Hard cap on analysis-server process RSS, in MB. 0 disables the valve.
  ///
  /// Defaults to 0 (DISABLED) so the valve is inert in every process that
  /// merely loads this library — the scan CLI and, critically, the `dart test`
  /// suite, whose process RSS legitimately exceeds any per-project cap while
  /// resolving thousands of fixtures concurrently. An armed-by-default valve
  /// tripped there and silenced every rule callback (see
  /// SaropaContext._wrapCallback), making all "rule fires" tests fail. The
  /// valve is the in-process plugin's protection only, so it is armed solely by
  /// [initializeCacheManagement] (called from `Plugin.start()`), which sets the
  /// real cap — 4096 MB by default, overridable via `SAROPA_LINTS_MAX_RSS_MB`.
  static int _hardLimitMb = 0;

  /// True once RSS has crossed [_hardLimitMb]; cleared when it drops below the
  /// recovery watermark. Read by [isOverHardLimit].
  static bool _hardLimitTripped = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Soft RSS threshold — early warning before the hard valve trips.
  // Triggers graduated rule shedding (Phase 1+3 of the memory monitor plan).
  // ─────────────────────────────────────────────────────────────────────────

  /// Whether graduated rule shedding is enabled. Must be explicitly armed via
  /// [enableShedding] — without this, soft-limit warnings still log but rules
  /// are never shed. Opt-in so users aren't surprised by rules vanishing.
  static bool _shedEnabled = false;

  /// Arm graduated rule shedding. Called from the native plugin's config
  /// loader (`shed_rules: true` in `analysis_options_custom.yaml`, or the
  /// legacy `SAROPA_LINTS_SHED_RULES=true` env var) once the user opts in.
  static void enableShedding() {
    _shedEnabled = true;
  }

  /// Soft limit: 70% of [_hardLimitMb]. Crossing this triggers warnings and,
  /// when shedding is enabled, graduated rule shedding. Computed lazily from
  /// [_hardLimitMb] so it tracks any env-var or adaptive override.
  static int get _softLimitMb =>
      _hardLimitMb > 0 ? (_hardLimitMb * 0.7).round() : 0;

  /// True once RSS crosses [_softLimitMb]; cleared with hysteresis when RSS
  /// drops below [_softLimitMb] - [_softRecoveryMarginMb].
  static bool _softLimitTripped = false;

  /// Hysteresis band for the soft limit (MB). Proportional to the soft limit
  /// (10%, floored at 32 MB) so that small _hardLimitMb values (e.g. 300 MB)
  /// still produce a viable recovery threshold instead of going negative.
  /// For the default 4096 MB hard limit, soft=2867, margin=286 — similar to
  /// the previous fixed 256 MB constant.
  static int get _softRecoveryMarginMb =>
      _softLimitMb > 0 ? (_softLimitMb * 0.1).round().clamp(32, 512) : 0;

  /// Highest supported shed level. Single source of truth for clamp bounds,
  /// escalation branches, and test helpers.
  static const int maxShedLevel = 3;

  /// Current shedding level, escalated as RSS climbs past the soft threshold.
  ///   0 = no shedding (normal operation)
  ///   1 = expensive rules shed (type-resolving + high/extreme cost)
  ///   2 = expensive + INFO-severity rules shed
  ///   3 = expensive + INFO + WARNING-severity rules shed
  /// ERROR-severity and essential-tier rules are never shed.
  static int _shedLevel = 0;

  /// Public getter for the current shed level. Read by SaropaContext's
  /// _wrapCallback on the hot per-node path — must be a simple field read.
  static int get shedLevel => _shedLevel;

  /// Names of rules currently shed by memory pressure. Populated when
  /// [_shedLevel] changes; read by the extension's memory state file.
  static final Set<String> _shedRuleNames = {};

  /// Snapshot of shed rule names for diagnostics and extension communication.
  static Set<String> get shedRuleNames => Set.unmodifiable(_shedRuleNames);

  /// Count of rules currently shed. Cheaper than copying the set.
  static int get shedRuleCount => _shedRuleNames.length;

  /// Callback invoked when the shed level changes. Set by the plugin at
  /// startup to write the memory state file for the VS Code extension.
  /// Nullable so the core library has no hard dependency on IO/extension code.
  static void Function(int shedLevel, int rssMb)? onShedLevelChanged;

  /// Gate-call counter — [isOverHardLimit] is read per rule-node (very hot), so
  /// the real RSS syscall is throttled to once per [_rssСheckInterval] calls.
  static int _callsSinceRssCheck = 0;
  static const int _rssCheckInterval = 200;

  /// Hysteresis band below the cap before the valve re-opens, in MB. Prevents
  /// flapping when RSS hovers at the threshold.
  static const int _rssRecoveryMarginMb = 512;

  /// Wall-clock time of the last periodic RSS trend line written to
  /// `plugin.log`. Separate from [_callsSinceRssCheck] (which throttles the
  /// RSS *syscall*) because the trend log needs its own, coarser cadence —
  /// otherwise a busy analysis pass would flood the log with a line every
  /// ~200 rule callbacks instead of the ~30s a human reviewing a post-crash
  /// log actually needs.
  static DateTime? _lastMemoryLogAt;
  static const Duration _memoryLogInterval = Duration(seconds: 30);

  /// True once the RSS-unavailable warning has been logged. Without this,
  /// _refreshHardLimit's early return on rss<=0 would leave the trend log
  /// permanently and silently empty on a platform without RSS support —
  /// indistinguishable from "the plugin never ran". One warning at first
  /// detection surfaces the cause without repeating it on every refresh.
  static bool _loggedRssUnavailable = false;

  /// The configured hard RSS cap in MB, or 0 if disabled. Used by
  /// FileBudgetTracker to compute its file-skipping threshold.
  static int get hardRssLimitMb => _hardLimitMb;

  /// Set the hard RSS cap (MB). 0 or negative disables the valve.
  static void setHardRssLimitMb(int mb) {
    _hardLimitMb = mb;
  }

  /// Force the hard-limit-tripped flag for testing. Production code should
  /// never call this — use [setHardRssLimitMb] to arm the real valve instead.
  /// This exists because tests can't control the real process RSS, so the
  /// end-to-end eviction path needs a way to simulate the trip.
  static void setHardLimitTrippedForTest(bool value) {
    _hardLimitTripped = value;
    // Arm the valve with a non-zero cap so isOverHardLimit doesn't short-
    // circuit on the _hardLimitMb <= 0 check.
    if (value && _hardLimitMb <= 0) _hardLimitMb = 1;
  }

  /// Runs the real RSS refresh (including the periodic memory-log write) on
  /// demand. Test-only — production code reaches [_refreshHardLimit] only via
  /// [isOverHardLimit]'s call-count throttle, which a test would otherwise
  /// have to drive 200+ times just to exercise the log line.
  static void refreshForTesting() => _refreshHardLimit();

  /// Resets the periodic memory-log cooldown so the next [refreshForTesting]
  /// or [isOverHardLimit] refresh is guaranteed to log. Test-only.
  static void resetMemoryLogCooldownForTesting() => _lastMemoryLogAt = null;

  /// Force the soft-limit-tripped flag for testing. Allows tests to simulate
  /// memory pressure without controlling real process RSS.
  static void setSoftLimitTrippedForTest(bool value) {
    _softLimitTripped = value;
  }

  /// Force the shed level for testing. Allows end-to-end shedding tests
  /// without real RSS pressure. Levels: 0=none, 1=expensive, 2=+INFO, 3=+WARNING.
  static void setShedLevelForTest(int level) {
    _shedLevel = level.clamp(0, maxShedLevel);
    // Rebuild the shed set so isRuleShed reflects the new level.
    _rebuildShedRuleNames();
  }

  /// Reset all soft-limit and shedding state. Test-only — clears the soft
  /// flag, shed level, shed rule names, and cost metadata so tests start clean.
  static void resetShedStateForTesting() {
    _shedEnabled = false;
    _softLimitTripped = false;
    _shedLevel = 0;
    _shedRuleNames.clear();
    _typeResolvingRules.clear();
    _highCostRules.clear();
  }

  /// Whether the process RSS is currently over the hard cap, meaning rule
  /// execution should pause. Self-samples the real RSS on a throttle so callers
  /// can invoke it on the hot per-node path without a syscall every time.
  static bool get isOverHardLimit {
    if (_hardLimitMb <= 0) return false;
    if (_callsSinceRssCheck++ >= _rssCheckInterval) {
      _callsSinceRssCheck = 0;
      _refreshHardLimit();
    }
    return _hardLimitTripped;
  }

  /// Read the real process RSS and update [_hardLimitTripped] and
  /// [_softLimitTripped] with hysteresis, escalating/de-escalating the shed
  /// level as RSS climbs or drops relative to the soft threshold.
  static void _refreshHardLimit() {
    final rss = _currentRssMb();
    if (rss <= 0) {
      // RSS unavailable on this platform — leave the hard-limit flag as-is
      // and the trend log empty, but say so once so an empty plugin.log
      // reads as "unsupported platform" rather than "plugin never started".
      if (!_loggedRssUnavailable) {
        _loggedRssUnavailable = true;
        PluginLogger.log(
          '[memory] RSS sampling unavailable on this platform — hard-limit '
          'valve and periodic memory trend log are both inert.',
        );
      }
      return;
    }

    // Periodic trend line for post-crash diagnosis: this call site already
    // runs on every RSS refresh (throttled via _rssCheckInterval above), so
    // piggybacking here avoids a second polling loop. Gated on wall-clock
    // interval, not refresh count, since refresh frequency depends on how
    // busy the analysis server is.
    final now = DateTime.now();
    if (_lastMemoryLogAt == null ||
        now.difference(_lastMemoryLogAt!) >= _memoryLogInterval) {
      _lastMemoryLogAt = now;
      // Include shed level in the periodic log so post-crash diagnosis shows
      // whether shedding was active and at what level.
      final shedInfo = _shedLevel > 0 ? ' shed=$_shedLevel' : '';
      PluginLogger.log(
        '[memory] RSS ${rss}MB (cap ${_hardLimitMb}MB, '
        'soft ${_softLimitMb}MB$shedInfo)',
      );
    }

    // ── Soft limit: graduated rule shedding ──
    _refreshSoftLimit(rss);

    // ── Hard limit: full rule-execution pause ──
    if (!_hardLimitTripped && rss >= _hardLimitMb) {
      _hardLimitTripped = true;
      // Shed the plugin's own caches immediately to give back what we can.
      relieve(clearAll: true);
      stderr.writeln(
        '[saropa_lints] Memory guard tripped: RSS ${rss}MB >= ${_hardLimitMb}MB '
        'cap. Pausing rule execution to protect the analysis server. Set '
        'SAROPA_LINTS_MAX_RSS_MB to adjust the cap (0 disables it).',
      );
    } else if (_hardLimitTripped && rss < _hardLimitMb - _rssRecoveryMarginMb) {
      _hardLimitTripped = false;
      stderr.writeln(
        '[saropa_lints] Memory guard released: RSS ${rss}MB. '
        'Resuming rule execution.',
      );
    }
  }

  /// Evaluate the soft RSS threshold and adjust [_shedLevel] accordingly.
  ///
  /// Cost-aware shedding: level 1 sheds expensive (type-resolving + high-cost)
  /// rules first, level 2 adds INFO-severity, level 3 adds WARNING-severity.
  /// Two escalation boundaries split the soft→hard range into thirds.
  ///
  /// De-escalation happens when RSS drops below [_softLimitMb] minus
  /// [_softRecoveryMarginMb] — the hysteresis band prevents flapping when
  /// RSS hovers near the threshold.
  static void _refreshSoftLimit(int rss) {
    final soft = _softLimitMb;
    // Soft limit disabled when hard limit is disabled (both derive from
    // _hardLimitMb = 0 set in tests and the scan CLI).
    if (soft <= 0) return;

    if (!_softLimitTripped && rss >= soft) {
      _tripSoftLimit(rss, soft);
    } else if (_softLimitTripped && rss < soft - _softRecoveryMarginMb) {
      _recoverSoftLimit(rss, soft);
    } else if (_softLimitTripped && _shedEnabled) {
      _refreshEscalation(rss, soft);
    }
  }

  /// Crossing the soft threshold — warn unconditionally, shed only if the
  /// user opted in via `shed_rules: true`.
  static void _tripSoftLimit(int rss, int soft) {
    _softLimitTripped = true;
    if (_shedEnabled) {
      _updateShedLevel(1, rss);
      PluginLogger.log(
        '[memory] WARNING: RSS ${rss}MB crossed soft limit ${soft}MB. '
        'Shedding expensive rules — type-resolving + high-cost '
        '(${_shedRuleNames.length} rules).',
      );
      stderr.writeln(
        '[saropa_lints] Memory pressure: RSS ${rss}MB >= ${soft}MB soft '
        'limit. Shedding type-resolving and high-cost non-essential '
        'rules to reduce memory growth.',
      );
    } else {
      // Shedding not enabled — notify the extension so it can prompt the
      // user with a visible VS Code warning (not just a log line).
      onShedLevelChanged?.call(0, rss);
      PluginLogger.log(
        '[memory] WARNING: RSS ${rss}MB crossed soft limit ${soft}MB. '
        'Set shed_rules: true in analysis_options_custom.yaml to enable '
        'graduated shedding.',
      );
      stderr.writeln(
        '[saropa_lints] Memory pressure: RSS ${rss}MB >= ${soft}MB soft '
        'limit. Rule shedding is not enabled — set shed_rules: true in '
        'analysis_options_custom.yaml to auto-shed low-severity rules.',
      );
    }
  }

  /// RSS dropped well below the soft threshold — restore all shed rules.
  /// The proportional margin (10% of soft, floor 32 MB) guarantees the
  /// recovery threshold stays positive for any viable soft limit.
  static void _recoverSoftLimit(int rss, int soft) {
    _softLimitTripped = false;
    final previousCount = _shedRuleNames.length;
    if (_shedEnabled) {
      _updateShedLevel(0, rss);
    } else {
      // Still notify the extension so the state file reflects recovery,
      // clearing any "enable shedding" prompt the extension may have shown.
      onShedLevelChanged?.call(0, rss);
    }
    PluginLogger.log(
      '[memory] RSS ${rss}MB dropped below soft recovery '
      '${soft - _softRecoveryMarginMb}MB. Restored $previousCount rules.',
    );
    if (previousCount > 0) {
      stderr.writeln(
        '[saropa_lints] Memory pressure released: RSS ${rss}MB. '
        'Restored $previousCount shed rules.',
      );
    }
  }

  /// Still above soft — escalate through 3 levels or de-escalate as RSS drops.
  /// Two escalation boundaries split the soft→hard range into thirds:
  ///   esc1 = soft + (hard-soft)/3  → level 2 (expensive + INFO rules)
  ///   esc2 = soft + 2*(hard-soft)/3 → level 3 (all non-essential non-ERROR)
  /// Only reached when shedding is enabled.
  static void _refreshEscalation(int rss, int soft) {
    final range = _hardLimitMb - soft;
    // Guard: if range is too small for meaningful thirds, collapse to
    // a single escalation point at the midpoint — level 2 is skipped,
    // but that's correct: there's no room for an intermediate band.
    final esc1 = soft + range ~/ 3;
    final esc2 = (range < 6) ? esc1 : soft + (range * 2) ~/ 3;
    final margin = _softRecoveryMarginMb;

    // Escalate upward.
    if (_shedLevel < maxShedLevel && rss >= esc2) {
      _updateShedLevel(maxShedLevel, rss);
      PluginLogger.log(
        '[memory] WARNING: RSS ${rss}MB crossed escalation-2 '
        '${esc2}MB. Shedding all non-essential non-ERROR rules '
        '(${_shedRuleNames.length} rules total).',
      );
      stderr.writeln(
        '[saropa_lints] Memory pressure critical: RSS ${rss}MB. '
        'Now shedding all non-essential WARNING-severity rules too.',
      );
    } else if (_shedLevel < 2 && rss >= esc1) {
      _updateShedLevel(2, rss);
      PluginLogger.log(
        '[memory] WARNING: RSS ${rss}MB crossed escalation-1 '
        '${esc1}MB. Shedding INFO-severity rules too '
        '(${_shedRuleNames.length} rules total).',
      );
      stderr.writeln(
        '[saropa_lints] Memory pressure escalated: RSS ${rss}MB. '
        'Now shedding INFO-severity non-essential rules too.',
      );
    }
    // De-escalate downward.
    else if (_shedLevel == 3 && rss < esc2 - margin) {
      _updateShedLevel(2, rss);
      PluginLogger.log(
        '[memory] RSS ${rss}MB below escalation-2 recovery. '
        'De-escalated to level 2 (${_shedRuleNames.length} rules).',
      );
    } else if (_shedLevel == 2 && rss < esc1 - margin) {
      _updateShedLevel(1, rss);
      PluginLogger.log(
        '[memory] RSS ${rss}MB below escalation-1 recovery. '
        'De-escalated to level 1 — expensive rules only '
        '(${_shedRuleNames.length} rules).',
      );
    }
  }

  /// Update the shed level and rebuild the shed rule name set from the tier
  /// and severity registries. Notifies the extension callback if set.
  static void _updateShedLevel(int newLevel, int rss) {
    // Skip rebuild when the level hasn't changed — _rebuildShedRuleNames
    // iterates all 2300+ rules and checks essential membership for each.
    if (newLevel == _shedLevel) return;
    final oldLevel = _shedLevel;
    _shedLevel = newLevel;
    _rebuildShedRuleNames();
    if (oldLevel != newLevel) {
      onShedLevelChanged?.call(newLevel, rss);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shed rule name registry — populated from tiers + severity metadata.
  // ─────────────────────────────────────────────────────────────────────────

  /// Severity metadata for each rule, populated at startup by the plugin
  /// via [registerRuleSeverities]. Keyed by lower-case rule name.
  static final Map<String, int> _ruleSeverityIndex = {};

  /// Whether each rule uses type resolution, populated alongside severity.
  /// Type-resolving rules force the analyzer to resolve cross-library types,
  /// which is the dominant memory cost — shed these first.
  static final Set<String> _typeResolvingRules = {};

  /// Rules with high or extreme RuleCost, populated alongside severity.
  /// These rules traverse large AST subtrees or simulate cross-file analysis,
  /// making them expensive even without type resolution.
  static final Set<String> _highCostRules = {};

  /// Register the severity of each active rule so the shed mechanism can
  /// filter by severity without instantiating rules at shedding time.
  /// Called once at plugin startup after rule registration.
  ///
  /// [severities] maps lower-case rule names to their DiagnosticSeverity
  /// index (INFO=0, WARNING=1, ERROR=2).
  static void registerRuleSeverities(Map<String, int> severities) {
    _ruleSeverityIndex
      ..clear()
      ..addAll(severities);
  }

  /// Register cost metadata for cost-aware shedding. [typeResolving] lists
  /// rules that declare `usesTypeResolution => true`; [highCost] lists rules
  /// with `RuleCost.high` or `RuleCost.extreme`. Called once at startup
  /// alongside [registerRuleSeverities].
  static void registerRuleCosts({
    required Set<String> typeResolving,
    required Set<String> highCost,
  }) {
    _typeResolvingRules
      ..clear()
      ..addAll(typeResolving);
    _highCostRules
      ..clear()
      ..addAll(highCost);
  }

  /// Cost-aware graduated shedding with 3 levels. Type-resolving and
  /// high-cost rules are the dominant memory consumers — shedding them
  /// first gives the biggest RSS reduction per rule dropped.
  ///
  /// Level 1: Shed expensive rules (type-resolving OR high/extreme cost),
  ///          excluding essential-tier and ERROR-severity rules.
  /// Level 2: Shed remaining INFO-severity rules (cheap syntactic rules
  ///          that were kept at level 1).
  /// Level 3: Shed remaining WARNING-severity rules.
  ///
  /// ERROR-severity and essential-tier rules are NEVER shed.
  static void _rebuildShedRuleNames() {
    _shedRuleNames.clear();
    if (_shedLevel <= 0) return;

    for (final entry in _ruleSeverityIndex.entries) {
      final ruleName = entry.key;
      final severityIndex = entry.value;

      // ERROR-severity rules (index 2) are never shed.
      if (severityIndex >= 2) continue;
      // Essential-tier rules are always protected.
      if (essentialRules.contains(ruleName)) continue;

      // Level 3 (maxShedLevel): shed unconditionally — skip cost lookups.
      if (_shedLevel < maxShedLevel) {
        // Level 1: only expensive rules (type-resolving or high/extreme cost).
        final isExpensive =
            _typeResolvingRules.contains(ruleName) ||
            _highCostRules.contains(ruleName);
        if (_shedLevel == 1 && !isExpensive) continue;

        // Level 2: expensive + INFO-severity rules. WARNING-only survive.
        if (_shedLevel == 2 && !isExpensive && severityIndex > 0) continue;
      }

      _shedRuleNames.add(ruleName);
    }
  }

  /// Whether [ruleName] is currently shed due to memory pressure. Called from
  /// SaropaContext._wrapCallback on the hot per-node path — the Set lookup
  /// is O(1) and the _shedLevel short-circuit avoids the lookup when no
  /// shedding is active.
  static bool isRuleShed(String ruleName) {
    if (_shedLevel <= 0) return false;
    return _shedRuleNames.contains(ruleName);
  }

  /// Detailed breakdown of currently shed rules for extension telemetry.
  /// Groups shed rules by category (typeResolving, highCost, infoSeverity,
  /// warningSeverity) so the user can see exactly what coverage was lost.
  /// Only called on shed-level transitions — not on the hot path.
  static Map<String, dynamic> getShedDetails() {
    if (_shedLevel <= 0) return {};
    final typeResolving = <String>[];
    final highCost = <String>[];
    final infoSeverity = <String>[];
    final warningSeverity = <String>[];
    for (final name in _shedRuleNames) {
      if (_typeResolvingRules.contains(name)) {
        typeResolving.add(name);
      } else if (_highCostRules.contains(name)) {
        highCost.add(name);
      } else if ((_ruleSeverityIndex[name] ?? -1) == 0) {
        infoSeverity.add(name);
      } else {
        warningSeverity.add(name);
      }
    }
    return {
      'typeResolving': typeResolving.length,
      'highCost': highCost.length,
      'infoSeverity': infoSeverity.length,
      'warningSeverity': warningSeverity.length,
      // First 20 rule names per category — enough for diagnostics without
      // bloating the state file on large projects.
      'typeResolvingRules': typeResolving.take(20).toList(),
      'highCostRules': highCost.take(20).toList(),
      'infoSeverityRules': infoSeverity.take(20).toList(),
      'warningSeverityRules': warningSeverity.take(20).toList(),
    };
  }

  /// Current process resident-set size in MB, or -1 if unavailable.
  static int _currentRssMb() {
    try {
      return ProcessInfo.currentRss ~/ (1 << 20);
    } on Object {
      // ProcessInfo.currentRss can throw on platforms without RSS support;
      // returning -1 makes the valve inert rather than crashing the plugin.
      return -1;
    }
  }

  /// Register a cache to be cleared under memory pressure.
  ///
  /// [priority] - Lower values are cleared first (0-100).
  /// Use low priority for expensive-to-rebuild caches.
  static void registerCache(
    String name,
    void Function() clearFunction, {
    int priority = 50,
  }) {
    _caches[name] = _CacheRegistration(
      name: name,
      clear: clearFunction,
      priority: priority,
    );
  }

  /// Unregister a cache.
  static void unregisterCache(String name) {
    _caches.remove(name);
  }

  /// Register a named callback that returns estimated bytes for memory not
  /// directly visible to this library (cross-library trackers). The
  /// estimate is included in [_estimateMemoryUsageMb] and therefore
  /// influences soft auto-relief decisions.
  ///
  /// Named registration is idempotent: re-registering the same [name]
  /// replaces the previous callback, so Plugin.start() re-entry and
  /// composite plugins cannot duplicate estimators.
  static void registerEstimator(String name, int Function() estimator) {
    _externalEstimators[name] = estimator;
  }

  /// Enable automatic memory relief.
  static void enableAutoRelief({
    int thresholdMb = 512,
    int checkIntervalFiles = 50,
  }) {
    _autoReliefEnabled = true;
    _thresholdMb = thresholdMb;
    _checkIntervalFiles = checkIntervalFiles;
  }

  /// Disable automatic memory relief.
  static void disableAutoRelief() {
    _autoReliefEnabled = false;
  }

  /// Record that a file was processed (for auto-relief timing).
  static void recordFileProcessed() {
    _filesProcessed++;

    if (_autoReliefEnabled && _filesProcessed >= _checkIntervalFiles) {
      _filesProcessed = 0;
      checkAndRelieve();
    }
  }

  /// Check memory pressure and relieve if needed.
  ///
  /// Returns true if caches were cleared.
  static bool checkAndRelieve() {
    // Note: Dart doesn't provide direct memory usage APIs in all environments.
    // We use a heuristic based on cache sizes instead.
    final estimatedUsageMb = _estimateMemoryUsageMb();

    if (estimatedUsageMb > _thresholdMb) {
      relieve(clearAll: false);
      return true;
    }
    return false;
  }

  /// Clear caches to relieve memory pressure.
  ///
  /// If [clearAll] is false, only clears caches with priority >= 50 (large
  /// per-file caches that hold the most memory). Caches with priority < 50
  /// (small stats, expensive-to-rebuild registries) are spared.
  /// If [clearAll] is true, clears everything (hard RSS valve trip).
  static void relieve({bool clearAll = false}) {
    _relieveCount++;
    _lastRelieve = DateTime.now().toUtc();

    final sorted = _caches.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final cleared = <String>[];
    for (final cache in sorted) {
      if (clearAll || cache.priority >= 50) {
        cache.clear();
        cleared.add(cache.name);
      }
    }

    final estimateAfter = _estimateMemoryUsageMb();
    final rss = _currentRssMb();
    stderr.writeln(
      '[saropa_lints] Memory relief: cleared ${cleared.length}/'
      '${_caches.length} caches (${cleared.join(', ')}). '
      'Estimated plugin usage: ${estimateAfter}MB. '
      '${rss > 0 ? 'Process RSS: ${rss}MB.' : 'RSS unavailable.'}',
    );
  }

  /// Force clear all registered caches.
  static void clearAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
  }

  /// Estimate current memory usage from known cache sizes.
  static int _estimateMemoryUsageMb() {
    var estimatedBytes = 0;

    // FileContentCache: hash map + _passedRules (LRU-capped Set<String> per
    // file). Each set entry is ~48 bytes (hash bucket + string ref).
    estimatedBytes += FileContentCache._contentHashes.length * 64;
    for (final ruleSet in FileContentCache._passedRules.values) {
      estimatedBytes += ruleSet.length * 48;
    }

    estimatedBytes += FileMetricsCache._cache.length * 200;
    estimatedBytes += SourceLocationCache._lineStarts.length * 1024;

    for (final symbols in SemanticTokenCache._symbols.values) {
      estimatedBytes += symbols.length * 500;
    }

    estimatedBytes += CompilationUnitCache._cache.length * 2048;
    estimatedBytes += ImportGraphCache._graph.length * 500;

    for (final s in StringInterner._pool.keys) {
      estimatedBytes += s.length * 2;
    }

    // DiffBasedAnalysis._previousContent: full source text per file.
    for (final content in DiffBasedAnalysis._previousContent.values) {
      estimatedBytes += content.length * 2;
    }

    // IncrementalAnalysisTracker: per-file state objects.
    estimatedBytes += IncrementalAnalysisTracker._state.length * 256;

    // ParallelAnalyzer: cached analysis results per file.
    estimatedBytes += ParallelAnalyzer._resultCache.length * 512;

    // HotPathProfiler: duration lists per rule.
    for (final durations in HotPathProfiler._measurements.values) {
      estimatedBytes += durations.length * 16;
    }

    // Cross-library trackers (ImpactTracker, SuppressionTracker, etc.)
    // registered via registerEstimator() from main.dart.
    for (final estimator in _externalEstimators.values) {
      estimatedBytes += estimator();
    }

    const bytesPerMb = 1 << 20;
    return estimatedBytes ~/ bytesPerMb;
  }

  /// Get statistics including process RSS and cache breakdown.
  static Map<String, dynamic> getStats() {
    final rss = _currentRssMb();
    return {
      'registeredCaches': _caches.length,
      'autoReliefEnabled': _autoReliefEnabled,
      'thresholdMb': _thresholdMb,
      'estimatedUsageMb': _estimateMemoryUsageMb(),
      'processRssMb': rss > 0 ? rss : null,
      'rssAvailable': rss > 0,
      'hardLimitMb': _hardLimitMb,
      'hardLimitTripped': _hardLimitTripped,
      'softLimitMb': _softLimitMb,
      'softRecoveryMarginMb': _softRecoveryMarginMb,
      'softLimitTripped': _softLimitTripped,
      'shedLevel': _shedLevel,
      'shedRuleCount': _shedRuleNames.length,
      'shedEnabled': _shedEnabled,
      'relieveCount': _relieveCount,
      'lastRelieve': _lastRelieve?.toUtc().toIso8601String(),
    };
  }
}

class _CacheRegistration {
  const _CacheRegistration({
    required this.name,
    required this.clear,
    required this.priority,
  });

  final String name;
  final void Function() clear;
  final int priority;
}

/// Compute an adaptive RSS cap based on system physical RAM.
///
/// Returns 60% of detected physical RAM, clamped to [2048, 8192].
/// Falls back to [fallbackMb] when RAM detection fails or returns an
/// implausible value (<4096 MB — systems that small are too constrained
/// for the analysis server + IDE + plugin).
///
/// Examples: 8 GB RAM → cap 4915 MB, 16 GB → 8192 MB (ceiling),
/// 32 GB → 8192 MB (ceiling). The 8192 upper bound prevents the plugin
/// from claiming too much on high-RAM servers where other processes
/// also need memory.
int _computeAdaptiveRssCap(int fallbackMb) {
  final ramMb = _totalPhysicalMemoryMb();
  if (ramMb < 4096) return fallbackMb;

  // 60% of physical RAM: the analysis server shares memory with the IDE,
  // OS, browser, and other dev tools. 60% is aggressive enough to protect
  // 8 GB machines (cap ≈ 4915) while giving 16 GB+ machines real headroom
  // (cap ≈ 9830, clamped to 8192).
  final adaptive = (ramMb * 0.6).round();

  // Clamp: never below 2048 (too aggressive — would pause rules on small
  // projects), never above 8192 (enough for large projects; beyond that
  // the OS/IDE/browser start competing for RAM). The fallbackMb default
  // (4096) only applies when RAM detection fails.
  return adaptive.clamp(2048, 8192);
}

/// Detect total physical memory in MB, or -1 if unavailable.
///
/// Platform-specific: Windows tries PowerShell CIM first (wmic is deprecated
/// since Win10 21H1), then falls back to wmic. Linux reads `/proc/meminfo`,
/// macOS uses `sysctl`. All wrapped in try/catch so a failure on an
/// unknown platform returns -1 (the caller falls back to the fixed default).
int _totalPhysicalMemoryMb() {
  try {
    if (Platform.isWindows) {
      // Try PowerShell CIM first — wmic is deprecated since Windows 10 21H1
      // and may be removed in future builds. CIM returns bytes as a string.
      final cimResult = Process.runSync('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      if (cimResult.exitCode == 0) {
        final bytes = int.tryParse((cimResult.stdout as String).trim());
        if (bytes != null && bytes > 0) return bytes ~/ (1 << 20);
      }

      // Fall back to wmic for older Windows versions where PowerShell CIM
      // may not be available or the powershell binary isn't on PATH.
      final wmicResult = Process.runSync('wmic', [
        'OS',
        'get',
        'TotalVisibleMemorySize',
        '/value',
      ]);
      if (wmicResult.exitCode == 0) {
        final output = (wmicResult.stdout as String).trim();
        // Format: "TotalVisibleMemorySize=16384000" (in KB)
        final match = RegExp(r'=(\d+)').firstMatch(output);
        if (match != null) {
          final kb = int.tryParse(match.group(1)!);
          if (kb != null) return kb ~/ 1024;
        }
      }
    } else if (Platform.isLinux) {
      // /proc/meminfo first line: "MemTotal:       16384000 kB"
      final file = File('/proc/meminfo');
      if (file.existsSync()) {
        final line = file.readAsLinesSync().firstWhere(
          (l) => l.startsWith('MemTotal'),
          orElse: () => '',
        );
        final match = RegExp(r'(\d+)').firstMatch(line);
        if (match != null) {
          final kb = int.tryParse(match.group(1)!);
          if (kb != null) return kb ~/ 1024;
        }
      }
    } else if (Platform.isMacOS) {
      // sysctl outputs: "hw.memsize: 17179869184" (in bytes)
      final result = Process.runSync('sysctl', ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        final bytes = int.tryParse((result.stdout as String).trim());
        if (bytes != null) return bytes ~/ (1 << 20);
      }
    }
  } on Object {
    // Any failure (permission, missing binary, unsupported platform) —
    // return -1 to trigger fallback.
  }
  return -1;
}

/// Initialize all caches with memory pressure handling.
///
/// Call this once at startup to register all caches.
void initializeCacheManagement({
  int maxFileContentCache = 500,
  int maxMetricsCache = 2000,
  int maxLocationCache = 2000,
  int maxSymbolCache = 1000,
  int maxCompilationUnitCache = 1000,
  int memoryThresholdMb = 512,
  // Lowered from 6144 to 4096: the Dart analysis server's default heap on
  // 64-bit is typically 4 GB, so 6 GB let the process OOM before the valve
  // could trip. 4 GB trips early enough to pause rule execution and shed
  // caches before the OS or runtime kills the process.
  int hardRssLimitMb = 4096,
}) {
  // Cap the LRU on the two largest unbounded caches.
  FileContentCache.setMaxPassedRulesFiles(maxFileContentCache);
  DiffBasedAnalysis.setMaxPreviousContentFiles(maxFileContentCache ~/ 2);

  // Register caches with priorities (lower = clear first when under pressure)
  // Content caches are expensive to rebuild, so clear last
  MemoryPressureHandler.registerCache(
    'stringInterner',
    StringInterner.clear,
    priority: 10, // Clear first - easy to rebuild
  );
  MemoryPressureHandler.registerCache(
    'contentFingerprint',
    ContentFingerprint.clearCache,
    priority: 20,
  );
  MemoryPressureHandler.registerCache(
    'lazyPatterns',
    LazyPatternCache.clearCache,
    priority: 25,
  );
  MemoryPressureHandler.registerCache(
    'contentRegions',
    ContentRegionIndex.clearCache,
    priority: 30,
  );
  MemoryPressureHandler.registerCache(
    'sourceLocation',
    SourceLocationCache.clearCache,
    priority: 40,
  );
  MemoryPressureHandler.registerCache(
    'semanticTokens',
    SemanticTokenCache.clearCache,
    priority: 50,
  );
  MemoryPressureHandler.registerCache(
    'compilationUnit',
    CompilationUnitCache.clearCache,
    priority: 60,
  );
  MemoryPressureHandler.registerCache(
    'fileMetrics',
    FileMetricsCache.clearCache,
    priority: 70,
  );
  MemoryPressureHandler.registerCache(
    'importGraph',
    ImportGraphCache.clearCache,
    priority: 80, // Expensive to rebuild
  );
  MemoryPressureHandler.registerCache(
    'fileContent',
    FileContentCache.clearCache,
    priority: 90, // Very expensive - clear last
  );

  // --- Caches NOT previously registered (unbounded per-file growth) ---
  //
  // Priority semantics (pre-existing — see relieve()):
  //   >= 50: cleared on SOFT relief (memory estimate exceeds threshold)
  //   <  50: cleared only on HARD relief (RSS valve trips at 4 GB)
  // Assign >= 50 to large per-file caches; < 50 to small stats or
  // expensive-to-rebuild registries.

  // Large per-file caches — clear on soft relief (>= 50).
  // Clearing _previousContent forces one full re-analysis pass (all lines
  // treated as changed), but that's a linear-time cost vs the OOM that
  // prompted the eviction. The cache repopulates on the very next pass.
  MemoryPressureHandler.registerCache(
    'diffBasedAnalysis',
    DiffBasedAnalysis.clearCache,
    priority: 65,
  );
  MemoryPressureHandler.registerCache(
    'incrementalAnalysisTracker',
    IncrementalAnalysisTracker.clearCache,
    priority: 55,
  );
  MemoryPressureHandler.registerCache(
    'parallelAnalyzer',
    ParallelAnalyzer.clearCache,
    priority: 55,
  );
  MemoryPressureHandler.registerCache(
    'baselineAwareEarlyExit',
    BaselineAwareEarlyExit.clearCache,
    priority: 50,
  );

  // Small stats / cheap caches — hard relief only (< 50).
  MemoryPressureHandler.registerCache(
    'throttledAnalysis',
    ThrottledAnalysis.clearAll,
    priority: 35,
  );
  MemoryPressureHandler.registerCache(
    'speculativeAnalysis',
    SpeculativeAnalysis.clearAll,
    priority: 35,
  );
  MemoryPressureHandler.registerCache(
    'hotPathProfiler',
    HotPathProfiler.clear,
    priority: 30,
  );
  MemoryPressureHandler.registerCache(
    'ruleExecutionStats',
    RuleExecutionStats.clearStats,
    priority: 25,
  );
  MemoryPressureHandler.registerCache(
    'violationBatch',
    ViolationBatch.clear,
    priority: 20,
  );
  MemoryPressureHandler.registerCache(
    'gitAwarePriority',
    GitAwarePriority.clear,
    priority: 30,
  );
  MemoryPressureHandler.registerCache(
    'rulePriorityQueue',
    RulePriorityQueue.clear,
    priority: 25,
  );
  MemoryPressureHandler.registerCache(
    'ruleBatchExecutor',
    RuleBatchExecutor.clear,
    priority: 30,
  );
  MemoryPressureHandler.registerCache(
    'ruleGroupExecutor',
    RuleGroupExecutor.clear,
    priority: 30,
  );

  // Expensive to rebuild — hard relief only (< 50).
  MemoryPressureHandler.registerCache(
    'consolidatedVisitorDispatch',
    ConsolidatedVisitorDispatch.clear,
    priority: 15,
  );
  MemoryPressureHandler.registerCache(
    'ruleDependencyGraph',
    RuleDependencyGraph.clear,
    priority: 15,
  );

  // Enable automatic relief
  MemoryPressureHandler.enableAutoRelief(
    thresholdMb: memoryThresholdMb,
    checkIntervalFiles: 50,
  );

  // Arm the hard RSS safety valve. This is the real protection against the
  // analysis server growing to ~10 GB on very large projects: when actual
  // process RSS crosses the cap, rule execution pauses. The soft relief above
  // only sees the plugin's own caches; this reads the true process size. The
  // env override lets a consumer tune the cap (or disable it with 0) without a
  // plugin release.
  //
  // Adaptive cap: if system RAM is detectable, cap at 60% of physical RAM
  // (the analysis server shares memory with the IDE, OS, and other tools).
  // Falls back to the hardRssLimitMb parameter default (4096 MB) when RAM
  // detection fails or returns an implausible value.
  final envCap = Platform.environment['SAROPA_LINTS_MAX_RSS_MB'];
  final parsedCap = envCap == null ? null : int.tryParse(envCap.trim());
  final adaptiveCap = _computeAdaptiveRssCap(hardRssLimitMb);
  final effectiveCap = parsedCap ?? adaptiveCap;
  MemoryPressureHandler.setHardRssLimitMb(effectiveCap);

  // Graduated rule shedding is armed by the config loader
  // (`_loadShedRulesConfig` in native/config_loader.dart), which reads
  // `shed_rules: true` from analysis_options_custom.yaml — or the legacy
  // SAROPA_LINTS_SHED_RULES env var — and runs before this function on
  // plugin start. Nothing to do here; kept as a no-op anchor point so a
  // reader tracing "how is shedding armed" lands on this comment.

  // Diagnostic: verify ProcessInfo.currentRss works on this platform.
  final startupRss = MemoryPressureHandler._currentRssMb();
  if (startupRss > 0) {
    // Log cap source so users understand the value.
    final capSource = parsedCap != null
        ? 'env SAROPA_LINTS_MAX_RSS_MB'
        : adaptiveCap != hardRssLimitMb
        ? 'adaptive (60% of system RAM)'
        : 'default';
    stderr.writeln(
      '[saropa_lints] Memory management armed: '
      '${MemoryPressureHandler._caches.length} caches registered, '
      'soft relief at ${memoryThresholdMb}MB estimated, '
      'hard RSS cap at ${effectiveCap}MB ($capSource). '
      'Current RSS: ${startupRss}MB.',
    );
  } else {
    stderr.writeln(
      '[saropa_lints] WARNING: ProcessInfo.currentRss unavailable on this '
      'platform — hard RSS safety valve is INERT. Only heuristic cache-size '
      'relief is active (threshold: ${memoryThresholdMb}MB).',
    );
  }
}
