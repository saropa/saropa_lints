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

import 'dart:convert' show JsonEncoder;
import 'dart:io';

import 'package:saropa_lints/src/cli/path_guard.dart';

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

  // WP2 (plans/PLAN_ext_ui_dart_deferred.md): `--format json` for the
  // Project Map Reports tab. `--format` must consume its own value here —
  // the old `args.where((a) => !a.startsWith('-')).firstOrNull` picked the
  // FIRST non-dash token as the project directory, which would have silently
  // swallowed a bare "json" value as the directory the moment this flag was
  // added.
  String? format;
  final positional = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--format' && i + 1 < args.length) {
      format = args[++i];
    } else if (!arg.startsWith('-')) {
      positional.add(arg);
    }
  }
  final asJson = format == 'json';

  // Sanitize the user-supplied project directory to block path traversal.
  final dir = sanitizePath(
    positional.firstOrNull ?? '.',
    label: 'project directory',
  );
  final sep = Platform.pathSeparator;

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

  final customFile = File('$dir${sep}analysis_options_custom.yaml');
  final issues = _diagnose(mainContent, customExists: customFile.existsSync());

  // --- Report ---
  // JSON mode short-circuits before any human-readable print()s — the row
  // schema (`issueToJson`) is the single source of truth, exercised directly
  // by test/config/doctor_test.dart so it can never drift from the text path.
  if (asJson) {
    print(
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final issue in issues) issueToJson(issue)]),
    );
    exitCode = issues.isEmpty ? 0 : 1;
    return;
  }

  if (issues.isEmpty) {
    print('No configuration issues found.');
    exitCode = 0;
    return;
  }

  print('Found ${issues.length} issue(s):');
  print('');
  for (final issue in issues) {
    print('  $issue');
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

/// Converts one `[key] message` diagnostic string (the shape `_diagnose`
/// already produces and `doctor_test.dart` already asserts on) into a
/// structured `--format json` row. Reusing the existing bracket-prefixed
/// string as the single source of truth avoids a second, parallel
/// structured-issue model that could drift from the text output.
///
/// Public (no leading underscore) so a unit test can pin the schema.
Map<String, Object?> issueToJson(String issue) {
  final match = RegExp(r'^\[(\w+)\]\s*(.*)$').firstMatch(issue);
  final key = match?.group(1) ?? 'unknown';
  final message = match?.group(2) ?? issue;
  return {
    'key': key,
    // '[plugin]' means the plugin never loads at all — that's fatal, not a
    // tolerated misconfiguration, so it alone gets 'error' severity.
    'severity': key == 'plugin' ? 'error' : 'warning',
    'message': message,
  };
}

/// Runs all diagnostic checks and returns a list of issue descriptions.
///
/// Extracted from main() so tests can call it without touching the filesystem
/// or exit code. [mainContent] is the normalized analysis_options.yaml text;
/// [customExists] indicates whether analysis_options_custom.yaml is present.
List<String> diagnose(String mainContent, {required bool customExists}) {
  return _diagnose(mainContent, customExists: customExists);
}

/// Internal: returns issue strings for all detected misconfigurations.
List<String> _diagnose(String mainContent, {required bool customExists}) {
  final issues = <String>[];

  // Extract the saropa_lints plugin block so key checks are scoped to it,
  // not to arbitrary indented keys elsewhere in the file.
  final pluginBlock = _extractSaropaPluginBlock(mainContent);

  // --- Check for saropa_lints plugin entry ---
  if (pluginBlock == null) {
    issues.add(
      '[plugin] saropa_lints not found under plugins: in '
      'analysis_options.yaml — the plugin will not load.',
    );
    return issues;
  }

  // --- Check for misplaced keys inside the saropa_lints plugin block ---
  // Any of _customFileKeys under `plugins > saropa_lints:` triggers the
  // SDK's `unsupported_option` warning.
  for (final key in _customFileKeys) {
    final keyInBlock = RegExp(
      '^\\s+${RegExp.escape(key)}:\\s',
      multiLine: true,
    ).hasMatch(pluginBlock);
    if (keyInBlock) {
      issues.add(
        '[$key] found under plugins > saropa_lints: in '
        'analysis_options.yaml — causes unsupported_option warning.',
      );
    }
  }

  // --- Check analysis_options_custom.yaml ---
  if (!customExists) {
    issues.add(
      '[custom_file] analysis_options_custom.yaml not found — '
      'run `dart run saropa_lints init` to create one.',
    );
  }

  // --- Check for version key inside the plugin block ---
  final hasVersion = RegExp(
    r'''^\s+version:\s+["']?\d''',
    multiLine: true,
  ).hasMatch(pluginBlock);
  if (!hasVersion) {
    issues.add(
      '[version] No version: constraint under saropa_lints: — '
      'the plugin may resolve to an unexpected version.',
    );
  }

  return issues;
}

/// Extracts the `saropa_lints:` block from `analysis_options.yaml`.
///
/// Returns the block text (from the `saropa_lints:` line through all its
/// indented children) or null if the plugin entry doesn't exist. Uses
/// indentation-based detection: lines deeper than the `saropa_lints:` key
/// are children; the block ends at the first line at or below that indent
/// (or EOF).
String? _extractSaropaPluginBlock(String content) {
  final lines = content.split('\n');

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Match `saropa_lints:` at any indent, with optional trailing comment.
    if (!RegExp(r'^\s+saropa_lints:\s*(?:#.*)?$').hasMatch(line)) continue;
    final baseIndent = _leadingWhitespace(line);

    // Collect all child lines (deeper than baseIndent).
    final block = StringBuffer(line);
    for (var j = i + 1; j < lines.length; j++) {
      final child = lines[j];
      final trimmed = child.trim();
      // Blank lines and comments inside the block are kept.
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        block
          ..write('\n')
          ..write(child);
        continue;
      }
      // Dedent to or past the saropa_lints key means the block ended.
      if (_leadingWhitespace(child) <= baseIndent) break;
      block
        ..write('\n')
        ..write(child);
    }
    return block.toString();
  }
  return null;
}

/// Counts leading whitespace (spaces and tabs).
///
/// Matches the `_leadingWhitespace()` in `runtime_tier_cap.dart` and the
/// updated `_leadingSpaces()` in `analysis_options_rule_packs.dart`.
int _leadingWhitespace(String value) {
  var count = 0;
  while (count < value.length) {
    final c = value.codeUnitAt(count);
    if (c != 32 && c != 9) break;
    count++;
  }
  return count;
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
  print('  -h, --help        Show this help message');
  print('  --format json     Machine-readable JSON array of');
  print('                    {key,severity,message} rows');
}
