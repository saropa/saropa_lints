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
import 'src/native/config_loader.dart';

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

  /// Loads plugin configuration before rules are registered.
  @override
  FutureOr<void> start() {
    loadNativePluginConfig();
  }

  @override
  void register(PluginRegistry registry) {
    final disabled = SaropaLintRule.disabledRules;
    for (final rule in allSaropaRules) {
      if (disabled != null && disabled.contains(rule.code.name)) {
        continue;
      }

      registry.registerLintRule(rule);

      for (final generator in rule.fixGenerators) {
        registry.registerFixForRule(rule.code, generator);
      }
    }
  }
}
