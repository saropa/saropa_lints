/// Post-write actions for the init tool.
///
/// Handles V4 ignore comment conversion, stylistic walkthrough,
/// log summary, and optional analysis run.
library;

import 'dart:convert' show utf8;
import 'dart:io';

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/migration.dart';
import 'package:saropa_lints/src/init/stylistic_walkthrough.dart';
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;

/// Handle post-write actions: V4 conversion, stylistic walkthrough, analysis.
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
  // Convert v4 ignore comments (interactive prompt or --fix-ignores flag)
  if (v4Detected && !cliArgs.isDryRun) {
    final bool shouldConvert;
    if (cliArgs.isFixIgnores) {
      shouldConvert = true;
    } else if (!stdin.hasTerminal) {
      // Non-interactive: skip unless explicitly requested
      shouldConvert = false;
    } else {
      log.terminal('');
      stdout.write(
        '${InitColors.cyan}Convert v4 ignore comments to v5 format? [y/N]: '
        '${InitColors.reset}',
      );
      final String resp = stdin.readLineSync()?.toLowerCase().trim() ?? '';
      shouldConvert = resp == 'y' || resp == 'yes';
    }

    if (shouldConvert) {
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
    } else {
      log.terminal(
        '${InitColors.dim}  Skipped ignore comment conversion${InitColors.reset}',
      );
    }
  }

  // ── Interactive stylistic walkthrough ──
  // Runs by default after config generation. Skip with --no-stylistic.
  // --stylistic-all already handled above (bulk-enable).
  if (!cliArgs.isDryRun && !cliArgs.isNoStylistic && !cliArgs.isStylisticAll) {
    final File overridesForWalkthrough =
        File('$targetDir/analysis_options_custom.yaml');
    if (overridesForWalkthrough.existsSync()) {
      runStylisticWalkthrough(
        customFile: overridesForWalkthrough,
        packageSettings: packageSettings,
        platformSettings: platformSettings,
        resetStylistic: cliArgs.isStylisticReset,
      );
    }
  }

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

    // Ask user if they want to run analysis
    stdout.write(
        '${InitColors.cyan}Run analysis now? [y/N]: ${InitColors.reset}');
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

    if (response == 'y' || response == 'yes') {
      log.terminal('');
      log.terminal(
          '${InitColors.bold}Running: dart analyze${InitColors.reset}');
      log.terminal('${'─' * 60}');

      // Stream output to terminal. The plugin's AnalysisReporter writes
      // the structured results to a separate *_saropa_lint_report.log.
      final process = await Process.start(
          'dart',
          [
            'analyze',
          ],
          workingDirectory: targetDir,
          runInShell: true);

      // Use UTF-8 decoder (not SystemEncoding) because Dart processes
      // always write UTF-8, and SystemEncoding on Windows uses the
      // console code page which corrupts Unicode progress bar characters.
      final stdoutDone =
          process.stdout.transform(utf8.decoder).forEach(stdout.write);
      final stderrDone =
          process.stderr.transform(utf8.decoder).forEach(stderr.write);

      // Wait for exit code AND stream drain together so the separator
      // line doesn't appear before trailing analyzer output.
      final exitCodeFuture = process.exitCode;
      await Future.wait([exitCodeFuture, stdoutDone, stderrDone]);
      final analyzeExitCode = await exitCodeFuture;
      log.terminal('${'─' * 60}');

      if (analyzeExitCode == 0) {
        log.terminal(successText('✓ dart analyze passed'));
      } else if (analyzeExitCode <= 2) {
        // Exit codes 1-2 mean "issues found" — the analysis completed.
        log.terminal(successText('✓ dart analyze completed'));
      } else {
        // Exit code 3+ means the analyzer itself failed (internal error,
        // could not analyze, etc.)
        log.terminal(
          errorText('✗ dart analyze failed (exit code $analyzeExitCode)'),
        );
      }

      // Show the plugin's lint report path if one was generated.
      // Retries briefly since the plugin may still be flushing to disk.
      final logTs = log.timestamp;
      if (logTs != null) {
        final dateFolder = AnalysisReporter.dateFolder(logTs);
        final pluginReport = await findNewestPluginReport(dateFolder);
        if (pluginReport != null) {
          log.terminal(
            '${InitColors.bold}Report:${InitColors.reset} '
            '${InitColors.cyan}$pluginReport${InitColors.reset}',
          );
        }
      }
    }
  }
}
