# BUG: Plugin session restart loop clears diagnostics from Problems tab

**Status: Investigating**

Created: 2026-07-24
Rule: N/A (infrastructure — affects all rules)
File: `lib/src/native/plugin_logger.dart` (session header, line ~116), `lib/main.dart` (register log, line ~115)
Severity: Critical
Rule version: N/A | Since: unknown (log data goes back to 2026-04-24) | Updated: N/A

---

## Summary

The Dart analysis server respawns the saropa_lints plugin isolate hundreds of
times per day. Each respawn causes the analysis server to invalidate all
diagnostics from the previous isolate, clearing them from the VS Code Problems
tab. The user sees real issues flash into the Problems tab and vanish before they
can be read or copied. The plugin log (`reports/.saropa_lints/plugin.log`) records
**13,660 isolate respawns** over 91 days (2026-04-24 to 2026-07-24), with bursts
of 50+ respawns in under 2 minutes.

---

## Attribution Evidence

This is an infrastructure bug in the plugin session lifecycle, not a specific lint
rule. The "session started" log line is emitted by the plugin itself.

```
grep -c "session started" reports/.saropa_lints/plugin.log
# 13,660
```

The session start is logged in `lib/src/native/plugin_logger.dart:116`. The
`Plugin.register()` call (which re-registers all 2,329 rules with the analyzer)
is logged in `lib/main.dart:115` and fires on a subset of these restarts:

```
grep -c "Plugin.register" reports/.saropa_lints/plugin.log
# 2,963
```

---

## Reproducer

Open the `contacts` project in VS Code and wait. The plugin log shows the restart
loop within minutes. No specific user action triggers it — it happens during
normal editing and also while idle.

**Observed burst (2026-07-24, today):**

53 isolate respawns between 14:05:54 and 14:07:20 (86 seconds). Each respawn
loads config and re-registers rules; the analysis server invalidates all
previously emitted diagnostics from the prior isolate.

```
2026-07-24T14:05:54 | --- saropa_lints plugin session started ---
2026-07-24T14:05:56 | --- saropa_lints plugin session started ---
2026-07-24T14:05:57 | --- saropa_lints plugin session started ---
2026-07-24T14:05:58 | --- saropa_lints plugin session started ---
2026-07-24T14:05:59 | --- saropa_lints plugin session started ---
2026-07-24T14:06:00 | --- saropa_lints plugin session started ---
2026-07-24T14:06:01 | --- saropa_lints plugin session started ---
2026-07-24T14:06:03 | --- saropa_lints plugin session started ---
2026-07-24T14:06:04 | --- saropa_lints plugin session started ---  (x2)
2026-07-24T14:06:05 | --- saropa_lints plugin session started ---  (x2)
2026-07-24T14:06:07 | --- saropa_lints plugin session started ---  (x2)
2026-07-24T14:06:08 | --- saropa_lints plugin session started ---
2026-07-24T14:06:10 | --- saropa_lints plugin session started ---
2026-07-24T14:06:11 | --- saropa_lints plugin session started ---  (x2)
2026-07-24T14:06:14 | --- saropa_lints plugin session started ---
2026-07-24T14:06:16 | --- saropa_lints plugin session started ---
2026-07-24T14:06:24 | --- saropa_lints plugin session started ---
2026-07-24T14:06:28 | --- saropa_lints plugin session started ---
2026-07-24T14:06:29 | --- saropa_lints plugin session started ---
2026-07-24T14:06:31 | --- saropa_lints plugin session started ---
2026-07-24T14:06:34 | --- saropa_lints plugin session started ---
2026-07-24T14:07:20 | --- saropa_lints plugin session started ---
```

**Frequency:** Always. Every single day in the log shows this pattern.

Worst days by restart count:

| Date | Restarts |
|------|----------|
| 2026-07-10 | 1,077 |
| 2026-06-22 | 819 |
| 2026-07-11 | 710 |
| 2026-07-21 | 576 |
| 2026-07-04 | 437 |

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Plugin isolate starts once per analyzer lifecycle. Diagnostics persist in the Problems tab until the file is re-analyzed or the analyzer restarts. User can read and copy issues. |
| **Actual** | Analysis server respawns the plugin isolate hundreds of times per day, invalidating all plugin diagnostics each time. Issues flash and vanish in the Problems tab faster than the user can interact with them. |

---

## Secondary symptom: wrong working directory

On some restarts, the plugin initializes with `C:\Users\craig\AppData\Local\Programs\Microsoft VS Code` as its working directory instead of the project root. This causes it to find 0 rules, then eventually reload from the correct path:

```
2026-07-24T14:53:16 | analysis_options.yaml not found at
    C:\Users\craig\AppData\Local\Programs\Microsoft VS Code
    — saropa_lints will not enable any rules until config is reloaded
    from the project root.
2026-07-24T14:53:16 | Runtime tier cap: essential (from default in-process cap)
2026-07-24T14:53:16 | Config loaded from
    C:\Users\craig\AppData\Local\Programs\Microsoft VS Code — enabledRules: 0
2026-07-24T14:55:19 | Config loaded from D:/src/contacts — enabledRules: 1131
```

This pattern occurs **1,636 times** in the log. It means the plugin goes through
a 0-rules phase (clearing any previous diagnostics) before re-loading the real
config, doubling the disruption per restart.

---

## Impact on downstream projects

The `contacts` project (`D:\src\contacts`) is the affected downstream consumer.
The user reports:

1. **Issues appear in the VS Code Problems tab and disappear before they can be
   copied.** This makes it impossible to act on saropa_lints diagnostics during
   normal development.

2. **The "Saropa Lints" output tab shows "38686 issues found"** but this count
   is from the standard Dart analyzer's output (captured alongside saropa_lints
   output), not from saropa_lints rules. The saropa_lints report itself shows
   0 issues — because with constant restarts, only 1-3 files get analyzed per
   session before the next restart clears the state.

3. **The saropa_lints report says "Files analyzed: 3"** on a 3,600-file project.
   The incremental analysis never completes before the session restarts.

---

## Root Cause

Investigated in the plugin source. The lifecycle is:

1. The analysis server spawns a plugin isolate and calls `Plugin.start()`
   ([lib/main.dart:50](lib/main.dart#L50)), which loads config from
   `Directory.current` (often the VS Code install dir, not the project root).
2. The server calls `Plugin.register()` ([lib/main.dart:114](lib/main.dart#L114)),
   registering all enabled rules.
3. On the first analyzed file, `SaropaContext._ensureConfigLoadedFromProjectRoot()`
   ([lib/src/native/saropa_context.dart:335](lib/src/native/saropa_context.dart#L335))
   derives the real project root and calls `PluginLogger.setProjectRoot()`, which
   writes the "session started" header and flushes buffered log entries.
4. `loadNativePluginConfigFromProjectRoot()` reloads config from the real root.

**Each "session started" entry = one fresh isolate spawn.** The logger's
`setProjectRoot` has an idempotency guard (`if (_logFilePath != null) return` at
[plugin_logger.dart:99](lib/src/native/plugin_logger.dart#L99)) so it fires
exactly once per isolate. 13,660 entries over 91 days = 13,660 isolate spawns.

**The plugin does NOT clear diagnostics.** No code in this repo calls any
diagnostic-clearing API. The analysis server itself invalidates diagnostics from
a plugin when it tears down and replaces that plugin's isolate — this is standard
`analysis_server_plugin` behavior, not something the plugin controls.

### Hypothesis A: Analyzer isolate churn (most likely)

The analysis server recycles plugin isolates on events such as `pubspec.yaml`
changes, `analysis_options.yaml` changes, package resolution changes, and
(on large projects) internal resource-management decisions. On a 3,600-file
project, the isolate recycling rate is far higher than on a small project.

**Check:** Correlate `%LOCALAPPDATA%\.dartServer\logs\` timestamps with the
plugin.log "session started" timestamps. If they match, the trigger is the
analysis server, not the plugin.

### Hypothesis B: Plugin log write triggers file-watcher restart loop (likely primary cause)

The plugin writes to `reports/.saropa_lints/plugin.log` — a file typically
outside the analysis scope (under `reports/`, not `lib/` or `test/`). Config
loading reads `analysis_options.yaml` and `analysis_options_custom.yaml` but
does not write to them. No feedback loop is possible through file writes.

**However:** if `reports/` is NOT excluded from the analyzer's file watcher,
appending to `plugin.log` on every startup could trigger a "workspace file
changed" event in the analysis server, which could restart the isolate. This
would create exactly the storm seen in the logs.

**CONFIRMED:** `D:\src\contacts\analysis_options.yaml` does NOT exclude
`reports/` or `reports/.saropa_lints/`. The exclude list covers generated code,
build output, `.dart_tool/**`, `scripts/**`, and test coverage — but not
`reports/**`. Every log write to `reports/.saropa_lints/plugin.log` is visible
to the analysis server's file watcher.

This is the most likely feedback loop: isolate starts → `setProjectRoot` writes
"session started" to `plugin.log` → file watcher sees the change → analysis
server restarts the plugin isolate → new isolate starts → writes "session
started" again → loop. The ~1-2 second interval between restarts in the burst
log matches the latency of a file-watcher debounce + isolate spawn cycle.

### Hypothesis C: Multiple analyzer contexts (confirmed partial)

The wrong-working-directory entries (1,636 occurrences) prove the analysis
server creates at least one context where `Directory.current` is the VS Code
install dir. Each such context spawns a plugin isolate that loads 0 rules,
then eventually gets the real root on the first analyzed file.

**Check:** Count distinct working directories in "Config loaded from" lines
to see how many contexts are being created.

---

## Suggested Fix

### Investigation steps (before code changes)

1. **DONE — Consumer's `analysis_options.yaml` does NOT exclude `reports/`.**
   The plugin's own log writes are visible to the analyzer's file watcher.
   Adding `reports/**` to the consumer's exclude list is the cheapest test —
   if the restart storm stops, Hypothesis B is confirmed as the primary cause.

2. **Correlate with analysis server logs.** Compare
   `%LOCALAPPDATA%\.dartServer\logs\` timestamps with plugin.log "session
   started" timestamps to confirm whether every restart is server-initiated.

3. **Count distinct working directories** in the log's "Config loaded from"
   lines to determine how many analyzer contexts are spawned.

### Possible mitigations (code changes)

1. **Guard `Plugin.start()` against non-project cwd.** In
   [lib/main.dart:50](lib/main.dart#L50), check for `pubspec.yaml` in
   `Directory.current` before calling `loadNativePluginConfig()`. When cwd is
   not a Dart project (VS Code install dir), skip config loading entirely —
   the real config will be loaded from the project root on the first analyzed
   file via `SaropaContext._ensureConfigLoadedFromProjectRoot()`. This
   eliminates the 0-rules phase and its log noise (1,636 occurrences).

2. **Suppress log file writes until the project root is confirmed.** The
   `PluginLogger` buffer mechanism already exists — extend it so the "session
   started" header is only written when the root is a valid Dart project
   (has `pubspec.yaml`). This prevents log writes into non-project directories
   and reduces potential file-watcher triggers.

3. **Move log file outside the project tree.** Write to
   `%LOCALAPPDATA%\.saropa_lints\<project-hash>\plugin.log` instead of
   `<projectRoot>/reports/.saropa_lints/plugin.log`. This eliminates any
   possibility of log writes triggering analyzer file-watcher events.

4. **Add `reports/**` to the `init` command's generated excludes.** The init
   runner ([lib/src/init/init_runner.dart](lib/src/init/init_runner.dart)) does
   not add `reports/**` to the consumer's `analyzer > exclude` list. Since the
   plugin writes to `reports/.saropa_lints/`, this directory should be excluded
   by default to prevent file-watcher-triggered isolate restarts.

Note: debouncing session restarts and preserving diagnostics across restarts are
NOT feasible at the plugin level. The analysis server controls isolate lifecycle
and diagnostic invalidation — the plugin cannot prevent either.

---

## Fixture Gap

N/A — this is a session lifecycle issue, not a rule detection issue.

---

## Changes Made

### File 1: `lib/src/native/plugin_logger.dart` (line ~101)

Added `pubspec.yaml` existence check in `setProjectRoot()`. Rejects non-Dart-project
roots (e.g. VS Code install dir) before writing the session header or flushing
buffered log entries.

### File 2: `lib/main.dart` (line ~60)

Added `pubspec.yaml` check in `Plugin.start()` before calling
`loadNativePluginConfig()`. When cwd is not a Dart project, skips config loading
entirely — the real config loads lazily from the project root on the first
analyzed file. Also calls `markNativePluginStarted()` unconditionally so the
essential-tier default still applies on the lazy reload.

### File 3: `lib/src/native/config_loader.dart` (line ~62)

Added `markNativePluginStarted()` — public setter for the `_nativePluginStarted`
flag, called from `Plugin.start()` before the cwd check so the essential-tier
default is preserved even when the initial config load is skipped.

### File 4: `lib/saropa_lints.dart` (line ~121)

Exported `markNativePluginStarted` from `config_loader.dart`.

### File 5: `lib/src/init/config_writer.dart` (line ~283)

Added `ensureNonDartExcludes()` — ensures common non-Dart directories
(`reports/**`, `docs/**`, `bugs/**`, `plans/**`, `doc/**`, `output/**`,
`tmp/**`) are in the `analyzer > exclude` list. Hardened to detect and skip
flow-style `exclude: [...]` (avoids inserting a duplicate YAML key) and to
handle trailing comments after `exclude:`.

### File 6: `lib/src/init/init_runner.dart` (line ~560)

Wired `ensureNonDartExcludes()` into the init runner, called after writing the
config file.

### File 7: `lib/src/init/write_config_runner.dart` (line ~198)

Wired `ensureNonDartExcludes()` into the headless config writer (used by the
VS Code extension).

### File 8: `lib/src/native/plugin_logger.dart` (line ~160)

Added `_checkRestartRate()` — after writing the session header, reads the
existing log file and counts "session started" entries in the last 10 minutes.
When the count exceeds 10, emits a `WARNING` line with remediation advice.
The log file itself is the durable counter since statics reset per isolate.

Session header string extracted to `_sessionHeader` constant, shared between
the writer (`setProjectRoot`) and reader (`_checkRestartRate`).

Added `_rotateIfNeeded()` — caps `plugin.log` at 512 KB by discarding the
oldest bytes at each isolate start. Uses byte-level I/O so the cap is
measured in actual bytes, not Dart string code units. Cuts at newline
boundaries; truncates entirely when no newline exists (single huge line).

---

## Tests Added

- `test/native/plugin_logger_test.dart` — 14 tests (7 new: restart-rate
  warning above/below threshold, all-old-entries case, corrupted log file,
  log rotation above cap, single-huge-line truncation; 1 existing:
  pubspec.yaml rejection; 4 updated for pubspec.yaml in temp dirs)
- `test/init/ensure_non_dart_excludes_test.dart` — 11 tests (5 new:
  flow-style YAML guard, trailing comment, flow-style under non-analyzer
  key, flow-style after blank line in analyzer section)

---

## Commits

See git log for this branch.

---

## Related

- [infra_native_plugin_analysis_server_memory_growth_10gb.md](plans/history/2026.06/2026.06.28/infra_native_plugin_analysis_server_memory_growth_10gb.md) — Fixed in 14.3.0.
  May share a root cause (excessive isolate churn → memory growth).
- [infra_native_plugin_full_tier_runs_on_files_in_flux.md](plans/history/2026.07/2026.07.10/infra_native_plugin_full_tier_runs_on_files_in_flux.md) — Fixed in 14.3.2.
  Rapid-edit gate was dead code; related to per-file re-analysis triggers.

---

## Environment

- saropa_lints version: 14.3.7
- Dart SDK version: 3.12.2 (stable)
- Plugin API: native `analysis_server_plugin` (not custom_lint)
- VS Code: installed at `C:\Users\craig\AppData\Local\Programs\Microsoft VS Code`
- Triggering project: `D:\src\contacts` (~3,600 Dart files under `lib/`)
- OS: Windows 11 Pro 10.0.22631
- Log file: `D:\src\contacts\reports\.saropa_lints\plugin.log` (41,003 lines, 3.6 MB)
