/// Parsed startup arguments for the scan daemon.
///
/// This library provides [parseScanDaemonArgs], which parses the argument
/// list for `dart run saropa_lints:scan_daemon`. It is used by
/// `bin/scan_daemon.dart` and is extracted here (mirroring
/// `scan_cli_args.dart`) so the parsing rules can be unit-tested without
/// spawning the daemon process.
///
/// **Validation:** a flag with no following value, a non-positive
/// `--max-rss-mb`, an unknown `--` flag, or a missing `<projectRoot>`
/// positional all return [ScanDaemonParseInvalid] with a user-facing
/// message; the binary prints it to stderr and exits with code 2.
library;

/// Default RSS ceiling in MB. Conservative: well below the 7.8–13.6 GB the
/// unbounded in-process plugin was observed to reach, high enough to hold
/// a large project's warm element models.
const int defaultMaxRssMb = 4096;

/// Result of parsing scan daemon arguments.
sealed class ScanDaemonParseResult {}

/// Parsing succeeded; [options] holds the parsed values.
class ScanDaemonParseOk extends ScanDaemonParseResult {
  ScanDaemonParseOk(this.options);
  final ScanDaemonOptions options;
}

/// Parsing failed; [message] is user-facing (the binary exits 2 with it).
class ScanDaemonParseInvalid extends ScanDaemonParseResult {
  ScanDaemonParseInvalid(this.message);
  final String message;
}

/// Parsed scan daemon startup options.
class ScanDaemonOptions {
  const ScanDaemonOptions({
    required this.projectRoot,
    required this.tier,
    required this.maxRssMb,
  });

  /// Root of the project to scan; the analysis context collection is built
  /// over this directory and relative request paths resolve against it.
  final String projectRoot;

  /// Optional tier name overriding the project's own configuration
  /// (e.g. `essential`, `recommended`).
  final String? tier;

  /// RSS ceiling in MB past which the daemon recycles itself (clean exit
  /// so the caller respawns a fresh process). Always positive.
  final int maxRssMb;
}

/// Margin multiplier applied to the post-prewarm RSS when deriving the
/// effective recycle ceiling. Measured on a large project (contacts,
/// 2026-08-15): prewarm lands at ~3650 MB and steady-state growth is
/// ~12 MB per repeated-save request, so ×1.5 (~1800 MB headroom there)
/// allows on the order of 150 saves between recycles instead of ~35.
const double rssPrewarmMarginFactor = 1.5;

/// Derives the RSS ceiling the daemon actually enforces.
///
/// The configured `--max-rss-mb` alone cannot fit every project: a large
/// app's analyzer element models can consume most of the default budget
/// at prewarm, leaving the daemon recycling (and re-paying a ~1 minute
/// warmup) after a handful of saves. So the ceiling adapts upward: the
/// larger of the configured value and post-prewarm RSS × margin. Small
/// projects keep the configured bound; large projects get proportional
/// headroom. Returns the configured value unchanged when the platform
/// could not report RSS ([postPrewarmRssMb] null).
int resolveRssCeilingMb({
  required int configuredMb,
  required int? postPrewarmRssMb,
}) {
  if (postPrewarmRssMb == null || postPrewarmRssMb <= 0) return configuredMb;
  final adaptive = (postPrewarmRssMb * rssPrewarmMarginFactor).round();
  return adaptive > configuredMb ? adaptive : configuredMb;
}

/// Parses [args] for the scan daemon.
///
/// Accepts one required positional (`<projectRoot>`) plus `--tier <name>`
/// and `--max-rss-mb <positive int>`. Anything else starting with `--` is
/// an unknown flag and fails parsing — the daemon protocol is machine-run
/// by the extension, so a typo must fail loudly rather than be ignored.
ScanDaemonParseResult parseScanDaemonArgs(List<String> args) {
  final positionals = <String>[];
  String? tier;
  var maxRssMb = defaultMaxRssMb;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--tier' || arg == '--max-rss-mb') {
      // Both value-taking flags share the "next token is the value" shape;
      // a missing value (end of args) is a hard parse failure.
      if (i + 1 >= args.length) {
        return ScanDaemonParseInvalid('$arg requires a value');
      }
      final value = args[++i];
      if (arg == '--tier') {
        tier = value;
      } else {
        // The RSS ceiling must be a positive integer — zero/negative would
        // make the daemon recycle after its very first request forever.
        final parsed = int.tryParse(value);
        if (parsed == null || parsed <= 0) {
          return ScanDaemonParseInvalid(
            '--max-rss-mb requires a positive integer, got: $value',
          );
        }
        maxRssMb = parsed;
      }
      continue;
    }
    if (arg.startsWith('--')) {
      return ScanDaemonParseInvalid('Unknown flag: $arg');
    }
    positionals.add(arg);
  }
  if (positionals.isEmpty) {
    return ScanDaemonParseInvalid('Missing required <projectRoot> argument.');
  }
  return ScanDaemonParseOk(
    ScanDaemonOptions(
      projectRoot: positionals.first,
      tier: tier,
      maxRssMb: maxRssMb,
    ),
  );
}
