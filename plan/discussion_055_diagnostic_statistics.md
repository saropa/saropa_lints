# Discussion: Diagnostic Statistics (Track hit counts per rule for metrics/reporting)

**Source:** [GitHub Discussion #55](https://github.com/saropa/saropa_lints/discussions/55)  
**Priority:** Low (most functionality already implemented)  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)  
**Status:** Largely implemented — remaining gaps are incremental

---

## 1. Goal

Track how many times each rule fires across a codebase to support:

- **Tuning overly aggressive rules** — Identify rules that fire too often and may need relaxation, better heuristics, or tier reclassification.
- **Identifying problem files** — See which files trigger the most violations (and for which rules).
- **Measuring progress over time** — Compare runs (e.g. before/after refactors, sprint-over-sprint).
- **Prioritizing fixes** — e.g. "847× `avoid_print` vs 3× `avoid_hardcoded_credentials`" to focus remediation on high-impact or security rules first.

---

## 2. Current state in saropa_lints

### 2a. Linter core (already implemented)

**ProgressTracker** (in `saropa_lint_rule.dart`) maintains:

- `_issuesByRule`: `Map<String, int>` — count of violations per rule name.
- `_issuesByFile`: `Map<String, int>` — count per file.
- `_issuesByFileByRule`: per-file, per-rule breakdown for accurate clearing on re-analysis.

**Additional tracking infrastructure:**

- **ImpactTracker** — tracks violations by impact level (critical/high/medium/low/opinionated) with per-violation records (file, line, rule, message).
- **RuleTimingTracker** — tracks rule execution time and identifies slow rules.
- **FileMetrics / FileMetricsCache** — caches file-level metrics via ProjectContext.

**Console summary** (via `ProgressTracker.reportSummary()`):

- "TOP TRIGGERED RULES" (top 5) and "TOP FILES WITH ISSUES" (top 5).
- Severity breakdown (ERROR, WARNING, INFO counts).
- Slow file warnings when analysis exceeds 2 seconds.

**Report files** (via `AnalysisReporter`):

- Written to `reports/<YYYYMMDD>/<YYYYMMDD_HHMMSS>_saropa_lint_report.log`.
- Sections: Overview, By Impact, By Severity, TOP RULES, FILE IMPORTANCE, FIX PRIORITY, PROJECT STRUCTURE.

**Violations export:**

- `violations.json` at `reports/.saropa_lints/violations.json` — structured JSON consumed by the extension.
- Contains: raw violations array (file, line, rule, message, severity, impact, OWASP mapping), summary data, config data, timestamp.

### 2b. VS Code extension (already implemented)

The extension consumes `violations.json` and presents statistics through multiple views:

| View | What it shows |
|------|---------------|
| **Overview Tree** | Combined dashboard: health score, violations, trends, embedded config |
| **Summary Tree** | Total violations, tier, files analyzed/with issues, breakdowns by severity and impact |
| **Issues Tree** | Violations grouped by rule, with triage groups (A/B/C/D by volume) |
| **File Risk Tree** | Files ranked by violation density (riskiest files first) |
| **Security Posture Tree** | OWASP Top 10 coverage matrix (Mobile & Web) |
| **Suggestions Tree** | Actionable "what to do next" items |

**Additional extension capabilities:**

- **Health score** (0–100) with score bands, delta tracking, regression detection, and threshold nudges.
- **Inline annotations** (code decorations, code lens, hover provider, diagnostics provider).
- **Score history tracking** and trend detection across runs.
- **Rule explain panel** — detailed rule info on demand via webview.
- **Copy as JSON** — export tree nodes for external consumption.

### 2c. What the original Discussion #55 proposed vs what exists

| Proposed feature | Status | Notes |
|-----------------|--------|-------|
| `hitCounts` map (rule → count) | **Implemented** | `ProgressTracker._issuesByRule` — tracking is external to rule class, which is the correct architecture |
| `fileHits` map (rule → files) | **Implemented** | `ProgressTracker._issuesByFileByRule` provides this |
| Per-rule `hitCount` getter on SaropaLintRule | **Not needed** | Statistics belong in ProgressTracker, not on rule instances — separation of concerns |
| CI / quality gates | **Partially implemented** | Health score and thresholds exist; no per-rule threshold gates yet |
| Dashboard visualization | **Implemented** | Extension provides multiple views, charts, health score |
| Trend / progress tracking | **Implemented** | Score history, delta tracking, regression detection in extension |

---

## 3. Remaining gaps

These are incremental improvements, not foundational work:

### ~~3a. Structured statistics export (JSON)~~ — DONE

`violations.json` already contains everything a CI pipeline or dashboard needs in its `summary` section: `issuesByRule`, `issuesByFile`, `bySeverity`, `byImpact`, `totalViolations`, `filesAnalyzed`, `filesWithIssues`, and `ruleSeverities`. No separate file is needed.

A **schema reference document** has been added at [`lib/src/report/VIOLATIONS_JSON_SCHEMA.md`](../lib/src/report/VIOLATIONS_JSON_SCHEMA.md) documenting `violations.json` and `consumer_contract.json` as stable public contracts with:

- Full field-by-field documentation for all sections (`config`, `summary`, `violations`)
- CI usage examples (`jq` one-liners for threshold checks, top-triggered rules, etc.)
- Stability guarantees (additive-only changes without version bump, breaking changes require version bump)
- Companion `consumer_contract.json` documentation (health score weights, tier rule sets)

External consumers can now depend on the schema with confidence.

### 3b. Per-rule threshold gates for CI

The health score provides a single aggregate gate. Per-rule thresholds would enable:

- "Fail CI if `avoid_hardcoded_credentials` > 0"
- "Warn if `avoid_print` > 50"

This could be configured in `analysis_options.yaml` or a dedicated `saropa_thresholds.yaml`.

### 3c. Diff / baseline comparison

Compare current run against a saved baseline to report only *new* violations. Useful for:

- PR checks ("this PR introduces 3 new violations")
- Sprint-over-sprint tracking

**Consideration:** The extension already tracks score deltas and detects regressions. A CLI-level baseline comparison (e.g. `saropa_lints --baseline reports/.saropa_lints/baseline.json`) would extend this to CI without the extension.

---

## 4. Use cases (updated)

| Use case | Current support | Gap |
|----------|----------------|-----|
| CI / quality gates | Health score thresholds, `dart analyze --fatal-infos` | Per-rule thresholds (§3b) |
| Dashboards | Extension views, health score, charts, violations.json schema doc | None — well covered |
| Onboarding | Summary tree, suggestions tree, triage groups | None — well covered |
| Rule maintenance | TOP RULES in reports, triage groups in extension | None — well covered |
| Security audits | Security Posture tree, OWASP mapping in violations.json | None — well covered |
| Trend tracking | Score history, delta detection, regression nudges | CLI-level baseline diff (§3c) |

---

## 5. Research & prior art

- **ESLint:** No built-in "run statistics" file; tools like `eslint-formatter-json` or custom formatters output counts per rule, which CI then parses.
- **SonarQube:** Exposes metrics (issues per rule, per file) via Web API and report files; often used for trend and quality gates.
- **Roslyn (C#):** Analyzers report diagnostics; IDEs and MSBuild aggregate; no standard "statistics API" in-core, but third-party tools can collect and report.
- **Dart analyzer:** Built-in lints don't expose a formal statistics API; custom_lint runs in-process and can maintain in-memory state during a run.

Conclusion: saropa_lints has already surpassed most comparable tools in statistics depth. The remaining gaps (§3a–§3c) are quality-of-life improvements for CI integration.

---

## 6. Implementation considerations

### ~~For §3a (JSON export)~~ — DONE

Schema documented in `lib/src/report/VIOLATIONS_JSON_SCHEMA.md`. No code changes needed.

### For §3b (per-rule thresholds)

- Configuration in `analysis_options.yaml` under a `saropa_lints` key keeps tooling consolidated.
- Threshold checks should run after analysis completes, not during — avoids coupling with rule execution.

### For §3c (baseline comparison)

- Store baseline as a snapshot of `byRule` counts + health score.
- Diff logic: current count minus baseline count per rule; report net new violations.
- The extension's score delta tracking is a model for the CLI-level implementation.

### General

- **Threading / isolation:** ProgressTracker already handles this. No new concurrency concerns for the remaining gaps.
- **Memory:** Current `Set<String>` per rule for file paths works. For very large codebases, the existing approach of capping report output (top N) is sufficient.

---

## 7. Open questions

- ~~Should statistics be opt-in?~~ **Resolved:** Statistics tracking is already always-on in ProgressTracker with negligible overhead.
- ~~Should fileHits be optional?~~ **Resolved:** Already implemented in ProgressTracker with acceptable memory usage.
- ~~Should the CI-friendly JSON export (§3a) be a new file or an extension of `violations.json`?~~ **Resolved:** `violations.json` already contains all needed statistics. Schema documented in `lib/src/report/VIOLATIONS_JSON_SCHEMA.md`.
- Should per-rule thresholds (§3b) live in `analysis_options.yaml` or a separate config file?
- Should baseline comparison (§3c) be a linter-core feature or an extension/CLI-tool feature?

---

## 8. Decision

Most of Discussion #55 is **already implemented**. §3a is now **done** (schema documented). The remaining gaps (§3b per-rule thresholds, §3c baseline comparison) are independent enhancements that can be prioritized individually. None require changes to `SaropaLintRule` — the original proposal to add static fields to the rule class was superseded by the better architecture of external tracking via ProgressTracker and ImpactTracker.

**Recommendation:** Close Discussion #55 as complete. File separate issues for §3b and §3c if/when they become priorities.
