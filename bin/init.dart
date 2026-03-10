#!/usr/bin/env dart
// ignore_for_file: avoid_print

library;

import 'dart:developer' as dev;

/// CLI tool to generate analysis_options.yaml with explicit rule configuration.
///
/// ## Purpose
///
/// The native analyzer plugin system requires lint rules to be explicitly
/// enabled in the `diagnostics:` section. This tool generates the full
/// `plugins: saropa_lints: diagnostics:` configuration with explicit
/// `rule_name: true/false` entries for ALL saropa_lints rules.
///
/// ## Usage
///
/// ```bash
/// dart run saropa_lints:init [options]
/// ```
///
/// ## Options
///
/// | Option | Description | Default |
/// |--------|-------------|---------|
/// | `-t, --tier <tier>` | Tier level (1-5 or name) | prompt (or comprehensive) |
/// | `-o, --output <file>` | Output file path | analysis_options.yaml |
/// | `--stylistic` | Interactive stylistic rules walkthrough | default |
/// | `--stylistic-all` | Bulk-enable all stylistic rules (CI) | false |
/// | `--no-stylistic` | Skip stylistic walkthrough entirely | false |
/// | `--reset-stylistic` | Clear reviewed markers, re-walkthrough | false |
/// | `--reset` | Discard user customizations | false |
/// | `--dry-run` | Preview output without writing | false |
/// | `-h, --help` | Show help message | - |
///
/// ## Tiers
///
/// 1. **essential** - Critical rules (~340): crashes, security, memory leaks
/// 2. **recommended** - Essential + accessibility, performance (~850)
/// 3. **professional** - Recommended + architecture, testing (~1590)
/// 4. **comprehensive** - Professional + thorough coverage (~1640)
/// 5. **pedantic** - All rules enabled (~1650)
///
/// ## Preservation Behavior
///
/// When regenerating an existing file, this tool preserves:
/// - All non-plugins sections (analyzer, linter, formatter, etc.)
/// - User customizations in plugins.saropa_lints.diagnostics (unless --reset)
///
/// User customizations appear first in the generated output, making it easy
/// to see which rules have been manually configured.
///
/// ## Exit Codes
///
/// - 0: Success
/// - 1: Invalid tier specified
/// - 2: File write error
///
/// ## Examples
///
/// ```bash
/// # Interactive tier selection (prompts if no --tier given)
/// dart run saropa_lints:init
///
/// # Start with essential tier for legacy projects
/// dart run saropa_lints:init --tier essential
///
/// # Bulk-enable all stylistic rules (for CI)
/// dart run saropa_lints:init --tier professional --stylistic-all
///
/// # Skip the interactive stylistic walkthrough
/// dart run saropa_lints:init --no-stylistic
///
/// # Preview without writing
/// dart run saropa_lints:init --dry-run
///
/// # Reset to tier defaults, discarding customizations
/// dart run saropa_lints:init --tier recommended --reset
/// ```
///
/// ## See Also
///
/// - [README.md](../README.md) for tier philosophy and adoption strategy
/// - [PERFORMANCE.md](../PERFORMANCE.md) for performance considerations
/// - [CONTRIBUTING.md](../CONTRIBUTING.md) for adding new rules

import 'dart:convert' show utf8;
import 'dart:io';

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/preflight.dart';
import 'package:saropa_lints/src/init/project_info.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/validation.dart';
import 'package:saropa_lints/src/init/config_reader.dart';
import 'package:saropa_lints/src/init/config_writer.dart';
import 'package:saropa_lints/src/init/custom_overrides_core.dart';
import 'package:saropa_lints/src/init/platforms_packages.dart';
import 'package:saropa_lints/src/init/stylistic_section.dart';
import 'package:saropa_lints/src/init/migration.dart';
import 'package:saropa_lints/src/init/stylistic_walkthrough.dart';
import 'package:saropa_lints/src/init/tier_ui.dart';
import 'package:saropa_lints/src/report/analysis_reporter.dart'
    show AnalysisReporter;
import 'package:saropa_lints/src/tiers.dart' as tiers;
import 'whats_new.dart' show AnsiColors, formatWhatsNew;



/// Append a detailed rule-by-rule listing to the log buffer.
///
/// Written to the log file only, not printed to the terminal.
/// Each rule gets one line: `+ SEVERITY  tier  rule_name  [note]`.
void _appendDetailedReport({
  required Set<String> enabledRules,
  required Set<String> disabledRules,
  required Map<String, bool> userCustomizations,
  required Set<String> platformFilteredRules,
  required Set<String> packageFilteredRules,
}) {
  final allRules = [...enabledRules, ...disabledRules]..sort();

  log.buffer.writeln('');
  log.buffer.writeln('${'=' * 80}');
  log.buffer.writeln('DETAILED RULE REPORT (${allRules.length} rules)');
  log.buffer.writeln('${'=' * 80}');
  log.buffer.writeln('');

  for (final rule in allRules) {
    final enabled = enabledRules.contains(rule);
    final marker = enabled ? '+' : '-';
    final severity = getRuleSeverity(rule).padRight(7);
    final tierName = tierToString(getRuleTierFromMetadata(rule)).padRight(13);
    final note = detailNote(
      rule,
      userCustomizations,
      platformFilteredRules,
      packageFilteredRules,
    );
    log.buffer.writeln('$marker $severity $tierName $rule$note');
  }

  log.buffer.writeln('');
  log.buffer.writeln('Legend: + enabled, - disabled');
  log.buffer.writeln('${'=' * 80}');
}




/// Display "what's new" from CHANGELOG.md (non-blocking, fail-safe).
void _showWhatsNew(String version, String? packageDir) {
  if (version == 'unknown' || packageDir == null) return;

  final lines = formatWhatsNew(
    packageDir: packageDir,
    version: version,
    colors: AnsiColors(
      bold: InitColors.bold,
      cyan: InitColors.cyan,
      dim: InitColors.dim,
      reset: InitColors.reset,
    ),
  );

  for (final line in lines) {
    log.terminal(line);
  }
}

/// Main entry point for the CLI tool.
Future<void> main(List<String> args) async {
  // Enable ANSI color support on Windows 10+
  tryEnableAnsiWindows();

  // Initialize log timestamp for report file
  final now = DateTime.now();
  log.timestamp =
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

  // Move old reports from reports/ root into date subfolders
  migrateOldReports();

  // Get version, source, and package directory early for logging + what's new
  final version = getPackageVersion();
  final source = getPackageSource();
  final rootUri = getSaropaLintsRootUri();
  final packageDir = rootUri != null ? rootUriToPath(rootUri) : null;

  // Add header to log buffer
  log.buffer.writeln('=' * 80);
  log.buffer.writeln('SAROPA LINTS CONFIGURATION LOG');
  log.buffer.writeln('Version: $version');
  log.buffer.writeln('Source: $source');
  log.buffer.writeln('Generated: ${now.toIso8601String()}');
  log.buffer.writeln('Arguments: ${args.join(' ')}');
  log.buffer.writeln('=' * 80);
  log.buffer.writeln();

  final CliArgs cliArgs = parseArguments(args);

  if (cliArgs.isShowHelp) {
    printUsage();
    return;
  }

  log.terminal('');
  log.terminal('${InitColors.cyan}SAROPA LINTS${InitColors.reset} v$version');
  log.terminal('${InitColors.dim}Source: $source${InitColors.reset}');
  _showWhatsNew(version, packageDir);
  log.terminal('');

  // Resolve tier (handle numeric input, or prompt if not specified)
  String? tier = resolveTier(cliArgs.tier);

  if (tier == null && cliArgs.tier != null) {
    // User explicitly provided an invalid tier name/number
    log.terminal(errorText('✗ Error: Invalid tier "${cliArgs.tier}"'));
    log.terminal('');
    log.terminal('Valid tiers:');
    for (final MapEntry<String, int> entry in tierIds.entries) {
      log.terminal('  ${entry.value} or ${tierColor(entry.key)}');
    }
    exitCode = 1;
    return;
  }

  if (tier == null) {
    // No tier specified — prompt interactively or fall back to default
    tier = promptForTier();
  }
  final String resolvedTier = tier;

  log.terminal(
    '${InitColors.bold}Tier:${InitColors.reset} ${tierColor(resolvedTier)} (level ${tierIds[resolvedTier]})',
  );
  log.terminal(
    '${InitColors.dim}${tierDescriptions[resolvedTier]}${InitColors.reset}',
  );
  log.terminal('');

  // Run pre-flight validation checks (non-fatal warnings)
  runPreflightChecks(log,version: version);

  // tiers.dart is the source of truth for all rules
  // A unit test validates that all plugin rules are in tiers.dart
  final Set<String> allRules = tiers.getAllDefinedRules();
  final Set<String> enabledRules = tiers.getRulesForTier(resolvedTier);
  final Set<String> disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in).
  // --stylistic-all: bulk-enable all (old --stylistic behavior for CI).
  // --stylistic / default: interactive walkthrough (handled after config gen).
  // --no-stylistic: skip entirely, stylistic rules stay as-is in custom yaml.
  Set<String> finalEnabled = enabledRules;
  Set<String> finalDisabled = disabledRules;

  if (cliArgs.isStylisticAll) {
    finalEnabled = finalEnabled.union(tiers.stylisticRules);
    finalDisabled = finalDisabled.difference(tiers.stylisticRules);
  } else {
    // Stylistic rules are managed in analysis_options_custom.yaml,
    // not in the main diagnostics block. Keep them out of tier output.
    finalEnabled = finalEnabled.difference(tiers.stylisticRules);
    finalDisabled = finalDisabled.union(tiers.stylisticRules);
  }

  // Read or create custom overrides file (survives --reset)
  final File overridesFile = File('analysis_options_custom.yaml');
  Map<String, bool> permanentOverrides = <String, bool>{};
  Map<String, bool> platformSettings = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );
  Map<String, bool> packageSettings = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (overridesFile.existsSync()) {
    // Ensure all sections exist in the file
    ensureMaxIssuesSetting(overridesFile);
    ensurePlatformsSetting(overridesFile);
    ensurePackagesSetting(overridesFile);
    ensureStylisticRulesSection(overridesFile);
    platformSettings = extractPlatformsFromFile(overridesFile);
    packageSettings = extractPackagesFromFile(overridesFile);

    // Extract overrides and partition stylistic from non-stylistic
    final allOverrides = extractOverridesFromFile(overridesFile, allRules);
    for (final entry in allOverrides.entries) {
      if (tiers.stylisticRules.contains(entry.key)) {
        // Stylistic overrides apply on top of --stylistic flag
        if (entry.value) {
          finalEnabled = finalEnabled.union(<String>{entry.key});
          finalDisabled = finalDisabled.difference(<String>{entry.key});
        } else {
          finalEnabled = finalEnabled.difference(<String>{entry.key});
          finalDisabled = finalDisabled.union(<String>{entry.key});
        }
      } else {
        permanentOverrides[entry.key] = entry.value;
      }
    }
  } else {
    // Auto-detect packages from pubspec.yaml for first-time setup
    packageSettings = detectProjectPackages(log);

    // Create the custom overrides file with a helpful header
    createCustomOverridesFile(overridesFile);
    log.terminal(
      '${InitColors.green}✓ Created:${InitColors.reset} '
      'analysis_options_custom.yaml',
    );
  }

  // Apply platform filtering - disable rules for disabled platforms
  final Set<String> platformDisabledRules = tiers.getRulesDisabledByPlatforms(
    platformSettings,
  );

  if (platformDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(platformDisabledRules);
    finalDisabled = finalDisabled.union(platformDisabledRules);

    final disabledPlatforms = platformSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    log.terminal(
      '${InitColors.yellow}Platforms disabled:${InitColors.reset} '
      '${disabledPlatforms.join(', ')} '
      '${InitColors.dim}(${platformDisabledRules.length} rules affected)${InitColors.reset}',
    );
  }

  // Apply package filtering - disable rules for disabled packages
  final Set<String> packageDisabledRules = tiers.getRulesDisabledByPackages(
    packageSettings,
  );

  if (packageDisabledRules.isNotEmpty) {
    finalEnabled = finalEnabled.difference(packageDisabledRules);
    finalDisabled = finalDisabled.union(packageDisabledRules);

    final disabledPackages = packageSettings.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();
    log.terminal(
      '${InitColors.yellow}Packages disabled:${InitColors.reset} '
      '${disabledPackages.join(', ')} '
      '${InitColors.dim}(${packageDisabledRules.length} rules affected)${InitColors.reset}',
    );
  }

  // Read existing config and extract user customizations
  final File outputFile = File(cliArgs.outputPath);
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  // Track whether v4 migration occurred (used for ignore comment tip)
  bool v4Detected = false;
  Map<String, bool> v4MigratedRules = <String, bool>{};
  // Count rule names normalized from v6 (mixed-case) to v7 (lowerCaseName)
  final List<int> v7NormalizedCount = [0];

  if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();

    // Auto-detect and migrate v4 custom_lint: format
    if (detectV4Config(existingContent)) {
      v4Detected = true;
      log.terminal('');
      log.terminal(
        '${InitColors.yellow}--- V4 MIGRATION DETECTED ---${InitColors.reset}',
      );
      log.terminal(
        '${InitColors.yellow}Found custom_lint: section (v4 format)${InitColors.reset}',
      );

      v4MigratedRules = extractV4Rules(existingContent, allRules);
      log.terminal(
        '${InitColors.dim}  Extracted ${v4MigratedRules.length} rule '
        'settings from v4 config${InitColors.reset}',
      );

      existingContent = removeCustomLintSection(existingContent);
      existingContent = removeAnalyzerCustomLintPlugin(existingContent);
      log.terminal(
        '${InitColors.green}Removed custom_lint: section${InitColors.reset}',
      );

      cleanPubspecCustomLint(dryRun: cliArgs.isDryRun);
      log.terminal('');
    }

    if (!cliArgs.isReset) {
      final result = extractUserCustomizations(
        existingContent,
        allRules,
        v7NormalizedCount,
      );
      userCustomizations = result.customizations;

      // cspell:ignore prefer_debugprint
      if (v7NormalizedCount[0] > 0) {
        log.terminal(
          '${InitColors.yellow}--- V7 MIGRATION ---${InitColors.reset}',
        );
        log.terminal(
          '${InitColors.yellow}Normalized ${v7NormalizedCount[0]} rule name(s) '
          'to lowerCaseName (v7 config format).${InitColors.reset}',
        );
        log.terminal(
          '${InitColors.dim}  Update any // ignore: comments to use '
          'lowercase rule names (e.g. prefer_debugprint).${InitColors.reset}',
        );
        log.terminal('');
      }

      // Warn if manual edits in tier sections were recovered
      if (result.tierEdits.isNotEmpty) {
        log.terminal(
          '${InitColors.yellow}⚠ Recovered ${result.tierEdits.length} manually '
          'edited rule(s) from tier sections${InitColors.reset}',
        );
        log.terminal(
          '${InitColors.dim}  Tip: add overrides to '
          'analysis_options_custom.yaml RULE OVERRIDES '
          'section instead${InitColors.reset}',
        );
      }

      // Merge v4 rules as customizations (v5 customizations take precedence)
      // Only import rules where v4 setting differs from v5 tier default
      if (v4MigratedRules.isNotEmpty) {
        final int totalV4 = v4MigratedRules.length;
        v4MigratedRules.removeWhere((rule, enabled) {
          if (enabled) {
            return finalEnabled.contains(rule);
          } else {
            return finalDisabled.contains(rule);
          }
        });
        userCustomizations = {...v4MigratedRules, ...userCustomizations};
        final int skipped = totalV4 - v4MigratedRules.length;
        log.terminal(
          '${InitColors.green}${v4MigratedRules.length} v4 rules imported '
          'as user customizations${InitColors.reset}'
          '${skipped > 0 ? ' ${InitColors.dim}($skipped matched tier defaults, skipped)${InitColors.reset}' : ''}',
        );
      }

      // Warn if suspiciously many customizations (likely corrupted)
      if (userCustomizations.length > 50) {
        log.terminal(
          '${InitColors.red}⚠ ${userCustomizations.length} customizations found - consider --reset${InitColors.reset}',
        );
      }
    } else {
      if (v4MigratedRules.isNotEmpty) {
        log.terminal(
          '${InitColors.yellow}⚠ --reset: discarding ${v4MigratedRules.length} '
          'v4 rule settings (run without --reset to preserve)${InitColors.reset}',
        );
      } else {
        log.terminal(
          '${InitColors.yellow}⚠ --reset: discarding customizations${InitColors.reset}',
        );
      }
    }
  }

  // Merge permanent overrides with user customizations
  // Permanent overrides always take precedence
  if (permanentOverrides.isNotEmpty) {
    userCustomizations = {...userCustomizations, ...permanentOverrides};
  }

  // Count rules by severity for summary
  final Map<String, int> enabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0,
  };
  final Map<String, int> disabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0,
  };

  for (final rule in finalEnabled) {
    final severity = getRuleSeverity(rule);
    enabledBySeverity[severity] = (enabledBySeverity[severity] ?? 0) + 1;
  }
  for (final rule in finalDisabled) {
    final severity = getRuleSeverity(rule);
    disabledBySeverity[severity] = (disabledBySeverity[severity] ?? 0) + 1;
  }

  // Count by tier for enabled rules
  final Map<String, int> enabledByTierCount = {};
  for (final rule in finalEnabled) {
    final tierName = tierToString(getRuleTierFromMetadata(rule));
    enabledByTierCount[tierName] = (enabledByTierCount[tierName] ?? 0) + 1;
  }

  // Compact summary
  log.terminal('');
  final totalRules = finalEnabled.length + finalDisabled.length;
  final disabledPct =
      totalRules > 0 ? (finalDisabled.length * 100 ~/ totalRules) : 0;
  log.terminal(
    '${InitColors.bold}Rules:${InitColors.reset} ${successText('${finalEnabled.length} enabled')} / ${errorText('${finalDisabled.length} disabled')} ${InitColors.dim}($disabledPct%)${InitColors.reset}',
  );
  log.terminal(
    '${InitColors.bold}Severity:${InitColors.reset} ${InitColors.red}${enabledBySeverity['ERROR']} errors${InitColors.reset} · ${InitColors.yellow}${enabledBySeverity['WARNING']} warnings${InitColors.reset} · ${InitColors.cyan}${enabledBySeverity['INFO']} info${InitColors.reset}',
  );

  // Project overrides summary
  final customCount = userCustomizations.length;

  if (customCount > 0) {
    final Map<String, int> customBySeverity = {
      'ERROR': 0,
      'WARNING': 0,
      'INFO': 0,
    };
    for (final rule in userCustomizations.keys) {
      final severity = getRuleSeverity(rule);
      customBySeverity[severity] = (customBySeverity[severity] ?? 0) + 1;
    }
    log.terminal(
      '${InitColors.bold}Project Overrides${InitColors.reset} ${InitColors.dim}(analysis_options_custom.yaml):${InitColors.reset} '
      '$customCount '
      '${InitColors.dim}(${InitColors.reset}'
      '${InitColors.red}${customBySeverity['ERROR']} error${InitColors.reset}, '
      '${InitColors.yellow}${customBySeverity['WARNING']} warning${InitColors.reset}, '
      '${InitColors.cyan}${customBySeverity['INFO']} info${InitColors.reset}'
      '${InitColors.dim})${InitColors.reset}',
    );
  }
  log.terminal('');

  // Append rule-by-rule detail to the log file (not printed to terminal)
  _appendDetailedReport(
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    platformFilteredRules: platformDisabledRules,
    packageFilteredRules: packageDisabledRules,
  );

  // Generate the new plugins section with proper formatting
  final String pluginsYaml = generatePluginsYaml(
    tier: resolvedTier,
    packageVersion: version,
    enabledRules: finalEnabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
    includeStylistic: cliArgs.isStylisticIncluded,
    platformSettings: platformSettings,
    packageSettings: packageSettings,
  );

  // Replace plugins section in existing content, preserving everything else
  final String newContent = replacePluginsSection(
    existingContent,
    pluginsYaml,
  );

  if (cliArgs.isDryRun) {
    log.terminal('${InitColors.yellow}━━━ DRY RUN ━━━${InitColors.reset}');
    log.terminal(
      '${InitColors.dim}Would write to: ${cliArgs.outputPath}${InitColors.reset}',
    );
    log.terminal('');

    // Show preview of plugins section only
    final List<String> lines = pluginsYaml.split('\n');
    const int previewLines = 100;
    log.terminal(
      '${InitColors.bold}Preview${InitColors.reset} ${InitColors.dim}(first $previewLines of ${lines.length} lines):${InitColors.reset}',
    );
    log.terminal('${InitColors.dim}${'─' * 60}${InitColors.reset}');
    for (int i = 0; i < previewLines && i < lines.length; i++) {
      log.terminal(lines[i]);
    }
    if (lines.length > previewLines) {
      log.terminal(
        '${InitColors.dim}... (${lines.length - previewLines} more lines)${InitColors.reset}',
      );
    }
    return;
  }

  // Skip writing if the file content hasn't changed
  if (newContent == existingContent) {
    log.terminal(
      '${InitColors.dim}✓ No changes needed: ${cliArgs.outputPath}${InitColors.reset}',
    );
  } else {
    // Create backup before overwriting
    try {
      final outputDir = outputFile.parent.path;
      final outputName = cliArgs.outputPath.split('/').last.split('\\').last;
      final backupPath = '$outputDir/${log.timestamp}_$outputName.bak';
      outputFile.copySync(backupPath);
    } on Exception catch (e, st) {
      dev.log('Backup before overwrite failed', error: e, stackTrace: st);
    }

    try {
      outputFile.writeAsStringSync(newContent);
      log.terminal('${successText('✓ Written to:')} ${cliArgs.outputPath}');
    } on Exception catch (e, st) {
      dev.log('Failed to write config file', error: e, stackTrace: st);
      log.terminal(errorText('✗ Failed to write file: $e'));
      exitCode = 2;
      return;
    }
  }

  // Validate the written file has the critical sections
  validateWrittenConfig(log,cliArgs.outputPath, allRules.length);

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
    final File overridesForWalkthrough = File('analysis_options_custom.yaml');
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
    stdout.write('${InitColors.cyan}Run analysis now? [y/N]: ${InitColors.reset}');
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';

    if (response == 'y' || response == 'yes') {
      log.terminal('');
      log.terminal('${InitColors.bold}Running: dart analyze${InitColors.reset}');
      log.terminal('${'─' * 60}');

      // Stream output to terminal. The plugin's AnalysisReporter writes
      // the structured results to a separate *_saropa_lint_report.log.
      final process = await Process.start(
          'dart',
          [
            'analyze',
          ],
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
