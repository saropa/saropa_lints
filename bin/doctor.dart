/// CLI command: `dart run saropa_lints doctor`
///
/// Scans a consumer project's configuration for common misconfigurations:
/// keys in the wrong file, missing custom file, stale legacy entries, and
/// other issues that produce SDK warnings or silent misbehavior.
///
/// Exit codes:
///   0 — no issues found
///   1 — one or more issues found (printed as a fix list)
library;

// ignore_for_file: avoid_print

import 'dart:io';

/// Keys that belong in `analysis_options_custom.yaml`, NOT under `plugins:`.
const _customFileKeys = <String>{
  'log_level',
  'lane',
  'memory_mode',
  'rule_packs',
};

/// Entry point for `dart run saropa_lints doctor`.
///
/// First positional arg is the project directory (defaults to `.`).
void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final dir = args.where((a) => !a.startsWith('-')).firstOrNull ?? '.';
  final sep = Platform.pathSeparator;
  final issues = <String>[];

  // --- Check analysis_options.yaml exists ---
  final mainFile = File('$dir${sep}analysis_options.yaml');
  if (!mainFile.existsSync()) {
    print('No analysis_options.yaml found in $dir');
    print('Run `dart run saropa_lints init` to create one.');
    exitCode = 1;
    return;
  }

  final mainContent = mainFile
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  // --- Check for misplaced keys in the plugin block ---
  // Any of _customFileKeys under `plugins > saropa_lints:` triggers the
  // SDK's `unsupported_option` warning.
  for (final key in _customFileKeys) {
    final keyInPluginBlock = RegExp(
      '^[ \\t]+${RegExp.escape(key)}:\\s',
      multiLine: true,
    ).hasMatch(mainContent);
    if (keyInPluginBlock) {
      issues.add(
        '  [$key] found under plugins > saropa_lints: in '
        'analysis_options.yaml — causes unsupported_option warning.',
      );
    }
  }

  // --- Check analysis_options_custom.yaml ---
  final customFile = File('$dir${sep}analysis_options_custom.yaml');
  final customExists = customFile.existsSync();

  if (!customExists) {
    // Only flag missing custom file if there are keys that need it, or if
    // no custom file exists at all (the init command should create one).
    final hasSaropaPlugin = mainContent.contains('saropa_lints:');
    if (hasSaropaPlugin) {
      issues.add(
        '  [custom_file] analysis_options_custom.yaml not found — '
        'run `dart run saropa_lints init` to create one.',
      );
    }
  }

  // --- Check for saropa_lints plugin entry ---
  final hasSaropaPlugin = RegExp(
    r'^\s+saropa_lints:\s*',
    multiLine: true,
  ).hasMatch(mainContent);
  if (!hasSaropaPlugin) {
    issues.add(
      '  [plugin] saropa_lints not found under plugins: in '
      'analysis_options.yaml — the plugin will not load.',
    );
  }

  // --- Check for version key ---
  if (hasSaropaPlugin) {
    final hasVersion = RegExp(
      r'^\s+version:\s+["\x27]?\d',
      multiLine: true,
    ).hasMatch(mainContent);
    if (!hasVersion) {
      issues.add(
        '  [version] No version: constraint under saropa_lints: — '
        'the plugin may resolve to an unexpected version.',
      );
    }
  }

  // --- Report ---
  if (issues.isEmpty) {
    print('No configuration issues found.');
    exitCode = 0;
    return;
  }

  print('Found ${issues.length} issue(s):');
  print('');
  for (final issue in issues) {
    print(issue);
  }
  print('');

  // Suggest fix command if misplaced keys were found.
  final hasMisplacedKeys = _customFileKeys.any(
    (key) => issues.any((i) => i.contains('[$key]')),
  );
  if (hasMisplacedKeys) {
    print('Fix: run `dart run saropa_lints migrate-config`');
  }

  exitCode = 1;
}

void _printUsage() {
  print('saropa_lints doctor — check project configuration for issues');
  print('');
  print('Usage: dart run saropa_lints doctor [directory]');
  print('');
  print('Checks:');
  print('  - Keys misplaced under plugins: that belong in the custom file');
  print('  - Missing analysis_options_custom.yaml');
  print('  - Missing saropa_lints plugin entry');
  print('  - Missing version constraint');
  print('');
  print('Options:');
  print('  -h, --help    Show this help message');
}
