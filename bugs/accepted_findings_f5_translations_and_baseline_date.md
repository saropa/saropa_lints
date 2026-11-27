# Accepted-findings list and baseline: remaining items

**Status: Open**

Created: 2026-11-26
Completed work: `plans/history/2026.11/2026.11.26/accepted_findings_list_open_items.md`

| Open item | Blocker |
|---|---|
| F5 check in light and dark themes: "Accept {rule} in this file" lightbulb (absent on SDK lints); kind picker; empty reason refused; confirmation toast and both buttons; "Check Accepted Findings" toolbar button; Problems markers (stale = warning, invalid = error); empty and clean states; summary tree "N accepted"; the "already has an entry" warning on a finding above `max:`; screenshot saved to `bugs/` | A person with an Extension Development Host. The summary tree part cannot be checked (see below) |
| F5 check: accept in a nested package and a second workspace folder; check lists in two packages; second folder with `pubspec.yaml` one level down; folder that only enables the plugin; "Migrate Renamed Rules" on a list naming a renamed rule | A person with an Extension Development Host |
| Scan-on-save through the VS Code extension | A person with an Extension Development Host |
| Translation quality (see "Translation: still open") | Hand repair or an owner-approved run, plus native-speaker review |
| Plugin with several project roots in a live analysis server (accepted list and per-project baseline) | A person running the IDE or `dart analyze` with the plugin |
| `dart run saropa_lints:baseline` against a real project with real `dart analyze` output | A run of `dart analyze` with the plugin |
| `--explain` has no VS Code surface; the project rule asks for visible UI as well as CLI | Extension work (command, strings, translation run) and an F5 check |
| Defect: `scan --find-stale-ignores` reports a live `// ignore:` as stale when the rule drops the finding at report time (observed 2026-11-27 with `// ignore: prefer_logger_over_print` above a `print`, relative and full path); `--fix-stale-ignores` would delete it | Code fix |
| With the plugin block commented out (language server on), a plain `scan` without `--tier`, `--find-stale-ignores` and `--fix-stale-ignores` still print "scan skipped" and exit 0, so the extension's stale-ignore commands do nothing there | Owner decision for plain `scan`; the stale-ignore modes wait for the defect above |
| "Summary tree shows N accepted" cannot be seen: the Summary tree is not registered as a view | Owner decision: drop the item or show the count elsewhere (step 29 checks the Manage Rule Packs strip) |

## Checklist to run

Every step says what to do and what a pass looks like. If a step does not pass, write down the step number and what appeared. The finding text always starts with the rule name in square brackets.

### Setup (already done 2026-11-27)

The test projects exist under `D:\tmp\accepted_check\`. Nothing needs to be typed.

| Folder or file | Contents |
|---|---|
| `accepted.code-workspace` | Opens `main`, `second`, `plugin_only`; turns scan-on-save on and the language server off |
| `main\` | `pubspec.yaml` (uses `D:\src\saropa_lints`), `analysis_options.yaml`, `analysis_options_custom.yaml`, `lib\a.dart`, `lib\b.dart`, `lib\clean.dart` |
| `main\example\` | Nested package: `pubspec.yaml`, `lib\c.dart` |
| `second\app\` | Package one level down: same files, `lib\d.dart` |
| `plugin_only\` | Turns the plugin on without listing saropa_lints in `pubspec.yaml`; `lib\e.dart` |
| `baseline\` | For the baseline command; `lib\f.dart` |
| `dated\` | Committed to its own git repository, baseline `date: "2030-01-01"`; `lib\h.dart` |
| `live\one\` | `lib\g.dart`; accepted list with `max: 1` |
| `live\two\` | `lib\g.dart`; its own baseline file that hides the `print` findings |

Shared contents:

- `analysis_options.yaml` turns on the plugin from `D:/src/saropa_lints` with `avoid_catch_all` and `avoid_print_error`. In `main`, `second\app` and `plugin_only` it also turns on the Dart SDK lint `avoid_print`.
- `analysis_options_custom.yaml` contains `lane: full`.
- Every `lib` file except `clean.dart` has two functions that catch errors: `avoid_catch_all` on lines 5 and 13, `avoid_print_error` on lines 6 and 14.

To start over, run in PowerShell:

```powershell
Remove-Item D:\tmp\accepted_check\main\saropa_accepted.yaml, D:\tmp\accepted_check\main\example\saropa_accepted.yaml, D:\tmp\accepted_check\second\app\saropa_accepted.yaml, D:\tmp\accepted_check\plugin_only\saropa_accepted.yaml, D:\tmp\accepted_check\baseline\saropa_baseline.json -ErrorAction SilentlyContinue
Set-Content D:\tmp\accepted_check\baseline\analysis_options_custom.yaml 'lane: full'
```

### A. Start

1. In PowerShell run `cd D:\src\saropa_lints\extension` then `npm run compile`. Pass: it ends with `build finished` and no errors. (An agent ran this on 2026-11-27; run it again if extension code changed since.)
2. Run `code --new-window --extensionDevelopmentPath=D:\src\saropa_lints\extension D:\tmp\accepted_check\accepted.code-workspace`. Pass: a window titled "Extension Development Host" opens with the three folders and a Saropa Lints icon in the left bar.
3. Open `main\lib\a.dart` and wait (the first analysis can take several minutes). Pass: the Problems panel (Ctrl+Shift+M) lists `avoid_catch_all` on lines 5 and 13.

### B. Accept and check (one package)

4. Open the Command Palette (Ctrl+Shift+P) and run **Saropa Lints: Check Accepted Findings**. Pass (empty state): a "Checking accepted findings…" progress message, then `No saropa_accepted.yaml found in any package of the workspace. Use "Accept in this file" on a finding to start one.`
5. Open `main\lib\b.dart`, click the `avoid_catch_all` underline on line 5, press Ctrl+. . Pass: the menu has **Accept avoid_catch_all in this file…**.
6. On the same file, click a `print` finding whose Problems entry is the plain Dart lint `avoid_print` (its text does not start with `[`), press Ctrl+. . Pass: no "Accept avoid_print in this file…" entry.
7. Choose **Accept avoid_catch_all in this file…**. Pass: a picker titled `Why is this finding accepted?` with two choices (Accepted, False positive).
8. Pick one. With the reason box empty, press Enter. Pass: `A reason is required.` and the box stays open.
9. Type a reason and press Enter. Pass: `Added avoid_catch_all in lib/b.dart to main/saropa_accepted.yaml. …` with buttons **Restart Analysis Server** and **Open List**.
10. Click **Open List**. Pass: the list opens with your entry.
11. Repeat steps 5 to 9 on `main\lib\a.dart` for `avoid_print_error`, then click **Restart Analysis Server**. Pass: the server restarts; after typing a space in each file and saving, the accepted findings are gone and the others remain.
12. Delete the `avoid_print_error` entry from the list and save. With the list open, click the checklist icon at the top right of the editor (tooltip **Saropa Lints: Check Accepted Findings**). Pass (clean state): `Accepted findings: 1 entries checked, none stale or invalid.`
13. Replace the whole list with the text below, save, and click the icon again.

    ```yaml
    version: 1
    accepted:
      - rule: avoid_print_error
        file: lib/a.dart
        reason: still matches
      - rule: avoid_catch_all
        file: lib/clean.dart
        reason: nothing found there
      - rule: avoid_catch_all
        file: lib/gone.dart
        reason: file does not exist
      - rule: avoid_catch_all
        file: lib/b.dart
    ```

    Pass: `Accepted findings: 2 stale and 1 invalid, out of 3 entries. See the Problems panel.` with **Open List**. The Problems panel shows warnings on lines 6 and 9 of the list and an error on line 12.
14. Replace the whole list with the text below and save. Type a space in `a.dart` and save. On the remaining `avoid_catch_all` (line 13) press Ctrl+. , accept it, and enter a reason. Pass: line 5 has no `avoid_catch_all`, line 13 does; the warning says `saropa_accepted.yaml already has an entry for avoid_catch_all in lib/a.dart. If the entry has a max count, raise it by hand.`; the list opens and no second entry was added.

    ```yaml
    version: 1
    accepted:
      - rule: avoid_catch_all
        file: lib/a.dart
        max: 1
        reason: one is fine
    ```

### C. Several packages and folders

15. Open `main\example\lib\c.dart` and accept `avoid_catch_all`. Pass: a new `main\example\saropa_accepted.yaml` with `file: "lib/c.dart"`; the list in `main` is unchanged.
16. Open `second\app\lib\d.dart`, wait for findings, accept `avoid_catch_all`. Pass: a new `second\app\saropa_accepted.yaml` with `file: "lib/d.dart"`.
17. Create `plugin_only\saropa_accepted.yaml` with the text below. Then add the same three-line entry (from `- rule`) to the end of the lists in `main`, `main\example` and `second\app`. Save all and run **Saropa Lints: Check Accepted Findings**.

    ```yaml
    version: 1
    accepted:
      - rule: avoid_catch_all
        file: lib/gone.dart
        reason: file does not exist
    ```

    Pass: the message reports 4 stale and 0 invalid; each of the four lists has a warning in the Problems panel.
18. Click **Open List** in that message. Pass: one of the lists with a warning opens.
19. Add the entry below to `main\saropa_accepted.yaml`, save, and run **Saropa Lints: Migrate Renamed Rules**. Keep the file ticked, click OK, review the comparison view, then click **Apply**.

    ```yaml
      - rule: deprecated_new_in_comment_reference
        file: lib/a.dart
        reason: rename check
    ```

    Pass: the picker is titled `Migrate renamed rules`; the final message says `Updated 1 rule reference(s) in 1 file(s)`; the entry now reads `deprecated_new_in_comment_reference_extended`.

### D. Scan on save and language server

20. Open `main\lib\b.dart`. Paste the function below at the end and save. Pass: within about a minute the Problems panel shows new `avoid_catch_all` and `avoid_print_error` entries marked `saropa_lints` on the new lines.

    ```dart
    void third() {
      try {
        print('third');
      } catch (e) {
        print(e);
      }
    }
    ```

21. Delete the function and save. Pass: those entries disappear. If step 20 failed, copy the `[scan-on-save]` lines from the Output panel, channel Saropa Lints.
22. Replace `main\saropa_accepted.yaml` with the `max: 1` list from step 14, then type a space in `a.dart` and save. Pass: the `saropa_lints` entries show `avoid_catch_all` on line 13 only.
23. Open `D:\tmp\accepted_check\accepted.code-workspace`, change `"saropaLints.lspServer.enabled"` to `true`, save, then run **Developer: Reload Window**. Pass: `main\analysis_options.yaml` now has its plugin section commented out (expected).
24. Open `main\lib\a.dart` and wait. Pass: `avoid_catch_all` appears on line 13 and not on line 5.
25. Run **Saropa Lints: Check Accepted Findings**. Pass: a normal result message (`… entries checked, none stale or invalid.`, or a stale/invalid count with **Open List**), not `Check accepted findings failed: …` and not a missing-list message. If it fails, record the exact message.
26. Change the setting back to `false` and save. Pass: within a few seconds the plugin section in `main\analysis_options.yaml` is no longer commented out.

### E. Light and dark

27. Press Ctrl+K then Ctrl+T and pick **Light Modern**. Repeat steps 7, 8 (cancel with Esc), 13. Pass: picker, reason box, error text, messages and Problems markers are readable. Save a screenshot as `D:\src\saropa_lints\bugs\accepted_findings_light.png`.
28. Same with **Dark Modern**, saved as `D:\src\saropa_lints\bugs\accepted_findings_dark.png`.

### F. Count of accepted findings

29. With at least one accepted entry that still matches, run **Dart: Restart Analysis Server**, wait for findings to return, then run **Saropa Lints: Manage Rule Packs**. Pass: the line titled `Suppressions (export)` includes `accepted` followed by a number. (This stands in for the Summary tree item, which cannot be seen. No agent has seen this line with accepted findings.)

### G. Live analysis server, no extension

30. Close the test window. Run `code --new-window --disable-extension saropa.saropa-lints D:\tmp\accepted_check\live`, open both `g.dart` files and wait. Pass: `one` shows `avoid_catch_all` on line 13 only, plus `avoid_print_error` on 6 and 14. `two` shows `avoid_catch_all` on 5 and 13 and no `avoid_print_error`.
31. In `live\one\saropa_accepted.yaml` change `max: 1` to `max: 2` and save; type a space in `one\lib\g.dart` and save. Pass: no `avoid_catch_all` left in `one`, without restarting; `two` is unchanged. Set it back to `max: 1`.
32. In PowerShell run `dart analyze D:\tmp\accepted_check\live`. Pass: 5 issues (`one`: one `avoid_catch_all`, two `avoid_print_error`; `two`: two `avoid_catch_all`). If no Saropa findings appear at all, also run it on `…\live\one` and `…\live\two` separately and record both.
33. Run `dart analyze D:\tmp\accepted_check\dated`. Pass: `No issues found!`
34. Paste the function from step 20 at the end of `D:\tmp\accepted_check\dated\lib\h.dart`, save, and run the same command. Pass: 2 issues, both inside the new function. Then run `git -C D:\tmp\accepted_check\dated checkout -- lib/h.dart`.

### H. Baseline command

35. Run `cd D:\tmp\accepted_check\baseline` then `dart analyze`. Pass: 4 issues.
36. Run `dart run saropa_lints:baseline`. Pass: `Found 4 violation(s)`, `Files: 1`, `Rules: 2`; `saropa_baseline.json` is created; `analysis_options_custom.yaml` keeps `lane: full` and gains a `baseline:` section.
37. Run `dart analyze`. Pass: `No issues found!`
38. Run `dart run saropa_lints:baseline --update`. Pass: `Previous: 4 violations`, `Current:  4 violations`, `No change`.
39. Paste the function from step 20 at the end of `lib\f.dart`, save, run `dart analyze`. Pass: 2 issues, both inside the new function.
40. Run `dart run saropa_lints:baseline --explain lib/f.dart`. Pass: it lists the baseline file entries with rule and line numbers for `lib/f.dart`.

When everything passes, tell an agent which steps passed so this file can be closed.

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

## Translation: still open

Locale parity tests: 49 passing, 0 failing after the hand repairs of 2026-11-26 and 2026-11-27 (written by an agent, not a native speaker, no MT engine).

- Fixed 2026-11-27: the 46 overlong values (40+ character English, more than 2.5 times as long) plus every leaked MT prompt and looped word or phrase, 387 values in all 24 locales. Repairs are in `extension/scripts/i18n/manual_translations_mt_leaks.py`, folded into `_REPAIRS`. The parity test and `bad_translations.py` now fail on a leaked numbered prompt, a word or phrase repeated three times in a row, or a 40+ character value over 2.5 times the English length.
- Still open: about 400 values where NLLB inserted an invented sentence, mostly right after "Saropa Lints:" (vi "là người có thể", zh "没有一个人", fr "Il s'agit de", it "è il nome di", es "Es el nombre de la persona") or after a placeholder (pt "É um tipo de vírus"). They are under 2.5 times the English length, so the new check does not catch them. Fixing them needs an owner decision on scope.
- Still open: many short labels are still wrong without being repeats or overlong (for example fr `packageDetail.versionGap.typePr` "Il s'agit de PR, PR.", ja `commandCatalog.entry.internalBadge` "メニューメニューメヌー").
- MT quality outside the repaired keys is often poor. For example, much of the sw text is still nonsense, and several locales still use "plugin route" in English in tooltips.
- No translation from any hand repair has a native-speaker review.
