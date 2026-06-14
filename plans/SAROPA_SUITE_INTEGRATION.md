# Saropa Suite Integration — Lints side

**Created:** 2026-06-13
**Question answered:** How does `saropa_lints` link with its two sibling tools so static findings,
live database state, and runtime behavior become one correlated picture — without any of the three
products subsuming another.

This is the **Saropa Lints** half of a three-repo plan. The sibling docs:

- **Drift Advisor** — `D:\src\saropa_drift_advisor\plans\67-saropa-suite-integration.md`
  (repo `saropa/saropa_drift_advisor`). **Owns the canonical shared protocol** (the Saropa Diagnostic
  Envelope); this doc references it rather than restating the schema.
- **Log Capture** — `D:\src\saropa-log-capture\plans\105_plan-saropa-suite-integration.md`
  (repo `saropa/saropa-log-capture`).
- **Saropa Dart Utils** — `D:\src\saropa_dart_utils\plans\SAROPA_SUITE_INTEGRATION.md`
  (repo `saropa/saropa_dart_utils`). The remediation layer, not a fourth lens: it ships the safe
  primitives R3's "enable rule X" prompt steers toward, and owns the rule-id ↔ util-symbol mapping.

---

## The thesis: three lenses on one app

| Tool | Sees | When | Emits |
|------|------|------|-------|
| `saropa_lints` (this) | Static **code** (AST) | Compile-time | findings |
| `saropa_drift_advisor` | Live **DB data + schema** | Debug runtime | issues |
| `saropa-log-capture` | **Behavior / telemetry** (logs, crashes) | Debug + production | signals |

Lints catches the bug *class* before it runs; the siblings confirm it in the running database and in
production telemetry. The whole value of integration is closing that loop: a crash Log Capture sees
in the wild → the Lints rule that would have prevented it; a missing index Advisor finds at runtime →
the static rule that governs it. The boundary is firm — Lints stays the only tool that reads source
(AST); it never inspects live data or logs. (Drift Advisor's README codifies this: complementary,
never subsumed.)

Today's only wiring is one-way: Advisor exposes `GET /api/issues` and Log Capture's SQL Query History
already runs "Saropa Lints checks." This plan makes Lints a first-class **producer and consumer** of
the shared envelope.

---

## Shared protocol (canonical: Drift Advisor doc, Section 2)

Lints conforms to the **Saropa Diagnostic Envelope** defined canonically in the Drift Advisor plan,
Section 2. Lints does not redefine it. The fields Lints is responsible for:

- `source: "lints"`, `severity: "error" | "warning" | "info"` — Lints already standardized on this
  exact triple (see `COLLAPSE_LINT_IMPACT_TO_SEVERITY.md`), so the suite adopts the Lints model.
- `ruleId` — the lint rule name (e.g. `avoid_drift_update_without_where`).
- `category` — map the rule's domain (`drift`, `security`, `performance`, `a11y`, …).
- `location.file` — workspace-relative; never an absolute home path.
- `fix` — when the rule has a quick fix, `kind: "quickFix"`; otherwise a `command` deep-link
  (Section "Deep-linking" below).
- `docUri` — the rule's documentation / Rule Explain entry.

---

## Lints requirements (what this package builds)

- **R1 — Export findings as the envelope.** The VS Code extension already reads *live* analyzer
  findings for its dashboards (Findings Dashboard, status bar, code-lens). Add an exporter that writes
  the current findings to `<workspace>/.saropa/diagnostics/lints.json` (envelope, `source: "lints"`)
  on analysis settle. This is the offline mirror the siblings read when the analyzer isn't the active
  tool. The metadata Lints already bundles (per-rule type, lifecycle status, security flag) fills
  `category` and `docUri`.
- **R2 — Consume sibling envelopes.** Read `.saropa/diagnostics/advisor.json` and
  `.saropa/diagnostics/log-capture.json`. Surface the relevant ones in Lints' holistic dashboard
  (which already merges built-in Dart lints + other `custom_lint` plugins — extend it to a third
  source class: "runtime evidence from the suite"). A Drift rule row gains a badge: "Advisor confirms
  this at runtime" or "Log Capture saw N occurrences."
- **R3 — Crash-to-rule attribution (consumes Log Capture).** Map crash classes Log Capture parses
  (StateError from `.first` on empty, RangeError on `[index]`, the Crashlytics issue families) back to
  the Lints rule that prevents that class — `geocoding_unchecked_first`,
  `image_picker_multi_result_unchecked_empty`, `avoid_unawaited_future`, etc. Ship a mapping table
  (rule id ↔ crash signature) and a code action: "This crash class is covered by rule `X`, currently
  disabled — enable it." This turns production telemetry into a static-analysis feedback loop and is a
  genuinely novel selling point. The mapping is data, colocated with rule metadata so tests pin it.
- **R4 — Deep-link command ids (public API).** Contribute and never rename:
  `saropaLints.explainRule { ruleId }` (open Rule Explain), `saropaLints.enableRule { ruleId }`
  (add to `analysis_options.yaml` overrides), `saropaLints.openFinding { id }`. A sibling envelope's
  `fix.command` targeting Lints must use one of these.
- **R5 — Reciprocal deep-links out.** A Lints Drift-rule finding offers
  `driftViewer.openExplainForSql` / `driftViewer.goToDefinitionForTable` (Advisor command ids) and
  `saropaLogCapture.openSqlHistoryForFingerprint` (Log Capture) as secondary actions when those
  extensions are installed, so a static finding jumps straight to live confirmation.
- **R6 — Commit stamp.** Stamp exported findings with the current `commitSha` for the cross-commit
  correlation in the Drift Advisor doc, Section 6.

---

## The Drift Health loop (flagship — Lints' part)

Defined in full in the Drift Advisor doc, Section 5. Lints owns leg 3: confirming whether a slow query
or bad write that Log Capture/Advisor observed is already covered by one of the 32 static Drift rules
in `lib/src/rules/packages/drift_rules.dart`, and offering the quick fix. If the pattern is observed
at runtime but no static rule covers it, that is a **new-rule signal** — a backlog input for the rule
authors, surfaced in the dashboard as "observed in production, no static rule yet."

---

## Cross-discovery / Package Vibrancy tie-in

- **R7 — Suite awareness in Package Vibrancy.** Lints already scans `pubspec` dependencies and has
  `siblingRepoPaths` for cross-project version drift. When it sees `saropa_drift_advisor` in a
  project's `dev_dependencies` (the recommended pairing — Drift Advisor's own pubspec dev-depends on
  `saropa_lints`), nudge once: "This project uses Drift Advisor; install the Log Capture extension to
  correlate runtime SQL with these static findings." Gate with the existing offered/dismissed pattern
  so it never nags.

---

## Shared infrastructure (cross-repo — identical Section in all three docs)

Duplicated across the three TypeScript extensions; extract to internal shared packages (path/git
deps, not a monorepo merge):

- **`saropa-vscode-i18n`** — NLLB-then-Google fallback, real-coverage audits, day-bucketed report
  paths, untranslated-locale notices. Lints is furthest along (24 languages) and the natural source
  of the extracted tooling. (Sharing tooling only; running a translation job stays separately
  authorized.)
- **`saropa-vscode-ui`** — theme tokens + dashboard kit. Lints already decomposed its dashboards into
  reusable section builders (`CENTRAL_DASHBOARD_CONSOLIDATION.md`); those become the seed of the
  shared kit.
- **`saropa-release-tools`** (Python) — `publish.py` orchestrator, dependency-import gate,
  American-English write-time gate, changelog conventions. All three already converged on these.

---

## Phasing

1. ✅ **R1 + R4** — export the envelope and contribute the command ids. Protocol foundation.
   Landed in `extension/src/suite/`: `envelope.ts` (envelope types + builder + writer, unit-tested in
   `test/suiteEnvelope.test.ts`), `exporter.ts` (writes `.saropa/diagnostics/lints.json` on the
   analysis-settle tick), and `commands.ts` (`saropaLints.enableRule` / `saropaLints.openFinding`
   deep-link commands; `explainRule` extended to accept the `{ ruleId }` object form). Phases below pending.
2. ✅ **R2** — render sibling evidence in the holistic dashboard.
   Landed: `suite/siblingEnvelopes.ts` reads `.saropa/diagnostics/advisor.json` + `log-capture.json`
   and correlates each sibling diagnostic back to the Lints rule it deep-links (`fix.command` =
   `saropaLints.explainRule` / `enableRule` / `openFinding` with a `{ ruleId }` arg). The consolidated
   dashboard (`views/consolidated/`) badges a rule row "Advisor confirms at runtime" / "Log Capture saw
   N" from that evidence; unit-tested in `test/suiteSiblingEnvelopes.test.ts`.
3. **R3** — crash-to-rule attribution (the novel feature).
4. **R5 + R7** — outbound deep-links and Package Vibrancy nudge.
5. **R6** — commit stamping for correlation.
6. **Shared infra extraction** — see the shared Section above.

---

## Related plans

- Sibling: `saropa_drift_advisor` — `D:\src\saropa_drift_advisor\plans\67-saropa-suite-integration.md`
  (canonical protocol + Drift Health loop)
- Sibling: `saropa-log-capture` — `D:\src\saropa-log-capture\plans\105_plan-saropa-suite-integration.md`
- Sibling: `saropa_dart_utils` — `D:\src\saropa_dart_utils\plans\SAROPA_SUITE_INTEGRATION.md`
  (its R1 rule-id ↔ util-symbol mapping is the direct counterpart to this doc's R3 crash-to-rule table;
  joined on `ruleId`)
- Internal: `CENTRAL_DASHBOARD_CONSOLIDATION.md` (the holistic dashboard that R2 extends),
  `COLLAPSE_LINT_IMPACT_TO_SEVERITY.md` (the error/warning/info model the envelope adopts),
  `TODO_rule_metadata_completeness.md` (the metadata that fills `category`/`docUri`).
