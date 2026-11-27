# `baseline --explain` has no VS Code surface

**Status: Open, human check**

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

The project rule asks for visible UI as well as CLI. `dart run saropa_lints:baseline --explain <file>` exists on the command line only.

Done: command `saropaLints.explainBaseline` (`extension/src/baselineExplainCommand.ts`) in the editor and Explorer context menus for `.dart` files, the Command Palette and the command catalog. Strings are hand-written in all locales.

Remaining:

- Human F5 check in light and dark themes: both context menus, palette with a non-Dart file active (message), report in the Output channel, progress notification and Cancel.
- Locale regeneration and review at publish.

## Finish Report (2026-11-27)

Command `saropaLints.explainBaseline` is registered, in both context menus, the palette and the catalog. Typechecks pass; `extension/src/test/baselineExplainCommand.test.ts` passes. The Windows shell fallback (used when `dart` is only `dart.bat`) now refuses any path containing `%`, `!`, `"`, `^` or a control character, since cmd.exe or a batch wrapper can still act on those inside quotes; such a path runs only without a shell.

Known gaps: on saropa_lints older than 17.10.0 the CLI does not support `--explain` and the result is not an explanation; when stderr is empty the error message ends in an English fallback from the shared `summarizeError`.

Unverified on screen: no Extension Development Host run, no screenshot. Remaining: human F5 check (light and dark: both context menus, palette with a non-Dart file active, Output report, progress and Cancel) and locale review at publish. Status stays Open, human check.

Hardening (2026-11-27): on Windows, a path the shell fallback refuses now shows a localized message naming the cause (`baselineExplain.error.unsafePath`) in place of `spawn dart ENOENT`. Not seen on screen; add it to the F5 check.
