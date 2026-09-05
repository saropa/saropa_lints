# Plan — Dart-side deferred work (extension UI redesign)

**Created:** 2026-09-05 · **Status:** Not started
**Parent:** `PLAN_extension_ui_redesign.md` Phases 2, 4, 6 deferred items
**Scope:** Dart (`lib/`, `bin/`) + corresponding TS consumers. Requires `dart test` and
`flutter test` runs.
**Model:** Sonnet for each work item. They are independent and can run in parallel.

---

## Overview

Five Dart-side features were deferred from the TS-only extension UI redesign because they
require changes to CLI tools, the LSP server, or the config loader. Each is independent.
Ordered by user-facing value.

---

## WP1 — Project Map progress bar

**Problem:** `bin/project_health.dart` has no `--progress` flag. The Project Map scanning
pane shows a real elapsed timer and activity log (Phase 6), but cannot show "43% — 812/1900
files" the way Code Health does, because the CLI never emits per-file progress events.

**Reference pattern:** `bin/project_vibrancy.dart` already implements `--progress` (NDJSON on
stderr, stdout reserved for final report) and `--control <path>` (pause/cancel via text file).
The TS consumer is `projectVibrancyCliRunner.ts` with types in `projectVibrancyTypes.ts`.

**Work:**
1. **Dart:** Add `--progress` flag to `bin/project_health.dart`. During `runSizeScan`, emit
   NDJSON events on stderr: `{"event":"fileScanned","file":"lib/foo.dart","done":812,"total":1900}`.
   Mirror the event schema from `project_vibrancy.dart`.
2. **Dart:** Add `--control <path>` flag for pause/cancel, same protocol.
3. **TS:** Update `projectMapView.ts`'s scan runner to pass `--progress` and parse the NDJSON
   events. Update `buildScanningMapPaneHtml()` to render a percentage progress bar (the HTML
   slot already exists as `id="pmScanElapsed"` — extend it or add a sibling).
4. **Test:** Dart unit test for the NDJSON output. TS test for the progress parser.

**Estimate:** 1 session (Sonnet). The Dart pattern is copy-paste from `project_vibrancy.dart`;
the TS consumer mirrors `projectVibrancyCliRunner.ts`.

---

## WP2 — Per-tool structured report columns

**Problem:** The 7 report-card CLIs (`severity_report`, `impact_report`, `quality_gate`,
`stub_test_report`, `accuracy_report`, `memory_report`, `doctor`) are `print()`-based text
tools. Only `accuracy_report` has `--format json`. The Reports tab renders all of them as a
generic two-column table (line number + raw text) instead of structured File/Line/Rule columns.

**Work:**
1. **Dart:** Add `--format json` to the highest-value CLIs first: `severity_report` and
   `doctor`. Each should output a JSON array of objects with typed fields (`file`, `line`,
   `rule`, `severity`, `message`).
2. **TS:** In `projectMapReports.ts`, add per-tool parsers for the JSON-enabled CLIs. When
   `--format json` is available, pass it and render a typed `.dash-table` with real columns
   (File, Line, Rule, Message) instead of the generic line-number table.
3. **Test:** Dart unit tests for JSON output schema. TS test for the typed table renderer.

**Estimate:** 1 session per CLI (Sonnet). Start with `severity_report` — it's the most
requested. `doctor` second. The others can follow the same pattern incrementally.

---

## WP3 — `runtime_tier` config key verification

**Problem:** The Rules & Tiers Config file tab writes `runtime_tier` to the TOP LEVEL of
`analysis_options_custom.yaml`. But `runtime_tier_cap.dart` reads `runtime_tier` only from
`plugins.saropa_lints` in `analysis_options.yaml` (nested, not top-level). The top-level
custom key `saropa_tier` is confirmed as priority 2, but whether top-level `runtime_tier`
in the custom file is honored is unverified.

**Research found:** `runtime_tier_cap.dart` uses `parseScalarFromPluginBlock` which reads
from the `plugins.saropa_lints` block only. `saropa_tier` in `analysis_options_custom.yaml`
top-level is deprecated — parsed only to warn users to migrate.

**Work:**
1. **Dart:** Read `runtime_tier` from the custom yaml top-level in `runtime_tier_cap.dart`,
   at the same precedence as `saropa_tier` (priority 2). OR: change the Config file tab to
   write `saropa_tier` instead (the key that already works). Decision needed — the simpler
   fix is option B.
2. **Test:** Unit test confirming the top-level key is read with correct precedence.

**Estimate:** < 1 hour (Sonnet). This is a config-loader read + test, not a feature.

---

## WP4 — LSP scan-progress surfacing

**Problem:** The LSP server runs a full workspace scan on startup, but progress (file count,
diagnostic count) is only logged to stderr (visible in the Output channel). The Engines card
in the Health Panel cannot show "scanning 812/1900 files" because no structured progress
events reach the TS client.

**Research found:** The LSP server uses standard JSON-RPC 2.0 with no custom notification
channels. The only non-standard method is `_internal/analyzeFromDidOpen` (internal debounce).

**Work:**
1. **Dart:** Add a custom LSP notification `saropa/scanProgress` to `bin/lsp_server.dart`.
   Emit during the workspace scan: `{"filesScanned": 812, "totalFiles": 1900, "diagnosticsPublished": 47}`.
   Use the standard `$/progress` LSP protocol if possible (preferred over a custom notification
   since `vscode-languageclient` handles it natively).
2. **TS:** In `saropaLspClient.ts`, register a handler for the progress notification. Surface
   in the Health Panel's engine card and optionally in the sidebar's Engines row description.
3. **Test:** Dart unit test for the notification emission. TS test for the handler.

**Estimate:** 1 session (Sonnet). The `$/progress` LSP protocol is well-documented; the TS
`vscode-languageclient` library has built-in support via `WorkDoneProgress`.

---

## WP5 — Project size JSON (low priority)

**Problem:** The Home hub (removed) and Project Map's KPI tile show "Mapped — see Project Map"
instead of a real project size number, because the structured size data is only available via
`--format json` (which IS supported by `project_health.dart` already) but the TS side never
reads it after the scan.

**Research found:** `project_health.dart` already supports `--format json` and outputs file
counts, LOC (code/comment/blank), and size in bytes. The data exists — it just isn't consumed.

**Work:**
1. **TS:** After a successful Project Map scan, read the JSON output (or the `files.ndjson`
   on disk) and extract the size summary. Cache it in `workspaceState` so it survives tab
   close/reopen.
2. **TS:** Surface the cached size in the Project Map's hero KPI strip (total files, total
   LOC, total size in MB).
3. **Test:** TS test for the JSON reader and cache.

**Estimate:** < 1 session (Sonnet). No Dart changes needed — the data already exists.

---

## Dependency graph

```
WP1 (progress bar) — independent
WP2 (report columns) — independent, incremental per CLI
WP3 (runtime_tier) — independent, < 1 hour
WP4 (LSP progress) — independent
WP5 (project size) — independent, TS-only
```

All five are independent. WP3 and WP5 are the smallest. WP1 and WP4 follow the same
"add progress events, consume in TS" pattern.
