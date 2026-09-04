# Plan: LSP Server — Remove In-Process Plugin & Harden (Phase 3-4)

**Status:** Not started
**Created:** 2026-09-04
**Predecessor:** `plans/history/2026.09/2026.09.04/PLAN_lsp_server_migration.md`
  (Phases 0-2 — standalone LSP server design, fake-diagnostic spike, full rule
  registration, extension integration — all shipped, BETA default-on)
**Audience:** maintainers planning the remaining LSP server work

## Where things actually stand (2026-09-04)

The predecessor plan's Phase 0-2 deliverables are shipped, per `CHANGELOG.md`:

- Standalone LSP server (`bin/lsp_server.dart`) runs all rules with a real
  `AnalysisContextCollection`, not the Phase 0 fake diagnostics
- `saropaLints.lspServer.enabled` defaults to `true` (BETA) — the analyzer
  plugin is **automatically disabled** when the LSP server is on
  (`disablePluginsIntegration()` / `restorePluginsIntegration()`)
- Full workspace scan on startup, with in-memory incremental re-scan
  (mtime-based, this-server-lifetime-only — see Gotchas)
- Quick fixes via `textDocument/codeAction`, wired to the same
  `SaropaFixProducer` infrastructure the plugin uses
- Per-rule config overrides (`analysis_options.yaml` diagnostics section,
  `analysis_options_custom.yaml` severities section) layered on tier
- Live config reload on `workspace/didChangeConfiguration`
- Debug/Health panel shows all three engines (Analyzer Plugin, Scan Daemon,
  LSP Server) with working toggles

**What has NOT shipped** — this is the actual remaining scope, corrected
against the original Phase 3/4 lists (some of which were written before
Phase 1/2 landed and are now partially or fully overtaken by what shipped):

## Phase 3 — Remove the in-process plugin

**Goal:** Eliminate `analysis_server_plugin` as a code path entirely. Today
the LSP server auto-disables the plugin at runtime (toggling
`saropaLints.enabled`/`plugins:` in the user's config), but the plugin entry
point (`lib/main.dart`) and its full registration/execution path still exist
and are still the fallback when a user turns the LSP server off.

**Why this is still open:** the LSP server is BETA and default-on, but
turning it off must currently fall back to a working analyzer plugin — that
fallback is why Phase 3 hasn't been able to start. Removing the plugin is a
one-way door: once `lib/main.dart` is gone, the LSP server is the *only*
diagnostic path, so this phase can't begin until the LSP server has proven
itself stable enough that the fallback is no longer needed as a safety net.

**Deliverables (unchanged from the original plan, still all pending):**
- Remove `lib/main.dart` plugin entry point, or make it a no-op that logs
  "saropa_lints now runs via the VS Code extension's LSP server"
- Update README/docs/guides to remove `plugins: saropa_lints:` instructions
- Migration guide: "remove `plugins: saropa_lints:` from
  `analysis_options.yaml`; install/update the VS Code extension"
- Deprecation period: one major version where `lib/main.dart` logs a warning
  before removal

**Exit criteria:**
- No saropa_lints code runs inside the Dart analysis server process
- Users see diagnostics only through the extension's LSP server
- `dart analyze` from the CLI still works (no saropa diagnostics — expected;
  `dart run saropa_lints scan` is the documented CLI/CI equivalent)

**Gate before starting:** the LSP server needs a stretch of BETA usage with
no P0/P1 bugs (crash loops, missed diagnostics, wrong quick fixes) before
pulling the analyzer-plugin safety net. This is a product/release decision,
not an engineering one — track it separately from the code work below.

## Phase 4 — Optimize and harden

**Goal:** production-quality LSP server. Several items on the original list
are now partially done; this section reflects what's actually left.

| Original deliverable | Current state | Remaining work |
|---|---|---|
| Incremental analysis (re-analyze only changed files + dependents) | **Partially shipped.** In-memory mtime cache skips unchanged files on re-scan, but only within one server process lifetime — every server restart is a full scan, and there's no dependent-file tracking (changing a shared base class doesn't re-analyze its subclasses). | Persist the mtime cache (or a content hash) across restarts; add a dependency graph so changing a file re-triggers analysis of files that import it, not just the file itself. |
| Workspace/monorepo support (multiple project roots) | **Not started.** `saropaLints.lspServer.scanDirectories` lets a user point at specific directories, but there's no multi-root-workspace awareness (VS Code's `workspaceFolders`) or per-root config (different tiers/pubspecs per package). | Wire `workspaceFolders` from the `initialize` request; one `AnalysisContextCollection` (or config resolution) per root. |
| Concurrent file analysis (don't block on one large file) | **Not started.** The workspace scan loop and per-file didSave/didOpen analysis appear to run sequentially in the current implementation (needs confirmation — see verification step below). | Profile first; only add concurrency if a real large-file/large-workspace stall is measured, not preemptively. |
| Graceful degradation under memory pressure (shed rules in-process, like the plugin does today) | **Not started.** The LSP server has no analog to the plugin's `RuntimeTierCap`/memory-pressure rule shedding. | Decide whether this is even needed — the whole premise of moving to a standalone process was that it uses far less RAM (~300-500 MB target vs 6-8 GB), so this may turn out to be unnecessary. Measure actual RSS on a large real project before designing this. |
| Telemetry: analysis time, rule hit rates, memory usage over time | **Not started.** | Low priority — revisit if/when a performance complaint needs data to diagnose. |
| Edge cases: file rename/delete, project structure change, SDK upgrade | **Not started / unverified.** | Needs a manual test pass — see verification list below. |

**New item not in the original plan, discovered this cycle:**
- The 5000-file workspace-scan cap (`bin/lsp_server.dart`, added
  2026-09-04) is an unbenchmarked guess. Before relying on it for real
  monorepos, measure actual scan time/memory at various file counts and
  adjust the constant if needed.

**Exit criteria (unchanged from original):**
- P95 time-to-diagnostic < 2s after file save on a 500-file project
- Stable RSS over an 8-hour editing session (no leaks)
- Correct behavior on a monorepo with 3+ package roots

## Suggested order of attack

1. **Measure before building.** RSS on a real large project, workspace-scan
   timing, whether concurrent analysis is actually needed — several Phase 4
   items above are speculative until measured. Don't build memory-pressure
   shedding or concurrency until a number proves it's needed.
2. **Persist the incremental-scan cache** (small, contained change, clear
   payoff: faster restarts).
3. **Multi-root workspace support** (clear scope, needed for any monorepo
   user of the LSP server today gets a single-root scan only).
4. **Edge-case verification pass** (file rename/delete, SDK upgrade) — mostly
   testing, not new code; do this alongside whichever phase is in flight.
5. **Phase 3 (remove the plugin)** only after a BETA stability track record —
   this is a release-management decision, revisit once Phase 4's measurable
   items are in a known-good state.

## How to verify current LSP server behavior before starting new work

- `saropaLints.lspServer.enabled: true` in a real Dart project → confirm
  Problems panel populates for files never opened in the editor (workspace
  scan)
- Edit a per-rule override in `analysis_options.yaml` while the LSP server
  is running → confirm `workspace scan: N unchanged files skipped
  (incremental)` appears in the Output channel on the next scan
- Rename/delete a Dart file with the LSP server running → confirm stale
  diagnostics for the old path are cleared (not currently verified either
  way)
