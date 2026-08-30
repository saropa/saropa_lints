// ignore_for_file: depend_on_referenced_packages

/// Loads saropa_lints configuration for the native analyzer plugin.
///
/// **When:** Called once from [SaropaLintsPlugin.start] before [register].
/// **Where:** Project root = [Directory.current]; files: analysis_options.yaml,
/// analysis_options_custom.yaml. Env vars (e.g. SAROPA_LINTS_MAX) override where applicable.
///
/// Populates:
/// - [SaropaLintRule.enabledRules] (diagnostics `true` + severity-implied enables +
///   rule pack codes from `rule_packs.enabled`, excluding
///   [SaropaLintRule.disabledRules])
/// - [SaropaLintRule.severityOverrides] and [SaropaLintRule.disabledRules]
/// - [BaselineManager] (baseline path, enabled)
/// - [ProgressTracker] (max_issues, file-only output)
/// - [BannedUsageConfig] from custom yaml
library;

import 'dart:io' show Directory, File, Platform;

import 'package:analyzer/error/error.dart' show DiagnosticSeverity;

import '../banned_usage_config.dart';
import '../config/max_declarations_config.dart';
import '../baseline/baseline_config.dart';
import '../baseline/baseline_manager.dart';
import '../config/analysis_options_rule_packs.dart';
import '../config/pubspec_lock_resolver.dart';
import '../config/rule_packs.dart';
import '../config/memory_mode.dart' show MemoryMode, MemoryModeConfig;
// Two-lane split (in-process light lane vs scan-daemon lane).
import '../config/rule_lane.dart'
    show
        RuleLane,
        applyLaneToEnabledRuleSet,
        kLaneConfigKey,
        parseRuleLane,
        setActiveRuleLane;
import '../config/runtime_tier_cap.dart';
import '../report/diagnostic_statistics.dart';
import '../saropa_lint_rule.dart' show ProgressTracker, SaropaLintRule;
import 'plugin_logger.dart' show PluginLogLevel, PluginLogger;
import 'package:saropa_lints/src/string_slice_utils.dart';

/// Loads all plugin configuration from yaml and environment variables.
/// Order matters: severity overrides first, then diagnostics (enable/disable),
/// then **rule packs** (adds enabled rule codes; skips
/// [SaropaLintRule.disabledRules]),
/// then baseline, banned usage, and output (max_issues, file-only).
/// Safe to call multiple times — static fields are simply overwritten.
/// Never throws; failures in any step are caught and the rest still run.
///
/// Uses [Directory.current] to locate config files. This works for CLI
/// invocations where cwd == project root, but fails silently for the
/// analyzer-launched plugin where cwd is the analysis-server process's
/// working directory (often the user's home or wherever the IDE was
/// launched from). For that path, see [loadNativePluginConfigFromProjectRoot],
/// triggered lazily from `SaropaContext` once the real project root can be
/// derived from an analyzed file path.
/// True once the in-process analyzer plugin has started (i.e. the no-arg
/// [loadNativePluginConfig] ran from `Plugin.start`). Gates the in-process
/// essential default cap: only the real analysis-server plugin reduces its
/// own footprint by defaulting to essential. Tests and the `dart run
/// saropa_lints scan` CLI reach [_loadFromRoot] via
/// [loadNativePluginConfigFromProjectRoot] (or the lazy `SaropaContext`
/// reload) WITHOUT starting the plugin, so they must run full coverage — an
/// essential default there silently gated every non-essential rule and broke
/// the rule test harness. Left false in those paths.
bool _nativePluginStarted = false;

/// Marks that the real analysis-server plugin has started. Call from
/// Plugin.start() BEFORE the cwd check so the essential-tier default
/// applies on the lazy config reload even when the initial load is skipped
/// (non-project cwd).
void markNativePluginStarted() {
  _nativePluginStarted = true;
}

void loadNativePluginConfig() {
  // Also set by markNativePluginStarted() in Plugin.start() before the cwd
  // check, so the flag is armed even when the initial config load is skipped.
  _nativePluginStarted = true;
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

/// Substring of the sentinel the VS Code extension writes into
/// `analysis_options.yaml` when the user toggles "Lint integration" off
/// (it comments out the `plugins:` block and brackets it with this marker —
/// see `DISABLE_BEGIN_MARKER` in `extension/src/setup.ts`). Matched as a
/// substring so punctuation/arrow changes around it don't silently defeat
/// the kill switch.
const String kIntegrationOffSentinel =
    'saropa_lints integration turned OFF by the VS Code extension';

/// Shared implementation for config loading from an optional [projectRoot].
/// When null, falls back to [Directory.current].
void _loadFromRoot(String? projectRoot) {
  try {
    // Hard kill switch — in-server plugin only. If the consumer's
    // analysis_options.yaml carries the extension's OFF sentinel, the user
    // explicitly disabled lint integration: enable ZERO rules, no matter
    // what fallback (tier floor, packs, severity-implied enables) would
    // otherwise populate the set. Field evidence (2026-08-13, contacts
    // project): with the plugins block commented out, a plugin session
    // still loaded 1034 rules from fallbacks and held multi-GB of resolved
    // AST state. Scoped to [_nativePluginStarted] so the scan CLI and the
    // rule test harness — which run full coverage deliberately, including
    // on projects whose integration is toggled off — are unaffected.
    // Read the main file once — used for the OFF sentinel, diagnostics, and
    // as a deprecation fallback for keys migrated to the custom file.
    final mainOptions = _readProjectFile('analysis_options.yaml', projectRoot);

    if (_nativePluginStarted) {
      if (mainOptions != null &&
          mainOptions.contains(kIntegrationOffSentinel)) {
        SaropaLintRule.enabledRules = null;
        SaropaLintRule.disabledRules = null;
        SaropaLintRule.severityOverrides = null;
        PluginLogger.log(
          'Lint integration is turned OFF (sentinel found in '
          'analysis_options.yaml) — 0 rules enabled. Toggle "Lint '
          'integration" On in the VS Code extension to restore.',
        );

        return;
      }
    }

    final content = _readProjectFile(
      'analysis_options_custom.yaml',
      projectRoot,
    );
    _loadSeverityOverrides(content);
    _loadDiagnosticsConfig(mainOptions, projectRoot);
    if (projectRoot != null) {
      loadRulePacksConfigFromProjectRoot(projectRoot);
    } else {
      _loadRulePacksConfig();
    }
    _loadBaselineConfig(content);
    loadBannedUsageConfig(content);
    loadMaxDeclarationsConfig(content);
    _loadOutputConfig(content);
    // log_level, lane, and memory_mode live in the custom file (top-level
    // keys) to avoid unsupported_option warnings from the SDK's plugin-block
    // validator. Falls back to the old `plugins > saropa_lints:` location
    // with a deprecation warning for projects that haven't migrated yet.
    _loadLogLevel(content, mainOptions);
    _loadMemoryMode(content, mainOptions);
    _loadDiagnosticStatisticsConfig(content, projectRoot);

    // Tier cap. The in-process essential DEFAULT applies only when BOTH:
    //
    //  1. The real analysis-server plugin started ([_nativePluginStarted]).
    //     Tests and the scan CLI reach here without starting the plugin and
    //     must run full coverage — an essential default in those paths silently
    //     gated every non-essential rule (broke the resolved-rule test harness,
    //     since it triggers this lazy reload from `example/`).
    //
    //  2. The consumer enabled NO rules explicitly (diagnostics `true` +
    //     severity-implied + rule packs all empty). When the consumer opted
    //     rules in, honor them EXACTLY — the memory default must never silently
    //     strip an enabled rule (e.g. `diagnostics: avoid_unguarded_debug: true`
    //     above essential). Only an explicit SAROPA_TIER / yaml tier caps an
    //     explicitly-enabled set. (User decision 2026-06-28: respect explicit
    //     enables — the RSS safety valve, not rule-count capping, is the real
    //     analysis-server protection.)
    //
    // Otherwise use the plain reload, which caps only when an explicit tier is
    // configured and never defaults.
    final hasExplicitEnables = SaropaLintRule.enabledRules?.isNotEmpty ?? false;
    if (_nativePluginStarted && !hasExplicitEnables) {
      reloadRuntimeTierCapForPlugin(projectRoot);
    } else {
      reloadRuntimeTierCapFromProject(projectRoot);
    }
    RuntimeTierCap.applyCapToEnabledRuleSet();

    // Two-lane split. Applied AFTER the tier cap so the lane narrows whatever
    // the cap left, never the other way round (the cap is the consumer's
    // strictness choice; the lane is a delivery-mechanism choice, and the
    // rules it removes here are not lost — the scan daemon reports them on
    // save). In-process only: the scan CLI and the rule test harness must keep
    // running full coverage, and they reach this loader without starting the
    // plugin, which is exactly what [_nativePluginStarted] distinguishes.
    // Lane lives in the custom file to avoid SDK unsupported_option warnings.
    if (_nativePluginStarted) {
      _loadRuleLane(content, mainOptions, projectRoot);
    }

    // Success telemetry — visible in reports/.saropa_lints/plugin.log once
    // the project root is set. This is the primary signal users can check
    // to confirm the fix landed and their config was actually read.
    final enabledCount = SaropaLintRule.enabledRules?.length ?? 0;
    PluginLogger.log(
      'Config loaded from ${projectRoot ?? Directory.current.path} — '
      'enabledRules: $enabledCount',
    );
  } on Object catch (e, st) {
    PluginLogger.error(
      'loadNativePluginConfig failed',
      error: e,
      stackTrace: st,
    );
    // Defensive: ensure plugin can still register with defaults
  }
}

/// Reads `lane:` as a top-level key in `analysis_options_custom.yaml` and
/// narrows [SaropaLintRule.enabledRules] to that lane.
///
/// ```yaml
/// # analysis_options_custom.yaml
/// lane: light   # default when the key is absent; or: full
/// ```
///
/// Moved from `analysis_options.yaml` (under `plugins > saropa_lints:`) to
/// avoid `unsupported_option` warnings from the Dart SDK's plugin-block
/// validator, which hardcodes the allowed key set.
///
/// `light` runs only rules that are severe, cheap, and free of type
/// resolution in the analysis server; everything else is delivered on save by
/// the scan daemon. See `lib/src/config/rule_lane.dart` for why that
/// particular set, and `plans/PLAN_two_lane_daemon_architecture.md` for the
/// architecture.
///
/// A null/empty [SaropaLintRule.enabledRules] is left alone rather than being
/// populated with the lane: null means "no explicit enables", and the
/// downstream per-node gate ([ruleAllowedByLane], consulted from
/// `SaropaContext._wrapCallback`) already enforces the lane for that path.
/// Writing a set here would turn "nothing configured" into "these 200 rules
/// are explicitly enabled", changing tier-cap and reporting semantics.
void _loadRuleLane(
  String? customContent,
  String? mainOptions,
  String? projectRoot,
) {
  // Reads `lane:` from the custom file, falling back to the old plugin block
  // with a deprecation warning via [_readWithDeprecationFallback].
  final raw = _readWithDeprecationFallback(
    customContent,
    mainOptions,
    kLaneConfigKey,
  );
  final lane = parseRuleLane(raw);
  setActiveRuleLane(lane);
  if (lane == RuleLane.full) return;

  final enabled = SaropaLintRule.enabledRules;
  if (enabled == null || enabled.isEmpty) return;

  final filtered = applyLaneToEnabledRuleSet(enabled);
  SaropaLintRule.enabledRules = filtered.isEmpty ? null : filtered;
}

/// Parse diagnostic statistics config (threshold gates + baseline diff).
///
/// Supported shape in `analysis_options_custom.yaml`:
/// ```yaml
/// diagnostic_statistics:
///   thresholds:
///     avoid_hardcoded_credentials:
///       fail: 0
///     avoid_print:
///       warn: 50
///   baseline:
///     file: reports/.saropa_lints/diagnostic_baseline.json
/// ```
void _loadDiagnosticStatisticsConfig(String? content, String? projectRoot) {
  DiagnosticStatisticsConfig.reset();
  if (content == null) return;

  final sectionMatch = RegExp(
    r'^diagnostic_statistics:\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (sectionMatch == null) return;

  final lines = content.afterIndex(sectionMatch.end).split('\n');
  final warn = <String, int>{};
  final fail = <String, int>{};
  String? baselineFile;

  var inThresholds = false;
  var inBaseline = false;
  String? currentRule;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    if (!line.startsWith('  ')) break;

    if (RegExp(r'^\s{2}thresholds:\s*$').hasMatch(line)) {
      inThresholds = true;
      inBaseline = false;
      currentRule = null;
      continue;
    }

    if (RegExp(r'^\s{2}baseline:\s*$').hasMatch(line)) {
      inThresholds = false;
      inBaseline = true;
      currentRule = null;
      continue;
    }

    if (inThresholds) {
      final ruleMatch = RegExp(r'^\s{4}([\w_.-]+):\s*$').firstMatch(line);
      if (ruleMatch != null) {
        currentRule = ruleMatch.group(1);
        continue;
      }

      final thresholdMatch = RegExp(
        r'^\s{6}(warn|fail):\s*(\d+)\s*$',
      ).firstMatch(line);
      final kind = thresholdMatch?.group(1);
      final valueRaw = thresholdMatch?.group(2);
      if (thresholdMatch == null ||
          kind == null ||
          valueRaw == null ||
          currentRule == null) {
        continue;
      }

      final value = int.tryParse(valueRaw);
      if (value == null) continue;
      if (kind == 'warn') {
        warn[currentRule] = value;
      } else {
        fail[currentRule] = value;
      }
      continue;
    }

    if (inBaseline) {
      final baselineMatch = RegExp(
        r'^\s{4}file:\s*"?([^"]+)"?\s*$',
      ).firstMatch(line);
      final filePath = baselineMatch?.group(1);
      if (filePath != null && filePath.isNotEmpty) {
        baselineFile = filePath;
      }
    }
  }

  DiagnosticStatisticsConfig.setThresholds(warn: warn, fail: fail);
  if (baselineFile != null) {
    // Keep relative paths as-is so downstream consumers can resolve against
    // the project root consistently regardless of where loading occurred.
    DiagnosticStatisticsConfig.setBaselinePath(baselineFile);
  } else if (projectRoot != null) {
    DiagnosticStatisticsConfig.setBaselinePath(null);
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
  } on Object catch (e, st) {
    PluginLogger.error('_readProjectFile failed', error: e, stackTrace: st);
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
  } on Object catch (e, st) {
    PluginLogger.error(
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
///   avoid_unguarded_debug: ERROR
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

  final lines = content.afterIndex(sectionMatch.end).split('\n');
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
void _loadDiagnosticsConfig(String? mainContent, [String? projectRoot]) {
  // Accept pre-read main file content to avoid re-reading the file.
  if (mainContent == null) {
    PluginLogger.warning(
      'analysis_options.yaml not found at '
      '${projectRoot ?? Directory.current.path} — saropa_lints will not '
      'enable any rules until config is reloaded from the project root.',
    );

    return;
  }
  final sectionMatch = RegExp(
    r'^\s+diagnostics:\s*$',
    multiLine: true,
  ).firstMatch(mainContent);
  if (sectionMatch == null) {
    PluginLogger.warning(
      'analysis_options.yaml found at '
      '${projectRoot ?? Directory.current.path} but no '
      '`plugins > saropa_lints > diagnostics:` block present. '
      'Run `dart run saropa_lints:init` or use the extension to generate it.',
    );

    return;
  }

  final enabled = SaropaLintRule.enabledRules ?? <String>{};
  final disabled = SaropaLintRule.disabledRules ?? <String>{};
  final lines = mainContent.afterIndex(sectionMatch.end).split('\n');

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

/// Parses `log_level:` as a top-level key in `analysis_options_custom.yaml`.
/// Valid values: off, error, warning, info, debug.
/// Unrecognized values leave [PluginLogger.minLevel] at its default (info).
///
/// Moved from `analysis_options.yaml` (under `plugins > saropa_lints:`) to
/// avoid `unsupported_option` warnings from the Dart SDK's plugin-block
/// validator, which hardcodes the allowed key set. Falls back to the old
/// plugin-block location in [mainOptions] with a deprecation warning via
/// [_readWithDeprecationFallback].
void _loadLogLevel(String? content, String? mainOptions) {
  final raw = _readWithDeprecationFallback(content, mainOptions, 'log_level');
  if (raw == null) return;
  final parsed = PluginLogLevel.tryParse(raw);
  if (parsed != null) {
    PluginLogger.minLevel = parsed;
  } else {
    PluginLogger.warning(
      'Unrecognized log_level "$raw" in analysis_options_custom.yaml — '
      'valid values: off, error, warning, info, debug. '
      'Keeping current level (${PluginLogger.minLevel.name}).',
    );
  }
}

/// Parses `memory_mode:` as a top-level key in
/// `analysis_options_custom.yaml` or the `SAROPA_MEMORY_MODE` env var.
/// Valid values: `balanced` (default), `full`. Env var takes precedence.
///
/// Lives in the custom file (not under `plugins > saropa_lints:`) to avoid
/// `unsupported_option` warnings from the SDK's plugin-block validator.
/// Falls back to the old plugin-block location in [mainOptions] with a
/// deprecation warning so projects that haven't migrated yet still work.
void _loadMemoryMode(String? content, String? mainOptions) {
  try {
    // Env var takes precedence over the yaml key.
    final envValue = Platform.environment['SAROPA_MEMORY_MODE'];
    if (envValue != null) {
      final parsed = _parseMemoryMode(envValue);
      if (parsed != null) {
        MemoryModeConfig.mode = parsed;
      } else {
        PluginLogger.warning(
          'Unrecognized SAROPA_MEMORY_MODE "$envValue" — '
          'valid values: balanced, full. '
          'Keeping current mode (${MemoryModeConfig.mode.name}).',
        );
      }
      return;
    }
  } on Object {
    // Platform.environment may throw on some platforms
  }

  // Reads `memory_mode:` from the custom file, falling back to the old plugin
  // block with a deprecation warning via [_readWithDeprecationFallback].
  final raw = _readWithDeprecationFallback(content, mainOptions, 'memory_mode');
  if (raw == null) return;
  final parsed = _parseMemoryMode(raw);
  if (parsed != null) {
    MemoryModeConfig.mode = parsed;
  } else {
    PluginLogger.warning(
      'Unrecognized memory_mode "$raw" in analysis_options_custom.yaml — '
      'valid values: balanced, full. '
      'Keeping current mode (${MemoryModeConfig.mode.name}).',
    );
  }
}

/// Extracts the value of a top-level YAML key from [content].
///
/// Matches `key: value` at column 0, excluding inline comments (`# ...`).
/// Strips surrounding YAML quotes (`"` or `'`) and lower-cases the result to
/// mirror the TS `parseLaneFromCustomConfig` in `laneConfig.ts`. Returns null
/// if the key is absent, commented out, or has no value.
///
/// Shared by `_loadLogLevel`, `_loadRuleLane`, and `_loadMemoryMode` so all
/// top-level custom-config keys parse consistently (avoids the drift that
/// happens when each copy re-implements its own regex).
String? _parseTopLevelScalar(String? content, String key) {
  if (content == null) return null;
  final match = RegExp(
    '^$key:\\s*([^\\s#]+)',
    multiLine: true,
  ).firstMatch(content);
  final raw = match?.group(1);
  if (raw == null) return null;
  // Strip surrounding YAML quotes (single or double) — `lane: "light"` and
  // `lane: light` must both parse as `light`.
  return raw.replaceAll(RegExp(r"""^['"]|['"]$"""), '').toLowerCase();
}

/// Reads a top-level key from the custom file, falling back to the old
/// `plugins > saropa_lints:` block in the main file with a deprecation
/// warning. Shared by `_loadLogLevel`, `_loadRuleLane`, and `_loadMemoryMode`
/// so the fallback-and-warn pattern is defined once.
String? _readWithDeprecationFallback(
  String? customContent,
  String? mainOptions,
  String key,
) {
  final value = _parseTopLevelScalar(customContent, key);
  if (value != null) return value;
  if (mainOptions == null) return null;

  // Check the old location under `plugins > saropa_lints:`.
  final legacy = parseScalarFromPluginBlock(mainOptions, {key});
  if (legacy != null) {
    PluginLogger.warning(
      '$key found under plugins > saropa_lints: in '
      'analysis_options.yaml — move it to analysis_options_custom.yaml '
      '(top-level key) to avoid unsupported_option warnings.',
    );
  }
  return legacy;
}

MemoryMode? _parseMemoryMode(String? raw) {
  final normalized = raw?.toLowerCase().trim();
  if (normalized == 'full') return MemoryMode.full;
  if (normalized == 'balanced') return MemoryMode.balanced;
  return null;
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
  // Take a mutable copy: callers (e.g. ScanRunner with tier=...) may assign a
  // `const Set<String>` from tiers.dart to SaropaLintRule.enabledRules, and
  // removeAll/add below must succeed regardless of the source's mutability.
  final enabled = <String>{...?SaropaLintRule.enabledRules};
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
  // pubspec drives the SDK-version carve-out: a flutter_sdk_/dart_sdk_ migration
  // rule is stripped from the floor only when the pinned SDK lower bound proves
  // the project is not on that version. null pubspec → no SDK strip (floor kept).
  final pubspec = _readProjectFile('pubspec.yaml', projectRoot);
  _packContributedCodes = mergeRulePacksIntoEnabled(
    enabled,
    SaropaLintRule.disabledRules,
    packIds,
    resolvedVersions: lockVersions,
    pubspecYamlContent: pubspec,
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
  final lines = content.afterIndex(offset).split('\n');
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
  } on Object catch (e, st) {
    PluginLogger.error(
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
