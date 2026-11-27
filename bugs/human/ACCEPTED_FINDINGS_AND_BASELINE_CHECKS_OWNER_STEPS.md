# Accepted findings and baseline: owner checks

Status: code merged. Steps 2 to 31 need a person at a VS Code window. Step 32 now runs per package (a parent-folder run hits an SDK limit); it needs only PowerShell. From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

Step 1 (`npm run compile` in `D:\src\saropa_lints\extension`) passed on 2026-11-27 and is left out; run it again first if extension code has changed since.

Steps 33 to 40 (dated baseline under `dart analyze`, and the baseline command) were agent-verified on 2026-11-27 and are left out; the `baseline\` and `dated\` folders are back to their starting state.

## Setup

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

## Steps

Every step says what to do and what a pass looks like. The finding text always starts with the rule name in square brackets.

### A. Start

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
24. (Language server output passed in an agent script; only the editor display is unchecked.) Open `main\lib\a.dart` and wait. Pass: `avoid_catch_all` appears on line 13 and not on line 5.
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
32. (A parent-folder run cannot pass: the Dart analysis server reports done when the first package's plugin finishes, so `dart analyze D:\tmp\accepted_check\live` shows only `one`. Upstream SDK limit, documented in `doc\guides\configuration.md`; see `plans\history\2026.11\2026.11.27\infra_dart_analyze_parent_folder_skips_second_package.md`.) In PowerShell run `dart analyze D:\tmp\accepted_check\live\one`, then `dart analyze D:\tmp\accepted_check\live\two`. Pass: `one` gives 3 issues (one `avoid_catch_all`, two `avoid_print_error`); `two` gives 2 (two `avoid_catch_all`). The agent run of 2026-11-27 already saw `two` give its 2.

## If a step fails

Write down the step number and what appeared, with a screenshot, and give it to an agent.
