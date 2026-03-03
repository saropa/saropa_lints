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
import 'src/native/config_loader.dart';

// ---------------------------------------------------------------------------
// Plugin discovery: analysis server loads this file and reads [plugin].
// ---------------------------------------------------------------------------

/// Top-level plugin instance discovered by the analysis server.
final plugin = SaropaLintsPlugin();

/// Native analyzer plugin for saropa_lints.
///
/// Registers all lint rules with the analysis server's [PluginRegistry].
/// Rules extend [SaropaLintRule] which bridges the callback-based
/// pattern to the native visitor system.
class SaropaLintsPlugin extends Plugin {
  @override
  String get name => 'saropa_lints';

  /// Loads plugin configuration (severity overrides, disabled rules, etc.)
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

  /// Registers each rule and its quick-fix generators with the analysis server.
  /// Disabled rules (from config) are skipped; all others get rule + fixes.
  /// Invalid rules (null code or empty name) are skipped defensively.
  @override
  void register(PluginRegistry registry) {
    try {
      final rules = allSaropaRules;
      if (rules.isEmpty) return;

      final disabled = SaropaLintRule.disabledRules;
      for (final rule in rules) {
        final code = rule.code;
        if (code.name.isEmpty) continue;

        if (disabled != null && disabled.contains(code.name)) {
          continue;
        }

        registry.registerLintRule(rule);

        for (final generator in rule.fixGenerators) {
          registry.registerFixForRule(code, generator);
        }
      }
    } catch (e, st) {
      developer.log(
        'register(PluginRegistry) failed',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      // Defensive: avoid bringing down the analysis server
    }
  }
}
