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
    node.prev = null;
    node.next = _head;

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

  // Configuration
  static int _thresholdMb = 512; // Default 512MB threshold
  static bool _autoReliefEnabled = false;
  static int _checkIntervalFiles = 50; // Check every N files
  static int _filesProcessed = 0;

  // Statistics
  static int _relieveCount = 0;
  static DateTime? _lastRelieve;

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
  /// If [clearAll] is false, only clears low-priority caches.
  /// If [clearAll] is true, clears everything.
  static void relieve({bool clearAll = false}) {
    _relieveCount++;
    _lastRelieve = DateTime.now();

    // Sort by priority (low priority = clear first)
    final sorted = _caches.values.toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    // Clear caches by priority
    for (final cache in sorted) {
      if (clearAll || cache.priority >= 50) {
        cache.clear();
      }
    }
  }

  /// Force clear all registered caches.
  static void clearAll() {
    for (final cache in _caches.values) {
      cache.clear();
    }
  }

  /// Estimate current memory usage from known cache sizes.
  static int _estimateMemoryUsageMb() {
    // Rough estimation based on typical cache entry sizes
    var estimatedBytes = 0;

    // File content cache: ~1KB per file (hash + rules set)
    estimatedBytes += FileContentCache._contentHashes.length * 1024;

    // Metrics cache: ~200 bytes per entry
    estimatedBytes += FileMetricsCache._cache.length * 200;

    // Source location cache: ~1KB per file (line starts array)
    estimatedBytes += SourceLocationCache._lineStarts.length * 1024;

    // Semantic token cache: ~500 bytes per symbol
    for (final symbols in SemanticTokenCache._symbols.values) {
      estimatedBytes += symbols.length * 500;
    }

    // Compilation unit cache: ~2KB per file
    estimatedBytes += CompilationUnitCache._cache.length * 2048;

    // Import graph: ~500 bytes per node
    estimatedBytes += ImportGraphCache._graph.length * 500;

    // String intern pool: actual string sizes
    for (final s in StringInterner._pool.keys) {
      estimatedBytes += s.length * 2; // UTF-16
    }

    const bytesPerMb = 1 << 20; // 1024 * 1024
    return estimatedBytes ~/ bytesPerMb;
  }

  /// Get statistics.
  static Map<String, dynamic> getStats() {
    return {
      'registeredCaches': _caches.length,
      'autoReliefEnabled': _autoReliefEnabled,
      'thresholdMb': _thresholdMb,
      'estimatedUsageMb': _estimateMemoryUsageMb(),
      'relieveCount': _relieveCount,
      'lastRelieve': _lastRelieve?.toIso8601String(),
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
}) {
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

  // Enable automatic relief
  MemoryPressureHandler.enableAutoRelief(
    thresholdMb: memoryThresholdMb,
    checkIntervalFiles: 50,
  );
}
