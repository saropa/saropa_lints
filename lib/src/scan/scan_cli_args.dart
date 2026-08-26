/// Parsed scan CLI arguments for the scan command.
///
/// This library provides [parseScanArgs], which parses the argument list
/// for `dart run saropa_lints:scan`. It is used by `bin/scan.dart` and is
/// extracted here so that CLI behavior can be unit-tested without
/// running the full binary.
///
/// **Usage from the binary:** Call [parseScanArgs] with [readStdin] set to
/// a function that reads lines from process stdin (used when [--files-from-stdin]
/// is present). The binary passes `_readStdinLines` from `bin/scan.dart`.
///
/// **Usage from tests:** Call [parseScanArgs] with [stdinLines] set to a
/// fixed list of paths so that stdin is not read. Omit [readStdin].
///
/// **Validation:** [--tier], [--min-severity], [--max-severity], and
/// [--debug-rule] with no following argument (or with the next argument being
/// an option like [--format]) return [ScanParseInvalid] with a user-facing
/// message; the binary then exits with code 2. Severity values are validated
/// against the set {info, warning, error} (case-insensitive).
library;

/// Result of parsing scan CLI arguments.
sealed class ScanParseResult {}

/// Parsing succeeded; [args] holds the parsed values.
class ScanParseOk extends ScanParseResult {
  ScanParseOk(this.args);
  final ScanCliArgs args;
}

/// Parsing failed (e.g. [--tier] with no value); [message] is user-facing.
class ScanParseInvalid extends ScanParseResult {
  ScanParseInvalid(this.message);
  final String message;
}

/// Parsed scan CLI arguments.
class ScanCliArgs {
  const ScanCliArgs({
    required this.path,
    required this.dartFiles,
    required this.tier,
    required this.formatJson,
    required this.resolve,
    this.debugRule,
    this.fixIgnores = false,
    this.minSeverity,
    this.maxSeverity,
    this.minImpact,
    this.failOn,
    this.failOnCount,
    this.jsonFilePath,
    this.profile = false,
    this.excludeLightLane = false,
    this.quiet = false,
    this.excludedGlobs = const [],
  });

  final String path;
  final List<String> dartFiles;
  final String? tier;
  final bool formatJson;

  /// When set, writes JSON output directly to this file path instead of
  /// stdout. Implies [formatJson] = true. Lets automation harnesses avoid
  /// stdout redirection entirely.
  final String? jsonFilePath;

  /// Minimum severity threshold for output filtering.
  /// When set, diagnostics below this severity are excluded from stdout
  /// and report output. Valid values: 'INFO', 'WARNING', 'ERROR'.
  /// Null means no filtering (show all severities).
  final String? minSeverity;

  /// Maximum severity cap for output filtering.
  /// When set, diagnostics above this severity are excluded — useful for
  /// viewing only lower-priority noise during triage. Valid values same
  /// as [minSeverity]. Null means no upper cap.
  final String? maxSeverity;

  /// Exit-code severity threshold, independent of display filtering.
  /// When set, the scan exits 1 only if any diagnostic in the FULL (unfiltered)
  /// set meets this severity — diagnostics below it still appear in output but
  /// do not cause a non-zero exit. This lets automation see all diagnostics
  /// while gating CI on errors only. Valid values: 'INFO', 'WARNING', 'ERROR'.
  /// Null means the exit code is determined by the filtered list (existing
  /// behavior: any displayed diagnostic → exit 1).
  final String? failOn;

  /// Count threshold for [failOn]. When set, the scan exits 1 only when the
  /// number of diagnostics at or above the [failOn] severity exceeds this
  /// count — lets CI tolerate a known baseline of warnings. Requires [failOn]
  /// to be set; ignored without it. Null means any single match triggers exit 1.
  final int? failOnCount;

  /// Minimum impact threshold for output filtering. Filters on the rule's
  /// declared [LintImpact] rather than the analyzer severity — some rules have
  /// info severity but warning impact, so this lets the user exclude the
  /// truly-info ones. Valid values: 'INFO', 'WARNING', 'ERROR'. Null = no
  /// filtering.
  final String? minImpact;

  /// When true, the scan fully resolves each unit instead of the default
  /// syntactic parse. Required for rules registered on
  /// `addInstanceCreationExpression` and any type-based rule: without
  /// resolution an implicit constructor call (`File('x')`) parses as a
  /// `MethodInvocation`, not an `InstanceCreationExpression`, so those rules
  /// silently never fire.
  final bool resolve;

  /// When set, emits per-node diagnostic trace output for the named rule,
  /// showing type resolution details (staticType, staticInvokeType, returnType)
  /// at each visited node. Used to diagnose false positives caused by
  /// type-resolution divergence in the analyzer plugin context.
  final String? debugRule;

  /// When true, bulk-convert bare `// ignore: rule_name` comments to
  /// `// ignore: saropa_lints/rule_name` for all known saropa_lints rules.
  final bool fixIgnores;

  /// When true, per-rule execution timing is recorded during the scan and
  /// flushed to `reports/.saropa_lints/rule_timings.json` at the end.
  /// Runtime flag (not a dart-define) so `dart run` snapshot caching can
  /// never silently disable it — see `SaropaContext.runtimeProfilingEnabled`.
  final bool profile;

  /// When true, light-lane rules are dropped from the scan.
  ///
  /// The CLI mirror of the scan daemon's `excludeLane` request field, so the
  /// two-lane de-duplication can be exercised and verified from a terminal
  /// without driving the daemon protocol by hand.
  final bool excludeLightLane;

  /// When true, suppresses ALL stderr progress/status messages (Loaded,
  /// Scanning, timing, threshold notes). The caller gets only the exit code
  /// and stdout output (report or JSON). Useful for fully silent automation
  /// where only the exit code and optional --json-file-path output matter.
  final bool quiet;

  /// User-defined glob patterns for files that should be excluded from scanning.
  ///
  /// Patterns are matched against paths relative to the scan target.
  /// An empty list means no additional file exclusions are applied.
  final List<String> excludedGlobs;
}

/// Parses [args] for the scan command.
///
/// When [--files-from-stdin] is present, uses [stdinLines] if provided,
/// otherwise calls [readStdin] (e.g. to read from process stdin). In tests
/// pass [stdinLines]; in the binary pass [readStdin].
///
/// Returns [ScanParseInvalid] when [--tier] is given with no value.
ScanParseResult parseScanArgs(
  List<String> args, {
  List<String>? stdinLines,
  List<String> Function()? readStdin,
}) {
  final positionals = args
      .where((a) => !a.startsWith('--') && a != 'scan')
      .toList();
  final path = positionals.isNotEmpty ? positionals.first : '.';

  List<String> dartFiles = [];
  String? tier;
  String? debugRule;
  String? minSeverity;
  String? maxSeverity;
  String? minImpact;
  String? failOn;
  int? failOnCount;
  String? jsonFilePath;
  bool formatJson = false;
  bool resolve = false;

  bool fixIgnores = false;
  bool profile = false;
  bool excludeLightLane = false;
  bool quiet = false;
  final excludedGlobs = <String>[];

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
    // Suppress all stderr progress/status messages for fully silent
    // automation — the caller gets only stdout output and the exit code.
    if (arg == '--quiet' || arg == '-q') {
      quiet = true;
      i++;
      continue;
    }
    if (arg == '--fix-ignores') {
      fixIgnores = true;
      i++;
      continue;
    }
    // Two-lane de-duplication: skip the rules the in-process plugin runs
    // itself under `lane: light`. Boolean flag with no value — the lane name
    // is implicit because "light" is the only lane the scan can exclude
    // (excluding "full" would leave nothing to scan).
    if (arg == '--exclude-light-lane') {
      excludeLightLane = true;
      i++;
      continue;
    }
    // Per-rule timing capture + report; a plain boolean flag with no value.
    if (arg == '--profile') {
      profile = true;
      i++;
      continue;
    }
    if (arg == '--files') {
      i++;
      while (i < args.length && !args[i].startsWith('--')) {
        dartFiles.add(args[i]);
        i++;
      }
      continue;
    }
    if (arg == '--files-from-stdin') {
      dartFiles.addAll(stdinLines ?? readStdin?.call() ?? []);
      i++;
      continue;
    }

    // Collect one or more exclusion patterns until the next CLI option.
    // Missing patterns are rejected instead of silently ignoring the flag.
    if (arg == '--exclude-globs') {
      i++;

      if (i >= args.length || args[i].startsWith('--')) {
        return ScanParseInvalid(
          '--exclude-globs requires at least one glob pattern.',
        );
      }
      while (i < args.length && !args[i].startsWith('--')) {
        excludedGlobs.add(args[i]);
        i++;
      }
      continue;
    }

    if (arg == '--tier') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        tier = args[i];
        i++;
      } else {
        return ScanParseInvalid(
          '--tier requires a value (essential, recommended, professional, comprehensive, pedantic).',
        );
      }
      continue;
    }
    if (arg == '--resolve') {
      resolve = true;
      i++;
      continue;
    }
    if (arg == '--debug-rule') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        debugRule = args[i];
        i++;
      } else {
        return ScanParseInvalid(
          '--debug-rule requires a rule name (e.g. avoid_redundant_await).',
        );
      }
      continue;
    }
    if (arg == '--min-severity') {
      i++;
      // Validate the severity value is a recognized level.
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toUpperCase();
        if (value == 'INFO' || value == 'WARNING' || value == 'ERROR') {
          minSeverity = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--min-severity must be one of: info, warning, error.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--min-severity requires a value (info, warning, error).',
        );
      }
      continue;
    }
    if (arg == '--max-severity') {
      i++;
      // Validate the severity value is a recognized level.
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toUpperCase();
        if (value == 'INFO' || value == 'WARNING' || value == 'ERROR') {
          maxSeverity = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--max-severity must be one of: info, warning, error.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--max-severity requires a value (info, warning, error).',
        );
      }
      continue;
    }
    // Impact filtering: uses the rule's declared LintImpact, which can differ
    // from the analyzer severity (e.g. info severity + warning impact).
    if (arg == '--min-impact') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toUpperCase();
        if (value == 'INFO' || value == 'WARNING' || value == 'ERROR') {
          minImpact = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--min-impact must be one of: info, warning, error.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--min-impact requires a value (info, warning, error).',
        );
      }
      continue;
    }
    // Exit-code threshold: decouples the exit code from display filtering so
    // automation can see all diagnostics but only fail on a chosen severity.
    if (arg == '--fail-on') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toUpperCase();
        if (value == 'INFO' || value == 'WARNING' || value == 'ERROR') {
          failOn = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--fail-on must be one of: info, warning, error.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--fail-on requires a value (info, warning, error).',
        );
      }
      continue;
    }
    // Count threshold for --fail-on: exit 1 only when the number of matching
    // diagnostics exceeds this count. Requires --fail-on to be meaningful.
    if (arg == '--fail-on-count') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final parsed = int.tryParse(args[i]);
        if (parsed != null && parsed >= 0) {
          failOnCount = parsed;
          i++;
        } else {
          return ScanParseInvalid(
            '--fail-on-count must be a non-negative integer.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--fail-on-count requires a non-negative integer value.',
        );
      }
      continue;
    }
    if (arg == '--format') {
      i++;
      if (i < args.length) {
        formatJson = args[i].toLowerCase() == 'json';
        i++;
      }
      continue;
    }
    // Write JSON directly to a file, bypassing stdout entirely.
    // Implies --format json.
    if (arg == '--json-file-path') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        jsonFilePath = args[i];
        formatJson = true;
        i++;
      } else {
        return ScanParseInvalid('--json-file-path requires a file path.');
      }
      continue;
    }
    i++;
  }
  return ScanParseOk(
    ScanCliArgs(
      path: path,
      dartFiles: dartFiles,
      tier: tier,
      formatJson: formatJson,
      jsonFilePath: jsonFilePath,
      resolve: resolve,
      debugRule: debugRule,
      fixIgnores: fixIgnores,
      minSeverity: minSeverity,
      maxSeverity: maxSeverity,
      minImpact: minImpact,
      failOn: failOn,
      failOnCount: failOnCount,
      profile: profile,
      excludeLightLane: excludeLightLane,
      quiet: quiet,
      excludedGlobs: excludedGlobs,
    ),
  );
}
