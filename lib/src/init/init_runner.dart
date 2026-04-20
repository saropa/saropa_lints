/// Init tool orchestration — main workflow logic.
library;

import 'dart:developer' as dev;
import 'dart:io';

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart';
import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/config_reader.dart';
import 'package:saropa_lints/src/init/config_writer.dart';
import 'package:saropa_lints/src/init/custom_overrides_core.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/init_post_write.dart';
import 'package:saropa_lints/src/init/migration.dart';
import 'package:saropa_lints/src/init/platforms_packages.dart';
import 'package:saropa_lints/src/init/preflight.dart';
import 'package:saropa_lints/src/init/rule_packs_init.dart';
import 'package:saropa_lints/src/init/project_info.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/tier_ui.dart';
import 'package:saropa_lints/src/init/validation.dart';
import 'package:saropa_lints/src/init/whats_new.dart'
    show AnsiColors, formatWhatsNew;
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Append a detailed rule-by-rule listing to the log buffer.
///
/// Written to the log file only, not printed to the terminal.
/// Each rule gets one line: `+ SEVERITY  tier  rule_name  [note]`.
void appendDetailedReport({
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
void showWhatsNew(String version, String? packageDir) {
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

/// Run the init configuration tool.
Future<void> runInit(List<String> args) async {
  // Enable ANSI color support on Windows 10+
  tryEnableAnsiWindows();

  // Initialize log timestamp for report file.
  // Fix: prefer_utc_for_storage — log file names are written to disk and
  // may be consumed across time zones; UTC keeps ordering stable.
  final now = DateTime.now().toUtc();
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
  // Fix: prefer_utc_for_storage — explicit .toUtc() at the call site so the
  // rule sees timezone normalization at the usage site.
  log.buffer.writeln('Generated: ${now.toUtc().toIso8601String()}');
  log.buffer.writeln('Arguments: ${args.join(' ')}');
  log.buffer.writeln('=' * 80);
  log.buffer.writeln();

  final CliArgs cliArgs = parseArguments(args);

  if (cliArgs.isShowHelp) {
    printUsage();

    return;
  }

  // Resolve target directory (--target <path> or current directory)
  final String targetDir = cliArgs.targetDir != null
      ? Directory(cliArgs.targetDir!).absolute.path
      : Directory.current.path;

  if (cliArgs.listPacksOnly) {
    printRulePacksInitSummary(targetDir: targetDir);

    return;
  }

  if (cliArgs.enablePackIds.isNotEmpty) {
    for (final String id in cliArgs.enablePackIds) {
      if (!knownRulePackIds.contains(id)) {
        stderr.writeln('Unknown rule pack: $id');
        stderr.writeln(
          'Valid ids: ${(knownRulePackIds.toList()..sort()).join(', ')}',
        );
        exitCode = 1;
        return;
      }
    }
  }

  log.terminal('');
  log.terminal('${InitColors.cyan}SAROPA LINTS${InitColors.reset} v$version');
  log.terminal('${InitColors.dim}Source: $source${InitColors.reset}');
  if (cliArgs.targetDir != null) {
    log.terminal('${InitColors.bold}Target:${InitColors.reset} $targetDir');
  }
  showWhatsNew(version, packageDir);
  // I4: Deprecation notice — extension is the supported setup path.
  log.terminal(
    '${InitColors.yellow}Note: CLI init is deprecated. '
    'Use the Saropa Lints VS Code extension for setup.${InitColors.reset}',
  );
  log.terminal('');

  // Resolve tier (handle numeric input, or prompt if not specified)
  String? tier = resolveTier(cliArgs.tier);

  if (tier == null && cliArgs.tier != null) {
    // User explicitly provided an invalid tier name/number
    // Default nullable tier to empty string (avoid_nullable_interpolation).
    log.terminal(errorText('✗ Error: Invalid tier "${cliArgs.tier ?? ''}"'));
    log.terminal('');
    log.terminal('Valid tiers:');
    for (final MapEntry<String, int> entry in tierIds.entries) {
      log.terminal('  ${entry.value} or ${tierColor(entry.key)}');
    }
    exitCode = 1;

    return;
  }

  // I4: Default to 'recommended' — interactive tier prompt removed.
  // Use --tier to specify a different tier.
  if (tier == null) {
    tier = 'recommended';
    log.terminal(
      '${InitColors.dim}No --tier specified, defaulting to '
      'recommended${InitColors.reset}',
    );
  }

  final String resolvedTier = tier;

  // Default nullable map lookups to empty string / '?' for safe output
  // (avoid_nullable_interpolation).
  log.terminal(
    '${InitColors.bold}Tier:${InitColors.reset} ${tierColor(resolvedTier)} (level ${tierIds[resolvedTier] ?? '?'})',
  );
  log.terminal(
    '${InitColors.dim}${tierDescriptions[resolvedTier] ?? ''}${InitColors.reset}',
  );
  log.terminal('');

  // Run pre-flight validation checks (non-fatal warnings)
  runPreflightChecks(log, version: version, targetDir: targetDir);

  printRulePacksInitSummary(targetDir: targetDir);

  // tiers.dart is the source of truth for all rules
  // A unit test validates that all plugin rules are in tiers.dart
  final Set<String> allRules = tiers.getAllDefinedRules();
  final Set<String> enabledRules = tiers.getRulesForTier(resolvedTier);
  final Set<String> disabledRules = allRules.difference(enabledRules);

  // Handle stylistic rules (opt-in).
  // --stylistic-all: bulk-enable all stylistic rules (CI/non-interactive).
  // Default: stylistic rules stay as-is in custom yaml overrides.
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
  final File overridesFile = File('$targetDir/analysis_options_custom.yaml');
  Map<String, bool> permanentOverrides = <String, bool>{};
  Map<String, bool> platformSettings = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );
  Map<String, bool> packageSettings = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (overridesFile.existsSync()) {
    // I3: Migrate old bloated format → minimal (one-time, creates .bak).
    // Removed ensurePlatformsSetting — migration preserves platforms;
    // new files include them in the template.
    // Removed ensurePackagesSetting — packages auto-detected from pubspec.
    // Removed ensureStylisticRulesSection — stylistic section eliminated;
    // enabled stylistic rules live in RULE OVERRIDES now.
    migrateToMinimalFormat(overridesFile, tiers.stylisticRules);
    ensureMaxIssuesSetting(overridesFile);
    platformSettings = extractPlatformsFromFile(overridesFile);

    // Extract overrides and partition stylistic from non-stylistic
    final allOverrides = extractOverridesFromFile(overridesFile, allRules);
    for (final entry in allOverrides.entries) {
      if (tiers.stylisticRules.contains(entry.key)) {
        // Stylistic overrides apply on top of --stylistic-all flag
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
    // Create the minimal custom overrides file
    createCustomOverridesFile(overridesFile);
    log.terminal(
      '${InitColors.green}✓ Created:${InitColors.reset} '
      'analysis_options_custom.yaml',
    );
  }

  // I3: Always auto-detect packages from pubspec (not from custom file)
  packageSettings = detectProjectPackages(log, targetDir: targetDir);

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
  final String resolvedOutput =
      cliArgs.outputPath.contains('/') || cliArgs.outputPath.contains('\\')
      ? cliArgs.outputPath
      : '$targetDir/${cliArgs.outputPath}';
  final File outputFile = File(resolvedOutput);
  Map<String, bool> userCustomizations = <String, bool>{};
  String existingContent = '';

  // Track whether v4 migration occurred (used for ignore comment tip)
  bool v4Detected = false;
  Map<String, bool> v4MigratedRules = <String, bool>{};
  // Count rule names normalized from v6 (mixed-case) to v7 (lowerCaseName).
  // MutableCounter wraps the shared counter so nested helpers can increment
  // without parameter mutation or constant-index list access warnings.
  final MutableCounter v7NormalizedCount = MutableCounter();

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

      cleanPubspecCustomLint(dryRun: cliArgs.isDryRun, targetDir: targetDir);
      log.terminal('');
    }

    if (!cliArgs.isReset) {
      final result = extractUserCustomizations(
        existingContent,
        allRules,
        v7NormalizedCount,
      );
      userCustomizations = result.customizations;

      // cspell:ignore prefer_debug_print
      if (v7NormalizedCount.value > 0) {
        log.terminal(
          '${InitColors.yellow}--- V7 MIGRATION ---${InitColors.reset}',
        );
        log.terminal(
          '${InitColors.yellow}Normalized ${v7NormalizedCount.value} rule name(s) '
          'to lowerCaseName (v7 config format).${InitColors.reset}',
        );
        log.terminal(
          '${InitColors.dim}  Update any // ignore: comments to use '
          'lowercase rule names (e.g. prefer_debug_print).${InitColors.reset}',
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
  _printRuleSummary(
    finalEnabled: finalEnabled,
    finalDisabled: finalDisabled,
    userCustomizations: userCustomizations,
  );

  // Append rule-by-rule detail to the log file (not printed to terminal)
  appendDetailedReport(
    enabledRules: finalEnabled,
    disabledRules: finalDisabled,
    userCustomizations: userCustomizations,
    platformFilteredRules: platformDisabledRules,
    packageFilteredRules: packageDisabledRules,
  );

  final List<String> mergedRulePacks = cliArgs.isReset
      ? mergeRulePackIdsForInit(const [], cliArgs.enablePackIds)
      : mergeRulePackIdsForInit(
          parseRulePacksEnabledList(existingContent),
          cliArgs.enablePackIds,
        );

  // Generate the new plugins section with proper formatting
  final String pluginsYaml = generatePluginsYaml(
    tier: resolvedTier,
    packageVersion: version,
    enabledRules: finalEnabled,
    userCustomizations: userCustomizations,
    allRules: allRules,
    platformSettings: platformSettings,
    packageSettings: packageSettings,
    rulePacksEnabled: mergedRulePacks,
  );

  // Replace plugins section in existing content, preserving everything else
  final String newContent = replacePluginsSection(existingContent, pluginsYaml);

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
      // Default nullable timestamp to 'unset' (avoid_nullable_interpolation).
      final backupPath =
          '$outputDir/${log.timestamp ?? 'unset'}_$outputName.bak';
      outputFile.copySync(backupPath);
    } on Exception catch (e, st) {
      dev.log('Backup before overwrite failed', error: e, stackTrace: st);
    }
    // Object fallback (avoid_catch_exception_alone): catch Errors too so
    // programming bugs like StateError aren't silently dropped.
    on Object catch (e, st) {
      dev.log(
        'Backup before overwrite failed (Error)',
        error: e,
        stackTrace: st,
      );
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
    // Object fallback (avoid_catch_exception_alone).
    on Object catch (e, st) {
      dev.log('Failed to write config file (Error)', error: e, stackTrace: st);
      log.terminal(errorText('✗ Failed to write file: $e'));
      exitCode = 2;
      return;
    }
  }

  // Validate the written file has the critical sections
  validateWrittenConfig(log, resolvedOutput, allRules.length);
  await runPostWriteActions(
    cliArgs: cliArgs,
    v4Detected: v4Detected,
    allRules: allRules,
    finalEnabled: finalEnabled,
    finalDisabled: finalDisabled,
    packageSettings: packageSettings,
    platformSettings: platformSettings,
    version: version,
    resolvedTier: resolvedTier,
    targetDir: targetDir,
  );
}

/// Print rule count summary to terminal.
void _printRuleSummary({
  required Set<String> finalEnabled,
  required Set<String> finalDisabled,
  required Map<String, bool> userCustomizations,
}) {
  final Map<String, int> enabledBySeverity = {
    'ERROR': 0,
    'WARNING': 0,
    'INFO': 0,
  };

  for (final rule in finalEnabled) {
    final severity = getRuleSeverity(rule);
    enabledBySeverity[severity] = (enabledBySeverity[severity] ?? 0) + 1;
  }

  log.terminal('');
  final totalRules = finalEnabled.length + finalDisabled.length;
  final disabledPct = totalRules > 0
      ? (finalDisabled.length * 100 ~/ totalRules)
      : 0;
  log.terminal(
    '${InitColors.bold}Rules:${InitColors.reset} ${successText('${finalEnabled.length} enabled')} / ${errorText('${finalDisabled.length} disabled')} ${InitColors.dim}($disabledPct%)${InitColors.reset}',
  );
  // Default nullable severity counts to 0 (avoid_nullable_interpolation):
  // missing severity key means zero counted, not a logical 'null'.
  log.terminal(
    '${InitColors.bold}Severity:${InitColors.reset} ${InitColors.red}${enabledBySeverity['ERROR'] ?? 0} errors${InitColors.reset} \u00b7 ${InitColors.yellow}${enabledBySeverity['WARNING'] ?? 0} warnings${InitColors.reset} \u00b7 ${InitColors.cyan}${enabledBySeverity['INFO'] ?? 0} info${InitColors.reset}',
  );

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
    // Default nullable severity counts to 0 (avoid_nullable_interpolation).
    log.terminal(
      '${InitColors.bold}Project Overrides${InitColors.reset} ${InitColors.dim}(analysis_options_custom.yaml):${InitColors.reset} '
      '$customCount '
      '${InitColors.dim}(${InitColors.reset}'
      '${InitColors.red}${customBySeverity['ERROR'] ?? 0} error${InitColors.reset}, '
      '${InitColors.yellow}${customBySeverity['WARNING'] ?? 0} warning${InitColors.reset}, '
      '${InitColors.cyan}${customBySeverity['INFO'] ?? 0} info${InitColors.reset}'
      '${InitColors.dim})${InitColors.reset}',
    );
  }
  log.terminal('');
}
