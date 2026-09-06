# BUG: Translation engine force-kills Ollama without killing its child, orphaning multi-GB llama-server processes

**Status: Fixed**

Created: 2026-09-05
Rule: N/A (infrastructure — extension translation tooling)
File: `extension/scripts/i18n/qwen_engine.py`
Severity: Critical (exhausts system commit memory; observed crashing VS Code)

---

## Summary

The Qwen translation engine starts and force-kills the Ollama daemon, but every
kill path targets `ollama.exe` alone. Ollama's actual model host is a separate
`llama-server.exe` child process holding the whole model in committed memory.
`taskkill /F` without `/T` does not terminate a process tree, so the child
survives its parent and is never reaped by anything.

Each orphan holds 9-16 GB of committed memory indefinitely. They accumulate
across runs.

---

## Attribution Evidence

Three orphaned `llama-server.exe` processes were found on the development
machine on 2026-09-05 at 19:20, holding 37 GB of committed memory between them,
with their parent PIDs already gone. All three accumulated within a single
uptime session: the machine booted 2026-09-03 at 19:50 and was next restarted
2026-09-05 at 19:45, after these processes had been terminated. No process
survived a restart; they simply were never reaped during a long uptime.

| PID | Committed | Started | Parallel setting |
|---|---|---|---|
| 28040 | 15.8 GB | 2026-09-03 21:14 | `-np 6` |
| 10672 | 11.5 GB | 2026-09-05 01:08 | `-np 1` |
| 31532 | 9.5 GB | 2026-09-05 11:41 | `-np 1` |

Two of the three carry `-np 1`, which matches this engine's
`OLLAMA_NUM_PARALLEL=1` (`qwen_engine.py:263`). The third carries `-np 6` and
came from a different caller or an Ollama default. All three had a working set
of approximately zero, meaning the memory was entirely paged out — the machine
had been paying for them for the rest of that uptime session, up to 46 hours in
the case of the oldest.

Windows logged event 2004, "low virtual memory", roughly 40 times across that
uptime session, naming these three processes as the top consumers on every
occurrence. VS Code renderer, GPU, and extension-host processes crashed at
12:33, 13:39, 14:20 and 19:08 on 2026-09-05, and the desktop compositor
`dwm.exe` crashed alongside them at 12:33. Killing the three orphans returned
pagefile usage from 18.7 GB to 7.6 GB.

A later VS Code crash at 22:18, after the 19:45 restart, was NOT caused by this
defect — no model host was running by then. That crash has a separate and
unrelated root cause, recorded in
`plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md`.

## Root Cause

```
qwen_engine.py:301  _kill_all_ollama()  ->  taskkill /IM ollama.exe /F
qwen_engine.py:345  targeted kill       ->  taskkill /PID <daemon> /F
```

Neither passes `/T`, so neither reaches `llama-server.exe`. The POSIX branches
have the same shape: `pkill -f "ollama serve"` and `kill -9 <pid>` both leave
the child running.

Three further factors compound it:

1. `qwen_engine.py:271` launches the daemon with Windows creation flags
   `DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP`, so the daemon is fully
   detached from the script and nothing ties its lifetime to the run.
2. `qwen_engine.py:389` kills a "rival" daemon on a port conflict and retries,
   which is an additional path to orphaning a child that was mid-load.
3. `qwen_engine.py:525` sends `keep_alive: "30m"`, so even a correctly parented
   model stays resident for half an hour after the last translation call.

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Killing the daemon terminates its model host. A run leaves no process behind. |
| **Actual** | The model host survives every kill path, holds 9-16 GB of commit indefinitely, and accumulates one orphan per affected run. |

## Suggested Fix

1. Use tree termination everywhere: `taskkill /PID <pid> /T /F` and
   `taskkill /IM ollama.exe /T /F` on Windows; kill the process group on POSIX.
2. Sweep for surviving `llama-server.exe` processes after the daemon is
   confirmed down, and terminate any whose parent no longer exists. This is the
   only reliable backstop, because a daemon that died some other way leaves the
   same orphan.
3. Prefer graceful shutdown before `/F`. A force kill is what strands the child.
4. Reconsider `keep_alive: "30m"` for a batch job. The run knows when it has
   finished translating; an explicit unload at the end is cheaper than leaving
   a model resident for thirty minutes.
5. Add a preflight check that refuses to start when orphaned `llama-server.exe`
   processes are already present, reporting their memory, so the condition is
   surfaced rather than silently compounded.

## Resolution (2026-09-05)

All five suggested fixes landed in `extension/scripts/i18n/qwen_engine.py`. The
defect was confined to that file: `nllb_engine.py` runs an in-process model and
only shells out to `pip`, and `generate_locales.py` spawns nothing at all.

1. **Tree termination everywhere.** `_terminate_tree()` replaces every kill
   path. Windows uses `taskkill /PID n /T` then `/T /F`; POSIX signals the
   process group (the daemon leads one via `start_new_session=True`).
2. **Orphan sweep.** `find_orphan_model_hosts()` snapshots the process table
   and returns model hosts whose parent PID is no longer live;
   `sweep_orphan_model_hosts()` terminates them after the daemon is down. A
   host with a live parent is never touched, and a failed snapshot returns
   `None` so "could not look" can never be read as "nothing to kill".
3. **Graceful before force.** `ollama stop <model>` and an explicit unload run
   first; the force kill is only reached after the polite one demonstrably
   failed.
4. **`keep_alive` cut from 30m to 5m** (`SAROPA_QWEN_KEEP_ALIVE` overrides), and
   `shutdown_engine()` — registered with `atexit` the moment the run adopts a
   daemon — unloads the model explicitly at the end of the run.
5. **Preflight.** `preflight_orphan_check()` refuses to start when orphans are
   already present and reports their committed memory. Reaping pre-existing
   orphans is opt-in via `SAROPA_QWEN_REAP_ORPHANS=1`.

Safety changes that came with it:

- The machine-wide `taskkill /IM ollama.exe` / `pkill -f "ollama serve"` path is
  now opt-in (`SAROPA_QWEN_ALLOW_GLOBAL_KILL=1`) and never a side effect of a
  normal run. Killing a daemon that another client was serving from is what
  caused this incident.
- Teardown only ever touches a daemon this run started (`_adopt_daemon`); a
  pre-existing daemon is left completely alone, including its model.
- `python extension/scripts/i18n/qwen_engine.py` now prints a read-only orphan
  report, replacing the manual PowerShell check below.

Verified by `extension/scripts/i18n/tests/test_qwen_process_hygiene.py` (25
tests, all mocked at the OS boundary — no process is ever started or killed).
Runtime behavior against a real Ollama daemon is **unverified**; the pipeline
was deliberately not run.

## Operational Note

Until this is fixed, check for orphans after any translation run:

```
Get-Process llama-server | Select Id,StartTime,@{n='CommitGB';e={[math]::Round($_.PagedMemorySize64/1GB,1)}}
```

Any entry older than the current Ollama session is a leak and can be killed.

## Related

- `plans/history/2026.09/2026.09.05/infra_drift_poll_opens_every_dart_file_triggers_full_project_scan.md`
  — the separate extension defect that crashed VS Code on the same day, after
  the orphans had been cleared and the machine rebooted.
