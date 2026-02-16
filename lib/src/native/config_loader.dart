// ignore_for_file: depend_on_referenced_packages

/// Loads saropa_lints configuration for the native analyzer plugin.
///
/// Called once from [SaropaLintsPlugin.start] to populate:
/// - [SaropaLintRule.severityOverrides] and [SaropaLintRule.disabledRules]
/// - [BaselineManager] configuration
/// - [ProgressTracker] output settings (max_issues, output mode)
///
/// Reads `analysis_options_custom.yaml` from the project root using the same
/// path resolution as the v4 plugin (`Directory.current`).
library;

import 'dart:io' show Directory, File, Platform;

import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

import '../baseline/baseline_config.dart';
import '../baseline/baseline_manager.dart';
import '../saropa_lint_rule.dart' show ProgressTracker, SaropaLintRule;

/// Loads all plugin configuration from yaml and environment variables.
///
/// Safe to call multiple times — static fields are simply overwritten.
void loadNativePluginConfig() {
  final content = _readConfigFile();
  _loadSeverityOverrides(content);
  _loadBaselineConfig(content);
  _loadOutputConfig(content);
}

/// Read the custom yaml config file. Returns null if not found.
String? _readConfigFile() {
  try {
    final sep = Platform.pathSeparator;
    final path = '${Directory.current.path}${sep}analysis_options_custom.yaml';
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (_) {
    return null;
  }
}

/// Parse `severities:` section from the config file.
///
/// Supported formats:
/// ```yaml
/// severities:
///   avoid_debug_print: ERROR
///   no_magic_number: false
///   prefer_const: INFO
/// ```
///
/// Values: `ERROR`, `WARNING`, `INFO`, or `false` (disables the rule).
void _loadSeverityOverrides(String? content) {
  if (content == null) {
    SaropaLintRule.severityOverrides = null;
    SaropaLintRule.disabledRules = null;
    return;
  }

  final sectionMatch = RegExp(
    r'^severities:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final overrides = <String, DiagnosticSeverity>{};
  final disabled = <String>{};

  final lines = content.substring(sectionMatch.end).split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith('  ')) break;

    final match = RegExp(r'^\s+(\w+):\s*(\S+)').firstMatch(line);
    if (match == null) continue;

    final ruleName = match.group(1)!;
    final value = match.group(2)!.toUpperCase();

    switch (value) {
      case 'ERROR':
        overrides[ruleName] = DiagnosticSeverity.ERROR;
      case 'WARNING':
        overrides[ruleName] = DiagnosticSeverity.WARNING;
      case 'INFO':
        overrides[ruleName] = DiagnosticSeverity.INFO;
      case 'FALSE':
        disabled.add(ruleName);
    }
  }

  SaropaLintRule.severityOverrides = overrides.isEmpty ? null : overrides;
  SaropaLintRule.disabledRules = disabled.isEmpty ? null : disabled;
}

/// Parse `baseline:` section and initialize [BaselineManager].
///
/// ```yaml
/// baseline:
///   file: "saropa_baseline.json"
///   date: "2025-01-15"
///   paths:
///     - "lib/legacy/"
/// ```
void _loadBaselineConfig(String? content) {
  if (content == null) return;

  final sectionMatch = RegExp(
    r'^baseline:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final map = _parseBaselineSection(content, sectionMatch.end);
  final config = BaselineConfig.fromYaml(map);
  if (config.isEnabled) {
    BaselineManager.initialize(config, projectRoot: Directory.current.path);
  }
}

/// Parse the baseline section into a Map for [BaselineConfig.fromYaml].
Map<String, Object> _parseBaselineSection(String content, int offset) {
  final map = <String, Object>{};
  final lines = content.substring(offset).split('\n');
  List<String>? currentList;
  String? currentListKey;

  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith('  ')) break;

    // List item: "    - value"
    final listMatch = RegExp(r'^\s+-\s+"?([^"]+)"?$').firstMatch(line);
    if (listMatch != null && currentList != null) {
      currentList.add(listMatch.group(1)!);
      continue;
    }

    // Key-value: "  key: value" or "  key:"
    final kvMatch = RegExp(r'^\s+(\w+):\s*(.*)$').firstMatch(line);
    if (kvMatch == null) continue;

    // Flush previous list
    if (currentList != null && currentListKey != null) {
      map[currentListKey] = currentList;
      currentList = null;
      currentListKey = null;
    }

    final key = kvMatch.group(1)!;
    final value = kvMatch.group(2)!.trim();

    if (value.isEmpty) {
      // Start of a list section
      currentListKey = key;
      currentList = <String>[];
    } else {
      map[key] = value.replaceAll('"', '');
    }
  }

  // Flush final list
  if (currentList != null && currentListKey != null) {
    map[currentListKey] = currentList;
  }

  return map;
}

/// Load max_issues and output config (env vars take priority over yaml).
///
/// Reuses the same logic as v4's `_loadAnalysisConfig()`.
void _loadOutputConfig(String? content) {
  var maxFromEnv = false;
  var outputFromEnv = false;

  try {
    final envMax = Platform.environment['SAROPA_LINTS_MAX'];
    if (envMax != null) {
      final value = int.tryParse(envMax);
      if (value != null) {
        ProgressTracker.setMaxIssues(value);
        maxFromEnv = true;
      }
    }

    final envOutput = Platform.environment['SAROPA_LINTS_OUTPUT'];
    if (envOutput != null) {
      final normalized = envOutput.toLowerCase();
      if (normalized == 'file' || normalized == 'both') {
        ProgressTracker.setFileOnly(fileOnly: normalized == 'file');
      }
      outputFromEnv = true;
    }
  } catch (_) {
    // Platform.environment may throw on some platforms
  }

  if (maxFromEnv && outputFromEnv) return;
  if (content == null) return;

  if (!maxFromEnv) {
    final match = RegExp(
      r'^max_issues:\s*(\d+)',
      multiLine: true,
    ).firstMatch(content);
    if (match != null) {
      final value = int.tryParse(match.group(1)!);
      if (value != null) ProgressTracker.setMaxIssues(value);
    }
  }

  if (!outputFromEnv) {
    final match = RegExp(
      r'^output:\s*(\w+)',
      multiLine: true,
    ).firstMatch(content);
    if (match != null && match.group(1)!.toLowerCase() == 'file') {
      ProgressTracker.setFileOnly(fileOnly: true);
    }
  }
}
