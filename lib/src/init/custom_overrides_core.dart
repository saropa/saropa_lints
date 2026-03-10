/// Core custom overrides file management.
///
/// Handles file creation, rule extraction, and analysis settings.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/platforms_packages.dart';
import 'package:saropa_lints/src/init/stylistic_section.dart';

/// Extract rule overrides from analysis_options_custom.yaml.
///
/// Supports multiple formats:
/// ```yaml
/// # Custom rule overrides (survives --reset)
/// avoid_print: false  # Allow print in this project
/// - avoid_null_assertion: false # With hyphen prefix
///   - require_error_widget: false # Indented with hyphen
/// prefer_const_constructors: true
/// ```
///
/// These overrides are always applied, even when using --reset.
Map<String, bool> extractOverridesFromFile(File file, Set<String> allRules) {
  final Map<String, bool> overrides = <String, bool>{};

  if (!file.existsSync()) {
    return overrides;
  }

  final content = file.readAsStringSync();

  // Match rule entries with optional hyphen, indentation, and trailing comments:
  // - rule_name: true/false # optional comment
  //   rule_name: true/false
  // rule_name: false
  final rulePattern = RegExp(
    r'^\s*-?\s*([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in rulePattern.allMatches(content)) {
    final ruleName = match.group(1);
    if (ruleName == null) continue;
    final enabled = match.group(2) == 'true';

    // Only include rules we know about
    if (allRules.contains(ruleName)) {
      overrides[ruleName] = enabled;
    }
  }

  return overrides;
}

/// Create the analysis_options_custom.yaml file with a helpful header.
///
/// Includes the STYLISTIC RULES section with all opinionated rules
/// defaulting to false, organized by category.
void createCustomOverridesFile(File file) {
  final stylisticSection = buildStylisticSection();
  final packageSection = buildPackageSection();

  final content = '''
# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║                    SAROPA LINTS CUSTOM CONFIG                             ║
# ║                                                                           ║
# ║  Settings in this file are ALWAYS applied, even when using --reset.      ║
# ║  Use this for project-specific customizations that should persist.       ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart analyze
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze

max_issues: 500
output: both

# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Rules specific to disabled platforms will be automatically disabled.
# Only ios and android are enabled by default.
#
# EXAMPLES:
#   - Web-only project: set ios, android, macos, windows, linux to false; web to true
#   - All platforms: set all to true
#   - Desktop app: set macos, windows, linux to true

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

$packageSection$stylisticSection# ─────────────────────────────────────────────────────────────────────────────
# RULE OVERRIDES
# ─────────────────────────────────────────────────────────────────────────────
# FORMAT: rule_name: true/false
#
# EXAMPLES:
#   - avoid_print: false                # Allow print statements
#   - avoid_null_assertion: false       # Allow ! operator
#   - prefer_const_constructors: true   # Force-enable regardless of tier
#
# Add your custom rule overrides below:

''';

  file.writeAsStringSync(content);
}

/// Ensure max_issues setting exists in an existing custom config file.
///
/// Added in v4.9.1 - older files won't have this setting, so we add it
/// at the top of the file if missing.
void ensureMaxIssuesSetting(File file) {
  var content = file.readAsStringSync();

  final hasMaxIssues = RegExp(
    r'^max_issues:\s*\d+',
    multiLine: true,
  ).hasMatch(content);
  final hasOutput = RegExp(
    r'^output:\s*\w+',
    multiLine: true,
  ).hasMatch(content);

  if (hasMaxIssues && hasOutput) return; // Both settings present

  if (!hasMaxIssues) {
    // Neither setting exists — add the full block
    content = addAnalysisSettingsBlock(content);
    file.writeAsStringSync(content);
    log.terminal(
      '${InitColors.green}✓ Added analysis settings to ${file.path}${InitColors.reset}',
    );
    return;
  }

  // max_issues exists but output is missing — add output after max_issues
  if (!hasOutput) {
    content = addOutputSetting(content);
    file.writeAsStringSync(content);
    log.terminal(
      '${InitColors.green}✓ Added output setting to ${file.path}${InitColors.reset}',
    );
  }
}

/// Add the full analysis settings block (max_issues + output).
String addAnalysisSettingsBlock(String content) {
  final settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# ANALYSIS SETTINGS (added in v4.9.1, updated v4.12.2)
# ─────────────────────────────────────────────────────────────────────────────
#
# max_issues: Maximum non-ERROR issues shown in the Problems tab.
#   After this limit, rules keep running but remaining issues go to the
#   report log only (reports/<timestamp>_saropa_lint_report.log).
#   - Default: 500
#   - Set to 0 for unlimited (all issues in Problems tab)
#   - Override per-run: SAROPA_LINTS_MAX=200 dart analyze
#
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze

max_issues: 500
output: both

''';

  final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);

  if (headerEndMatch != null) {
    final insertPos = headerEndMatch.end;
    return content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  }

  return settingBlock + content;
}

/// Add just the output setting after an existing max_issues line.
String addOutputSetting(String content) {
  final maxIssuesMatch = RegExp(
    r'^(max_issues:\s*\d+.*)\n',
    multiLine: true,
  ).firstMatch(content);

  if (maxIssuesMatch == null) return content;

  final insertPos = maxIssuesMatch.end;
  const outputBlock = '''
# output: Where violations are sent.
#   - "both"  (default) — Problems tab + report file
#   - "file"  — Report file only (nothing in Problems tab)
#   - Override per-run: SAROPA_LINTS_OUTPUT=file dart analyze
output: both

''';

  return content.substring(0, insertPos) +
      outputBlock +
      content.substring(insertPos);
}
