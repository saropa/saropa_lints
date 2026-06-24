/// Measures rule *liveness* against the `expect_lint` ground truth in fixtures.
///
/// The `*_expect_lint_contract_test.dart` integrity tests only assert that a
/// fixture *declares* an `// expect_lint:` marker; they never run the rule to
/// confirm it actually fires. This module closes that gap: for every rule that
/// is declared in a fixture file, it checks the rule produced at least one
/// diagnostic in that file. A declared-but-silent rule is the clearest signal a
/// rule has regressed or never worked.
///
/// Why file granularity, not line. The fixture corpus is not line-precise: many
/// markers sit above a *function* while the rule fires on a statement several
/// lines inside it (e.g. `require_request_timeout`'s marker precedes the
/// function, the violation is the `http.get` two lines down). Exact-line
/// matching therefore reports false negatives for correctly-firing rules. Per
/// file, "did the rule fire at all" is robust to marker placement and still
/// catches the real defect — a rule that never fires in its own fixture.
///
/// True false-positive / true-positive *rate* measurement against
/// [AccuracyTarget] is intentionally out of scope here: it requires markers
/// placed immediately above each violation with good examples isolated in
/// separate files, which this corpus does not yet provide. See
/// `plans/TODO_rule_metadata_completeness.md` §4.1.
///
/// IO and scan execution live in the CLI (`bin/accuracy_report.dart`); this
/// core is pure so the matching logic is unit-testable without a real scan.
library;

import 'package:saropa_lints/saropa_lints.dart' show AccuracyTarget;

/// A single fired-or-expected diagnostic location, decoupled from the analyzer
/// and scan types so the core can be tested with plain records.
typedef LintLocation = ({String rule, String file, int line});

/// Parsed result of one `// expect_lint:` marker.
typedef ExpectedLint = ({String rule, int line});

/// Per-rule liveness tally across the fixtures that declare the rule.
class RuleAccuracy {
  const RuleAccuracy({
    required this.rule,
    required this.testedFiles,
    required this.firedFiles,
    required this.target,
  });

  /// Rule name (e.g. `require_request_timeout`).
  final String rule;

  /// Fixture files that declare at least one `expect_lint` marker for the rule.
  final Set<String> testedFiles;

  /// Of [testedFiles], those in which the rule actually produced a diagnostic.
  final Set<String> firedFiles;

  /// The rule's derived target; carried for reporting (null = unspecified).
  final AccuracyTarget? target;

  /// Fixture files that declare the rule but where it never fired.
  Set<String> get silentFiles => testedFiles.difference(firedFiles);

  /// True when the rule is declared in a fixture but fires in none of them —
  /// the rule is effectively dead and the gate should fail.
  bool get isSilent => testedFiles.isNotEmpty && firedFiles.isEmpty;

  /// Fraction of declaring fixtures in which the rule fired (1.0 = all).
  double get firingRate =>
      testedFiles.isEmpty ? 0 : firedFiles.length / testedFiles.length;
}

/// Full liveness report across all rules declared in the fixtures.
class AccuracyReport {
  const AccuracyReport(this.rules);

  /// One entry per rule that has at least one `expect_lint` marker.
  final List<RuleAccuracy> rules;

  /// Rules declared in a fixture that never fire there — the gate failures.
  List<RuleAccuracy> get silentRules =>
      rules.where((r) => r.isSilent).toList();

  /// Rules that fired in some but not all of their declaring fixtures.
  List<RuleAccuracy> get partiallyFiringRules => rules
      .where((r) => !r.isSilent && r.firedFiles.length < r.testedFiles.length)
      .toList();

  int get totalTestedFiles =>
      rules.fold(0, (sum, r) => sum + r.testedFiles.length);
  int get totalFiredFiles =>
      rules.fold(0, (sum, r) => sum + r.firedFiles.length);
}

/// Parses every `// expect_lint:` marker in a single file's [source].
///
/// A marker may list several comma-separated rules. The returned line is the
/// marker's own 1-based line; callers measuring liveness use only the rule
/// name, so exact violation position is not inferred here.
List<ExpectedLint> parseExpectedLints(String source) {
  final results = <ExpectedLint>[];
  final lines = source.split('\n');
  final markerPattern = RegExp(r'//\s*expect_lint:\s*([A-Za-z0-9_,\s]+)');

  for (var i = 0; i < lines.length; i++) {
    final match = markerPattern.firstMatch(lines[i]);
    if (match == null) continue;

    final ruleList = match.group(1) ?? '';
    for (final raw in ruleList.split(',')) {
      final rule = raw.trim();
      if (rule.isNotEmpty) results.add((rule: rule, line: i + 1));
    }
  }
  return results;
}

/// Tallies which declared rules actually fired in their fixtures.
///
/// [expected] are the parsed markers (rule + file); [actual] are scan
/// diagnostics (rule + file). Only rules present in [expected] are measured —
/// a rule has no ground truth where no fixture declares it. [targets] is
/// carried into each entry for reporting.
AccuracyReport computeAccuracy({
  required Iterable<LintLocation> expected,
  required Iterable<LintLocation> actual,
  required Map<String, AccuracyTarget?> targets,
}) {
  final testedFilesByRule = _filesByRule(expected);
  final firedFilesByRule = _filesByRule(actual);

  final entries = <RuleAccuracy>[];
  for (final rule in testedFilesByRule.keys) {
    final tested = testedFilesByRule[rule] ?? const <String>{};
    // Restrict fired files to the rule's own fixtures: a hit in some other
    // rule's fixture is not evidence this rule works as specified.
    final fired = (firedFilesByRule[rule] ?? const <String>{})
        .intersection(tested);

    entries.add(
      RuleAccuracy(
        rule: rule,
        testedFiles: tested,
        firedFiles: fired,
        target: targets[rule],
      ),
    );
  }

  entries.sort((a, b) => a.rule.compareTo(b.rule));
  return AccuracyReport(entries);
}

/// Groups locations into the set of distinct files seen per rule.
Map<String, Set<String>> _filesByRule(Iterable<LintLocation> locations) {
  final byRule = <String, Set<String>>{};
  for (final loc in locations) {
    byRule.putIfAbsent(loc.rule, () => <String>{}).add(loc.file);
  }
  return byRule;
}
