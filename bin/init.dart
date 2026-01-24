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
/// 5. **insanity** - All rules enabled (~1650)
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

import 'dart:io';

import 'package:custom_lint_builder/custom_lint_builder.dart' show LintRule;
import 'package:saropa_lints/saropa_lints.dart'
    show RuleTier, SaropaLintRule, allSaropaRules;
// ignore: deprecated_member_use_from_same_package
import 'package:saropa_lints/src/tiers.dart' as legacy_tiers;

/// Package version - update when releasing.
const String _version = '4.7.1';

// ---------------------------------------------------------------------------
// Cross-platform ANSI color support
// ---------------------------------------------------------------------------

/// Detects if the terminal supports ANSI colors.
bool get _supportsColor {
  // Check for NO_COLOR environment variable (standard)
  if (Platform.environment.containsKey('NO_COLOR')) return false;

  // Check for FORCE_COLOR
  if (Platform.environment.containsKey('FORCE_COLOR')) return true;

  // Check if stdout is a terminal
  if (!stdout.hasTerminal) return false;

  // Windows: check for newer Windows Terminal or ConEmu
  if (Platform.isWindows) {
    final term = Platform.environment['TERM'];
    final wtSession = Platform.environment['WT_SESSION'];
    final conEmu = Platform.environment['ConEmuANSI'];
    return wtSession != null || conEmu == 'ON' || term == 'xterm';
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
String _warning(String text) => '${_Colors.yellow}$text${_Colors.reset}';
String _highlight(String text) => '${_Colors.bold}$text${_Colors.reset}';
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
    case 'insanity':
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
    required this.severity,
    required this.tier,
  });

  final String name;
  final String problemMessage;
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

      // Extract severity from LintCode
      final severity = rule.code.errorSeverity.name.toUpperCase();

      // Get tier (with legacy fallback)
      RuleTier tier = rule.tier;
      if (tier == RuleTier.professional) {
        // Check legacy if not explicitly set
        final legacyTier = _getLegacyTier(ruleName);
        if (legacyTier != null) {
          tier = legacyTier;
        }
      }

      _ruleMetadataCache![ruleName] = _RuleMetadata(
        name: ruleName,
        problemMessage: message,
        severity: severity,
        tier: tier,
      );
    }
  }
  return _ruleMetadataCache!;
}

/// Gets a short problem message (truncated for YAML comment).
String _getShortProblemMessage(String ruleName) {
  final metadata = _getRuleMetadata()[ruleName];
  if (metadata == null) return '';

  String msg = metadata.problemMessage;

  // Remove rule name prefix if present (e.g., "[rule_name] ...")
  final prefixMatch = RegExp(r'^\[[\w_]+\]\s*').firstMatch(msg);
  if (prefixMatch != null) {
    msg = msg.substring(prefixMatch.end);
  }

  // Truncate to reasonable length for YAML comment
  const maxLength = 60;
  if (msg.length > maxLength) {
    msg = '${msg.substring(0, maxLength - 3)}...';
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
  'insanity',
];

/// Map tier names to numeric IDs for user convenience.
const Map<String, int> tierIds = <String, int>{
  'essential': 1,
  'recommended': 2,
  'professional': 3,
  'comprehensive': 4,
  'insanity': 5,
};

/// Tier descriptions for display.
const Map<String, String> tierDescriptions = <String, String>{
  'essential':
      'Critical rules preventing crashes, security holes, memory leaks',
  'recommended': 'Essential + accessibility, performance patterns',
  'professional': 'Recommended + architecture, testing, documentation',
  'comprehensive': 'Professional + thorough coverage (recommended)',
  'insanity': 'All rules enabled (may have conflicts)',
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
    case RuleTier.insanity:
      return 'insanity';
    case RuleTier.stylistic:
      return 'stylistic';
  }
}

/// Maps tier string name to RuleTier enum.
RuleTier? _stringToTier(String tier) {
  switch (tier) {
    case 'essential':
      return RuleTier.essential;
    case 'recommended':
      return RuleTier.recommended;
    case 'professional':
      return RuleTier.professional;
    case 'comprehensive':
      return RuleTier.comprehensive;
    case 'insanity':
      return RuleTier.insanity;
    case 'stylistic':
      return RuleTier.stylistic;
    default:
      return null;
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
    case RuleTier.insanity:
      return 4;
    case RuleTier.stylistic:
      return -1; // Stylistic is opt-in, not part of tier progression
  }
}

/// Cache for rule tier mappings (built once from allSaropaRules).
Map<String, RuleTier>? _ruleTierCache;

/// Builds and returns the rule-to-tier mapping from rule classes.
///
/// Uses a two-phase approach for backwards compatibility during migration:
/// 1. If rule class has explicit tier override (not default), use that
/// 2. Otherwise, fall back to legacy tiers.dart assignments
///
/// This allows incremental migration from tiers.dart to rule classes.
Map<String, RuleTier> _getRuleTiers() {
  if (_ruleTierCache != null) return _ruleTierCache!;

  _ruleTierCache = <String, RuleTier>{};
  for (final LintRule rule in allSaropaRules) {
    if (rule is SaropaLintRule) {
      final String ruleName = rule.code.name;
      final RuleTier declaredTier = rule.tier;

      // Check if rule has explicit tier (not the default professional)
      // Rules with explicit tier override take precedence
      if (declaredTier != RuleTier.professional) {
        _ruleTierCache![ruleName] = declaredTier;
        continue;
      }

      // Fall back to legacy tiers.dart for unmigrated rules
      final RuleTier? legacyTier = _getLegacyTier(ruleName);
      _ruleTierCache![ruleName] = legacyTier ?? RuleTier.professional;
    }
  }
  return _ruleTierCache!;
}

/// Gets tier from legacy tiers.dart (for backwards compatibility).
RuleTier? _getLegacyTier(String ruleName) {
  if (legacy_tiers.stylisticRules.contains(ruleName)) {
    return RuleTier.stylistic;
  }
  if (legacy_tiers.essentialRules.contains(ruleName)) {
    return RuleTier.essential;
  }
  // Check tier sets in order (most restrictive first)
  if (legacy_tiers.insanityOnlyRules.contains(ruleName)) {
    return RuleTier.insanity;
  }
  if (legacy_tiers.comprehensiveOnlyRules.contains(ruleName)) {
    return RuleTier.comprehensive;
  }
  if (legacy_tiers.professionalOnlyRules.contains(ruleName)) {
    return RuleTier.professional;
  }
  if (legacy_tiers.recommendedOnlyRules.contains(ruleName)) {
    return RuleTier.recommended;
  }
  return null;
}

/// Returns all defined rule names (from rule classes).
Set<String> getAllDefinedRules() {
  return _getRuleTiers().keys.toSet();
}

/// Returns rules enabled for a given tier (cumulative).
/// Tiers are cumulative: higher tiers include all rules from lower tiers.
Set<String> getRulesForTier(String tierName) {
  final RuleTier? targetTier = _stringToTier(tierName);
  if (targetTier == null || targetTier == RuleTier.stylistic) {
    return <String>{};
  }

  final int targetIndex = _tierIndex(targetTier);
  final Map<String, RuleTier> ruleTiers = _getRuleTiers();

  return ruleTiers.entries
      .where((MapEntry<String, RuleTier> entry) {
        final RuleTier ruleTier = entry.value;
        // Stylistic rules are never included in tier progression
        if (ruleTier == RuleTier.stylistic) return false;
        // Include if rule's tier is at or below target tier
        return _tierIndex(ruleTier) <= targetIndex;
      })
      .map((MapEntry<String, RuleTier> entry) => entry.key)
      .toSet();
}

/// Returns all stylistic rules (opt-in only).
Set<String> get stylisticRules {
  final Map<String, RuleTier> ruleTiers = _getRuleTiers();
  return ruleTiers.entries
      .where((MapEntry<String, RuleTier> entry) =>
          entry.value == RuleTier.stylistic)
      .map((MapEntry<String, RuleTier> entry) => entry.key)
      .toSet();
}

/// Main entry point for the CLI tool.
Future<void> main(List<String> args) async {
  final CliArgs cliArgs = _parseArguments(args);
  if (cliArgs.showHelp) {
    _printUsage();
    return;
  }

  _logTerminal('');
  _logTerminal(
      '${_Colors.bold}╔══════════════════════════════════════════════════════════╗${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}║     ${_Colors.cyan}SAROPA LINTS${_Colors.reset}${_Colors.bold} Configuration Generator      v$_version  ║${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}╚══════════════════════════════════════════════════════════╝${_Colors.reset}');
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
  final Set<String> allRules = getAllDefinedRules();
  final Set<String> enabledRules = getRulesForTier(tier);
  final Set<String> disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in)
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;
  if (cliArgs.includeStylistic) {
    finalEnabled = finalEnabled.union(stylisticRules);
    finalDisabled = finalDisabled.difference(stylisticRules);
  } else {
    finalEnabled = finalEnabled.difference(stylisticRules);
    finalDisabled = finalDisabled.union(stylisticRules);
  }

  // Read existing config and extract user customizations
  final File outputFile = File(cliArgs.outputPath);
  final String absolutePath = outputFile.absolute.path;
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  _logTerminal('${_Colors.dim}Reading: $absolutePath${_Colors.reset}');

  if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();
    _logTerminal(
        '${_Colors.dim}  File size: ${existingContent.length} bytes${_Colors.reset}');

    if (!cliArgs.reset) {
      // Extract existing rule customizations from custom_lint.rules
      // Only rules in the USER CUSTOMIZATIONS section are preserved
      userCustomizations = _extractUserCustomizations(
        existingContent,
        allRules,
      );

      // Debug: show where customizations section was found
      final hasSection = existingContent.contains('USER CUSTOMIZATIONS');
      _logTerminal(
          '${_Colors.dim}  USER CUSTOMIZATIONS section: ${hasSection ? 'found' : 'not found'}${_Colors.reset}');

      if (userCustomizations.isNotEmpty) {
        // Warn if suspiciously many customizations (likely corrupted from buggy run)
        if (userCustomizations.length > 50) {
          _logTerminal('');
          _logTerminal(
              '${_Colors.red}⚠ WARNING: Found ${userCustomizations.length} user customizations!${_Colors.reset}');
          _logTerminal(
              '${_Colors.yellow}  This is unusually high and may indicate a corrupted config.${_Colors.reset}');
          _logTerminal(
              '${_Colors.yellow}  The USER CUSTOMIZATIONS section contains rules that should be in tier sections.${_Colors.reset}');
          _logTerminal(
              '${_Colors.yellow}  Consider running with --reset to start fresh:${_Colors.reset}');
          _logTerminal(
              '${_Colors.cyan}    dart run saropa_lints:init --tier ${cliArgs.tier} --reset${_Colors.reset}');
        } else {
          _logTerminal('');
          _logTerminal(
              '${_Colors.yellow}⚡ Preserving ${userCustomizations.length} user customizations:${_Colors.reset}');
          for (final MapEntry<String, bool> entry
              in userCustomizations.entries) {
            final color = entry.value ? _Colors.green : _Colors.red;
            _logTerminal(
                '  ${_Colors.dim}•${_Colors.reset} ${entry.key}: $color${entry.value}${_Colors.reset}');
          }
        }
      }
    } else {
      _logTerminal(
          '${_Colors.yellow}⚠ --reset specified: discarding user customizations${_Colors.reset}');
    }

    _logTerminal('');
    _logTerminal(
        '${_Colors.yellow}⚠ Warning: ${cliArgs.outputPath} already exists.${_Colors.reset}');
    _logTerminal(
        '${_Colors.dim}  Backing up to ${cliArgs.outputPath}.bak${_Colors.reset}');
    try {
      outputFile.copySync('${cliArgs.outputPath}.bak');
    } on Exception catch (e) {
      _logTerminal(_error('✗ Failed to backup file: $e'));
    }
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

  _logTerminal('');
  _logTerminal(
      '${_Colors.bold}┌─────────────────────────────────────────────────────────┐${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}│                     RULES SUMMARY                       │${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}└─────────────────────────────────────────────────────────┘${_Colors.reset}');
  _logTerminal('');
  _logTerminal(
      '  ${_Colors.bold}Total rules:${_Colors.reset} ${allRules.length}');
  _logTerminal('  ${_success('✓ Enabled:')} ${finalEnabled.length}');
  _logTerminal('  ${_error('✗ Disabled:')} ${finalDisabled.length}');
  _logTerminal(
      '  ${_warning('⚡ User customizations:')} ${userCustomizations.length}');
  _logTerminal('');

  // Enabled by tier breakdown
  _logTerminal('  ${_Colors.bold}Enabled by tier:${_Colors.reset}');
  for (final tierName in [
    'essential',
    'recommended',
    'professional',
    'comprehensive',
    'insanity'
  ]) {
    final count = enabledByTierCount[tierName] ?? 0;
    if (count > 0) {
      _logTerminal('    ${_tierColor(tierName)}: $count rules');
    }
  }
  final stylisticCount = enabledByTierCount['stylistic'] ?? 0;
  if (stylisticCount > 0 || cliArgs.includeStylistic) {
    _logTerminal(
        '    ${_tierColor('stylistic')}: $stylisticCount rules ${cliArgs.includeStylistic ? '(included)' : '(opt-in)'}');
  }
  _logTerminal('');

  // Enabled by severity breakdown
  _logTerminal('  ${_Colors.bold}Enabled by severity:${_Colors.reset}');
  _logTerminal(
      '    ${_Colors.red}ERROR:${_Colors.reset}   ${enabledBySeverity['ERROR']}');
  _logTerminal(
      '    ${_Colors.yellow}WARNING:${_Colors.reset} ${enabledBySeverity['WARNING']}');
  _logTerminal(
      '    ${_Colors.cyan}INFO:${_Colors.reset}    ${enabledBySeverity['INFO']}');
  _logTerminal('');

  if (!cliArgs.includeStylistic) {
    _logTerminal(
        '  ${_Colors.dim}ℹ Stylistic rules disabled by default. Use --stylistic to enable.${_Colors.reset}');
    _logTerminal('');
  }

  // Generate the new custom_lint section with proper formatting
  final String customLintYaml = _generateCustomLintYaml(
    tier: tier,
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
    includeStylistic: cliArgs.includeStylistic,
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

  try {
    outputFile.writeAsStringSync(newContent);
    _logTerminal('${_success('✓ Written to:')} ${cliArgs.outputPath}');
  } on Exception catch (e) {
    _logTerminal(_error('✗ Failed to write file: $e'));
    exitCode = 2;
    return;
  }

  _logTerminal('');
  _logTerminal(
      '${_Colors.bold}┌─────────────────────────────────────────────────────────┐${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}│                      NEXT STEPS                         │${_Colors.reset}');
  _logTerminal(
      '${_Colors.bold}└─────────────────────────────────────────────────────────┘${_Colors.reset}');
  _logTerminal('');
  _logTerminal(
      '  ${_Colors.cyan}1.${_Colors.reset} Review the generated configuration');
  _logTerminal(
      '  ${_Colors.cyan}2.${_Colors.reset} Run: ${_highlight('dart run custom_lint')}');
  _logTerminal(
      '  ${_Colors.cyan}3.${_Colors.reset} Customize rules as needed (change true to false)');
  _logTerminal('');
  _logTerminal(
      '${_Colors.dim}To change tiers later, run this command again with a different --tier${_Colors.reset}');
  _logTerminal('');
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
      '  #   5. insanity     - All rules (pedantic, highly opinionated)');
  buffer.writeln('  #   +  stylistic    - Opt-in only (formatting, ordering)');
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
      final String msg = _getShortProblemMessage(rule);
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
    RuleTier.insanity,
  ]) {
    final rules = enabledByTier[tierLevel]!..sort();
    if (rules.isEmpty) continue;

    final tierName = _tierToString(tierLevel).toUpperCase();
    final tierNum = _tierIndex(tierLevel) + 1;
    buffer.writeln('    #');
    buffer.writeln(
        '    # ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    buffer.writeln(
        '    # ┃  TIER $tierNum: $tierName${' ' * (60 - tierName.length)}┃');
    buffer.writeln('    # ┃  ${rules.length} rules enabled${' ' * 53}┃');
    buffer.writeln(
        '    # ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    buffer.writeln('    #');
    for (final String rule in rules) {
      final String msg = _getShortProblemMessage(rule);
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
        final String msg = _getShortProblemMessage(rule);
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
        final String msg = _getShortProblemMessage(rule);
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
    RuleTier.insanity,
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
      RuleTier.insanity,
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
        final String msg = _getShortProblemMessage(rule);
        final String severity = _getRuleSeverity(rule);
        buffer.writeln('    - $rule: false  # [$severity] $msg');
      }
      buffer.writeln('');
    }
  }

  return buffer.toString();
}

/// Generate a MASSIVE, unmissable section header for YAML.
///
/// Creates headers so big you can't possibly miss them when scrolling!
String _sectionHeader(String title, String char) {
  final String upperTitle = title.toUpperCase();

  // Different styles for different section types
  if (char == '=') {
    // ENABLED RULES - Double-line box, very prominent
    return '''
    #
    #
    # ████████████████████████████████████████████████████████████████████████████
    # ████████████████████████████████████████████████████████████████████████████
    # ████                                                                    ████
    # ████    ███████╗███╗   ██╗ █████╗ ██████╗ ██╗     ███████╗██████╗       ████
    # ████    ██╔════╝████╗  ██║██╔══██╗██╔══██╗██║     ██╔════╝██╔══██╗      ████
    # ████    █████╗  ██╔██╗ ██║███████║██████╔╝██║     █████╗  ██║  ██║      ████
    # ████    ██╔══╝  ██║╚██╗██║██╔══██║██╔══██╗██║     ██╔══╝  ██║  ██║      ████
    # ████    ███████╗██║ ╚████║██║  ██║██████╔╝███████╗███████╗██████╔╝      ████
    # ████    ╚══════╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚═════╝       ████
    # ████                                                                    ████
    # ████████████████████████████████████████████████████████████████████████████
    # ████████████████████████████████████████████████████████████████████████████
    #
    # ╔══════════════════════════════════════════════════════════════════════════╗
    # ║                                                                          ║
    # ║   ★ ★ ★ ★ ★ ★ ★ ★ ★   $upperTitle   ★ ★ ★ ★ ★ ★ ★ ★ ★
    # ║                                                                          ║
    # ╚══════════════════════════════════════════════════════════════════════════╝
    #
    #''';
  } else if (char == '~') {
    // STYLISTIC or USER CUSTOMIZATIONS - Wavy pattern
    return '''
    #
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #
    #     ╭─────────────────────────────────────────────────────────────────────╮
    #     │                                                                     │
    #     │    ◆ ◇ ◆ ◇ ◆   $upperTitle   ◆ ◇ ◆ ◇ ◆
    #     │                                                                     │
    #     ╰─────────────────────────────────────────────────────────────────────╯
    #
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    # ~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*~*
    # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    #
    #''';
  } else {
    // DISABLED RULES - Dashed pattern (less prominent)
    return '''
    #
    #
    # ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
    # ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
    #
    #     ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐
    #
    #         ○ ● ○ ● ○   $upperTitle   ○ ● ○ ● ○
    #
    #     └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
    #
    # ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
    # ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄
    #
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
  dart run saropa_lints:init --tier insanity --stylistic
  dart run saropa_lints:init --dry-run

After generating, run `dart run custom_lint` to verify.
''');
}
