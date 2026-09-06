# BUG: VS Code extension shows stale "Rules paused" when plugin is disabled

**Status: Open**

Created: 2026-09-05
Rule: N/A (infrastructure — VS Code extension status bar)
File: extension source (status bar rendering / `memory_state.json` reader)
Severity: High

---

## Summary

When the saropa_lints native analyzer plugin is disabled (both `plugins:` blocks
commented out in `analysis_options.yaml`), the VS Code extension still displays
`Rules paused (8425 MB)` in the status bar. The extension is reading a stale
`memory_state.json` file written by a previous session when the plugin WAS
enabled. The file persists on disk and the extension does not check whether the
plugin is actually loaded before displaying its contents.

This is misleading — it suggests the plugin is actively running and paused, when
in fact it is not loaded at all.

---

## Reproducer

1. Enable saropa_lints native plugin in `analysis_options.yaml`.
2. Open a large project — let the plugin trip the hard RSS valve.
3. Observe `Rules paused (NNNN MB)` in the status bar (correct at this point).
4. Disable the plugin by commenting out the `plugins:` block.
5. Restart VS Code / reload the window.
6. Status bar still shows `Rules paused (8425 MB)` — stale data.

**Frequency:** Always, once a `memory_state.json` exists on disk from a prior
session.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Extension detects the plugin is not loaded and either hides the memory status or shows "Plugin disabled". Stale `memory_state.json` is ignored or deleted. |
| **Actual** | Extension reads `memory_state.json` unconditionally and displays whatever state it contains, even if the plugin hasn't written to it in days. |

---

## Root Cause

The extension reads `memory_state.json` from the plugin's log directory on a
file-watch or periodic poll basis. It does not:

1. Check whether the `plugins:` block is active in `analysis_options.yaml`.
2. Check the file's modification timestamp against the current session start.
3. Receive a heartbeat from the plugin confirming it is alive.

Any of these checks would prevent stale display.

---

## Suggested Fix

**Option A (simplest):** Check `memory_state.json` mtime against the current
VS Code session start. If the file is older than the session, ignore it and
show the default "not running" state.

**Option B:** Have the plugin write a `plugin_alive.json` heartbeat file on
startup and delete it on shutdown. Extension only reads `memory_state.json`
when the heartbeat file exists and is recent.

**Option C:** Extension reads the `plugins:` block from `analysis_options.yaml`
and only shows memory state when the plugin is configured as active.

---

## Impact

- Misleading status bar causes users to investigate a non-problem.
- User may assume the plugin is causing performance issues when it is not
  loaded.
- In this case, the stale "Rules paused" status appeared alongside a VS Code
  crash, leading to a false attribution chain.

---

## Environment

- saropa_lints version: v15.x (extension active, native plugin disabled)
- VS Code: current stable
- Platform: Windows 11, 16 GB RAM
- Triggering project: d:\src\contacts
- `plugins:` block status: both instances commented out
