/// CLI command: `dart run saropa_lints migrate-config`
///
/// Moves `log_level`, `lane`, `memory_mode`, and `rule_packs` from the legacy
/// `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level
/// keys in `analysis_options_custom.yaml`, eliminating false
/// `unsupported_option` warnings from the Dart SDK's plugin-block validator.
///
/// Safe to run multiple times — already-migrated keys are skipped.
library;

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:saropa_lints/src/config/analysis_options_rule_packs.dart'
    show parseRulePacksEnabledList;
import 'package:saropa_lints/src/config/runtime_tier_cap.dart'
    show parseScalarFromPluginBlock;
import 'package:saropa_lints/src/init/custom_overrides_core.dart'
    show writeRulePacksToCustomFile;

/// Scalar keys that were moved from the plugin block to the custom file.
const _migrateKeys = <String>{'log_level', 'lane', 'memory_mode'};

/// Pattern matching the indented `rule_packs:` block (with `enabled:` list)
/// inside the plugin block. Used to remove it from analysis_options.yaml.
final _pluginRulePacksBlock = RegExp(
  r'^[ \t]+rule_packs:\s*\n(?:[ \t]+enabled:\s*\n)?(?:[ \t]+-\s+\S+.*\n|[ \t]+#[^\n]*\n|[ \t]*\n)*',
  multiLine: true,
);

/// Entry point for `dart run saropa_lints migrate-config`.
///
/// Flags:
///   `--dry-run`  Preview what would change without writing any files.
///   First positional arg is the project directory (defaults to `.`).
void main(List<String> args) {
  // Parse --dry-run flag and extract the directory argument.
  final dryRun = args.contains('--dry-run');
  final positional = args.where((a) => a != '--dry-run').toList();
  final dir = positional.isNotEmpty ? positional.first : '.';
  final sep = Platform.pathSeparator;

  final mainFile = File('$dir${sep}analysis_options.yaml');
  if (!mainFile.existsSync()) {
    print('No analysis_options.yaml found in $dir');
    exitCode = 1;
    return;
  }

  // Normalize line endings so removal regexes (which match `\n`) work on
  // Windows files that may contain `\r\n`.
  final mainContent =
      mainFile.readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  // --- Scalar keys (log_level, lane, memory_mode) ---
  final found = <String, String>{};
  for (final key in _migrateKeys) {
    final value = parseScalarFromPluginBlock(mainContent, {key});
    if (value != null) {
      found[key] = value;
    }
  }

  // --- Nested key: rule_packs ---
  final rulePackIds = parseRulePacksEnabledList(mainContent);

  if (found.isEmpty && rulePackIds.isEmpty) {
    print('Nothing to migrate — no legacy config keys found under '
        'plugins > saropa_lints:');
    return;
  }

  // Read or create the custom file.
  final customFile = File('$dir${sep}analysis_options_custom.yaml');
  var customContent = customFile.existsSync()
      ? customFile.readAsStringSync().replaceAll('\r\n', '\n').replaceAll('\r', '\n')
      : '';

  // Only add scalar keys that aren't already in the custom file, but always
  // remove them from the legacy plugin block (even when skipped) so the
  // unsupported_option warning is eliminated.
  final added = <String>[];
  for (final entry in found.entries) {
    // Check if already present as a top-level key.
    final existing = RegExp(
      '^${entry.key}:\\s',
      multiLine: true,
    ).hasMatch(customContent);
    if (existing) {
      print('  SKIP ${entry.key}: already in analysis_options_custom.yaml');
    } else {
      // Append the key to the custom file.
      if (customContent.isNotEmpty && !customContent.endsWith('\n')) {
        customContent += '\n';
      }
      customContent += '${entry.key}: ${entry.value}\n';
      print('  MOVE ${entry.key}: ${entry.value}');
    }
    // Track all found keys for removal from the main file, regardless of
    // whether they were added to or already existed in the custom file.
    added.add(entry.key);
  }

  // Write the custom file with the scalar keys first.
  if (added.isNotEmpty && !dryRun) {
    customFile.writeAsStringSync(customContent);
  }

  // Migrate rule_packs: write to custom file, remove from main file.
  // Always remove from the legacy block even when skipped, to eliminate
  // the unsupported_option warning.
  var hasLegacyRulePacks = rulePackIds.isNotEmpty;
  if (rulePackIds.isNotEmpty) {
    // Check if rule_packs already exists in the custom file — reuse the
    // in-memory content (may have been updated with scalar keys above).
    final customHasRulePacks = RegExp(
      r'^rule_packs:\s',
      multiLine: true,
    ).hasMatch(customContent);
    if (customHasRulePacks) {
      print('  SKIP rule_packs: already in analysis_options_custom.yaml');
    } else {
      // Write rule_packs block to the custom file using the shared helper.
      if (!dryRun) {
        writeRulePacksToCustomFile(customFile, rulePackIds);
      }
      print('  MOVE rule_packs: [${rulePackIds.join(', ')}]');
    }
  }

  if (found.isEmpty && !hasLegacyRulePacks) {
    print('All keys already migrated — nothing to do.');
    return;
  }

  // Remove the scalar keys from the main file's plugin block. Match a full
  // line like `    log_level: info  # comment` and remove it (including the
  // newline). Indented so it's inside the plugin block, not top-level.
  var updatedMain = mainContent;
  for (final key in added) {
    updatedMain = updatedMain.replaceAll(
      RegExp('^[ \\t]+$key:\\s+[^\\n]*\\n', multiLine: true),
      '',
    );
  }

  // Remove the rule_packs block from the main file (even when skipped —
  // the goal is to eliminate the warning, not just copy the value).
  if (hasLegacyRulePacks) {
    updatedMain = updatedMain.replaceAll(_pluginRulePacksBlock, '');
  }

  if (!dryRun) {
    mainFile.writeAsStringSync(updatedMain);
  }

  final totalMoved = added.length + (hasLegacyRulePacks ? 1 : 0);
  print('');
  if (dryRun) {
    print('[dry-run] Would migrate $totalMoved key(s) to '
        'analysis_options_custom.yaml. No files were modified.');
  } else {
    print('Migrated $totalMoved key(s) to analysis_options_custom.yaml.');
    print('The unsupported_option warnings will no longer appear.');
  }
}
