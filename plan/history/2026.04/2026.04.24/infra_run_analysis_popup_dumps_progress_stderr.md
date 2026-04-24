# BUG: `Run Analysis` popup dumps progress-bar stderr — no issue count, no actions

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-24
Component: VS Code extension — `saropaLints.runAnalysis` command
File: `extension/src/setup.ts` (lines ~282–300)
Severity: UX — High (surfaces on every non-clean run of the primary command, first thing users see)
Rule version: N/A (extension bug, not a rule bug)

<!-- cspell:ignore countr -->
---

## Summary

When `Saropa Lints: Run Analysis` finishes with a non-zero exit (i.e. issues were found — the common case), the extension shows a `showWarningMessage` that concatenates the first 200 characters of `dart analyze`'s stderr. `dart analyze` / `saropa_lints` writes a progress bar to stderr during long runs, so the popup body is *always* the progress bar text frozen at the moment analysis exited — never a diagnostic, never a count, never an action.

The user observes this:

```
Analysis reported issues.
░░░░░░░░░░░░░░░░░░░░ 0% │ Files: 10/3699 │ Issues: 169 │ ETA: 18m 40s │ activity_list_recent_emails.dart
░░░░░░░░░░░░░░░░░░░░ 1% │ Files: 20/3699 │ Issues: 398 │ ETA: 14m 22s │ hidden_notice_countr
```

It tells the user nothing actionable. The popup should state the real issue count (read from `reports/.saropa_lints/violations.json` — the extension already has a reader) and offer buttons to jump to the Violations view or the Output channel.

---

## Attribution Evidence

This is an extension bug, not a rule bug. No `lib/src/rules/` grep applies. Source of the offending popup is confirmed in-repo:

```bash
grep -rn "Analysis reported issues" extension/src/
# extension/src/setup.ts:296:        logReport(`- Analysis reported issues (${cmd} analyze)`);
# extension/src/setup.ts:298:          `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
# extension/src/setup.ts:349:        logReport(`- Analysis reported issues (${cmd} analyze ${toRun.length} files)`);
# extension/src/setup.ts:464:    '- Analysis reported issues',
```

**Emitter:** `extension/src/setup.ts:297-299` — inside `runAnalysis()`.
**Sibling (same class of bug):** `extension/src/setup.ts:283` — inside the `openEditorsOnly` branch of `runAnalysis()`, shows `'Analysis reported violations (open Dart files only). Check the Violations view.'` — less egregious (no stderr dump) but still has no count and no action buttons.

---

## Reproducer

1. Open the `saropa-contacts` workspace (or any large Dart/Flutter project where `dart analyze` takes more than a few seconds and reports issues — the progress-bar writer starts emitting stderr once analysis is long enough).
2. Ensure `saropa_lints` is enabled (so `analysis_options.yaml` activates the plugin).
3. From the VS Code command palette: `Saropa Lints: Run Analysis`.
4. Wait for the progress notification titled `Running analysis` to finish.
5. Observe the follow-up **warning** popup — it reads `Analysis reported issues.` followed by garbled progress-bar fragments clipped at 200 characters mid-line.

**Frequency:** Always, on any analysis run that (a) takes long enough to emit progress output AND (b) exits non-zero. That is the normal, expected path for any real-world project — so every user sees this the first time they try the command.

**Shortcut reproducer (no large project):** in any pub workspace, add one ignored lint and run the command — when exit is zero the popup does not fire, but any introduced violation produces exit != 0 and triggers the popup. If the analyze run is too fast to emit progress output, the popup body degrades to `See Problems view.` (the `result.stderr ? ... : 'See Problems view.'` fallback) — still useless (no count, no button).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Concise popup with the real issue count from `violations.json`, e.g. `Saropa Lints: 5,234 issues found.`, plus `[View Violations]` and `[Show Output]` action buttons that invoke `saropaLints.focusIssues` and `saropaLints.showOutput`. |
| **Actual** | `Analysis reported issues. ░░░░░░░░░░░░░░░░░░░░ 0% │ Files: 10/3699 │ Issues: 169 │ ETA: 18m 40s │ activity_list_recent_…` — stderr progress text truncated mid-line at 200 characters. No count (nothing authoritative — the ETA and partial count are stale snapshots from mid-analysis), no action buttons, no next step. |

The success path already does the right thing — `extension/src/extension.ts:679` posts a status-bar message `Saropa Lints: Analysis complete. Score: NN`. Only the failure path (which is the common path) is broken.

---

## Offending Code

`extension/src/setup.ts:293-300` (current state):

```ts
if (ok) {
  logReport('- Analysis completed clean');
} else {
  logReport(`- Analysis reported issues (${cmd} analyze)`);
  vscode.window.showWarningMessage(
    `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
  );
}
```

`extension/src/setup.ts:281-285` (sibling, open-editors-only path):

```ts
ok = await runAnalysisForFiles(context, files, { showProgress: false });
if (!ok) {
  vscode.window.showWarningMessage('Analysis reported violations (open Dart files only). Check the Violations view.');
}
```

---

## Root Cause

Two separate mistakes compound:

1. **stderr is the wrong stream.** `dart analyze` writes progress updates to stderr (the `░░░░ N% │ Files: … │ Issues: … │ ETA: …` bar) and writes its diagnostic output to stdout. Slicing the first 200 bytes of stderr therefore yields progress chrome, not findings. Even if stdout were sliced instead, the first 200 chars would still be unusable — a popup is the wrong place for raw CLI output.
2. **The extension already has structured issue data and ignores it.** `extension/src/violationsReader.ts:92` exposes `readViolations(workspaceRoot)` which returns `ViolationsData.summary.totalViolations` — the authoritative count, written to `reports/.saropa_lints/violations.json` on every successful run of the analyzer plugin. The runAnalysis failure path never reads it, so it reconstructs nothing useful and falls back to the stderr slice. The success path at `extension/src/extension.ts:675-679` already calls `readViolations` and `computeHealthScore` for the status-bar message — the same data is available to the failure popup and is simply unused.

`vscode.window.showWarningMessage` also accepts trailing string arguments as clickable buttons; the current call passes none, so even the generic `See Problems view.` fallback offers no way to act on it.

---

## Suggested Fix

Extract a helper in `extension/src/setup.ts` that reads `violations.json` for the real count and shows a warning with two action buttons. Use it from both popup sites.

```ts
import { readViolations } from './violationsReader';

// Fire-and-forget: not awaited so the caller's `withProgress` indicator
// clears immediately. The popup itself is modeless.
function showAnalysisIssuesNotification(workspaceRoot: string, scope?: string): void {
  const data = readViolations(workspaceRoot);
  // Prefer the summary count; fall back to violations.length so older
  // violations.json files (pre-summary) still produce a useful number.
  const total = data?.summary?.totalViolations ?? data?.violations.length ?? 0;
  const scopeLabel = scope ? ` (${scope})` : '';
  const message = total > 0
    ? `Saropa Lints: ${total.toLocaleString()} issue${total === 1 ? '' : 's'} found${scopeLabel}.`
    : `Saropa Lints analysis finished with a non-zero exit${scopeLabel}. See Output for details.`;

  void vscode.window.showWarningMessage(message, 'View Violations', 'Show Output').then((choice) => {
    if (choice === 'View Violations') {
      void vscode.commands.executeCommand('saropaLints.focusIssues');
    } else if (choice === 'Show Output') {
      void vscode.commands.executeCommand('saropaLints.showOutput');
    }
  });
}
```

### Replace in `runAnalysis` (full-project path)

```ts
// Before (extension/src/setup.ts:297-299):
vscode.window.showWarningMessage(
  `Analysis reported issues. ${result.stderr ? result.stderr.slice(0, 200) : 'See Problems view.'}`,
);

// After:
showAnalysisIssuesNotification(workspaceRoot);
```

### Replace in `runAnalysis` (open-editors-only path)

```ts
// Before (extension/src/setup.ts:283):
vscode.window.showWarningMessage('Analysis reported violations (open Dart files only). Check the Violations view.');

// After:
showAnalysisIssuesNotification(workspaceRoot, 'open editors only');
```

The command IDs `saropaLints.focusIssues` and `saropaLints.showOutput` are already registered in `extension/src/extension.ts` (lines 781 and 1040 respectively), so no command additions are needed.

---

## Fixture Gap

N/A — this is an extension UX bug, not a rule bug. Manual verification steps:

1. `Run Analysis` on a project with zero violations → no popup (success path unchanged, status bar still shows `Analysis complete. Score: NN`).
2. `Run Analysis` on a project with violations → popup reads `Saropa Lints: N issues found.` with `[View Violations]` and `[Show Output]` buttons.
3. Click `View Violations` → focuses the issues tree (`saropaLints.focusIssues`).
4. Click `Show Output` → surfaces the `Saropa Lints` output channel.
5. Temporarily delete `reports/.saropa_lints/violations.json` before clicking `Run Analysis` and force a failure exit → popup falls back to the generic `non-zero exit` message with both buttons still present.
6. Toggle `saropaLints.runAnalysisOpenEditorsOnly` to `true`, open a Dart file with violations → popup reads `Saropa Lints: N issues found (open editors only).`

---

## Changes Made

- [extension/src/setup.ts](../extension/src/setup.ts): added `readViolations` import; added two helpers above `runAnalysis`:
  - `formatAnalysisIssuesMessage(total, scope?)` — pure message builder, exported so the test suite can pin pluralization / scope-label / zero-count branches without stubbing the vscode UI module.
  - `showAnalysisIssuesNotification(workspaceRoot, scope?)` — reads `violations.json` (preferring `summary.totalViolations`, falling back to `violations.length` for pre-summary files), composes the message via `formatAnalysisIssuesMessage`, and fires a `showWarningMessage` with `View Violations` / `Show Output` buttons wired to the existing `saropaLints.focusIssues` and `saropaLints.showOutput` commands. Fire-and-forget so the caller's `withProgress` indicator clears immediately.
- [extension/src/setup.ts](../extension/src/setup.ts): both popup call sites inside `runAnalysis` now invoke `showAnalysisIssuesNotification`:
  - Full-project path (was: `Analysis reported issues. ${result.stderr?.slice(0, 200) ?? 'See Problems view.'}`).
  - `openEditorsOnly` path (was: `Analysis reported violations (open Dart files only). Check the Violations view.`) — passes `'open editors only'` as the scope label.
- [CHANGELOG.md](../CHANGELOG.md): entry under `[Unreleased] › Fixed` summarizing the popup fix; also extended the top `Unreleased` intro line so pub.dev readers see the extension fix alongside the new Dart rule.
- No new commands or package.json `contributes.commands` entries — `saropaLints.focusIssues` and `saropaLints.showOutput` were already registered in [extension/src/extension.ts](../extension/src/extension.ts) at lines 781 and 1040 respectively.

---

## Tests Added

- [extension/src/test/formatAnalysisIssuesMessage.test.ts](../extension/src/test/formatAnalysisIssuesMessage.test.ts) — seven cases covering plural/singular nouns, `toLocaleString` thousands separators, presence vs. absence of the scope label (asserting no stray `()` or double-space when `scope` is undefined), and the `total === 0` fallback in both with-scope and without-scope forms. Loads `./vibrancy/register-vscode-mock` first so `setup.ts`'s module-scope `import * as vscode from 'vscode'` resolves outside the VS Code host.
- [extension/package.json](../extension/package.json): added `out-test/test/formatAnalysisIssuesMessage.test.js` to the `test` script's explicit file list (it enumerates rather than globs).

---

## Commits

- `392c4642` — fix(extension): show real issue count in Run Analysis warning popup

---

## Environment

- saropa_lints package version: `^12.3.4` (per `CHANGELOG.md` top entry)
- saropa_lints VS Code extension: current `main` as of 2026-04-24
- Dart SDK: project-dependent (reproduced against a Flutter 3.x project using `flutter analyze`)
- Triggering project: `d:\src\contacts` (saropa-contacts — 3,699 Dart files per the captured popup text)
