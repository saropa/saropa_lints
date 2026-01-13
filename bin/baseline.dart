#!/usr/bin/env dart
// ignore_for_file: avoid_print

/// CLI tool to generate and manage baseline files for saropa_lints.
///
/// Usage:
///   dart run saropa_lints:baseline [options]
///
/// This tool:
/// 1. Runs `dart run custom_lint` on your project
/// 2. Parses the output to extract violations
/// 3. Generates a baseline JSON file
/// 4. Optionally updates analysis_options.yaml
library;

import 'dart:convert';
import 'dart:io';

import 'package:saropa_lints/src/baseline/baseline_file.dart';

/// Represents a parsed violation from custom_lint output.
class Violation {
  Violation({
    required this.file,
    required this.line,
    required this.column,
    required this.rule,
    required this.message,
  });

  final String file;
  final int line;
  final int column;
  final String rule;
  final String message;
}

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final dryRun = args.contains('--dry-run');
  final update = args.contains('--update');
  final skipConfig = args.contains('--skip-config');

  // Parse output file option
  var outputPath = 'saropa_baseline.json';
  final outputIndex = args.indexOf('--output');
  if (outputIndex != -1 && outputIndex + 1 < args.length) {
    outputPath = args[outputIndex + 1];
  }
  final outputIndexShort = args.indexOf('-o');
  if (outputIndexShort != -1 && outputIndexShort + 1 < args.length) {
    outputPath = args[outputIndexShort + 1];
  }

  // Parse working directory
  var workingDir = '.';
  for (final arg in args) {
    if (!arg.startsWith('-') &&
        arg != outputPath &&
        args.indexOf(arg) != outputIndex + 1 &&
        args.indexOf(arg) != outputIndexShort + 1) {
      workingDir = arg;
      break;
    }
  }

  print('Saropa Lints Baseline Generator');
  print('================================');
  print('');

  // Check if we're updating an existing baseline
  BaselineFile? existingBaseline;
  if (update) {
    existingBaseline = BaselineFile.load(outputPath);
    if (existingBaseline != null) {
      print(
          'Updating existing baseline (${existingBaseline.totalViolations} violations)');
    } else {
      print('No existing baseline found, creating new one');
    }
  }

  print('Running lint analysis...');
  print('');

  // Run custom_lint
  final result = await Process.run(
    'dart',
    ['run', 'custom_lint'],
    workingDirectory: workingDir,
    runInShell: true,
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  // Check for errors (but ignore "Analyzing" messages)
  if (result.exitCode != 0 && !stderr.contains('Analyzing')) {
    if (stderr.isNotEmpty) {
      print('Warning: custom_lint returned errors:');
      print(stderr);
    }
  }

  // Parse violations
  final violations = _parseViolations(output);

  if (violations.isEmpty) {
    print('No violations found!');
    print('');
    print('Your codebase is already clean - no baseline needed.');
    return;
  }

  print('Found ${violations.length} violation(s)');
  print('');

  // Build baseline data structure
  final baselineData = <String, Map<String, List<int>>>{};

  for (final v in violations) {
    final fileViolations = baselineData.putIfAbsent(v.file, () => {});
    final ruleLines = fileViolations.putIfAbsent(v.rule, () => []);
    if (!ruleLines.contains(v.line)) {
      ruleLines.add(v.line);
    }
  }

  // Sort line numbers for consistent output
  for (final fileViolations in baselineData.values) {
    for (final ruleLines in fileViolations.values) {
      ruleLines.sort();
    }
  }

  final baseline = BaselineFile(violations: baselineData);

  // Handle --update: show what was fixed
  if (update && existingBaseline != null) {
    final oldCount = existingBaseline.totalViolations;
    final newCount = baseline.totalViolations;
    final fixed = oldCount - newCount;

    print('Baseline Update Summary:');
    print('  Previous: $oldCount violations');
    print('  Current:  $newCount violations');
    if (fixed > 0) {
      print('  Fixed:    $fixed violations removed!');
    } else if (fixed < 0) {
      print('  New:      ${-fixed} violations added');
    } else {
      print('  No change');
    }
    print('');
  }

  // Show summary
  print('Baseline Summary:');
  print('  Files: ${baseline.fileCount}');
  print('  Violations: ${baseline.totalViolations}');
  print('  Rules: ${baseline.rules.length}');
  print('');

  // Show top rules
  final ruleCounts = <String, int>{};
  for (final fileViolations in baselineData.values) {
    for (final entry in fileViolations.entries) {
      ruleCounts[entry.key] = (ruleCounts[entry.key] ?? 0) + entry.value.length;
    }
  }
  final topRules = ruleCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('Top rules by count:');
  for (final entry in topRules.take(5)) {
    print('  ${entry.key}: ${entry.value}');
  }
  print('');

  if (dryRun) {
    print('[DRY RUN] Would write baseline to: $outputPath');
    print('[DRY RUN] Would update analysis_options.yaml');
    print('');
    print('Baseline content preview:');
    final encoder = const JsonEncoder.withIndent('  ');
    final preview = encoder.convert(baseline.toJson());
    // Show first 20 lines
    final lines = preview.split('\n');
    for (final line in lines.take(20)) {
      print('  $line');
    }
    if (lines.length > 20) {
      print('  ... (${lines.length - 20} more lines)');
    }
    return;
  }

  // Write baseline file
  baseline.save(outputPath);
  print('Baseline written to: $outputPath');

  // Update analysis_options.yaml
  if (!skipConfig) {
    final updated = await _updateAnalysisOptions(outputPath);
    if (updated) {
      print('Updated analysis_options.yaml with baseline configuration');
    }
  }

  print('');
  print('Done! Run `dart run custom_lint` again to see clean output.');
  print('');
  print('As you fix violations, run `dart run saropa_lints:baseline --update`');
  print('to remove fixed items from the baseline.');
}

/// Parse custom_lint output into violations.
List<Violation> _parseViolations(String output) {
  final violations = <Violation>[];

  // Pattern: file.dart:line:col - rule_name - message
  // Or: file.dart:line:col - rule_name . message (bullet point separator)
  final pattern = RegExp(
    r'^(.+?):(\d+):(\d+)\s+-\s+(\w+)\s+[-.\u2022]\s+(.+)$',
    multiLine: true,
  );

  for (final match in pattern.allMatches(output)) {
    final file = match.group(1)!;
    final line = int.tryParse(match.group(2)!) ?? 0;
    final column = int.tryParse(match.group(3)!) ?? 0;
    final rule = match.group(4)!;
    final message = match.group(5)!;

    violations.add(Violation(
      file: file,
      line: line,
      column: column,
      rule: rule,
      message: message,
    ));
  }

  return violations;
}

/// Update analysis_options.yaml to include baseline configuration.
Future<bool> _updateAnalysisOptions(String baselinePath) async {
  final file = File('analysis_options.yaml');

  if (!file.existsSync()) {
    print('Note: analysis_options.yaml not found, skipping config update');
    return false;
  }

  var content = file.readAsStringSync();

  // Check if baseline is already configured
  if (content.contains('baseline:') && content.contains('file:')) {
    print('Note: baseline already configured in analysis_options.yaml');
    return false;
  }

  // Find the saropa_lints section and add baseline config
  // Look for pattern like:
  //   saropa_lints:
  //     tier: recommended
  final saropaPattern = RegExp(
    r'(\s*saropa_lints:\s*\n\s*tier:\s*\w+)',
    multiLine: true,
  );

  final match = saropaPattern.firstMatch(content);
  if (match != null) {
    // Add baseline config after tier
    final indent = _detectIndent(content, match.start);
    final baselineConfig =
        '\n$indent  baseline:\n$indent    file: "$baselinePath"';
    content = content.replaceFirst(
      match.group(0)!,
      '${match.group(0)}$baselineConfig',
    );
    file.writeAsStringSync(content);
    return true;
  }

  // If no saropa_lints section found, check for custom_lint section
  final customLintPattern = RegExp(
    r'(custom_lint:\s*\n)',
    multiLine: true,
  );

  final customMatch = customLintPattern.firstMatch(content);
  if (customMatch != null) {
    // Add saropa_lints with baseline after custom_lint:
    final baselineConfig =
        '  saropa_lints:\n    baseline:\n      file: "$baselinePath"\n';
    content = content.replaceFirst(
      customMatch.group(0)!,
      '${customMatch.group(0)}$baselineConfig',
    );
    file.writeAsStringSync(content);
    return true;
  }

  print('Note: Could not find saropa_lints section in analysis_options.yaml');
  print('Add this manually:');
  print('');
  print('custom_lint:');
  print('  saropa_lints:');
  print('    baseline:');
  print('      file: "$baselinePath"');
  return false;
}

/// Detect the indentation used in the YAML file.
String _detectIndent(String content, int position) {
  // Find the start of the line
  var lineStart = position;
  while (lineStart > 0 && content[lineStart - 1] != '\n') {
    lineStart--;
  }

  // Count leading spaces
  var spaces = 0;
  while (lineStart + spaces < content.length &&
      content[lineStart + spaces] == ' ') {
    spaces++;
  }

  return ' ' * spaces;
}

void _printUsage() {
  print('Saropa Lints Baseline Generator');
  print('');
  print('Usage: dart run saropa_lints:baseline [options] [path]');
  print('');
  print('Generates a baseline file that suppresses existing lint violations,');
  print('allowing you to adopt linting in brownfield projects without being');
  print('overwhelmed by legacy issues.');
  print('');
  print('Options:');
  print(
      '  -o, --output <path>   Output file path (default: saropa_baseline.json)');
  print(
      '  --update              Update existing baseline, removing fixed violations');
  print(
      '  --dry-run             Show what would be done without making changes');
  print('  --skip-config         Skip updating analysis_options.yaml');
  print('  -h, --help            Show this help message');
  print('');
  print('Examples:');
  print('  dart run saropa_lints:baseline');
  print('  dart run saropa_lints:baseline --output .baseline.json');
  print('  dart run saropa_lints:baseline --update');
  print('  dart run saropa_lints:baseline --dry-run');
  print('  dart run saropa_lints:baseline ./my_project');
  print('');
  print('After generating a baseline, run `dart run custom_lint` again.');
  print('Old violations will be hidden, but new ones will still be reported.');
}
