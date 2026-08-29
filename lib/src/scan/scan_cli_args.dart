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
    this.findStaleIgnores = false,
    this.fixStaleIgnores = false,
    this.checkSdkCompat = false,
    this.minSeverity,
    this.maxSeverity,
    this.minImpact,
    this.failOn,
    this.failOnImpact,
    this.failOnTier,
    this.failOnCount,
    this.failOnImpactCount,
    this.jsonFilePath,
    this.profile = false,
    this.excludeLightLane = false,
    this.lane,
    this.laneStats = false,
    this.quiet = false,
    this.excludeGlobs = const [],
    this.includeGlobs = const [],
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

  /// Exit-code impact threshold, independent of display filtering.
  /// Like [failOn] but checks the rule's declared [LintImpact] instead of the
  /// analyzer severity. Diagnostics with no impact (non-saropa rules) are
  /// excluded from the match count. When both [failOn] and [failOnImpact] are
  /// set, either threshold being met triggers exit 1 (logical OR — strictest
  /// wins, so CI catches problems on EITHER axis).
  /// Valid values: 'INFO', 'WARNING', 'ERROR'. Null = not used.
  final String? failOnImpact;

  /// Exit-code tier threshold. When set, the scan exits 1 only when any
  /// diagnostic comes from a rule that belongs to this tier or below it.
  /// This lets CI fail only on essential-tier findings during incremental
  /// adoption, even if the scan runs at a higher tier for visibility.
  /// Valid values: 'essential', 'recommended', 'professional', 'comprehensive',
  /// 'pedantic'. Null = not used. When combined with [failOn] or
  /// [failOnImpact], any threshold being met triggers exit 1 (logical OR).
  final String? failOnTier;

  /// Count threshold for [failOn]. When set, the scan exits 1 only when the
  /// number of diagnostics at or above the [failOn] severity exceeds this
  /// count — lets CI tolerate a known baseline of warnings. Requires [failOn]
  /// to be set; ignored without it. Null means any single match triggers exit 1.
  final int? failOnCount;

  /// Count threshold for [failOnImpact]. When set, the scan exits 1 only when
  /// the number of saropa diagnostics at or above the impact threshold exceeds
  /// this count — lets CI tolerate a known baseline of high-impact findings
  /// during migration. Requires [failOnImpact] to be set; ignored without it.
  /// Null means any single match triggers exit 1.
  final int? failOnImpactCount;

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

  /// When true, run the normal scan and then detect `// ignore:` directives
  /// whose suppressed saropa_lints rule no longer fires on the target line.
  /// Reports each stale ignore with file, line, and rule name. Supports
  /// `--format json` for machine-readable output. Exits 1 if any stale
  /// ignores are found, 0 if none.
  final bool findStaleIgnores;

  /// When true, run the stale-ignore detection (same as [findStaleIgnores])
  /// and then automatically remove the stale directives from the source files.
  /// Standalone comments are deleted; inline comments are stripped; multi-rule
  /// comments have only the stale rules pruned. Prints a summary of changes.
  final bool fixStaleIgnores;

  /// When true, run a standalone SDK compatibility audit: cross-reference
  /// the pubspec.yaml SDK lower bound against Dart syntax features in lib/
  /// and output a summary showing the minimum required version.
  final bool checkSdkCompat;

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

  /// Which lane the scan should use. `full` (default) runs every enabled
  /// rule; `light` restricts to cheap, resolution-free rules only. When
  /// null, the scanner defaults to `full`.
  final String? lane;

  /// When true, prints how many rules are in the light lane vs full-only,
  /// making the lane gate's effect observable.
  final bool laneStats;

  /// When true, suppresses ALL stderr progress/status messages (Loaded,
  /// Scanning, timing, threshold notes). The caller gets only the exit code
  /// and stdout output (report or JSON). Useful for fully silent automation
  /// where only the exit code and optional --json-file-path output matter.
  final bool quiet;

  /// Glob patterns for additional path exclusions beyond the hardcoded
  /// defaults. Supports `**` (any path segments), `*` (any non-separator
  /// chars), and `?` (single char). Matched against forward-slash-normalized
  /// paths. See #313 — the reporter's project scanned platform ephemeral
  /// dirs; now those are excluded by default, but this flag lets users
  /// exclude any other paths they don't control.
  final List<String> excludeGlobs;

  /// Glob patterns that override the hardcoded exclusions. When a path matches
  /// both a hardcoded exclusion (e.g. `ephemeral/`) AND an include-glob, the
  /// include wins — letting users force-scan paths the defaults would skip.
  /// Useful for auditing third-party plugin code in platform directories.
  final List<String> includeGlobs;
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
  List<String> excludeGlobs = [];
  List<String> includeGlobs = [];
  String? tier;
  String? debugRule;
  String? minSeverity;
  String? maxSeverity;
  String? minImpact;
  String? failOn;
  String? failOnImpact;
  String? failOnTier;
  int? failOnCount;
  int? failOnImpactCount;
  String? jsonFilePath;
  bool formatJson = false;
  bool resolve = false;

  bool fixIgnores = false;
  bool findStaleIgnores = false;
  bool fixStaleIgnores = false;
  bool checkSdkCompat = false;
  bool profile = false;
  bool excludeLightLane = false;
  String? lane;
  bool laneStats = false;
  bool quiet = false;

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
    // Stale-ignore detection: run the scan, then compare diagnostics against
    // `// ignore:` comments to find directives whose rule no longer fires.
    if (arg == '--find-stale-ignores') {
      findStaleIgnores = true;
      i++;
      continue;
    }
    // Stale-ignore auto-fix: detect stale ignores (same as --find-stale-ignores)
    // and then remove them from the source files automatically.
    if (arg == '--fix-stale-ignores') {
      fixStaleIgnores = true;
      i++;
      continue;
    }
    // Standalone SDK compatibility audit — cross-references pubspec SDK
    // lower bound against syntax features in lib/.
    if (arg == '--check-sdk-compat') {
      checkSdkCompat = true;
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
    // Explicit lane override: --lane full (default) or --lane light.
    // Light lane restricts the scan to cheap, resolution-free rules; full
    // runs every enabled rule. Validates the value against the known set.
    if (arg == '--lane') {
      i++;
      if (i >= args.length || args[i].startsWith('--')) {
        return ScanParseInvalid('--lane requires a value (full or light)');
      }
      final value = args[i].toLowerCase();
      if (value != 'full' && value != 'light') {
        return ScanParseInvalid(
          '--lane must be "full" or "light", got "$value"',
        );
      }
      lane = value;
      i++;
      continue;
    }
    // Lane stats: show how the lane gate partitions the loaded rules.
    if (arg == '--lane-stats') {
      laneStats = true;
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
    // User-specified glob patterns for path exclusion — consumes all
    // following non-flag arguments, same grammar as --files. See #313.
    if (arg == '--exclude-globs') {
      i++;
      while (i < args.length && !args[i].startsWith('--')) {
        excludeGlobs.add(args[i]);
        i++;
      }
      continue;
    }
    // Include-glob patterns that override the hardcoded exclusions —
    // same grammar as --exclude-globs. See #313.
    if (arg == '--include-globs') {
      i++;
      while (i < args.length && !args[i].startsWith('--')) {
        includeGlobs.add(args[i]);
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
    // Exit-code threshold by impact: like --fail-on but uses the rule author's
    // declared impact rather than the analyzer severity. Non-saropa diagnostics
    // (which have no impact) are excluded from the check.
    if (arg == '--fail-on-impact') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toUpperCase();
        if (value == 'INFO' || value == 'WARNING' || value == 'ERROR') {
          failOnImpact = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--fail-on-impact must be one of: info, warning, error.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--fail-on-impact requires a value (info, warning, error).',
        );
      }
      continue;
    }
    // Exit-code tier gate: fail only when a diagnostic comes from a rule
    // in this tier or below. Lets CI see all diagnostics at a high tier
    // but only fail on essential/recommended findings during adoption.
    if (arg == '--fail-on-tier') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final value = args[i].toLowerCase();
        if (const {
          'essential',
          'recommended',
          'professional',
          'comprehensive',
          'pedantic',
        }.contains(value)) {
          failOnTier = value;
          i++;
        } else {
          return ScanParseInvalid(
            '--fail-on-tier must be one of: essential, recommended, '
            'professional, comprehensive, pedantic.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--fail-on-tier requires a value (essential, recommended, '
          'professional, comprehensive, pedantic).',
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
    // Count threshold for --fail-on-impact: exit 1 only when the number of
    // matching impact-level diagnostics exceeds this count. Mirrors the
    // --fail-on-count semantics but for the impact axis.
    if (arg == '--fail-on-impact-count') {
      i++;
      if (i < args.length && !args[i].startsWith('--')) {
        final parsed = int.tryParse(args[i]);
        if (parsed != null && parsed >= 0) {
          failOnImpactCount = parsed;
          i++;
        } else {
          return ScanParseInvalid(
            '--fail-on-impact-count must be a non-negative integer.',
          );
        }
      } else {
        return ScanParseInvalid(
          '--fail-on-impact-count requires a non-negative integer value.',
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
      findStaleIgnores: findStaleIgnores,
      fixStaleIgnores: fixStaleIgnores,
      checkSdkCompat: checkSdkCompat,
      minSeverity: minSeverity,
      maxSeverity: maxSeverity,
      minImpact: minImpact,
      failOn: failOn,
      failOnImpact: failOnImpact,
      failOnTier: failOnTier,
      failOnCount: failOnCount,
      failOnImpactCount: failOnImpactCount,
      profile: profile,
      excludeLightLane: excludeLightLane,
      lane: lane,
      laneStats: laneStats,
      quiet: quiet,
      excludeGlobs: excludeGlobs,
      includeGlobs: includeGlobs,
    ),
  );
}
