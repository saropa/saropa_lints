/// CLI argument parsing for the saropa_lints init tool.
library;

/// All available tiers in order of strictness.
const List<String> tierOrder = <String>[
  'essential',
  'recommended',
  'professional',
  'comprehensive',
  'pedantic',
];

/// Map tier names to numeric IDs for user convenience.
const Map<String, int> tierIds = <String, int>{
  'essential': 1,
  'recommended': 2,
  'professional': 3,
  'comprehensive': 4,
  'pedantic': 5,
};

/// Tier descriptions for display.
const Map<String, String> tierDescriptions = <String, String>{
  'essential':
      'Critical rules preventing crashes, security holes, memory leaks',
  'recommended': 'Essential + accessibility, performance patterns',
  'professional': 'Recommended + architecture, testing, documentation',
  'comprehensive': 'Professional + thorough coverage (recommended)',
  'pedantic': 'All rules enabled (may have conflicts)',
};

/// Struct for parsed CLI arguments.
class CliArgs {
  const CliArgs({
    required this.isShowHelp,
    required this.isDryRun,
    required this.isReset,
    required this.isStylisticIncluded,
    required this.isStylisticAll,
    required this.isNoStylistic,
    required this.isStylisticReset,
    required this.isFixIgnores,
    required this.outputPath,
    required this.tier,
  });

  final bool isShowHelp;
  final bool isDryRun;
  final bool isReset;

  /// --stylistic: triggers interactive walkthrough (was bulk-enable in v4).
  final bool isStylisticIncluded;

  /// --stylistic-all: bulk-enable all stylistic rules (old --stylistic
  /// behavior, useful for CI/non-interactive).
  final bool isStylisticAll;

  /// --no-stylistic: skip the stylistic walkthrough entirely.
  final bool isNoStylistic;

  /// --reset-stylistic: clear all [reviewed] markers and re-walkthrough.
  final bool isStylisticReset;

  final bool isFixIgnores;
  final String outputPath;
  final String? tier;
}

/// Parse CLI arguments into a [CliArgs] struct.
CliArgs parseArguments(List<String> args) {
  final bool showHelp = args.contains('--help') || args.contains('-h');
  final bool dryRun = args.contains('--dry-run');
  final bool reset = args.contains('--reset');
  final bool includeStylistic = args.contains('--stylistic');
  final bool stylisticAll = args.contains('--stylistic-all');
  final bool noStylistic = args.contains('--no-stylistic');
  final bool resetStylistic = args.contains('--reset-stylistic');
  final bool fixIgnores = args.contains('--fix-ignores');

  String outputPath = 'analysis_options.yaml';
  int outputIndex = args.indexOf('--output');

  if (outputIndex == -1) {
    outputIndex = args.indexOf('-o');
  }

  if (outputIndex != -1) {
    if (outputIndex + 1 < args.length &&
        !args[outputIndex + 1].startsWith('-')) {
      outputPath = args[outputIndex + 1];
    } else {
      // ignore: avoid_print
      print(
        'Warning: --output requires a file path. '
        'Using default: $outputPath',
      );
    }
  }

  String? requestedTier;
  int tierIndex = args.indexOf('--tier');

  if (tierIndex == -1) {
    tierIndex = args.indexOf('-t');
  }

  if (tierIndex != -1) {
    if (tierIndex + 1 < args.length && !args[tierIndex + 1].startsWith('-')) {
      requestedTier = args[tierIndex + 1];
    } else {
      // --tier without a value: warn and fall through to prompt/default
      // ignore: avoid_print
      print(
        'Warning: --tier requires a value (1-5 or tier name). '
        'Will prompt for selection.',
      );
    }
  }

  return CliArgs(
    isShowHelp: showHelp,
    isDryRun: dryRun,
    isReset: reset,
    isStylisticIncluded: includeStylistic,
    isStylisticAll: stylisticAll,
    isNoStylistic: noStylistic,
    isStylisticReset: resetStylistic,
    isFixIgnores: fixIgnores,
    outputPath: outputPath,
    tier: requestedTier,
  );
}

/// Resolve a tier input (numeric 1-5 or name) to a canonical tier name.
///
/// Returns `null` if the input is not a valid tier.
String? resolveTier(String? input) {
  if (input == null) return null;

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
