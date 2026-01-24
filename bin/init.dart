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

import 'package:saropa_lints/src/tiers.dart';

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

/// Main entry point for the CLI tool.
Future<void> main(List<String> args) async {
  final CliArgs cliArgs = _parseArguments(args);
  if (cliArgs.showHelp) {
    _printUsage();
    return;
  }

  _logTerminal('Saropa Lints Configuration Generator');
  _logTerminal('=====================================');
  _logTerminal('');

  // Resolve tier (handle numeric input)
  final String? tier = _resolveTier(cliArgs.tier);
  if (tier == null) {
    stderr.writeln('Error: Invalid tier "${cliArgs.tier}"');
    stderr.writeln('');
    stderr.writeln('Valid tiers:');
    for (final MapEntry<String, int> entry in tierIds.entries) {
      stderr.writeln('  ${entry.value} or ${entry.key}');
    }
    exitCode = 1;
    return;
  }

  _logTerminal('Tier: $tier (${tierIds[tier]})');
  _logTerminal('Description: ${tierDescriptions[tier]}');
  _logTerminal('');

  // Get all rules (from all tiers and stylistic)
  final Set<String> allRules = _getAllRules();
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
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();

    if (!cliArgs.reset) {
      // Extract existing rule customizations from custom_lint.rules
      userCustomizations = _extractUserCustomizations(existingContent);
      if (userCustomizations.isNotEmpty) {
        _logTerminal(
            'Preserving ${userCustomizations.length} user customizations');
      }
    } else {
      _logTerminal('--reset specified: discarding user customizations');
    }

    _logTerminal('Warning: ${cliArgs.outputPath} already exists.');
    _logTerminal('Backing up to ${cliArgs.outputPath}.bak');
    try {
      outputFile.copySync('${cliArgs.outputPath}.bak');
    } on Exception catch (e) {
      stderr.writeln('Error: Failed to backup file: $e');
    }
  }

  _logTerminal('');
  _logTerminal('Rules summary:');
  _logTerminal('  Enabled by tier: ${finalEnabled.length}');
  _logTerminal('  Disabled by tier: ${finalDisabled.length}');
  _logTerminal('  User customizations: ${userCustomizations.length}');
  _logTerminal('  Total: ${allRules.length}');
  if (!cliArgs.includeStylistic) {
    _logTerminal(
        '  (Stylistic rules disabled by default - use --stylistic to enable)');
  }
  _logTerminal('');

  // Generate the new custom_lint section with proper formatting
  final String customLintYaml = _generateCustomLintYaml(
    tier: tier,
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
  );

  // Replace custom_lint section in existing content, preserving everything else
  final String newContent =
      _replaceCustomLintSection(existingContent, customLintYaml);

  if (cliArgs.dryRun) {
    _logTerminal('[DRY RUN] Would write to: ${cliArgs.outputPath}');
    _logTerminal('');
    _logTerminal('Enabled rules by tier:');
    for (final String t in tierOrder) {
      final Set<String> rules = getRulesForTier(t);
      _logTerminal('  ${tierIds[t]}. $t: ${rules.length} rules');
    }
    _logTerminal(
        'Stylistic rules: ${cliArgs.includeStylistic ? stylisticRules.length : 0} ${cliArgs.includeStylistic ? "(included)" : "(not included)"}');
    _logTerminal('');

    // Show preview of custom_lint section only
    final List<String> lines = customLintYaml.split('\n');
    const int previewLines = 80;
    _logTerminal(
        'Preview of custom_lint section (first $previewLines lines of ${lines.length}):');
    _logTerminal('-' * 60);
    for (int i = 0; i < previewLines && i < lines.length; i++) {
      _logTerminal(lines[i]);
    }
    if (lines.length > previewLines) {
      _logTerminal('... (${lines.length - previewLines} more lines)');
    }
    return;
  }

  try {
    outputFile.writeAsStringSync(newContent);
    _logTerminal('Written to: ${cliArgs.outputPath}');
  } on Exception catch (e) {
    stderr.writeln('Error: Failed to write file: $e');
    exitCode = 2;
    return;
  }

  _logTerminal('');
  _logTerminal('Next steps:');
  _logTerminal('  1. Review the generated configuration');
  _logTerminal('  2. Run: dart run custom_lint');
  _logTerminal('  3. Customize rules as needed (change true to false)');
  _logTerminal('');
  _logTerminal(
      'To change tiers later, run this command again with a different --tier');
}

/// Extract existing user customizations from custom_lint.rules section.
Map<String, bool> _extractUserCustomizations(String yamlContent) {
  final Map<String, bool> customizations = <String, bool>{};

  // Find custom_lint: section
  final RegExp customLintPattern =
      RegExp(r'^custom_lint:\s*$', multiLine: true);
  final Match? customLintMatch = customLintPattern.firstMatch(yamlContent);
  if (customLintMatch == null) {
    return customizations;
  }

  // Extract rules from the custom_lint section
  // Match lines like "    - rule_name: true" or "    - rule_name: false"
  final RegExp rulePattern =
      RegExp(r'^\s+-\s+(\w+):\s*(true|false)', multiLine: true);

  final String afterCustomLint = yamlContent.substring(customLintMatch.end);

  // Stop at next top-level section (line starting without indentation)
  final RegExp nextSectionPattern = RegExp(r'^\w+:', multiLine: true);
  final Match? nextSection = nextSectionPattern.firstMatch(afterCustomLint);
  final String customLintSection = nextSection != null
      ? afterCustomLint.substring(0, nextSection.start)
      : afterCustomLint;

  for (final Match match in rulePattern.allMatches(customLintSection)) {
    final String ruleName = match.group(1)!;
    final bool enabled = match.group(2) == 'true';
    customizations[ruleName] = enabled;
  }

  return customizations;
}

/// Generate the custom_lint YAML section with proper formatting.
String _generateCustomLintYaml({
  required String tier,
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> allRules,
}) {
  final StringBuffer buffer = StringBuffer();

  buffer.writeln('custom_lint:');
  buffer
      .writeln('  # Regenerate with: dart run saropa_lints:init --tier $tier');
  buffer.writeln(
      '  # Tier: $tier (${enabledRules.length} of ${allRules.length} rules enabled)');
  buffer
      .writeln('  # User customizations are preserved unless --reset is used');
  buffer.writeln('');
  buffer.writeln('  rules:');

  // Section 1: User customizations (always at top, preserved)
  if (userCustomizations.isNotEmpty) {
    buffer.writeln(_sectionHeader('USER CUSTOMIZATIONS', '~'));
    buffer.writeln(
        '    # These rules have been manually configured and will be preserved');
    buffer.writeln(
        '    # when regenerating. Use --reset to discard these customizations.');

    final List<String> sortedCustomizations = userCustomizations.keys.toList()
      ..sort();
    for (final String rule in sortedCustomizations) {
      final bool enabled = userCustomizations[rule]!;
      buffer.writeln('    - $rule: $enabled');
    }
    buffer.writeln('');
  }

  // Section 2: Enabled rules (by tier)
  buffer.writeln(_sectionHeader('ENABLED RULES ($tier tier)', '*'));

  // Filter out user-customized rules from the tier lists
  final Set<String> tierEnabledNotCustomized =
      enabledRules.difference(userCustomizations.keys.toSet());
  final List<String> sortedEnabled = tierEnabledNotCustomized.toList()..sort();

  for (final String rule in sortedEnabled) {
    buffer.writeln('    - $rule: true');
  }
  buffer.writeln('');

  // Section 3: Disabled rules (not in tier, excluding user customizations)
  buffer.writeln(_sectionHeader('DISABLED RULES (below $tier tier)', '-'));

  final Set<String> tierDisabledNotCustomized =
      disabledRules.difference(userCustomizations.keys.toSet());
  final List<String> sortedDisabled = tierDisabledNotCustomized.toList()
    ..sort();

  for (final String rule in sortedDisabled) {
    buffer.writeln('    - $rule: false');
  }

  return buffer.toString();
}

/// Generate a section header comment with centered title.
///
/// Creates a visually distinct section separator like:
/// ```
/// # ************************************************************************
/// # *                      ENABLED RULES (tier name)                       *
/// # ************************************************************************
/// ```
///
/// Handles long titles gracefully by truncating if necessary.
String _sectionHeader(String title, String char) {
  const int width = 76;
  final String line = char * width;

  // Handle titles that are too long (>72 chars leaves room for padding)
  final String safeTitle = title.length > 72 ? title.substring(0, 72) : title;

  // Calculate padding for centering (width - title - 2 chars for delimiters)
  final int totalPadding = width - safeTitle.length - 2;
  final int leftPadding = totalPadding ~/ 2;
  final int rightPadding = totalPadding - leftPadding; // Handles odd lengths

  final String paddedTitle =
      '$char${' ' * leftPadding}$safeTitle${' ' * rightPadding}$char';

  return '''
    # $line
    # $paddedTitle
    # $line''';
}

/// Replace the custom_lint section in existing content, preserving everything else.
String _replaceCustomLintSection(String existingContent, String newCustomLint) {
  if (existingContent.isEmpty) {
    return newCustomLint;
  }

  // Find custom_lint: section
  final RegExp customLintPattern =
      RegExp(r'^custom_lint:\s*$', multiLine: true);
  final Match? customLintMatch = customLintPattern.firstMatch(existingContent);

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
  final RegExp nextSectionPattern = RegExp(r'^\w+:', multiLine: true);
  final Match? nextSection =
      nextSectionPattern.firstMatch(afterCustomLintStart);

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

Set<String> _getAllRules() {
  return essentialRules
      .union(recommendedOnlyRules)
      .union(professionalOnlyRules)
      .union(comprehensiveOnlyRules)
      .union(insanityOnlyRules)
      .union(stylisticRules);
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
