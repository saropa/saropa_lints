# Analysis: The RSS valve is measuring the wrong thing

Created: 2026-09-05

---

## What happened

VS Code status bar showed `Rules paused (8425 MB)`. User investigated. The
native analyzer plugin (`plugins:` block) is **commented out** in
`analysis_options.yaml` — saropa_lints is not loaded, not running, not
consuming memory. The 8425 MB figure is stale data from a previous session,
displayed by the extension reading an old `memory_state.json`.

VS Code then crashed. The crash has nothing to do with saropa_lints.

---

## Two separate bugs

### Bug 1: Extension displays stale state when the plugin isn't running

Filed: `infra_extension_shows_stale_memory_state_when_plugin_disabled.md`

The extension reads `memory_state.json` and renders the status bar without
checking whether the plugin is actually loaded. A file written days ago by a
now-disabled plugin still drives the UI. Fix: check file mtime against session
start, or check whether `plugins:` is active, or require a heartbeat.

### Bug 2: Even when the plugin IS running, the valve measures the wrong thing

Filed: `infra_hard_rss_valve_penalizes_plugin_for_server_memory.md`

This is the deeper design problem. The rest of this document explains it.

---

## What the valve does today

```
ProcessInfo.currentRss  →  entire analysis server process RSS
         ↓
  crosses adaptive cap (60% of system RAM, clamped 2048–8192 MB)
         ↓
  MemoryPressureHandler._hardLimitTripped = true
         ↓
  every saropa_lints rule callback becomes a no-op
         ↓
  plugin clears its own caches (relieve(clearAll: true))
```

## Why this is wrong

`ProcessInfo.currentRss` is the **process-wide** resident set size. The
saropa_lints plugin runs **inside** the Dart analysis server process as a
native analyzer plugin. It shares the heap with:

- The analysis server's resolved element model
- AST node caches for every file in the project
- Cross-library type resolution graphs
- Other analyzer plugins (if any)
- The Dart VM runtime itself

On a large project (1500+ Dart files), the analysis server's own data
structures consume **6–8 GB** before the plugin even starts executing rules.
The plugin's own caches (`_estimateMemoryUsageMb`) are typically **tens of MB**.

```
┌─────────────────────────────────────────────────┐
│           Analysis server process (8425 MB)      │
│                                                   │
│  ┌─────────────────────────────────────────┐     │
│  │  Analysis server own data    ~8300 MB   │     │
│  │  (resolved elements, AST, types)        │     │
│  └─────────────────────────────────────────┘     │
│                                                   │
│  ┌──────────────────┐                             │
│  │ saropa_lints      │                             │
│  │ caches  ~50 MB    │                             │
│  └──────────────────┘                             │
│                                                   │
│  ┌──────────────┐                                 │
│  │ Dart VM  ~75 MB│                               │
│  └──────────────┘                                 │
└─────────────────────────────────────────────────┘
         ↑
    ProcessInfo.currentRss reads THIS number
```

The plugin sees 8425 MB, concludes it is causing a memory problem, pauses all
its rules, and clears its 50 MB of caches. The server's 8300 MB is untouched.
The pause accomplishes nothing — RSS does not drop meaningfully. The user
loses all lint diagnostics for zero benefit.

## What the valve SHOULD do

The plugin should only pause when **its own memory** is the problem. It
already has `_estimateMemoryUsageMb()` which tracks plugin-owned cache sizes.
That should be the primary signal.

Process-wide RSS is useful only as a last-resort OOM guard — and even then,
the threshold should be much higher (e.g. 90% of physical RAM), because at
8 GB of 16 GB the system is not in danger of OOM. The analysis server being
large is the analysis server's problem, not the plugin's.

## What saropa_lints should NOT claim

The valve's stderr message says:

> `[saropa_lints] Memory guard tripped: RSS 8425MB >= 8192MB cap.`
> `Pausing rule execution to protect the analysis server.`

This implies saropa_lints is protecting the server from itself. It is not.
The plugin is 0.6% of that RSS. Pausing rules does not protect anything — it
just removes lint coverage. The message should not claim a protective role it
cannot fulfill.

## Recommendation

1. **Primary valve:** trip on `_estimateMemoryUsageMb()` exceeding a
   plugin-specific cap (e.g. 500 MB). This catches runaway plugin caches.
2. **Last-resort valve:** trip on process RSS exceeding 90% of physical RAM.
   This is a genuine OOM guard, not a plugin-attribution claim.
3. **Remove the 60% adaptive cap.** It fires in normal operation on any large
   project and delivers no benefit.
4. **Fix the extension** to not display stale state when the plugin is off.

---

## Outcome (2026-09-05)

This document is an analysis, not a defect, so it carries no status field. Its
substance is resolved and it is archived for the reasoning, which remains the
best explanation of why the valve is shaped as it is.

Both bugs it filed are fixed and archived:

- Bug 1, the extension rendering stale state, is fixed. State is published only
  when the plugin is enrolled in `analysis_options.yaml` and the reading came
  from the current session. Either check failing renders nothing.
  See `infra_extension_shows_stale_memory_state_when_plugin_disabled.md`.
- Bug 2, the valve measuring the wrong thing, is fixed. Attribution gates the
  pause, with an unconditional panic threshold above it.
  See `infra_hard_rss_valve_penalizes_plugin_for_server_memory.md`.

Three further defects were found by review of that attribution fix before it
shipped, and are also fixed: the bystander state re-walked every cache on every
sample, a legitimate trip could never release because clearing the plugin's
caches made it a bystander while release tested process RSS alone, and the
physical-memory probe re-spawned a subprocess on every call after a failed
detection. See
`infra_rss_valve_attribution_leaves_rules_paused_and_rescans_caches.md`.

### Recommendation 3 was not implemented, and is now moot

The document recommended removing the 60% adaptive cap outright, on the grounds
that it fires during normal operation on any large project and delivers no
benefit. The cap still exists, at 60% of physical RAM clamped to 2048-8192 MB
(`project_context_throttle_memory.dart:2105-2130`).

Removing it became unnecessary rather than being rejected. The complaint was
never the threshold itself but what crossing it caused: an unconditional pause
of every rule. With attribution in place, crossing the cap pauses rules only
when the plugin is actually responsible for the memory, so the cap now selects
when to *ask* the attribution question rather than deciding the outcome. Left
in place it is a cheap trigger; removed, the attribution check would need some
other trigger of its own.

Recommendations 1, 2 and 4 all landed as written.
