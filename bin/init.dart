#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// CLI tool to generate analysis_options.yaml with explicit rule configuration.
///
/// Usage:
///   dart run saropa_lints:init [options]
///
/// This tool generates explicit `- rule_name: true/false` for ALL saropa_lints
/// rules, bypassing custom_lint's limited plugin configuration support.
///
/// The tier system works correctly in the Dart code, but custom_lint doesn't
/// reliably pass plugin config (like `tier: comprehensive`) to plugins.
/// This tool solves that by generating explicit rule lists.
library;

import 'dart:io';

import 'package:saropa_lints/src/tiers.dart';

/// All available tiers in order of strictness.
const List<String> tierOrder = [
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'insanity',
];

/// Map tier names to numeric IDs for user convenience.
const Map<String, int> tierIds = {
  'essential': 1,
  'recommended': 2,
  'professional': 3,
  'comprehensive': 4,
  'insanity': 5,
};

/// Tier descriptions for display.
const Map<String, String> tierDescriptions = {
  'essential': 'Critical rules preventing crashes, security holes, memory leaks',
  'recommended': 'Essential + accessibility, performance patterns',
  'professional': 'Recommended + architecture, testing, documentation',
  'comprehensive': 'Professional + thorough coverage (recommended)',
  'insanity': 'All rules enabled (may have conflicts)',
};

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Parse arguments
  final dryRun = args.contains('--dry-run');
  final includeStylistic = args.contains('--stylistic');

  // Parse output file option
  var outputPath = 'analysis_options.yaml';
  final outputIndex = args.indexOf('--output');
  if (outputIndex != -1 && outputIndex + 1 < args.length) {
    outputPath = args[outputIndex + 1];
  }
  final outputIndexShort = args.indexOf('-o');
  if (outputIndexShort != -1 && outputIndexShort + 1 < args.length) {
    outputPath = args[outputIndexShort + 1];
  }

  // Parse tier option
  String? requestedTier;
  final tierIndex = args.indexOf('--tier');
  if (tierIndex != -1 && tierIndex + 1 < args.length) {
    requestedTier = args[tierIndex + 1];
  }
  final tierIndexShort = args.indexOf('-t');
  if (tierIndexShort != -1 && tierIndexShort + 1 < args.length) {
    requestedTier = args[tierIndexShort + 1];
  }

  print('');
  print('Saropa Lints Configuration Generator');
  print('=====================================');
  print('');

  // Resolve tier (handle numeric input)
  final tier = _resolveTier(requestedTier);
  if (tier == null) {
    stderr.writeln('Error: Invalid tier "$requestedTier"');
    stderr.writeln('');
    stderr.writeln('Valid tiers:');
    for (final entry in tierIds.entries) {
      stderr.writeln('  ${entry.value} or ${entry.key}');
    }
    exitCode = 1;
    return;
  }

  print('Tier: $tier (${tierIds[tier]})');
  print('Description: ${tierDescriptions[tier]}');
  print('');

  // Get all rules
  final allRules = _getAllRules();
  final enabledRules = getRulesForTier(tier);
  final disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;

  if (includeStylistic) {
    finalEnabled = finalEnabled.union(stylisticRules);
    finalDisabled = finalDisabled.difference(stylisticRules);
  } else {
    // Remove stylistic from enabled (they're opt-in)
    finalEnabled = finalEnabled.difference(stylisticRules);
    finalDisabled = finalDisabled.union(stylisticRules);
  }

  print('Rules summary:');
  print('  Enabled: ${finalEnabled.length}');
  print('  Disabled: ${finalDisabled.length}');
  print('  Total: ${allRules.length}');
  if (!includeStylistic) {
    print('  (Stylistic rules disabled by default - use --stylistic to enable)');
  }
  print('');

  // Generate YAML content
  final yamlContent = _generateYaml(
    tier: tier,
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    includeStylistic: includeStylistic,
  );

  if (dryRun) {
    print('[DRY RUN] Would write to: $outputPath');
    print('');
    print('Preview (first 50 lines):');
    print('-' * 40);
    final lines = yamlContent.split('\n');
    for (final line in lines.take(50)) {
      print(line);
    }
    if (lines.length > 50) {
      print('... (${lines.length - 50} more lines)');
    }
    return;
  }

  // Write file
  final outputFile = File(outputPath);

  // Check for existing file
  if (outputFile.existsSync()) {
    print('Warning: $outputPath already exists.');
    print('Backing up to ${outputPath}.bak');
    outputFile.copySync('${outputPath}.bak');
  }

  outputFile.writeAsStringSync(yamlContent);
  print('Written to: $outputPath');
  print('');
  print('Next steps:');
  print('  1. Review the generated configuration');
  print('  2. Run: dart run custom_lint');
  print('  3. Customize rules as needed (change true to false)');
  print('');
  print('To change tiers later, run this command again with a different --tier');
}

/// Resolve tier from name or number.
String? _resolveTier(String? input) {
  if (input == null) {
    // Default to comprehensive
    return 'comprehensive';
  }

  // Try as number first
  final numericTier = int.tryParse(input);
  if (numericTier != null) {
    for (final entry in tierIds.entries) {
      if (entry.value == numericTier) {
        return entry.key;
      }
    }
    return null;
  }

  // Try as name
  final normalized = input.toLowerCase();
  if (tierIds.containsKey(normalized)) {
    return normalized;
  }

  return null;
}

/// Get all rules from all tiers.
Set<String> _getAllRules() {
  return essentialRules
      .union(recommendedOnlyRules)
      .union(professionalOnlyRules)
      .union(comprehensiveOnlyRules)
      .union(insanityOnlyRules)
      .union(stylisticRules);
}

/// Generate YAML configuration content.
String _generateYaml({
  required String tier,
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required bool includeStylistic,
}) {
  final buffer = StringBuffer();

  // Header
  buffer.writeln('# SAROPA LINTS CONFIGURATION');
  buffer.writeln('# Generated by: dart run saropa_lints:init --tier $tier');
  buffer.writeln('# Date: ${DateTime.now().toIso8601String().split('T')[0]}');
  buffer.writeln('#');
  buffer.writeln('# Tier: $tier (${enabledRules.length} of ${enabledRules.length + disabledRules.length} rules enabled)');
  buffer.writeln('#');
  buffer.writeln('# This file contains explicit true/false for every rule.');
  buffer.writeln('# To customize: change "true" to "false" (or vice versa).');
  buffer.writeln('# To change tiers: re-run "dart run saropa_lints:init --tier <name>"');
  buffer.writeln('#');
  buffer.writeln('# Tiers:');
  for (final tierName in tierOrder) {
    final id = tierIds[tierName];
    final desc = tierDescriptions[tierName];
    final marker = tierName == tier ? ' <-- current' : '';
    buffer.writeln('#   $id. $tierName: $desc$marker');
  }
  buffer.writeln('');

  // Analyzer section (optional - for dart analyze)
  buffer.writeln('# Optional: Include recommended Dart lints for dart analyze');
  buffer.writeln('# include: package:lints/recommended.yaml');
  buffer.writeln('');

  // custom_lint section
  buffer.writeln('custom_lint:');
  buffer.writeln('  rules:');

  // Write enabled rules
  buffer.writeln('    # **************************************************************************');
  buffer.writeln('    # ***  ENABLED RULES ($tier tier)  *****************************************');
  buffer.writeln('    # **************************************************************************');

  final sortedEnabled = enabledRules.toList()..sort();
  for (final rule in sortedEnabled) {
    buffer.writeln('    - $rule: true');
  }

  buffer.writeln('');
  buffer.writeln('    # **************************************************************************');
  buffer.writeln('    # ***  DISABLED RULES (enable manually if needed)  ************************');
  buffer.writeln('    # **************************************************************************');

  // Separate stylistic rules
  final disabledStylistic = disabledRules.intersection(stylisticRules);
  final disabledOther = disabledRules.difference(stylisticRules);

  if (disabledOther.isNotEmpty) {
    buffer.writeln('');
    buffer.writeln('    # --- Higher tier rules (not in $tier) ---');
    final sortedDisabledOther = disabledOther.toList()..sort();
    for (final rule in sortedDisabledOther) {
      buffer.writeln('    - $rule: false');
    }
  }

  if (disabledStylistic.isNotEmpty && !includeStylistic) {
    buffer.writeln('');
    buffer.writeln('    # --- Stylistic rules (opinionated, opt-in) ---');
    buffer.writeln('    # These are formatting/style preferences. Enable with --stylistic flag');
    buffer.writeln('    # or set individual rules to true below.');
    final sortedStylistic = disabledStylistic.toList()..sort();
    for (final rule in sortedStylistic) {
      buffer.writeln('    - $rule: false');
    }
  }

  buffer.writeln('');

  return buffer.toString();
}

void _printUsage() {
  print('');
  print('Saropa Lints Configuration Generator');
  print('');
  print('Generates analysis_options.yaml with explicit rule configuration,');
  print('bypassing custom_lint\'s limited plugin config support.');
  print('');
  print('Usage: dart run saropa_lints:init [options]');
  print('');
  print('Options:');
  print('  -t, --tier <tier>     Tier level (1-5 or name, default: comprehensive)');
  print('  -o, --output <file>   Output file (default: analysis_options.yaml)');
  print('  --stylistic           Include stylistic rules (opinionated, off by default)');
  print('  --dry-run             Preview output without writing');
  print('  -h, --help            Show this help message');
  print('');
  print('Tiers:');
  for (final tierName in tierOrder) {
    final id = tierIds[tierName];
    final desc = tierDescriptions[tierName];
    print('  $id. $tierName');
    print('     $desc');
  }
  print('');
  print('Examples:');
  print('  dart run saropa_lints:init');
  print('  dart run saropa_lints:init --tier comprehensive');
  print('  dart run saropa_lints:init --tier 4');
  print('  dart run saropa_lints:init --tier essential --output custom.yaml');
  print('  dart run saropa_lints:init --tier insanity --stylistic');
  print('  dart run saropa_lints:init --dry-run');
  print('');
  print('After generating, run `dart run custom_lint` to verify.');
}
