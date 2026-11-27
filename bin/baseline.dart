#!/usr/bin/env dart

/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Dart CLI entrypoint for saropa_lints tooling.
///
/// Saropa custom lints: rules register in `lib/src/rules/all_rules.dart`
/// and tiers in `lib/src/tiers.dart` where applicable; see `plans/PLAN_comment_coverage.md`.

// ignore_for_file: avoid_print

/// CLI tool to generate and manage baseline files for saropa_lints.
///
/// Usage:
///   dart run saropa_lints:baseline [options]
///
/// This tool:
/// 1. Runs `dart analyze` on your project
/// 2. Parses the output to extract violations
/// 3. Generates a baseline JSON file
/// 4. Optionally activates it in analysis_options_custom.yaml
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/src/baseline/analysis_failure.dart';
import 'package:saropa_lints/src/baseline/baseline_activation.dart';
import 'package:saropa_lints/src/baseline/baseline_cli_args.dart';
import 'package:saropa_lints/src/baseline/baseline_explain.dart';
import 'package:saropa_lints/src/baseline/baseline_file.dart';
import 'package:saropa_lints/src/violation_parser.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();

    return;
  }

  // Read-only report: returns before anything that analyzes or writes.
  if (args.contains('--explain')) {
    exitCode = await _explain(args);
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

  // Project directory: first positional argument (see baselineWorkingDir for
  // the argument-0 bug this replaces).
  final workingDir = baselineWorkingDir(args);

  // A relative output path belongs to the analyzed project, not to the
  // shell's directory: `baseline ./my_project` used to write the JSON into
  // the caller's folder while the plugin looks for it under my_project.
  // `configPath` stays as given, because the loader resolves it against the
  // project root itself.
  final configPath = outputPath;
  if (!p.isAbsolute(outputPath)) {
    outputPath = p.join(workingDir, outputPath);
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
        'Updating existing baseline (${existingBaseline.totalViolations} violations)',
      );
    } else {
      print('No existing baseline found, creating new one');
    }
  }

  print('Running lint analysis...');
  print('');

  // Run dart analyze with the baseline JSON ignored by the plugin (`date:`
  // and `paths:` still apply). An active baseline file hides the findings it lists, so this run would otherwise see
  // only new findings: `--update` dropped every still-present entry, and a
  // plain re-run overwrote the baseline with the new findings alone.
  final result = await Process.run(
    'dart',
    ['analyze'],
    workingDirectory: workingDir,
    runInShell: true,
    environment: {kSkipBaselineEnvVar: '1'},
  );

  final output = result.stdout.toString();
  final stderr = result.stderr.toString();

  // Parse violations. This command runs `dart analyze`, whose diagnostics use
  // the hyphen-delimited human format ("info - file:line:col - msg - code"), so
  // it must use the matching parser. The bullet-delimited parseViolations() is
  // for custom_lint / scan CLI output ("file:line:col • msg • code •") and
  // silently returns zero rows on dart analyze output — which previously made
  // this tool report every real project as clean (issue #269).
  final violations = parseDartAnalyzeHumanOutput(output);

  // Guard against a false "clean codebase" verdict when the analyzer never
  // actually completed. A crashed analysis server (e.g. a plugin that fails
  // to AOT-compile, exit code 255) emits no parseable violation lines, so an
  // empty result set is ambiguous: it means EITHER "genuinely zero
  // violations" OR "analysis aborted before it could report anything".
  // Treating the crash case as clean would silently ship an empty baseline
  // over an unchecked codebase. Distinguish them by the process exit state:
  // a clean run exits 0; a run with real violations parses at least one line.
  // Anything else (non-zero exit with nothing parsed, or a known fatal
  // analyzer signature) is an execution failure we must surface, not swallow.
  final failure = detectAnalysisFailure(
    exitCode: result.exitCode,
    parsedViolationCount: violations.length,
    stdout: output,
    stderr: stderr,
  );

  if (failure != null) {
    _printError('ERROR: Lint analysis did not complete successfully.');
    _printError(failure);
    if (stderr.trim().isNotEmpty) {
      _printError('');
      _printError('dart analyze stderr:');
      _printError(stderr.trimRight());
    }
    _printError('');
    _printError(
      'No baseline was generated. Resolve the analysis failure above and '
      're-run this command.',
    );
    // Non-zero exit so CI and scripts treat this as a hard failure instead of
    // a clean pass.
    exitCode = 1;

    return;
  }

  // Surface non-fatal analyzer stderr (progress noise aside) for visibility,
  // but only after we have confirmed analysis actually completed.
  if (result.exitCode != 0 &&
      stderr.trim().isNotEmpty &&
      !stderr.contains('Analyzing')) {
    print('Warning: dart analyze returned errors:');
    print(stderr);
  }

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
    print('[DRY RUN] Would update $kBaselineConfigFileName');
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

  // Activate the baseline where the loader reads it.
  if (!skipConfig) _activateBaseline(workingDir, configPath);

  print('');
  print('Done! Run `dart analyze` again to see clean output.');
  print('');
  print('As you fix violations, run `dart run saropa_lints:baseline --update`');
  print('to remove fixed items from the baseline.');
}

/// Writes an error line to stderr. A local variable named `stderr` shadows the
/// `dart:io` top-level stream in `main`, so error output is funneled here.
void _printError(String message) {
  stderr.writeln(message);
}

/// Handles `--explain <file>` and returns the process exit code. A relative
/// file belongs to the project directory, like a relative output path.
Future<int> _explain(List<String> args) async {
  final index = args.indexOf('--explain') + 1;
  if (index >= args.length || args[index].startsWith('-')) {
    _printError('ERROR: --explain needs a file path.');
    return 64;
  }
  final path = p.normalize(
    p.absolute(p.join(baselineWorkingDir(args), args[index])),
  );
  if (!File(path).existsSync()) {
    _printError('ERROR: file not found: $path');
    return 66;
  }
  print(await explainBaseline(path, Platform.environment));
  return 0;
}

/// Makes `analysis_options_custom.yaml` in [projectDir] reference
/// [baselinePath], creating the file when missing, and prints what changed.
///
/// This replaces an insert into the plugin block of `analysis_options.yaml`,
/// which the loader never read, so a generated baseline was never active.
/// An existing `baseline:` section keeps its other keys; only its `file:`
/// line is added or changed (and shown), because a section without it, or
/// naming another file, left the JSON just written unreferenced.
void _activateBaseline(String projectDir, String baselinePath) {
  final file = File(p.join(projectDir, kBaselineConfigFileName));
  final existing = file.existsSync() ? file.readAsStringSync() : '';
  final activation = planBaselineActivation(existing, baselinePath);
  final text = activation.text;
  if (text != null) file.writeAsStringSync(text);
  print(describeBaselineActivation(activation, kBaselineConfigFileName));

  // An older CLI wrote an indented `baseline:` into analysis_options.yaml.
  // It never took effect; point it out so the user can delete it.
  final options = File(p.join(projectDir, 'analysis_options.yaml'));
  if (options.existsSync() &&
      hasLegacyNestedBaseline(options.readAsStringSync())) {
    print(
      'Note: analysis_options.yaml has a nested "baseline:" entry that is '
      'not read. The baseline is configured in $kBaselineConfigFileName; '
      'the old entry can be removed.',
    );
  }
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
    '  -o, --output <path>   Output file path (default: saropa_baseline.json)',
  );
  print(
    '  --update              Update existing baseline, removing fixed violations',
  );
  print(
    '  --dry-run             Show what would be done without making changes',
  );
  print('  --skip-config         Skip updating $kBaselineConfigFileName');
  print(
    '  --explain <file>      Show which baseline settings (date, paths, JSON',
  );
  print(
    '                        entries, only_impacts) hide findings in <file>.',
  );
  print('                        Read-only; does not run analysis.');
  print('  -h, --help            Show this help message');
  print('');
  print('Examples:');
  print('  dart run saropa_lints:baseline');
  print('  dart run saropa_lints:baseline --output .baseline.json');
  print('  dart run saropa_lints:baseline --update');
  print('  dart run saropa_lints:baseline --dry-run');
  print('  dart run saropa_lints:baseline ./my_project');
  print('  dart run saropa_lints:baseline --explain lib/legacy/old.dart');
  print('');
  print('After generating a baseline, run `dart analyze` again.');
  print('Old violations will be hidden, but new ones will still be reported.');
}
