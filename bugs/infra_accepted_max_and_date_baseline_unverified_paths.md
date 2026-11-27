# Accepted `max:` and date baseline: unverified paths

**Status: Open (macOS date baseline only).** Daemon and language-server `max:` verified 2026-11-27.

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

Not verified, and not covered by the owner checklist:

- ~~`max:` in the scan daemon, end to end.~~ Verified: `test/accepted/accepted_max_daemon_process_test.dart` spawns `bin/scan_daemon.dart` on a temp package with `max: 1` over three findings (lines 2, 3, 4). Result `[3, 4]`; with `// ignore:` on line 2, result `[4]`.
- ~~`max:` in the language server, end to end.~~ Verified: `test/lsp/accepted_max_lsp_test.dart` runs `bin/lsp_server.dart` over JSON-RPC on stdio with the same fixture. Results match the daemon: `[3, 4]`, and `[4]` with the ignore.
- `baseline: date:` behavior on Linux and macOS. Linux passes in CI (run 45954091686). macOS is unverified.

## Ignored findings in the language server

`bin/lsp_server.dart` has no `filterIgnoredDiagnostics` call. That is not a defect. The resolved runner (`runResolvedWithCollection`) reports through `SaropaDiagnosticReporter`, which already drops `// ignore:`d findings. So an ignored finding never reaches `filterAcceptedByNearestRoot`. It is not published and does not count toward `max`. The ignore case in `accepted_max_lsp_test.dart` proves this: without the drop it would return `[2, 4]`. No code change.

## Finish Report (2026-11-27)

`max:` in the scan daemon and in the language server is verified end to end by `test/accepted/accepted_max_daemon_process_test.dart` and `test/lsp/accepted_max_lsp_test.dart`; both pass. Ignored findings do not count toward `max` in either path.

Remaining: `baseline: date:` on macOS is unverified; no macOS run was made. Status stays Open (macOS date baseline only).
