/// Post-write configuration validation.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/preflight.dart'
    show findSaropaLintsPluginVersion;

/// Marker the VS Code extension writes when it comments out the plugin block.
const String extensionDisabledMarker =
    '# >>> saropa_lints integration turned OFF by the VS Code extension';

/// True when the config has no active `plugins:` block or lists no rules,
/// i.e. the analyzer would run no saropa_lints rules.
///
/// A marker-wrapped (commented-out) block is the default for new projects,
/// so it is usable unless [ownedOff] says the extension itself turned lints off.
bool isConfigUnusable(String content, {required bool ownedOff}) {
  if (!ownedOff && content.contains(extensionDisabledMarker)) return false;
  final hasPlugins = RegExp(r'^plugins:', multiLine: true).hasMatch(content);
  final ruleLines = RegExp(
    r'^\s{6}\w+:\s*(true|false)',
    multiLine: true,
  ).allMatches(content).length;

  return !hasPlugins || ruleLines == 0;
}

/// Validate the written configuration file has the critical sections.
///
/// Returns true if all checks pass.
bool validateWrittenConfig(
  LogWriter log,
  String filePath,
  int expectedRuleCount, {
  required bool ownedOff,
}) {
  log.terminal('');
  log.terminal('${InitColors.bold}Post-write validation${InitColors.reset}');

  final file = File(filePath);

  if (!file.existsSync()) {
    log.check(filePath, pass: false, detail: 'file does not exist');
    return false;
  }

  final content = file.readAsStringSync();
  var allPassed = true;

  // Check plugins: section exists
  if (RegExp(r'^plugins:', multiLine: true).hasMatch(content)) {
    log.check('plugins: section present', pass: true);
  } else {
    log.check(
      'plugins:',
      pass: false,
      detail: content.contains(extensionDisabledMarker)
          ? (ownedOff
                ? "switched off in the VS Code extension — click 'Saropa "
                      "Lints: Off' in the status bar to turn it on (init does "
                      'not re-enable it)'
                : 'commented out: default lightweight mode (the daemon '
                      'delivers diagnostics; the in-process plugin is not '
                      'loaded)')
          : 'section missing',
    );
    allPassed = false;
  }

  // A marker-wrapped block is commented out on purpose, so the live-block
  // checks below (version, diagnostics, rule count) do not apply.
  if (content.contains(extensionDisabledMarker)) {
    log.terminal('');
    return allPassed;
  }

  // Check version: key under saropa_lints
  if (findSaropaLintsPluginVersion(content) != null) {
    log.check('version: key present', pass: true);
  } else {
    log.check(
      'version:',
      pass: false,
      detail: 'key missing — analyzer will silently ignore plugin',
    );
    allPassed = false;
  }

  // Check diagnostics: section
  if (RegExp(r'^\s+diagnostics:', multiLine: true).hasMatch(content)) {
    log.check('diagnostics: section present', pass: true);
  } else {
    log.check('diagnostics:', pass: false, detail: 'section missing');
    allPassed = false;
  }

  // Check rule count (5% tolerance)
  final ruleLines = RegExp(
    r'^\s{6}\w+:\s*(true|false)',
    multiLine: true,
  ).allMatches(content).length;
  final tolerance = (expectedRuleCount * 0.05).ceil();
  final diff = (ruleLines - expectedRuleCount).abs();

  if (diff <= tolerance) {
    log.check(
      'Rule count: $ruleLines (expected ~$expectedRuleCount)',
      pass: true,
    );
  } else {
    log.check(
      'Rule count',
      pass: false,
      detail: '$ruleLines rules found, expected ~$expectedRuleCount',
    );
    allPassed = false;
  }

  log.terminal('');
  return allPassed;
}
