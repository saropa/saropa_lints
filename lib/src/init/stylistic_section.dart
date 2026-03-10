/// Stylistic rules section management in analysis_options_custom.yaml.
///
/// Build, ensure, insert, and interact with the STYLISTIC RULES section.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/stylistic_rulesets.dart';
import 'package:saropa_lints/src/init/stylistic_section_parser.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;


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

/// Regex matching the RULE OVERRIDES section header.

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
  final sectionMatch = stylisticSectionHeaderPattern.firstMatch(content);

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
