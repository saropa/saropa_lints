#!/usr/bin/env dart

/// Full audit CLI — runs every saropa_lints rule against a codebase.
///
/// Unlike `scan` (which respects the project's configured tier), audit
/// always enables every rule (pedantic ∪ stylistic) with the tier cap
/// bypassed. The output is enriched JSON with per-diagnostic `tier` and
/// `category` fields.
///
/// Usage:
///   dart run saropa_lints audit [path] [options]
///
/// Exit codes:
///   0 — audit completed, diagnostics written
///   1 — audit completed but encountered analysis errors
///   2 — invalid arguments, not a Dart project, or `pub get` not run
// ignore_for_file: avoid_print
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:saropa_lints/saropa_lints.dart' show getAllDefinedRules;
import 'package:saropa_lints/scan.dart';
import 'package:saropa_lints/src/config/rule_lane.dart' show RuleLane;
import 'package:saropa_lints/src/native/saropa_context.dart'
    show SaropaContext;
import 'package:saropa_lints/src/report/timing_emitter.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show RuleTimingTracker;
import 'package:saropa_lints/src/scan/audit_baseline.dart';
import 'package:saropa_lints/src/scan/git_changed_files.dart';
import 'package:saropa_lints/src/scan/rule_tier_index.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final parsed = _parseArgs(args);
  if (parsed == null) exit(2);

  final path = p.absolute(parsed.path);

  // Verify the target is a Dart project with resolved dependencies.
  if (!File(p.join(path, 'pubspec.yaml')).existsSync()) {
    stderr.writeln('Error: $path is not a Dart project (no pubspec.yaml).');
    exit(2);
  }
  if (!File(p.join(path, '.dart_tool', 'package_config.json')).existsSync()) {
    stderr.writeln(
      'Error: $path has not had `pub get` run '
      '(no .dart_tool/package_config.json).\n'
      'Run `dart pub get` or `flutter pub get` first.',
    );
    exit(2);
  }

  // When --since is set, restrict the file list to changed files only.
  List<String>? dartFiles;
  if (parsed.since != null) {
    dartFiles = gitChangedDartFiles(path, parsed.since!);
    if (dartFiles.isEmpty) {
      stderr.writeln('No Dart files changed since ${parsed.since}.');
      // Still produce valid JSON output with zero diagnostics.
    }
  }

  // Enable every defined rule — pedantic ∪ stylistic = everything.
  final allRules = getAllDefinedRules();

  if (!parsed.quiet) {
    stderr.writeln(
      'Audit: scanning ${dartFiles?.length ?? 'all'} files '
      'with ${allRules.length} rules...',
    );
  }

  // Arm per-rule timing capture before any rule callback runs.
  if (parsed.profile) {
    RuleTimingTracker.reset();
    SaropaContext.runtimeProfilingEnabled = true;
  }

  // Progress sink: when --quiet, emit machine-readable JSON progress lines
  // on stderr so the extension can parse them for the progress bar. When
  // not quiet, pass through to stderr for human-readable output.
  void Function(String)? progressSink;
  if (parsed.quiet) {
    // Parse the ScanRunner progress format and emit structured lines.
    progressSink = (msg) {
      final match = _progressPattern.firstMatch(msg);
      if (match != null) {
        final current = int.tryParse(match.group(1)!) ?? 0;
        final total = int.tryParse(match.group(2)!) ?? 1;
        final elapsed = match.group(3)!;
        final issues = int.tryParse(match.group(4)!) ?? 0;
        final file = match.group(5)!.trim();
        // JSON line on stderr — the extension reads these.
        stderr.writeln(
          '{"progress":$current,"total":$total,'
          '"elapsed":"$elapsed","issues":$issues,'
          '"file":"${file.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"}',
        );
      }
    };
  }

  final runner = ScanRunner(
    targetPath: path,
    dartFiles: dartFiles,
    enabledRuleNames: allRules,
    // Feed progress messages through our structured sink.
    messageSink: progressSink,
    // Always full lane — audit must exercise every rule.
    lane: RuleLane.full,
    excludeGlobs: parsed.excludeGlobs,
    includeGlobs: parsed.includeGlobs,
  );

  final diagnostics = await runner.runResolved();
  if (diagnostics == null) {
    stderr.writeln('Error: audit scan failed (could not resolve analysis).');
    exit(2);
  }

  // Post-filter by severity / impact when requested.
  var filtered = diagnostics;
  if (parsed.minSeverity != null) {
    final threshold = _severityRank(parsed.minSeverity!);
    filtered =
        filtered.where((d) => _severityRank(d.severity) >= threshold).toList();
  }
  if (parsed.minImpact != null) {
    final threshold = _impactRank(parsed.minImpact!);
    filtered = filtered
        .where((d) => _impactRank(d.impact ?? '') >= threshold)
        .toList();
  }

  // Build tier reverse-index for JSON enrichment.
  final tiers = tierIndexForRules(allRules);

  // Build the enriched JSON output.
  final json = scanDiagnosticsToJson(filtered);

  // Enrich each diagnostic with its tier from the reverse-index.
  final diagList = json['diagnostics'];
  if (diagList is List) {
    for (final entry in diagList) {
      if (entry is Map<String, dynamic>) {
        final rule = entry['rule'] as String?;
        if (rule != null) {
          final tier = tiers[rule];
          if (tier != null) entry['tier'] = tier;
        }
      }
    }
  }

  // Add audit-specific top-level fields.
  json['tierCapBypassed'] = true;
  json['timestamp'] = DateTime.now().toUtc().toIso8601String();

  // Baseline diffing: compare current diagnostics against the saved baseline
  // and tag each diagnostic with `baselineStatus` (new / unchanged).
  if (parsed.useBaseline) {
    final baseline = loadBaseline(
      path,
      overridePath: parsed.baselinePath,
    );
    if (baseline == null) {
      stderr.writeln(
        'Warning: no baseline found at '
        '${baselinePath(path, overridePath: parsed.baselinePath)}. '
        'Skipping baseline comparison.',
      );
    } else {
      // Mutates the diagnostic maps in `filtered` to add `baselineStatus`.
      final diagMaps = (json['diagnostics'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final diff = diffAgainstBaseline(diagMaps, baseline);

      // Add baseline summary to the JSON output.
      json['baseline'] = {
        'comparedTo': diff.baselineTimestamp,
        'new': diff.newCount,
        'resolved': diff.resolvedCount,
        'unchanged': diff.unchangedCount,
      };

      if (!parsed.quiet) {
        stderr.writeln(
          'Baseline: ${diff.newCount} new, '
          '${diff.resolvedCount} resolved, '
          '${diff.unchangedCount} unchanged '
          '(vs ${diff.baselineTimestamp}).',
        );
      }
    }
  }

  // Save baseline when requested — after diffing so the new baseline
  // includes `baselineStatus` tags for traceability.
  if (parsed.saveBaseline) {
    saveBaseline(path, json, overridePath: parsed.baselinePath);
    if (!parsed.quiet) {
      stderr.writeln(
        'Baseline saved to '
        '${baselinePath(path, overridePath: parsed.baselinePath)}.',
      );
    }
  }

  final output = const JsonEncoder.withIndent('  ').convert(json);

  // Write to --output path or stdout.
  if (parsed.outputPath != null) {
    File(parsed.outputPath!).writeAsStringSync(output);
    if (!parsed.quiet) {
      stderr.writeln('Audit report written to ${parsed.outputPath}');
    }
  } else {
    stdout.writeln(output);
  }

  // Write timing report when --profile is active.
  if (parsed.profile) {
    final timingPath = writeRuleTimingReport(
      projectRoot: path,
      resolved: true,
      fileCount: dartFiles?.length,
    );
    if (timingPath != null) {
      if (!parsed.quiet) stderr.writeln('Timing profile: $timingPath');
    } else {
      if (!parsed.quiet) {
        stderr.writeln('Timing profile: no data collected (no rules ran).');
      }
    }
  }

  // Exit 0 for clean audit, 1 when diagnostics were found.
  exit(filtered.isEmpty ? 0 : 1);
}

// ── Arg parsing ──────────────────────────────────────────────────────

/// Parsed audit CLI arguments.
class _AuditArgs {
  const _AuditArgs({
    required this.path,
    this.outputPath,
    this.since,
    this.minSeverity,
    this.minImpact,
    this.profile = false,
    this.quiet = false,
    this.excludeGlobs = const [],
    this.includeGlobs = const [],
    this.saveBaseline = false,
    this.useBaseline = false,
    this.baselinePath,
  });

  final String path;
  final String? outputPath;
  final String? since;
  final String? minSeverity;
  final String? minImpact;
  final bool profile;
  final bool quiet;
  final List<String> excludeGlobs;
  final List<String> includeGlobs;

  /// When true, save the audit output as the project baseline.
  final bool saveBaseline;

  /// When true, compare against the saved baseline and tag diagnostics.
  final bool useBaseline;

  /// Override path for the baseline file (default: .saropa/audit_baseline.json).
  final String? baselinePath;
}

/// Parses CLI args into [_AuditArgs], or prints an error and returns null.
_AuditArgs? _parseArgs(List<String> args) {
  String? path;
  String? outputPath;
  String? since;
  String? minSeverity;
  String? minImpact;
  var profile = false;
  var quiet = false;
  var saveBaseline = false;
  var useBaseline = false;
  String? baselinePathOverride;
  final excludeGlobs = <String>[];
  final includeGlobs = <String>[];

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '--output':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --output requires a path argument.');
          return null;
        }
        outputPath = args[++i];
      case '--since':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --since requires a git ref argument.');
          return null;
        }
        since = args[++i];
      case '--min-severity':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --min-severity requires a value.');
          return null;
        }
        minSeverity = args[++i];
      case '--min-impact':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --min-impact requires a value.');
          return null;
        }
        minImpact = args[++i];
      case '--exclude-globs':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --exclude-globs requires a value.');
          return null;
        }
        excludeGlobs.addAll(args[++i].split(','));
      case '--include-globs':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --include-globs requires a value.');
          return null;
        }
        includeGlobs.addAll(args[++i].split(','));
      case '--save-baseline':
        saveBaseline = true;
      case '--baseline':
        useBaseline = true;
      case '--baseline-path':
        if (i + 1 >= args.length) {
          stderr.writeln('Error: --baseline-path requires a path argument.');
          return null;
        }
        baselinePathOverride = args[++i];
      case '--profile':
        profile = true;
      case '--quiet' || '-q':
        quiet = true;
      default:
        if (arg.startsWith('-')) {
          stderr.writeln('Error: unknown flag: $arg');
          return null;
        }
        // Positional arg = target path.
        if (path != null) {
          stderr.writeln('Error: multiple paths given ($path and $arg).');
          return null;
        }
        path = arg;
    }
  }

  // Default to current directory when no path given.
  path ??= '.';

  return _AuditArgs(
    path: path,
    outputPath: outputPath,
    since: since,
    minSeverity: minSeverity,
    minImpact: minImpact,
    profile: profile,
    quiet: quiet,
    excludeGlobs: excludeGlobs,
    includeGlobs: includeGlobs,
    saveBaseline: saveBaseline,
    useBaseline: useBaseline,
    baselinePath: baselinePathOverride,
  );
}

// ── Progress parsing ────────────────────────────────────────────────

/// Matches the ScanRunner progress format:
///   `\r  Files: 10/200 | 1.5s | 7/s | Issues: 3 | main.dart`
/// Groups: 1=current, 2=total, 3=elapsed, 4=issues, 5=filename
final _progressPattern = RegExp(
  r'Files:\s*(\d+)/(\d+)\s*\|\s*([\d.]+s)\s*\|\s*\d+/s\s*\|\s*Issues:\s*(\d+)\s*\|\s*(.+)',
);

// ── Severity / impact ranking for post-filters ───────────────────────

/// Numeric rank for severity strings (higher = more severe).
int _severityRank(String severity) => switch (severity.toLowerCase()) {
  'error' => 3,
  'warning' => 2,
  'info' => 1,
  _ => 0,
};

/// Numeric rank for impact strings (higher = more impactful).
int _impactRank(String impact) => switch (impact.toLowerCase()) {
  'critical' => 5,
  'high' => 4,
  'medium' => 3,
  'low' => 2,
  'minimal' => 1,
  _ => 0,
};

// ── Usage ────────────────────────────────────────────────────────────

void _printUsage() {
  print('saropa_lints audit — run every rule against a codebase');
  print('');
  print('Usage: dart run saropa_lints audit [path] [options]');
  print('');
  print('Runs all saropa_lints rules (pedantic + stylistic = everything)');
  print('regardless of the project\'s configured tier. Produces enriched');
  print('JSON with per-diagnostic tier and category fields.');
  print('');
  print('Options:');
  print('  --output <path>       Write JSON to a file instead of stdout');
  print('  --since <ref>         Only audit files changed since this git ref');
  print('  --min-severity <s>    Post-filter: hide below this severity');
  print('                        (error, warning, info)');
  print('  --min-impact <i>      Post-filter: hide below this impact');
  print('                        (critical, high, medium, low, minimal)');
  print('  --exclude-globs <g>   Comma-separated glob patterns to skip');
  print('  --include-globs <g>   Comma-separated glob patterns to force-include');
  print('  --save-baseline       Save this audit as the project baseline');
  print('  --baseline            Compare against the saved baseline');
  print('  --baseline-path <p>   Override baseline file path');
  print('  --profile             Emit per-rule timing report');
  print('  --quiet, -q           Suppress non-fatal stderr messages');
  print('  -h, --help            Show this help');
  print('');
  print('Exit codes:');
  print('  0  Audit completed, no diagnostics found');
  print('  1  Audit completed, diagnostics found');
  print('  2  Invalid arguments, not a Dart project, or pub get not run');
  print('');
  print('Examples:');
  print('  dart run saropa_lints audit .');
  print('  dart run saropa_lints audit /path/to/project --output report.json');
  print('  dart run saropa_lints audit . --since main');
  print('  dart run saropa_lints audit . --min-severity warning --quiet');
}
