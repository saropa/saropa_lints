# Suite API: expose `getDailySummary` from activate() exports

Filed from Saropa Workspace (`d:\src\saropa_workspace`,
`plans/TODO_better integration with saropa suite.md`). Workspace is building a
consolidated Suite daily report and needs each Suite tool to expose one small
data-returning API. This plan specifies the Saropa Lints side; the Workspace
consumer already tolerates the API being absent (section omitted), so there is no
ordering constraint.

## What to build

Return an API object from the extension's `activate()` so siblings can call
`vscode.extensions.getExtension('saropa.saropa-lints')?.exports`:

```ts
interface SaropaSuiteApi {
  apiVersion: 1;
  getDailySummary(date: string /* YYYY-MM-DD */): Promise<DailySummary | undefined>;
}

interface DailySummary {
  tool: 'saropa-lints';
  date: string;                    // echo of the requested day
  headline: string;                // one plain-language sentence for the caller's
                                   // executive summary, e.g. current health score +
                                   // violation delta for the day
  counts: Record<string, number>;  // e.g. { violations, critical, healthScore,
                                   //        outdatedPackages }
  trouble: Array<{                 // failure-only items for the caller's Trouble
    label: string;                 // section (new criticals, budget breaches)
    detail?: string;
    command?: string;              // deep-link id, e.g. 'saropaLints.focusIssues'
    args?: unknown;
  }>;
  openCommand?: string;            // e.g. 'saropaLints.openProjectHealthDashboard'
}
```

## Why this shape

- **Thin wrapper, not new logic.** Violation counts by impact, the project health
  score, and package-vibrancy budget state already exist for the dashboards
  (`openProjectHealthDashboard`, `openConsolidatedDashboard`) — the API returns
  the current/that-day view of what those surfaces already compute.
- **The API is the contract.** `apiVersion` lets the shape evolve without breaking
  callers; siblings never touch internals or on-disk state.
- **Same protocol family as the documented `saropaLints.*` deep-link ids** the
  Suite already uses for jumping in; this is the matching data-out channel. Treat
  the exported shape with the same never-rename discipline.
- If there is no meaningful per-day history, returning the current snapshot with
  today's date is acceptable for `apiVersion: 1` — note it in the doc.
  `undefined` when no analysis has ever run — callers omit the section.

## Constraints

- Local read only; nothing transmitted. No new dependencies.
- Must not slow activation: build the summary lazily on call, not eagerly.

## Acceptance

- `getExtension('saropa.saropa-lints').exports.getDailySummary(<date>)` resolves
  with real counts + headline after an analysis exists, `undefined` before.
- The exported shape is documented as part of the cross-tool Suite contract.

## Finish Report (2026-07-16)

Status: Implemented.

### What shipped

The VS Code extension's public exports object (`SaropaLintsApi`) gained two
members: a constant `apiVersion: 1` marking the cross-tool Suite contract
version, and `getDailySummary(date)` returning the Suite daily-report
contribution for a `YYYY-MM-DD` day, or `undefined` before any analysis has run.

- `extension/src/api.ts` — added the `DailySummary` interface and the two new
  members on `SaropaLintsApi`, with contract documentation (additive-only,
  never-rename discipline).
- `extension/src/dailySummary.ts` (new) — `buildDailySummary`, a pure builder
  taking `{ date, data, history, outdatedPackages }` and returning the payload.
  It reuses existing surfaces (`computeHealthScore`, severity counts off the
  violations summary, run-history for the day-over-day delta); it introduces no
  new analysis, no disk reads beyond the caller-supplied data, and no network.
- `extension/src/extension.ts` — wired the two members into the `api` object
  (returns `undefined` when `readViolations` is null) and added
  `countOutdatedPackages`, which reads the in-memory Package Vibrancy scan
  (`getLatestResults`), never triggering a scan, and counts direct dependencies
  (`package.isDirect`) whose `updateInfo.updateStatus` is `patch`/`minor`/`major`.
- `extension/src/test/dailySummary.test.ts` (new) — 8 mocha tests pinning the
  contract shape, count presence/omission (`healthScore` withheld on a partial
  sweep, `outdatedPackages` absent when undefined), the pre-date-only baseline
  selection, and both Trouble paths. Registered in the `test` script and
  `tsconfig.test.json`.
- `CHANGELOG.md` — `[Unreleased]` entry; `extension/README.md` — API table row
  plus a Suite daily-report contract section.

### Design notes

- The existing single `exports` object was extended rather than adding a
  competing `SaropaSuiteApi` export, because a VS Code extension exposes exactly
  one `exports` value. The plan's `SaropaSuiteApi` shape is satisfied as a subset
  of `SaropaLintsApi`.
- `counts` is a `Record<string, number>`: a key is omitted (not zeroed) when its
  source is unavailable, so callers never read a misleading value.
- `apiVersion: 1` keeps no per-day history store: counts reflect the current
  snapshot echoed against the requested date, with a best-effort day-over-day
  delta from the run-history the extension already persists — the plan's stated
  acceptable behavior for version 1.
- `headline`/`trouble` strings are English contract data returned to the sibling
  tool (which controls its own locale), so they are intentionally not routed
  through this extension's `l10n` catalog.

### Verification

- Full extension `tsc --noEmit`: clean (exit 0).
- `tsconfig.test.json` compile: clean; the 8 `dailySummary` tests pass.

### Follow-up (not blocking)

- `countOutdatedPackages` (the in-memory Vibrancy filtering) is covered only
  indirectly by passing a literal `outdatedPackages` into the builder. A direct
  test would require mocking the vibrancy activation module.
