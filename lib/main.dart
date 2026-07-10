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

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'saropa_lints.dart';
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

    try {
      loadNativePluginConfig();
    } on Object catch (e, st) {
      PluginLogger.log(
        'loadNativePluginConfig failed in Plugin.start()',
        error: e,
        stackTrace: st,
      );
      // Defensive: plugin still registers with defaults
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
    } on Object catch (e, st) {
      PluginLogger.log(
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
