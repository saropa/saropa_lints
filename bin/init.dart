#!/usr/bin/env dart
// ignore_for_file: avoid_print

library;

/// CLI tool to generate analysis_options.yaml with explicit rule configuration.
///
/// ## Purpose
///
/// The `custom_lint` plugin has a known limitation where YAML configuration
/// (like `tier: recommended`) is not reliably passed to plugins. This tool
/// bypasses that limitation by generating explicit `- rule_name: true/false`
/// entries for ALL saropa_lints rules.
///
/// ## Usage
///
/// ```bash
/// dart run saropa_lints:init [options]
/// ```
///
/// ## Options
///
/// | Option | Description | Default |
/// |--------|-------------|---------|
/// | `-t, --tier <tier>` | Tier level (1-5 or name) | comprehensive |
/// | `-o, --output <file>` | Output file path | analysis_options.yaml |
/// | `--stylistic` | Include opinionated formatting rules | false |
/// | `--reset` | Discard user customizations | false |
/// | `--dry-run` | Preview output without writing | false |
/// | `-h, --help` | Show help message | - |
///
/// ## Tiers
///
/// 1. **essential** - Critical rules (~340): crashes, security, memory leaks
/// 2. **recommended** - Essential + accessibility, performance (~850)
/// 3. **professional** - Recommended + architecture, testing (~1590)
/// 4. **comprehensive** - Professional + thorough coverage (~1640)
/// 5. **pedantic** - All rules enabled (~1650)
///
/// ## Preservation Behavior
///
/// When regenerating an existing file, this tool preserves:
/// - All non-custom_lint sections (analyzer, linter, formatter, etc.)
/// - User customizations in custom_lint.rules (unless --reset is used)
///
/// User customizations appear first in the generated output, making it easy
/// to see which rules have been manually configured.
///
/// ## Exit Codes
///
/// - 0: Success
/// - 1: Invalid tier specified
/// - 2: File write error
///
/// ## Examples
///
/// ```bash
/// # Generate config for comprehensive tier (default)
/// dart run saropa_lints:init
///
/// # Start with essential tier for legacy projects
/// dart run saropa_lints:init --tier essential
///
/// # Include stylistic rules
/// dart run saropa_lints:init --tier professional --stylistic
///
/// # Preview without writing
/// dart run saropa_lints:init --dry-run
///
/// # Reset to tier defaults, discarding customizations
/// dart run saropa_lints:init --tier recommended --reset
/// ```
///
/// ## See Also
///
/// - [README.md](../README.md) for tier philosophy and adoption strategy
/// - [PERFORMANCE.md](../PERFORMANCE.md) for performance considerations
/// - [CONTRIBUTING.md](../CONTRIBUTING.md) for adding new rules

import 'dart:ffi';
import 'dart:io';

import 'package:custom_lint_builder/custom_lint_builder.dart' show LintRule;
import 'package:saropa_lints/saropa_lints.dart'
    show RuleTier, SaropaLintRule, allSaropaRules;
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Get saropa_lints rootUri from .dart_tool/package_config.json.
/// Returns null if not found. Used by both version and source detection.
String? _getSaropaLintsRootUri() {
  try {
    final packageConfigFile = File('.dart_tool/package_config.json');
    if (!packageConfigFile.existsSync()) return null;

    final content = packageConfigFile.readAsStringSync();
    final match = RegExp(
      r'"name":\s*"saropa_lints"[^}]*"rootUri":\s*"([^"]+)"',
    ).firstMatch(content);

    return match?.group(1);
  } catch (_) {}
  return null;
}

/// Convert rootUri to absolute file path.
String? _rootUriToPath(String rootUri) {
  if (rootUri.startsWith('file://')) {
    return Uri.parse(rootUri).toFilePath();
  } else if (rootUri.startsWith('../')) {
    final dartToolDir = Directory('.dart_tool').absolute.path;
    return Directory('$dartToolDir/$rootUri').absolute.path;
  }
  return null;
}

/// Get package version by reading pubspec.yaml from package location.
String _getPackageVersion() {
  try {
    final rootUri = _getSaropaLintsRootUri();
    if (rootUri == null) return 'unknown';

    final packageDir = _rootUriToPath(rootUri);
    if (packageDir == null) return 'unknown';

    final pubspecFile = File('$packageDir/pubspec.yaml');
    if (!pubspecFile.existsSync()) return 'unknown';

    final content = pubspecFile.readAsStringSync();
    final match =
        RegExp(r'^version:\s*(.+)$', multiLine: true).firstMatch(content);
    return match?.group(1)?.trim() ?? 'unknown';
  } catch (_) {}
  return 'unknown';
}

/// Detect where the saropa_lints package is loaded from.
String _getPackageSource() {
  final rootUri = _getSaropaLintsRootUri();
  if (rootUri == null) return 'unknown';

  if (rootUri.startsWith('file://') || rootUri.startsWith('../')) {
    return 'local: $rootUri';
  } else if (rootUri.contains('.pub-cache')) {
    return 'pub.dev';
  }
  return rootUri;
}

// ---------------------------------------------------------------------------
// Log buffer for detailed report file
// ---------------------------------------------------------------------------

/// Buffer to collect all log output for the report file.
final StringBuffer _logBuffer = StringBuffer();

/// Timestamp for log file naming.
String? _logTimestamp;

/// Strip ANSI escape codes from text for plain text log file.
String _stripAnsi(String text) {
  return text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
}

/// Write the log buffer to a timestamped report file.
void _writeLogFile() {
  if (_logTimestamp == null) return;

  try {
    final reportsDir = Directory('reports');
    if (!reportsDir.existsSync()) {
      reportsDir.createSync(recursive: true);
    }

    final logPath = 'reports/${_logTimestamp}_saropa_lints_init.log';
    final logContent = _stripAnsi(_logBuffer.toString());
    File(logPath).writeAsStringSync(logContent);

    print('${_Colors.dim}Log written to: $logPath${_Colors.reset}');
  } on Exception catch (e) {
    print(
        '${_Colors.yellow}Warning: Could not write log file: $e${_Colors.reset}');
  }
}

// ---------------------------------------------------------------------------
// Cross-platform ANSI color support
// ---------------------------------------------------------------------------

/// Enable ANSI virtual terminal processing on Windows 10+.
///
/// Windows supports ANSI escape codes but requires enabling
/// ENABLE_VIRTUAL_TERMINAL_PROCESSING on the console output handle.
/// Dart's [stdout.supportsAnsiEscapes] only checks the flag; this sets it.
void _tryEnableAnsiWindows() {
  if (!Platform.isWindows) return;
  try {
    final k = DynamicLibrary.open('kernel32.dll');
    final getStdHandle =
        k.lookupFunction<IntPtr Function(Int32), int Function(int)>(
            'GetStdHandle');
    final getMode = k.lookupFunction<Int32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)>('GetConsoleMode');
    final setMode = k.lookupFunction<Int32 Function(IntPtr, Uint32),
        int Function(int, int)>('SetConsoleMode');
    final getHeap =
        k.lookupFunction<IntPtr Function(), int Function()>('GetProcessHeap');
    final alloc = k.lookupFunction<
        Pointer<Void> Function(IntPtr, Uint32, IntPtr),
        Pointer<Void> Function(int, int, int)>('HeapAlloc');
    final free = k.lookupFunction<Int32 Function(IntPtr, Uint32, Pointer<Void>),
        int Function(int, int, Pointer<Void>)>('HeapFree');

    final handle = getStdHandle(-11); // STD_OUTPUT_HANDLE
    final heap = getHeap();
    final ptr = alloc(heap, 0x08, 4); // HEAP_ZERO_MEMORY, 4 bytes
    if (ptr.address == 0) return;

    final mode = ptr.cast<Uint32>();
    if (getMode(handle, mode) != 0) {
      setMode(
          handle, mode.value | 0x0004); // ENABLE_VIRTUAL_TERMINAL_PROCESSING
    }
    free(heap, 0, ptr);
  } catch (_) {
    // VTP unavailable - colors degrade gracefully to plain text
  }
}

/// Cached color support result.
bool? _colorSupportCache;

/// Detects if the terminal supports ANSI colors.
bool get _supportsColor {
  return _colorSupportCache ??= _detectColorSupport();
}

/// Checks terminal capabilities for ANSI color support.
bool _detectColorSupport() {
  // Standard NO_COLOR / FORCE_COLOR environment variables
  if (Platform.environment.containsKey('NO_COLOR')) return false;
  if (Platform.environment.containsKey('FORCE_COLOR')) return true;

  // Not a terminal (piped, redirected)
  if (!stdout.hasTerminal) return false;

  // Dart's built-in check (reliable after VTP is enabled on Windows)
  if (stdout.supportsAnsiEscapes) return true;

  // Windows: detect terminals known to support ANSI
  if (Platform.isWindows) {
    final env = Platform.environment;
    return env.containsKey('WT_SESSION') || // Windows Terminal
        env['ConEmuANSI'] == 'ON' || // ConEmu
        env['TERM_PROGRAM'] == 'vscode' || // VS Code terminal
        env.containsKey('ANSICON') || // ANSICON
        env['TERM'] == 'xterm'; // xterm-compatible
  }

  // Unix-like: most terminals support colors
  return true;
}

/// ANSI color codes (cross-platform safe).
class _Colors {
  static String get reset => _supportsColor ? '\x1B[0m' : '';
  static String get bold => _supportsColor ? '\x1B[1m' : '';
  static String get dim => _supportsColor ? '\x1B[2m' : '';

  // Foreground colors
  static String get red => _supportsColor ? '\x1B[31m' : '';
  static String get green => _supportsColor ? '\x1B[32m' : '';
  static String get yellow => _supportsColor ? '\x1B[33m' : '';
  static String get blue => _supportsColor ? '\x1B[34m' : '';
  static String get magenta => _supportsColor ? '\x1B[35m' : '';
  static String get cyan => _supportsColor ? '\x1B[36m' : '';

  // Bright variants
  static String get brightRed => _supportsColor ? '\x1B[91m' : '';
  static String get brightCyan => _supportsColor ? '\x1B[96m' : '';
}

/// Color helpers for consistent styling.
String _success(String text) => '${_Colors.green}$text${_Colors.reset}';
String _error(String text) => '${_Colors.red}$text${_Colors.reset}';
String _tierColor(String tier) {
  switch (tier) {
    case 'essential':
      return '${_Colors.brightRed}$tier${_Colors.reset}';
    case 'recommended':
      return '${_Colors.yellow}$tier${_Colors.reset}';
    case 'professional':
      return '${_Colors.blue}$tier${_Colors.reset}';
    case 'comprehensive':
      return '${_Colors.magenta}$tier${_Colors.reset}';
    case 'pedantic':
      return '${_Colors.brightCyan}$tier${_Colors.reset}';
    case 'stylistic':
      return '${_Colors.dim}$tier${_Colors.reset}';
    default:
      return tier;
  }
}

// ---------------------------------------------------------------------------
// Rule metadata cache (problem messages, severities)
// ---------------------------------------------------------------------------

/// Cache for rule metadata (built once from allSaropaRules).
Map<String, _RuleMetadata>? _ruleMetadataCache;

/// Metadata for a single rule.
class _RuleMetadata {
  const _RuleMetadata({
    required this.name,
    required this.problemMessage,
    required this.correctionMessage,
    required this.severity,
    required this.tier,
  });

  final String name;
  final String problemMessage;
  final String correctionMessage;
  final String severity; // 'ERROR', 'WARNING', 'INFO'
  final RuleTier tier;
}

/// Builds and returns rule metadata from rule classes.
Map<String, _RuleMetadata> _getRuleMetadata() {
  if (_ruleMetadataCache != null) return _ruleMetadataCache!;

  _ruleMetadataCache = <String, _RuleMetadata>{};
  for (final LintRule rule in allSaropaRules) {
    if (rule is SaropaLintRule) {
      final String ruleName = rule.code.name;
      final String message = rule.code.problemMessage;
      final String correction = rule.code.correctionMessage ?? '';

      // Extract severity from LintCode
      final severity = rule.code.errorSeverity.name.toUpperCase();

      // Get tier from tiers.dart (single source of truth)
      final RuleTier tier = _getTierFromSets(ruleName);

      _ruleMetadataCache![ruleName] = _RuleMetadata(
        name: ruleName,
        problemMessage: message,
        correctionMessage: correction,
        severity: severity,
        tier: tier,
      );
    }
  }
  return _ruleMetadataCache!;
}

/// Gets the problem message for a rule (for YAML comment).
String _getProblemMessage(String ruleName) {
  final metadata = _getRuleMetadata()[ruleName];
  if (metadata == null) return '';

  return _stripRulePrefix(metadata.problemMessage);
}

/// Gets a combined description for a rule (problem + correction).
///
/// Used in the stylistic section of analysis_options_custom.yaml where
/// users need enough context to decide whether to enable each rule.
/// Falls back to just problemMessage if correctionMessage is empty or
/// redundant.
String _getStylisticDescription(String ruleName) {
  final metadata = _getRuleMetadata()[ruleName];
  if (metadata == null) return '';

  final problem = _stripRulePrefix(metadata.problemMessage);
  final correction = _stripRulePrefix(metadata.correctionMessage);

  if (correction.isEmpty) return problem;

  // If correction just restates the problem, skip it
  if (problem.contains(correction) || correction.contains(problem)) {
    // Return whichever is longer (more context)
    return problem.length >= correction.length ? problem : correction;
  }

  return '$problem $correction';
}

/// Remove rule name prefix if present (e.g., "`rule_name` ...").
String _stripRulePrefix(String msg) {
  final prefixMatch = RegExp(r'^\[[\w_]+\]\s*').firstMatch(msg);
  if (prefixMatch != null) {
    return msg.substring(prefixMatch.end);
  }
  return msg;
}

/// Gets the severity for a rule.
String _getRuleSeverity(String ruleName) {
  return _getRuleMetadata()[ruleName]?.severity ?? 'INFO';
}

/// Gets the tier for a rule.
RuleTier _getRuleTierFromMetadata(String ruleName) {
  return _getRuleMetadata()[ruleName]?.tier ?? RuleTier.professional;
}

// ---------------------------------------------------------------------------
// Regex patterns (defined once, used in multiple places)
// ---------------------------------------------------------------------------

/// Matches the `custom_lint:` section header in YAML.
final RegExp _customLintSectionPattern =
    RegExp(r'^custom_lint:\s*$', multiLine: true);

/// Matches any top-level YAML key (for finding section boundaries).
final RegExp _topLevelKeyPattern = RegExp(r'^\w+:', multiLine: true);

/// Matches rule entries like `- rule_name: true` or `- rule_name: false`.
final RegExp _ruleEntryPattern =
    RegExp(r'^\s+-\s+(\w+):\s*(true|false)', multiLine: true);

/// All available tiers in order of strictness.
const List<String> tierOrder = <String>[
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'pedantic',
];

/// Map tier names to numeric IDs for user convenience.
const Map<String, int> tierIds = <String, int>{
  'essential': 1,
  'recommended': 2,
  'professional': 3,
  'comprehensive': 4,
  'pedantic': 5,
};

/// Tier descriptions for display.
const Map<String, String> tierDescriptions = <String, String>{
  'essential':
      'Critical rules preventing crashes, security holes, memory leaks',
  'recommended': 'Essential + accessibility, performance patterns',
  'professional': 'Recommended + architecture, testing, documentation',
  'comprehensive': 'Professional + thorough coverage (recommended)',
  'pedantic': 'All rules enabled (may have conflicts)',
};

/// Stylistic rule categories, mirroring the organization in tiers.dart.
/// Used to generate the STYLISTIC RULES section in analysis_options_custom.yaml.
const Map<String, List<String>> _stylisticRuleCategories =
    <String, List<String>>{
  'Debug/Test utility': <String>[
    'prefer_fail_test_case',
  ],
  'Ordering & Sorting': <String>[
    'prefer_member_ordering',
    'prefer_arguments_ordering',
    'prefer_sorted_members',
    'prefer_sorted_parameters',
    'prefer_sorted_pattern_fields',
    'prefer_sorted_record_fields',
  ],
  'Naming conventions': <String>[
    'prefer_boolean_prefixes',
    'prefer_no_getter_prefix',
    'prefer_kebab_tag_name',
    'prefer_capitalized_comment_start',
    'prefer_descriptive_bool_names',
    'prefer_snake_case_files',
    'prefer_camel_case_method_names',
    'prefer_exception_suffix',
    'prefer_error_suffix',
  ],
  'Error handling style': <String>[
    'prefer_catch_over_on',
  ],
  'Code style preferences': <String>[
    'prefer_no_continue_statement',
    'prefer_single_exit_point',
    'prefer_wildcard_for_unused_param',
    'prefer_rethrow_over_throw_e',
  ],
  'Function & Parameter style': <String>[
    'prefer_arrow_functions',
    'prefer_all_named_parameters',
    'prefer_inline_callbacks',
    'avoid_parameter_reassignment',
  ],
  'Widget style': <String>[
    'avoid_shrink_wrap_in_scroll',
    'prefer_one_widget_per_file',
    'prefer_widget_methods_over_classes',
    'prefer_borderradius_circular',
    'avoid_small_text',
  ],
  'Class & Record style': <String>[
    'prefer_class_over_record_return',
    'prefer_private_underscore_prefix',
    'prefer_explicit_this',
  ],
  'Formatting': <String>[
    'prefer_trailing_comma_always',
  ],
  'Comments & Documentation': <String>[
    'prefer_todo_format',
    'prefer_fixme_format',
    'prefer_sentence_case_comments',
    'prefer_period_after_doc',
    'prefer_doc_comments_over_regular',
    'prefer_no_commented_out_code',
  ],
  'Testing style': <String>[
    'prefer_expect_over_assert_in_tests',
  ],
  'Type argument style (conflicting - choose one)': <String>[
    'prefer_inferred_type_arguments',
    'prefer_explicit_type_arguments',
  ],
  'Import style (conflicting - choose one)': <String>[
    'prefer_absolute_imports',
    'prefer_flat_imports',
    'prefer_grouped_imports',
    'prefer_named_imports',
    'prefer_relative_imports',
  ],
  'Quote style (conflicting - choose one)': <String>[
    'prefer_double_quotes',
    'prefer_single_quotes',
  ],
  'Apostrophe style (conflicting - choose one)': <String>[
    'prefer_doc_curly_apostrophe',
    'prefer_doc_straight_apostrophe',
    'prefer_straight_apostrophe',
  ],
  'Member ordering (conflicting - choose one)': <String>[
    'prefer_static_members_first',
    'prefer_instance_members_first',
    'prefer_public_members_first',
    'prefer_private_members_first',
  ],
  'Opinionated prefer_* rules': <String>[
    'prefer_addall_over_spread',
    'prefer_async_only_when_awaiting',
    'prefer_await_over_then',
    'prefer_blank_line_after_declarations',
    'prefer_blank_lines_between_members',
    'prefer_cascade_over_chained',
    'prefer_chained_over_cascade',
    'prefer_clip_r_superellipse',
    'prefer_clip_r_superellipse_clipper',
    'prefer_collection_if_over_ternary',
    'prefer_compact_class_members',
    'prefer_compact_declarations',
    'prefer_concatenation_over_interpolation',
    'prefer_concise_variable_names',
    'prefer_constructor_assertion',
    'prefer_constructor_body_assignment',
    'prefer_container_over_sizedbox',
    'prefer_curly_apostrophe',
    'prefer_default_enum_case',
    'prefer_descriptive_bool_names_strict',
    'prefer_descriptive_variable_names',
    'prefer_dot_shorthand',
    'prefer_dynamic_over_object',
    'prefer_edgeinsets_only',
    'prefer_edgeinsets_symmetric',
    'prefer_exhaustive_enums',
    'prefer_expanded_over_flexible',
    'prefer_explicit_boolean_comparison',
    'prefer_explicit_colors',
    'prefer_explicit_null_assignment',
    'prefer_explicit_types',
    'prefer_factory_for_validation',
    'prefer_fake_over_mock',
    'prefer_fields_before_methods',
    'prefer_flexible_over_expanded',
    'prefer_future_void_function_over_async_callback',
    'prefer_generic_exception',
    'prefer_given_when_then_comments',
    'prefer_grouped_by_purpose',
    'prefer_grouped_expectations',
    'prefer_guard_clauses',
    'prefer_if_null_over_ternary',
    'prefer_implicit_boolean_comparison',
    'prefer_initializing_formals',
    'prefer_interpolation_over_concatenation',
    'prefer_keys_with_lookup',
    'prefer_late_over_nullable',
    'prefer_lower_camel_case_constants',
    'prefer_map_entries_iteration',
    'prefer_material_theme_colors',
    'prefer_methods_before_fields',
    'prefer_no_blank_line_before_return',
    'prefer_no_blank_line_inside_blocks',
    'prefer_null_aware_assignment',
    'prefer_nullable_over_late',
    'prefer_object_over_dynamic',
    'prefer_on_over_catch',
    'prefer_positive_conditions',
    'prefer_positive_conditions_first',
    'prefer_required_before_optional',
    'prefer_richtext_over_text_rich',
    'prefer_screaming_case_constants',
    'prefer_self_documenting_tests',
    'prefer_single_blank_line_max',
    'prefer_single_expectation_per_test',
    'prefer_sizedbox_over_container',
    'prefer_specific_exceptions',
    'prefer_spread_over_addall',
    'prefer_super_parameters',
    'prefer_switch_statement',
    'prefer_sync_over_async_where_possible',
    'prefer_ternary_over_collection_if',
    'prefer_ternary_over_if_null',
    'prefer_test_data_builder',
    'prefer_test_name_descriptive',
    'prefer_test_name_should_when',
    'prefer_text_rich_over_richtext',
    'prefer_then_over_await',
    'prefer_var_over_explicit_type',
    'prefer_wheretype_over_where_is',
  ],
  'Control flow & collection style': <String>[
    'prefer_early_return',
    'prefer_mutable_collections',
    'prefer_record_over_equatable',
  ],
};

// ---------------------------------------------------------------------------
// Tier functions - read directly from rule classes (single source of truth)
// ---------------------------------------------------------------------------

/// Maps RuleTier enum to tier string name.
String _tierToString(RuleTier tier) {
  switch (tier) {
    case RuleTier.essential:
      return 'essential';
    case RuleTier.recommended:
      return 'recommended';
    case RuleTier.professional:
      return 'professional';
    case RuleTier.comprehensive:
      return 'comprehensive';
    case RuleTier.pedantic:
      return 'pedantic';
    case RuleTier.stylistic:
      return 'stylistic';
  }
}

/// Returns the tier order index (lower = stricter requirements).
int _tierIndex(RuleTier tier) {
  switch (tier) {
    case RuleTier.essential:
      return 0;
    case RuleTier.recommended:
      return 1;
    case RuleTier.professional:
      return 2;
    case RuleTier.comprehensive:
      return 3;
    case RuleTier.pedantic:
      return 4;
    case RuleTier.stylistic:
      return -1; // Stylistic is opt-in, not part of tier progression
  }
}

/// Gets tier from tiers.dart sets (single source of truth).
RuleTier _getTierFromSets(String ruleName) {
  if (tiers.stylisticRules.contains(ruleName)) return RuleTier.stylistic;
  if (tiers.essentialRules.contains(ruleName)) return RuleTier.essential;
  if (tiers.pedanticOnlyRules.contains(ruleName)) return RuleTier.pedantic;
  if (tiers.comprehensiveOnlyRules.contains(ruleName)) {
    return RuleTier.comprehensive;
  }
  if (tiers.professionalOnlyRules.contains(ruleName)) {
    return RuleTier.professional;
  }
  if (tiers.recommendedOnlyRules.contains(ruleName)) {
    return RuleTier.recommended;
  }
  return RuleTier.professional;
}

/// Main entry point for the CLI tool.
Future<void> main(List<String> args) async {
  // Enable ANSI color support on Windows 10+
  _tryEnableAnsiWindows();

  // Initialize log timestamp for report file
  final now = DateTime.now();
  _logTimestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

  // Get version and source info early for logging
  final version = _getPackageVersion();
  final source = _getPackageSource();

  // Add header to log buffer
  _logBuffer.writeln('=' * 80);
  _logBuffer.writeln('SAROPA LINTS CONFIGURATION LOG');
  _logBuffer.writeln('Version: $version');
  _logBuffer.writeln('Source: $source');
  _logBuffer.writeln('Generated: ${now.toIso8601String()}');
  _logBuffer.writeln('Arguments: ${args.join(' ')}');
  _logBuffer.writeln('=' * 80);
  _logBuffer.writeln();

  final CliArgs cliArgs = _parseArguments(args);
  if (cliArgs.showHelp) {
    _printUsage();
    return;
  }

  _logTerminal('');
  _logTerminal('${_Colors.cyan}SAROPA LINTS${_Colors.reset} v$version');
  _logTerminal('${_Colors.dim}Source: $source${_Colors.reset}');
  _logTerminal('');

  // Resolve tier (handle numeric input)
  final String? tier = _resolveTier(cliArgs.tier);
  if (tier == null) {
    _logTerminal(_error('✗ Error: Invalid tier "${cliArgs.tier}"'));
    _logTerminal('');
    _logTerminal('Valid tiers:');
    for (final MapEntry<String, int> entry in tierIds.entries) {
      _logTerminal('  ${entry.value} or ${_tierColor(entry.key)}');
    }
    exitCode = 1;
    return;
  }

  _logTerminal(
      '${_Colors.bold}Tier:${_Colors.reset} ${_tierColor(tier)} (level ${tierIds[tier]})');
  _logTerminal('${_Colors.dim}${tierDescriptions[tier]}${_Colors.reset}');
  _logTerminal('');

  // tiers.dart is the source of truth for all rules
  // A unit test validates that all plugin rules are in tiers.dart
  final Set<String> allRules = tiers.getAllDefinedRules();
  final Set<String> enabledRules = tiers.getRulesForTier(tier);
  final Set<String> disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in)
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;
  if (cliArgs.includeStylistic) {
    finalEnabled = finalEnabled.union(tiers.stylisticRules);
    finalDisabled = finalDisabled.difference(tiers.stylisticRules);
  } else {
    finalEnabled = finalEnabled.difference(tiers.stylisticRules);
    finalDisabled = finalDisabled.union(tiers.stylisticRules);
  }

  // Read or create custom overrides file (survives --reset)
  final File overridesFile = File('analysis_options_custom.yaml');
  Map<String, bool> permanentOverrides = <String, bool>{};
  Map<String, bool> platformSettings = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );
  Map<String, bool> packageSettings = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (overridesFile.existsSync()) {
    // Ensure all sections exist in the file
    _ensureMaxIssuesSetting(overridesFile);
    _ensurePlatformsSetting(overridesFile);
    _ensurePackagesSetting(overridesFile);
    _ensureStylisticRulesSection(overridesFile);
    platformSettings = _extractPlatformsFromFile(overridesFile);
    packageSettings = _extractPackagesFromFile(overridesFile);

    // Extract overrides and partition stylistic from non-stylistic
    final allOverrides = _extractOverridesFromFile(overridesFile, allRules);
    for (final entry in allOverrides.entries) {
      if (tiers.stylisticRules.contains(entry.key)) {
        // Stylistic overrides apply on top of --stylistic flag
        if (entry.value) {
          finalEnabled = finalEnabled.union(<String>{entry.key});
          finalDisabled = finalDisabled.difference(<String>{entry.key});
        } else {
          finalEnabled = finalEnabled.difference(<String>{entry.key});
          finalDisabled = finalDisabled.union(<String>{entry.key});
        }
      } else {
        permanentOverrides[entry.key] = entry.value;
      }
    }
  } else {
    // Create the custom overrides file with a helpful header
    _createCustomOverridesFile(overridesFile);
    _logTerminal(
        '${_Colors.green}✓ Created:${_Colors.reset} analysis_options_custom.yaml');
  }

  // Apply platform filtering - disable rules for disabled platforms
  final Set<String> platformDisabledRules =
      tiers.getRulesDisabledByPlatforms(platformSettings);

  if (platformDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(platformDisabledRules);
    finalDisabled = finalDisabled.union(platformDisabledRules);

    final disabledPlatforms = platformSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    _logTerminal('${_Colors.yellow}Platforms disabled:${_Colors.reset} '
        '${disabledPlatforms.join(', ')} '
        '${_Colors.dim}(${platformDisabledRules.length} rules affected)${_Colors.reset}');
  }

  // Apply package filtering - disable rules for disabled packages
  final Set<String> packageDisabledRules =
      tiers.getRulesDisabledByPackages(packageSettings);

  if (packageDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(packageDisabledRules);
    finalDisabled = finalDisabled.union(packageDisabledRules);

    final disabledPackages = packageSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    _logTerminal('${_Colors.yellow}Packages disabled:${_Colors.reset} '
        '${disabledPackages.join(', ')} '
        '${_Colors.dim}(${packageDisabledRules.length} rules affected)${_Colors.reset}');
  }

  // Read existing config and extract user customizations
  final File outputFile = File(cliArgs.outputPath);
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();

    if (!cliArgs.reset) {
      userCustomizations = _extractUserCustomizations(
        existingContent,
        allRules,
      );

      // Warn if suspiciously many customizations (likely corrupted)
      if (userCustomizations.length > 50) {
        _logTerminal(
            '${_Colors.red}⚠ ${userCustomizations.length} customizations found - consider --reset${_Colors.reset}');
      }
    } else {
      _logTerminal(
          '${_Colors.yellow}⚠ --reset: discarding customizations${_Colors.reset}');
    }
  }

  // Merge permanent overrides with user customizations
  // Permanent overrides always take precedence
  if (permanentOverrides.isNotEmpty) {
    userCustomizations = {...userCustomizations, ...permanentOverrides};
  }

  // Count rules by severity for summary
  final Map<String, int> enabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0
  };
  final Map<String, int> disabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0
  };

  for (final rule in finalEnabled) {
    final severity = _getRuleSeverity(rule);
    enabledBySeverity[severity] = (enabledBySeverity[severity] ?? 0) + 1;
  }
  for (final rule in finalDisabled) {
    final severity = _getRuleSeverity(rule);
    disabledBySeverity[severity] = (disabledBySeverity[severity] ?? 0) + 1;
  }

  // Count by tier for enabled rules
  final Map<String, int> enabledByTierCount = {};
  for (final rule in finalEnabled) {
    final tierName = _tierToString(_getRuleTierFromMetadata(rule));
    enabledByTierCount[tierName] = (enabledByTierCount[tierName] ?? 0) + 1;
  }

  // Compact summary
  _logTerminal('');
  final customCount = userCustomizations.length;
  final customStr = customCount > 0
      ? ' ${_Colors.dim}(+$customCount custom)${_Colors.reset}'
      : '';
  _logTerminal(
      '${_Colors.bold}Rules:${_Colors.reset} ${_success('${finalEnabled.length} enabled')} / ${_error('${finalDisabled.length} disabled')}$customStr');
  _logTerminal(
      '${_Colors.bold}Severity:${_Colors.reset} ${_Colors.red}${enabledBySeverity['ERROR']} errors${_Colors.reset} · ${_Colors.yellow}${enabledBySeverity['WARNING']} warnings${_Colors.reset} · ${_Colors.cyan}${enabledBySeverity['INFO']} info${_Colors.reset}');
  _logTerminal('');

  // Generate the new custom_lint section with proper formatting
  final String customLintYaml = _generateCustomLintYaml(
    tier: tier,
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
    includeStylistic: cliArgs.includeStylistic,
    platformSettings: platformSettings,
    packageSettings: packageSettings,
  );

  // Replace custom_lint section in existing content, preserving everything else
  final String newContent =
      _replaceCustomLintSection(existingContent, customLintYaml);

  if (cliArgs.dryRun) {
    _logTerminal('${_Colors.yellow}━━━ DRY RUN ━━━${_Colors.reset}');
    _logTerminal(
        '${_Colors.dim}Would write to: ${cliArgs.outputPath}${_Colors.reset}');
    _logTerminal('');

    // Show preview of custom_lint section only
    final List<String> lines = customLintYaml.split('\n');
    const int previewLines = 100;
    _logTerminal(
        '${_Colors.bold}Preview${_Colors.reset} ${_Colors.dim}(first $previewLines of ${lines.length} lines):${_Colors.reset}');
    _logTerminal('${_Colors.dim}${'─' * 60}${_Colors.reset}');
    for (int i = 0; i < previewLines && i < lines.length; i++) {
      _logTerminal(lines[i]);
    }
    if (lines.length > previewLines) {
      _logTerminal(
          '${_Colors.dim}... (${lines.length - previewLines} more lines)${_Colors.reset}');
    }
    return;
  }

  // Skip writing if the file content hasn't changed
  if (newContent == existingContent) {
    _logTerminal(
        '${_Colors.dim}✓ No changes needed: ${cliArgs.outputPath}${_Colors.reset}');
  } else {
    // Create backup before overwriting
    try {
      final outputDir = outputFile.parent.path;
      final outputName = cliArgs.outputPath.split('/').last.split('\\').last;
      final backupPath = '$outputDir/${_logTimestamp}_$outputName.bak';
      outputFile.copySync(backupPath);
    } on Exception catch (_) {
      // Backup failed - continue anyway
    }

    try {
      outputFile.writeAsStringSync(newContent);
      _logTerminal('${_success('✓ Written to:')} ${cliArgs.outputPath}');
    } on Exception catch (e) {
      _logTerminal(_error('✗ Failed to write file: $e'));
      exitCode = 2;
      return;
    }
  }

  _logTerminal('');

  // Write detailed log file (unless dry-run)
  if (!cliArgs.dryRun) {
    _writeLogFile();

    // Ask user if they want to run analysis
    stdout.write('${_Colors.cyan}Run analysis now? [y/N]: ${_Colors.reset}');
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

    if (response == 'y' || response == 'yes') {
      _logTerminal('');
      _logTerminal(
          '🚀 ${_Colors.bold}Running: dart run custom_lint${_Colors.reset}');
      _logTerminal('${'─' * 60}');

      // Run with inheritStdio for real-time output streaming
      // Must await to prevent parent exit from killing child process
      final process = await Process.start(
        'dart',
        ['run', 'custom_lint'],
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      await process.exitCode;
      _logTerminal('${'─' * 60}');
    }
  }
}

/// Matches the USER CUSTOMIZATIONS section header in generated YAML.
final RegExp _userCustomizationsSectionPattern =
    RegExp(r'USER CUSTOMIZATIONS', multiLine: true);

/// Extract existing user customizations from the USER CUSTOMIZATIONS section.
///
/// Only rules that appear in the explicit USER CUSTOMIZATIONS section are
/// considered customizations. Rules in tier sections are NOT customizations -
/// they were set by the tier system and will be recalculated.
///
/// This prevents tier changes from creating spurious "customizations".
///
/// Parameters:
/// - [yamlContent] - The existing YAML file content
/// - [allRules] - All known saropa_lints rules
Map<String, bool> _extractUserCustomizations(
  String yamlContent,
  Set<String> allRules,
) {
  final Map<String, bool> customizations = <String, bool>{};

  // Find USER CUSTOMIZATIONS section
  final Match? customizationsMatch =
      _userCustomizationsSectionPattern.firstMatch(yamlContent);
  if (customizationsMatch == null) {
    // No customizations section - file wasn't generated by this tool
    // or user hasn't made any customizations
    return customizations;
  }

  // Find the content after USER CUSTOMIZATIONS header
  final String afterHeader = yamlContent.substring(customizationsMatch.end);

  // Find the end of the customizations section (next major section header)
  // Look for ENABLED, DISABLED, STYLISTIC, or TIER headers
  final sectionEndPattern = RegExp(
    r'(ENABLED RULES|DISABLED RULES|STYLISTIC|TIER \d+:)',
    multiLine: true,
  );
  final Match? nextSection = sectionEndPattern.firstMatch(afterHeader);
  final String customizationsSection = nextSection != null
      ? afterHeader.substring(0, nextSection.start)
      : afterHeader;

  // Extract rules from the customizations section only
  for (final Match match
      in _ruleEntryPattern.allMatches(customizationsSection)) {
    final String ruleName = match.group(1)!;
    final bool currentEnabled = match.group(2) == 'true';

    // Skip rules that aren't in our rule set (might be from other plugins)
    if (!allRules.contains(ruleName)) {
      continue;
    }

    customizations[ruleName] = currentEnabled;
  }

  return customizations;
}

/// Extract rule overrides from analysis_options_custom.yaml.
///
/// Supports multiple formats:
/// ```yaml
/// # Custom rule overrides (survives --reset)
/// avoid_print: false  # Allow print in this project
/// - avoid_null_assertion: false # With hyphen prefix
///   - require_error_widget: false # Indented with hyphen
/// prefer_const_constructors: true
/// ```
///
/// These overrides are always applied, even when using --reset.
Map<String, bool> _extractOverridesFromFile(File file, Set<String> allRules) {
  final Map<String, bool> overrides = <String, bool>{};

  if (!file.existsSync()) {
    return overrides;
  }

  final content = file.readAsStringSync();

  // Match rule entries with optional hyphen, indentation, and trailing comments:
  // - rule_name: true/false # optional comment
  //   rule_name: true/false
  // rule_name: false
  final rulePattern = RegExp(
    r'^\s*-?\s*([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(content)) {
    final ruleName = match.group(1)!;
    final enabled = match.group(2) == 'true';

    // Only include rules we know about
    if (allRules.contains(ruleName)) {
      overrides[ruleName] = enabled;
    }
  }

  return overrides;
}

/// Create the analysis_options_custom.yaml file with a helpful header.
///
/// Includes the STYLISTIC RULES section with all opinionated rules
/// defaulting to false, organized by category.
void _createCustomOverridesFile(File file) {
  final stylisticSection = _buildStylisticSection();
  final packageSection = _buildPackageSection();

  final content = '''
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    SAROPA LINTS CUSTOM CONFIG                             ║
# ║                                                                           ║
# ║  Settings in this file are ALWAYS applied, even when using --reset.      ║
# ║  Use this for project-specific customizations that should persist.       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart run custom_lint
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart run custom_lint

max_issues: 500
output: both

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Rules specific to disabled platforms will be automatically disabled.
# Only ios and android are enabled by default.
#
# EXAMPLES:
#   - Web-only project: set ios, android, macos, windows, linux to false; web to true
#   - All platforms: set all to true
#   - Desktop app: set macos, windows, linux to true

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

$packageSection$stylisticSection# ─────────────────────────────────────────────────────────────────────────────
# RULE OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────
# FORMAT: rule_name: true/false
#
# EXAMPLES:
#   - avoid_print: false                # Allow print statements
#   - avoid_null_assertion: false       # Allow ! operator
#   - prefer_const_constructors: true   # Force-enable regardless of tier
#
# Add your custom rule overrides below:

''';

  file.writeAsStringSync(content);
}

/// Ensure max_issues setting exists in an existing custom config file.
///
/// Added in v4.9.1 - older files won't have this setting, so we add it
/// at the top of the file if missing.
void _ensureMaxIssuesSetting(File file) {
  final content = file.readAsStringSync();

  // Check if max_issues already exists
  if (RegExp(r'^max_issues:\s*\d+', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  // Add max_issues at the top, after any existing header comments
  final settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS (added in v4.9.1, updated v4.12.2)
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart run custom_lint
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart run custom_lint

max_issues: 500
output: both

''';

  // Find where to insert - after the header box if present, else at top
  final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);
  String newContent;
  if (headerEndMatch != null) {
    // Insert after the header box
    final insertPos = headerEndMatch.end;
    newContent = content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    // No header box, insert at top
    newContent = settingBlock + content;
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
      '${_Colors.green}✓ Added max_issues setting to ${file.path}${_Colors.reset}');
}

/// Ensure platforms setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// max_issues setting if missing.
void _ensurePlatformsSetting(File file) {
  final content = file.readAsStringSync();

  // Check if platforms section already exists
  if (RegExp(r'^platforms:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  const settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Only ios and android are enabled by default.

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

''';

  // Insert after max_issues line if present, else after header
  final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
  String newContent;
  if (maxIssuesMatch != null) {
    final insertPos = maxIssuesMatch.end;
    newContent = content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);
    if (headerEndMatch != null) {
      final insertPos = headerEndMatch.end;
      newContent = content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
      '${_Colors.green}✓ Added platforms setting to ${file.path}${_Colors.reset}');
}

/// Ensure packages setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// platforms setting if missing.
void _ensurePackagesSetting(File file) {
  final content = file.readAsStringSync();

  // Check if packages section already exists
  if (RegExp(r'^packages:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  final packageEntries = tiers.allPackages
      .map((p) => '  $p: ${tiers.defaultPackages[p]}')
      .join('\n');

  final settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable packages your project doesn't use.
# Rules specific to disabled packages will be automatically disabled.
# All packages are enabled by default for backward compatibility.
#
# EXAMPLES:
#   - Riverpod-only project: set bloc, provider, getx to false
#   - No local DB: set isar, hive, sqflite to false
#   - No Firebase: set firebase to false

packages:
$packageEntries

''';

  // Insert after platforms section if present
  final platformsEndMatch = RegExp(
    r'^platforms:\s*\n(?:\s+\w+:\s*(?:true|false)\s*\n)*',
    multiLine: true,
  ).firstMatch(content);

  String newContent;
  if (platformsEndMatch != null) {
    final insertPos = platformsEndMatch.end;
    newContent = content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    // Fallback: insert after max_issues
    final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
    if (maxIssuesMatch != null) {
      final insertPos = maxIssuesMatch.end;
      newContent = content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  _logTerminal(
      '${_Colors.green}✓ Added packages setting to ${file.path}${_Colors.reset}');
}

/// Builds the PACKAGE SETTINGS section for analysis_options_custom.yaml.
String _buildPackageSection() {
  final buffer = StringBuffer();
  buffer.writeln(
      '# ─────────────────────────────────────────────────────────────────────────────');
  buffer.writeln('# PACKAGE SETTINGS');
  buffer.writeln(
      '# ─────────────────────────────────────────────────────────────────────────────');
  buffer.writeln("# Disable packages your project doesn't use.");
  buffer.writeln(
      '# Rules specific to disabled packages will be automatically disabled.');
  buffer.writeln(
      '# All packages are enabled by default for backward compatibility.');
  buffer.writeln('#');
  buffer.writeln('# EXAMPLES:');
  buffer.writeln(
      '#   - Riverpod-only project: set bloc, provider, getx to false');
  buffer.writeln('#   - No local DB: set isar, hive, sqflite to false');
  buffer.writeln('#   - No Firebase: set firebase to false');
  buffer.writeln('');
  buffer.writeln('packages:');
  for (final package in tiers.allPackages) {
    final enabled = tiers.defaultPackages[package] ?? true;
    buffer.writeln('  $package: $enabled');
  }
  buffer.writeln('');
  return buffer.toString();
}

/// Builds the STYLISTIC RULES section content for analysis_options_custom.yaml.
///
/// Lists all stylistic rules organized by category with problem message
/// comments. Preserves existing true/false values from [existingValues].
/// Skips rules in [skipRules] (found elsewhere in the file).
/// New rules default to `false`.
String _buildStylisticSection({
  Map<String, bool> existingValues = const <String, bool>{},
  Set<String> skipRules = const <String>{},
}) {
  final buffer = StringBuffer();
  buffer.writeln(
      '# ─────────────────────────────────────────────────────────────────────────────');
  buffer.writeln('# STYLISTIC RULES');
  buffer.writeln(
      '# ─────────────────────────────────────────────────────────────────────────────');
  buffer.writeln(
      '# Opinionated formatting, ordering, and naming convention rules.');
  buffer.writeln(
      '# These are NOT included in any tier - enable the ones that match your style.');
  buffer.writeln('# Set to true to enable, false to disable.');
  buffer.writeln('#');
  buffer.writeln('# NOTE: Some rules conflict (e.g., prefer_single_quotes vs');
  buffer.writeln(
      '# prefer_double_quotes). Only enable one from each conflicting group.');
  buffer.writeln('');

  final categorizedRules = <String>{};

  for (final entry in _stylisticRuleCategories.entries) {
    final category = entry.key;
    final rules = entry.value;

    // Filter out skipped rules
    final activeRules = rules.where((r) => !skipRules.contains(r)).toList();
    if (activeRules.isEmpty) continue;

    buffer.writeln('# --- $category ---');
    for (final rule in activeRules) {
      final enabled = existingValues[rule] ?? false;
      final msg = _getStylisticDescription(rule);
      final comment = msg.isNotEmpty ? '  # $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
      categorizedRules.add(rule);
    }
    buffer.writeln('');
  }

  // Add any uncategorized stylistic rules (safety net for new rules)
  final uncategorized = tiers.stylisticRules
      .difference(categorizedRules)
      .difference(skipRules)
      .toList()
    ..sort();

  if (uncategorized.isNotEmpty) {
    buffer.writeln('# --- Other stylistic rules ---');
    for (final rule in uncategorized) {
      final enabled = existingValues[rule] ?? false;
      final msg = _getStylisticDescription(rule);
      final comment = msg.isNotEmpty ? '  # $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}

/// Regex matching the STYLISTIC RULES section header.
final RegExp _stylisticSectionHeader =
    RegExp(r'# STYLISTIC RULES\s*\n', multiLine: true);

/// Regex matching the RULE OVERRIDES section header.
final RegExp _ruleOverridesSectionHeader =
    RegExp(r'# RULE OVERRIDES\s*\n', multiLine: true);

/// Ensure stylistic rules section exists and is complete in the custom
/// config file. Adds missing rules, preserves existing true/false values.
/// Skips rules that appear in the RULE OVERRIDES section.
void _ensureStylisticRulesSection(File file) {
  final content = file.readAsStringSync();

  // Find rules in the RULE OVERRIDES section (to skip them)
  final rulesInOverrides = _extractRulesInOverridesSection(content);
  final skipRules = rulesInOverrides.intersection(tiers.stylisticRules);

  // Check if STYLISTIC RULES section exists
  final sectionMatch = _stylisticSectionHeader.firstMatch(content);

  if (sectionMatch == null) {
    // No section yet - insert after platforms section, before RULE OVERRIDES
    final newSection = _buildStylisticSection(skipRules: skipRules);
    final insertContent = '\n$newSection';

    // Find insertion point: before RULE OVERRIDES header
    final overridesHeaderMatch = RegExp(
      r'# ─+\n# RULE OVERRIDES',
      multiLine: true,
    ).firstMatch(content);

    String newContent;
    if (overridesHeaderMatch != null) {
      newContent = content.substring(0, overridesHeaderMatch.start) +
          insertContent +
          content.substring(overridesHeaderMatch.start);
    } else {
      // No RULE OVERRIDES section, append before end
      newContent = content + insertContent;
    }

    file.writeAsStringSync(newContent);
    _logTerminal(
        '${_Colors.green}✓ Added stylistic rules section to ${file.path}${_Colors.reset}');
    return;
  }

  // Section exists - parse existing values and rebuild
  final existingValues = _extractStylisticSectionValues(content);
  final newSection = _buildStylisticSection(
    existingValues: existingValues,
    skipRules: skipRules,
  );

  // Find section boundaries
  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);

  final newContent = content.substring(0, sectionStart) +
      newSection +
      content.substring(sectionEnd);

  file.writeAsStringSync(newContent);
}

/// Find the start of the STYLISTIC RULES section (including the divider).
int _findStylisticSectionStart(String content) {
  // Look for the divider line before "# STYLISTIC RULES"
  final match = RegExp(
    r'# ─+\n# STYLISTIC RULES',
    multiLine: true,
  ).firstMatch(content);
  return match?.start ?? content.length;
}

/// Find the end of the STYLISTIC RULES section.
/// Ends at the next section divider or end of file.
int _findStylisticSectionEnd(String content, int sectionStart) {
  // Find the next section header (─── divider) after the STYLISTIC RULES
  // header itself. Skip the first two divider lines (the section's own header).
  final afterHeader = content.indexOf('\n', sectionStart);
  if (afterHeader == -1) return content.length;

  // Skip past the "# STYLISTIC RULES" line and its closing divider
  final afterSectionHeader =
      _stylisticSectionHeader.firstMatch(content.substring(afterHeader));
  final searchFrom = afterSectionHeader != null
      ? afterHeader + afterSectionHeader.end
      : afterHeader;

  final nextDivider = RegExp(
    r'\n# ─+\n# ',
    multiLine: true,
  ).firstMatch(content.substring(searchFrom));

  if (nextDivider != null) {
    return searchFrom + nextDivider.start + 1; // +1 for the leading \n
  }
  return content.length;
}

/// Extract rule name → enabled values from the STYLISTIC RULES section only.
Map<String, bool> _extractStylisticSectionValues(String content) {
  final values = <String, bool>{};

  final sectionStart = _findStylisticSectionStart(content);
  final sectionEnd = _findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  final rulePattern = RegExp(
    r'^([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(sectionContent)) {
    final ruleName = match.group(1)!;
    final enabled = match.group(2) == 'true';
    if (tiers.stylisticRules.contains(ruleName)) {
      values[ruleName] = enabled;
    }
  }

  return values;
}

/// Extract rule names from the RULE OVERRIDES section.
Set<String> _extractRulesInOverridesSection(String content) {
  final rules = <String>{};

  final sectionMatch = _ruleOverridesSectionHeader.firstMatch(content);
  if (sectionMatch == null) return rules;

  // Content after the RULE OVERRIDES header until end of file
  // (it's the last section)
  final afterSection = content.substring(sectionMatch.end);

  final rulePattern = RegExp(
    r'^([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(afterSection)) {
    rules.add(match.group(1)!);
  }

  return rules;
}

/// Extract platform settings from analysis_options_custom.yaml.
///
/// Returns a map of platform name to enabled status.
/// Defaults to [tiers.defaultPlatforms] if not specified (ios and android
/// enabled, others disabled).
///
/// Supports format:
/// ```yaml
/// platforms:
///   ios: true
///   android: false
///   web: true
/// ```
Map<String, bool> _extractPlatformsFromFile(File file) {
  final Map<String, bool> platforms = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );

  if (!file.existsSync()) return platforms;

  final content = file.readAsStringSync();

  // Find the platforms: section
  final sectionMatch =
      RegExp(r'^platforms:\s*$', multiLine: true).firstMatch(content);
  if (sectionMatch == null) return platforms;

  // Extract indented entries after platforms:
  final afterSection = content.substring(sectionMatch.end);

  final platformPattern = RegExp(
    r'^\s+(ios|android|macos|web|windows|linux):\s*(true|false)',
    multiLine: true,
  );

  for (final match in platformPattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1)!;
    final enabled = match.group(2) == 'true';
    platforms[name] = enabled;
  }

  return platforms;
}

/// Extract package settings from analysis_options_custom.yaml.
///
/// Returns a map of package name to enabled status.
/// Defaults to [tiers.defaultPackages] if not specified (all enabled).
///
/// Supports format:
/// ```yaml
/// packages:
///   bloc: true
///   riverpod: false
///   firebase: true
/// ```
Map<String, bool> _extractPackagesFromFile(File file) {
  final Map<String, bool> packages = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (!file.existsSync()) return packages;

  final content = file.readAsStringSync();

  // Find the packages: section
  final sectionMatch =
      RegExp(r'^packages:\s*$', multiLine: true).firstMatch(content);
  if (sectionMatch == null) return packages;

  // Extract indented entries after packages:
  final afterSection = content.substring(sectionMatch.end);

  final packagePattern = RegExp(
    r'^\s+([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in packagePattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1)!;
    final enabled = match.group(2) == 'true';

    // Only include packages we know about
    if (tiers.defaultPackages.containsKey(name)) {
      packages[name] = enabled;
    }
  }

  return packages;
}

/// Generate the custom_lint YAML section with proper formatting.
///
/// Organizes rules by tier with problem message comments.
String _generateCustomLintYaml({
  required String tier,
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> allRules,
  required bool includeStylistic,
  required Map<String, bool> platformSettings,
  required Map<String, bool> packageSettings,
}) {
  final StringBuffer buffer = StringBuffer();
  final customizedRuleNames = userCustomizations.keys.toSet();

  buffer.writeln('custom_lint:');
  buffer.writeln(
      '  # ═══════════════════════════════════════════════════════════════════════');
  buffer.writeln('  # SAROPA LINTS CONFIGURATION');
  buffer.writeln(
      '  # ═══════════════════════════════════════════════════════════════════════');
  buffer
      .writeln('  # Regenerate with: dart run saropa_lints:init --tier $tier');
  buffer.writeln(
      '  # Tier: $tier (${enabledRules.length} of ${allRules.length} rules enabled)');
  buffer.writeln(
      '  # custom_lint enables ALL rules by default. To disable a rule, set it to false.');
  buffer
      .writeln('  # User customizations are preserved unless --reset is used');
  buffer.writeln('  #');
  buffer.writeln('  # Tiers (cumulative):');
  buffer.writeln(
      '  #   1. essential    - Critical: crashes, security, memory leaks');
  buffer.writeln(
      '  #   2. recommended  - Essential + accessibility, performance');
  buffer.writeln('  #   3. professional - Recommended + architecture, testing');
  buffer.writeln('  #   4. comprehensive - Professional + thorough coverage');
  buffer.writeln(
      '  #   5. pedantic     - All rules (pedantic, highly opinionated)');
  buffer.writeln('  #   +  stylistic    - Opt-in only (formatting, ordering)');
  buffer.writeln('  #');

  // Show platform status
  final disabledPlatforms = platformSettings.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList();
  if (disabledPlatforms.isNotEmpty) {
    buffer.writeln('  # Disabled platforms: ${disabledPlatforms.join(', ')}');
    buffer.writeln('  #');
  }

  // Show package status
  final disabledPackages =
      packageSettings.entries.where((e) => !e.value).map((e) => e.key).toList();
  if (disabledPackages.isNotEmpty) {
    buffer.writeln('  # Disabled packages: ${disabledPackages.join(', ')}');
    buffer.writeln('  #');
  }

  buffer.writeln(
      '  # Settings (max_issues, platforms, packages) are in analysis_options_custom.yaml');
  buffer.writeln(
      '  # ═══════════════════════════════════════════════════════════════════════');
  buffer.writeln('');
  buffer.writeln('  rules:');

  // Section 1: User customizations (always at top, preserved)
  if (userCustomizations.isNotEmpty) {
    buffer.writeln(_sectionHeader('USER CUSTOMIZATIONS', '~'));
    buffer.writeln(
        '    # These rules have been manually configured and will be preserved');
    buffer.writeln(
        '    # when regenerating. Use --reset to discard these customizations.');
    buffer.writeln('');

    final List<String> sortedCustomizations = userCustomizations.keys.toList()
      ..sort();
    for (final String rule in sortedCustomizations) {
      final bool enabled = userCustomizations[rule]!;
      final String msg = _getProblemMessage(rule);
      final String severity = _getRuleSeverity(rule);
      buffer.writeln('    - $rule: $enabled  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Group rules by their tier
  final Map<RuleTier, List<String>> enabledByTier = {};
  final Map<RuleTier, List<String>> disabledByTier = {};

  for (final tier in RuleTier.values) {
    enabledByTier[tier] = [];
    disabledByTier[tier] = [];
  }

  // Categorize enabled rules by tier
  for (final String rule in enabledRules.difference(customizedRuleNames)) {
    final ruleTier = _getRuleTierFromMetadata(rule);
    enabledByTier[ruleTier]!.add(rule);
  }

  // Categorize disabled rules by tier
  for (final String rule in disabledRules.difference(customizedRuleNames)) {
    final ruleTier = _getRuleTierFromMetadata(rule);
    disabledByTier[ruleTier]!.add(rule);
  }

  // Section 2: Enabled rules organized by tier
  buffer.writeln(_sectionHeader('ENABLED RULES ($tier tier)', '='));
  buffer.writeln('');

  // Output enabled tiers in order
  for (final tierLevel in [
    RuleTier.essential,
    RuleTier.recommended,
    RuleTier.professional,
    RuleTier.comprehensive,
    RuleTier.pedantic,
  ]) {
    final rules = enabledByTier[tierLevel]!..sort();
    if (rules.isEmpty) continue;

    final tierName = _tierToString(tierLevel).toUpperCase();
    final tierNum = _tierIndex(tierLevel) + 1;
    buffer.writeln('    #');
    buffer.writeln(
        '    # --- TIER $tierNum: $tierName (${rules.length} rules) ---');
    buffer.writeln('    #');
    for (final String rule in rules) {
      final String msg = _getProblemMessage(rule);
      final String severity = _getRuleSeverity(rule);
      buffer.writeln('    - $rule: true  # [$severity] $msg');
    }
    buffer.writeln('');
  }

  // Section 3: Stylistic rules (separate section)
  final stylisticEnabled = enabledByTier[RuleTier.stylistic]!..sort();
  final stylisticDisabled = disabledByTier[RuleTier.stylistic]!..sort();

  if (stylisticEnabled.isNotEmpty || stylisticDisabled.isNotEmpty) {
    buffer.writeln(_sectionHeader('STYLISTIC RULES (opt-in)', '~'));
    buffer.writeln('    # Formatting, ordering, naming conventions.');
    buffer.writeln(
        '    # Enable with: dart run saropa_lints:init --tier <tier> --stylistic');
    buffer.writeln('');

    if (stylisticEnabled.isNotEmpty) {
      buffer.writeln('    #');
      buffer.writeln(
          '    # ┌───────────────────────────────────────────────────────────────────────┐');
      buffer.writeln(
          '    # │  ✓ ENABLED STYLISTIC (${stylisticEnabled.length} rules)${' ' * (47 - stylisticEnabled.length.toString().length)}│');
      buffer.writeln(
          '    # └───────────────────────────────────────────────────────────────────────┘');
      buffer.writeln('    #');
      for (final String rule in stylisticEnabled) {
        final String msg = _getProblemMessage(rule);
        buffer.writeln('    - $rule: true  # $msg');
      }
      buffer.writeln('');
    }

    if (stylisticDisabled.isNotEmpty) {
      buffer.writeln('    #');
      buffer.writeln(
          '    # ┌───────────────────────────────────────────────────────────────────────┐');
      buffer.writeln(
          '    # │  ✗ DISABLED STYLISTIC (${stylisticDisabled.length} rules)${' ' * (46 - stylisticDisabled.length.toString().length)}│');
      buffer.writeln(
          '    # └───────────────────────────────────────────────────────────────────────┘');
      buffer.writeln('    #');
      for (final String rule in stylisticDisabled) {
        final String msg = _getProblemMessage(rule);
        buffer.writeln('    - $rule: false  # $msg');
      }
      buffer.writeln('');
    }
  }

  // Section 4: Disabled rules by tier (rules above selected tier)
  final hasDisabledNonStylistic = [
    RuleTier.essential,
    RuleTier.recommended,
    RuleTier.professional,
    RuleTier.comprehensive,
    RuleTier.pedantic,
  ].any((t) => disabledByTier[t]!.isNotEmpty);

  if (hasDisabledNonStylistic) {
    buffer.writeln(_sectionHeader('DISABLED RULES (above $tier tier)', '-'));
    buffer.writeln('    # These rules are in higher tiers. To enable:');
    buffer.writeln('    #   1. Choose a higher tier with --tier <tier>');
    buffer.writeln(
        '    #   2. Or manually set to true in USER CUSTOMIZATIONS above');
    buffer.writeln('');

    // Output disabled tiers (from highest to lowest)
    for (final tierLevel in [
      RuleTier.pedantic,
      RuleTier.comprehensive,
      RuleTier.professional,
      RuleTier.recommended,
      RuleTier.essential,
    ]) {
      final rules = disabledByTier[tierLevel]!..sort();
      if (rules.isEmpty) continue;

      final tierName = _tierToString(tierLevel).toUpperCase();
      final tierNum = _tierIndex(tierLevel) + 1;
      buffer.writeln('    #');
      buffer.writeln(
          '    # ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐');
      buffer.writeln(
          '    #   TIER $tierNum: $tierName (${rules.length} rules disabled)');
      buffer.writeln(
          '    # └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘');
      buffer.writeln('    #');
      for (final String rule in rules) {
        final String msg = _getProblemMessage(rule);
        final String severity = _getRuleSeverity(rule);
        buffer.writeln('    - $rule: false  # [$severity] $msg');
      }
      buffer.writeln('');
    }
  }

  return buffer.toString();
}

/// Generate a clear, visible section header for YAML.
String _sectionHeader(String title, String char) {
  final String upperTitle = title.toUpperCase();
  const int width = 76;

  if (char == '=') {
    // ENABLED RULES - Double-line box
    return '''
    #
    # ${'═' * width}
    #   ✓ $upperTitle
    # ${'═' * width}
    #''';
  } else if (char == '~') {
    // STYLISTIC or USER CUSTOMIZATIONS - Wavy pattern
    return '''
    #
    # ${'~' * width}
    #   ◆ $upperTitle
    # ${'~' * width}
    #''';
  } else {
    // DISABLED RULES - Dashed pattern
    return '''
    #
    # ${'-' * width}
    #   ✗ $upperTitle
    # ${'-' * width}
    #''';
  }
}

/// Replace the custom_lint section in existing content, preserving everything else.
String _replaceCustomLintSection(String existingContent, String newCustomLint) {
  if (existingContent.isEmpty) {
    return newCustomLint;
  }

  // Find custom_lint: section
  final Match? customLintMatch =
      _customLintSectionPattern.firstMatch(existingContent);

  if (customLintMatch == null) {
    // No existing custom_lint section - append to end
    return '$existingContent\n$newCustomLint';
  }

  // Find the end of the custom_lint section (next top-level key or end of file)
  final String beforeCustomLint =
      existingContent.substring(0, customLintMatch.start);
  final String afterCustomLintStart =
      existingContent.substring(customLintMatch.end);

  // Find next top-level section (line starting with a word followed by colon, no indentation)
  final Match? nextSection =
      _topLevelKeyPattern.firstMatch(afterCustomLintStart);

  final String afterCustomLint = nextSection != null
      ? afterCustomLintStart.substring(nextSection.start)
      : '';

  return '$beforeCustomLint$newCustomLint\n$afterCustomLint';
}

/// Struct for parsed CLI arguments.
class CliArgs {
  const CliArgs({
    required this.showHelp,
    required this.dryRun,
    required this.reset,
    required this.includeStylistic,
    required this.outputPath,
    required this.tier,
  });

  final bool showHelp;
  final bool dryRun;
  final bool reset;
  final bool includeStylistic;
  final String outputPath;
  final String? tier;
}

/// Parse CLI arguments into a struct.
CliArgs _parseArguments(List<String> args) {
  final bool showHelp = args.contains('--help') || args.contains('-h');
  final bool dryRun = args.contains('--dry-run');
  final bool reset = args.contains('--reset');
  final bool includeStylistic = args.contains('--stylistic');

  String outputPath = 'analysis_options.yaml';
  int outputIndex = args.indexOf('--output');
  if (outputIndex == -1) {
    outputIndex = args.indexOf('-o');
  }
  if (outputIndex != -1 && outputIndex + 1 < args.length) {
    outputPath = args[outputIndex + 1];
  }

  String? requestedTier;
  int tierIndex = args.indexOf('--tier');
  if (tierIndex == -1) {
    tierIndex = args.indexOf('-t');
  }
  if (tierIndex != -1 && tierIndex + 1 < args.length) {
    requestedTier = args[tierIndex + 1];
  }

  return CliArgs(
    showHelp: showHelp,
    dryRun: dryRun,
    reset: reset,
    includeStylistic: includeStylistic,
    outputPath: outputPath,
    tier: requestedTier,
  );
}

void _logTerminal(String message) {
  print(message);
  _logBuffer.writeln(message);
}

String? _resolveTier(String? input) {
  if (input == null) {
    return 'comprehensive';
  }

  final int? numericTier = int.tryParse(input);
  if (numericTier != null) {
    for (final MapEntry<String, int> entry in tierIds.entries) {
      if (entry.value == numericTier) {
        return entry.key;
      }
    }
    return null;
  }

  final String normalized = input.toLowerCase();
  if (tierIds.containsKey(normalized)) {
    return normalized;
  }

  return null;
}

void _printUsage() {
  print('''

Saropa Lints Configuration Generator

Generates analysis_options.yaml with explicit rule configuration,
bypassing custom_lint's limited plugin config support.

IMPORTANT: This tool preserves:
  - All non-custom_lint sections (analyzer, linter, formatter, etc.)
  - User customizations in custom_lint.rules (unless --reset is used)

Usage: dart run saropa_lints:init [options]

Options:
  -t, --tier <tier>     Tier level (1-5 or name, default: comprehensive)
  -o, --output <file>   Output file (default: analysis_options.yaml)
  --stylistic           Include stylistic rules (opinionated, off by default)
  --reset               Discard user customizations and reset to tier defaults
  --dry-run             Preview output without writing
  -h, --help            Show this help message

Tiers:
${tierOrder.map((String t) => '  ${tierIds[t]}. $t\n     ${tierDescriptions[t]}').join('\n')}

Examples:
  dart run saropa_lints:init                          # Default: comprehensive
  dart run saropa_lints:init --tier comprehensive
  dart run saropa_lints:init --tier 4
  dart run saropa_lints:init --tier essential --reset
  dart run saropa_lints:init --tier pedantic --stylistic
  dart run saropa_lints:init --dry-run

After generating, run `dart run custom_lint` to verify.
''');
}
