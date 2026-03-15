/// Tier selection UI, help display, and what's new.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Prompts the user to select a tier interactively.
///
/// Defaults to the tier found in the existing analysis_options.yaml,
/// or 'essential' for fresh setups. In non-interactive mode (piped input,
/// CI), uses the default without prompting.
String promptForTier({required String targetDir}) {
  final String defaultTier =
      detectExistingTier(targetDir: targetDir) ?? 'essential';

  if (!stdin.hasTerminal) {
    log.terminal(
      '${InitColors.dim}Non-interactive: using default tier '
      '($defaultTier)${InitColors.reset}',
    );
    return defaultTier;
  }

  log.terminal('${InitColors.bold}Select a tier:${InitColors.reset}');
  log.terminal('');

  for (final String name in tierOrder) {
    final int? id = tierIds[name];
    if (id == null) continue;
    final int count = tiers.getRulesForTier(name).length;
    final String desc = tierDescriptions[name] ?? '';
    final String label = tierColor(name.padRight(13));
    final String countStr =
        '${InitColors.dim}(~$count rules)${InitColors.reset}';
    final String isDefault = name == defaultTier
        ? ' ${InitColors.cyan}(default)${InitColors.reset}'
        : '';
    log.terminal('  $id. $label $countStr  $desc$isDefault');
  }

  log.terminal('');
  stdout.write(
    '${InitColors.cyan}Enter tier (1-5) '
    '[default: ${tierIds[defaultTier]}]: ${InitColors.reset}',
  );

  final String input = stdin.readLineSync()?.trim() ?? '';

  if (input.isEmpty) return defaultTier;

  final String? resolved = resolveTier(input);

  if (resolved != null) return resolved;

  log.terminal(
    '${InitColors.yellow}Invalid selection "$input", '
    'using $defaultTier${InitColors.reset}',
  );
  return defaultTier;
}

/// Reads the existing analysis_options.yaml and returns the tier name
/// from the `# Tier: <name>` comment, or null if not found.
String? detectExistingTier({required String targetDir}) {
  final file = File('$targetDir/analysis_options.yaml');

  if (!file.existsSync()) return null;

  final match = RegExp(r'# Tier:\s*(\w+)').firstMatch(file.readAsStringSync());

  if (match == null) return null;

  final group = match.group(1);
  if (group == null) return null;
  final tier = group.toLowerCase();
  return tierIds.containsKey(tier) ? tier : null;
}

void printUsage() {
  print('''

Saropa Lints Configuration Generator (headless)

NOTE: The VS Code extension is the recommended way to set up
and configure Saropa Lints. This CLI is for CI/scripting only.

Generates analysis_options.yaml with explicit rule configuration
for the native analyzer plugin system.

IMPORTANT: This tool preserves:
  - All non-plugins sections (analyzer, linter, formatter, etc.)
  - User customizations in plugins.saropa_lints.diagnostics (unless --reset)

Usage: dart run saropa_lints:init --tier <tier> [options]

Options:
  -t, --tier <tier>     Tier level (1-5 or name, defaults to recommended)
  -o, --output <file>   Output file (default: analysis_options.yaml)
  --target <path>       Target project directory (default: current directory)
  --stylistic-all       Bulk-enable all stylistic rules
  --no-stylistic        Exclude stylistic rules (default)
  --fix-ignores         Auto-convert v4 ignore comments
  --reset               Discard user customizations and reset to tier defaults
  --dry-run             Preview output without writing
  -h, --help            Show this help message

Tiers:
${tierOrder.map((String t) => '  ${tierIds[t]}. $t\n     ${tierDescriptions[t]}').join('\n')}

Examples:
  dart run saropa_lints:init --tier recommended
  dart run saropa_lints:init --tier comprehensive
  dart run saropa_lints:init --tier 4
  dart run saropa_lints:init --tier essential --reset
  dart run saropa_lints:init --tier professional --target /path/to/project
  dart run saropa_lints:init --tier recommended --stylistic-all
  dart run saropa_lints:init --dry-run --tier recommended

After generating, run `dart analyze` to verify.
''');
}
