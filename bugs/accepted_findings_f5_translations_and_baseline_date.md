# Accepted-findings list and baseline: remaining items

**Status: Open**

Created: 2026-11-26
Completed work: `plans/history/2026.11/2026.11.26/accepted_findings_list_open_items.md`

| Open item | Blocker |
|---|---|
| F5 check in light and dark themes: "Accept {rule} in this file" lightbulb (absent on SDK lints); kind picker; empty reason refused; confirmation toast and both buttons; "Check Accepted Findings" toolbar button; Problems markers (stale = warning, invalid = error); empty and clean states; summary tree "N accepted"; screenshot saved to `bugs/` | A person with an Extension Development Host |
| F5 check: accept in a nested package and a second workspace folder; check lists in two packages; second folder with `pubspec.yaml` one level down; folder that only enables the plugin; "Migrate Renamed Rules" on a list naming a renamed rule | A person with an Extension Development Host |
| Scan-on-save through the VS Code extension | A person with an Extension Development Host |
| Translation catalog regeneration for the `acceptedFindings.*` and `command.checkAcceptedFindings.title` keys (locale-parity tests fail until then) | A person must run the translation pipeline |
| Per-entry maximum count (`max:`) | Owner decision on changing the version 1 schema |
| Plugin with several project roots in a live analysis server (accepted list and per-project baseline) | A person running the IDE or `dart analyze` with the plugin |
| `dart run saropa_lints:baseline` against a real project with real `dart analyze` output | A run of `dart analyze` with the plugin |
| `--explain` has no VS Code surface; the project rule asks for visible UI as well as CLI | Extension work (command, strings, translation run) and an F5 check |

## Finish report: `baseline: date:` (2026-11-26)

- Cause: `BaselineManager.preloadDateBaseline` had no caller, and the porcelain parser dated only the first line of each commit.
- Fix: the reporter's date check now runs `git blame` synchronously, once per file content, only for findings that `file` and `paths` did not hide. Cost and limits are in `doc/guides/configuration.md`.
- Tests: a temporary git repository covers the matching rules, safe failures, caching, reloads, and end-to-end `scan`, resolved `scan` and the language server.
- Hardening: event handler names require a capital after `on` and accept both spellings of the canceled suffix; analyzer element resolution confirms the constant-list scoping assumption across files; the `dart analyze` line format was checked against dartdev source and the baseline parser.
- Not verified: the date baseline inside a live analysis server (covered by the plugin item above), real `dart analyze` output (item above), and behavior on Linux or macOS.
