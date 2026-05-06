# BUG: Analysis report format is insufficient for large issue backlogs (23k+) — no triage guidance, no concentration callout, no path-to-zero

**Status: Fix Ready**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Component: Report generator — `AnalysisReporter`
File: `lib/src/report/analysis_reporter.dart` (plus `lib/src/report/report_consolidator.dart`)
Severity: UX — High (blocks adoption on any established codebase with a large initial backlog)
Rule version: N/A (infrastructure bug, not a rule bug)

---

## Summary

On a real project with 23,434 issues (saropa-contacts, 1,185 Dart files analyzed, 68 rules triggered), the current text report at `reports/<yyyymmdd>/<hhmmss>_saropa_lint_report.log` is an *inventory* — it enumerates everything that is wrong — but it is not an *action plan*. It fails to surface the one fact that actually matters for triage: **22,695 of the 23,434 issues (96.8%) come from a single rule, `depend_on_referenced_packages`**. The user reading the report cannot see this without doing arithmetic; the top-rules table lists the rule at position 1 with its count but does not call out the concentration, does not suggest what would remain if the top rule were suppressed, and does not provide a path from 23k to zero. The report does the same thing whether the project has 50 issues or 50,000 issues — and at 50,000 the same format is actively unusable.

Verbatim (real-run captured): `reports/20260424/20260424_093112_saropa_lint_report.log:10-28` shows `Total issues: 23434` and `depend_on_referenced_packages (22695)` — two facts, twenty lines apart, with no synthesis between them.

---

## Attribution Evidence

This is a report-generation bug, not a rule bug. No `lib/src/rules/` grep applies. Generator is confirmed in-repo:

```bash
grep -rn "FILE IMPORTANCE\|TOP RULES" lib/src/report/
# lib/src/report/analysis_reporter.dart — produces the text report format quoted in Summary
# lib/src/report/report_consolidator.dart — aggregates per-isolate batch data
```

**Emitter:** `lib/src/report/analysis_reporter.dart` (entire file — the report layout is baked into this class's write path).
**Sibling file:** `lib/src/report/report_consolidator.dart` (aggregates counts that the reporter consumes — same data is already computed, just not surfaced as recommendations).

---

## Reproducer

1. Open the `saropa-contacts` workspace (`d:/src/contacts`).
2. Run `Saropa Lints: Run Analysis` from the VS Code extension. Use the `recommended` tier (default). Analysis produces `reports/20260424/20260424_HHMMSS_saropa_lint_report.log`.
3. Open the most recent `saropa_lint_report.log`. Observe:

   ```
   OVERVIEW
     Total issues:       23434
     Files analyzed:     1185
     Files with issues:  1181
     Rules triggered:    68

   TOP RULES
      1. depend_on_referenced_packages (22695) [WARNING]
      2. prefer_final_locals (347) [INFO]
      3. require_rtl_layout_support (98) [WARNING]
      ...
   ```

4. Observe what the report does **not** tell the user:
   - That rule #1 accounts for 96.8% of everything — so dropping or fixing it is the entire game.
   - What the issue count *would be* if the user suppressed the top rule (answer: 739 — a 97% reduction, a completely different project).
   - Which of the 68 rules have quick fixes available and which require manual refactoring.
   - Which rules are from the Dart SDK / `lints` package (not owned by `saropa_lints`) vs which are authored here.
   - How the count changed since the previous run in the same folder (today's folder alone has runs producing 13,568 / 23,434 / other counts — no delta shown).
   - A minimum-viable-state recommendation: "Suppress rule X, fix files Y, baseline the rest."

**Frequency:** Always — every run on a project with a skewed rule distribution (which is the typical shape of a real codebase) produces a report that buries the headline.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Report leads with a **concentration callout**: "1 rule accounts for 97% of all issues. Suppressing `depend_on_referenced_packages` would drop the count from 23,434 to 739." Followed by a **triage plan**: top-N rules-to-suppress, top-N files to fix, estimated fixability (by whether each rule has a quick fix), and a **delta** against the previous report in the same directory. |
| **Actual** | Flat enumeration of counts. User has to mentally compute percentages and plan the approach themselves. At 23k issues this is infeasible; at 50k it is meaningless. |

---

## Current Report Structure (what exists)

From `reports/20260424/20260424_093112_saropa_lint_report.log` (lightly abbreviated):

```
Saropa Lints Analysis Report
Generated: 2026-04-24T13:36:22.056480Z
Project: D:/src/contacts
Batches: 3 isolates contributed
======================================================================

CONFIGURATION
  (not available — config was not captured)      ← [Gap 1] config never captured
OVERVIEW
  Total issues:       23434
  Files analyzed:     1185
  Files with issues:  1181
  Rules triggered:    68
BY IMPACT
  critical     15 (0.1%)
  high         22783 (97.2%)
  medium       156 (0.7%)
  low          480 (2.0%)                         ← [Gap 2] "high" dominance is rule #1 bleeding through — not actionable
BY SEVERITY
  ERROR        19
  WARNING      22925
  INFO         490
TOP RULES
   1. depend_on_referenced_packages (22695) [WARNING]  ← [Gap 3] no percentage, no "if-suppressed" delta
   2. prefer_final_locals (347) [INFO]
   ... (18 more)                                  ← [Gap 4] no fix-availability column, no source-of-rule column
FILE IMPORTANCE (1185 files, ... top 50)
  Score | Fan-in | Layer | Issues | File           ← [Gap 5] no "which rules are in this file" link
  ...
```

---

## Gaps (in priority order)

### Gap 1 — Concentration callout is missing

When any single rule contributes ≥ 25% of total issues, or the top 3 rules together contribute ≥ 80%, the report should open with a dedicated `CONCENTRATION` section that names the dominant rule(s), the percentage, and the **residual count if the rule were suppressed**. On this run that would read:

```
CONCENTRATION (highest-leverage single action)
  depend_on_referenced_packages    22695  (96.8% of total)
  → Suppressing this rule drops the report to 739 issues (a 97% reduction).
  → Rule source: dart lints (not authored by saropa_lints)  ← Gap 4 data shown here too
```

This is the single most important change. It turns the report from an inventory into a decision document.

### Gap 2 — "Path to zero" is absent

For backlogs above some threshold (say, 1,000+ issues), the report should include a `RECOMMENDED TRIAGE` section that proposes:

- **Step 1 — Suppress**: rules whose count is high AND whose impact/severity is low AND which are not security-critical. For each, state the residual count if that single rule were baselined or downgraded.
- **Step 2 — Baseline**: remaining bulk. Reference the `baseline` suppression mechanism (already supported — see `suppressionsByKind` in `violationsReader.ts:45-48`) and produce a copy-pasteable command / config snippet.
- **Step 3 — Fix**: a numbered top-N files where fixing a handful of files has disproportionate effect (score × issue-count).

Without this, the user has no path from 23k to zero — they have a list.

### Gap 3 — No delta against previous runs

`reports/20260424/` already contains five runs from today (13,568 / 23,434 / etc.). The report does not reference the prior run. A one-line `CHANGE SINCE LAST RUN` at the top (`23434 issues, +N since 09:31 (same tier)`) would let the user see whether work is converging or diverging. Glob pattern and folder convention already exist — the generator just does not read the neighbor file.

### Gap 4 — No fix-availability, no rule-source column

The TOP RULES table lists counts but not two facts that govern the triage order:

- **Fixability**: does this rule have a registered `QuickFix`? If yes, a bulk `dart fix` run handles it; if no, each violation is a manual edit. This data is already known to `saropa_lints` — every rule either registers a fix or does not.
- **Source / owner**: is this rule authored by `saropa_lints` (enforceable local policy), by `dart`/`lints`/`flutter_lints` (SDK policy), or by another analyzer plugin? At 22,695 / 23,434 = 96.8%, the top rule is a Dart SDK lint — the user's leverage on it is different (configuration-level, not code-level) from a saropa-authored rule.

Adding two columns to the top-rules table (`Fixable?`, `Source`) changes every triage decision.

### Gap 5 — CONFIGURATION block is empty

Every report in the folder prints `(not available — config was not captured)`. The reporter accepts a `ReportConfig` object (`lib/src/report/analysis_reporter.dart:19-45`) with tier, rule count, rule names, platform filters, package filters, exclusions, and max-issues cap. Something in the run path is not calling `setAnalysisConfig()` before `scheduleWrite()`. Separate narrow bug — but it directly hurts triage because without knowing the tier, the user cannot reason about "what if I dropped to `essential`".

### Gap 6 — No machine-readable twin

`reports/.saropa_lints/violations.json` exists (read by the extension for the Violations view), but `reports/<yyyymmdd>/` only has the `.log` text file. There is no JSON or Markdown twin of the triage report — so neither CI nor an LLM agent can parse the concentration / residual-count data. Producing the same report as JSON and as Markdown (alongside the existing `.log`) unblocks both downstream CI gates and any AI-assisted cleanup work.

### Gap 7 — Pagination / cap is fixed

`_maxInlineViolations = 500` and `_maxFileImportanceRows = 50` are hard-coded in `analysis_reporter.dart:71-80`. For a 23k backlog, 500 inline violations is a rounding error. The user cannot override from the extension config. Either expose the caps as settings, or split into `report.summary.log` (always short) and `report.full.log` (everything, un-capped).

---

## Root Cause

The report format in `lib/src/report/analysis_reporter.dart` was designed for a project with a reasonable backlog — hundreds to low thousands of issues — where a flat enumeration is tolerable. At 23k+ issues the same format inverts: the density of the data hides the single fact (`one rule is 97%`) that the entire triage depends on. The generator has the raw data to compute concentration, residuals, deltas, and fixability (all of it is already in `report_consolidator.dart`'s aggregates) — it simply does not synthesize.

---

## Suggested Fix

Add three new sections to the existing report, in this order, **above** the current `OVERVIEW` block. No existing output is removed — only synthesized views are added. All data needed is already aggregated in `report_consolidator.dart`; no new scans of the AST or disk.

### 1. `CONCENTRATION` (always present when total > 500)

```
CONCENTRATION
  Top rule:   depend_on_referenced_packages       22695  (96.8%)
  Top 3:     + prefer_final_locals (347) + require_rtl_layout_support (98)
             → together 23140 / 23434 = 98.7%
  If top rule were suppressed → residual: 739 issues
  If top 3 rules suppressed   → residual: 294 issues
```

### 2. `CHANGE SINCE LAST RUN` (when a prior `*_saropa_lint_report.log` exists in the same date folder)

```
CHANGE SINCE LAST RUN   (reports/20260424/20260424_094124_saropa_lint_report.log)
  Total:     23434 → 13568   (-9866, -42.1%)
  New rules triggered: 0
  Rules no longer triggered: 26     (dominant cause of delta — drill-down below)
```

Glob the neighbor files, sort descending by filename, read the most recent that is *not* the current report, compute a count diff.

### 3. `RECOMMENDED TRIAGE` (always present when total > 1000)

```
RECOMMENDED TRIAGE
  Step 1 — Suppress (highest-leverage, lowest risk)
    depend_on_referenced_packages   22695   source: dart-lints   → residual: 739
    (WARNING-severity package-hygiene lint; baseline or disable in analysis_options.yaml)

  Step 2 — Baseline remaining bulk
    739 residual issues → write baseline via:
      dart run saropa_lints:baseline --target <workspace>

  Step 3 — Fix highest-score files (manual, biggest payoff)
    1. lib/components/primitive/buttons/common_button.dart      score 599, 28 issues
    2. lib/service/static_data/import_static_data.dart          score 474, 43 issues
    3. lib/components/contact/import/import_single_contact_form.dart  score 440, 48 issues
    ...
```

### Additionally: widen the TOP RULES table

```
TOP RULES
   #  Rule                               Count  %of-total  Severity  Source       Fixable?
   1  depend_on_referenced_packages      22695     96.8%   WARNING   dart-lints   No
   2  prefer_final_locals                  347      1.5%   INFO      saropa       Yes
   3  require_rtl_layout_support            98      0.4%   WARNING   saropa       No
   ...
```

`Source` is one of `saropa`, `dart-lints`, `flutter-lints`, `other` — derived from the rule registration site. `Fixable?` is known at rule-registration time (each rule either has a `QuickFix` or not).

### Separately: fix CONFIGURATION-not-captured (Gap 5)

One-line fix in the run entrypoint: call `AnalysisReporter.setAnalysisConfig(...)` before the first `scheduleWrite`. Narrow, mechanical — worth splitting into its own bug if the agent prefers.

---

## Fixture Gap

N/A — report-format bug. Manual verification:

1. Run analysis on `d:/src/contacts` at `recommended` tier; confirm the new `CONCENTRATION` section names `depend_on_referenced_packages` at 96.8% and quotes residual 739.
2. Run twice back-to-back; confirm `CHANGE SINCE LAST RUN` appears on the second run and is absent on the first.
3. Run on a small project (< 500 issues); confirm `CONCENTRATION` and `RECOMMENDED TRIAGE` are suppressed (gated by thresholds so small projects still see the original concise report).
4. Confirm `CONFIGURATION` block now lists tier, enabled-rule count, and exclusions instead of `(not available)`.

---

## Changes Made

- **New module** [lib/src/report/report_synthesis.dart](../lib/src/report/report_synthesis.dart) — pure functions for concentration math, residual-after-suppress, delta lookup against sibling reports, and rule-source classification (`saropa` / `dart-lints` / `flutter-lints` / `other`). No I/O or static state except `findPreviousRunTotal`, which is extracted so the rest is unit-testable with synthetic inputs.
- **Reporter integration** [lib/src/report/analysis_reporter.dart](../lib/src/report/analysis_reporter.dart) — three new sections (`CONCENTRATION`, `CHANGE SINCE LAST RUN`, `RECOMMENDED TRIAGE`) are inserted between the header and `CONFIGURATION`. They share one synthesis pass with the widened `TOP RULES` table so percentages and residuals never diverge between sections. New `setPluginRuleMetadata(saropaRuleNames, fixableRuleNames)` hook lets the plugin publish authoritative sets so the reporter can attribute each rule without re-instantiating anything.
- **Widened TOP RULES table** — gains `% of total`, `Source`, and `Fixable?` columns. Long rule names are truncated with `...` (ASCII) so terminals without U+2026 support still render correctly.
- **Plugin metadata publishing** [lib/saropa_lints.dart](../lib/saropa_lints.dart) — `_buildRuleFactoriesMap` (the single place both `rulesWithFixes` and the factory-map keys are computed) now calls `AnalysisReporter.setPluginRuleMetadata` so both the CLI scan path and the analyzer-plugin path populate the metadata through the same lazy initialization.
- **Gap 5 fix (CONFIGURATION empty)** [lib/src/native/saropa_context.dart](../lib/src/native/saropa_context.dart) — `_ensureConfigLoadedFromProjectRoot` now captures a `ReportConfig` snapshot immediately after `loadNativePluginConfigFromProjectRoot` runs, so the analyzer-plugin path populates the same config block the CLI path already writes. Tier / platform / package filters remain empty on this path because they aren't knowable from the plugin entrypoint (the scan CLI supplies its own full config).

**Gap coverage against the bug report:**

| Gap | Addressed? | Where |
|---|---|---|
| 1 — Concentration callout | Yes | `_writeConcentration`, threshold ≥ 25% single or ≥ 80% top-three |
| 2 — Path to zero | Yes | `_writeTriage` (suppress + auto-fix + file-importance pointer) |
| 3 — Delta vs prior run | Yes | `_writeRunDelta` via `findPreviousRunTotal` glob + parse |
| 4 — Fixability + Source columns | Yes | Widened TOP RULES table |
| 5 — CONFIGURATION empty | Yes | `_captureReportConfigSnapshot` in SaropaContext |
| 6 — JSON/Markdown twin | Deferred | Pure synthesis logic is now reusable; JSON/Markdown surfaces not added in this change |
| 7 — Pagination / cap configurable | Deferred | `_maxInlineViolations` / `_maxFileImportanceRows` remain hard-coded |

---

## Tests Added

[test/report_synthesis_test.dart](../test/report_synthesis_test.dart) — 18 tests covering:

- `buildRuleRows` sort order, share derivation, source classification (saropa / dart-lints / other), and empty input
- `buildConcentration` dominant-rule trigger (with real-world 96.8% scenario), aggregate top-three trigger independence from the single-rule cutoff, flat-distribution no-trigger, empty-rows safe zero summary
- `buildTriage` suppress/auto-fix split, `maxPerGroup` cap, empty plan handling, residual-after-suppress math
- `findPreviousRunTotal` null on first run, correct delta, "most recent prior" selection with multiple siblings, unparseable-file tolerance (falls back to older valid file), missing-folder handling
- `RunDelta` percent-change zero-guard and negative-delta improving scenarios

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: `^12.3.4` (per `CHANGELOG.md` top entry)
- Dart SDK: project-dependent (reproduced against a Flutter 3.x project)
- Triggering project: `d:/src/contacts` — 1,185 files, 68 rules triggered, 23,434 issues
- Captured reports: `d:/src/contacts/reports/20260424/20260424_093112_saropa_lint_report.log` (23,434-issue run) and `20260424_094124_saropa_lint_report.log` (13,568-issue run)
