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
  /// in memory until [SaropaContext._ensureConfigLoadedFromProjectRoot]
  /// calls [PluginLogger.setProjectRoot] on the first analyzed file, then
  /// flushed to `reports/.saropa_lints/plugin.log` so users have a visible
  /// surface confirming the plugin actually started.
  @override
  FutureOr<void> start() {
    PluginLogger.log('Plugin.start() — loading initial config');
    try {
      loadNativePluginConfig();
    } catch (e, st) {
      PluginLogger.log(
        'loadNativePluginConfig failed in Plugin.start()',
        error: e,
        stackTrace: st,
      );
      // Defensive: plugin still registers with defaults
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
