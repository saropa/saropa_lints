/// Synthesized triage views over consolidated analysis data.
///
/// The raw report is an inventory (counts and lists). On a large backlog —
/// thousands of issues with a skewed rule distribution — an inventory is
/// unactionable: the user has to compute percentages, residuals, and
/// deltas by hand before they can decide what to do.
///
/// This module turns raw [ConsolidatedData]-style inputs into three
/// triage-oriented views that the text reporter prints above `OVERVIEW`:
///
/// - [ConcentrationSummary] — names the top rule(s) driving the count and
///   states what the count would drop to if each were suppressed.
/// - [RunDelta] — count change vs. the most recent previous report file
///   in the same date folder.
/// - [TriageRecommendation] — a suppress → baseline → fix plan keyed off
///   the same residual math, gated by a count threshold.
///
/// **Why this is a separate module.** The analysis reporter renders the
/// output; the synthesis logic decides what the output should *say*. Keeping
/// them apart lets tests cover threshold / residual / delta math without
/// parsing text, and lets future machine-readable report formats (JSON,
/// Markdown) reuse the exact same synthesized values.
library;

import 'dart:developer' as developer;
import 'dart:io' show Directory, File, Platform;

/// Thresholds that gate the optional sections.
///
/// Small projects (< 500 issues) suppress the synthesis sections entirely —
/// a flat count is already readable at that scale. The split between the
/// concentration threshold and the triage threshold lets a medium-sized
/// project see the concentration headline without the longer triage block.
class SynthesisThresholds {
  const SynthesisThresholds({
    this.concentrationMinTotal = 500,
    this.triageMinTotal = 1000,
    this.topRuleShareCutoff = 0.25,
    this.topThreeShareCutoff = 0.80,
  });

  /// Below this total, suppress `CONCENTRATION`. Small projects don't need it.
  final int concentrationMinTotal;

  /// Below this total, suppress `RECOMMENDED TRIAGE`.
  final int triageMinTotal;

  /// A single rule contributing at least this fraction of the total counts
  /// as "dominant" in the headline. Independent of the top-three cutoff so
  /// either condition can produce the callout.
  final double topRuleShareCutoff;

  /// Top three rules contributing at least this fraction count as
  /// "concentrated" even when the single-rule cutoff is not met.
  final double topThreeShareCutoff;

  static const SynthesisThresholds defaults = SynthesisThresholds();
}

/// Per-rule row used by both the concentration callout and the widened
/// TOP RULES table. Carries every derived field the text writer needs so
/// the writer does not duplicate arithmetic.
class RuleRow {
  const RuleRow({
    required this.name,
    required this.count,
    required this.share,
    required this.severity,
    required this.source,
    required this.fixable,
  });

  /// Rule name, e.g. `depend_on_referenced_packages`.
  final String name;

  /// Violation count for this rule across the consolidated batches.
  final int count;

  /// Fraction of the total (0.0–1.0). Stored as a fraction rather than a
  /// pre-formatted percent so consumers can format it however they want.
  final double share;

  /// Severity string (`ERROR` / `WARNING` / `INFO`), or `?` if unknown.
  /// Matches the casing the text reporter expects.
  final String severity;

  /// Origin of the rule — see [RuleSource].
  final RuleSource source;

  /// Whether a quick-fix generator is registered for this rule. Governs
  /// which triage step the rule belongs to: fixable rules route to the
  /// "auto-fix" path (dart fix), non-fixable to "suppress or manual edit".
  final bool fixable;
}

/// Source attribution for a rule name.
///
/// The practical distinction the user cares about is "is this mine to
/// change?" — saropa-authored rules can be adjusted in this package; SDK
/// and other-plugin rules must be handled at the consumer's
/// `analysis_options.yaml` level (baseline, disable, severity override).
enum RuleSource {
  /// Rule is registered by this `saropa_lints` package (present in the
  /// plugin's factory map).
  saropa('saropa'),

  /// Rule is a Dart SDK / `package:lints` built-in (e.g.
  /// `depend_on_referenced_packages`, `prefer_final_locals`).
  dartLints('dart-lints'),

  /// Rule is a Flutter `package:flutter_lints` rule.
  flutterLints('flutter-lints'),

  /// Rule is not registered by saropa and is not in the known SDK sets —
  /// probably from another analyzer plugin or a private rule pack.
  other('other');

  const RuleSource(this.label);

  final String label;
}

/// Headline concentration data for the top rule(s).
///
/// Always present when the run meets [SynthesisThresholds.concentrationMinTotal]
/// and the rule list is non-empty. The text writer checks [shouldRender] to
/// decide whether to print the section.
class ConcentrationSummary {
  const ConcentrationSummary({
    required this.total,
    required this.top,
    required this.topThreeCount,
    required this.residualAfterTopRule,
    required this.residualAfterTopThree,
    required this.dominantRuleTriggered,
    required this.topThreeTriggered,
  });

  /// Total violations across all rules (not just the top ones).
  final int total;

  /// Top 1..3 rows, already sorted descending by count. May contain fewer
  /// than three entries when the project has fewer rules triggered.
  final List<RuleRow> top;

  /// Sum of counts across [top]. Cached so writers don't recompute.
  final int topThreeCount;

  /// What [total] would drop to if the #1 rule were suppressed.
  final int residualAfterTopRule;

  /// What [total] would drop to if all rules in [top] were suppressed.
  final int residualAfterTopThree;

  /// True when rule #1 exceeds the single-rule share cutoff — this is the
  /// strongest triage signal ("one rule is the entire problem").
  final bool dominantRuleTriggered;

  /// True when the top three rules together exceed the aggregate cutoff —
  /// a softer signal that still warrants the callout.
  final bool topThreeTriggered;

  /// Section is worth rendering when either cutoff fired and there is at
  /// least one row to show.
  bool get shouldRender =>
      top.isNotEmpty && (dominantRuleTriggered || topThreeTriggered);
}

/// Count change against the most recent prior report in the same date
/// folder. Absent on the first run of the day (nothing to compare to).
class RunDelta {
  const RunDelta({
    required this.previousTotal,
    required this.currentTotal,
    required this.previousReportFile,
  });

  /// Total issues from the previous report. Negative delta = improving.
  final int previousTotal;

  /// Current run's total.
  final int currentTotal;

  /// Filename (not full path) of the prior report — printed so the user
  /// can open the file to compare.
  final String previousReportFile;

  /// Signed difference. Positive means regressions, negative means fixes.
  int get delta => currentTotal - previousTotal;

  /// Percent change relative to the prior total. Guarded against
  /// zero-division when the previous run had no issues.
  double get percentChange {
    if (previousTotal == 0) return 0;
    return (delta * 100.0) / previousTotal;
  }
}

/// Staged triage plan. Each stage has an actionable label; the text writer
/// formats these into the `RECOMMENDED TRIAGE` block.
class TriageRecommendation {
  const TriageRecommendation({
    required this.suppressCandidates,
    required this.residualAfterSuppress,
    required this.autoFixableCandidates,
    required this.hasFileImportance,
  });

  /// Rules proposed for suppression. Chosen from non-fixable rules with the
  /// largest counts — the user's highest-leverage single-config action.
  final List<RuleRow> suppressCandidates;

  /// What the total would drop to after the suppress step. Mirrors the
  /// concentration residual when the suppress step is just "the top rule".
  final int residualAfterSuppress;

  /// Top fixable rules — the ones `dart fix` can auto-resolve. Presented
  /// alongside suppression so the user sees both levers.
  final List<RuleRow> autoFixableCandidates;

  /// Whether the text writer can follow up with "fix highest-score files"
  /// — cheaper for the synthesizer to flag than to duplicate the file
  /// importance ranking.
  final bool hasFileImportance;

  bool get shouldRender =>
      suppressCandidates.isNotEmpty || autoFixableCandidates.isNotEmpty;
}

/// Builds the three synthesis views from the raw per-rule aggregates.
///
/// All methods are pure functions of their inputs. No I/O, no static state
/// — so tests can exercise threshold and residual math with synthetic
/// inputs and no filesystem setup. [findPreviousRunTotal] is the sole
/// exception because the "previous run" datum lives on disk; it's
/// extracted to its own method to keep everything else testable.
class ReportSynthesis {
  ReportSynthesis._();

  /// Build the ordered rule-row list the reporter uses for both the
  /// concentration section and the TOP RULES table.
  ///
  /// [issuesByRule] and [ruleSeverities] come straight from the
  /// consolidated batch data. [saropaRuleNames] is the plugin's factory
  /// map keys — the authoritative list of saropa-authored rules.
  /// [fixableRuleNames] is the plugin's `rulesWithFixes` set.
  static List<RuleRow> buildRuleRows({
    required Map<String, int> issuesByRule,
    required Map<String, String> ruleSeverities,
    required Set<String> saropaRuleNames,
    required Set<String> fixableRuleNames,
    int? total,
  }) {
    if (issuesByRule.isEmpty) return const <RuleRow>[];

    // Recompute total when not passed so the method is self-contained in
    // tests. Callers that already have the deduped total should pass it
    // to avoid a second pass.
    final computedTotal =
        total ?? issuesByRule.values.fold<int>(0, (s, v) => s + v);
    if (computedTotal == 0) return const <RuleRow>[];

    final sorted = issuesByRule.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (final e in sorted)
        RuleRow(
          name: e.key,
          count: e.value,
          share: e.value / computedTotal,
          severity: ruleSeverities[e.key] ?? '?',
          source: _classifyRuleSource(e.key, saropaRuleNames),
          fixable: fixableRuleNames.contains(e.key),
        ),
    ];
  }

  /// Classify a rule name as saropa/dart-lints/flutter-lints/other.
  ///
  /// Saropa-authored is the authoritative check (presence in the factory
  /// map). Everything else is a best-effort label to help triage: the user
  /// mainly needs to see "is this one the saropa project owns, or one I
  /// control via analysis_options.yaml?" — so a few mislabeled Flutter-vs-
  /// Dart lints is tolerable.
  static RuleSource _classifyRuleSource(
    String name,
    Set<String> saropaRuleNames,
  ) {
    if (saropaRuleNames.contains(name)) return RuleSource.saropa;
    if (_flutterLintsRuleNames.contains(name)) return RuleSource.flutterLints;
    if (_dartLintsRuleNames.contains(name)) return RuleSource.dartLints;
    return RuleSource.other;
  }

  /// Build the concentration summary from a pre-built ordered row list.
  ///
  /// Expects [rows] descending by count (as produced by [buildRuleRows]).
  /// Callers should pass the same [thresholds] they use elsewhere so UI
  /// gating and text-rendering stay in lockstep.
  static ConcentrationSummary buildConcentration({
    required List<RuleRow> rows,
    required int total,
    SynthesisThresholds thresholds = SynthesisThresholds.defaults,
  }) {
    if (rows.isEmpty || total <= 0) {
      return ConcentrationSummary(
        total: total,
        top: const <RuleRow>[],
        topThreeCount: 0,
        residualAfterTopRule: total,
        residualAfterTopThree: total,
        dominantRuleTriggered: false,
        topThreeTriggered: false,
      );
    }

    final top = rows.take(3).toList(growable: false);
    // `rows.isEmpty` guard above proves there's at least one row, so `top`
    // is guaranteed non-empty — but bind the #1 row via a local to keep
    // the static analyzer from flagging `top.first` as unsafe.
    final topOne = top[0];
    final topThreeCount = top.fold<int>(0, (s, r) => s + r.count);
    final topOneCount = topOne.count;

    return ConcentrationSummary(
      total: total,
      top: top,
      topThreeCount: topThreeCount,
      residualAfterTopRule: total - topOneCount,
      residualAfterTopThree: total - topThreeCount,
      dominantRuleTriggered: topOne.share >= thresholds.topRuleShareCutoff,
      topThreeTriggered:
          (topThreeCount / total) >= thresholds.topThreeShareCutoff,
    );
  }

  /// Build the triage recommendation from the same row list.
  ///
  /// Chooses suppression candidates (non-fixable, highest count) and
  /// auto-fix candidates (fixable, highest count) separately — the two
  /// steps require different user actions so mixing them hides the
  /// tradeoff. [maxPerGroup] caps the output so the text writer doesn't
  /// print a wall of rules.
  static TriageRecommendation buildTriage({
    required List<RuleRow> rows,
    required int total,
    bool hasFileImportance = false,
    int maxPerGroup = 5,
  }) {
    if (rows.isEmpty) {
      return const TriageRecommendation(
        suppressCandidates: <RuleRow>[],
        residualAfterSuppress: 0,
        autoFixableCandidates: <RuleRow>[],
        hasFileImportance: false,
      );
    }

    final nonFixable = rows.where((r) => !r.fixable).take(maxPerGroup).toList();
    final fixable = rows.where((r) => r.fixable).take(maxPerGroup).toList();

    final suppressedCount = nonFixable.fold<int>(0, (s, r) => s + r.count);
    final residual = (total - suppressedCount).clamp(0, total);

    return TriageRecommendation(
      suppressCandidates: nonFixable,
      residualAfterSuppress: residual,
      autoFixableCandidates: fixable,
      hasFileImportance: hasFileImportance,
    );
  }

  /// Find the total-issue count from the most recent prior report in
  /// [dateFolder]. Returns null when no prior report exists, when the
  /// folder is missing, or when the total cannot be parsed.
  ///
  /// [currentReportFilename] is excluded from the search so the function
  /// never matches the report currently being written.
  ///
  /// Parses the literal line `  Total issues:       12345` from the
  /// report header. The format is stable (see `_writeOverview`); if the
  /// header format changes in the future this regex must be updated.
  /// Kept as a tolerant parser — an unparseable prior file produces a
  /// null delta, not an error, so one broken file never blocks a run.
  static RunDelta? findPreviousRunTotal({
    required String dateFolder,
    required String currentReportFilename,
    required int currentTotal,
  }) {
    final dir = Directory(dateFolder);
    if (!dir.existsSync()) return null;

    const suffix = '_saropa_lint_report.log';
    final sep = Platform.pathSeparator;

    // Lexicographic sort over filenames with embedded YYYYMMDD_HHMMSS
    // timestamps produces chronological order — the prefix is fixed-width
    // so string sort = time sort.
    final candidates = <File>[];
    try {
      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final name = entity.path.split(sep).last;
        if (!name.endsWith(suffix)) continue;
        if (name == currentReportFilename) continue;
        candidates.add(entity);
      }
    } on Object catch (e, st) {
      // Directory listing failed (permissions, concurrent delete). The
      // delta is a nice-to-have; log for diagnosis but still surface
      // null rather than propagating — a broken sibling-scan must not
      // abort report generation.
      developer.log(
        'findPreviousRunTotal: listSync failed for $dateFolder',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return null;
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.path.compareTo(a.path));

    for (final f in candidates) {
      final parsed = _parseTotalIssuesFromReport(f);
      if (parsed == null) continue;
      return RunDelta(
        previousTotal: parsed,
        currentTotal: currentTotal,
        previousReportFile: f.path.split(sep).last,
      );
    }
    return null;
  }

  static final RegExp _totalIssuesRegExp = RegExp(
    r'^\s*Total issues:\s+(\d+)',
    multiLine: true,
  );

  static int? _parseTotalIssuesFromReport(File file) {
    // Read the whole file as a string. Reports are rotated at
    // `_maxReportFiles = 10` so at most ~10 siblings exist; the 4 KiB
    // hand-rolled-RAF optimization that used to live here traded a
    // file-descriptor-leak lint warning for a few hundred milliseconds
    // saved on a filesystem that probably page-caches the file anyway.
    // Simplicity wins.
    try {
      final content = file.readAsStringSync();
      final match = _totalIssuesRegExp.firstMatch(content);
      if (match == null) return null;
      return int.tryParse(match.group(1) ?? '');
    } on Object catch (e, st) {
      // Unreadable prior file shouldn't block the current run — log and
      // return null so the caller falls back to the next candidate.
      developer.log(
        '_parseTotalIssuesFromReport: read failed for ${file.path}',
        name: 'saropa_lints',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}

/// Known Dart SDK / `package:lints` rule names referenced in the Essential
/// tier of this project plus the broadly-shipped built-ins most likely to
/// dominate real-project backlogs. Not exhaustive — unknown SDK rules fall
/// through to [RuleSource.other], which is still correct in the "not
/// saropa-authored" sense and doesn't mislead triage. Add entries here
/// only when a user-report shows a real SDK rule being mislabeled.
const Set<String> _dartLintsRuleNames = <String>{
  'depend_on_referenced_packages',
  'prefer_final_locals',
  'prefer_const_literals_to_create_immutables',
  'prefer_const_declarations',
  'prefer_const_constructors',
  'prefer_const_constructors_in_immutables',
  'prefer_final_fields',
  'prefer_final_in_for_each',
  'prefer_final_parameters',
  'use_setstate_synchronously',
  'use_super_parameters',
  'use_build_context_synchronously',
  'avoid_print',
  'avoid_web_libraries_in_flutter',
  'avoid_relative_lib_imports',
  'await_only_futures',
  'cancel_subscriptions',
  'close_sinks',
  'constant_identifier_names',
  'deprecated_consistency',
  'document_ignores',
  'empty_catches',
  'empty_constructor_bodies',
  'empty_statements',
  'exhaustive_cases',
  'hash_and_equals',
  'library_prefixes',
  'library_private_types_in_public_api',
  'no_leading_underscores_for_local_identifiers',
  'no_logic_in_create_state',
  'non_constant_identifier_names',
  'null_closures',
  'overridden_fields',
  'package_api_docs',
  'prefer_adjacent_string_concatenation',
  'prefer_collection_literals',
  'prefer_conditional_assignment',
  'prefer_contains',
  'prefer_equal_for_default_values',
  'prefer_for_elements_to_map_fromiterable',
  'prefer_function_declarations_over_variables',
  'prefer_generic_function_type_aliases',
  'prefer_if_null_operators',
  'prefer_inlined_adds',
  'prefer_interpolation_to_compose_strings',
  'prefer_iterable_whereType',
  'prefer_null_aware_operators',
  'prefer_spread_collections',
  'prefer_typing_uninitialized_variables',
  'prefer_void_to_null',
  'recursive_getters',
  'slash_for_doc_comments',
  'sort_child_properties_last',
  'type_init_formals',
  'unawaited_futures',
  'unnecessary_brace_in_string_interps',
  'unnecessary_const',
  'unnecessary_constructor_name',
  'unnecessary_getters_setters',
  'unnecessary_late',
  'unnecessary_library_directive',
  'unnecessary_new',
  'unnecessary_null_aware_assignments',
  'unnecessary_null_in_if_null_operators',
  'unnecessary_nullable_for_final_variable_declarations',
  'unnecessary_overrides',
  'unnecessary_parenthesis',
  'unnecessary_string_escapes',
  'unnecessary_string_interpolations',
  'unnecessary_this',
  'unrelated_type_equality_checks',
  'unused_element',
  'unused_field',
  'unused_import',
  'unused_local_variable',
  'use_collection_literals',
  'use_function_type_syntax_for_parameters',
  'use_key_in_widget_constructors',
  'use_rethrow_when_possible',
  'uri_does_not_exist',
  'valid_regexps',
  'void_checks',
};

/// Known `package:flutter_lints` rule names. Narrow set — most
/// Flutter-adjacent lints actually live in `package:lints` and are covered
/// above. Separate classification is kept so the user sees "flutter-lints"
/// for the ones that really ship from that package.
const Set<String> _flutterLintsRuleNames = <String>{
  'avoid_unnecessary_containers',
  'use_full_hex_values_for_flutter_colors',
};
