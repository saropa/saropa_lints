/// Tier help display.
library;

import 'package:saropa_lints/src/init/cli_args.dart';

// ignore: avoid_print
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
