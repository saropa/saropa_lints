# INFRA: Saropa suite integration — contract Saropa Lints must satisfy (Log Capture side has shipped)

**Status: Fixed**

Created: 2026-06-13
Type: Infrastructure / cross-tool integration
Related plan (this repo): `plans/SAROPA_SUITE_INTEGRATION.md`
Sibling plan (Log Capture): `D:\src\saropa-log-capture\plans\105_plan-saropa-suite-integration.md`
Canonical protocol: `D:\src\saropa_drift_advisor\plans\67-saropa-suite-integration.md` Section 2

---

## Why this file exists

The **Saropa Log Capture** side of the three-tool suite integration is now implemented and
committed (saropa-log-capture commits `d5c87e4e`, `49fa4fb1`, `c1e9bfa6`). Log Capture now both
produces and consumes the **Saropa Diagnostic Envelope** and exposes deep-link buttons that target
**Saropa Lints** commands.

Those buttons and the crash-to-rule loop are **gated on Lints actually implementing its half** — a
"Show this rule in Saropa Lints" button only appears when the `saropaLints.explainRule` command is
registered (Log Capture probes the live command list, so it never shows a dead action). This file is
the precise, self-contained contract so the Lints work matches what Log Capture already ships. No code
change is requested in Log Capture; this is the Lints task list.

This is a hand-off **spec**, not a rule bug — filed under `bugs/` per the guide's `infra_*` convention.

---

## What Lints must build (3 pieces)

### 1. Contribute two stable VS Code commands (public deep-link surface)

| Command id | Args | Opens |
|------------|------|-------|
| `saropaLints.explainRule` | `{ ruleId: string }` | The rule's explanation / docs |
| `saropaLints.enableRule` | `{ ruleId: string }` | Enable that rule (and surface how) |

- These ids are the canonical surface (Drift Advisor doc Section 3). **Never rename them** — Log
  Capture and Drift Advisor hard-code them as deep-link targets.
- Log Capture invokes `saropaLints.explainRule` with a **single object arg** `{ ruleId }`. (Its
  executor passes a lone object straight through and spreads an array, so accept the options object as
  the first positional arg: `(opts: { ruleId: string }) => …`.)
- Until these are registered, Log Capture's "Show this rule" button and any envelope `fix.command`
  pointing at them stay hidden — by design, not a bug.

### 2. Write the offline mirror `<workspace>/.saropa/diagnostics/lints.json`

Write the **Saropa Diagnostic Envelope** (schema below) on each analysis so Log Capture (and Drift
Advisor) can read Lints findings without the analyzer running. Log Capture reads this file as the
**fallback** source for its SQL Query History "Static code issues (Saropa Lints)" section and renders
each diagnostic as a typed row (source tag, severity color, fix button).

For the SQL panel specifically, Log Capture keeps only the DB-relevant categories from your envelope:
`drift`, `schema`, `data`, `performance`. Emit your Drift-rule findings in those categories (most are
`drift`). Other categories are still valid in the envelope; they just aren't shown in that panel.

Field mapping for a Lints diagnostic:
- `source: "lints"`
- `severity`: one of `error | warning | info` (the suite triple Lints already standardizes on).
- `category`: `drift` for the Drift rule pack; `schema`/`data` where apt.
- `ruleId`: the lint rule name (e.g. `require_database_index`). This is what
  `saropaLints.explainRule` receives.
- `title`: already-localized one-line message.
- `location.file`: **workspace-relative** (never an absolute home path — Section 2.4).
- `fix` (optional): `{ kind: "command", title, command: "saropaLints.explainRule", args: [{ ruleId }] }`
  is a natural primary action. Note `fix.args` is a **spread array** (VS Code `executeCommand(id,
  ...args)` semantics), so wrap the options object: `args: [{ ruleId }]`.

### 3. Crash-to-rule mapping (R3 consumer half — the flagship loop)

Log Capture parses runtime crash families and now emits, in
`<workspace>/.saropa/diagnostics/log-capture.json`, a `crash`-category diagnostic whose `ruleId`
carries a **stable crash-family signature**, prefixed `crash:`. Lints owns the mapping from signature
to the rule that would have prevented it, and the "enable rule X" prompt.

**The complete, frozen signature set Log Capture emits** (source of truth:
`saropa-log-capture/src/modules/diagnostics/crash-signature.ts`):

| `ruleId` on the Log Capture diagnostic | Crash family (runtime text it matched) |
|----------------------------------------|----------------------------------------|
| `crash:state-error-no-element` | `Bad state: No element` — `.first`/`.last`/`.single` on an empty iterable |
| `crash:range-error-index` | `RangeError (index)` — `list[i]` past the end / negative |
| `crash:null-check-operator` | `Null check operator used on a null value` — the `!` bang on null |
| `crash:late-init` | `LateInitializationError` — a `late` field read before assignment |
| `crash:concurrent-modification` | `Concurrent modification during iteration` |
| `crash:type-error-cast` | `type 'X' is not a subtype of type 'Y'` — failed cast |
| `crash:format-exception` | `FormatException` — parsing malformed input |
| `crash:no-such-method` | `NoSuchMethodError` — method/getter on null or wrong type |
| `crash:assertion-failed` | `Failed assertion` — an `assert(...)` tripped |
| `crash:stack-overflow` | `Stack Overflow` — unbounded recursion |
| `crash:out-of-memory` | `OutOfMemoryError` / heap exhaustion |
| `crash:anr` | Application Not Responding — main-thread block |

Lints work:
1. Read `.saropa/diagnostics/log-capture.json`, take diagnostics with `category === "crash"`, strip the
   `crash:` prefix off `ruleId` to get the signature id.
2. Map each signature → the preventing Lints rule(s). Suggested starting map (adjust to the actual rule
   inventory in `lib/src/rules/`):
   - `state-error-no-element` → the rule(s) preferring `firstOrNull`/length-guards over `.first`.
   - `range-error-index` → unsafe-index / bounds rules.
   - `null-check-operator` → avoid-null-assertion (`!`) rules.
   - `late-init` → unassigned-`late`-field rules.
   - `concurrent-modification` → mutate-during-iteration rules.
   - `type-error-cast` → unsafe-cast (`as`) rules.
   - others → nearest applicable rule, or no-op if none exists yet.
3. When a mapped rule is currently disabled, surface an **"enable rule X"** prompt (this is where
   `saropaLints.enableRule { ruleId }` is the action).

Log Capture owns the **signature**; Lints owns the **mapping**. Do not ask Log Capture to change the
signature ids — they are a frozen contract (renaming one silently breaks this mapping).

---

## The Saropa Diagnostic Envelope (schema you must write — schemaVersion 1)

File: `<workspace>/.saropa/diagnostics/lints.json`, UTF-8, pretty-printed is fine.

```jsonc
{
  "schemaVersion": 1,
  "producer": { "name": "saropa_lints", "version": "<your version>" },
  "generatedAt": "<ISO 8601>",
  "diagnostics": [
    {
      "id": "string",                 // stable, product-scoped dedupe key
      "source": "lints",
      "severity": "error | warning | info",
      "category": "drift | security | performance | crash | schema | data | a11y | other",
      "title": "string",              // already-localized, one line
      "detail": "string?",
      "ruleId": "string?",            // the lint rule name
      "location": { "file": "lib/db/app_database.dart", "line": 12, "column": 3, "uri": "string?" },
      "sql": "string?",
      "table": "string?",
      "fix": { "kind": "command", "title": "string", "command": "saropaLints.explainRule", "args": [ { "ruleId": "require_database_index" } ], "uri": "string?" },
      "docUri": "string?",
      "commitSha": "string?",
      "timestamp": "string?"
    }
  ]
}
```

Compatibility rules (Section 2.4): `schemaVersion` is a single integer (bump only on a breaking
change); consumers ignore unknown fields and refuse a higher major. Every human-facing string is
**already localized** by the producer — do not ship translation keys across the boundary.

---

## Reciprocal: commands Log Capture exposes (for your deep-links back into it)

If a Lints diagnostic wants to deep-link **into** Log Capture (e.g. "this rule fired on a query Log
Capture saw run slow"), these are the stable ids Log Capture now contributes:

| Command id | Args | Opens |
|------------|------|-------|
| `saropaLogCapture.openSignal` | `{ id: string }` | Reveals + flashes that signal in the Signal panel |
| `saropaLogCapture.openSqlHistoryForFingerprint` | `{ sql?: string, fingerprint?: string }` | SQL Query History focused on that query |

---

## Done criteria for the Lints side

- `saropaLints.explainRule` + `saropaLints.enableRule` registered (Log Capture's "Show rule" button
  then appears automatically).
- `.saropa/diagnostics/lints.json` written on analysis, conforming to the schema above.
- Crash signatures from `log-capture.json` mapped to rules; disabled mapped rules surface an
  "enable rule X" prompt.
- Reading is tolerant: absent/truncated/newer-schema sibling files are ignored, not fatal.

---

## Changes Made

All three contract pieces are now implemented in the extension.

**Piece 1 — deep-link commands (was already done before this task).**
`saropaLints.explainRule` (accepts the `{ ruleId }` object form) and `saropaLints.enableRule` are
contributed in `extension/package.json` and registered in `extension/src/extension.ts` /
`extension/src/suite/commands.ts`. Log Capture's "Show this rule" button unhides once it probes these
live.

**Piece 2 — offline mirror (was already done before this task).**
`extension/src/suite/envelope.ts` builds the Saropa Diagnostic Envelope (schemaVersion 1) and
`exporter.ts` writes `<workspace>/.saropa/diagnostics/lints.json` on each analysis settle, with
`source: "lints"`, the error/warning/info triple, workspace-relative `location.file`, `drift` category
for Drift rules, and a `saropaLints.explainRule` command `fix` carrying `args: [{ ruleId }]`.

**Piece 3 — crash-to-rule mapping (this task).**
- `extension/src/suite/crashToRule.ts` — `vscode`-free, unit-testable. Holds the frozen 12-signature
  set (mirrored from Log Capture's `crash-signature.ts`), the `CRASH_SIGNATURE_TO_RULES` map
  (signature → preventing Lints rule[s], most-direct-first), and a tolerant reader of
  `.saropa/diagnostics/log-capture.json` that keeps `category === "crash"` rows, strips the `crash:`
  prefix, ignores unknown/newer signatures, and never throws on a missing/truncated/malformed file.
  `findCrashCoveredDisabledRules` returns one suggestion per observed crash family whose mapped rule is
  currently disabled, with the occurrence count.
- `extension/src/suite/crashCoverageNudge.ts` — the `vscode` glue. Reads the disabled-rules set,
  computes suggestions, and shows a single "enable rule X" toast (highest-occurrence first) wired to
  `saropaLints.enableRule { ruleId }`. Gated once per rule in `globalState` so a rewritten mirror never
  re-nags; the flag is set before the toast awaits so a rapid second change event can't double-show.
- `extension/src/extension.ts` — fires the nudge on activation and on a `FileSystemWatcher` for
  `**/.saropa/diagnostics/log-capture.json`.
- `extension/src/test/suiteCrashToRule.test.ts` — pins the signature set member-for-member,
  cross-checks every mapped rule id against the bundled `media/rules_catalog.json` (all 33 exist), and
  pins reader tolerance + the disabled-only suggestion logic. 9 passing.
- l10n: `suite.crashNudge.message` / `suite.crashNudge.enable` added to `en.json`.

Signature → rule map (adjusted to the real `lib/src/rules/` inventory):

| Signature | Preventing rule(s) |
|-----------|--------------------|
| `state-error-no-element` | `geocoding_unchecked_first`, `image_picker_multi_result_unchecked_empty`, `image_picker_lost_data_empty_check_missing`, `device_calendar_retrieve_events_empty_params` |
| `range-error-index` | `avoid_builder_index_out_of_bounds`, `avoid_accessing_collections_by_constant_index`, `avoid_enum_values_by_index` |
| `null-check-operator` | `avoid_non_null_assertion`, `avoid_null_assertion`, `avoid_ios_force_unwrap_in_callbacks` |
| `late-init` | `avoid_unassigned_late_fields`, `avoid_late_without_guarantee`, `require_late_access_check`, `require_late_initialization_in_init_state` |
| `concurrent-modification` | `avoid_collection_mutating_methods` |
| `type-error-cast` | `avoid_unsafe_cast`, `avoid_unrelated_type_casts`, `avoid_removed_cast_error` |
| `format-exception` | `prefer_try_parse_for_dynamic_data`, `avoid_datetime_parse_unvalidated` |
| `no-such-method` | `avoid_dynamic_type`, `require_null_safe_json_access`, `prefer_correct_json_casts` |
| `assertion-failed` | `avoid_assert_in_production` |
| `stack-overflow` | `avoid_recursive_calls`, `avoid_recursive_widget_calls` |
| `out-of-memory` | `avoid_large_images_in_memory`, `avoid_loading_full_pdf_in_memory`, `avoid_unbounded_cache_growth`, `avoid_memory_intensive_operations` |
| `anr` | `avoid_blocking_main_thread`, `avoid_blocking_database_ui`, `prefer_compute_for_heavy_work` |

Note: `state-error-no-element` has no single generic "`.first` on possibly-empty" rule yet — only the
package-specific empty-result rules cover it today. That gap is a new-rule backlog signal (plan §5),
not a mapping omission.

## Commits

<!-- Add commit hashes as pieces land. -->

## Finish Report (2026-06-14)

**Scope:** (B) VS Code extension (TypeScript under `extension/`). No Dart rule code, analyzer
plugin, or `analysis_options*.yaml` changed.

**What the change does.** Closes the final open piece of the Saropa suite contract — crash-to-rule
attribution (plan requirement R3). The Saropa Log Capture extension records runtime crash families and
writes a `crash`-category diagnostic to `<workspace>/.saropa/diagnostics/log-capture.json` whose
`ruleId` is a stable `crash:`-prefixed signature. The extension now reads that mirror, maps each
signature to the static Lints rule(s) that prevent that crash class, and — when an observed family's
preventing rule is currently disabled — offers a one-time "enable rule X" toast wired to the public
`saropaLints.enableRule { ruleId }` deep-link. This turns production telemetry into a static-analysis
feedback loop. Contract pieces 1 (the `explainRule` / `enableRule` deep-link commands) and 2 (the
`lints.json` envelope mirror) were already implemented before this change; piece 3 completes the set.

**Design.**
- `extension/src/suite/crashToRule.ts` is `vscode`-free and unit-testable, mirroring the established
  pattern of `envelope.ts` and `siblingEnvelopes.ts`. It holds the frozen 12-signature set (kept
  byte-identical to Log Capture's `crash-signature.ts`, a cross-tool contract), the
  `CRASH_SIGNATURE_TO_RULES` map (signature → preventing rule[s], most-direct-first), and a tolerant
  reader. The reader keeps only `category === "crash"` rows, strips the `crash:` prefix, ignores
  signatures outside the frozen set (forward tolerance for a newer Log Capture), and returns an empty
  result rather than throwing on a missing / truncated / malformed file.
- `findCrashCoveredDisabledRules` joins observed crash families against the disabled-rules set
  (`configWriter.readDisabledRules`) and emits one suggestion per (signature, disabled-rule) pair,
  carrying the occurrence count.
- `extension/src/suite/crashCoverageNudge.ts` is the `vscode` glue: it surfaces a single toast (the
  highest-occurrence un-offered suggestion) and gates each rule once in `globalState`. The offered flag
  is written before the toast awaits, so a rapid second mirror-change event cannot double-show the same
  suggestion.
- `extension/src/extension.ts` fires the nudge on activation and registers a `FileSystemWatcher` on
  `**/.saropa/diagnostics/log-capture.json` so a freshly written crash mirror triggers a re-check; the
  per-rule gate prevents re-nagging on rewrite.

**Signature → rule map** (fitted to the real `lib/src/rules/` inventory; every id verified to exist in
the bundled `media/rules_catalog.json`). `state-error-no-element` has no single generic
"`.first` on a possibly-empty iterable" rule today — only package-specific empty-result rules
(`geocoding_unchecked_first`, the two `image_picker_*` rules, `device_calendar_retrieve_events_empty_params`)
cover it. That is a deliberate new-rule backlog signal (plan §5), not a mapping omission.

**Verification.**
- `extension/src/test/suiteCrashToRule.test.ts` — 9 cases, all passing. Pins the signature set
  member-for-member against the frozen list, cross-checks every one of the 33 mapped rule ids against
  the bundled rule catalog (all present), and pins reader tolerance (missing / malformed / non-crash /
  unknown-signature) plus the disabled-only suggestion logic.
- `npx tsc -p tsconfig.test.json` and `npx tsc -p tsconfig.json --noEmit` both exit 0.
- The full suite-test set (`suite*.test.js`, 30 cases) passes.
- A failure in `report-html.test.js` ("missing +example row") is unrelated: it is driven by
  in-progress, uncommitted edits to `vibrancy/views/report-script.ts` / `report-webview.ts` from a
  separate workstream; that test references none of the files changed here and is excluded from this
  commit.

**Localization.** Two user-facing keys added to `extension/src/i18n/locales/en.json`
(`suite.crashNudge.message`, `suite.crashNudge.enable`), interpolated with `{ruleId}` / `{count}`
tokens, no English concatenation. The runtime resolver falls back to English for any locale missing a
key, so the translated catalogs are not regenerated here — that regeneration drives the machine-
translation pipeline, which runs on its own separately-authorized cadence and whose
`--fail-on-missing` publish gate surfaces any stale locale at release time.

**Plan status.** `plans/SAROPA_SUITE_INTEGRATION.md` remains active: R1, R2, R3, R4 are now landed;
R5 (outbound deep-links) + R7 (Package Vibrancy nudge), R6 (commit stamping), and the shared-infra
extraction are still open, so the plan is not archived. This bug file, which tracks the full three-
piece contract, is fully satisfied and archived.

Finish report appended: `plans/history/2026.06/2026.06.14/infra_suite_integration_contract_from_log_capture.md`
Bug archived: `bugs/infra_suite_integration_contract_from_log_capture.md → plans/history/2026.06/2026.06.14/infra_suite_integration_contract_from_log_capture.md`
