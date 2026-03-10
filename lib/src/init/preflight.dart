/// Pre-flight validation checks before generating configuration.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';

/// Run pre-flight checks before generating the configuration.
///
/// All checks are non-fatal (warnings only). Results are logged to both
/// terminal and the log buffer so they appear in the report file.
void runPreflightChecks(LogWriter log, {required String version}) {
  log.terminal('${InitColors.bold}Pre-flight checks${InitColors.reset}');

  _checkPubspecDependency(log);
  _checkDartSdkVersion(log);
  _checkV7SdkIfNeeded(log, version);
  _auditExistingConfig(log, version);

  log.terminal('');
}

/// Check that pubspec.yaml lists saropa_lints as a dependency.
void _checkPubspecDependency(LogWriter log) {
  final pubspec = File('pubspec.yaml');

  if (!pubspec.existsSync()) {
    log.check(
      'pubspec.yaml',
      pass: false,
      detail: 'file not found — are you in the project root?',
    );
    return;
  }

  final content = pubspec.readAsStringSync();
  final hasDep = RegExp(
    r'^\s+saropa_lints:',
    multiLine: true,
  ).hasMatch(content);

  if (hasDep) {
    log.check('pubspec.yaml contains saropa_lints dependency', pass: true);
  } else {
    log.check(
      'pubspec.yaml',
      pass: false,
      detail: 'saropa_lints not found in dependencies — '
          'add it to dev_dependencies',
    );
  }
}

/// Parses Dart SDK version from [Platform.version].
/// Returns (major, minor) or null if unparseable.
(int major, int minor)? _parseDartSdkVersion() {
  final match = RegExp(r'^(\d+)\.(\d+)').firstMatch(Platform.version);
  if (match == null) return null;
  final g1 = match.group(1);
  final g2 = match.group(2);
  if (g1 == null || g2 == null) return null;
  return (int.parse(g1), int.parse(g2));
}

/// Check that the Dart SDK version supports the plugin system (>= 3.6).
void _checkDartSdkVersion(LogWriter log) {
  final parsed = _parseDartSdkVersion();
  if (parsed == null) {
    log.check(
      'Dart SDK version',
      pass: false,
      detail: 'could not parse: ${Platform.version}',
    );
    return;
  }
  final (major, minor) = parsed;
  if (major > 3 || (major == 3 && minor >= 6)) {
    log.check('Dart SDK $major.$minor (plugin support OK)', pass: true);
  } else {
    log.check(
      'Dart SDK version',
      pass: false,
      detail: '$major.$minor detected — native plugins require Dart >= 3.6',
    );
  }
}

/// If saropa_lints is v7+, ensure Dart SDK is 3.9+.
void _checkV7SdkIfNeeded(LogWriter log, String packageVersion) {
  if (!packageVersion.startsWith('7.')) return;

  final parsed = _parseDartSdkVersion();
  if (parsed == null) return;
  final (major, minor) = parsed;

  if (major > 3 || (major == 3 && minor >= 9)) {
    log.check('Dart SDK $major.$minor (v7 / analyzer 10 OK)', pass: true);
  } else {
    log.check(
      'Dart SDK for v7',
      pass: false,
      detail: '$major.$minor detected — saropa_lints v7 requires Dart SDK 3.9+ '
          '(analyzer 10). v7 was retracted; use saropa_lints 8.0.0 for Flutter.',
    );
  }
}

/// Audit an existing analysis_options.yaml for common issues.
void _auditExistingConfig(LogWriter log, String currentVersion) {
  final configFile = File('analysis_options.yaml');

  if (!configFile.existsSync()) {
    log.check('No existing analysis_options.yaml (fresh setup)', pass: true);
    return;
  }

  final content = configFile.readAsStringSync();

  // Check for old custom_lint section (v4 leftover)
  if (RegExp(r'custom_lint:', multiLine: true).hasMatch(content)) {
    log.check(
      'Existing config',
      pass: false,
      detail: 'contains custom_lint: section — '
          'saropa_lints v5 uses native plugins, not custom_lint',
    );
  }

  // Check for plugins section missing version key
  if (RegExp(r'^\s+saropa_lints:', multiLine: true).hasMatch(content) &&
      !RegExp(r'^\s+version:', multiLine: true).hasMatch(content)) {
    log.check(
      'Existing config',
      pass: false,
      detail: 'plugins section missing version: key — '
          'the analyzer will silently ignore the plugin',
    );
  }

  // Check for stale version constraint
  final versionMatch = RegExp(
    r'version:\s*"?\^?([^"\s]+)"?',
    multiLine: true,
  ).firstMatch(content);

  if (versionMatch != null && currentVersion != 'unknown') {
    final existing = versionMatch.group(1);
    if (existing != null &&
        existing != currentVersion &&
        !existing.startsWith(currentVersion)) {
      log.check(
        'Existing config',
        pass: false,
        detail: 'version $existing may be stale (current: $currentVersion) '
            '— re-run "dart run saropa_lints" to update',
      );
    }
  }

  // If none of the config-specific checks above fired, report OK
  if (!log.warnings.any((w) => w.startsWith('Existing config'))) {
    log.check('Existing analysis_options.yaml looks OK', pass: true);
  }
}
