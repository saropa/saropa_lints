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
3. ✅ **R3** — crash-to-rule attribution (the novel feature).
   Landed: `suite/crashToRule.ts` holds the frozen crash-family signature set (mirrored from Log
   Capture's `crash-signature.ts`) and the signature → preventing-rule(s) map, with a tolerant reader
   for `.saropa/diagnostics/log-capture.json` (`category === "crash"`, `crash:` prefix stripped).
   `suite/crashCoverageNudge.ts` surfaces a once-per-rule "enable rule X" toast (gated in `globalState`)
   when an observed crash family's mapped rule is disabled, firing on activation and on the crash
   mirror changing. Unit-tested in `test/suiteCrashToRule.test.ts`, which pins the signature set and
   cross-checks every mapped rule id against the bundled rule catalog.
4. ✅ **R5 + R7** — outbound deep-links and Package Vibrancy nudge.
   Landed: `suite/siblingDeepLinkTargets.ts` (pure) decides the reciprocal jumps and
   `suite/siblingDeepLinks.ts` registers a Dart code-action provider that surfaces "Show live Drift
   issues (Drift Advisor)" on a Drift finding when `saropa.drift-viewer` is installed —
   `driftViewer.openIssues {category:"drift"}`, the only sibling command callable correctly without a
   table/SQL/fingerprint a static finding does not carry. `suite/suiteAwarenessNudge.ts` (gate in
   `suiteAwarenessGate.ts`) shows a once-per-workspace toast suggesting the Log Capture extension when a
   project dev-depends on `saropa_drift_advisor` but lacks it. Unit-tested in `test/suiteDeepLinks.test.ts`.
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

---

## Finish Report (2026-06-14)

Covers the protocol-foundation and dashboard-consumer phases (R1, R2, R4) of this plan. R3
(crash-to-rule attribution) shipped separately in commit `ad5225e5` and is not part of this report;
R5, R6, R7, and the shared-infra extraction remain open, so this plan stays active.

**Scope.** (B) VS Code extension TypeScript only — `extension/src/suite/`,
`extension/src/views/consolidated/`, `extension/src/extension.ts`, the extension manifest, and the
extension i18n catalog. No Dart rules, analyzer plugin, tiers, or `example/` fixtures were touched.

**What shipped.**
- R1 (export the envelope): `suite/envelope.ts` defines the Saropa Diagnostic Envelope producer
  (types matching the canonical Drift Advisor schema §2.1/2.2, `deriveCategory`, finding-id
  build/parse, `buildLintsEnvelope`, `writeLintsEnvelope`) with no `vscode` dependency so it is unit
  testable. `suite/exporter.ts` is the impure glue that reads live diagnostics and resolves the
  localized fix label. `extension.ts` calls it on the existing debounced analysis-settle tick, writing
  `<workspace>/.saropa/diagnostics/lints.json`; a write failure is caught and logged so linting is
  never disrupted.
- R4 (deep-link command ids): `suite/commands.ts` registers `saropaLints.enableRule` (writes a rule
  override via `writeRuleOverrides` + cache invalidation, then offers a one-tap re-analysis) and
  `saropaLints.openFinding` (round-trips a finding id back to its source line). `explainRule` was
  extended to accept the documented `{ ruleId }` object form. All three ids are contributed in the
  manifest, hidden from the command palette (they take args).
- R2 (consume sibling evidence): `suite/siblingEnvelopes.ts` reads the two sibling mirrors and counts
  only the explicit cross-references — a sibling diagnostic whose `fix.command` is a Lints deep-link id
  carrying a `{ ruleId }` arg — bucketed by source. The consolidated dashboard
  (`views/consolidated/`) badges a rule row "Advisor confirms at runtime" / "Log Capture saw N" from
  that map; the badge strings are localized host-side and rendered as quiet, theme-token-driven pills.

**Verification.** `tsc --noEmit` over the whole extension is clean for the suite and consolidated
files. The suite + consolidated unit tests pass (`suiteEnvelope`, `suiteSiblingEnvelopes`,
`consolidatedClient`, `consolidatedModel`). The R3 test (`suiteCrashToRule`) was already written but
absent from the `npm test` glob; it is now registered so it runs in CI.

**Known follow-up.** New `en.json` keys (`suite.*`, `consolidated.evidence.*`) leave the 23 translated
locale catalogs stale. Regenerating them runs the machine-translation pipeline, which is gated behind
its own separate authorization and was not run here; the publish coverage gate
(`generate_locales.py --fail-on-missing`) blocks a release until they are regenerated.

A pre-existing `tsc` error in `rulePacks/rulePacksWebviewProvider.ts` (`_handleStylisticBulk` missing)
belongs to a separate in-progress workstream and is unrelated to the suite integration.
