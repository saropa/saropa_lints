// ignore_for_file: depend_on_referenced_packages

/// Native analyzer plugin entry point for saropa_lints.
///
/// The analysis server discovers this via `lib/main.dart` and accesses
/// the top-level [plugin] variable.
///
/// Consumer projects enable this in `analysis_options.yaml`:
/// ```yaml
/// plugins:
///   saropa_lints: ^5.0.0
/// ```
library;

import 'dart:async' show FutureOr;
import 'dart:convert' show jsonEncode;
import 'dart:io' show Directory, File, Platform;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'saropa_lints.dart';
import 'src/config/runtime_tier_cap.dart' show RuntimeTierCap;
import 'src/native/plugin_logger.dart' show PluginLogger;
import 'src/report/import_graph_tracker.dart' show ImportGraphTracker;

// ---------------------------------------------------------------------------
// Plugin discovery: analysis server loads this file and reads [plugin].
// ---------------------------------------------------------------------------

/// Top-level plugin instance discovered by the analysis server.
final plugin = SaropaLintsPlugin();

/// Native analyzer plugin for saropa_lints.
///
/// [start] loads YAML/env into [SaropaLintRule] statics via
/// [loadNativePluginConfig]. [register] forwards to [registerSaropaLintRules]
/// so composite meta-plugins reuse the same registration path without
/// duplicating logic.
class SaropaLintsPlugin extends Plugin {
  @override
  String get name => 'saropa_lints';

  /// Loads plugin configuration (enabled rules, severity overrides, etc.)
  /// from analysis_options / SAROPA env vars before rules are registered.
  ///
  /// Logs the start event via [PluginLogger] — the entry will be buffered
  /// in memory until [loadNativePluginConfigFromProjectRoot] runs and
  /// [PluginLogger.setProjectRoot] is called on the first analyzed file, then
  /// flushed to `reports/.saropa_lints/plugin.log` so users have a visible
  /// surface confirming the plugin actually started.
  @override
  FutureOr<void> start() {
    PluginLogger.log('Plugin.start() — loading initial config');

    // Arm the rapid-edit gate: this runs ONLY inside the interactive analysis
    // server (no bin/ CLI instantiates the plugin), so it is the reliable signal
    // that in-flux relief is safe. Batch runners (scan/baseline/health, `dart
    // analyze`) leave this false and therefore report every rule at full
    // fidelity. See SaropaLintRule.deferForRapidEdit / isAnalysisServer.
    SaropaLintRule.isAnalysisServer = true;

    // Mark the plugin as started BEFORE the cwd check so the essential-tier
    // default applies on the lazy config reload from the real project root.
    markNativePluginStarted();

    // Skip initial config load when cwd is not a Dart project (e.g. when the
    // analysis server sets cwd to the VS Code install dir). The real config
    // will load from the project root on the first analyzed file via
    // SaropaContext._ensureConfigLoadedFromProjectRoot(). Loading from a
    // non-project cwd produces a noisy 0-rules phase in the log.
    final sep = Platform.pathSeparator;
    final cwdHasPubspec = File(
      '${Directory.current.path}${sep}pubspec.yaml',
    ).existsSync();

    if (cwdHasPubspec) {
      try {
        loadNativePluginConfig();
      } on Object catch (e, st) {
        PluginLogger.error(
          'loadNativePluginConfig failed in Plugin.start()',
          error: e,
          stackTrace: st,
        );
        // Defensive: plugin still registers with defaults
      }
    } else {
      PluginLogger.debug(
        'Plugin.start() — cwd is not a Dart project '
        '(${Directory.current.path}), deferring config to project root',
      );
    }

    // Arm the memory-relief subsystem. Before this call,
    // initializeCacheManagement() was defined but never invoked anywhere, so
    // MemoryPressureHandler stayed disabled: none of the plugin's own caches
    // (compilation-unit, file-content, metrics, source-location, semantic
    // tokens, import-graph, string interner, …) were ever registered for
    // eviction, and auto-relief never armed. They therefore grew for the
    // entire analysis-server process lifetime. Wiring it here bounds the
    // plugin's OWN footprint and sheds it under pressure.
    //
    // Scope honesty: this caps the plugin's caches only (sub-GB on a large
    // project). It does NOT bound the analyzer's resolved element/AST model,
    // which is the dominant cost when many element-resolving rules run over a
    // large codebase under strict modes — that is reduced by doing less
    // resolution, not by cache relief.
    try {
      initializeCacheManagement();
      // initializeCacheManagement registers the project_context caches but not
      // the report-layer ImportGraphTracker, which holds a per-file set of
      // import/export URIs for every analyzed file and is never evicted across
      // the server lifetime. Register it for pressure relief at clear-late
      // priority (rebuilding the graph requires re-walking files, so shed it
      // only after cheaper caches). Non-destructive in normal operation — it
      // is cleared only when the memory estimate crosses the threshold, and
      // repopulates as files are re-analyzed.
      MemoryPressureHandler.registerCache(
        'importGraphTracker',
        ImportGraphTracker.reset,
        priority: 85,
      );

      // Register saropa_lint_rule.dart caches (separate library, not
      // reachable from initializeCacheManagement's project_context library).
      //
      // ImpactTracker, SuppressionTracker, and ProgressTracker are
      // forward-accumulating session counters — clearing them mid-session
      // truncates the analysis summary. They are registered at priority < 50
      // so they shed ONLY on hard RSS relief (OOM imminent), not on soft
      // relief. A truncated summary is acceptable when the alternative is
      // crashing the analysis server.
      //
      // NOTE: BaselineManager is NOT registered — its reset() nulls _config,
      // permanently disabling baseline suppression with no lazy re-init path.
      MemoryPressureHandler.registerCache(
        'impactTracker',
        ImpactTracker.reset,
        // Hard-relief only: losing violation records beats OOM crash.
        priority: 15,
      );
      MemoryPressureHandler.registerCache(
        'suppressionTracker',
        SuppressionTracker.reset,
        // Hard-relief only: suppression counts are diagnostic, not critical.
        priority: 15,
      );
      MemoryPressureHandler.registerCache(
        'progressTrackerMaps',
        ProgressTracker.releasePerFileMaps,
        // Hard-relief only: per-file maps are the largest ProgressTracker
        // allocation; scalar counters survive for limit tracking.
        priority: 20,
      );
      // Include tracker footprints in the soft-relief memory estimate so
      // auto-relief fires earlier on projects that accumulate many violations.
      // Named registration is idempotent — safe if start() re-runs.
      MemoryPressureHandler.registerEstimator(
        'saropa_lint_trackers',
        () => ImpactTracker.estimatedBytes + SuppressionTracker.estimatedBytes,
      );

      MemoryPressureHandler.registerCache(
        'ruleTimingTracker',
        RuleTimingTracker.reset,
        priority: 55,
      );

      // Baseline date cache and config caches are recomputable.
      MemoryPressureHandler.registerCache(
        'baselineDate',
        BaselineDate.clearCache,
        priority: 55,
      );
      MemoryPressureHandler.registerCache(
        'runtimeTierCap',
        RuntimeTierCap.clearCache,
        priority: 60,
      );
      // Write memory_state.json on shed-level transitions so the VS Code
      // extension can surface pressure in the status bar without polling.
      MemoryPressureHandler.onShedLevelChanged = (shedLevel, rssMb) =>
          _writeMemoryStateFile(shedLevel, rssMb);
    } on Object catch (e, st) {
      PluginLogger.error(
        'initializeCacheManagement failed in Plugin.start()',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Registers enabled rules and their quick-fix generators with the server.
  ///
  /// Delegates to [registerSaropaLintRules] so composite plugins can share the
  /// same registration path.
  @override
  void register(PluginRegistry registry) {
    PluginLogger.log('Plugin.register() — registering rules with analyzer');
    registerSaropaLintRules(registry);
  }
}

/// Writes `memory_state.json` alongside `plugin.log` on shed-level transitions.
///
/// The VS Code extension watches this file via `fs.watch` and surfaces
/// memory-pressure state in the status bar. Written only when the shed level
/// or hard-limit trip state changes — not periodically.
void _writeMemoryStateFile(int shedLevel, int rssMb) {
  try {
    final logPath = PluginLogger.logFilePath;
    if (logPath == null) return;

    // Derive the reports directory from the log file's parent.
    final dir = File(logPath).parent.path;
    final stats = MemoryPressureHandler.getStats();
    final payload = jsonEncode({
      'shedLevel': shedLevel,
      'rssMb': rssMb,
      'softLimitMb': stats['softLimitMb'],
      'hardLimitMb': stats['hardLimitMb'],
      'softLimitTripped': stats['softLimitTripped'],
      'hardLimitTripped': stats['hardLimitTripped'],
      'shedRuleCount': stats['shedRuleCount'],
      'shedEnabled': stats['shedEnabled'],
      'timestamp': DateTime.now().toIso8601String(),
    });
    File('$dir/memory_state.json').writeAsStringSync(payload);
  } on Object catch (e, st) {
    // Never crash the plugin on a state-file write failure.
    PluginLogger.error(
      'Failed to write memory_state.json',
      error: e,
      stackTrace: st,
    );
  }
}
