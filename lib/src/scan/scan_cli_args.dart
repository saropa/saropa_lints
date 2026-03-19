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
/// **Validation:** [--tier] with no following argument (or with the next
/// argument being an option like [--format]) returns [ScanParseInvalid]
/// with a user-facing message; the binary then exits with code 2.
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
  });

  final String path;
  final List<String> dartFiles;
  final String? tier;
  final bool formatJson;
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
  bool formatJson = false;

  var i = 0;
  while (i < args.length) {
    final arg = args[i];
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
    if (arg == '--format') {
      i++;
      if (i < args.length) {
        formatJson = args[i].toLowerCase() == 'json';
        i++;
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
    ),
  );
}
