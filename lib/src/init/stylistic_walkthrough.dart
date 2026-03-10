/// Interactive stylistic rules walkthrough UI.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/custom_overrides.dart';
import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/stylistic_rulesets.dart';
import 'package:saropa_lints/src/tiers.dart' as tiers;



// ---------------------------------------------------------------------------
// Interactive stylistic rules walkthrough
// ---------------------------------------------------------------------------

/// Result of running the stylistic walkthrough.
class WalkthroughResult {
  const WalkthroughResult({
    required this.reviewed,
    required this.enabled,
    required this.disabled,
    required this.skipped,
    required this.isAborted,
  });

  final int reviewed;
  final int enabled;
  final int disabled;
  final int skipped;
  final bool isAborted;
}


/// Run the interactive stylistic rules walkthrough.
///
/// Walks through unreviewed stylistic rules category by category,
/// showing code examples and prompting the user to enable or disable
/// each rule. Saves decisions immediately to [customFile].
///
/// Returns early if non-interactive.
WalkthroughResult runStylisticWalkthrough({
  required File customFile,
  required Map<String, bool> packageSettings,
  required Map<String, bool> platformSettings,
  required bool resetStylistic,
}) {
  if (!stdin.hasTerminal) {
    log.terminal(
      '${InitColors.dim}Non-interactive: skipping stylistic '
      'walkthrough${InitColors.reset}',
    );
    return const WalkthroughResult(
      reviewed: 0,
      enabled: 0,
      disabled: 0,
      skipped: 0,
      isAborted: false,
    );
  }

  final content = customFile.readAsStringSync();

  // Get existing values and reviewed markers
  final existingValues = extractStylisticSectionValues(content);
  var reviewedRules =
      resetStylistic ? <String>{} : extractReviewedRules(content);

  // If --reset-stylistic, strip markers from the file first
  if (resetStylistic && content.contains('[reviewed]')) {
    customFile.writeAsStringSync(stripReviewedMarkers(content));
    log.terminal(
      '${InitColors.yellow}Cleared all [reviewed] markers${InitColors.reset}',
    );
  }

  // Filter out rules irrelevant to this project
  final disabledByPackage = tiers.getRulesDisabledByPackages(packageSettings);
  final disabledByPlatform = tiers.getRulesDisabledByPlatforms(
    platformSettings,
  );
  var irrelevantRules = disabledByPackage.union(disabledByPlatform);

  // Skip widget-specific stylistic rules for pure Dart projects.
  // packageSettings already detected Flutter from pubspec.yaml in main().
  if (packageSettings['flutter'] != true) {
    irrelevantRules = irrelevantRules.union(tiers.flutterStylisticRules);
  }

  // Build the list of rules to walk through (unreviewed + relevant)
  final rulesToReview = tiers.stylisticRules
      .difference(reviewedRules)
      .difference(irrelevantRules);

  if (rulesToReview.isEmpty) {
    log.terminal(
      '${InitColors.green}All stylistic rules already '
      'reviewed.${InitColors.reset}',
    );
    log.terminal(
      '${InitColors.dim}Use --reset-stylistic to '
      're-review.${InitColors.reset}',
    );
    return const WalkthroughResult(
      reviewed: 0,
      enabled: 0,
      disabled: 0,
      skipped: 0,
      isAborted: false,
    );
  }

  log.terminal('');
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── Stylistic Rules Walkthrough ──${InitColors.reset}',
  );
  // Use global counts so progress (e.g. 51/143) persists on resume, not 1/N.
  final int totalAllRules =
      tiers.stylisticRules.difference(irrelevantRules).length;
  final int alreadyReviewed = totalAllRules - rulesToReview.length;
  final int irrelevantCount =
      irrelevantRules.intersection(tiers.stylisticRules).length;
  log.terminal(
    alreadyReviewed > 0
        ? '${InitColors.dim}${rulesToReview.length} rules remaining '
            '($alreadyReviewed already reviewed, $irrelevantCount '
            'skipped as irrelevant to project)${InitColors.reset}'
        : '${InitColors.dim}${rulesToReview.length} rules to review '
            '($irrelevantCount skipped as irrelevant to project)${InitColors.reset}',
  );
  log.terminal('');
  log.terminal(
    '${InitColors.dim}  Per ruleset: [y] enable all  [n] disable all  '
    '[q] quit & save${InitColors.reset}',
  );
  log.terminal('');

  final metadata = getRuleMetadata();
  int enabled = 0;
  int disabled = 0;
  int skipped = 0;
  bool aborted = false;
  var decisions = <String, bool>{};

  // 1) Rulesets: one question per ruleset (~13–14); decisions applied in order.
  final rulesets = getStylisticRulesets();
  int rulesetIndex = 0;
  final totalRulesets = rulesets
      .where((rs) => rs.rules.intersection(rulesToReview).isNotEmpty)
      .length;

  for (final rs in rulesets) {
    final toReview = rs.rules
        .intersection(rulesToReview)
        .difference(Set<String>.from(decisions.keys))
        .toList();
    if (toReview.isEmpty) continue;

    rulesetIndex++;
    final result = walkthroughMajorGroup(
      label: rs.label,
      description: rs.description,
      rules: toReview,
      groupIndex: rulesetIndex,
      totalGroups: totalRulesets,
      showRuleNames: rs.id == StylisticRulesetId.other,
    );
    if (result == null) {
      aborted = true;
      break;
    }
    for (final r in toReview) {
      decisions[r] = result;
    }
    final count = toReview.length;
    if (result) {
      enabled += count;
    } else {
      disabled += count;
    }
    writeStylisticDecisions(customFile, decisions);
    reviewedRules = reviewedRules.union(Set<String>.from(toReview));
  }

  // 2) Conflicting style choices: one gate, then pick-one per category if yes
  if (!aborted) {
    final conflictingEntries = stylisticRuleCategories.entries
        .where(
          (e) =>
              e.key.contains('conflicting') &&
              e.value.any((r) => rulesToReview.contains(r)),
        )
        .toList();
    final conflictingToReview = conflictingEntries
        .expand((e) => e.value.where((r) => rulesToReview.contains(r)))
        .toSet();
    final alreadyDecided = Set<String>.from(decisions.keys);
    final conflictingUnreviewed =
        conflictingToReview.difference(alreadyDecided).toList();

    if (conflictingUnreviewed.isNotEmpty) {
      final doConflicting = walkthroughConflictingGate(
        count: conflictingUnreviewed.length,
        categoryCount: conflictingEntries.length,
      );
      if (doConflicting == null) {
        aborted = true;
      } else if (doConflicting) {
        int categoryIndex = 0;
        final totalConflicting = conflictingEntries.length;
        int ruleOffset = alreadyReviewed + decisions.length;

        for (final entry in conflictingEntries) {
          final categoryRules =
              entry.value.where((r) => rulesToReview.contains(r)).toList();
          if (categoryRules.isEmpty) continue;

          categoryIndex++;
          final result = walkthroughConflicting(
            category: entry.key,
            rules: categoryRules,
            metadata: metadata,
            existingValues: existingValues,
            categoryIndex: categoryIndex,
            totalCategories: totalConflicting,
            ruleOffset: ruleOffset,
            totalRules: totalAllRules,
          );
          if (result == null) {
            aborted = true;
            break;
          }
          ruleOffset += categoryRules.length;
          enabled += result.enabled;
          disabled += result.disabled;
          skipped += result.skipped;
          decisions.addAll(result.decisions);
          writeStylisticDecisions(customFile, result.decisions);
          reviewedRules = reviewedRules.union(
            Set<String>.from(result.decisions.keys),
          );
        }
      }
      // If doConflicting == false: leave conflicting rules unreviewed (skip)
    }
  }

  // 3) Remaining (uncategorized) rules: one bulk prompt if any
  if (!aborted) {
    final categorizedRuleNames = <String>{};
    for (final rules in stylisticRuleCategories.values) {
      categorizedRuleNames.addAll(rules);
    }
    final remaining = rulesToReview
        .difference(Set<String>.from(decisions.keys))
        .toList()
      ..sort();
    if (remaining.isNotEmpty) {
      final result = walkthroughRemainingBulk(
        rules: remaining,
        existingValues: existingValues,
      );
      if (result == null) {
        aborted = true;
      } else {
        enabled += result.enabled;
        disabled += result.disabled;
        skipped += result.skipped;
        decisions.addAll(result.decisions);
        writeStylisticDecisions(customFile, result.decisions);
      }
    }
  }

  final totalReviewed = enabled + disabled;
  log.terminal('');
  log.terminal(
    '${InitColors.bold}Walkthrough '
    '${aborted ? 'paused' : 'complete'}:${InitColors.reset} '
    '$totalReviewed reviewed '
    '(${InitColors.green}$enabled enabled${InitColors.reset}, '
    '${InitColors.red}$disabled disabled${InitColors.reset}, '
    '${InitColors.dim}$skipped skipped${InitColors.reset})',
  );

  if (aborted) {
    log.terminal(
      '${InitColors.dim}Run init again to resume from where you '
      'left off.${InitColors.reset}',
    );
  }

  return WalkthroughResult(
    reviewed: totalReviewed,
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    isAborted: aborted,
  );
}

/// Result from walking through a single category.
class CategoryResult {
  const CategoryResult({
    required this.enabled,
    required this.disabled,
    required this.skipped,
    required this.decisions,
  });

  final int enabled;
  final int disabled;
  final int skipped;

  /// Rule name to enabled/disabled decision.
  /// Skipped rules are included with their current value preserved.
  final Map<String, bool> decisions;
}

/// Asks one bulk question for a major group. Returns true = enable all,
/// false = disable all, null = quit.
/// When [showRuleNames] is true, the rule names are listed so the user can decide.
bool? walkthroughMajorGroup({
  required String label,
  required String description,
  required List<String> rules,
  required int groupIndex,
  required int totalGroups,
  bool showRuleNames = false,
}) {
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── Ruleset $groupIndex of $totalGroups ──${InitColors.reset}',
  );
  log.terminal('');
  log.terminal('  ${InitColors.bold}$label${InitColors.reset}');
  log.terminal('');
  log.terminal('  $description');
  if (showRuleNames && rules.isNotEmpty) {
    log.terminal('');
    const int _maxRuleNamesToList = 25;
    if (rules.length <= _maxRuleNamesToList) {
      log.terminal('  ${InitColors.dim}Rule names:${InitColors.reset}');
      for (final name in rules) {
        log.terminal('    $name');
      }
    } else {
      log.terminal(
        '  ${InitColors.dim}${rules.length} rules (list omitted; see the '
        'stylistic section in your config for names).${InitColors.reset}',
      );
    }
  }
  log.terminal('');
  log.terminal(
    '  ${InitColors.cyan}Enable all ${rules.length} rules in this ruleset? '
    '[y/N/q]: ${InitColors.reset}',
  );
  final rawInput = stdin.readLineSync();
  log.terminal('');
  if (rawInput == null) return null;
  final input = rawInput.trim().toLowerCase();
  if (input == 'q' || input == 'quit') return null;
  if (input == 'y' || input == 'yes') return true;
  return false;
}

/// Asks whether to run conflicting style-choice prompts. Returns true = yes,
/// false = no (skip), null = quit.
bool? walkthroughConflictingGate({
  required int count,
  required int categoryCount,
}) {
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── Conflicting style choices ($count rules in $categoryCount categories) '
    '──${InitColors.reset}',
  );
  log.terminal('');
  log.terminal(
    '  ${InitColors.cyan}Set these now (e.g. quote style, blank line before return)? '
    '[y/N/q]: ${InitColors.reset}',
  );
  final rawInput = stdin.readLineSync();
  log.terminal('');
  if (rawInput == null) return null;
  final input = rawInput.trim().toLowerCase();
  if (input == 'q' || input == 'quit') return null;
  return input == 'y' || input == 'yes';
}

/// One bulk prompt for all remaining stylistic rules. Returns null if quit.
CategoryResult? walkthroughRemainingBulk({
  required List<String> rules,
  required Map<String, bool> existingValues,
}) {
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── Remaining stylistic rules (${rules.length}) ──${InitColors.reset}',
  );
  log.terminal('');
  log.terminal(
    '  ${InitColors.cyan}Enable all ${rules.length} remaining rules? '
    '[y/N/q]: ${InitColors.reset}',
  );
  final rawInput = stdin.readLineSync();
  log.terminal('');
  if (rawInput == null) return null;
  final input = rawInput.trim().toLowerCase();
  if (input == 'q' || input == 'quit') return null;
  final enable = input == 'y' || input == 'yes';
  final decisions = <String, bool>{};
  for (final r in rules) {
    decisions[r] = enable;
  }
  final count = rules.length;
  return CategoryResult(
    enabled: enable ? count : 0,
    disabled: enable ? 0 : count,
    skipped: 0,
    decisions: decisions,
  );
}

/// Walk through a non-conflicting category rule by rule.
/// Returns null if user chose to quit.
/// Kept for potential future "review individually" option.
// ignore: unused_element
CategoryResult? walkthroughCategory({
  required String category,
  required List<String> rules,
  required Map<String, RuleMetadata> metadata,
  required Map<String, bool> existingValues,
  required int categoryIndex,
  required int totalCategories,
  required int ruleOffset,
  required int totalRules,
}) {
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── $category ($categoryIndex of $totalCategories) '
    '──${InitColors.reset}',
  );
  log.terminal('');

  int enabled = 0;
  int disabled = 0;
  int skipped = 0;
  final decisions = <String, bool>{};
  bool enableAllRemaining = false;

  for (int i = 0; i < rules.length; i++) {
    final rule = rules[i];
    final meta = metadata[rule];

    if (enableAllRemaining) {
      decisions[rule] = true;
      enabled++;
      log.terminal('  ${InitColors.green}+ $rule${InitColors.reset}');
      continue;
    }

    // Display rule info with progress
    final ruleNum = ruleOffset + i + 1;
    final pct = (ruleNum * 100 / totalRules).round();
    final progress =
        '${InitColors.dim}($ruleNum/$totalRules — $pct%)${InitColors.reset}';
    final fixTag = (meta != null && meta.hasFix)
        ? '  ${InitColors.green}[quick fix]${InitColors.reset}'
        : '';
    log.terminal('  ${InitColors.bold}$rule${InitColors.reset}$fixTag  $progress');
    log.terminal('');

    if (meta != null) {
      // Show code examples if available (GOOD first for readability)
      if (meta.exampleGood != null) {
        log.example('GOOD', InitColors.green, meta.exampleGood!);
      }
      if (meta.exampleBad != null) {
        log.example('BAD', InitColors.red, meta.exampleBad!);
      }
      if (meta.exampleBad != null || meta.exampleGood != null) {
        log.terminal('');
      }

      // Show description
      final desc = meta.correctionMessage.isNotEmpty
          ? stripRulePrefix(meta.correctionMessage)
          : stripRulePrefix(meta.problemMessage);
      if (desc.isNotEmpty) {
        log.terminal('  $desc');
        log.terminal('');
      }
    }

    // Prompt
    final after = rules.length - i - 1;
    final aLabel = after > 0 ? '[a] enable this + $after more  ' : '';
    stdout.write(
      '  ${InitColors.cyan}[y] enable  [n] disable  '
      '[s] skip (keeps current)  '
      '$aLabel'
      '[q] quit: ${InitColors.reset}',
    );

    final rawInput = stdin.readLineSync();
    log.terminal('');
    if (rawInput == null) return null; // EOF → quit
    final input = rawInput.trim().toLowerCase();

    switch (input) {
      case 'y':
      case 'yes':
        decisions[rule] = true;
        enabled++;
      case 'n':
      case 'no':
        decisions[rule] = false;
        disabled++;
      case 's':
      case 'skip':
      case '':
        // Mark as reviewed with current value so it won't be re-prompted
        decisions[rule] = existingValues[rule] ?? false;
        skipped++;
      case 'a':
      case 'all':
        decisions[rule] = true;
        enabled++;
        enableAllRemaining = true;
      case 'q':
      case 'quit':
        return null;
      default:
        log.terminal(
          '  ${InitColors.yellow}Unknown "$input", '
          'skipping${InitColors.reset}',
        );
        // Mark as reviewed with current value so it won't be re-prompted
        decisions[rule] = existingValues[rule] ?? false;
        skipped++;
    }
  }

  return CategoryResult(
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    decisions: decisions,
  );
}

/// Walk through a conflicting category as a multiple-choice selection.
/// Returns null if user chose to quit.
CategoryResult? walkthroughConflicting({
  required String category,
  required List<String> rules,
  required Map<String, RuleMetadata> metadata,
  required Map<String, bool> existingValues,
  required int categoryIndex,
  required int totalCategories,
  required int ruleOffset,
  required int totalRules,
}) {
  final ruleNum = ruleOffset + 1;
  final pct = (ruleNum * 100 / totalRules).round();
  final progress =
      '${InitColors.dim}($ruleNum/$totalRules — $pct%)${InitColors.reset}';
  log.terminal(
    '${InitColors.bold}${InitColors.cyan}'
    '── $category ($categoryIndex of $totalCategories) '
    '──${InitColors.reset}  $progress',
  );
  log.terminal('');

  // Display all options with numbers
  for (int i = 0; i < rules.length; i++) {
    final rule = rules[i];
    final meta = metadata[rule];
    log.terminal('  ${InitColors.bold}${i + 1}. $rule${InitColors.reset}');
    if (meta != null &&
        (meta.exampleGood != null || meta.exampleBad != null)) {
      if (meta.exampleGood != null) {
        log.example('GOOD', InitColors.green, meta.exampleGood!, indent: 5);
      }
      if (meta.exampleBad != null) {
        log.example('BAD', InitColors.red, meta.exampleBad!, indent: 5);
      }
    } else if (meta != null) {
      final desc = stripRulePrefix(meta.correctionMessage).isNotEmpty
          ? stripRulePrefix(meta.correctionMessage)
          : stripRulePrefix(meta.problemMessage);
      log.terminal('     $desc');
    }
    log.terminal('');
  }

  // Prompt
  final nums = List.generate(rules.length, (i) => '${i + 1}').join('/');
  stdout.write(
    '  ${InitColors.cyan}Choose [$nums] or [s] skip (keeps current)  '
    '[q] quit: ${InitColors.reset}',
  );

  final rawInput = stdin.readLineSync();
  log.terminal('');

  if (rawInput == null) return null; // EOF → quit
  final input = rawInput.trim().toLowerCase();

  if (input == 'q' || input == 'quit') return null;

  final decisions = <String, bool>{};
  int enabled = 0;
  int disabled = 0;
  int skipped = 0;

  if (input == 's' || input == 'skip' || input.isEmpty) {
    // Mark all rules in group as reviewed with current values
    for (final rule in rules) {
      decisions[rule] = existingValues[rule] ?? false;
    }
    skipped += rules.length;
  } else {
    final choice = int.tryParse(input);
    if (choice != null && choice >= 1 && choice <= rules.length) {
      // Enable the chosen rule, disable all others
      for (int i = 0; i < rules.length; i++) {
        if (i == choice - 1) {
          decisions[rules[i]] = true;
          enabled++;
        } else {
          decisions[rules[i]] = false;
          disabled++;
        }
      }
    } else {
      log.terminal(
        '  ${InitColors.yellow}Unknown "$input", '
        'skipping${InitColors.reset}',
      );
      // Mark all rules in group as reviewed with current values
      for (final rule in rules) {
        decisions[rule] = existingValues[rule] ?? false;
      }
      skipped += rules.length;
    }
  }

  return CategoryResult(
    enabled: enabled,
    disabled: disabled,
    skipped: skipped,
    decisions: decisions,
  );
}

/// Write walkthrough decisions to the custom yaml file.
///
/// Updates rule values and adds [reviewed] markers in the STYLISTIC
/// RULES section. Only modifies rules present in [decisions].
void writeStylisticDecisions(File customFile, Map<String, bool> decisions) {
  if (decisions.isEmpty) return;

  var content = customFile.readAsStringSync();

  // Scope replacements to the STYLISTIC RULES section only, so a rule
  // that also appears in RULE OVERRIDES is not accidentally modified.
  final sectionStart = findStylisticSectionStart(content);
  final sectionEnd = findStylisticSectionEnd(content, sectionStart);

  for (final entry in decisions.entries) {
    final rule = entry.key;
    final enabled = entry.value;

    // Match the rule line: rule_name: true/false  # ...
    final rulePattern = RegExp(
      '^(${RegExp.escape(rule)}):\\s*(true|false)(\\s*#.*)?\\s*\$',
      multiLine: true,
    );

    // Search only within the STYLISTIC RULES section
    final sectionContent = content.substring(sectionStart, sectionEnd);
    final match = rulePattern.firstMatch(sectionContent);
    if (match != null) {
      // Preserve description after [reviewed] marker
      final existingComment = match.group(3)?.trim() ?? '';

      // Strip old marker if present, keep description
      final descPart = existingComment
          .replaceFirst(RegExp(r'^#\s*'), '')
          .replaceFirst(RegExp(r'\[reviewed\]\s*'), '')
          .trim();

      final newComment =
          descPart.isNotEmpty ? '  # [reviewed] $descPart' : '  # [reviewed]';

      // Offset match positions back to full-content coordinates
      content = content.replaceRange(
        sectionStart + match.start,
        sectionStart + match.end,
        '$rule: $enabled$newComment',
      );
    }
  }

  customFile.writeAsStringSync(content);
}
