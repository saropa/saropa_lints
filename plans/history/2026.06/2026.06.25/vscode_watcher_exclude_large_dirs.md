# VS Code watcher load — exclude the Dart `build` output from the file watcher

## Status: Fixed (2026-06-25)

`files.watcherExclude` with `**/build/**` added to `.vscode/settings.json`.

## Origin

Cross-project hygiene item dispatched from the `saropa-log-capture` repo's
Bug 003 (workspace-wide VS Code blowout detection across `D:\src`).

## Problem

When VS Code opens a folder it watches and indexes the **entire** tree minus a
short default-exclude list (`node_modules`, `.git`). VS Code does **not** exclude
`build/` by default. Large build output is crawled in full on every open. Past a
few GB this adds watcher/index load; at the extreme (16 GB / 180k files in
another project) it pins a CPU core and hangs the window on open. Gitignore stops
commits, not the watcher.

## This repo's large dir (scan 2026-06-25)

| Size | Path | Kind |
|---|---|---|
| 1.14 GB | `build` | Dart build output |

Secondary severity (the project opens today).

## Fix — add to `.vscode/settings.json`

`build/` is regenerated output (gitignored in Dart projects), so excluding it
from the watcher is safe. Add (merge into any existing `files.watcherExclude`):

```json
"files.watcherExclude": {
  "**/build/**": true
}
```

If `.vscode/settings.json` already has settings, merge this key by hand (it may
contain `//` comments, so an automated JSON merge is unsafe). If it does not
exist, create it with the block above wrapped in `{ … }`.

## Reference

`saropa-log-capture` → `plans/history/2026.06/2026.06.25/bug_003_workspace-large-dir-blowout-detection-and-prevention.md`.

## Finish Report (2026-06-25)

### Defect

VS Code's file watcher and indexer crawl the full workspace tree on every open,
excluding only a short built-in list (`node_modules`, `.git`). `build/` is not on
that list, so this repo's 1.14 GB of regenerated Dart build output was scanned in
full each time the project opened, adding watcher and index load. Gitignore
suppresses commits, not the watcher, so the directory was excluded from version
control yet still fully crawled.

### Change

`files.watcherExclude` with the glob `**/build/**` set to `true` was merged into
`.vscode/settings.json`, alongside an explanatory comment noting `build/` is
gitignored regenerated output and therefore safe to exclude. The key was merged
by hand because the file carries `//` comments that make automated JSON merge
unsafe.

`.vscode/settings.json` is gitignored, so the watcher exclusion is applied
locally and is not tracked — the correct location for per-developer editor
configuration. The tracked artifacts of this fix are this archived bug report and
the CHANGELOG Maintenance entry under `[14.2.2]`.

### Scope

Editor configuration and documentation only. No Dart lint rules, analyzer
behavior, or extension code changed. No tests apply.
