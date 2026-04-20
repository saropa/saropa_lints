// ignore_for_file: depend_on_referenced_packages

/// Loads saropa_lints configuration for the native analyzer plugin.
///
/// **When:** Called once from [SaropaLintsPlugin.start] before [register].
/// **Where:** Project root = [Directory.current]; files: analysis_options.yaml,
/// analysis_options_custom.yaml. Env vars (e.g. SAROPA_LINTS_MAX) override where applicable.
///
/// Populates:
/// - [SaropaLintRule.enabledRules] (diagnostics `true` + severity-implied enables +
///   rule pack codes from `rule_packs.enabled`, excluding [disabledRules])
/// - [SaropaLintRule.severityOverrides] and [SaropaLintRule.disabledRules]
/// - [BaselineManager] (baseline path, enabled)
/// - [ProgressTracker] (max_issues, file-only output)
/// - [BannedUsageConfig] from custom yaml
library;

import 'dart:io' show Directory, File, Platform;

import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

import '../banned_usage_config.dart';
import '../baseline/baseline_config.dart';
import '../baseline/baseline_manager.dart';
import '../config/analysis_options_rule_packs.dart';
import '../config/pubspec_lock_resolver.dart';
import '../config/rule_packs.dart';
import '../saropa_lint_rule.dart' show ProgressTracker, SaropaLintRule;
import 'plugin_logger.dart' show PluginLogger;

/// Loads all plugin configuration from yaml and environment variables.
/// Order matters: severity overrides first, then diagnostics (enable/disable),
/// then **rule packs** (adds enabled rule codes; skips [disabledRules]),
/// then baseline, banned usage, and output (max_issues, file-only).
/// Safe to call multiple times — static fields are simply overwritten.
/// Never throws; failures in any step are caught and the rest still run.
///
/// Uses [Directory.current] to locate config files. This works for CLI
/// invocations where cwd == project root, but fails silently for the
/// analyzer-launched plugin where cwd is the analysis-server process's
/// working directory (often the user's home or wherever the IDE was
/// launched from). For that path, see [loadNativePluginConfigFromProjectRoot],
/// triggered lazily by [SaropaContext._wrapCallback] once the real project
/// root can be derived from an analyzed file path.
void loadNativePluginConfig() {
  _loadFromRoot(null);
}

/// Reloads all plugin configuration using a known [projectRoot] instead of
/// [Directory.current]. Call when the analyzer supplies a file path from
/// which the real project root can be derived (walk up to `pubspec.yaml`).
///
/// This is the fix for the analyzer-launched-plugin bug where the plugin's
/// `start()` runs with cwd set to the analysis-server process's working
/// directory, not the consumer project. Without a reload from the real
/// project root, [SaropaLintRule.enabledRules] stays null and every rule
/// is silently gated off at visitor-entry time.
///
/// Safe to call multiple times — static fields are simply overwritten.
/// Never throws; failures in any step are caught and the rest still run.
void loadNativePluginConfigFromProjectRoot(String projectRoot) {
  if (projectRoot.isEmpty) return;
  _loadFromRoot(projectRoot);
}

/// Shared implementation for config loading from an optional [projectRoot].
/// When null, falls back to [Directory.current].
void _loadFromRoot(String? projectRoot) {
  try {
    final content = _readProjectFile(
      'analysis_options_custom.yaml',
      projectRoot,
    );
    _loadSeverityOverrides(content);
    _loadDiagnosticsConfig(projectRoot);
    if (projectRoot != null) {
      loadRulePacksConfigFromProjectRoot(projectRoot);
    } else {
      _loadRulePacksConfig();
    }
    _loadBaselineConfig(content);
    loadBannedUsageConfig(content);
    _loadOutputConfig(content);

    // Success telemetry — visible in reports/.saropa_lints/plugin.log once
    // the project root is set. This is the primary signal users can check
    // to confirm the fix landed and their config was actually read.
    final enabledCount = SaropaLintRule.enabledRules?.length ?? 0;
    PluginLogger.log(
      'Config loaded from ${projectRoot ?? Directory.current.path} — '
      'enabledRules: $enabledCount',
    );
  } catch (e, st) {
    PluginLogger.log('loadNativePluginConfig failed', error: e, stackTrace: st);
    // Defensive: ensure plugin can still register with defaults
  }
}

/// Read a yaml file from the project root. Returns null if not found or on error.
/// Uses [Directory.current] when no [projectRoot] is given (e.g. at plugin start).
String? _readProjectFile(String filename, [String? projectRoot]) {
  if (filename.isEmpty) return null;
  try {
    final basePath = projectRoot ?? Directory.current.path;
    if (basePath.isEmpty) return null;
    final sep = Platform.pathSeparator;
    final path = '$basePath$sep$filename';
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } catch (e, st) {
    PluginLogger.log('_readProjectFile failed', error: e, stackTrace: st);
    // I/O or path error; return null so config steps use defaults
    return null;
  }
}

/// Load max_issues and output from analysis_options_custom.yaml in [projectRoot].
/// Call this when the project root is first known (e.g. from first analyzed file),
/// so config is found even when the plugin runs with cwd in a temp directory.
/// Safe to call multiple times; env vars still take precedence over file.
void loadOutputConfigFromProjectRoot(String projectRoot) {
  try {
    final content = _readProjectFile(
      'analysis_options_custom.yaml',
      projectRoot,
    );
    if (content != null) _loadOutputConfig(content);
  } catch (e, st) {
    PluginLogger.log(
      'loadOutputConfigFromProjectRoot failed',
      error: e,
      stackTrace: st,
    );
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
    SaropaLintRule.enabledRules = null;
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

  // Severity overrides with a level (ERROR/WARNING/INFO) implicitly enable
  // the rule, so it fires even without a diagnostics: true entry.
  if (overrides.isNotEmpty) {
    final enabled = SaropaLintRule.enabledRules ?? <String>{};
    enabled.addAll(overrides.keys);
    SaropaLintRule.enabledRules = enabled;
  }
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
/// Rules marked `true` are added to [SaropaLintRule.enabledRules].
/// Rules marked `false` are removed from [enabledRules] and added to
/// [SaropaLintRule.disabledRules]. This merges with any severity-implied
/// enables and severity-disabled rules from the custom config file.
///
/// When no file or no diagnostics section is found, logs a diagnostic via
/// [PluginLogger] and returns without modifying [enabledRules] — preserving
/// any severity-implied enables. The log surfaces the "plugin loaded but
/// silent" failure mode so consumers can see why zero diagnostics flow.
///
/// [projectRoot] resolves `analysis_options.yaml` relative to the consumer's
/// project when provided. When null, falls back to [Directory.current] —
/// which fails silently in the analyzer-launched path (see
/// [loadNativePluginConfigFromProjectRoot]).
void _loadDiagnosticsConfig([String? projectRoot]) {
  final content = _readProjectFile('analysis_options.yaml', projectRoot);
  if (content == null) {
    PluginLogger.log(
      'analysis_options.yaml not found at '
      '${projectRoot ?? Directory.current.path} — saropa_lints will not '
      'enable any rules until config is reloaded from the project root.',
    );
    return;
  }

  final sectionMatch = RegExp(
    r'^\s+diagnostics:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) {
    PluginLogger.log(
      'analysis_options.yaml found at '
      '${projectRoot ?? Directory.current.path} but no '
      '`plugins > saropa_lints > diagnostics:` block present. '
      'Run `dart run saropa_lints:init` or use the extension to generate it.',
    );
    return;
  }

  final enabled = SaropaLintRule.enabledRules ?? <String>{};
  final disabled = SaropaLintRule.disabledRules ?? <String>{};
  final lines = content.substring(sectionMatch.end).split('\n');

  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    // diagnostics entries are indented 6+ spaces; stop at less indentation
    if (!line.startsWith('      ')) break;

    final match = RegExp(r'^\s+([\w_]+):\s*(true|false)').firstMatch(line);
    if (match == null) continue;

    final ruleName = match.group(1);
    if (ruleName == null || ruleName.isEmpty) continue;

    if (match.group(2) == 'true') {
      enabled.add(ruleName);
      disabled.remove(ruleName);
    } else {
      disabled.add(ruleName);
      enabled.remove(ruleName);
    }
  }

  SaropaLintRule.enabledRules = enabled.isEmpty ? null : enabled;
  SaropaLintRule.disabledRules = disabled.isEmpty ? null : disabled;
}

/// Rule codes last merged from `rule_packs.enabled` (subtract before re-merge).
Set<String>? _packContributedCodes;

/// Parses `rule_packs.enabled` under `plugins.saropa_lints` and merges rule
/// codes via [mergeRulePacksIntoEnabled] (respects [SaropaLintRule.disabledRules]).
///
/// Uses [Directory.current] for `analysis_options.yaml` and `pubspec.lock`.
void _loadRulePacksConfig() {
  _reloadRulePacksFromRoot(Directory.current.path);
}

/// Re-merges rule packs using [projectRoot] for config and lockfile (Phase 3).
///
/// Call when the real project root is known (e.g. first analyzed file). Removes
/// only rule codes contributed by the previous pack merge so tier/diagnostics
/// enables are preserved. If the analyzer already registered rules, newly added
/// pack codes may not run until the next analysis server restart when cwd
/// differed from [projectRoot] at plugin start.
void loadRulePacksConfigFromProjectRoot(String projectRoot) {
  if (projectRoot.isEmpty) return;
  _reloadRulePacksFromRoot(projectRoot);
}

void _reloadRulePacksFromRoot(String projectRoot) {
  final enabled = SaropaLintRule.enabledRules ?? <String>{};
  if (_packContributedCodes != null) {
    enabled.removeAll(_packContributedCodes!);
  }

  final content = _readProjectFile('analysis_options.yaml', projectRoot);
  if (content == null) {
    _packContributedCodes = {};
    SaropaLintRule.enabledRules = enabled.isEmpty ? null : enabled;
    return;
  }

  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final packIds = parseRulePacksEnabledList(normalized);
  final lockVersions = readResolvedPackageVersions(projectRoot);
  _packContributedCodes = mergeRulePacksIntoEnabled(
    enabled,
    SaropaLintRule.disabledRules,
    packIds,
    resolvedVersions: lockVersions,
  );
  SaropaLintRule.enabledRules = enabled.isEmpty ? null : enabled;
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
    PluginLogger.log(
      '_loadOutputConfig env read failed',
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
