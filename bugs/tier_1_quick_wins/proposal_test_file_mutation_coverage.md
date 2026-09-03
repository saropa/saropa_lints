# PROPOSAL: Cross-Reference Mutation-Testing Report Coverage Per Test File

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `test_file_mutation_coverage` to cross-check that every `lib/` file with a corresponding `*_test.dart` also has an adequate MUTATION-testing score recorded in a project-generated mutation-test report — not line/branch coverage, but the percentage of intentionally-injected bugs (mutants) the test suite actually catches. This rule cannot run mutation testing itself; it can only read and cross-reference an existing report produced out-of-band by a tool like `mutation_test`.

**Closes gap:** ripplearc_linter (github.com/ripplearc/ripplearc-flutter-lint). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` line ~362, where it is explicitly called out as "low generalizability."

---

## Motivation

Line/branch coverage measures whether a test SUITE executes a line, not whether it would actually CATCH a bug on that line — a test that calls a method but asserts nothing meaningful about its result shows 100% line coverage while catching zero mutants. Mutation testing closes that gap by injecting small deliberate bugs ("mutants": flipping a `<` to `<=`, negating a boolean, etc.) and checking whether the existing test suite fails against each one; the mutation SCORE is the percentage of mutants killed. `ripplearc_linter` cross-references a mutation-test report against the `lib/`/test/ file pairing so a file with high line coverage but a low mutation score gets flagged.

**This is explicitly a low-priority / narrow-ROI candidate.** Per `plans/GAP_ANALYSIS.md`'s own assessment, this gap is called out as "low generalizability" — it requires a project to already run a SEPARATE mutation-testing pipeline (e.g. the `mutation_test` package) and produce a report in a specific, parseable format before this rule can do anything at all. Without that report file present, the rule is inert by construction: it is not a self-contained static-analysis check like the rest of saropa's rule set, but a report-cross-referencing shim dependent on external tooling saropa doesn't control the output format of. Most projects (including saropa's own target audience) do not run mutation testing at all, making this the weakest-ROI candidate among the rules considered in this batch — see Alternatives Considered for the explicit "maybe defer" framing.

---

## Detection / Behavior

Given a configured path to a mutation-test report file (format TBD — likely the `mutation_test` package's own JSON/XML output) and a configured minimum mutation-score threshold, flag a `*_test.dart` file whose corresponding `lib/` source file's recorded mutation score in the report falls below the threshold. If no report file is found at the configured path, the rule should emit NO diagnostics (fail silent/inert, not fail loud) — it cannot invent a score.

### Config (proposed)

```yaml
saropa_lints:
  mutation_coverage:
    report_path: "mutation_test_report.json"
    minimum_score: 70
```

### Should flag (bad code)

Given a report showing `lib/services/pricing_service.dart` killed 40% of injected mutants (below the configured 70% threshold):

```dart
// test/services/pricing_service_test.dart
// LINT — test_file_mutation_coverage: pricing_service.dart mutation score
// is 40%, below the configured 70% threshold — tests exercise the code but
// may not assert meaningful outcomes.
void main() {
  test('calculates price', () {
    final result = PricingService().calculate(10, 2);
    expect(result, isNotNull); // weak assertion — a mutant flipping the
                                 // multiplication to addition would still pass
  });
}
```

### Should pass (good code)

A `*_test.dart` file whose corresponding source file's recorded mutation score meets or exceeds the configured threshold, per the report.

---

## Proposed Tier

Tier: Pedantic
Justification: Requires an external, project-maintained mutation-testing pipeline most projects don't run; opt-in and low-default-value even within the projects that enable it, consistent with the "low generalizability" / weakest-ROI assessment below.

---

## Edge Cases

1. **No report file present** — must emit zero diagnostics, not an error; this is the expected default state for the overwhelming majority of projects that never ran mutation testing.
2. **Stale report (report older than the source/test file's last modification)** — should ideally be detected and suppressed or flagged as "stale" rather than presenting outdated scores as current, but staleness detection itself requires filesystem timestamp comparison of unclear reliability across CI checkouts (which often reset mtimes) — needs design work before implementation.
3. **Report format lock-in** — the `mutation_test` package's report format is external and not saropa-controlled; a format change upstream could silently break this rule's parsing. This is itself an argument for deferring implementation until report-format stability is confirmed.
4. **`lib/` file with no corresponding `*_test.dart` at all** — out of scope for this rule; that gap is already covered by saropa's existing "mirror test" rules (`avoid_missing_test_files` / equivalent), so this rule should only ever evaluate files that already have a test file, cross-referencing the mutation score on top.

---

## Alternatives Considered

- **Defer entirely — do not implement.** Given the external-tooling dependency, the report-format lock-in risk, and GAP_ANALYSIS's own "low generalizability" framing, this is a genuine candidate for indefinite deferral rather than active implementation. Recommend treating this proposal as documentation of the gap for completeness, not as a near-term implementation commitment — of the rules considered in this batch, this one has the weakest cost/benefit ratio by a clear margin (highest external dependency, lowest addressable-project fraction).
- **Implement a saropa-native mutation-testing engine instead of cross-referencing an external report** — far larger scope (an entire mutation-testing engine is a different category of tool than a lint rule) and explicitly out of scope for this proposal, which only covers the cross-referencing behavior ripplearc_linter itself implements.

---

## Decision

---

## Implementation Notes

---

## Commits
