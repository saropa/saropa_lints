# Plan: Standalone LSP Server Migration

**Status:** Phase 0 implemented — pending manual VS Code test
**Created:** 2026-09-02
**Updated:** 2026-09-03
**Audience:** maintainers planning the migration from `analysis_server_plugin` to a standalone LSP server

## Problem statement

The Dart analysis server's resolved element model consumes 6–8 GB RSS for large
projects. saropa_lints runs inside that process via `analysis_server_plugin`,
making it appear responsible for the entire footprint. Rule shedding (2,000+
rules) barely dents RSS because the memory is the analyzer's element model, not
the rules themselves.

The scan daemon already proves out-of-process analysis works — it runs ~2,100
rules in a separate `dart` process using its own `AnalysisContextCollection`.
But it only runs on save (not continuously), communicates via NDJSON (not LSP),
and can't deliver squiggles or quick fixes to the editor in real time.

**DCM (Dart Code Metrics) solved this exact problem** by abandoning the analyzer
plugin model entirely. DCM runs as a standalone native binary with its own LSP
server. Squiggles, Problems panel entries, and quick fixes all flow through
standard LSP — completely independent of the Dart analysis server. Result:
350 MB on the Flame repo (down from 4 GB in-process). Two LSP servers feed the
same VS Code Problems panel seamlessly.

## Vision: what "done" looks like

1. saropa_lints runs as a **standalone Dart process** with its own LSP server
2. The VS Code extension **spawns and manages** the LSP process (like it already
   manages the scan daemon)
3. Diagnostics (squiggles), quick fixes, and code actions appear in the
   **same Problems panel and editor gutter** as Dart analyzer diagnostics
4. The `analysis_server_plugin` entry point (`lib/main.dart`) is **removed** —
   no rules run inside the Dart analysis server process
5. Memory footprint is **saropa's own** — separate process, separately
   attributable, independently manageable
6. Users install via the VS Code extension only — no `plugins:` entry in
   `analysis_options.yaml` required (though config is still read from there)

## Architecture comparison

### Current (in-process plugin + scan daemon)

```
[Dart Analysis Server — 6-8 GB RSS]
  ├── Analyzer core (resolved element model)
  └── saropa_lints plugin (~200 light-lane rules, in-process)

[Scan Daemon — ~1 GB RSS, separate process]
  ├── Own AnalysisContextCollection
  └── ~2,100 full-lane rules (NDJSON protocol, save-triggered)

[VS Code Extension]
  ├── Listens to analyzer diagnostics (in-process rules)
  ├── Spawns/manages scan daemon
  └── DiagnosticCollection for daemon findings
```

### Target (standalone LSP server)

```
[Dart Analysis Server — 6-8 GB RSS]
  └── Analyzer core only (no saropa plugin)

[Saropa LSP Server — estimated 300-500 MB RSS]
  ├── Own AnalysisContextCollection + resolved element model
  ├── ALL 2,343 rules (no lane split needed)
  ├── LSP textDocument/publishDiagnostics
  ├── LSP textDocument/codeAction (quick fixes)
  └── Watches files for changes (continuous, not save-only)

[VS Code Extension]
  ├── LanguageClient connected to Saropa LSP
  └── Diagnostics merge into Problems panel automatically
```

### Why this should use LESS memory than the current model

- **Eliminates duplication.** Today: analyzer process (6-8 GB) + scan daemon
  (~1 GB) + in-process plugin overhead = 7-9 GB total Dart memory. Target:
  analyzer process (6-8 GB, unchanged) + saropa LSP (~300-500 MB) = 6.3-8.5 GB.
  Net savings: the scan daemon's ~1 GB + plugin overhead.
- **Independent lifecycle.** Saropa LSP can be stopped/restarted without
  touching the analysis server. Memory pressure → kill saropa LSP → instant
  recovery. Today killing the scan daemon still leaves the in-process plugin.
- **DCM precedent.** DCM dropped from 4 GB to 350 MB on the Flame repo with
  this exact architecture. saropa_lints has more rules but similar AST access
  patterns.

## Key technical decisions

### D1: LSP server implementation

**Options:**
- (a) Use `package:lsp_server` / `package:analysis_server` LSP primitives
- (b) Use `package:lsp4dart` or similar community LSP framework
- (c) Hand-roll LSP JSON-RPC over stdin/stdout (like the scan daemon, but LSP)

**Recommendation:** (c) — the scan daemon already has the process management,
stdin/stdout I/O, and error handling patterns. LSP is JSON-RPC 2.0 over
stdin/stdout with a `Content-Length` header framing. The protocol surface we
need is small:
- `initialize` / `initialized` / `shutdown` / `exit`
- `textDocument/didOpen` / `didChange` / `didClose` / `didSave`
- `textDocument/publishDiagnostics` (server → client)
- `textDocument/codeAction` (client → server, for quick fixes)

This is ~200 lines of protocol framing on top of the analysis infrastructure
we already have.

**Decision:** TBD — needs prototyping to validate complexity.

### D2: Analysis strategy

**Options:**
- (a) Full `AnalysisContextCollection` (like scan daemon) — resolved types
- (b) `parseString` only (like light lane) — no type resolution
- (c) Hybrid: parse for fast initial pass, resolve on demand or in background

**Recommendation:** (a) — the whole point is to run ALL rules including
type-resolution rules. The scan daemon already does this. The memory cost is
the `AnalysisContextCollection`, which DCM benchmarks suggest is 300-500 MB
for large projects (much less than the full analysis server because we don't
need the analysis server's incremental resolution cache, code completion
indexes, navigation indexes, etc.).

**Decision:** TBD.

### D3: File watching and incremental analysis

**Options:**
- (a) Re-analyze on save only (like scan daemon today)
- (b) Re-analyze on every keystroke (like the Dart analyzer)
- (c) Re-analyze on save + debounced re-analyze on change (compromise)

**Recommendation:** (c) — save triggers immediate full analysis of the file;
content changes trigger a debounced (500ms) re-analysis so squiggles update
as you type, but not on every keystroke. The LSP `textDocument/didChange`
event provides the file content, so no disk I/O needed.

**Decision:** TBD.

### D4: Quick fix delivery

**Options:**
- (a) Compute fixes eagerly during analysis (cache per diagnostic)
- (b) Compute fixes lazily on `textDocument/codeAction` request
- (c) Register fix generators, compute on codeAction, cache for 5s

**Recommendation:** (b) or (c) — eager computation wastes CPU for fixes the
user never requests. The existing `SaropaFixGenerator` infrastructure already
supports lazy computation; we just need to map the analyzer's `ChangeBuilder`
output to LSP `TextEdit` arrays.

**Decision:** TBD.

### D5: Configuration

The LSP server still reads `analysis_options.yaml` / `analysis_options_custom.yaml`
for tier selection, rule_packs, diagnostics overrides, and severity config.
No change to user-facing config. The only change: `plugins: saropa_lints:` is
no longer needed (the extension spawns the server directly).

### D6: Extension lifecycle management

The extension already manages:
- `ScanDaemonManager` — spawn, crash detection, exponential backoff, teardown
- `ProcessMonitor` — RSS tracking, orphan detection, health classification

The LSP server replaces the scan daemon. Same lifecycle patterns, but the
extension uses `vscode.LanguageClient` (from `vscode-languageclient` npm
package) instead of raw `child_process.spawn` + NDJSON parsing. The
`LanguageClient` handles LSP framing, reconnection, and diagnostic routing
automatically.

## Migration phases

### Phase 0 — Fake LSP plumbing test (opt-in, zero risk) ✓ IMPLEMENTED

**Goal:** Prove the VS Code extension can spawn a second LSP server for Dart
files and that its diagnostics merge into the same Problems panel alongside the
Dart analyzer's diagnostics. No real analysis, no rules, no
`AnalysisContextCollection`. Just: does the plumbing work?

**Implementation status:** Code complete (commits `157e3c4e`, `67ed0562`,
`38968fe9`). Test diagnostics removed after shipping default-on bug (`1ef3b058`).
Setting now defaults to `false`. Locale catalogs regenerated (`93734f21`).

**BLOCKER — server crash loop (2026-09-03):** The inert LSP server crashes
during initialization or shortly after. VS Code's `LanguageClient` retries 5
times then gives up with "Server initialization failed" / "will not be
restarted." This violates the Phase 0 exit criterion that the server coexist
without interference. Root causes to investigate:

1. **Unhandled notifications in switch default.** `textDocument/didChange`,
   `$/cancelRequest`, `$/setTrace`, `workspace/didChangeConfiguration` arrive
   as notifications (no `id`). The default case calls `_sendError(id, ...)`
   with `id == null` — sending an error response to a notification violates
   JSON-RPC 2.0 and may crash `LanguageClient`.
2. **`dart pub get` needed.** After removing code from `bin/lsp_server.dart`,
   the server may fail to compile if the pub cache is stale.
3. **Init handshake incomplete.** The `initialize` response must include all
   fields `LanguageClient` expects. A missing or malformed capability may
   cause the client to reject the handshake.

**Fix approach:** Add all common notification methods as silent no-ops in the
switch. For unknown methods without an `id` (notifications), log and ignore
instead of sending an error. Run `dart pub get` before testing. Verify the
`initialize` response satisfies `LanguageClient` expectations.

**Lesson learned — default-on shipping incident:** `lspServer.enabled`
shipped as `true` in 15.2.10, causing fake test diagnostics on every `.dart`
file for all users. Hard rule going forward: **every new engine/feature
defaults to OFF until its exit criteria are fully verified in a manual test.**

**Control surface — extension Debug Panel:**

The extension gets a **Debug / Diagnostics** panel (sidebar section or
webview, gated behind `saropaLints.debug.enabled` setting, default: true).
This is the master control for both diagnostic engines:

```
┌─────────────────────────────────────────────┐
│  Saropa Lints — Debug Panel                 │
├─────────────────────────────────────────────┤
│                                             │
│  Diagnostic Engines                         │
│  ─────────────────                          │
│  ● Analyzer Plugin    [ON]  [OFF]  (pid: —) │
│    Status: active via analysis_options.yaml  │
│    RSS: — (in-process, not separately       │
│         measurable)                         │
│                                             │
│  ● Scan Daemon        [ON]  [OFF]  (pid: —) │
│    Status: idle / running / suspended       │
│    RSS: 1.02 GB                             │
│                                             │
│  ● LSP Server         [ON]  [OFF]  (pid: —) │
│    Status: stopped / starting / ready       │
│    Rules: 4 fake (test mode)                │
│    RSS: 12 MB                               │
│                                             │
│  ─────────────────                          │
│  [Kill All]  [Restart All]                  │
│                                             │
│  Log                                        │
│  ─────────────────                          │
│  12:03:01  LSP server started (pid 14320)   │
│  12:03:01  LSP initialize handshake OK      │
│  12:03:02  Published 4 diagnostics for      │
│            main.dart                        │
│  12:03:05  Scan daemon suspended (memory    │
│            pressure level 2)                │
│                                             │
└─────────────────────────────────────────────┘
```

**Toggle behavior:**

| Engine | ON | OFF |
|--------|-----|------|
| **Analyzer Plugin** | Ensures `plugins: saropa_lints:` in `analysis_options.yaml`, triggers analysis server restart | Removes `plugins: saropa_lints:` from `analysis_options.yaml`, triggers analysis server restart |
| **Scan Daemon** | Spawns daemon (normal behavior) | Kills daemon, sets `_daemonSuspended = true` |
| **LSP Server** | Spawns `dart run saropa_lints:lsp_server`, connects `LanguageClient` | Stops `LanguageClient`, kills process, clears its diagnostics |

Each toggle takes effect **immediately** — no VS Code restart needed (except
Analyzer Plugin, which requires an analysis server restart; the extension
triggers this via `dart.restartAnalysisServer` command).

**Settings:**
- `saropaLints.debug.enabled` (boolean, default: true) — shows the Debug
  Panel in the sidebar. When false, the panel is hidden and the LSP server
  is never spawned. No overhead.
- `saropaLints.lspServer.enabled` (boolean, default: false) — persisted
  independently from the debug panel. Off by default (opt-in during Phase 0).
  When the debug panel is hidden, this setting still controls whether the
  LSP server runs (for headless/CI use or for users who just want to flip
  a setting without the full debug UI).

**Commands (command palette):**
- `Saropa Lints: Toggle Debug Panel`
- `Saropa Lints: Start LSP Server`
- `Saropa Lints: Stop LSP Server`
- `Saropa Lints: Restart LSP Server`

**Parallel operation — all combinations valid:**

| Analyzer Plugin | Scan Daemon | LSP Server | Result |
|-----------------|-------------|------------|--------|
| ON | ON | OFF | **Today's behavior.** Light lane in-process + full lane in daemon. |
| ON | ON | ON | **All three.** Duplicate diagnostics expected from plugin + LSP — useful for comparison testing. |
| OFF | OFF | ON | **LSP-only.** Target end state. Only the standalone LSP server delivers diagnostics. |
| ON | OFF | ON | **Plugin + LSP, no daemon.** Light lane in-process + LSP for everything. Comparison without daemon overhead. |
| OFF | OFF | OFF | **Nothing.** No saropa diagnostics in editor (CLI `scan` still works). |
| _(any other combination)_ | | | All valid — each engine is independent. |

The three engines share no state, no IPC, no coordination. Independent
processes, independent diagnostic streams, one Problems panel. Turning one
off doesn't affect the others.

**Deliverables:**

1. **`bin/lsp_server.dart`** — minimal fake LSP server (~100 lines):
   - Handles `initialize` → responds with server capabilities
     (`textDocumentSync`, `codeActionProvider`)
   - Handles `initialized` → no-op
   - On `textDocument/didOpen` and `textDocument/didSave`:
     - Publishes FOUR fake diagnostics on the opened file, one per LSP
       severity level, each on a different line (lines 1-4, or fewer if
       file is shorter), each with a distinct source code:
       - **Error** (severity 1): `saropa-lsp-test-error` —
         `"[saropa_lsp_test] Error-level diagnostic — proves red squiggles
         from standalone LSP"`
       - **Warning** (severity 2): `saropa-lsp-test-warning` —
         `"[saropa_lsp_test] Warning-level diagnostic — proves yellow
         squiggles from standalone LSP"`
       - **Information** (severity 3): `saropa-lsp-test-info` —
         `"[saropa_lsp_test] Info-level diagnostic — proves blue squiggles
         from standalone LSP"`
       - **Hint** (severity 4): `saropa-lsp-test-hint` —
         `"[saropa_lsp_test] Hint-level diagnostic — proves hint squiggles
         from standalone LSP"`
     - Each diagnostic spans the full text of its target line (not just
       col 1) so the squiggle underline is visible
     - Each diagnostic has a corresponding `codeAction` quick fix:
       `"Dismiss this test <severity> diagnostic"` — the fix inserts a
       `// saropa_lsp_test: <severity> dismissed` comment at end of the
       line (proves TextEdit round-trip works for all severity levels)
   - On `textDocument/didClose` → clears all diagnostics for that file
   - Handles `shutdown` / `exit` gracefully
   - Logs lifecycle events to stderr (extension captures in Output channel)

2. **Extension: `SaropaLspClient`** (new file):
   - On activation, checks `saropaLints.lspServer.enabled` setting
   - If true: spawns `dart run saropa_lints:lsp_server` via `LanguageClient`
     (from `vscode-languageclient` npm package)
   - `documentSelector: [{ scheme: 'file', language: 'dart' }]`
   - Exposes `start()`, `stop()`, `restart()` methods for Debug Panel toggles
   - Logs lifecycle events to the `Saropa Lints LSP` Output channel

3. **Extension: Debug Panel** (new file, sidebar webview):
   - Gated behind `saropaLints.debug.enabled` setting (default: true)
   - Shows status + toggle for all three engines (Analyzer Plugin, Scan
     Daemon, LSP Server) — see mockup above
   - Live log tail from all three engines
   - Kill All / Restart All buttons

4. **Extension: `package.json`** — new settings:
   - `saropaLints.debug.enabled` (boolean, default: true)
   - `saropaLints.lspServer.enabled` (boolean, default: true)
   - New commands: toggle debug panel, start/stop/restart LSP server

**Exit criteria (updated 2026-09-03):**

Phase 0 test diagnostics have been removed (proven: 3 of 4 severity levels
confirmed working 2026-09-03). Remaining exit criteria focus on stability:

- **Crash-free coexistence (BLOCKER).** Enable `saropaLints.lspServer.enabled`
  → LSP server starts, completes init handshake, stays alive indefinitely
  with zero crashes. VS Code must never show "Server initialization failed"
  or "will not be restarted." The server handles all notifications
  (`textDocument/didChange`, `$/cancelRequest`, `$/setTrace`,
  `workspace/didChangeConfiguration`, etc.) as silent no-ops without sending
  error responses.
- Debug Panel shows all three engines with correct status and toggle buttons
- Toggle LSP Server OFF in Debug Panel → server stops cleanly
- Toggle LSP Server ON → server restarts without VS Code restart
- Disable `saropaLints.lspServer.enabled` in settings → no LSP server,
  zero overhead
- `Saropa Lints LSP` appears in Output channel dropdown
- Reload window → no orphaned dart.exe in Task Manager

**What Phase 0 proved (test diagnostics, now removed):**
- VS Code allows two LSP servers to serve the same `language: 'dart'`
- Diagnostics from both servers merge in the Problems panel without conflict
- 3 of 4 severity levels render distinct squiggle styles (hint untested —
  test files had <4 lines)
- `LanguageClient` lifecycle (spawn, shutdown) works
- No interference with the Dart extension's own LanguageClient

**What Phase 0 has NOT yet proven (crash blocker):**
- `LanguageClient` crash recovery — server currently crashes on init
- Long-running stability — server must stay alive through an editing session

**What this does NOT prove (deferred to Phase 1):**
- Real analysis performance or memory footprint
- Rule registration / diagnostic reporting through `SaropaLintRule`
- `AnalysisContextCollection` memory cost
- Config loading or tier/pack filtering

**Implementation notes (2026-09-02):**
- `SPAWN_USE_SHELL` added to LSP server spawn for Windows `dart.bat` PATHEXT
- Diagnostic source `saropa_lsp_test` with filter in `liveDiagnosticsModel.ts`
  (prevents fake diagnostics from affecting the status bar score)
- `LSP_TEST_DIAGNOSTIC_SOURCE` constant extracted in TS; cross-language sync
  test (`test/integrity/lsp_source_string_sync_test.dart`) ensures Dart and
  TS source strings stay aligned
- `SaropaLspClient` constructor pushes itself to `context.subscriptions`
  (once per instance — do NOT also push from call sites)
- `engine.status` is a machine key (not translated); translation happens at
  display time in `debugPanel-html.ts` via `l10n('debug.engine.statusValue.${engine.status}')`
- Kill All / Restart All log strings routed through `l10n()`
- All new en.json keys regenerated across 24 locales via Qwen

**Risk:** `LanguageClient` might conflict with the Dart extension's own
`LanguageClient`. Mitigation: use a different `documentSelector` scheme
or output channel name. If conflict occurs, this is exactly what Phase 0
exists to discover — and the opt-in gate means zero blast radius.

### Phase 1 — Full rule registration in LSP server

**Goal:** Run all 2,343 rules in the LSP server.

**Deliverables:**
- Port `registerSaropaLintRules` to work with the LSP server's analysis context
  (may need adapter from `PluginRegistry` to direct rule invocation)
- Config loading from `analysis_options.yaml` (tier, packs, diagnostics)
- All fix generators wired to `codeAction`
- Memory profiling: RSS with all rules on large project
- Benchmark: time-to-first-diagnostic after file open

**Exit criteria:**
- All rules that fire in the current plugin also fire in the LSP server
- Quick fixes work for all 289 fix generators
- RSS < 1 GB on a 500-file Flutter project (stretch: < 500 MB)

### Phase 2 — Extension integration

**Goal:** Replace scan daemon with LSP server in the extension.

**Deliverables:**
- `SaropaLanguageClient` replaces `ScanDaemonManager` + `ScanDaemonClient`
- `ProcessMonitor` updated to track LSP server process (not scan daemon)
- Status bar, health panel, cleanup command updated for new process type
- Orphan detection for LSP server processes
- Memory pressure: stop/restart LSP server instead of daemon suspension
- Config change detection: restart LSP server on `analysis_options.yaml` change
- Remove scan-on-save fallback (LSP provides continuous diagnostics)

**Exit criteria:**
- Extension spawns LSP server on activation
- Diagnostics appear in real time (not just on save)
- Process health monitoring works for LSP server
- Memory pressure → LSP server killed → recovery on pressure drop

### Phase 3 — Remove in-process plugin

**Goal:** Eliminate the `analysis_server_plugin` entry point entirely.

**Deliverables:**
- Remove `lib/main.dart` plugin entry point (or make it a no-op that logs
  "saropa_lints now runs via the VS Code extension's LSP server")
- Update documentation: remove `plugins:` instructions from README, guides
- Migration guide for users: "remove `plugins: saropa_lints:` from
  `analysis_options.yaml`; install/update VS Code extension"
- Deprecation period: one major version where `lib/main.dart` logs a warning
  before removal

**Exit criteria:**
- No saropa_lints code runs inside the Dart analysis server process
- Users see diagnostics only through the extension's LSP server
- `dart analyze` from CLI still works (no saropa diagnostics, but that's
  expected — CLI users use `dart run saropa_lints scan` instead)

### Phase 4 — Optimize and harden

**Goal:** Production-quality LSP server.

**Deliverables:**
- Incremental analysis (re-analyze only changed files + dependents)
- Workspace/monorepo support (multiple project roots)
- Concurrent file analysis (don't block on one large file)
- Graceful degradation under memory pressure (shed rules like today, but
  in the LSP server process)
- Telemetry: analysis time, rule hit rates, memory usage over time
- Edge cases: file rename/delete, project structure change, SDK upgrade

**Exit criteria:**
- P95 time-to-diagnostic < 2s after file save on 500-file project
- Stable RSS over 8-hour editing session (no leaks)
- Correct behavior on monorepo with 3+ package roots

## What this does NOT change

- **Rule implementation.** `SaropaLintRule`, `SaropaDiagnosticReporter`,
  `SaropaFixGenerator` — all unchanged. Rules don't know or care whether
  they're running in-process or in the LSP server.
- **User configuration.** `analysis_options.yaml`, `analysis_options_custom.yaml`,
  tiers, rule_packs, diagnostics overrides — all read the same way.
- **CLI tools.** `dart run saropa_lints scan`, `dart run saropa_lints:init`,
  `dart run saropa_lints:project_health` — all unchanged.
- **pub.dev package.** saropa_lints is still published to pub.dev. Users who
  don't use VS Code get the CLI tools. The `plugins:` entry becomes optional
  (for non-VS Code editors that support analyzer plugins).

## What this DOES change

- **VS Code extension becomes required** for IDE diagnostics (today the
  analyzer plugin works without the extension, just with `plugins:` config)
- **Non-VS Code editors** (IntelliJ, Android Studio, Neovim) would need their
  own LSP client integration — or a generic LSP client plugin. This is a
  significant reach reduction unless we ship editor-agnostic LSP setup docs.
- **CI diagnostics** — `dart analyze` no longer includes saropa rules.
  `dart run saropa_lints scan` is the CI equivalent (already exists and works).

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Two LSP servers conflict on same language | Diagnostics lost or duplicated | Test with Dart extension; LSP spec allows multiple servers per language |
| RSS higher than expected | No memory improvement | Phase 0 spike measures before committing; DCM precedent suggests 300-500 MB |
| Type resolution slower in standalone process | Slow diagnostics | Benchmark in Phase 0; scan daemon already does this and is acceptable |
| Non-VS Code editor users lose diagnostics | User complaints | Keep `plugins:` entry as deprecated fallback for 1 major version; document `scan` CLI for CI |
| Quick fix mapping complex | Delayed Phase 1 | Prototype 1 fix in Phase 0 to validate the ChangeBuilder → TextEdit path |
| `LanguageClient` npm package version conflicts with Dart extension | Extension won't activate | Pin compatible version; test with latest Dart extension |
| analyzer 12 → 13 migration intersects | Double the work | Independent concern — LSP server uses same analyzer version as today |

## Effort estimate

| Phase | Estimate | Dependencies |
|-------|----------|--------------|
| Phase 0 (spike) | 2-3 days | None |
| Phase 1 (full rules) | 1-2 weeks | Phase 0 validates approach |
| Phase 2 (extension) | 1-2 weeks | Phase 1 |
| Phase 3 (remove plugin) | 2-3 days | Phase 2 stable for 1+ release |
| Phase 4 (optimize) | 2-4 weeks | Phase 3 |

**Total:** 5-10 weeks, with Phase 0 as the go/no-go gate.

## Prior art

- **DCM** — standalone binary, own LSP, 350 MB on Flame repo. Proprietary.
- **dart_code_metrics** (old, open source) — ran as analyzer plugin, discontinued
  2023. Replaced by DCM's standalone architecture.
- **rust-analyzer** — standalone LSP server, separate from rustc. Same pattern.
- **typescript-language-server** — wraps tsserver as LSP. Similar wrapping model.

## Open questions

1. **IntelliJ / Android Studio support.** These editors use the Dart analysis
   server's plugin system directly. Moving to LSP means IntelliJ users need a
   generic LSP client plugin (e.g. `lsp4ij`). Is this acceptable?
2. **Dual-mode transition.** Should we support BOTH modes (plugin + LSP) during
   transition? Or clean break at a major version?
3. **Compilation target.** DCM ships a compiled native binary (AOT). Should we
   do the same, or keep `dart run saropa_lints:lsp_server`? AOT = faster startup,
   no SDK dependency at runtime, but more complex CI/CD (per-platform binaries).
4. **Licensing.** DCM is proprietary. Is there any IP concern with adopting the
   same architecture pattern? (Almost certainly no — "standalone LSP server" is
   a standard architecture, not proprietary.)

---

_Phase 0 is the decision gate. If the spike shows RSS < 500 MB and diagnostics
coexist cleanly with the Dart analyzer, proceed. If not, revisit._
