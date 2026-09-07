# Analysis: Flutter dev-machine stability, AI extensions, and translation-engine hygiene

Filed 2026-09-06. Web research across four threads (Dart analysis server, VS Code + AI
extensions, Ollama/NLLB process hygiene, Flutter tooling sprawl), prompted by the
memory-crash investigation in [`docs/handover/20260906_0016_memory_crashes_and_scan_cascade.md`](../docs/handover/20260906_0016_memory_crashes_and_scan_cascade.md)
and the ongoing fixes to `qwen_engine.py` / `project_context_throttle_memory.dart` /
`memoryPressureWatcher.ts`. Every claim below is sourced; no claim here is acted on yet —
this is a survey to decide what's worth doing next, not a plan.

## Why this matters right now

The crash pattern this session investigated — VS Code going unresponsive or Crashpad-dumping
under Windows Event 2004 ("low virtual memory") — is not one bug. It's the overlap of four
independently-known-bad actors on the same 32 GB machine: the Dart analysis server, Flutter's
daemon sprawl, at least one AI coding extension, and (specific to this project) a
translation-engine script that mismanages an Ollama daemon. Each is a documented, still-open
class of problem upstream. None of them will be fixed by upstream maintainers on any
timeline we can rely on.

---

## 1. Dart analysis server memory

Analysis-server memory blowups are a recurring, multi-year complaint, not a single bug:

- 19 GB usage, closed as `type-performance` — [dart-lang/sdk#52447](https://github.com/dart-lang/sdk/issues/52447)
- Excessive memory with no open projects — [dart-lang/sdk#52808](https://github.com/dart-lang/sdk/issues/52808)
- "analysis_server has memory leaks", 2.3 GB just opening `package:flutter` — [dart-lang/sdk#48875](https://github.com/dart-lang/sdk/issues/48875)
- Feature request to auto-kill/restart the server past a memory threshold (proposed 8 GB
  default or % of physical RAM), still open — [dart-lang/sdk#48876](https://github.com/dart-lang/sdk/issues/48876)
- `dart.exe` eating all memory, ~150 MB/sec growth reported — [dart-lang/sdk#40243](https://github.com/dart-lang/sdk/issues/40243)
- Too many lints enabled inflates memory — [dart-lang/sdk#41793](https://github.com/dart-lang/sdk/issues/41793)
- Analyzer plugins should be auto-terminated past 5 GB/CPU-seconds, still open — [dart-lang/sdk#48654](https://github.com/dart-lang/sdk/issues/48654)
- 18-package workspace analyzed 4.4x slower than the sum of its parts — [dart-lang/sdk#62704](https://github.com/dart-lang/sdk/issues/62704)

**Settings that exist:**
- `dart.analyzerVmAdditionalArgs` — VM flags for the server process (this is where
  `--old_gen_heap_size=6144`, seen live on this machine, comes from).
- `dart.analyzerAdditionalArgs` — analysis-server protocol flags, not VM flags.
- There is **no** `dart.analysisServerMemory` setting, and no flag that forces a GC on demand.
- `dart.analysisExcludedFolders` and `analyzer.exclude` in `analysis_options.yaml` are the
  confirmed-effective mitigations ([#62704](https://github.com/dart-lang/sdk/issues/62704)).
- `dart.onlyAnalyzeProjectsWithOpenFiles` exists but Dart-Code's own docs warn it makes
  navigation performance "significantly worse" — do not enable it.

**Plugin cost:** old `custom_lint` ran each plugin in its own isolate/process;
`dart_code_metrics` alone was reported using >10 GB
([Very Good Ventures](https://verygood.ventures/blog/creating-your-first-dart-analyzer-plugin-with-the-new-plugin-system/)).
The newer in-process `analysis_server_plugin` (Dart 3.10+/Flutter 3.38+,
[dart.dev/tools/analyzer-plugins](https://dart.dev/tools/analyzer-plugins)) still runs each
plugin in a separate isolate inside the server process — lower IPC overhead, but isolates
still don't share heap, so a runaway plugin still balloons the parent's RSS. The 5 GB
auto-kill ask ([#48654](https://github.com/dart-lang/sdk/issues/48654)) has not shipped.

**One item resolved locally, not by research:** the initial handover flagged
`dartaotruntime.exe` at 4 GB as unidentified. Checking this machine directly during this
session found no `dartaotruntime.exe` process at that size at the time of checking — the
4.1 GB figure in the earlier screenshot was a snapshot-in-time; `dart.exe` running
`language-server` with `--old_gen_heap_size=6144` was independently confirmed at 2.6 GB.
`dartaotruntime.exe` is the generic AOT-snapshot runtime
([dart.dev/tools/dartaotruntime](https://dart.dev/tools/dartaotruntime)) — whichever Dart
tool (DevTools, Dart Tooling Daemon, a `flutter_tools` snapshot) was AOT-compiled runs under
that binary name, so a live command-line capture is needed each time to attribute it, not a
one-time answer.

---

## 2. VS Code + AI coding extensions

**Claude Code (Anthropic) extension specifically** — filed against `anthropics/claude-code`,
2025-2026:
- Per-session leak: closed session tabs don't release their child process/heap, ~400 MB
  accumulates per session until VS Code restarts — [#16508](https://github.com/anthropics/claude-code/issues/16508)
- 11.6 GB per conversation window (macOS, v2.1.20) — [#21182](https://github.com/anthropics/claude-code/issues/21182)
- 58 GB RAM / OOM-killed after ~2 hours (Linux) — [#27946](https://github.com/anthropics/claude-code/issues/27946);
  23 GB / 143% CPU after 14 hours — [#11377](https://github.com/anthropics/claude-code/issues/11377)
- 2 GB+ heap-out-of-memory crashes — [#23071](https://github.com/anthropics/claude-code/issues/23071)
- Multiple agent panels going gray/unresponsive simultaneously, unrecoverable — [#38994](https://github.com/anthropics/claude-code/issues/38994)
- Windows ARM64: crashes every 1-2 min, exit code 3, extension host killed by VS Code's own
  watchdog — [#27820](https://github.com/anthropics/claude-code/issues/27820)

The extension spawns the same `cli.js` agentic-loop binary as the terminal CLI, per session,
as its own Node child process — not a thin client to a shared daemon
([architecture writeup](https://medium.com/@sujaypawar/how-claude-code-actually-works-1f6d4f1eea82)).
This explains why its memory growth is large and session-scoped rather than bounded by VS
Code's own extension-host budget.

**Other AI extensions, same class of symptom:**
- **Copilot Chat**: extension-host process 100 MB → 2 GB+, JS heap OOM. Root cause: a
  dependency (`source-map-support`) caching source maps indefinitely on every thrown error,
  **shared across every extension in that host** — a bug in Copilot degraded all
  co-located extensions until rolled back
  ([microsoft/vscode#255571](https://github.com/microsoft/vscode/issues/255571)).
- **Cursor**: extension-host processes at ~4 GB each with sustained ~100% CPU
  ([forum#151614](https://forum.cursor.com/t/cursor-causing-extremely-high-cpu-and-memory-usage-extension-host-processes/151614));
  22 GB across dozens of helper processes
  ([forum#158844](https://forum.cursor.com/t/cursor-consuming-22-gb-ram-across-dozens-of-helper-processes-ide-becomes-extremely-slow/158844)).

**Isolation mechanism that exists today:** `extensions.experimental.affinity` pins a named
extension ID to its own dedicated extension-host process, so its crash/leak doesn't take
down co-located extensions — but only for `ExtensionHostKind.LocalProcess`, not
remote/WSL/container hosts
([vscode-remote-release#9199](https://github.com/microsoft/vscode-remote-release/issues/9199)).

**Crash mechanics on Windows:** "extension host terminated unexpectedly" crash logs pair
`Allocation failed - JavaScript heap out of memory` with `crashpad_client_win.cc` in the
stack — Crashpad catching a V8 OOM abort in the extension-host renderer
([microsoft/vscode#107950](https://github.com/microsoft/vscode/issues/107950),
[#266349](https://github.com/microsoft/vscode/issues/266349)). There is **no** documented
equivalent of `typescript.tsserver.maxTsServerMemory` for the extension host's own V8 heap.

**Diagnosis tools:** "Developer: Show Running Extensions" measures activation latency, not
memory. **Help → Open Process Explorer** is the actual per-process memory/CPU attribution
tool and should be the first thing opened when the status bar or Task Manager shows an
unattributed spike.

---

## 3. Ollama / NLLB translation-engine hygiene

This directly informs the just-shipped `qwen_engine.py` fixes and flags one gap they don't
close.

**Confirmed root cause, matching this project's exact incident:** `ollama serve` launches
`llama-server`/`ollama_llama_server.exe` per loaded model as an independent `exec.Cmd` with
its own lifecycle timer, not tightly bound to the parent's process tree
([llm/server.go](https://github.com/ollama/ollama/blob/main/llm/server.go)). Killing the
parent does not reliably kill the runner — confirmed by real-world reports of exactly this
pattern, including "5-6 orphan processes" as a known recurrence, not a one-off
([writeup](https://dev.to/bashsnippets/i-was-killing-ollama-processes-the-hard-way-for-months-a-one-word-command-fixed-it-3f0i),
[ollama/ollama#14761](https://github.com/ollama/ollama/issues/14761)).

**Correct release mechanisms** (all from
[docs.ollama.com/faq](https://docs.ollama.com/faq)): `keep_alive: 0` per-request or
`ollama stop <model>` unloads immediately; `OLLAMA_MAX_LOADED_MODELS` caps concurrent
residency; `GET /api/ps` shows what's actually loaded. **The 30-minute `keep_alive` this
project's script used is irrelevant to the crash** — `keep_alive` is an idle-unload timer,
not an exit hook, and does nothing once the parent has already died and orphaned the runner.

**Gap the current fix doesn't close:** `qwen_engine.py`'s tree-kill (`_terminate_tree`,
landed this session) uses `os.killpg`/bare `os.kill` — best-effort, and only works if the
script survives long enough to run its own cleanup path. The dependable OS-level guarantee
on Windows is a **Job Object with `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`**: assign the daemon
(and everything it spawns) to the job at creation; when the job handle closes — including on
the Python script's own crash — Windows kills every process still in the job, independent of
whether any Python exception handler ever ran
([Job Objects](https://learn.microsoft.com/nl-nl/windows/win32/procthread/job-objects),
[background](https://nikhilism.com/post/2017/windows-job-objects-process-tree-management/)).
`atexit`/`signal` handlers are documented as unreliable for console-close and forced
termination on Windows — third-party packages (`safe-exit`, `pyterminate`) exist specifically
because they aren't sufficient alone.

**Should the script even own the daemon?** Better default: probe
`http://localhost:11434/api/version` first; if a daemon answers (including a
Windows-tray-managed one, which itself respawns a killed `ollama.exe`), use it and never
adopt or tear it down. Only spawn when genuinely absent. This project's own fix (commit
`3479eee6`, confirmed-dead-parent required before reaping, foreign daemon used but never
adopted) already matches this recommendation in spirit.

**Model size / quantization:** Q4_K_M is roughly half the RSS of Q8_0 for the same parameter
count at the "sweet spot" of the accuracy/size/speed tradeoff
([cheat sheet](https://computingforgeeks.com/ollama-models-cheat-sheet/)) — a direct lever to
shrink per-orphan blast radius independent of the process-hygiene fix.

**NLLB:** CTranslate2 int8 quantization cuts memory 2-4x versus raw `transformers`/`torch`
([model cards](https://huggingface.co/OpenNMT/nllb-200-distilled-1.3B-ct2-int8)) — this
project's memory already flags Qwen as the target engine over NLLB
([`project_i18n_mt_engine` / `reference_qwen_upgrade_path`], internal memory), so this is
confirmation, not new direction. In-process `del model; gc.collect()` does not guarantee OS
reclaim; a short-lived subprocess per translation batch is more deterministic — process exit
is the only release mechanism no leaked C++/CUDA context can defeat.

---

## 4. Flutter tooling process sprawl

**Process inventory and typical footprint** (per real sessions cited in research):
`dart language-server` (the analysis server, ~593 MB baseline, spikes far higher — see §1),
`dart tooling-daemon --machine` (~59 MB), `dart devtools --machine` (~65 MB), the Flutter
daemon (`flutter_tools` snapshot under `dartaotruntime.exe`), `build_runner watch` (if left
running in watch mode), `dart run custom_lint` (server + one isolate per plugin package,
runaway plugins reported at 10+ GB — [#48654](https://github.com/dart-lang/sdk/issues/48654)),
and `frontend_server.dart.snapshot` (the hot-reload kernel compiler, scales with app size).

**Orphaned-daemon issues, still open across years, tied to abnormal termination:**
[Dart-Code#5155](https://github.com/Dart-Code/Dart-Code/issues/5155) (Flutter daemon
survives IDE close), [#2223](https://github.com/Dart-Code/Dart-Code/issues/2223) (orphan
sleeping `dart` processes on Linux), [#1140](https://github.com/Dart-Code/Dart-Code/issues/1140)
(test-runner processes not terminated), [#5216](https://github.com/Dart-Code/Dart-Code/issues/5216)
(Flutter daemon orphaned again). Pattern: reproduction ties to concurrent sessions, stuck
debug sessions, or a force-closed IDE — the same "abnormal exit orphans a child" shape as the
Ollama incident, just inside Dart-Code's own tooling.

**Confirmed: Dart-Code/`flutter_tools` do not use Windows Job Objects.** Killing a parent
process on Windows does not kill its children (bash wrappers, `dart run`) — this is the
opposite of macOS/Linux process-group kill behavior
([flutter/flutter#98435](https://github.com/flutter/flutter/issues/98435),
[dart-lang/sdk#55219](https://github.com/dart-lang/sdk/issues/55219)). One
`google/process.dart` issue explicitly proposes a Job Object as the fix
([process.dart#42](https://github.com/google/process.dart/issues/42)) — a known, proposed,
not-yet-shipped remedy. This is the same gap identified independently in §3 for the
translation engine; it is a Windows-wide pattern in this toolchain, not specific to any one
script.

**Settings that reduce footprint:** `dart.openDevTools: "never"` (though one report says it
doesn't always suppress the DevTools server —
[Dart-Code#3619](https://github.com/Dart-Code/Dart-Code/issues/3619)),
`dart.flutterHotReloadOnSave: "never"` (avoids extra `frontend_server` recompiles per save),
`dart.showTodos: false` (trims analyzer scanning). No setting fully disables the Flutter
daemon when not running an app — it starts on-demand per debug session.

**Monorepo practice:** Dart 3.6+ pub workspaces give one shared analysis context instead of
one server per package — a real memory win
([dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces)) — but with at least
one documented severe regression case on an 18-package workspace after an SDK bump
([#62704](https://github.com/dart-lang/sdk/issues/62704)). Not a pure win; measure before/after
if this project ever consolidates into a workspace.

**Cross-ecosystem comparison — what a more mature tool looks like:** JetBrains IDEs expose an
explicit per-language-service UI toggle ("Automatically increase memory, if available" vs.
"Set memory limit") plus a global IDE heap setting
([RustRover docs](https://www.jetbrains.com/help/rust/language-services.html)) — a first-class
memory cap surfaced in settings UI, not an env var buried in docs. TypeScript's
`typescript.tsserver.maxTsServerMemory` does the same for `tsserver`
([vscode#82630](https://github.com/microsoft/vscode/pull/82630)). Dart has neither. Neither
does rust-analyzer, which is reported at 40+ GB on large workspaces with "no knob to tune
down" ([rust-analyzer#18127](https://github.com/rust-lang/rust-analyzer/issues/18127)) — so
this is an industry-wide gap in language servers generally, not a Dart-specific failing.

---

## Cross-cutting pattern

Every one of the four areas researched shares the same two failure shapes:

1. **A daemon/child process outlives the thing that spawned it**, because Windows has no
   default parent-death propagation and none of these tools (Ollama, `flutter_tools`,
   Dart-Code) uses the OS mechanism that would guarantee it (Job Objects with
   `KILL_ON_JOB_CLOSE`). This project's own `qwen_engine.py` fix this session addressed the
   symptom (tree-kill, orphan sweep) but not the root cause (no Job Object) — see §3.
2. **No language-server-class tool in this stack has a first-class memory cap.** Dart's
   `--old_gen_heap_size` is a VM flag buried in an "additional args" setting, not a UI toggle;
   rust-analyzer has none at all; only JetBrains and TypeScript's `tsserver` expose this
   properly. `project_context_throttle_memory.dart` in this project is, notably, already this
   project's own attempt to build exactly that missing capability for the plugin's own memory
   — the exponential-backoff fix landed this session is directly in this tradition.

## What this suggests, without committing to any of it

- The Job Object gap (§3, §4) is real and affects both the translation engine and, in
  principle, any long-running child process this project's tooling spawns on Windows. Whether
  it's worth adding `pywin32`/`ctypes` Job Object support to `qwen_engine.py` specifically
  (vs. relying on the tree-kill already shipped) is a cost/benefit call: Job Objects close the
  "script itself crashes before cleanup runs" case that tree-kill cannot.
- `extensions.experimental.affinity` (§2) is a user-side VS Code setting, not something this
  project ships — but worth knowing about for personal dev-machine hygiene independent of any
  code change here.
- Nothing here implies saropa_lints' own memory valve is miscalibrated; if anything, the
  research confirms the general shape of what it's already doing (attribute to self, back off
  under sustained pressure) is the right instinct where upstream tools (Dart analyzer,
  rust-analyzer) have no equivalent.

## Sources

All URLs are inlined above at first mention of each claim; no source is cited without a
direct claim attached to it.
