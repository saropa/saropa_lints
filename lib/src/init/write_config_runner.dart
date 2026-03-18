/// Headless config writer: tier + overrides → analysis_options.yaml.
///
/// Used by the VS Code extension to write config without running the full
/// init CLI. No terminal output; all file paths are under [targetDir].
library;

import 'dart:io';

import 'package:saropa_lints/src/init/cli_args.dart';
import 'package:saropa_lints/src/init/config_reader.dart';
import 'package:saropa_lints/src/init/config_writer.dart';
import 'package:saropa_lints/src/init/custom_overrides_core.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/platforms_packages.dart';
import 'package:saropa_lints/src/init/project_info.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;

/// Options for headless config write (extension / CI).
class WriteConfigOptions {
  const WriteConfigOptions({
    required this.targetDir,
    required this.tier,
    this.stylisticAll = false,
    this.reset = false,
    this.outputPath = 'analysis_options.yaml',
  });

  /// Absolute path to the project root (where analysis_options.yaml lives).
  final String targetDir;

  /// Tier name: essential, recommended, professional, comprehensive, pedantic.
  final String tier;

  /// If true, enable all stylistic rules.
  final bool stylisticAll;

  /// If true, do not preserve user customizations from existing analysis_options.yaml.
  final bool reset;

  /// Output filename (relative to [targetDir]) or path.
  final String outputPath;

  /// Resolve output to absolute path.
  String get resolvedOutputPath {
    if (outputPath.contains('/') || outputPath.contains(r'\')) {
      return outputPath;
    }
    return '$targetDir${Platform.pathSeparator}$outputPath';
  }
}

/// Result of [runWriteConfig].
class WriteConfigResult {
  const WriteConfigResult({required this.ok, this.error});

  final bool ok;
  final String? error;
}

void _noOp(String _) {}

/// Writes analysis_options.yaml from tier + analysis_options_custom.yaml.
///
/// Reads or creates analysis_options_custom.yaml under [options.targetDir],
/// computes enabled/disabled rules (tier + overrides + platform + package),
/// merges with existing user customizations unless [options.reset],
/// generates the plugins section and writes the file.
///
/// Produces no terminal output. Returns [WriteConfigResult.ok] true on success.
///
/// Logic is aligned with `init_runner.dart`; keep tier/override/platform/package
/// semantics in sync when changing either.
WriteConfigResult runWriteConfig(WriteConfigOptions options) {
  final targetDir = options.targetDir;
  final resolvedTier = resolveTier(options.tier);
  if (resolvedTier == null) {
    return WriteConfigResult(
      ok: false,
      error:
          'Invalid tier: "${options.tier}". Use: essential, recommended, professional, comprehensive, pedantic.',
    );
  }

  final allRules = tiers.getAllDefinedRules();
  Set<String> enabledRules = tiers.getRulesForTier(resolvedTier);
  Set<String> disabledRules = allRules.difference(enabledRules);

  if (options.stylisticAll) {
    enabledRules = enabledRules.union(tiers.stylisticRules);
    disabledRules = disabledRules.difference(tiers.stylisticRules);
  } else {
    enabledRules = enabledRules.difference(tiers.stylisticRules);
    disabledRules = disabledRules.union(tiers.stylisticRules);
  }

  final overridesFile =
      File('$targetDir${Platform.pathSeparator}analysis_options_custom.yaml');
  Map<String, bool> permanentOverrides = <String, bool>{};
  Map<String, bool> platformSettings =
      Map<String, bool>.of(tiers.defaultPlatforms);
  Map<String, bool> packageSettings =
      Map<String, bool>.of(tiers.defaultPackages);

  if (overridesFile.existsSync()) {
    migrateToMinimalFormat(overridesFile, tiers.stylisticRules, logLine: _noOp);
    ensureMaxIssuesSetting(overridesFile, logLine: _noOp);
    platformSettings = extractPlatformsFromFile(overridesFile);

    final allOverrides = extractOverridesFromFile(overridesFile, allRules);
    for (final entry in allOverrides.entries) {
      if (tiers.stylisticRules.contains(entry.key)) {
        if (entry.value) {
          enabledRules = enabledRules.union(<String>{entry.key});
          disabledRules = disabledRules.difference(<String>{entry.key});
        } else {
          enabledRules = enabledRules.difference(<String>{entry.key});
          disabledRules = disabledRules.union(<String>{entry.key});
        }
      } else {
        permanentOverrides[entry.key] = entry.value;
      }
    }
  } else {
    createCustomOverridesFile(overridesFile);
  }

  packageSettings = detectProjectPackages(
    log,
    targetDir: targetDir,
    logLine: _noOp,
  );

  final platformDisabledRules =
      tiers.getRulesDisabledByPlatforms(platformSettings);
  if (platformDisabledRules.isNotEmpty) {
    enabledRules = enabledRules.difference(platformDisabledRules);
    disabledRules = disabledRules.union(platformDisabledRules);
  }

  final packageDisabledRules =
      tiers.getRulesDisabledByPackages(packageSettings);
  if (packageDisabledRules.isNotEmpty) {
    enabledRules = enabledRules.difference(packageDisabledRules);
    disabledRules = disabledRules.union(packageDisabledRules);
  }

  final outputPath = options.resolvedOutputPath;
  final outputFile = File(outputPath);
  String existingContent = '';
  Map<String, bool> userCustomizations = <String, bool>{};

  if (outputFile.existsSync() && !options.reset) {
    existingContent = outputFile.readAsStringSync();
    final result = extractUserCustomizations(existingContent, allRules);
    userCustomizations = result.customizations;
  } else if (outputFile.existsSync()) {
    existingContent = outputFile.readAsStringSync();
  }

  if (permanentOverrides.isNotEmpty) {
    userCustomizations = {...userCustomizations, ...permanentOverrides};
  }

  final version = getPackageVersion();
  final pluginsYaml = generatePluginsYaml(
    tier: resolvedTier,
    packageVersion: version,
    enabledRules: enabledRules,
    userCustomizations: userCustomizations,
    allRules: allRules,
    platformSettings: platformSettings,
    packageSettings: packageSettings,
  );

  final newContent = replacePluginsSection(existingContent, pluginsYaml);

  try {
    outputFile.writeAsStringSync(newContent);
    return const WriteConfigResult(ok: true);
  } on Exception catch (e) {
    return WriteConfigResult(ok: false, error: e.toString());
  }
}
