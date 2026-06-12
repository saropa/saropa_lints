# Outstanding Items Audit — buried-and-unbuilt work across finish reports

**Created:** 2026-06-11
**Purpose:** A single backlog of concrete work that finish reports and plans described as needed but left unbuilt, unverified, or deferred — so items buried under "Outstanding / not yet verified", "Deferred", "Follow-up", and "Phase N" headings don't disappear once a session closes.

## Method

All 1,335 markdown files under [plans/history/](history/) (2026.01 → 2026.06) were swept for buried-work signals (outstanding / deferred / follow-up / phase-N / not-built / not-run / still-reads). Every candidate was then **cross-checked against current code** — the report claim alone was not trusted. That check moved the large majority of older (Jan–Mar) "outstanding" items into the **Shipped** column: they were built after the report was written.

## Verification legend

- **[OPEN — verified]** — confirmed still unbuilt by reading current code this audit.
- **[OPEN — needs per-item confirm]** — the headline feature shipped but specific sub-items were not individually code-verified; triage before building.
- **[BLOCKED]** — design done, gated on a decision.
- **[POLICY]** — intentional standing deferral (i18n MT cadence); listed for completeness, not as action.

Items carry **no time estimates** by project convention — they are characterized by scope and risk only.

---

## 1. Live diagnostics + consolidated dashboard (2026-06-11) — highest value

Source: [consolidated-dashboard.md](history/2026.06/2026.06.11/consolidated-dashboard.md), [findings-dashboard-live-diagnostics-sync.md](history/2026.06/2026.06.11/findings-dashboard-live-diagnostics-sync.md)

### 1.1 Consolidated webview never rendered — visual + interaction unverified **[OPEN — verified]**
The model is unit-tested and the view is wired to the live diagnostics listener, but the client is an **un-typechecked template string** ([consolidatedClient.ts](../extension/src/views/consolidated/consolidatedClient.ts)) and the dashboard has never been launched in the Extension Development Host. Every interaction (DOM-patch reconciler, lazy occurrence fetch, filter, keyboard nav) and the elevated stylesheet are unverified at runtime.
- **De-risk without a GUI:** add a headless DOM test that `eval`s `getConsolidatedClient()` into a jsdom/linkedom document and drives `model`/`occurrences` messages + click/keydown — catches the interaction bugs an `includes()` test cannot (see memory `reference_webview_template_literal_regex_trap`). Then a human F5 render + tuning round for pixels only.
- **Risk:** client logic correctness is currently asserted by code review alone.

### 1.2 Live-diagnostics migration of the high-value surfaces **[SHIPPED 2026-06-12]**
The status-bar score and the Issues sidebar tree now read live diagnostics via the
new `liveViolationsData.ts` helper (same source as the wide report + consolidated
dashboard), with a debounced `onDidChangeDiagnostics` listener keeping them current.
See [history record](history/2026.06/2026.06.12/live-diagnostics-status-bar-issues-tree.md).

**Still on the batch `violations.json` path (next surfaces to migrate):**
[codeLensProvider.ts](../extension/src/codeLensProvider.ts),
[issuesViewCommands.ts](../extension/src/commands/issuesViewCommands.ts),
[configSuggestions.ts](../extension/src/config/configSuggestions.ts), inline
annotations, the triage dashboard, and the rule-packs panel. The
`liveViolationsData` helper now centralizes the "prefer live" read, so these can
adopt it incrementally.

### 1.3 `pushModel` not try/catch-wrapped **[OPEN — verified]**
[consolidatedView.ts](../extension/src/views/consolidated/consolidatedView.ts) runs the debounced `pushModel()` inside a timer with no error boundary; a model-build throw would be unhandled. Minor defensive hardening.

### 1.4 18 `consolidated.*` keys English-only in 24 locales **[POLICY]**
Source keys are in `en.json`; translation runs on the i18n cadence (NLLB not run). The publish coverage gate (`generate_locales.py --fail-on-missing`) blocks release until filled. No action here beyond the standing cadence.

---

## 2. Migration rule packs (2026-06-11)

### 2.1 `<` gate archetype — RATIFIED, packs shipped **[SHIPPED]**
The pre-upgrade `<version` gate archetype was ratified and the gated packs shipped — verified in [lib/src/config/rule_packs.dart](../lib/src/config/rule_packs.dart) `kRulePackDependencyGates`: `local_auth_3` (`<3.0.0`), `google_sign_in_7` (`<7.0.0`), `connectivity_plus_6` (`<6.0.0`), `webview_flutter` (`<4.0.0`), `file_picker_10` / `file_picker_12`. The report headers that still read "blocked on `<` gate decision" are stale; their own finish reports record the ratification. **No decision outstanding.**

### 2.2 app_links migration pack — unbuilt (no longer blocked) **[OPEN — verified]**
Source: [plan_app_links.md](history/2026.06/2026.06.11/plan_app_links.md). The 3 always-on correctness rules shipped (`avoid_get_initial_link_string`, `listen_in_build`, `uncaught_stream_error`), but the 3 pre-upgrade migration rules (`get_initial_link` / `uri_link_stream` / `get_latest_link`, pack `app_links_6`) are **not present** in `tiers.dart` / `rule_packs.dart`. The gate archetype they waited on now exists, so this is unblocked — it just needs building like any other `<`-gated pack.

---

## 3. Project Health dashboard — parked deferrals (2026-05-25)

Source: [PROJECT_HEALTH_DASHBOARD_PLAN.md](history/2026.05/2026.05.25/PROJECT_HEALTH_DASHBOARD_PLAN.md); parked specs live in [plans/deferred/](deferred/). Core CLI + size map shipped.

- **3.1 Phase-4 render unverified [OPEN — verified]** — the `--format html` beautiful report and the async cancellable webview render in a browser but were never screenshot/runtime-verified against the design.
- **3.2 Isolate worker pool [OPEN — deferred]** — cold-scan CPU parallelism; intentionally not built (throughput-only; would destabilize the verified core for unmeasured gain).
- **3.3 Adaptive huge-workspace auto-defaults [OPEN — deferred]** — auto-aggregate above a file-count threshold; no real-user trigger yet.
- **3.4 SQLite store [OPEN — deferred]** — NDJSON shards shipped; SQLite deferred until full-set interactive arbitrary-filter querying is needed.

---

## 4. Rule metadata completeness (2026-04-28)

Source: [PLAN_RULE_METADATA_AND_QUALITY.md](history/2026.04/2026.04.28/PLAN_RULE_METADATA_AND_QUALITY.md), [RULE_METADATA_BULK_STATUS.md](history/2026.04/2026.04.28/RULE_METADATA_BULK_STATUS.md). The metadata schema, CWE/OWASP mapping, per-rule CI threshold gate ([bin/quality_gate.dart](../bin/quality_gate.dart)), and baseline comparison ([bin/baseline.dart](../bin/baseline.dart), [bin/diagnostic_baseline.dart](../bin/diagnostic_baseline.dart)) **all shipped**. Remaining gaps:

- **4.1 `accuracyTarget` null for every rule [OPEN — verified]** — getter exists, populated nowhere. Intentional until an audit/report consumes it; populate only if such a consumer is built.
- **4.2 `certIds` sparse/empty [OPEN — verified]** — by design; populate where a clear CERT/CWE mapping exists.
- **4.3 Rule-lifecycle enforcement [OPEN — needs per-item confirm]** — `RuleStatus` (ready/beta/deprecated) enum exists; confirm beta-gating + deprecated-exclusion is wired through init/profiles before treating as done.

---

## 5. Project / Package vibrancy — residual surfaces (2026-04-28)

Source: [project_vibrancy_report.md](history/2026.04/2026.04.28/project_vibrancy_report.md), [package_vibrancy_report_remediation_2026-04-28.md](history/2026.04/2026.04.28/package_vibrancy_report_remediation_2026-04-28.md).

**Most of these plans shipped** — the extension has tree-data, codelens, hover, code-action providers and `vibrancy-history.ts` (history/trends). The April finish report's "≈90% unbuilt" framing is stale. Verified-unbuilt residuals:

- **5.1 Flight-risk predictive scoring (Phase 5) [OPEN — verified]** — `grep` finds no `flightRisk` surface; research-gated in the plan.
- **5.2 Package network / dependency diagram [OPEN — verified]** — no `networkDiagram`/dependency-graph surface in vibrancy.
- **5.3 package_vibrancy remediation 14-item list [OPEN — needs per-item confirm]** — footprint-toggle correctness, UTC age accuracy, deterministic category/deps sort, deps-link back-nav, clickable `path:line`, age-filter slider, dev-deps toggle, grade-rationale tooltip. Several may have shipped inside the current vibrancy UI; triage each against code before building.
- **5.4 Cross-file semantic Usage collector [OPEN — needs per-item confirm]** — plan specifies analyzer element-resolution; confirm whether the shipped collector is still name-based before deciding to upgrade.

---

## 6. Supplementary dashboard counts (2026-05-13)

Source: [DASHBOARD_SUPPLEMENTARY_COUNTS.md](history/2026.05/2026.05.13/DASHBOARD_SUPPLEMENTARY_COUNTS.md). Surface non-Saropa analyzer findings + analyzer TODOs alongside the Saropa count. The TODO/HACK workspace-scan half shipped ([todosAndHacksTree.ts](../extension/src/views/todosAndHacksTree.ts)); the `showAnalyzerLints` dashboard pills were not found in code. **[OPEN — needs per-item confirm]** — confirm the analyzer-lints pill + toggle, build if absent.

---

## 7. Audited and confirmed SHIPPED (no action — recorded so the audit is trustworthy)

These were prominent "outstanding" entries in older reports; current code shows them built. Listed so they are not re-surfaced.

| Reported as outstanding | Source month | Verified state |
|---|---|---|
| Native analyzer-plugin migration (custom_lint → analysis_server_plugin) | 2026.01–03 | Shipped — pubspec on `analysis_server_plugin ^0.3.4` |
| 213 quick-fix migration / "quick fixes not appearing in VS Code" | 2026.02–03 | Shipped — 221+ fixes on the native plugin |
| FILE_SPLIT_PLAN + file_structure reorg (packages/ + platforms/) | 2026.02 | Shipped — 52 `packages/`, 9 `platforms/` rule files |
| tier_assignment_reliability (remove per-rule tier getter) | 2026.01 | Shipped — no `RuleTier get tier` in rule classes |
| drift_support_plan (21 proposed rules) | 2026.02 | Shipped/exceeded — ~33 `*_drift_*` rules in tiers |
| INIT_REDESIGN modularization of bin/init.dart | 2026.03 | Shipped — `bin/init.dart` now a 14-line wrapper |
| Per-rule CI threshold gates + baseline "new violations only" | 2026.04 | Shipped — `bin/quality_gate.dart` + `bin/baseline.dart` |
| Vibrancy tree / codelens / hover / code-action / history surfaces | 2026.04 | Shipped — providers present under `extension/src/vibrancy/` |
| rule_versioning_plan, log_capture_integration, test_coverage_improvement | 2026.02 | Marked done in-report; consistent with current code |

> Not individually re-verified (low value, likely superseded by the shipped extension): the residual polish items in [VSCODE_EXTENSION_COHESION_WOW_PLAN.md](history/2026.03/20260314/VSCODE_EXTENSION_COHESION_WOW_PLAN.md) Phase D (onboarding sequence, celebration-on-drop messages, focus mode) and the [UNIT_TEST_COVERAGE.md](history/2026.03/20260302/UNIT_TEST_COVERAGE.md) `_rule_metrics.py` code_quality category metric fix. Confirm before building if revisited.

---

## Recommended order

1. **1.2** — migrate Issues sidebar tree + status-bar score to live diagnostics (biggest displayed-vs-reality win, pure code).
2. **1.1** — headless eval-test for the consolidated client, then a human render + tuning pass.
3. **2.2** — app_links migration pack (3 rules; gate archetype already exists, `file_picker_*` is the exemplar).
4. **1.3** — `pushModel` try/catch (trivial, fold into the next dashboard touch).
5. Triage clusters **5.3 / 5.4 / 6 / 4.3** against code before committing to build — "confirm, then maybe build", not confirmed work.
6. Genuine deferral choices (no code blocker): **§3** project-health deferrals (isolate pool / adaptive defaults / SQLite) and **§4.1–4.2** `accuracyTarget` / `certIds` population — build only if a consumer justifies it.

> **No item remains blocked on a maintainer decision.** The single decision gate the reports pointed to (the `<` gate archetype) is ratified in code.
