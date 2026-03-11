/// Individual walkthrough prompt functions for stylistic rules.
library;

import 'dart:io';

import 'package:saropa_lints/src/init/display.dart';
import 'package:saropa_lints/src/init/log_writer.dart';
import 'package:saropa_lints/src/init/rule_metadata.dart';
import 'package:saropa_lints/src/init/stylistic_section_parser.dart';
import 'package:saropa_lints/src/init/stylistic_walkthrough.dart'
    show CategoryResult;

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
