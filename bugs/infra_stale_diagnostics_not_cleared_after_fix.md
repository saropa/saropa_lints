# BUG: Infrastructure — Diagnostics go stale after code fix or `// ignore:` addition

**Status: Open**

Created: 2026-09-05
Rule: ALL rules (infrastructure-level)
File: `lib/src/rules/saropa_lint_rule.dart` (line ~3223, `deferForRapidEdit`)
Severity: Critical — blocks the entire fix-verify loop; developers must reload
VS Code to see whether a fix worked
Rule version: N/A (infrastructure)

---

## Summary

After adding an `// ignore:` directive or fixing flagged code, saropa_lints
diagnostics do NOT clear from VS Code's Problems panel. "Dart: Restart Analysis
Server" does not help. Only "Developer: Reload Window" (full VS Code reload)
clears stale diagnostics. This breaks the edit-verify loop for every rule.

---

## Attribution Evidence

Infrastructure bug — not rule-specific. The mechanism lives in the shared base
class used by all rules:

```
lib/src/rules/saropa_lint_rule.dart — deferForRapidEdit (line ~3223)
```

The `_fileEditHistory` static map and the 2-second / 3-pass rapid-edit gate are
the root cause.

---

## Reproducer

1. Open a file with a saropa_lints diagnostic in VS Code Problems panel.
2. Add `// ignore: saropa_lints/rule_name -- reason` on the line above.
3. Save the file.
4. **Expected:** diagnostic disappears from Problems panel within seconds.
5. **Actual:** diagnostic remains indefinitely. Only "Developer: Reload Window"
   clears it. "Dart: Restart Analysis Server" does NOT help.

Same behavior when FIXING the underlying code instead of suppressing.

**Frequency:** Always. Reproducible on every edit that resolves a diagnostic.

---

## Root Cause

The plugin implements a **rapid-edit deferral** system. When 3+ analysis passes
occur within 2 seconds on the same file, ALL saropa_lints rule callbacks return
early as no-ops — they report ZERO diagnostics for that pass.

The Dart Analysis Server protocol treats a plugin pass that reports zero
diagnostics as "this plugin found no problems." The server clears any previous
diagnostics from that plugin. This is correct behavior from the server's
perspective — a plugin that reports nothing is saying "all clear."

**The failure sequence:**

1. File has diagnostic D at line 10.
2. User adds `// ignore:` at line 9 and saves.
3. Save triggers analysis pass 1. The ignore is now present — D should not fire.
4. VS Code's auto-format or auto-save triggers pass 2 within milliseconds.
5. `deferForRapidEdit` sees 2+ passes within 2 seconds → all callbacks become
   no-ops → zero diagnostics reported.
6. Server receives zero diagnostics from saropa_lints → clears D from panel.
   **This part works correctly** (D disappears briefly).
7. The rapid-edit window expires. But NO further file change occurs, so the
   analysis server does NOT trigger another pass.
8. If the server DOES trigger a re-analysis (e.g., the user clicks in the file),
   the new pass sees the `// ignore:` and correctly reports zero diagnostics.
   **This path works.**
9. But if no re-analysis fires, the panel stays in whatever state the last pass
   left it. For files where rapid-edit produced a misleading empty pass, the
   panel shows "0 problems" even when problems remain. For files where the
   deferral happened DURING the first analysis after the fix, the panel may
   still show the OLD diagnostic because the deferred pass never ran to
   completion.

**The net effect:** diagnostics sometimes persist after fixes, sometimes
disappear when problems remain, and the state is unpredictable. The only
reliable reset is a full VS Code window reload.

**Why "Restart Analysis Server" doesn't help:** the restart kills the server
process and respawns it. The new server loads the plugin fresh, but the first
analysis pass on all open files hits the rapid-edit gate again (the restart
itself triggers multiple near-simultaneous passes as all open files are
re-analyzed).

---

## Suggested Fix

### Option A: Cache and replay (preferred)

When `deferForRapidEdit` decides to defer, instead of returning zero diagnostics
(which clears the panel), replay the **last valid diagnostic set** for that file.
This keeps the panel stable during rapid edits and lets the "real" pass update
it when edits settle.

Implementation: maintain a `Map<String, List<Diagnostic>> _lastValidDiagnostics`
alongside `_fileEditHistory`. On defer, report the cached set. On a full
(non-deferred) pass, update the cache.

### Option B: Don't register during deferral

Instead of registering callbacks that return early (producing an empty result),
skip registration entirely during the rapid-edit window. If the plugin reports
NO result (vs an empty result), the server retains previous diagnostics. This
depends on the `analysis_server_plugin` API distinguishing "no result" from
"empty result" — verify this is possible.

### Option C: Post-deferral re-analysis trigger

After the rapid-edit window expires, schedule a forced re-analysis of the file
(if the API supports it). This ensures the accurate state is always computed
once edits settle, even if no further file change occurs.

### Option D (minimum viable): Increase the deferral threshold

Raise the rapid-edit gate from 3 passes / 2 seconds to a higher threshold (e.g.,
5 passes / 1 second) so that a single save + auto-format doesn't trigger
deferral. This is a band-aid but reduces the frequency of the problem.

---

## Impact

- Every developer using saropa_lints in VS Code is affected.
- The fix-verify loop is broken: developers cannot tell if a fix worked without
  reloading VS Code.
- Bulk lint sweeps (80+ diagnostics) require repeated VS Code reloads, costing
  5-10 minutes per sweep in restart overhead.
- Agent-assisted fixes cannot be verified by checking the Problems panel — the
  agent must use CLI `dart run saropa_lints scan` instead, which is slower and
  doesn't match the developer's workflow.

---

## Environment

- saropa_lints: current HEAD
- analysis_server_plugin: 0.3.14
- Dart SDK: current stable
- VS Code: current stable
- Observed on: Windows 11, contacts app (3957-file workspace)
