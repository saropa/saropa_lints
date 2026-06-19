# BUG: `infra` — Drift Advisor integration duplicates Problems diagnostics when the standalone Saropa Drift Advisor extension is installed

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-18
Area: Optional Drift Advisor integration (extension, not a lint rule)
File: `extension/src/driftAdvisor/driftAdvisorTree.ts` (`updateDiagnostics`, ~line 67)
Severity: High — every Drift anomaly / index suggestion appears twice in the Problems panel
Type: Infrastructure / duplicate diagnostic emission

---

## Summary

When a user has **both** the Saropa Lints extension (`saropa.saropa-lints`) and the standalone **Saropa Drift Advisor** extension (`saropa.drift-viewer`) installed, each Drift anomaly and index suggestion is published to the Problems panel **twice** — once by each extension. Both connect to the same Drift Advisor server and republish the same issues.

The Saropa Lints integration should defer to the standalone extension when it is present (the standalone extension is the canonical owner of these Problems-panel diagnostics), or surface a one-time recommendation, instead of silently double-emitting.

---

## Attribution Evidence

This is not a lint-rule false positive — it is duplicate diagnostic emission across two extensions. Attribution here means proving **which extension emits which of the two diagnostics**.

```bash
# Diagnostic #1 emitter — IS in saropa_lints (this repo)
grep -rn "drift_advisor_anomaly" extension/src/
# extension/src/driftAdvisor/driftAdvisorTree.ts:24:  const CODE_ANOMALY = 'drift_advisor_anomaly';
# extension/src/driftAdvisor/driftAdvisorTree.ts:8: ... codes drift_advisor_index_suggestion / drift_advisor_anomaly ...

# Diagnostic #2 emitter — is the standalone extension, NOT this repo
grep -rn "drift_advisor_anomaly" ../saropa_drift_advisor/extension/src/
# 0 matches — the standalone extension uses code 'anomaly', source 'Drift Advisor'
```

**Emitter (diagnostic #1):** `extension/src/driftAdvisor/driftAdvisorTree.ts:67-93` (`DriftAdvisorTreeProvider.updateDiagnostics`)
**Diagnostic `source` / `owner`:** `Saropa Drift Advisor`; **codes:** `drift_advisor_anomaly`, `drift_advisor_index_suggestion`; **message prefix:** `[Drift] `
**The other (standalone) emitter (diagnostic #2):** `../saropa_drift_advisor/extension/src/diagnostics/diagnostic-manager.ts` → collection `drift-advisor`, source `Drift Advisor`, code `anomaly`, prefix `[drift_advisor]`. Working correctly — one diagnostic on the column line.

---

## Reproducer

1. Install both extensions in VS Code: `saropa.saropa-lints` and `saropa.drift-viewer`.
2. Open a workspace with a Drift schema and a running app (`d:\src\contacts`).
3. Both extensions discover the Drift Advisor server and fetch issues.
4. Open a table file with an anomaly, e.g. `lib/database/drift/tables/static_data/contact/star_trek_table.dart`.

Observed — two diagnostics on the same line, identical statistics (`n=149`):

```json
[{
	"owner": "Saropa Drift Advisor",
	"code": "drift_advisor_anomaly",
	"source": "Saropa Drift Advisor",
	"message": "[Drift] star_trek_characters.weight_kilograms: Potential outlier in star_trek_characters.weight_kilograms: min value 30.0 is 3.3σ from mean 70.75 (range [30.0, 110.0], n=149)",
	"startLineNumber": 80
},{
	"owner": "drift-advisor",
	"code": "anomaly",
	"source": "Drift Advisor",
	"message": "[drift_advisor] Potential outlier in star_trek_characters.weight_kilograms: min value 30.0 is 3.3σ from mean 70.75 (range [30.0, 110.0], n=149)",
	"startLineNumber": 80
}]
```

**Frequency:** Always, whenever both extensions are installed and connected to the same server.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | One diagnostic per Drift anomaly / index suggestion. When the standalone extension owns the Problems panel, Saropa Lints does not also publish there. |
| **Actual** | Two diagnostics per issue (one from each extension), at the same line, with identical numbers but different `source` / `code` / prefix. |

---

## Root Cause

The Saropa Lints "Drift Advisor integration" predates / parallels the standalone extension. Its `updateDiagnostics()` publishes to the Problems panel gated **only** by `saropaLints.driftAdvisor.showInProblems`, which **defaults to `true`** — there is no check for whether the standalone extension is already publishing the same issues.

`extension/src/driftAdvisor/driftAdvisorTree.ts:67-70`:

```ts
private updateDiagnostics(): void {
  this.diagnosticCollection.clear();
  const showInProblems = vscode.workspace.getConfiguration('saropaLints.driftAdvisor').get<boolean>('showInProblems', true);
  if (!showInProblems) return;
  // ... publishes every issue with no awareness of the standalone extension ...
}
```

When both extensions run, both reach this code path (each in its own process) and both publish. Neither is internally double-emitting; the duplication is the two extensions overlapping.

---

## Suggested Fix — Plan (detect + suppress, with a recommendation fallback)

The repo already has the pieces: the canonical standalone id `ADVISOR_EXTENSION_ID = 'saropa.drift-viewer'` in `extension/src/suite/siblingDeepLinkTargets.ts`, and a once-gated sibling-detection nudge pattern in `extension/src/suite/suiteAwarenessNudge.ts`. Reuse both.

### Part 1 — auto-suppress the duplicate (primary)

In `DriftAdvisorTreeProvider.updateDiagnostics()`, skip the **Problems publish** when the standalone extension is active. Keep populating the tree view regardless (the tree does not depend on the Problems publish, so the Lints "Drift Advisor" sidebar still works).

```ts
import { ADVISOR_EXTENSION_ID } from '../suite/siblingDeepLinkTargets';

private updateDiagnostics(): void {
  this.diagnosticCollection.clear();

  // The standalone Saropa Drift Advisor extension (saropa.drift-viewer) is the
  // canonical owner of these Problems-panel diagnostics. When it is installed and
  // active it publishes the same anomalies/index suggestions, so emitting our copy
  // produces duplicate squiggles (one per extension). Defer to it for the Problems
  // panel; the Lints "Drift Advisor" tree view below is unaffected.
  const standalone = vscode.extensions.getExtension(ADVISOR_EXTENSION_ID);
  if (standalone?.isActive) return;

  const showInProblems = vscode.workspace
    .getConfiguration('saropaLints.driftAdvisor')
    .get<boolean>('showInProblems', true);
  if (!showInProblems) return;
  // ... existing publish loop ...
}
```

Guard correctness:
- Check `isActive`, not mere presence — an installed-but-disabled standalone extension should not suppress us.
- Re-run `updateDiagnostics()` on `vscode.extensions.onDidChange` so suppression flips correctly if the standalone extension is enabled/disabled mid-session.

### Part 2 — surface a one-time recommendation (fallback, mirrors the suite nudge)

When the standalone extension is **not** installed but a Drift Advisor server is connected, optionally surface a once-gated toast recommending the standalone extension (it has the richer Problems-panel experience), exactly like `maybeNudgeSuiteAwareness` recommends Log Capture: per-workspace `surfaced` flag, honors the existing `saropaLints.upgradePackNudge.enabled` opt-out, and an "Install" action that runs `workbench.extensions.search` filtered to `ADVISOR_EXTENSION_ID`. This is optional polish; Part 1 is the duplicate fix.

### Part 3 — config default

Leave `saropaLints.driftAdvisor.showInProblems` defaulting to `true` (lints-only users still want the diagnostics). The active-extension check in Part 1 is what removes the duplicate; do **not** flip the default to `false`, which would hide diagnostics for users who only have Saropa Lints.

---

## Fixture / Test Gap

Extract the suppression decision into a pure predicate so it is testable without VS Code (same split as `shouldNudgeSuiteAwareness`):

```ts
export function shouldPublishDriftProblems(inputs: {
  standaloneActive: boolean;
  showInProblems: boolean;
}): boolean {
  return !inputs.standaloneActive && inputs.showInProblems;
}
```

Tests:
1. standalone active → `false` (suppressed) regardless of `showInProblems`.
2. standalone absent, `showInProblems = true` → `true` (publish).
3. standalone absent, `showInProblems = false` → `false` (user opted out).

---

## Changes Made

All three parts landed: Part 1 (primary duplicate fix), Part 2 (one-time recommendation toast), Part 3 (config default unchanged).

### Part 1 — auto-suppress the duplicate

- **New pure predicate** `extension/src/driftAdvisor/driftProblemsGate.ts` — `shouldPublishDriftProblems({ standaloneActive, showInProblems })` returns `!standaloneActive && showInProblems`. Mirrors the `suiteAwarenessGate` split so the suppression rule is unit-testable without VS Code.
- **`DriftAdvisorTreeProvider.updateDiagnostics()`** (`extension/src/driftAdvisor/driftAdvisorTree.ts`) now skips the Problems publish when the standalone extension (`saropa.drift-viewer`) is **active** (`isActive`, not mere presence), via the predicate. The tree view is unaffected. Reuses `ADVISOR_EXTENSION_ID` from `siblingDeepLinkTargets.ts`.
- **New public method** `reevaluateDiagnostics()` on the provider — re-runs the publish decision from the cached issue set with no network re-fetch.
- **`extension.ts`** registers `vscode.extensions.onDidChange(() => driftAdvisorProvider.reevaluateDiagnostics())` so the suppression flips immediately when the standalone extension is enabled/disabled mid-session.

### Part 2 — one-time recommendation toast

- **New pure gate** `extension/src/driftAdvisor/driftAdvisorRecommendGate.ts` — `shouldRecommendDriftAdvisor(...)` is a four-way AND: standalone missing, server connected, not already surfaced, nudges on.
- **New nudge shell** `extension/src/driftAdvisor/driftAdvisorRecommendNudge.ts` — `maybeRecommendDriftAdvisor(context, serverConnected)`. Per-workspace `surfaced` flag, honors the `saropaLints.upgradePackNudge.enabled` opt-out, "Install" action runs `workbench.extensions.search` filtered to `saropa.drift-viewer`. Mirrors `maybeNudgeSuiteAwareness`.
- **Wired in** `extension.ts` right after a successful Drift server connection in the refresh command.
- **l10n** new keys `suite.driftRecommend.{message,install,dismiss}` in `extension/src/i18n/locales/en.json`. Translated locale catalogs must be regenerated before release (the publish coverage gate enforces this).

### Part 3 — config default

- `saropaLints.driftAdvisor.showInProblems` left defaulting to `true`. The active-extension check in Part 1 removes the duplicate; lints-only users keep their diagnostics.

- **`CHANGELOG.md`** — two bullets under `[14.0.3] → Fixed (Extension)`.

---

## Tests Added

Both picked up by the existing `driftAdvisor/**` test glob. All 9 cases pass; `tsc --noEmit` clean.

`extension/src/test/driftAdvisor/driftProblemsGate.test.ts`:
1. standalone active, `showInProblems` on → `false` (suppressed).
2. standalone active, `showInProblems` off → `false` (suppressed).
3. standalone absent, `showInProblems` on → `true` (publish).
4. standalone absent, `showInProblems` off → `false` (user opted out).

`extension/src/test/driftAdvisor/driftAdvisorRecommendGate.test.ts`:
1. standalone absent + server connected + unseen + nudges on → `true` (recommend).
2. standalone installed → `false`.
3. no server connected → `false`.
4. already surfaced → `false`.
5. proactive nudges off → `false`.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: (fill in)
- Standalone extension: `saropa.drift-viewer` (Saropa Drift Advisor)
- VS Code version: (fill in)
- Triggering project/file: `d:\src\contacts` — `lib/database/drift/tables/static_data/contact/star_trek_table.dart:80`

---

## Related

- Downstream report (standalone-extension side, no code change needed there): `../saropa_drift_advisor/bugs/BUG_remove duplicate lint warning.md`
- Prior in-repo duplicate on the advisor side (distinct, already resolved): `../saropa_drift_advisor/plans/history/2026.04/2026.04.22/BUG_anomaly_false_positive_tight_timestamp_range.md`
- Existing detection precedent to reuse: `extension/src/suite/suiteAwarenessNudge.ts`, `extension/src/suite/siblingDeepLinkTargets.ts`

---

## Finish Report (2026-06-18)

### Defect

With both the Saropa Lints extension (`saropa.saropa-lints`) and the standalone Saropa Drift Advisor extension (`saropa.drift-viewer`) installed, every Drift anomaly and index suggestion was published to the Problems panel twice — once by each extension — because the Lints integration's `updateDiagnostics()` gated its publish only on `saropaLints.driftAdvisor.showInProblems` (default `true`) with no awareness that the standalone extension already owns those diagnostics.

### Resolution

The Lints integration now defers the Problems publish to the standalone extension when that extension is active, and recommends installing it when it is absent. The duplicate disappears without hiding diagnostics for lints-only users.

**Part 1 — auto-suppress the duplicate.** A pure predicate `shouldPublishDriftProblems({ standaloneActive, showInProblems })` (`extension/src/driftAdvisor/driftProblemsGate.ts`) returns `!standaloneActive && showInProblems`. `DriftAdvisorTreeProvider.updateDiagnostics()` checks `vscode.extensions.getExtension('saropa.drift-viewer')?.isActive` — active state, not mere presence, so an installed-but-disabled standalone extension does not suppress — and skips the publish accordingly. The tree view is independent of the publish and remains populated. A new public `reevaluateDiagnostics()` re-runs the decision from the cached issue set with no network re-fetch, driven by a `vscode.extensions.onDidChange` listener registered in `extension.ts`, so suppression flips immediately when the standalone extension is enabled/disabled mid-session.

**Part 2 — one-time recommendation.** When a Drift server connects through the Lints integration but the standalone extension is not installed, a once-per-workspace toast recommends it. The decision is the pure four-way AND `shouldRecommendDriftAdvisor(...)` (`driftAdvisorRecommendGate.ts`): standalone missing, server connected, not already surfaced, proactive nudges on. The impure shell `maybeRecommendDriftAdvisor(context, serverConnected)` (`driftAdvisorRecommendNudge.ts`) records a per-workspace `surfaced` flag before showing, honors the existing `saropaLints.upgradePackNudge.enabled` opt-out, and routes "Install" to `workbench.extensions.search` filtered to the standalone extension id. It is invoked after a successful server connection in the refresh command. New runtime catalog keys `suite.driftRecommend.{message,install,dismiss}` were added to `en.json`; the translated locale catalogs are stale until regenerated.

**Part 3 — config default.** `saropaLints.driftAdvisor.showInProblems` remains defaulting to `true`; the active-extension check is what removes the duplicate, so lints-only users keep their diagnostics.

### Verification

Nine unit tests across `driftProblemsGate.test.ts` (4) and `driftAdvisorRecommendGate.test.ts` (5) pin both gates without VS Code. All pass; `tsc --noEmit` clean.

### Follow-up

The translated locale catalogs must be regenerated (NLLB/MT pipeline) before release so the three new keys are not English placeholders; the publish coverage gate (`--fail-on-missing`) blocks until then.
