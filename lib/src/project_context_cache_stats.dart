part of 'project_context.dart';

/// Aggregates statistics from all caches in one call.
///
/// Useful for debugging and monitoring. Read-only; does not change
/// analysis correctness or performance.
///
/// Usage:
/// ```dart
/// final stats = CacheStatsAggregator.getStats();
/// print(stats);
/// ```
class CacheStatsAggregator {
  CacheStatsAggregator._();

  /// Returns a single map with keys per cache (e.g. [importGraph], [throttle]).
  /// Each value is the result of that cache's getStats().
  static Map<String, dynamic> getStats() {
    final out = <String, dynamic>{};

    void add(String key, Map<String, dynamic>? value) {
      if (value != null && value.isNotEmpty) {
        out[key] = value;
      }
    }

    add('importGraph', _safeStats(ImportGraphCache.getStats));
    add('sourceLocation', _safeStats(SourceLocationCache.getStats));
    add('throttle', _safeStats(ThrottledAnalysis.getStats));
    add('speculative', _safeStats(SpeculativeAnalysis.getStats));
    add('ruleGroupExecutor', _safeStats(RuleGroupExecutor.getStats));
    add('stringInterner', _safeStats(StringInterner.getStats));
    add('hotPathProfiler', _safeStats(HotPathProfiler.getStats));
    add('memoryPressure', _safeStats(MemoryPressureHandler.getStats));
    add('parallelAnalyzer', _safeStats(ParallelAnalyzer.getStats));
    add('ruleBatchExecutor', _safeStats(RuleBatchExecutor.getStats));
    add('baselineAwareEarlyExit', _safeStats(BaselineAwareEarlyExit.getStats));
    add('diffBasedAnalysis', _safeStats(DiffBasedAnalysis.getStats));
    add('semanticToken', _safeStats(SemanticTokenCache.getStats));
    add('compilationUnit', _safeStats(CompilationUnitCache.getStats));
    add('incrementalTracker', _safeStats(IncrementalAnalysisTracker.getStats));

    return out;
  }

  static Map<String, dynamic>? _safeStats(Map<String, dynamic> Function() fn) {
    try {
      return fn();
    } catch (_) {
      return null;
    }
  }
}
