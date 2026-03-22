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
import 'dart:developer' as developer;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'saropa_lints.dart';

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
  @override
  FutureOr<void> start() {
    try {
      loadNativePluginConfig();
    } catch (e, st) {
      developer.log(
        'loadNativePluginConfig failed',
        name: 'saropa_lints',
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
    registerSaropaLintRules(registry);
  }
}
