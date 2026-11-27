# Accepted `max:` and date baseline: unverified paths

**Status: Open**

From `plans/history/2026.11/2026.11.26/accepted_findings_f5_translations_and_baseline_date.md`.

Not verified, and not covered by the owner checklist:

- `max:` in the scan daemon, end to end.
- `max:` in the language server, end to end. One agent script against `bin/lsp_server.dart` showed `max: 1` hiding line 5 and reporting line 13; nothing more was run.
- `baseline: date:` behavior on Linux and macOS.
