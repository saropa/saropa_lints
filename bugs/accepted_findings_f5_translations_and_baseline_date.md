# Accepted-findings list and baseline: remaining items

**Status: Open**

Created: 2026-11-26
Completed work: `plans/history/2026.11/2026.11.26/accepted_findings_list_open_items.md`

| Open item | Blocker |
|---|---|
| F5 check in light and dark themes: "Accept {rule} in this file" lightbulb (absent on SDK lints); kind picker; empty reason refused; confirmation toast and both buttons; "Check Accepted Findings" toolbar button; Problems markers (stale = warning, invalid = error); empty and clean states; summary tree "N accepted"; the "already has an entry" warning on a finding above `max:`; screenshot saved to `bugs/` | A person with an Extension Development Host |
| F5 check: accept in a nested package and a second workspace folder; check lists in two packages; second folder with `pubspec.yaml` one level down; folder that only enables the plugin; "Migrate Renamed Rules" on a list naming a renamed rule | A person with an Extension Development Host |
| Scan-on-save through the VS Code extension | A person with an Extension Development Host |
| Translation quality left after the hand repairs: suspected MT prompt leaks and overlong values, poor MT outside the repaired keys, no native-speaker review (see the second hand repair below) | Hand repair or an owner-approved run, plus native-speaker review |
| Plugin with several project roots in a live analysis server (accepted list and per-project baseline) | A person running the IDE or `dart analyze` with the plugin |
| `dart run saropa_lints:baseline` against a real project with real `dart analyze` output | A run of `dart analyze` with the plugin |
| `--explain` has no VS Code surface; the project rule asks for visible UI as well as CLI | Extension work (command, strings, translation run) and an F5 check |

## Finish report: `baseline: date:` (2026-11-26)

- Cause: `BaselineManager.preloadDateBaseline` had no caller, and the porcelain parser dated only the first line of each commit.
- Fix: the reporter's date check now runs `git blame` synchronously, once per file content, only for findings that `file` and `paths` did not hide. Cost and limits are in `doc/guides/configuration.md`.
- Tests: a temporary git repository covers the matching rules, safe failures, caching, reloads, and end-to-end `scan`, resolved `scan` and the language server.
- Hardening: event handler names require a capital after `on` and accept both spellings of the canceled suffix; analyzer element resolution confirms the constant-list scoping assumption across files; the `dart analyze` line format was checked against dartdev source and the baseline parser.
- Not verified: the date baseline inside a live analysis server (covered by the plugin item above), real `dart analyze` output (item above), and behavior on Linux or macOS.

## Finish report: `max:` count (2026-11-26)

- The owner accepted adding an optional `max:` to version 1. The first `max` findings by source position stay hidden; the rest report. Entries without it stay unlimited.
- The analyzer plugin holds matching findings until the library walk ends; CLI producers sort per run. A scan CLI smoke run and the `test/accepted`, `test/baseline` and `test/scan` suites passed.
- Not verified: `max:` inside a live analysis server (covered by the plugin item above), and the language server and scan daemon end to end.

## Translation gap-fill run (2026-11-26)

The owner-approved run (Qwen `qwen3:8b`) exited 0 and committed `e061b383e`. Both extension typechecks passed. Locale parity went from 48 failing tests (934 problems) to 31 failing (100 problems); 18 pass. No "Saropa" or `{placeholder}` was lost in values the run changed.

The items listed there as remaining were fixed by the two hand repairs below.

## Hebrew repair and allowlist (2026-11-26)

The six corrupted Hebrew values above, plus the manifest `command.pickUiLanguage.title` (MT had appended "השפה / הלשון"), were hand-written by an agent (not a native speaker) into `he.json` / `package.nls.he.json` and into `TRANSLATIONS["he"]` via `manual_translations_gaps.py`, so a later run keeps them. `pubGuard.source.path` (the `PATH` variable) and `pubGuard.projectSource.dartToolVersion` (a file path) are now in the `english_allowed.json` key list. Locale parity went from 31 failing tests (100 problems) to 29 failing (52 problems); no Hebrew value contains Arabic or kana except the intentional `言語 / 语言` in the picker title.

The items listed there as remaining were repaired in the second hand repair below.

## Second hand repair (2026-11-26)

An agent (not a native speaker, no MT engine) hand-wrote the remaining parity failures and picker titles into the locale files and into `_REPAIRS` in `manual_translations_gaps.py` (which wins over GAPS), plus two fil entries edited in place in GAPS and two in `dictionaries.py`. `compat.status.plugin` and `compat.status.both` now have translations in all 24 locales and left `DO_NOT_TRANSLATE`. Also fixed: the 9 other identical values, the 10 damaged tokens, `command.pickUiLanguage.title` in 17 locales (fr, ja and zh now match the source), and 21 Hebrew accepted-findings strings (22 values) plus the command title. Locale parity: 29 failing (52 problems) before, 49 passing and 0 failing after.

Remaining:

- 46 values are much longer than English, a sign of leaked MT prompt text or repetition. Confirmed leaks: ru and zh `walkthrough.step.walkthrough.triage.description` contain the MT instructions. A length check found the rest (for example de `triageDash.hintSameAsTree`, it `debug.engine.recommended.analyzerPlugin`, uk `config.property.docPlacement.openSignals.description`). The parity test does not detect them.
- MT quality outside the repaired keys is often poor. For example, the sw accepted-findings, vibrancy and walkthrough strings are largely nonsense, and several locales still use "plugin route" in English in tooltips.
- No translation from either hand repair has a native-speaker review.
