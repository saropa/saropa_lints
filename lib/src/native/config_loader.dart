// ignore_for_file: depend_on_referenced_packages

/// Loads saropa_lints configuration for the native analyzer plugin.
///
/// **When:** Called once from [SaropaLintsPlugin.start] before [register].
/// **Where:** Project root = [Directory.current]; files: analysis_options.yaml,
/// analysis_options_custom.yaml. Env vars (e.g. SAROPA_LINTS_MAX) override where applicable.
///
/// Populates:
/// - [SaropaLintRule.severityOverrides] and [SaropaLintRule.disabledRules]
/// - [BaselineManager] (baseline path, enabled)
/// - [ProgressTracker] (max_issues, file-only output)
/// - [BannedUsageConfig] from custom yaml
library;

import 'dart:developer' as developer;
import 'dart:io' show Directory, File, Platform;

import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

import '../banned_usage_config.dart';
import '../baseline/baseline_config.dart';
import '../baseline/baseline_manager.dart';
import '../saropa_lint_rule.dart' show ProgressTracker, SaropaLintRule;

/// Loads all plugin configuration from yaml and environment variables.
/// Order matters: severity overrides first, then diagnostics (enable/disable),
/// then baseline, banned usage, and output (max_issues, file-only).
/// Safe to call multiple times — static fields are simply overwritten.
/// Never throws; failures in any step are caught and the rest still run.
void loadNativePluginConfig() {
  try {
    final content = _readProjectFile('analysis_options_custom.yaml');
    _loadSeverityOverrides(content);
    _loadDiagnosticsConfig();
    _loadBaselineConfig(content);
    loadBannedUsageConfig(content);
    _loadOutputConfig(content);
  } catch (e, st) {
    developer.log(
      'loadNativePluginConfig failed',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    // Defensive: ensure plugin can still register with defaults
  }
}

/// Read a yaml file from the project root. Returns null if not found or on error.
String? _readProjectFile(String filename) {
  if (filename.isEmpty) return null;
  try {
    final currentPath = Directory.current.path;
    if (currentPath.isEmpty) return null;
    final sep = Platform.pathSeparator;
    final path = '$currentPath$sep$filename';
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (e, st) {
    developer.log(
      '_readProjectFile failed',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    // I/O or path error; return null so config steps use defaults
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

    final ruleName = match.group(1);
    final value = match.group(2);
    if (ruleName == null || ruleName.isEmpty || value == null) continue;

    switch (value.toUpperCase()) {
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

/// Parse `diagnostics:` section from `analysis_options.yaml`.
///
/// The init command generates rule enable/disable config here:
/// ```yaml
/// plugins:
///   saropa_lints:
///     diagnostics:
///       rule_name: true   # enabled
///       rule_name: false  # disabled
/// ```
///
/// Rules marked `false` are added to [SaropaLintRule.disabledRules].
/// This merges with any rules already disabled by `severities:` in the
/// custom config file.
void _loadDiagnosticsConfig() {
  final content = _readProjectFile('analysis_options.yaml');
  if (content == null) return;

  final sectionMatch = RegExp(
    r'^\s+diagnostics:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final disabled = SaropaLintRule.disabledRules ?? <String>{};
  final lines = content.substring(sectionMatch.end).split('\n');

  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    // diagnostics entries are indented 6+ spaces; stop at less indentation
    if (!line.startsWith('      ')) break;

    final match = RegExp(r'^\s+([\w_]+):\s*(true|false)').firstMatch(line);
    if (match == null) continue;

    final ruleName = match.group(1);
    if (match.group(2) == 'false' && ruleName != null && ruleName.isNotEmpty) {
      disabled.add(ruleName);
    }
  }

  if (disabled.isNotEmpty) {
    SaropaLintRule.disabledRules = disabled;
  }
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
    final listItem = listMatch?.group(1);
    if (listMatch != null && currentList != null && listItem != null) {
      currentList.add(listItem);
      continue;
    }

    // Key-value: "  key: value" or "  key:"
    final kvMatch = RegExp(r'^\s+(\w+):\s*(.*)$').firstMatch(line);
    final key = kvMatch?.group(1);
    final value = (kvMatch?.group(2) ?? '').trim();
    if (kvMatch == null || key == null || key.isEmpty) continue;

    // Flush previous list
    if (currentList != null && currentListKey != null) {
      map[currentListKey] = currentList;
      currentList = null;
      currentListKey = null;
    }

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
  } catch (e, st) {
    developer.log(
      '_loadOutputConfig env read failed',
      name: 'saropa_lints',
      error: e,
      stackTrace: st,
    );
    // Platform.environment may throw on some platforms
  }

  if (maxFromEnv && outputFromEnv) return;
  if (content == null) return;

  if (!maxFromEnv) {
    final match = RegExp(
      r'^max_issues:\s*(\d+)',
      multiLine: true,
    ).firstMatch(content);
    final group1 = match?.group(1);
    if (match != null && group1 != null) {
      final value = int.tryParse(group1);
      if (value != null) ProgressTracker.setMaxIssues(value);
    }
  }

  if (!outputFromEnv) {
    final match = RegExp(
      r'^output:\s*(\w+)',
      multiLine: true,
    ).firstMatch(content);
    final outputGroup = match?.group(1);
    if (match != null &&
        outputGroup != null &&
        outputGroup.toLowerCase() == 'file') {
      ProgressTracker.setFileOnly(fileOnly: true);
    }
  }
}
