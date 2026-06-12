# Status-bar score + Issues tree read live diagnostics

The VS Code extension's status-bar lint score and Issues list read the batch
`reports/.saropa_lints/violations.json` export, which is only written by an
explicit, expensive analysis run. Between runs the file goes stale, so the
status bar could show "grade A / 0 findings" while the Problems panel held
dozens of live findings — the same diagnostics, two sources, free to diverge.
The Findings (wide) report and the consolidated dashboard already read live
diagnostics; the status bar and Issues tree did not. Routing them through the
same live source closes the divergence and removes the staleness window.

## Finish Report (2026-06-12)

### Scope
**(B)** VS Code extension (TypeScript). No Dart lint rules / analyzer plugin
changed — Linter-Specific Integrity SKIPPED [A-NOT-IN-SCOPE].

### What changed
A new module, [liveViolationsData.ts](../../../../extension/src/liveViolationsData.ts),
wraps the #1a `buildViolationsDataFromDiagnostics` so the status bar and the
Issues tree grade against the analyzer's current diagnostics instead of the
stale JSON export:

- **`readLiveViolations(root, getDiagnostics?, tier?)`** — raw live findings
  (every analyzer diagnostic on a `.dart` file, holistic by design). The Issues
  tree consumes this; it does its own disabled / text / suppression filtering
  downstream, so it must receive the unfiltered set.
- **`readVisibleLiveViolations(root, …, disabled?)`** — live findings with
  disabled rules removed and summary counts recomputed, mirroring the former
  file-based `readVisibleViolations`. The status-bar score reads this, so a
  muted rule never drags the grade.
- **`hasLiveViolations(root, getDiagnostics?)`** — drop-in for the file-based
  `hasViolations`, gating the Issues tree's empty state.

All three accept injected dependencies (`getDiagnostics`, `tier`, `disabled`) so
unit tests touch neither the `vscode` config API nor the filesystem.

Wiring:
- [views/issuesTree.ts](../../../../extension/src/views/issuesTree.ts) re-sourced
  via import alias (`readLiveViolations as readViolations`, `hasLiveViolations as
  hasViolations`), so every call site is unchanged — only the data source moves.
- [extension.ts](../../../../extension/src/extension.ts): the local
  `readVisibleViolations` now delegates to `readVisibleLiveViolations`; the
  status-bar score read switched from the raw, file-based `readViolations` to
  that live + disabled-filtered read.
- A debounced (`400 ms`) `vscode.languages.onDidChangeDiagnostics` listener was
  added — previously absent — to refresh the status bar, the Issues tree, and the
  `hasViolations` context key whenever the analyzer updates diagnostics. Without
  it the live surfaces would only move on an explicit command and re-introduce
  the staleness the migration removes. The 400 ms debounce coalesces the per-file
  burst VS Code emits during one analysis pass into a single refresh (matching the
  consolidated dashboard's cadence).
- The now-unused `filterDisabledFromData` import was removed from `extension.ts`.

### Behavior change
The status bar and Issues tree are now **holistic** — they count every analyzer
diagnostic (built-in Dart lints, other `custom_lint` plugins, Saropa rules),
matching the Problems panel and the already-live wide report, instead of the
saropa-only JSON export. Finding counts and the status-bar score may therefore
read higher than before; this is the intended alignment, not a regression.

### Deep review
- **Logic & safety:** the debounce timer is cleared on dispose (registered as a
  `context.subscriptions` disposable) so no callback fires after teardown.
  `readVisibleLiveViolations` recomputes summary counts from the filtered array
  via the existing `filterDisabledFromData`, so disabled rules drop from both the
  violation list and every aggregate. Live reads always return a non-null model
  (empty = clean), which all call sites already tolerate (`data?.violations ?? []`).
- **Architecture:** reuses the existing `buildViolationsDataFromDiagnostics`,
  `filterDisabledFromData`, and `readDisabledRules`; no logic duplicated. The new
  module centralizes the "prefer live" read so future surfaces (CodeLens, inline
  annotations, triage, rule-packs panel — still on the JSON path) can adopt it.
- **Performance:** zero analysis — reads the diagnostics the analyzer already
  produced; the debounce prevents a refresh per file during a sweep.
- **Docs:** module header on `liveViolationsData.ts` states the why (anti-
  divergence, holistic, injectable); the listener and the source swap carry
  inline rationale comments.

### Testing
- **Audited** existing tests referencing the changed symbols. `issuesTree.test.ts`
  stubbed `violationsReader.readViolations`; because the tree now sources from
  `liveViolationsData`, those three stubs were retargeted to
  `liveViolationsData.readLiveViolations` (same fake data, same assertions) — the
  intent (tree structure from injected findings) is preserved. The four other
  tree tests that stub `violationsReader` exercise trees not touched here and were
  left unchanged.
- **New:** [test/liveViolationsData.test.ts](../../../../extension/src/test/liveViolationsData.test.ts)
  — four cases: raw passthrough + tier propagation, disabled-rule removal with
  summary recompute, passthrough when nothing disabled, and the has-findings gate
  (true with findings, false on an empty stream — no stale file to fall back to).
- **Build wiring:** `tsconfig.test.json` (explicit include allowlist) and the
  `package.json` mocha file list both gained the new module + test.
- **Run:** `npm run check-types` clean; `npm test` = **1224 passing / 11 failing**.
  The 11 failures pre-exist (cross-file CLI harness + a languagePick locale-coverage
  assertion, all in untouched modules) — count rose from 1220 to 1224 (the four new
  tests), zero regressions.

### Not verified
The status bar and Issues tree were not launched in the Extension Development
Host; the data-layer migration is unit-verified, but the rendered status-bar
label and tree under live updates were not visually confirmed on a running
instance. The model and listener logic carry no UI-render risk beyond the
holistic count change noted above.

### Files
- New: `extension/src/liveViolationsData.ts`, `extension/src/test/liveViolationsData.test.ts`
- Modified: `extension/src/extension.ts`, `extension/src/views/issuesTree.ts`,
  `extension/src/test/views/issuesTree.test.ts`, `extension/tsconfig.test.json`,
  `extension/package.json`, `CHANGELOG.md`, `plans/OUTSTANDING_ITEMS_AUDIT.md`
