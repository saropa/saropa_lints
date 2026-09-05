# Status bar: memory breakdown link + actionable tooltip menu

The extension's main status bar item crammed lint score, tier, vibrancy, and
memory/system-health state into one text string with no way to click through
to memory details, and its hover tooltip was read-only text with no actions.
Neither defect had a tracking bug filed; this record exists so the change is
discoverable outside the CHANGELOG.

## What changed

**`extension/src/extension.ts`**

- Split the single status bar item into two: the existing `statusBarItem`
  (lint score/tier/vibrancy only) and a new `memoryStatusBarItem`
  (`StatusBarAlignment.Right`, priority 99), which is hidden unless plugin
  memory pressure or system-health is non-healthy. Its command is
  `saropaLints.showProcessHealth`, so clicking a memory warning now opens the
  Process Health panel instead of going nowhere.
- Added `updateMemoryStatusBar()`, extracted from the memory/system-health
  logic that used to live inline in `updateAllStatusBars()`.
- Added `STATUS_BAR_TRUSTED_COMMANDS`, `statusBarCmdLink()`, and
  `buildStatusBarTooltipMarkdown()`: the main item's tooltip is now a
  `vscode.MarkdownString` with `isTrusted.enabledCommands`, rendering a
  clickable action menu (toggle analysis on/off via a checkbox-style
  `$(check)`/`$(circle-outline)` icon, open Violations Report, open Package
  Dashboard, open Process Health, Command Catalog, About) below the existing
  read-only info lines. Pattern mirrors `CaptureToggleStatusBar` in the
  sibling `saropa-log-capture` extension (`src/ui/shared/capture-toggle-status-bar.ts`),
  which uses the same MarkdownString + trusted-command-link technique for its
  own status bar menu.

**`extension/src/statusBarLabel.ts`**

- Removed the now-dead `systemHealthSuffix` parameter and its branch from
  `buildStatusBarLabel()` — no caller passes it since memory/system-health
  rendering moved to `memoryStatusBarItem`. Caught by code review: the
  parameter was still exercised directly by two unit tests, so the tests were
  green on a code path production could no longer reach.

**`extension/src/test/sidebarToggleLabel.test.ts`**

- Replaced the two `systemHealthSuffix` present/absent test cases with one
  case pinning the current signature (no suffix parameter).

**`extension/src/i18n/locales/en.json`**

- Added `systemHealth.statusBar.openHint` (memory item tooltip hint).
- Added `statusBar.menu.*` (7 keys) for the new tooltip menu labels — these
  were originally hardcoded English literals; code review flagged the i18n
  violation (`.claude/rules/i18n.md` requires every user-facing string route
  through `l10n()`) and they were moved into the catalog.

## Verification

- `npx tsc --noEmit -p tsconfig.json` — clean, twice (after the initial
  change and again after the i18n/dead-code fixes).
- `sidebarToggleLabel.test.ts` compiled via `tsconfig.test.json` and run
  directly with mocha — 8/8 passing, including the updated
  `buildStatusBarLabel` case.
- Not verified in a running Extension Development Host — the split status
  bar item and the new tooltip menu have not been visually confirmed in VS
  Code; only the compiled TypeScript and the unit test were checked.

## Known issue surfaced, not fixed here

Running `extension/scripts/generate_translations.py` during the i18n
checklist step (in violation of the global rule requiring explicit
in-the-moment authorization for any translation-pipeline run) revealed a
pre-existing backlog: 3,240 untranslated-key gaps across all locales,
unrelated to this change. The 8 new keys added here (`statusBar.menu.*`,
`systemHealth.statusBar.openHint`) join that backlog and render in English
in non-English locales until a deliberately authorized translation run. The
script's own git hook committed `extension/src/i18n/locale_coverage.json`
(coverage-percentage bookkeeping only, no translated content) as
`0067ea43` — left in place per user decision rather than reverted.

## Context: concurrent sessions on the same working tree

During this work, `HEAD` on `main` advanced twice from commits made by other
concurrent sessions unrelated to this task (`scan-on-save` observability,
`scan-on-open` activation scanning), and an untracked file
(`plans/AUDIT_extension_ux_facts.md`) appeared that this session did not
create. Those files and commits were left untouched — only the files listed
above were authored or modified as part of this task.
