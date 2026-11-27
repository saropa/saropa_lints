# Accepted findings and baseline: look at it in VS Code

**Status: Closed** (owner order, 2026-11-27)

Not verified:

- Screen checks: never run (no Extension Development Host run, no screenshot).
- macOS `baseline: date:`: pending the first run of the `test-macos` CI job.
- Translations: no native-speaker review.

In PowerShell, run `npm run compile` in `D:\src\saropa_lints\extension`, then open the window:

```powershell
code --new-window --extensionDevelopmentPath=D:\src\saropa_lints\extension D:\tmp\accepted_check\accepted.code-workspace
```

Pick **Light Modern** first (Ctrl+K, Ctrl+T). The Command Palette is Ctrl+Shift+P, Problems is Ctrl+Shift+M. Save screenshots in `D:\src\saropa_lints\bugs\`.

1. **Quick fix.** Open `main\lib\b.dart`, wait for findings (can take minutes), click the `avoid_catch_all` underline on line 5, press Ctrl+. and choose **Accept avoid_catch_all in this file…**.
   - See: a picker `Why is this finding accepted?`, then a reason box. Enter on the empty box shows `A reason is required.`
2. **Messages.** Type any reason, press Enter. Click **Restart Analysis Server**, then type a space in `b.dart` and save.
   - See: `Added avoid_catch_all in lib/b.dart to main/saropa_accepted.yaml. …` with **Restart Analysis Server** and **Open List**. After the restart, line 5 loses `avoid_catch_all`; line 13 keeps it.
   - Then run **Saropa Lints: Check Accepted Findings** and click **Open List**. See: `Accepted findings: 1 stale and 1 invalid, out of 2 entries. See the Problems panel.`, and in Problems a warning (line 3) and an error (line 6) on `second\app\saropa_accepted.yaml`.
3. **Both themes.** Screenshot the picker or reason box, the message and the Problems entries as `accepted_light.png`. Switch to **Dark Modern**, run the check again, open the quick fix on `a.dart` line 5, screenshot as `accepted_dark.png`, press Esc.
   - See: all text and markers readable in both.
4. **Count.** Run **Saropa Lints: Manage Rule Packs**. Screenshot in both themes (`accepted_count_light.png`, `accepted_count_dark.png`).
   - See: the `Suppressions (export)` line includes `accepted` and a number.
5. **Explain baseline.** Open `dated\lib\h.dart`, right-click in the editor, choose **Saropa Lints: Explain Baseline for This File**. Screenshot as `explain_baseline.png`.
   - See: a progress notification, then in Output, channel **Saropa Lints**, a report with `date: 2030-01-01; findings on 16 line(s) …`.
   - Right-click `h.dart` in the Explorer: the same entry is there. Run it and press **Cancel** on the notification: it stops with no error.
   - Open `dated\analysis_options.yaml` and run the command from the Command Palette. See: `Open or select a Dart file to explain its baseline.`
6. **Without the extension.** Close the window, run the command below, open `lib\g.dart` and wait.

   ```powershell
   code --new-window --disable-extension saropa.saropa-lints D:\tmp\accepted_check\live\one
   ```

   - See: `avoid_catch_all` on line 13 only, not line 5 (line 5 is accepted).

If a step fails, give an agent the step number and a screenshot.
