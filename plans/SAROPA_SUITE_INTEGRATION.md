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

## Shared infrastructure (cross-repo) — WON'T DO (rejected 2026-06-14)

**Decision: not extracting shared packages.** The idea was to pull the code duplicated across the
three TypeScript extensions into internal shared packages — `saropa-vscode-i18n`, `saropa-vscode-ui`,
and `saropa-release-tools`. Rejected as over-engineering: three (or even one-repo-three-dir)
publishable units for three in-house consumers cost more in versioning, pinning surface (up to nine
submodule links), lockstep releases, and an untested-shared-toolkit maintenance burden than the
duplication they remove — with **zero user-facing benefit**. Matches drift_advisor's Plan 67 §7, which
rejected the same architecture the same day, and an independent review that flagged the submodule
consumption-surface and the missing shared-package test story as the unaddressed costs.

The duplication is real but accepted as a known trade-off. If a shared bug recurs and the pain
justifies action, the lighter moves — a single internal shared module via a path dep, or a
vendoring/sync script, scoped to the specific shared code that hurt — are preferred over new
published units; revisit then.

The three detailed extraction plans are retained as the record of what was considered, archived to
`plans/history/2026.06/2026.06.14/`:
- `SHARED_INFRA_VSCODE_I18N.md` — i18n runtime + NLLB/Google translation tooling.
- `SHARED_INFRA_VSCODE_UI.md` — theme tokens + dashboard kit.
- `SHARED_INFRA_RELEASE_TOOLS.md` — `publish.py` orchestrator + release gates.

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
5. ✅ **R6** — commit stamping for correlation.
   Landed: `suite/commitSha.ts` resolves the current SHA by reading `.git` directly (HEAD → branch ref →
   loose or packed SHA, plus detached-HEAD and linked-worktree commondir handling; no git process
   spawned on the settle tick). `exporter.ts` stamps it onto every diagnostic via the envelope builder's
   `commitSha` field; omitted outside a git checkout. Unit-tested in `test/suiteCommitSha.test.ts`.
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

---

## Complete Status Report (updated 2026-06-14)

Consolidated state of the whole suite integration — requirements, file inventory, the rejected
shared-infrastructure extraction, the external review of that extraction (with verification against
the repo), cross-repo state, commits, and open decisions. Written because several parallel sessions
edited these repos at once; this section is the single source of truth for the end state.

### TL;DR

- Per-requirement integration work **R1–R7 is DONE and committed** in saropa_lints.
- The shared-infrastructure extraction (3 proposed packages) was **REJECTED — WON'T DO**. Its 3 plan
  docs are archived; the sibling bug copies were moved to each sibling's `plans/history`.
- A later **external review** of a consolidated shared-infra doc surfaced 2 real factual errors + 3
  substantive gaps + a stronger alternative. The reviewed consolidated doc itself is **not on disk**
  in any of the 4 repos — but parts of the review map to real archived files (verified below).

### 1. The integration

Three sibling tools, three lenses on the same Flutter/Drift app, correlated without merging:

| Tool | Sees | When | Emits |
|------|------|------|-------|
| `saropa_lints` (this repo) | Static code (AST) | Compile-time | findings |
| `saropa_drift_advisor` | Live DB data + schema | Debug runtime | issues |
| `saropa-log-capture` | Behavior/telemetry (logs, crashes) | Debug + prod | signals |
| `saropa_dart_utils` | Remediation layer (not a 4th lens) | — | safe primitives |

Shared contract = the **Saropa Diagnostic Envelope** (canonical schema owned by Drift Advisor's Plan
67 §2). Tools write/read offline mirrors at `<workspace>/.saropa/diagnostics/<source>.json`.

### 2. Requirements — all DONE

| Req | What it does | Status | Key files (extension/src/) |
|-----|--------------|--------|----------------------------|
| R1 | Export findings as envelope to `.saropa/diagnostics/lints.json` on analysis settle | ✅ | suite/envelope.ts, suite/exporter.ts |
| R2 | Consume sibling mirrors; badge rows "Advisor confirms" / "Log Capture saw N" | ✅ | suite/siblingEnvelopes.ts, views/consolidated/* |
| R3 | Crash-to-rule attribution; prompt to enable the rule a crash would've prevented | ✅ | suite/crashToRule.ts, suite/crashCoverageNudge.ts |
| R4 | Public deep-link command ids: explainRule / enableRule / openFinding | ✅ | suite/commands.ts, extension.ts |
| R5 | Reciprocal deep-link OUT: Drift finding → "Show live Drift issues (Drift Advisor)" | ✅ | suite/siblingDeepLinkTargets.ts, suite/siblingDeepLinks.ts |
| R6 | Stamp each exported diagnostic with the current commit SHA | ✅ | suite/commitSha.ts (+ exporter.ts) |
| R7 | Once-gated nudge: project uses Drift Advisor → suggest installing Log Capture | ✅ | suite/suiteAwarenessGate.ts, suite/suiteAwarenessNudge.ts |

i18n keys present under `suite.*` (fix, enableRule, openFinding, crashNudge, deepLink, nudge) and
`consolidated.evidence.*` in `extension/src/i18n/locales/en.json`.

### 3. Source + test inventory (`extension/src/suite/`)

Source (11): commands.ts, commitSha.ts, crashCoverageNudge.ts, crashToRule.ts, envelope.ts,
exporter.ts, siblingDeepLinkTargets.ts, siblingDeepLinks.ts, siblingEnvelopes.ts, suiteAwarenessGate.ts,
suiteAwarenessNudge.ts

Tests (5, all in the npm test glob): suiteEnvelope, suiteSiblingEnvelopes, suiteCrashToRule,
suiteDeepLinks, suiteCommitSha → ~50 cases passing. `tsc --noEmit` clean for suite files. (One
UNRELATED tsc error in `rulePacks/rulePacksWebviewProvider.ts` is a different workstream's WIP — not
suite code.)

### 4. Shared-infrastructure extraction — REJECTED (WON'T DO)

Proposed: pull duplicated code from the 3 TS extensions into shared packages `saropa-vscode-i18n`,
`saropa-vscode-ui`, `saropa-release-tools`. Rejected as over-engineering: 3 publishable units for 3
in-house consumers cost more (versioning, up to 9 submodule links, lockstep releases, untested
shared-toolkit burden) than the duplication they remove — zero user-facing benefit. Matches
drift_advisor's Plan 67 §7 (same rejection, same day) + an independent review.

Disposition:
- 3 extraction plans ARCHIVED at `plans/history/2026.06/2026.06.14/SHARED_INFRA_{VSCODE_I18N,VSCODE_UI,RELEASE_TOOLS}.md`.
- 6 task copies in siblings' `bugs/` were MOVED to each sibling's
  `plans/history/2026.06/2026.06.14/shared_infra_*_extraction.md`.
- Fallback if a shared bug recurs: a single path-dep module or vendoring/sync script scoped to the
  code that hurt — NOT new published units.

### 5. External review of the shared-infra plan — findings + verification

**Factual errors**
- `generate_translations.py` path is WRONG — listed under `extension/scripts/i18n/{…}`. CONFIRMED
  wrong; the file is at `extension/scripts/generate_translations.py` (one level up). Present at
  `plans/history/2026.06/2026.06.14/SHARED_INFRA_VSCODE_I18N.md:37`. Real, fixable.
- Sibling-notes path is stale — a consolidated doc reportedly says it supersedes
  `saropa_drift_advisor/bugs/shared_infra_*.md`. CONFIRMED those are not in `bugs/` — they are
  archived at `saropa_drift_advisor/plans/history/2026.06/2026.06.14/shared_infra_*_extraction.md`.

**Substantive gaps (all valid)**
1. Submodule decision dismisses its own biggest cost — 3 pkgs × 3 consumers = 9 pinned submodule
   links (detached HEAD, `--recursive` footguns, CI checkout, forgotten bumps). Never engages the
   lighter alternative: ONE repo, 3 top-level dirs = ONE submodule per consumer (3 links). Build-step
   1 also mixes "git mv/subtree for seeding" with "submodule for consuming" — two different ops that
   read as a contradiction; spell them out.
2. No story for testing a shared change against all 3 consumers. Pinned SHAs make a bugfix a 3-repo
   bump, framed as a feature — but nothing says how you know a publish-guard fix doesn't break Drift
   Advisor before merge. No CI integration; no shared-package test suites. A shared toolkit with no
   tests of its own regresses the moment it leaves Lints. The least-specified, real maintenance cost.
3. Divergence discovered too late. Forks are only diffed against the shared version at the consume
   step, after the package is shaped by whatever Lints did. Mitigation should be proactive: diff all 3
   forks UP FRONT to define the true shared surface before extraction.

**Minor** — A consolidation that supersedes `plans/SHARED_INFRA_*.md` belongs in `plans/`, not
`bugs/`. NOTE: the consolidated doc the review describes is NOT on disk in any of the 4 repos
(searched); only the 3 per-package plans exist, archived. So this item can't be applied to an absent
file.

**Accurate / well-captured (no action)** — NLLB ABI single-interpreter risk; snapshot-test coupling;
theme-token regression checks; the envelope rule (ship the loader, never the strings); the non-goals.

**Reviewer's recommendation (strong, endorsed)** — One shared repo, three top-level directories,
consumed as a single submodule per consumer. Same code cohesion (3 dirs stay separate), one-third the
pinning surface, one CI to test all three layers together. Directly answers the costs that got the
3-package version rejected.

### 6. Cross-repo state

- saropa_lints: `plans/SAROPA_SUITE_INTEGRATION.md` active (shared-infra section = WON'T DO).
- saropa_drift_advisor: `plans/67-saropa-suite-integration.md` (canonical envelope owner; §7 also rejects extraction).
- saropa-log-capture: `plans/105_plan-saropa-suite-integration.md`.
- saropa_dart_utils: `plans/SAROPA_SUITE_INTEGRATION.md` (remediation layer; rule-id ↔ util-symbol map).
- No live shared-infra artifacts in any sibling `bugs/` — all archived to `plans/history/2026.06.14`.

### 7. Relevant commits (saropa_lints, newest first)

- `5d1d3f54` docs(bugs): dart_utils version-nudge feature request; archive the 3 shared-infra plans
- `777da857` docs(plans): the 3 shared-infra extraction plans (later archived)
- `1044a8be` feat(suite): R6 — stamp diagnostics with commit SHA
- `717fb710` feat(suite): R5 + R7 — reciprocal deep-links out + pairing nudge
- `7be84584` feat(suite): R2 — dashboard runtime-evidence badges
- `ad5225e5` feat(suite): R3 — crash-to-rule attribution
- `4e2aa305` (R1 + R4 envelope/exporter/commands landed here, entangled with a rule-packs commit)

### 8. Open items / decisions

1. **CONTRADICTION TO RESOLVE.** The decision says extraction is WON'T DO; the review treats it as
   live. Pick one:
   - (a) Stays WON'T DO → only fix the `generate_translations.py` path in the archived i18n doc
     (record accuracy); the review's 3 gaps are moot.
   - (b) Reopened → create one consolidated `plans/SHARED_INFRA_EXTRACTION.md` incorporating the full
     review (both path fixes, the 3 gaps engaged, the one-repo-three-dirs alternative as the
     recommended mechanism), superseding the 3 archived plans.
2. The reviewed consolidated doc is not on disk — if a draft exists, it must be saved somewhere
   readable before its line-13/line-100 can be edited in place.
3. Translated locale catalogs are STALE for the new suite keys (`suite.*`, `consolidated.evidence.*`).
   Regen runs the NLLB pipeline — NOT run (authorization-gated). The publish coverage gate blocks a
   release until regenerated. Command when authorized: `py -3 extension\scripts\generate_translations.py`.
4. Device verification pending — suite features verified by unit tests + type-check, not in a running
   VS Code host (envelope file written, badges render, deep-link lightbulb, nudge toast).
