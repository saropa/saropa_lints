# INFRA: Saropa suite integration — contract Saropa Lints must satisfy (Log Capture side has shipped)

**Status: Open**

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

<!-- Fill in as the Lints work lands; add commit hashes. -->

## Commits

<!-- Add commit hashes as pieces land. -->
