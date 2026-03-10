/// Management of analysis_options_custom.yaml file.
///
/// Handles file creation, platform/package settings, stylistic section
/// management, and rule override extraction.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/stylistic_rulesets.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;



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

/// Ensure platforms setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// max_issues setting if missing.
void ensurePlatformsSetting(File file) {
  final content = file.readAsStringSync();

  // Check if platforms section already exists
  if (RegExp(r'^platforms:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  const settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# PLATFORM SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable platforms your project doesn't target.
# Only ios and android are enabled by default.

platforms:
  ios: true
  android: true
  macos: false
  web: false
  windows: false
  linux: false

''';

  // Insert after max_issues line if present, else after header
  final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
  String newContent;

  if (maxIssuesMatch != null) {
    final insertPos = maxIssuesMatch.end;
    newContent = content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    final headerEndMatch = RegExp(r'╚[═]+╝\n*').firstMatch(content);
    if (headerEndMatch != null) {
      final insertPos = headerEndMatch.end;
      newContent = content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  log.terminal(
    '${InitColors.green}✓ Added platforms setting to ${file.path}${InitColors.reset}',
  );
}

/// Ensure packages setting exists in an existing custom config file.
///
/// Older files won't have this setting, so we add it after the
/// platforms setting if missing.
void ensurePackagesSetting(File file) {
  final content = file.readAsStringSync();

  // Check if packages section already exists
  if (RegExp(r'^packages:', multiLine: true).hasMatch(content)) {
    return; // Already has the setting
  }

  final packageEntries = tiers.allPackages
      .map((p) => '  $p: ${tiers.defaultPackages[p]}')
      .join('\n');

  final settingBlock = '''
# ─────────────────────────────────────────────────────────────────────────────
# PACKAGE SETTINGS
# ─────────────────────────────────────────────────────────────────────────────
# Disable packages your project doesn't use.
# Rules specific to disabled packages will be automatically disabled.
# All packages are enabled by default for backward compatibility.
#
# EXAMPLES:
#   - Riverpod-only project: set bloc, provider, getx to false
#   - No local DB: set isar, hive, sqflite to false
#   - No Firebase: set firebase to false

packages:
$packageEntries

''';

  // Insert after platforms section if present
  final platformsEndMatch = RegExp(
    r'^platforms:\s*\n(?:\s+\w+:\s*(?:true|false)\s*\n)*',
    multiLine: true,
  ).firstMatch(content);

  String newContent;

  if (platformsEndMatch != null) {
    final insertPos = platformsEndMatch.end;
    newContent = content.substring(0, insertPos) +
        '\n' +
        settingBlock +
        content.substring(insertPos);
  } else {
    // Fallback: insert after max_issues
    final maxIssuesMatch = RegExp(r'max_issues:\s*\d+\n*').firstMatch(content);
    if (maxIssuesMatch != null) {
      final insertPos = maxIssuesMatch.end;
      newContent = content.substring(0, insertPos) +
          '\n' +
          settingBlock +
          content.substring(insertPos);
    } else {
      newContent = settingBlock + content;
    }
  }

  file.writeAsStringSync(newContent);
  log.terminal(
    '${InitColors.green}✓ Added packages setting to ${file.path}${InitColors.reset}',
  );
}

/// Builds the PACKAGE SETTINGS section for analysis_options_custom.yaml.
String buildPackageSection() {
  final buffer = StringBuffer();
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln('# PACKAGE SETTINGS');
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln("# Disable packages your project doesn't use.");
  buffer.writeln(
    '# Rules specific to disabled packages will be automatically disabled.',
  );
  buffer.writeln(
    '# All packages are enabled by default for backward compatibility.',
  );
  buffer.writeln('#');
  buffer.writeln('# EXAMPLES:');
  buffer.writeln(
    '#   - Riverpod-only project: set bloc, provider, getx to false',
  );
  buffer.writeln('#   - No local DB: set isar, hive, sqflite to false');
  buffer.writeln('#   - No Firebase: set firebase to false');
  buffer.writeln('');
  buffer.writeln('packages:');
  for (final package in tiers.allPackages) {
    final enabled = tiers.defaultPackages[package] ?? true;
    buffer.writeln('  $package: $enabled');
  }
  buffer.writeln('');
  return buffer.toString();
}

/// Builds the STYLISTIC RULES section content for analysis_options_custom.yaml.
///
/// Lists all stylistic rules organized by category with problem message
/// comments. Preserves existing true/false values from [existingValues].
/// Preserves [reviewed] markers from [reviewedRules].
/// Skips rules in [skipRules] (found elsewhere in the file).
/// New rules default to `false`.
String buildStylisticSection({
  Map<String, bool> existingValues = const <String, bool>{},
  Set<String> reviewedRules = const <String>{},
  Set<String> skipRules = const <String>{},
}) {
  final buffer = StringBuffer();
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  buffer.writeln('# STYLISTIC RULES');
  buffer.writeln(
    '# ─────────────────────────────────────────────────────────────────────────────',
  );
  // ┌─────────────────────────────────────────────────────────────────────────┐
  // │ IMPORTANT: The [reviewed] markers below track interactive walkthrough  │
  // │ progress. Do NOT remove them — they prevent re-prompting users for     │
  // │ rules they've already decided on. Use --reset-stylistic to clear all   │
  // │ markers and start the walkthrough from scratch.                        │
  // └─────────────────────────────────────────────────────────────────────────┘
  buffer.writeln(
    '# Opinionated formatting, ordering, and naming convention rules.',
  );
  buffer.writeln(
    '# These are NOT included in any tier - enable the ones that match your style.',
  );
  buffer.writeln('# Set to true to enable, false to disable.');
  buffer.writeln('#');
  buffer.writeln('# NOTE: Some rules conflict (e.g., prefer_single_quotes vs');
  buffer.writeln(
    '# prefer_double_quotes). Only enable one from each conflicting group.',
  );
  buffer.writeln('#');
  buffer.writeln(
    '# [reviewed] markers track walkthrough progress. Do NOT remove them.',
  );
  buffer.writeln(
    '# Use --reset-stylistic to clear markers and re-review all rules.',
  );
  buffer.writeln('');

  final categorizedRules = <String>{};

  for (final entry in stylisticRuleCategories.entries) {
    final category = entry.key;
    final rules = entry.value;

    // Filter out rules not in tiers.stylisticRules (prevents stale entries)
    // and skip rules already in RULE OVERRIDES section
    final activeRules = rules
        .where((r) => tiers.stylisticRules.contains(r))
        .where((r) => !skipRules.contains(r))
        .toList();
    if (activeRules.isEmpty) continue;

    buffer.writeln('# --- $category ---');
    for (final rule in activeRules) {
      final enabled = existingValues[rule] ?? false;
      final msg = getStylisticDescription(rule);
      final reviewed = reviewedRules.contains(rule);
      final marker = reviewed ? ' [reviewed]' : '';
      final comment = msg.isNotEmpty ? '  #$marker $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
      categorizedRules.add(rule);
    }
    buffer.writeln('');
  }

  // Add any uncategorized stylistic rules (safety net for new rules)
  final uncategorized = tiers.stylisticRules
      .difference(categorizedRules)
      .difference(skipRules)
      .toList()
    ..sort();

  if (uncategorized.isNotEmpty) {
    buffer.writeln('# --- Other stylistic rules ---');
    for (final rule in uncategorized) {
      final enabled = existingValues[rule] ?? false;
      final msg = getStylisticDescription(rule);
      final reviewed = reviewedRules.contains(rule);
      final marker = reviewed ? ' [reviewed]' : '';
      final comment = msg.isNotEmpty ? '  #$marker $msg' : '';
      buffer.writeln('$rule: $enabled$comment');
    }
    buffer.writeln('');
  }

  return buffer.toString();
}

/// Regex matching the STYLISTIC RULES section header.
final RegExp _stylisticSectionHeader = RegExp(
  r'# STYLISTIC RULES\s*\n',
  multiLine: true,
);

/// Regex matching the RULE OVERRIDES section header.
final RegExp _ruleOverridesSectionHeader = RegExp(
  r'# RULE OVERRIDES\s*\n',
  multiLine: true,
);

/// Ensure stylistic rules section exists and is complete in the custom
/// config file. Adds missing rules, preserves existing true/false values.
/// Skips rules that appear in the RULE OVERRIDES section.
void ensureStylisticRulesSection(File file) {
  var content = file.readAsStringSync();

  // Find stylistic rules in the RULE OVERRIDES section (to skip them)
  final overrideValues = extractOverrideSectionValues(content);
  var skipRules = overrideValues.keys.toSet().intersection(
        tiers.stylisticRules,
      );

  // Check if STYLISTIC RULES section exists
  final sectionMatch = _stylisticSectionHeader.firstMatch(content);

  if (sectionMatch == null) {
    insertNewStylisticSection(file, content, skipRules);
    return;
  }

  // Section exists - parse existing values and reviewed markers
  final existingValues = extractStylisticSectionValues(content);
  final reviewedRules = extractReviewedRules(content);

  // Clean up obsolete rules no longer in tiers.stylisticRules
  logRemovedStylisticRules(content);

  // Offer to move stylistic rules from RULE OVERRIDES to STYLISTIC section
  final moveResult = promptMoveOverridesToStylistic(
    content,
    skipRules,
    overrideValues,
    existingValues,
  );
  content = moveResult.content;
  skipRules = moveResult.skipRules;

  // Rebuild the section with current rules, preserved values and markers
  final newSection = buildStylisticSection(
    existingValues: existingValues,
    reviewedRules: reviewedRules,
    skipRules: skipRules,
  );

  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);

  final newContent = content.substring(0, sectionStart) +
      newSection +
      content.substring(sectionEnd);

  file.writeAsStringSync(newContent);
}

/// Insert a new STYLISTIC RULES section when none exists yet.
void insertNewStylisticSection(
  File file,
  String content,
  Set<String> skipRules,
) {
  final newSection = buildStylisticSection(skipRules: skipRules);
  final insertContent = '\n$newSection';

  // Find insertion point: before RULE OVERRIDES header
  final overridesHeaderMatch = RegExp(
    r'# ─+\n# RULE OVERRIDES',
    multiLine: true,
  ).firstMatch(content);

  String newContent;

  if (overridesHeaderMatch != null) {
    newContent = content.substring(0, overridesHeaderMatch.start) +
        insertContent +
        content.substring(overridesHeaderMatch.start);
  } else {
    newContent = content + insertContent;
  }

  file.writeAsStringSync(newContent);
  log.terminal(
    '${InitColors.green}✓ Added stylistic rules section to ${file.path}${InitColors.reset}',
  );
}

/// Log warnings about obsolete stylistic rules being cleaned up during
/// section rebuild. Enabled rules get a yellow warning; disabled ones
/// get a dim info message.
void logRemovedStylisticRules(String content) {
  final removedRules = extractRemovedStylisticRules(content);

  if (removedRules.isEmpty) return;

  final enabledRemoved = removedRules.entries
      .where((e) => e.value)
      .map((e) => e.key)
      .toList()
    ..sort();
  final disabledRemoved = removedRules.entries
      .where((e) => !e.value)
      .map((e) => e.key)
      .toList()
    ..sort();

  if (enabledRemoved.isNotEmpty) {
    log.terminal(
      '${InitColors.yellow}⚠ Removing ${enabledRemoved.length} obsolete '
      'stylistic rule(s) that were enabled:${InitColors.reset}',
    );
    for (final rule in enabledRemoved) {
      log.terminal('${InitColors.dim}  - $rule${InitColors.reset}');
    }
  }

  if (disabledRemoved.isNotEmpty) {
    log.terminal(
      '${InitColors.dim}  Cleaned up ${disabledRemoved.length} obsolete '
      'disabled stylistic rule(s)${InitColors.reset}',
    );
  }
}

/// Prompt the user to move stylistic rules from RULE OVERRIDES into the
/// STYLISTIC RULES section. Returns updated content and skipRules.
({String content, Set<String> skipRules}) promptMoveOverridesToStylistic(
  String content,
  Set<String> skipRules,
  Map<String, bool> overrideValues,
  Map<String, bool> existingValues,
) {
  if (skipRules.isEmpty) {
    return (content: content, skipRules: skipRules);
  }

  log.terminal('');
  log.terminal(
    '${InitColors.yellow}Found ${skipRules.length} stylistic rule(s) '
    'in RULE OVERRIDES section:${InitColors.reset}',
  );
  for (final rule in skipRules.toList()..sort()) {
    log.terminal('${InitColors.dim}  - $rule${InitColors.reset}');
  }

  bool shouldMove = false;

  if (stdin.hasTerminal) {
    stdout.write(
      '${InitColors.cyan}Move to STYLISTIC RULES section? [y/N]: '
      '${InitColors.reset}',
    );
    final response = stdin.readLineSync()?.toLowerCase().trim() ?? '';
    shouldMove = response == 'y' || response == 'yes';
  } else {
    log.terminal(
      '${InitColors.dim}  Non-interactive: keeping in RULE OVERRIDES'
      '${InitColors.reset}',
    );
  }

  if (!shouldMove) {
    return (content: content, skipRules: skipRules);
  }

  final movedCount = skipRules.length;
  final movedValues = Map<String, bool>.fromEntries(
    overrideValues.entries.where((e) => skipRules.contains(e.key)),
  );
  final updatedContent = removeRulesFromOverridesSection(content, skipRules);
  existingValues.addAll(movedValues);
  log.terminal(
    '${InitColors.green}✓ Moved $movedCount rule(s) to '
    'STYLISTIC RULES section${InitColors.reset}',
  );

  return (content: updatedContent, skipRules: <String>{});
}

/// Find the start of the STYLISTIC RULES section (including the divider).
int findStylisticSectionStart(String content) {
  // Look for the divider line before "# STYLISTIC RULES"
  final match = RegExp(
    r'# ─+\n# STYLISTIC RULES',
    multiLine: true,
  ).firstMatch(content);
  return match?.start ?? content.length;
}

/// Find the end of the STYLISTIC RULES section.
/// Ends at the next section divider or end of file.
int findStylisticSectionEnd(String content, int sectionStart) {
  // Find the next section header (─── divider) after the STYLISTIC RULES
  // header itself. Skip the first two divider lines (the section's own header).
  final afterHeader = content.indexOf('\n', sectionStart);

  if (afterHeader == -1) return content.length;

  // Skip past the "# STYLISTIC RULES" line and its closing divider
  final afterSectionHeader = _stylisticSectionHeader.firstMatch(
    content.substring(afterHeader),
  );
  final searchFrom = afterSectionHeader != null
      ? afterHeader + afterSectionHeader.end
      : afterHeader;

  final nextDivider = RegExp(
    r'\n# ─+\n# ',
    multiLine: true,
  ).firstMatch(content.substring(searchFrom));

  if (nextDivider != null) {
    return searchFrom + nextDivider.start + 1; // +1 for the leading \n
  }

  return content.length;
}

/// Extract rule name → enabled values from the STYLISTIC RULES section only.
Map<String, bool> extractStylisticSectionValues(String content) {
  final values = <String, bool>{};

  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(sectionContent)) {
    final ruleName = match.group(1);
    if (ruleName == null) continue;
    final enabled = match.group(2) == 'true';
    if (tiers.stylisticRules.contains(ruleName)) {
      values[ruleName] = enabled;
    }
  }

  return values;
}

/// Extract rule names that have the [reviewed] marker in their comment.
///
/// Reviewed markers track which stylistic rules the user has already
/// decided on during the interactive walkthrough. Rules without [reviewed]
/// will be re-prompted on the next `init` run.
///
/// Marker format: `rule_name: true  # [reviewed] description`
Set<String> extractReviewedRules(String content) {
  final reviewed = <String>{};

  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  // Match lines like: rule_name: true/false  # [reviewed] ...
  final reviewedPattern = RegExp(
    r'^([\w_]+):\s*(?:true|false)\s*#.*\[reviewed\]',
    multiLine: true,
  );

  for (final match in reviewedPattern.allMatches(sectionContent)) {
    final ruleName = match.group(1);
    if (ruleName == null) continue;
    if (tiers.stylisticRules.contains(ruleName)) {
      reviewed.add(ruleName);
    }
  }

  return reviewed;
}

/// Strip all [reviewed] markers from the STYLISTIC RULES section only.
/// Used by --reset-stylistic to force re-walkthrough of all rules.
/// Scoped to the section to avoid stripping the text from user comments
/// in other sections.
String stripReviewedMarkers(String content) {
  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);

  final before = content.substring(0, sectionStart);
  final section = content.substring(sectionStart, sectionEnd);
  final after = content.substring(sectionEnd);

  return before + section.replaceAll(RegExp(r' \[reviewed\]'), '') + after;
}

/// Extract rules from the STYLISTIC RULES section that no longer exist in
/// [tiers.stylisticRules]. Returns a map of removed rule name to its
/// enabled/disabled value so we can warn if user-enabled rules are dropped.
Map<String, bool> extractRemovedStylisticRules(String content) {
  final removed = <String, bool>{};

  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);
  final sectionContent = content.substring(sectionStart, sectionEnd);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(sectionContent)) {
    final ruleName = match.group(1);
    if (ruleName == null) continue;
    final enabled = match.group(2) == 'true';
    if (!tiers.stylisticRules.contains(ruleName)) {
      removed[ruleName] = enabled;
    }
  }

  return removed;
}

/// Extract all rule name → enabled/disabled values from the RULE OVERRIDES
/// section. Returns empty map if the section doesn't exist.
Map<String, bool> extractOverrideSectionValues(String content) {
  final values = <String, bool>{};

  final sectionMatch = _ruleOverridesSectionHeader.firstMatch(content);

  if (sectionMatch == null) return values;

  // Content after the RULE OVERRIDES header until end of file
  // (it's the last section)
  final afterSection = content.substring(sectionMatch.end);

  final rulePattern = RegExp(r'^([\w_]+):\s*(true|false)', multiLine: true);

  for (final match in rulePattern.allMatches(afterSection)) {
    final key = match.group(1);
    if (key != null) values[key] = match.group(2) == 'true';
  }

  return values;
}

/// Remove specific rules from the RULE OVERRIDES section.
/// Returns the modified content string.
String removeRulesFromOverridesSection(
  String content,
  Set<String> rulesToRemove,
) {
  final sectionMatch = _ruleOverridesSectionHeader.firstMatch(content);

  if (sectionMatch == null) return content;

  // Only modify content after the RULE OVERRIDES header
  final before = content.substring(0, sectionMatch.end);
  var after = content.substring(sectionMatch.end);

  for (final rule in rulesToRemove) {
    // Remove the line: "rule_name: true/false" with optional comment/newline
    after = after.replaceAll(
      RegExp('^$rule:\\s*(true|false).*\\n?', multiLine: true),
      '',
    );
  }

  return before + after;
}

/// Extract platform settings from analysis_options_custom.yaml.
///
/// Returns a map of platform name to enabled status.
/// Defaults to [tiers.defaultPlatforms] if not specified (ios and android
/// enabled, others disabled).
///
/// Supports format:
/// ```yaml
/// platforms:
///   ios: true
///   android: false
///   web: true
/// ```
Map<String, bool> extractPlatformsFromFile(File file) {
  final Map<String, bool> platforms = Map<String, bool>.of(
    tiers.defaultPlatforms,
  );

  if (!file.existsSync()) return platforms;

  final content = file.readAsStringSync();

  // Find the platforms: section
  final sectionMatch = RegExp(
    r'^platforms:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (sectionMatch == null) return platforms;

  // Extract indented entries after platforms:
  final afterSection = content.substring(sectionMatch.end);

  final platformPattern = RegExp(
    r'^\s+(ios|android|macos|web|windows|linux):\s*(true|false)',
    multiLine: true,
  );

  for (final match in platformPattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1);
    if (name == null) continue;
    final enabled = match.group(2) == 'true';
    platforms[name] = enabled;
  }

  return platforms;
}

/// Extract package settings from analysis_options_custom.yaml.
///
/// Returns a map of package name to enabled status.
/// Defaults to [tiers.defaultPackages] if not specified (all enabled).
///
/// Supports format:
/// ```yaml
/// packages:
///   bloc: true
///   riverpod: false
///   firebase: true
/// ```
Map<String, bool> extractPackagesFromFile(File file) {
  final Map<String, bool> packages = Map<String, bool>.of(
    tiers.defaultPackages,
  );

  if (!file.existsSync()) return packages;

  final content = file.readAsStringSync();

  // Find the packages: section
  final sectionMatch = RegExp(
    r'^packages:\s*$',
    multiLine: true,
  ).firstMatch(content);

  if (sectionMatch == null) return packages;

  // Extract indented entries after packages:
  final afterSection = content.substring(sectionMatch.end);

  final packagePattern = RegExp(
    r'^\s+([\w_]+):\s*(true|false)',
    multiLine: true,
  );

  for (final match in packagePattern.allMatches(afterSection)) {
    // Stop if we hit a non-indented line (next section)
    final beforeMatch = afterSection.substring(0, match.start);
    if (RegExp(r'^\S', multiLine: true).hasMatch(beforeMatch)) break;

    final name = match.group(1);
    if (name == null) continue;
    final enabled = match.group(2) == 'true';

    // Only include packages we know about
    if (tiers.defaultPackages.containsKey(name)) {
      packages[name] = enabled;
    }
  }

  return packages;
}
