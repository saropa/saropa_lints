/// CLI command: `dart run saropa_lints migrate-config`
///
/// Moves `log_level`, `lane`, and `memory_mode` from the legacy
/// `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level
/// keys in `analysis_options_custom.yaml`, eliminating false
/// `unsupported_option` warnings from the Dart SDK's plugin-block validator.
///
/// Safe to run multiple times — already-migrated keys are skipped.
library;

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:saropa_lints/src/config/runtime_tier_cap.dart'
    show parseScalarFromPluginBlock;

/// Keys that were moved from the plugin block to the custom file.
const _migrateKeys = <String>{'log_level', 'lane', 'memory_mode'};

/// Entry point for `dart run saropa_lints migrate-config`.
void main(List<String> args) {
  final dir = args.isNotEmpty ? args.first : '.';
  final sep = Platform.pathSeparator;

  final mainFile = File('$dir${sep}analysis_options.yaml');
  if (!mainFile.existsSync()) {
    print('No analysis_options.yaml found in $dir');
    exitCode = 1;
    return;
  }

  final mainContent = mainFile.readAsStringSync();

  // Find which keys exist in the old plugin block.
  final found = <String, String>{};
  for (final key in _migrateKeys) {
    final value = parseScalarFromPluginBlock(mainContent, {key});
    if (value != null) {
      found[key] = value;
    }
  }

  if (found.isEmpty) {
    print('Nothing to migrate — no legacy config keys found under '
        'plugins > saropa_lints:');
    return;
  }

  // Read or create the custom file.
  final customFile = File('$dir${sep}analysis_options_custom.yaml');
  var customContent = customFile.existsSync()
      ? customFile.readAsStringSync()
      : '';

  // Only add keys that aren't already in the custom file as top-level keys.
  final added = <String>[];
  for (final entry in found.entries) {
    // Check if already present as a top-level key.
    final existing = RegExp(
      '^${entry.key}:\\s',
      multiLine: true,
    ).hasMatch(customContent);
    if (existing) {
      print('  SKIP ${entry.key}: already in analysis_options_custom.yaml');
      continue;
    }
    // Append the key to the custom file.
    if (customContent.isNotEmpty && !customContent.endsWith('\n')) {
      customContent += '\n';
    }
    customContent += '${entry.key}: ${entry.value}\n';
    added.add(entry.key);
    print('  MOVE ${entry.key}: ${entry.value}');
  }

  if (added.isEmpty) {
    print('All keys already migrated — nothing to do.');
    return;
  }

  // Write the custom file with the new keys.
  customFile.writeAsStringSync(customContent);

  // Remove the keys from the main file's plugin block. Match a full line
  // like `    log_level: info  # optional comment` and remove it (including
  // the newline). Indented so it's inside the plugin block, not top-level.
  var updatedMain = mainContent;
  for (final key in added) {
    updatedMain = updatedMain.replaceAll(
      RegExp('^[ \\t]+$key:\\s+[^\\n]*\\n', multiLine: true),
      '',
    );
  }
  mainFile.writeAsStringSync(updatedMain);

  print('');
  print('Migrated ${added.length} key(s) to analysis_options_custom.yaml.');
  print('The unsupported_option warnings will no longer appear.');
}
