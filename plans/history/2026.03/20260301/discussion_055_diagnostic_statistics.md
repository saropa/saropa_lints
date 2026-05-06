# Discussion: Diagnostic Statistics (Track hit counts per rule for metrics/reporting)

**Source:** [GitHub Discussion #55](https://github.com/saropa/saropa_lints/discussions/55)  
**Priority:** Medium  
**ROADMAP:** Part 3 — Planned Enhancements (SaropaLintRule Base Class)

---

## 1. Goal

Track how many times each rule fires across a codebase to support:

- **Tuning overly aggressive rules** — Identify rules that fire too often and may need relaxation, better heuristics, or tier reclassification.
- **Identifying problem files** — See which files trigger the most violations (and for which rules).
- **Measuring progress over time** — Compare runs (e.g. before/after refactors, sprint-over-sprint).
- **Prioritizing fixes** — e.g. "847× `avoid_print` vs 3× `avoid_hardcoded_credentials`" to focus remediation on high-impact or security rules first.

---

## 2. Current state in saropa_lints

- **ProgressTracker** already maintains:
  - `_issuesByRule`: `Map<String, int>` — count of violations per rule name.
  - `_issuesByFile`: `Map<String, int>` — count per file.
  - `_issuesByFileByRule`: per-file, per-rule breakdown for accurate clearing on re-analysis.
- **Report summary** (at end of analysis) includes:
  - "TOP TRIGGERED RULES" (top 5) and "TOP FILES WITH ISSUES" (top 5).
  - Full breakdowns are written to a timestamped log under `reports/<date>/` when analysis completes.
- **AnalysisReporter** writes detailed reports (path set via project root); report format and content are implementation-defined.
- **Gap:** No first-class, stable API for "diagnostic statistics" as a product feature: no `SaropaLintRule`-level hit counts, no `fileHits` (which files triggered which rule), and no explicit export for tooling (e.g. CI metrics, dashboards). The data exists internally but is not exposed as a dedicated statistics API or file format (e.g. JSON) for external consumers.

---

## 3. Proposed design (from Discussion #55)

```dart
abstract class SaropaLintRule extends DartLintRule {
  static final Map<String, int> hitCounts = {};
  static final Map<String, Set<String>> fileHits = {};

  int get hitCount => hitCounts[code.name] ?? 0;
}
```

- **hitCounts:** rule name → total number of times the rule reported a diagnostic in this run.
- **fileHits:** rule name → set of file paths where the rule fired (optional; enables "which files have violations for rule X?").
- **hitCount getter:** per-rule instance API for tests or tooling that need to query after a run.

**Integration point:** Whenever a rule reports a diagnostic (e.g. via `SaropaDiagnosticReporter.atNode` / `atOffset`), increment `hitCounts[ruleName]` and add `currentFilePath` to `fileHits[ruleName]`. This can be implemented inside the reporter so all rules get statistics without per-rule code.

---

## 4. Use cases

| Use case | How statistics help |
|----------|----------------------|
| CI / quality gates | Fail or warn when a rule’s hit count exceeds a threshold (e.g. no new `avoid_print` in main). |
| Dashboards | Plot trends: rule X count over time per branch or release. |
| Onboarding | Show "your project has N violations for rule Y" to guide which rules to enable or fix first. |
| Rule maintenance | Find rules that fire 1000+ times in typical projects and may need tuning or moving to a higher tier. |
| Security audits | Report "security-related rules fired M times" and list files (from fileHits) for review. |

---

## 5. Research & prior art

- **ESLint:** No built-in "run statistics" file; tools like `eslint-formatter-json` or custom formatters output counts per rule, which CI then parses.
- **SonarQube:** Exposes metrics (issues per rule, per file) via Web API and report files; often used for trend and quality gates.
- **Roslyn (C#):** Analyzers report diagnostics; IDEs and MSBuild aggregate; no standard "statistics API" in-core, but third-party tools (e.g. NuGet packages) can collect and report.
- **Dart analyzer:** Built-in lints don’t expose a formal statistics API; custom_lint runs in-process and can maintain in-memory state (e.g. hit counts) during a run.

Conclusion: Implementing statistics inside the linter (hit counts + optional file sets) and optionally exporting them (e.g. JSON or existing report format) is a common pattern and fits saropa_lints’ architecture.

---

## 6. Implementation considerations

- **Threading / isolation:** custom_lint may run rules in parallel or in separate isolates. Any global `hitCounts` / `fileHits` must be updated in a thread-safe way (e.g. merge from workers at end of run) or maintained per-run in a single-threaded phase.
- **Memory:** For large codebases, `Set<String>` per rule for file paths can grow. Option: cap file set size, or store only count and top-N files per rule.
- **Re-analysis:** On file re-analysis, ProgressTracker already clears per-file data; statistics should either be reset per run or merged so "full run" stats are well-defined.
- **Output:** Decide whether to add a dedicated "diagnostic statistics" report (e.g. `saropa_diagnostic_stats.json`) or extend the existing report/log format so CI and dashboards can consume it without parsing terminal output.

---

## 7. Open questions

- Should statistics be opt-in (e.g. env flag like `SAROPA_LINTS_STATS=true`) to avoid any overhead in default runs?
- Should fileHits be optional (configurable) to reduce memory on large codebases?
- Should we support "diff" semantics (e.g. only count new violations since baseline) for trend reporting?
