/// Parsing and extraction for STYLISTIC RULES section.
library;

import 'package:saropa_lints/src/tiers.dart' as tiers;

final RegExp stylisticSectionHeaderPattern = RegExp(
  r'# STYLISTIC RULES\s*\n',
  multiLine: true,
);

final RegExp ruleOverridesSectionHeaderPattern = RegExp(
  r'# RULE OVERRIDES\s*\n',
  multiLine: true,
);


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
  final afterSectionHeader = stylisticSectionHeaderPattern.firstMatch(
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

  final sectionMatch = ruleOverridesSectionHeaderPattern.firstMatch(content);

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
  final sectionMatch = ruleOverridesSectionHeaderPattern.firstMatch(content);

  if (sectionMatch == null) return content;

  // Only modify content after the RULE OVERRIDES header
  final before = content.substring(0, sectionMatch.end);
  var after = content.substring(sectionMatch.end);

  for (final rule in rulesToRemove) {
    // Remove the line: "rule_name: true/false" with optional comment/newline
    after = after.replaceAll(
      RegExp('^${RegExp.escape(rule)}:\\s*(true|false).*\\n?', multiLine: true),
      '',
    );
  }

  return before + after;
}
