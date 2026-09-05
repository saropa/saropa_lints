# Fix Five Code-Review Bugs (Beta 4 Extension UI)

Five confirmed code-review bugs in the beta 4 extension UI work — all surfaced by
a `/code-review medium` scoped to the session's own changes, then verified against
source after three separate delegated agents each produced comments around the
defects without changing behavior. Fixed directly with exact-site edits.

## Finish Report (2026-09-05)

### BUG 1 — Embedded tabs show "Generating…" forever on first open, stale data on subsequent opens

**Defect:** `report-webview.ts` `_updateContent` assigned `this._options` inside a
single object literal that called `_getFullReportEmbed()` and `_getUpgradesEmbed()`
as property initializers. Both fire async builders (`_buildFeatureInventoryReport`,
`_buildOpportunityCardsReport`) that synchronously snapshot `this._options` before
their first `await`. Since the assignment had not completed, they read the OLD
`_options` (or `null` on first open). First open: `null` → builder aborts → tab
stuck on placeholder. Later opens: stale `options.results` from the previous scan.

**Fix:** Split into two-step assignment — assign `_options` with base fields first,
then call the embed builders in a second spread so they snapshot the current data.

**File:** `extension/src/vibrancy/views/report-webview.ts` ~line 178.

### BUG 2 — Full report tab's script leaks into the Overview tab

**Defect:** `getFeatureInventoryScript()` was concatenated bare (no IIFE) into the
Package Dashboard's shared `<script>` tag. Its `setAllOpen()` called
`document.querySelectorAll('details')`, toggling every `<details>` in every tab —
Overview's charts, package filters, grade breakdown. Top-level `var` and `function`
declarations also leaked into the shared scope.

**Fix:** Added a `root` parameter to all three inner script functions
(`getFilterScript`, `getDisclosureScript`, `getSortScript`). Created
`getFeatureInventoryEmbedScript()` that wraps in an IIFE scoped to
`#pkg-tab-fullReport`, mirroring `getKnownIssuesEmbedScript`. `report-html.ts`
now imports and uses the embed variant.

**Files:** `extension/src/vibrancy/views/feature-inventory-script.ts`,
`extension/src/vibrancy/views/report-html.ts`.

### BUG 3 — Engine card stuck "scanning" after a canceled scan

**Defect:** `extension.ts` derived `scanning` from
`progress.filesScanned < progress.totalFiles`. A canceled scan's final tick from
`bin/lsp_server.dart` has `analyzed < total`, so the flag never cleared. The Health
Panel engine card and sidebar Engines row showed "scanning 300/1900" indefinitely.

**Fix at source:** Added a `done` boolean to `buildScanProgressNotification` in
`lib/src/lsp/scan_progress_notification.dart`. `bin/lsp_server.dart` sends
`done: true` on both the cancel and completion terminal paths. The TS
`LspScanProgress` interface carries `done?` (optional for backward compat with
older servers). `extension.ts` uses `progress.done === true` to clear `scanning`,
falling back to the ratio when the field is absent.

**Files:** `lib/src/lsp/scan_progress_notification.dart`, `bin/lsp_server.dart`,
`extension/src/debug/saropaLspClient.ts`, `extension/src/extension.ts`.

### BUG 4 — stderr banner kills typed report tables

**Defect:** `projectMapReports.ts` `startReportRun`'s `onLine` callback appended
both stdout and stderr to `combined`, which `postJsonReportRows` then
`JSON.parse`d. On first run after install/upgrade/`pub get`, Dart prints "Building
package executable…" to stderr, corrupting the parse and dropping to the raw-text
fallback.

**Fix:** Only accumulate `stdout` into `combined`; stderr goes to the per-line
diagnostic table only.

**File:** `extension/src/views/projectMapReports.ts` ~line 444.

### BUG 5 — Project Map progress bar never reaches 100%

**Defect:** `projectHealthCliRunner.ts`'s `close` handler flushed the remaining
`stderrBuf` directly via `handlers.onOutputLine(stderrBuf, 'stderr')`, bypassing
`tryParseHealthProgressEvent`. A final `{"event":"done"}` without a trailing
newline rendered as raw log text and the bar never completed.

**Fix:** Changed the final stderr flush from a direct `onOutputLine` call to
`flushStderr('\n')`, which appends a newline to complete the partial line and
routes it through the normal parse path.

**File:** `extension/src/views/projectHealthCliRunner.ts` ~line 210.

### Test changes

- `test/lsp/scan_progress_notification_test.dart`: Updated exact-map comparison
  to include `'done': false`; added new test for `done: true` on both cancel and
  completion terminal ticks.

### Hardening (post-reflection)

- Verified `_buildOpportunityCardsReport` has the same synchronous `this._options`
  snapshot as `_buildFeatureInventoryReport` — the two-step assignment covers both.
- Fixed `postJsonReportRows` `|| '[]'` fallback that masked CLI crashes (empty
  stdout) as "0 issues found" — empty stdout now falls through to the raw-text
  path showing "(no output)".
- Verified BUG 5 `flushStderr('\n')` is guarded by `stderrBuf.length > 0` — no
  double-flush when the buffer is empty.
- Verified BUG 3 `_lastScanProgress` is already cleared on server stop and
  overwritten by the next scan's initial tick — no stale `done: true` leakage.

### Verification

- `npx tsc --noEmit -p .` — clean.
- `npx tsc -p tsconfig.test.json` — clean.
- Mocha: 1423 passing, 8 failing (all 8 pre-existing, unchanged from baseline).
- F5 visual verification NOT performed — requires Extension Development Host.
