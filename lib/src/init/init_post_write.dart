/// Post-write actions for the init tool.
///
/// Handles V4 ignore comment conversion (via --fix-ignores flag),
/// log summary, and analysis hint.
library;

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/migration.dart';

/// Handle post-write actions: V4 conversion (flag-only), log writing.
Future<void> runPostWriteActions({
  required CliArgs cliArgs,
  required bool v4Detected,
  required Set<String> allRules,
  required Set<String> finalEnabled,
  required Set<String> finalDisabled,
  required Map<String, bool> packageSettings,
  required Map<String, bool> platformSettings,
  required String version,
  required String resolvedTier,
  required String targetDir,
}) async {
  // I4: No interactive prompt — use --fix-ignores flag to opt in.
  if (v4Detected && !cliArgs.isDryRun && cliArgs.isFixIgnores) {
    log.terminal(
      '${InitColors.bold}Converting v4 ignore comments...${InitColors.reset}',
    );
    final Map<String, int> ignoreResults = convertIgnoreComments(
      allRules,
      false,
      targetDir: targetDir,
    );
    if (ignoreResults.isEmpty) {
      log.terminal(
        '${InitColors.dim}  No v4 ignore comments found${InitColors.reset}',
      );
    } else {
      final int total = ignoreResults.values.fold(0, (s, c) => s + c);
      log.terminal(
        '${InitColors.green}Converted $total ignore comments in '
        '${ignoreResults.length} files${InitColors.reset}',
      );
      for (final MapEntry<String, int> entry in ignoreResults.entries) {
        log.terminal(
          '${InitColors.dim}  ${entry.key}: ${entry.value}${InitColors.reset}',
        );
      }
    }
  }

  // I4: Interactive stylistic walkthrough removed. Stylistic rules are
  // managed via RULE OVERRIDES in analysis_options_custom.yaml.

  log.terminal('');

  if (!cliArgs.isDryRun) {
    // Write the init log (setup only) BEFORE analysis. The plugin writes
    // its own detailed report (*_saropa_lint_report.log) during analysis.
    log.appendSummary((
      version: version,
      tier: resolvedTier,
      enabled: finalEnabled.length,
      disabled: finalDisabled.length,
      outputPath: cliArgs.outputPath,
    ));
    log.writeFile();
    log.terminal('');

    // I4: Interactive analysis prompt removed. Extension runs analysis
    // automatically; CLI users can run `dart analyze` manually.
    log.terminal(
      '${InitColors.dim}Run `dart analyze` to check your '
      'project.${InitColors.reset}',
    );
  }
}
