#!/usr/bin/env dart
// ignore_for_file: avoid_print

library;

import 'package:yaml/yaml.dart' as yaml;
import 'package:json2yaml/json2yaml.dart' as json2yaml;

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
  // Show help if requested
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  // Parse arguments
  final dryRun = args.contains('--dry-run');
  final includeStylistic = args.contains('--stylistic');
  final noPager = args.contains('--no-pager'); // New: disables pagination in dry-run

  // Parse output file option (last one wins)
  var outputPath = 'analysis_options.yaml';
  final outputFlags = <int, String>{};
  final outputIndex = args.indexOf('--output');
  if (outputIndex != -1 && outputIndex + 1 < args.length) {
    outputFlags[outputIndex] = args[outputIndex + 1];
  }
  final outputIndexShort = args.indexOf('-o');
  if (outputIndexShort != -1 && outputIndexShort + 1 < args.length) {
    outputFlags[outputIndexShort] = args[outputIndexShort + 1];
  }
  if (outputFlags.isNotEmpty) {
    // Use the value from the last flag occurrence
    final last = outputFlags.entries.reduce((a, b) => a.key > b.key ? a : b);
    outputPath = last.value;
  }

  // Parse tier option (by name or number)
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

  // Get all rules (from all tiers and stylistic)
  final allRules = _getAllRules();
  final enabledRules = getRulesForTier(tier);
  final disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in)
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;
  if (includeStylistic) {
    finalEnabled = finalEnabled.union(stylisticRules);
    finalDisabled = finalDisabled.difference(stylisticRules);
  } else {
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

  // Only update custom_lint section, preserve other config
  Map<String, dynamic> newCustomLintSection = {'rules': {}};
  for (final rule in finalEnabled) {
    newCustomLintSection['rules'][rule] = true;
  }
  for (final rule in finalDisabled) {
    newCustomLintSection['rules'][rule] = false;
  }

  Map<String, dynamic> mergedConfig = {};
  final outputFile = File(outputPath);
  bool fileExisted = outputFile.existsSync();
  if (fileExisted) {
    print('Warning: $outputPath already exists.');
    print('Backing up to ${outputPath}.bak');
    outputFile.copySync('${outputPath}.bak');
    final existingContent = outputFile.readAsStringSync();
    try {
      // Try to parse existing YAML config
      final doc = yaml.loadYaml(existingContent);
      if (doc is Map) {
        mergedConfig = Map<String, dynamic>.from(doc);
      }
    } catch (e) {
      stderr.writeln('Error: Failed to parse existing YAML: $e');
      stderr.writeln('Proceeding with a fresh config.');
      mergedConfig = {};
    }
  }

  // Overwrite only the custom_lint section
  mergedConfig['custom_lint'] = newCustomLintSection;

  // Add header as a comment (not preserved by YAML serialization)
  final header = [
    '# SAROPA LINTS CONFIGURATION',
    '# Generated by: dart run saropa_lints:init --tier $tier',
    '# Date: ${DateTime.now().toIso8601String().split('T')[0]}',
    '#',
    '# Tier: $tier (${finalEnabled.length} of ${finalEnabled.length + finalDisabled.length} rules enabled)',
    '#',
    '# This file contains explicit true/false for every rule.',
    '# To customize: change "true" to "false" (or vice versa).',
    '# To change tiers: re-run "dart run saropa_lints:init --tier <name>"',
    '#',
    '# Tiers:',
    ...tierOrder.map((tierName) {
      final id = tierIds[tierName];
      final desc = tierDescriptions[tierName];
      final marker = tierName == tier ? ' <-- current' : '';
      return '#   $id. $tierName: $desc$marker';
    }),
    ''
  ].join('\n');

  final yamlContent = header + '\n' + json2yaml.json2yaml(mergedConfig);

  if (dryRun) {
    print('[DRY RUN] Would write to: $outputPath');
    print('');
    // Print summary of enabled/disabled rules by tier
    print('Enabled rules by tier:');
    for (final t in tierOrder) {
      final rules = getRulesForTier(t);
      print('  ${tierIds[t]}. $t: ${rules.length} rules');
    }
    print(
        'Stylistic rules: ${includeStylistic ? stylisticRules.length : 0} ${includeStylistic ? "(included)" : "(not included)"}');
    print('');
    // Paginate preview if output is long, unless --no-pager or not a terminal
    final lines = yamlContent.split('\n');
    const pageSize = 50;
    int page = 0;
    final isTerminal = stdin.hasTerminal;
    final usePager = !noPager && isTerminal;
    while (page * pageSize < lines.length) {
      final start = page * pageSize;
      final end = ((page + 1) * pageSize).clamp(0, lines.length);
      print('Preview (lines ${start + 1}-${end} of ${lines.length}):');
      print('-' * 40);
      for (final line in lines.sublist(start, end)) {
        print(line);
      }
      if (end < lines.length && usePager) {
        print('--- Press Enter to continue, Ctrl+C to quit ---');
        stdin.readLineSync();
      }
      page++;
    }
    return;
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
  print(
      '  -o, --output <file>   Output file (default: analysis_options.yaml). If both --output and -o are provided, the last one wins.');
  print(
      '  --no-pager            Print full preview in dry-run mode without pausing (for CI/non-interactive use).');
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
