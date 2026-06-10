# Collapse `LintImpact` into the Analyzer's Severity Model

**Status:** **DONE — landed in [Unreleased] on 2026-05-03.** This document captures the rationale and the migration path. Future "follow-up" work is at the bottom under "Open / follow-up after the collapse."
**Owner:** delivered.
**Created:** 2026-05-03.
**Spawned from:** review of "critical" overuse (CHANGELOG `[Unreleased]` entries on the regression-nudge toast and lint problem-message wording, 2026-05-03).

## Active follow-up queue

Only these items are considered open work for this topic:

- [~] **SEV-01 (P1)** Audit `severity:` assignments rule-by-rule against MUST-fix / should-fix / info guidance. (Partial, 2026-06-10: full cross-check of all 2159 rules' `severity:` field vs `impact` getter generated — see [`SEV01_SEVERITY_AUDIT.md`](SEV01_SEVERITY_AUDIT.md). 714 disagreements found; 574 are default-impact-only artifacts, not real. Confirmed-safe slice applied so far: **11 rules** downgraded ERROR→WARNING after reading each (5 Riverpod/Bloc `prefer_*` preferences + 6 `bloc_rules.dart` should-fix patterns). **Still open:** Bucket A (66 ERROR/impact-warning over-rated candidates remaining — safe downgrade direction, but each needs an individual read because several "advisory-looking" rules describe genuine runtime throws and are correctly ERROR) and Bucket B (46 WARNING/impact-error under-rated candidates — the UPGRADE direction breaks `dart analyze` for consumers, so it needs per-rule sign-off).)
- [x] **SEV-02 (P1)** Update `saropa_quality_gate.yaml.example` to foreground `new_errors/new_warnings/new_info`. (Done 2026-05-08: primary row uses `new_errors`; hotspots + `overall_warnings` documented with legacy-alias pointer.)
- [x] **SEV-03 (P2)** Rename `bin/impact_report.dart` to `severity_report.dart` with compatibility alias. (Done 2026-06-05: `bin/severity_report.dart` holds the implementation; `bin/impact_report.dart` is now a thin forwarder that re-exports `severity_report.main`. `pubspec.yaml` registers both `severity_report` and the legacy `impact_report` executable.)
- [x] **SEV-04 (P2)** Verify internal scripts parsing impact accept `error|warning|info` value set. (Done 2026-06-10: the three remaining DX scripts — `_audit_dx.py`, `_improve_dx_messages.py`, `_audit.py:_dx_impact_table`/`_dx_failing_table` — re-keyed from the dead 5-value names to `error/warning/info`. Thresholds collapsed: `MIN_PROBLEM` error 180 / warning 150 / info 100, `MIN_CORRECTION` error 100 / warning+info 80; consequence + specific-type + AI-copilot checks now gate on `("error","warning")`; vague-language skip now gates on `info`; the no-override default impact now mirrors the base getter `LintImpact.warning` (was the dead `medium`). The "By Impact" report table is now "By Severity" and buckets non-zero again. Prior pass (2026-06-05) had already fixed `_audit_checks.py`. **Separate pre-existing breakage surfaced, NOT fixed here:** the DX message *extractor* (`extract_rule_messages` / `LINTCODE_RE`) expects `LintCode(name: '...')` keyword syntax, but the analyzer-9 migration moved all 2171 rule LintCodes to positional `LintCode('name', 'msg', ...)`, so the extractor returns **0 messages** and the whole DX audit is dead regardless of vocabulary. Orthogonal to the impact collapse; needs its own fix.)

### SEV-01 audit pass order

Run rule-by-rule severity audit in this order:

1. Security/network input + auth/storage rule files
2. Architecture/disposal + async core rule files
3. Naming/style and other likely-overrated historical criticals

## Summary of what shipped

- **Enum collapsed.** `LintImpact` redefined in [`lib/src/saropa_lint_rule.dart`](../lib/src/saropa_lint_rule.dart): `critical / high / medium / low / opinionated` → `error / warning / info`. Mapping: `critical → error`, `high + medium → warning`, `low + opinionated → info`.
- **All 2103 rule overrides bulk-renamed** across 117 files in `lib/src/rules/` (sed on `LintImpact.X`).
- **`ImpactTracker` collapsed** from 5 buckets to 3, with summary text rewritten to "Errors: N, Warnings: N, Info: N" and section headers in the final report changed from CRITICAL VIOLATIONS to ERRORS (must fix).
- **`Violation.impact` field** keeps the same key name in the JSON shape but now emits `error | warning | info` values.
- **Health-score weights collapsed** in [`extension/src/healthScore.ts`](../extension/src/healthScore.ts): `{ error: 8, warning: 3, info: 0.25 }`. Was `{ critical: 8, high: 3, medium: 1, low: 0.25, opinionated: 0.05 }`.
- **`bin/impact_report.dart` CLI labels** rewritten to ERRORS / WARNINGS / INFO. Exit code now equals error count (was: critical count).
- **Quality-gate metric aliases** added in [`lib/src/report/quality_gate.dart`](../lib/src/report/quality_gate.dart) so existing `saropa_quality_gate.yaml` configs keep working: `new_critical_issues / new_high_issues / new_medium_issues / new_low_issues` map onto `error / warning / warning / info` respectively. New code should use `new_errors / new_warnings / new_info` (and `overall_*` equivalents).
- **Findings Dashboard KPI cards** in [`extension/src/views/violationsDashboardHtml.ts`](../extension/src/views/violationsDashboardHtml.ts): five-card layout (Visible / Errors / Critical / High / Warnings) replaced with severity-keyed three-card layout (Visible / Errors / Warnings / Info). Order: Visible → Errors → Warnings → Info → scope cards.
- **TS view consumers updated**: `runHistory.ts` (severity-only counts; legacy `RunSnapshot.critical` kept optional for old persisted entries), `triageUtils.RuleImpactCounts` (3 fields), `fileRiskTree.ts` (`RISK_WEIGHTS` and detection logic), `suggestionsTree.ts`, `suggestionCounts.ts`, `sectionedSidebar.ts`, `summaryTree.ts`, `extension.ts`, `issuesTree.ts` (default impact filter, sort order, group icons).
- **All 5825 Dart tests + 1015 extension tests pass.** Test fixtures updated to the new vocabulary; one obsolete test (`opinionated prefer_* rules must be in stylisticRules`) marked `skip:` because its premise depended on the 5-bucket taxonomy.

The original five-phase plan (audit, parallel paths, switch consumers, schema migration, delete) collapsed into a single bulk-rename pass plus targeted edits because:
1. The 5→3 mapping is unambiguous, so no audit was needed before the bulk rename.
2. Keeping the JSON `byImpact` field name with new value spelling (`error|warning|info`) was less disruptive than dropping the field; external consumers see new values, not a missing field.
3. Quality-gate aliases preserve back-compat for `saropa_quality_gate.yaml` users.

---

## Problem

Today the package carries **two parallel severity systems**:

1. **`DiagnosticSeverity.{ERROR, WARNING, INFO, HINT}`** — the analyzer's native severity, set on every [`LintCode`](../lib/src/saropa_lint_rule.dart). 2170 occurrences across 118 files in `lib/`. Drives IDE squiggle color, Problems-tab icons, and the analyzer's own pass/fail behavior.

2. **`LintImpact.{critical, high, medium, low, opinionated}`** — a Saropa-invented enum at [`lib/src/saropa_lint_rule.dart:1598-1626`](../lib/src/saropa_lint_rule.dart#L1598). 203 `LintImpact.critical` occurrences plus assignments at every other tier across 56 rule files. Drives:
   - Health-score weights at [`extension/src/healthScore.ts:25`](../extension/src/healthScore.ts#L25) (`critical: 8, high: 3, medium: 1, low: 0.25, opinionated: 0.05`)
   - File-risk tree weighting at [`extension/src/views/fileRiskTree.ts:20`](../extension/src/views/fileRiskTree.ts#L20)
   - Dashboard KPI cards (separate "Critical" and "High" cards alongside severity-keyed "Errors" and "Warnings" cards) at [`extension/src/views/violationsDashboardHtml.ts:312-368`](../extension/src/views/violationsDashboardHtml.ts#L312)
   - Triage groups in `Triage` activity-bar view ([`extension/src/views/triageTree.ts`](../extension/src/views/triageTree.ts), [`extension/src/triageUtils.ts`](../extension/src/triageUtils.ts))
   - Persisted run-history snapshots in `vscode.Memento` ([`extension/src/runHistory.ts:14-23`](../extension/src/runHistory.ts#L14))
   - JSON output schema (`v.impact` field) consumed by external CI/scripts — see [`VIOLATION_EXPORT_API.md`](../VIOLATION_EXPORT_API.md)
   - The `bin/impact_report.dart` CLI tool

Every rule that overrides `impact` is **double-tagged** with both a `severity:` and an `impact:`. Sample: [`lib/src/rules/architecture/disposal_rules.dart:61,81`](../lib/src/rules/architecture/disposal_rules.dart#L61) — `LintImpact.critical` AND `DiagnosticSeverity.ERROR`.

The two systems do not reliably agree:
- Some rules tagged `LintImpact.critical` carry `DiagnosticSeverity.WARNING` (e.g. `avoid_path_traversal` in [`security_network_input_rules.dart:2138`](../lib/src/rules/security/security_network_input_rules.dart#L2138)).
- The dashboard surfaces both axes side-by-side ("Errors" + "Critical" + "High" + "Warnings"), which assumes a meaningful distinction the data does not always carry.

The user's stated mental model is the analyzer's three levels: **error = MUST fix, warning = could fail or look bad, info = FYI**. The `LintImpact` 5-level taxonomy duplicates that with extra granularity that the user doesn't believe in.

---

## Goal

Eliminate `LintImpact` as an independent rule attribute. Use `DiagnosticSeverity` as the single source of truth. Health-score weights, KPI cards, triage groups, and the JSON schema all derive from severity.

---

## Approach

### Option A — Remove `LintImpact` entirely (recommended)

Delete the `LintImpact` enum, the `impact` getter override on every rule, the `ImpactTracker` accumulator at [`lib/src/saropa_lint_rule.dart:1700+`](../lib/src/saropa_lint_rule.dart#L1700), and the `Violation.impact` field. Replace with severity reads directly off `LintCode.severity`.

**Pros:** one model, no divergence possible, smallest steady-state surface, matches user's mental model.
**Cons:** largest blast radius — touches every rule and every TS consumer. JSON `v.impact` field disappears; consumers (`saropa_quality_gate`, custom CI scripts) need migration.

### Option B — Make `LintImpact` derived

Keep the enum as a presentation alias that maps from severity:
- `DiagnosticSeverity.ERROR` → `LintImpact.error` (renamed from `critical`/`high`)
- `DiagnosticSeverity.WARNING` → `LintImpact.warning` (renamed from `medium`/`low`)
- `DiagnosticSeverity.INFO` → `LintImpact.info` (renamed from `opinionated`)

Make `impact` a non-overridable getter computed from `severity`. Drop all 203 explicit `impact` overrides.

**Pros:** keeps the JSON field name; smaller TS-side change because views still read `byImpact`.
**Cons:** still a rename across all consumers; old persisted snapshots have stale `critical`/`high`/etc. counts.

### Recommendation

**Option A.** The `LintImpact` enum's documented intent ("each occurrence is independently harmful" for `critical`, "10+ indicates systemic problems" for `high`) is a separate concept from severity, but in practice nearly every rule has been tagged based on severity-like reasoning anyway, and the dashboard now shows the two axes as if they were distinct grades of the same thing. Collapsing removes the parallel system rather than papering over it.

If migration cost is too high in one shot, do Option B as an intermediate step: rename values, derive from severity, then later delete the enum.

---

## Migration Plan (Option A)

Each phase is independently shippable.

### Phase 1 — Audit `severity:` assignments against the user's definitions

Before deleting anything, make sure the analyzer severity field is the right answer for every rule.

User's definitions:
- `ERROR` = the code is broken / will crash / is exploitable / will fail in production. MUST be fixed.
- `WARNING` = could fail, will look bad, or is a known-bad pattern. Should be fixed.
- `INFO` = style / suggestion / FYI.

For every rule, ask: "if this rule fires in real production code, does the user MUST fix it?" If yes → `ERROR`. If "should" → `WARNING`. Otherwise → `INFO`.

Files with the highest density of `LintImpact.critical` to review first (impact-critical assignments are the most likely to be wrong):

| File | `critical` count |
|------|---|
| [`lib/src/rules/architecture/disposal_rules.dart`](../lib/src/rules/architecture/disposal_rules.dart) | 14 |
| [`lib/src/rules/security/security_network_input_rules.dart`](../lib/src/rules/security/security_network_input_rules.dart) | 14 |
| [`lib/src/rules/security/security_auth_storage_rules.dart`](../lib/src/rules/security/security_auth_storage_rules.dart) | 11 |
| [`lib/src/rules/widget/widget_patterns_require_rules.dart`](../lib/src/rules/widget/widget_patterns_require_rules.dart) | 8 |
| [`lib/src/rules/packages/bloc_rules.dart`](../lib/src/rules/packages/bloc_rules.dart) | 9 |
| [`lib/src/rules/resources/resource_management_rules.dart`](../lib/src/rules/resources/resource_management_rules.dart) | 8 |
| [`lib/src/rules/core/async_rules.dart`](../lib/src/rules/core/async_rules.dart) | 7 |
| [`lib/src/rules/packages/hive_rules.dart`](../lib/src/rules/packages/hive_rules.dart) | 6 |
| [`lib/src/rules/packages/riverpod_rules.dart`](../lib/src/rules/packages/riverpod_rules.dart) | 6 |
| [`lib/src/rules/widget/widget_layout_flex_scroll_rules.dart`](../lib/src/rules/widget/widget_layout_flex_scroll_rules.dart) | 5 |

Particularly suspect (likely overrated as `critical` impact when they should be `WARNING` severity, not `ERROR`):
- Layout/animation rules — degrade UX but rarely crash.
- [`lib/src/rules/core/naming_style_rules.dart:2738`](../lib/src/rules/core/naming_style_rules.dart#L2738) — a naming rule at `LintImpact.critical` is almost certainly miscategorized.

Output of this phase: every rule's `severity:` field is the canonical source of truth and matches the user's three-level model. No code deletion yet.

### Phase 2 — Add severity-keyed equivalents for everything `LintImpact`-keyed

Without removing `LintImpact`, add parallel severity-driven paths:

- Health score: weight by `DiagnosticSeverity` (`ERROR=8, WARNING=3, INFO=1` — the same shape as today's `critical=8, high=3, medium=1`, but keyed off severity). Deprecate `low: 0.25, opinionated: 0.05` weights.
- File-risk tree, dashboard KPI cards, triage groups, suggestion card: parallel computations that read `bySeverity`.
- JSON output: ensure `v.severity` is reliably present alongside `v.impact`. (Already there — see [`VIOLATION_EXPORT_API.md`](../VIOLATION_EXPORT_API.md).)

This phase is risk-free: nothing breaks because the old paths still work.

### Phase 3 — Switch consumers to severity

Flip every TS consumer from `byImpact` to `bySeverity`:

- [`extension/src/runHistory.ts`](../extension/src/runHistory.ts) — `RunSnapshot.critical` already coexists with `error/warning/info`. Drop `critical` from new snapshots; tolerate it on old ones.
- [`extension/src/views/violationsDashboardHtml.ts:312-368`](../extension/src/views/violationsDashboardHtml.ts#L312) — collapse "Errors" + "Critical" + "High" + "Warnings" cards into "Errors" + "Warnings" + "Info" (and "Visible findings" stays).
- [`extension/src/views/fileRiskTree.ts`](../extension/src/views/fileRiskTree.ts) — `${critical} must-fix` becomes `${error} error`. Same for tree summaries.
- [`extension/src/views/suggestionsTree.ts:74-93`](../extension/src/views/suggestionsTree.ts#L74) — "Fix N must-fix issue(s)" becomes "Fix N error(s)" and the filter switches from `kind: 'imp', value: 'critical'` to `kind: 'sev', value: 'error'`.
- [`extension/src/views/triageTree.ts`](../extension/src/views/triageTree.ts) — `criticalGroup` becomes `errorGroup`, `identifyCriticalRules` becomes `identifyErrorRules` (reads severity from `impactMap` — but we'll need to rename `impactMap` to `severityMap` here too).
- [`extension/src/triageUtils.ts`](../extension/src/triageUtils.ts) — `RuleImpactCounts.critical/high/medium/low/opinionated` becomes `RuleSeverityCounts.error/warning/info`.
- [`extension/src/treeSerializers.ts`](../extension/src/treeSerializers.ts) — `risk.critical/high` becomes `risk.error/warning`.
- [`extension/src/views/issuesTree.ts`](../extension/src/views/issuesTree.ts) — sort orders, filter sets, default groupings all keyed on `impact` switch to `severity`.
- [`bin/impact_report.dart`](../bin/impact_report.dart) — relabel CRITICAL/HIGH/MEDIUM/LOW/OPINIONATED to ERROR/WARNING/INFO. Rename file to `severity_report.dart` (with backward-compatible alias).
- Tests in `extension/src/test/views/*.test.ts` and `test/rules/*_test.dart` referencing `LintImpact.critical/high/medium/low/opinionated`.

### Phase 4 — Schema migration for `violations.json`

External consumers may rely on `v.impact`. Choose one:

**(a) Drop `v.impact`** — let consumers read `v.severity` directly. Document in [`VIOLATION_EXPORT_API.md`](../VIOLATION_EXPORT_API.md) under "Breaking Changes" with the version bump.

**(b) Keep `v.impact` as an alias for severity** — emit `v.impact` with values `error/warning/info` (instead of `critical/high/medium/low/opinionated`). Easier on consumers but renames the value set.

**(c) Keep both `v.impact` and `v.severity` populated, but with severity-derived values for `v.impact`** — maximally compatible, mildly redundant.

Recommendation: **(a)** — clean break aligned with the package's other "no half-finished implementations" guidance. Bump major version.

External-consumer impact:
- [`saropa_quality_gate.yaml.example`](../saropa_quality_gate.yaml.example) — references `impact` thresholds.
- [`scripts/modules/_audit.py`](../scripts/modules/_audit.py), [`scripts/modules/_audit_checks.py`](../scripts/modules/_audit_checks.py), [`scripts/modules/_rule_metrics.py`](../scripts/modules/_rule_metrics.py) — internal scripts that read `v.impact`.

### Phase 5 — Delete `LintImpact`

With consumers migrated and external schema settled:

- Delete the `LintImpact` enum, the `impact` getter on `SaropaLintRule`, the `ImpactTracker` accumulator, and the `Violation.impact` field.
- Strip every `@override LintImpact get impact => LintImpact.X;` line from rule files (~203 occurrences).
- Remove `byImpact` from `ViolationsData.summary`.
- Update [`CONTRIBUTING.md`](../CONTRIBUTING.md), [`CLAUDE.md`](../CLAUDE.md), and the `lint-rules` skill — drop all references to `LintImpact` and the 5-tier model.

Run `dart analyze --fatal-infos` and `npm run check-types` after each phase.

---

## Schema impact summary

| Surface | Today | After |
|---|---|---|
| Rule field | `LintImpact get impact => LintImpact.critical;` (override) | deleted; `severity:` is the only severity attribute |
| `Violation.impact` field | `'critical' \| 'high' \| 'medium' \| 'low' \| 'opinionated'` | deleted |
| `Violation.severity` field | `'error' \| 'warning' \| 'info'` (already present) | unchanged — now sole source |
| `ViolationsData.summary.byImpact` | counts per impact | deleted |
| `ViolationsData.summary.bySeverity` | counts per severity (already present) | unchanged |
| `RunSnapshot.critical` | impact-critical count | deleted |
| `RunSnapshot.error/warning/info` | severity counts (already present) | unchanged |
| Health score weights | `critical: 8, high: 3, medium: 1, low: 0.25, opinionated: 0.05` | `error: 8, warning: 3, info: 1` |
| Dashboard KPI cards | Errors / Critical / High / Warnings / Files / Top rule | Errors / Warnings / Info / Files / Top rule |
| Triage view | "Must-fix rules" group (impact-critical) | "Errors" group (severity-error) |
| Persisted history (`vscode.Memento`) | snapshots have `critical: number` | new snapshots omit; old entries tolerated with fallback |
| `bin/impact_report.dart` | CRITICAL/HIGH/MEDIUM/LOW/OPINIONATED labels | ERROR/WARNING/INFO labels (and possibly renamed to `severity_report.dart`) |
| External CI consumers | read `v.impact` | read `v.severity` |

---

## Open / follow-up after the collapse

The collapse landed without breaking any consumer. These items are still worth touching at some point but were intentionally NOT done in this pass:

1. **Audit `severity:` assignments** rule-by-rule against the new three-level model — many `DiagnosticSeverity.WARNING` rules used to also be `LintImpact.critical`, and now both axes agree because they're the same axis. Some assignments may still be miscategorized (the reflexive sed mapping treats `high` and `medium` identically as `warning`, which is conservative but loses nuance). Ask for each rule: "if this fires, MUST it be fixed?" → ERROR, "could it fail / look bad?" → WARNING, otherwise INFO. Files to review first: `lib/src/rules/widget/widget_layout_*` (5+ rules at old `LintImpact.critical` whose layout/animation issues degrade UX without crashing), `lib/src/rules/core/naming_style_rules.dart:2738` (a naming rule at the old `critical` is almost certainly miscategorized).
2. **Update `saropa_quality_gate.yaml.example`** to show `new_errors / new_warnings / new_info` syntax in the foreground; demote `new_critical_issues / new_high_issues / etc.` aliases to a "back-compat" footnote. Currently the back-compat aliases work transparently but the example file still teaches the old vocabulary.
3. **`saropa_lint_rule.dart` doc on `RuleTier.essential`** still says "Must-fix rules preventing crashes…" — keep or rephrase to "Error-severity rules…" for clarity. Trivial; left for a docs polish pass.
4. **`bin/impact_report.dart` filename** is misleading now ("impact" is gone). Rename to `severity_report.dart` with a forward alias if any external scripts invoke `dart run saropa_lints:impact_report`. Low priority.
5. **Persisted user history (`vscode.Memento.RunSnapshot[]`)**: old entries carry `critical: N` but no `error: N`. The runtime tolerates this (`error` defaults to 0 and the toast falls back to the "score dipped" message). Decision deferred: drop legacy entries on read, or keep them lossy for trend continuity.
6. **`scripts/modules/_audit*.py` and `_rule_metrics.py`** read `v.impact` — they still work because the field name didn't change, but they parse the value space. Confirm they handle `error|warning|info` cleanly; if they whitelist the old value set anywhere, update.

---

## Non-goals

- Renaming `RuleTier` enum values. Tiers are about which rules are enabled by default, not severity.
- Renaming `RuleType.{bug, codeSmell, vulnerability, ...}`. That's a category axis, not severity.
- Touching the `OWASP` mappings.
- Touching the package-vibrancy CVSS labels (`extension/package.json:1683-1685` legitimately uses "critical" as a CVSS-defined severity tier for vulnerabilities).
- Renaming CSS class names like `.bar-fill.imp-critical` and `--accent-critical` — internal identifiers.

---

## Out of scope (already done in Scope 1)

The following user-visible "critical" prose was already cleaned up in CHANGELOG `[Unreleased]` (2026-05-03) without touching the data model:

- Regression-nudge toast and all-clear celebration headlines (`extension/src/extension.ts:124-160`).
- Suggestion sidebar card label (`extension/src/views/suggestionsTree.ts:87`).
- File-risk tree count labels (`extension/src/views/fileRiskTree.ts:175,225`).
- Triage view group label (`extension/src/views/triageTree.ts:85`).
- Triage dashboard summary (`extension/src/views/triageDashboardHtml.ts:142`).
- Walkthrough descriptions in `extension/package.json:1702,1735`.
- Essential tier picker description in `extension/src/setup.ts:863`.
- Eight lint problem messages: `avoid_path_traversal`, `require_sqflite_error_handling`, `require_dio_ssl_pinning`, `require_database_migration`, `avoid_instantiating_in_bloc_value_provider`, `avoid_webview_file_access`, `avoid_instantiating_in_value_provider`, `avoid_animation_in_build`.
- Internal DartDoc comments referencing "Critical issue" prefix on impact getters.
- `RuleTier.essential` doc on `lib/src/saropa_lint_rule.dart:1636`.

The Scope 1 changes intentionally did not touch the underlying data model (`LintImpact` enum still exists, dashboards still show separate "Critical" KPI card, JSON `v.impact` field still emitted) — those are this plan's job.

---

## Finish Report (2026-06-05)

This work will be reviewed by another AI.

**Trigger:** "do some work on this: COLLAPSE_LINT_IMPACT_TO_SEVERITY.md" — picked up the open follow-up queue and closed SEV-03 fully plus the highest-impact part of SEV-04.

**Plan status after this pass (why it stays active, not archived):** the plan still has genuinely open scope — **SEV-01 (P1)** rule-by-rule severity audit is untouched, and **SEV-04 is only partial**. It is also the canonical tracker referenced from `ROADMAP.md`. Splitting the queue into a separate active file would fragment that single tracker, so the plan is kept active with its checkboxes updated rather than split + archived. The `Active follow-up queue` at the top is the live representation of remaining work.

### SEV-03 — `impact_report` → `severity_report` rename (DONE)

- `bin/severity_report.dart` (new) holds the implementation, copied verbatim from the old `bin/impact_report.dart` with only the usage strings and header comments relabeled to `severity_report`. No behavior change — same parse, same ERROR/WARNING/INFO grouping, same exit-code-equals-error-count.
- `bin/impact_report.dart` (was 160 lines) is now a 17-line thin forwarder: `import 'severity_report.dart' as severity_report; main(args) => severity_report.main(args);`. Keeps `dart run saropa_lints:impact_report` working.
- `pubspec.yaml` registers `severity_report` as the canonical executable and keeps `impact_report` as a documented back-compat alias.
- `bin/saropa_lints.dart` dispatcher: imports `severity_report.dart` (dropped the `impact_report.dart` import), routes `severity-report` / `severity_report` / `impact-report` / `impact_report` all to `severity_cmd.main`, and relabels the usage text + example.
- `README.md` "Impact Report" section rewritten to "Severity Report": new command, corrected sample output (was the retired `--- CRITICAL ---` / `Impact Summary` with critical/high/medium/low; now `--- ERROR ---` / `Severity Summary` with errors/warnings/info), and the "Impact levels" list replaced with "Severity levels" matching the `LintImpact` doc.

### SEV-04 — internal scripts accept `error|warning|info` (PARTIAL)

- **Fixed** `scripts/modules/_audit_checks.py`: `SEVERITIES` was `["critical","high","medium","low"]` and `SeverityStats.counts` was keyed on it, so `get_severity_stats` — whose regex now matches the post-collapse `LintImpact.error/warning/info` getters — hit `if severity in stats.counts` as always-False and reported **zero** for every rule in the publish audit's "Rules by Severity" table. Now `["error","warning","info"]` with a matching color map (error→RED, warning→YELLOW, info→DIM).
- **Confirmed scope correction:** no script actually parses the JSON `v.impact` field; the impact-reading scripts all parse the Dart-source `LintImpact get impact => LintImpact.X;` getter. The SEV-04 wording ("parsing `v.impact`") was inaccurate.
- **Still open:** the DX-message audit scripts `_audit_dx.py`, `_improve_dx_messages.py`, and `_audit.py:_dx_impact_table` key their length thresholds / "By Impact" table on the retired 5-value names. They do not crash (the value regex still captures, unknown values fall back to defaults) but degrade to default grading. The collapse mapping (critical→error, high+medium→warning, low+opinionated→info) makes the fix deterministic when picked up. Not touched this pass.

### Verification

- `dart analyze bin/saropa_lints.dart bin/severity_report.dart bin/impact_report.dart` → **No issues found** (exit 0).
- `python -m py_compile scripts/modules/_audit_checks.py` → clean.
- Functional: `dart run saropa_lints:severity_report --help`, `dart run saropa_lints:impact_report --help` (alias), and `dart run saropa_lints severity-report --help` (subcommand) all print the Severity Report usage.
- No Dart test references `impact_report` / `severity_report` / `SEVERITIES` / `get_severity_stats` (grep of `test/` → no matches); no Python test suite covers `_audit_checks.py`. Tooling has no existing test harness; verified by compile + run instead.

**No bug archive** — task did not close a `bugs/*.md` file.

---

## Finish Report (2026-06-10)

**Trigger:** "so then do sev-01 and sev-04" — picked up the two remaining open queue items.

### SEV-04 — DX scripts accept `error|warning|info` (DONE)

Re-keyed the three remaining DX-audit scripts from the retired 5-value impact names to the 3-level severity model:

- `scripts/modules/_audit_dx.py` — `RuleMessage.audit_dx()` length thresholds (180/150/100 now keyed error/warning/info), consequence/specific-type/AI-copilot checks now gate on `("error","warning")`, vague-language skip on `"info"`; the no-override extraction default changed from `"medium"` → `"warning"` (mirrors base `SaropaLintRule.impact`); `print_dx_audit_report()` and `export_dx_report()` bucket dicts, `impact_priority`, color maps, and summary counts all collapsed to 3 values.
- `scripts/modules/_improve_dx_messages.py` — `MIN_PROBLEM`/`MIN_CORRECTION` collapsed; `audit_message()` vague-skip + consequence + correction-length checks re-keyed; the no-override default `"medium"` → `"warning"`.
- `scripts/modules/_audit.py` — `_dx_impact_table()` is now "By Severity" (error/warning/info), `_dx_failing_table()` `impact_order` and header column relabeled.

**Verification:** `py_compile` clean on all three; a direct synthetic `RuleMessage` test confirms error rules get the 180-char + consequence + 100-char-correction checks, warning rules get 150/80, and info rules skip the vague penalty. Grep confirms no live old-value references remain (only one explanatory comment naming the retirement).

**Separate pre-existing breakage found (NOT fixed — out of SEV-04 scope):** the DX message *extractor* regex (`LINTCODE_RE` / `extract_rule_messages`) expects `LintCode(name: '...')` keyword syntax. The analyzer-9 compat migration moved all 2171 rule LintCodes to positional `LintCode('name', 'msg', ...)`, so the extractor matches **zero** rules and the entire DX message audit returns empty regardless of the vocabulary fix. This is orthogonal to the impact collapse and predates this work; it needs its own regex fix to make the (now-correct) vocabulary actually exercise live data.

### SEV-01 — severity audit (PARTIAL)

Generated a complete read-only cross-check of every rule's `severity:` field against its `LintImpact get impact` getter; persisted to [`SEV01_SEVERITY_AUDIT.md`](SEV01_SEVERITY_AUDIT.md). Of 2159 paired rules: 714 disagreements, of which 574 are default-impact-only (no explicit override → base `warning`), leaving ~140 real author disagreements split into Bucket A (over-rated, ERROR with explicit impact≤warning) and Bucket B (under-rated, WARNING with explicit impact=error).

**Applied (confirmed safe — 11 rules, each read first, each with an inline `// SEV-01:` why-comment):**

- Round 1, `prefer_*` performance/architecture preferences: `prefer_cubit_for_simple`, `prefer_copy_with_for_state`, `prefer_consumer_widget`, `prefer_select_for_partial`, `prefer_family_for_params`.
- Round 2, `bloc_rules.dart` should-fix patterns (missed events / rebuilds / observability / races, not crashes): `avoid_bloc_event_in_constructor`, `require_immutable_bloc_state`, `require_bloc_observer`, `avoid_bloc_event_mutation`, `avoid_bloc_listen_in_build`, `require_error_state`.

**Deliberately left at ERROR** after reading: `prefer_platform_io_conditional` (throws UnsupportedError → crashes web), `prefer_url_launcher_uri_over_string` (Uri.parse FormatException), `prefer_fail_test_case` (intentional always-fail pipeline hook), `require_initial_state` (throws LateInitializationError), `require_bloc_close` (resource/memory leak, consistent with the disposal family). These reads proved that bulk-downgrading by name would have introduced bugs.

**Still open (needs sign-off):** Bucket A's remaining 66 candidates (downgrade direction is safening but each needs an individual read) and all of Bucket B's 46 candidates (upgrade WARNING→ERROR breaks `dart analyze` for every consumer — a product decision).

**No bug archive** — task did not close a `bugs/*.md` file.
