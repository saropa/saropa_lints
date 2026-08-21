// Regression test for the `max_issues` Problems-tab cap.
//
// `ProgressTracker.isLimitReached` was tracked and displayed in the
// stderr/progress summaries, but `SaropaDiagnosticReporter.atNode/atToken/
// atOffset` never consulted it — every diagnostic still reached the
// Problems tab regardless of `max_issues`, making the printed cap message
// false. This pins the fix: once the non-ERROR count exceeds `max_issues`,
// further non-ERROR diagnostics are withheld from the Problems tab (the
// `_rule.report*` call is skipped) but still counted via
// `ProgressTracker.recordViolation`, so `violations.json` and the text
// report stay uncapped per `violation_export.dart`'s documented contract.
library;

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart' show ProgressTracker;
import 'package:test/test.dart';

import '../support/resolved_rule_harness.dart';

void main() {
  setUp(ProgressTracker.reset);

  tearDown(() {
    // maxIssues is config, not state — ProgressTracker.reset() deliberately
    // leaves it untouched (see saropa_lint_rule.dart), so restore the
    // package default explicitly to avoid leaking into other test files
    // that share this isolate.
    ProgressTracker.setMaxIssues(500);
    ProgressTracker.reset();
  });

  test('withholds non-ERROR diagnostics from the Problems tab once '
      'max_issues is exceeded, but keeps tracking every violation', () async {
    ProgressTracker.setMaxIssues(2);

    // prefer_static_method is INFO severity — five independent
    // static-eligible methods each trigger one non-ERROR violation.
    final diags = await runRuleResolved(PreferStaticMethodRule(), '''
class FiveMethods {
  int one() => 1;
  int two() => 2;
  int three() => 3;
  int four() => 4;
  int five() => 5;
}
''');

    // Cap trips strictly AFTER the count exceeds max_issues (matches the
    // documented semantics on ProgressTracker.recordViolation), so the
    // 3rd violation is the one that flips isLimitReached — it still
    // reports, and the 4th/5th are withheld.
    expect(diags.length, 3);
    expect(ProgressTracker.isLimitReached, isTrue);
    expect(ProgressTracker.reportData.violationsFound, 5);
  });

  test('does not cap while max_issues is unlimited (0)', () async {
    ProgressTracker.setMaxIssues(0);

    final diags = await runRuleResolved(PreferStaticMethodRule(), '''
class FiveMethods {
  int one() => 1;
  int two() => 2;
  int three() => 3;
  int four() => 4;
  int five() => 5;
}
''');

    expect(diags.length, 5);
    expect(ProgressTracker.isLimitReached, isFalse);
  });
}
