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
| `baseline: date:` hides nothing during analysis: `BaselineManager.preloadDateBaseline` has no caller (also true at commit be403f6c7), and the reporter's date check reads only preloaded data | Owner decision: running git blame from the synchronous reporter path (cost, process spawning in the analysis server) or removing the setting. Documented in `doc/guides/configuration.md` and stated by `--explain` |
| `--explain` has no VS Code surface; the project rule asks for visible UI as well as CLI | Extension work (command, strings, translation run) and an F5 check |
