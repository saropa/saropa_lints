/// Interactive stylistic rules walkthrough UI.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/stylistic_section_parser.dart';
import 'package:saropa_lints/src/init/stylistic_walkthrough_prompts.dart';
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
