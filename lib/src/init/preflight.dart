/// Pre-flight validation checks before generating configuration.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';

/// Run pre-flight checks before generating the configuration.
///
/// All checks are non-fatal (warnings only). Results are logged to both
/// terminal and the log buffer so they appear in the report file.
/// [targetDir] is the absolute path to the project being configured.
void runPreflightChecks(
  LogWriter log, {
  required String version,
  required String targetDir,
}) {
  log.terminal('${InitColors.bold}Pre-flight checks${InitColors.reset}');

  _checkPubspecDependency(log, targetDir);
  _checkDartSdkVersion(log);
  _checkV7SdkIfNeeded(log, version);
  _auditExistingConfig(log, version, targetDir);

  log.terminal('');
}

/// Check that pubspec.yaml lists saropa_lints as a dependency.
void _checkPubspecDependency(LogWriter log, String targetDir) {
  final pubspec = File('$targetDir/pubspec.yaml');

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
      detail:
          'saropa_lints not found in dependencies — '
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
  // Use tryParse instead of parse — regex guarantees digits but tryParse
  // is safer against unexpected Platform.version formats.
  final major = int.tryParse(g1);
  final minor = int.tryParse(g2);
  if (major == null || minor == null) return null;
  return (major, minor);
}

/// Check that the Dart SDK meets the saropa_lints 17 floor (>= 3.11).
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
  if (major > 3 || (major == 3 && minor >= 11)) {
    log.check('Dart SDK $major.$minor (plugin support OK)', pass: true);
  } else {
    log.check(
      'Dart SDK version',
      pass: false,
      detail:
          '$major.$minor detected — saropa_lints 17 requires Dart >= 3.11 '
          '(analyzer 13). Upgrade Dart/Flutter, or stay on saropa_lints '
          '^16.7.0 for Dart 3.9/3.10.',
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
      detail:
          '$major.$minor detected — saropa_lints v7 requires Dart SDK 3.9+ '
          '(analyzer 10). v7 was retracted; use saropa_lints 8.0.0 for Flutter.',
    );
  }
}

/// Audit an existing analysis_options.yaml for common issues.
void _auditExistingConfig(
  LogWriter log,
  String currentVersion,
  String targetDir,
) {
  final configFile = File('$targetDir/analysis_options.yaml');

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
      detail:
          'contains custom_lint: section — '
          'saropa_lints v5 uses native plugins, not custom_lint',
    );
  }

  // Scope version checks to the saropa_lints entry under plugins: — an
  // unrelated `version:` elsewhere in the file must not be read.
  final hasEntry = RegExp(
    r'^\s+saropa_lints:',
    multiLine: true,
  ).hasMatch(content);
  final existing = findSaropaLintsPluginVersion(content);

  if (hasEntry && existing == null) {
    log.check(
      'Existing config',
      pass: false,
      detail:
          'plugins section missing version: key — '
          'the analyzer will silently ignore the plugin',
    );
  }

  // Check for stale version constraint (drift vs resolved package version)
  if (existing != null && currentVersion != 'unknown') {
    if (existing != currentVersion && !existing.startsWith(currentVersion)) {
      log.check(
        'Existing config',
        pass: false,
        detail:
            'version $existing differs from resolved $currentVersion '
            '— run "dart run saropa_lints:init" to update it',
      );
    }
  }

  // If none of the config-specific checks above fired, report OK
  if (!log.warnings.any((w) => w.startsWith('Existing config'))) {
    log.check('Existing analysis_options.yaml looks OK', pass: true);
  }
}

/// Returns the `version:` value of the `saropa_lints:` entry under the
/// top-level `plugins:` block, or null if absent. Commented lines and
/// `version:` keys elsewhere in the file are ignored.
String? findSaropaLintsPluginVersion(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  var inPlugins = false;
  int? entryIndent;
  for (final line in lines) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final indent = line.length - line.trimLeft().length;
    if (indent == 0) {
      inPlugins = line.trimRight() == 'plugins:';
      entryIndent = null;
      continue;
    }
    if (!inPlugins) continue;
    if (entryIndent != null && indent <= entryIndent) entryIndent = null;
    if (entryIndent == null) {
      if (RegExp(r'^\s+saropa_lints:').hasMatch(line)) {
        entryIndent = indent;
        // Inline form: `saropa_lints: ^1.2.3` or `saropa_lints: "1.2.3"`.
        final inline = RegExp(
          r'saropa_lints:\s*"?\^?([^"\s#]+)"?',
        ).firstMatch(line);
        if (inline != null) return inline.group(1);
      }
      continue;
    }
    final m = RegExp(r'^\s+version:\s*"?\^?([^"\s#]+)"?').firstMatch(line);
    if (m != null) return m.group(1);
  }

  return null;
}
