# BUG: Infrastructure — Diagnostics go stale after code fix or `// ignore:` addition

**Status: Open — needs investigation**

Created: 2026-09-05
Rule: ALL rules (infrastructure-level)
File: `lib/src/rules/saropa_lint_rule.dart` (line ~3223, `deferForRapidEdit`)
      `lib/src/native/saropa_context.dart` (line ~322, `_wrapCallback`)
Severity: Critical — blocks the entire fix-verify loop; developers must reload
VS Code to see whether a fix worked
Rule version: N/A (infrastructure)

---

## Summary

After adding an `// ignore:` directive or fixing flagged code, saropa_lints
diagnostics do NOT clear from VS Code's Problems panel. "Dart: Restart Analysis
Server" does not help. Only "Developer: Reload Window" (full VS Code reload)
clears stale diagnostics. This breaks the edit-verify loop for every rule.

The `deferForRapidEdit` mechanism is the primary suspect but the exact failure
path has NOT been verified. The pivotal question is what the analysis server
does when per-node callbacks emit nothing during a deferred pass.

---

## Attribution Evidence

Infrastructure bug — not rule-specific. The mechanism lives in:

```
lib/src/rules/saropa_lint_rule.dart — deferForRapidEdit (line ~3223)
lib/src/native/saropa_context.dart — _wrapCallback (line ~322)
```

The deferral happens inside `_wrapCallback` at `saropa_context.dart:322` — the
per-node callback returns early without calling the reporter. The rule's
`registerNodeProcessors` already ran at startup; it is the per-node visitor
that short-circuits.

The docstring at `saropa_lint_rule.dart:3218–3222` acknowledges the tradeoff:
"saropa_lints diagnostics are deferred and briefly disappear, returning on the
next settled pass… The plugin cannot force a settle-pass; it relies on the
server's normal idle re-analysis."

---

## Reproducer

1. Open a file with a saropa_lints diagnostic in VS Code Problems panel.
2. Add `// ignore: saropa_lints/rule_name -- reason` on the line above.
3. Save the file.
4. **Expected:** diagnostic disappears from Problems panel within seconds.
5. **Actual:** diagnostic remains indefinitely. Only "Developer: Reload Window"
   clears it. "Dart: Restart Analysis Server" does NOT help.

Same behavior when FIXING the underlying code instead of suppressing.

**Frequency:** Reported as consistent, but not yet verified with logging. The
docstring says diagnostics should restore on the next idle re-analysis — if they
truly never restore, the problem may not be `deferForRapidEdit` at all.

---

## Hypothesis (UNVERIFIED)

The `deferForRapidEdit` mechanism is the primary suspect, but two critical
questions are open:

### Question 1: What does the server do when callbacks emit nothing?

The defer happens inside `_wrapCallback` — the per-node callback returns early
without calling the reporter. The `analysis_server_plugin` framework still ran
the pass; the callbacks just didn't emit anything.

**If the framework treats "callbacks emitted nothing" as "zero diagnostics":**
the server clears previous diagnostics. When the rapid-edit window expires and
no further file change occurs, the server never triggers a new pass, so the
panel stays stale. This matches the observed behavior.

**If the framework treats "callbacks emitted nothing" as "no result" and retains
previous diagnostics:** then `deferForRapidEdit` is NOT the cause, and the
staleness comes from somewhere else — possibly the server not scheduling idle
re-analysis after rapid edits, or the plugin not receiving file-change
notifications.

This is the **pivotal question**. The fix depends entirely on the answer.

### Question 2: Does idle re-analysis actually fire?

The docstring says the plugin relies on the server's "normal idle re-analysis"
to restore diagnostics after edits settle. If the server reliably fires idle
re-analysis, diagnostics should self-heal within seconds. If they don't
self-heal, either (a) idle re-analysis never fires, (b) the deferred pass
consumed the last analysis trigger, or (c) the problem is unrelated to
`deferForRapidEdit`.

---

## Investigation Steps (REQUIRED before implementing any fix)

1. **Add logging inside `deferForRapidEdit` and `_wrapCallback`:** log when
   deferral triggers, the file path, the pass count, and whether the deferral
   window has expired. Log when a non-deferred (real) pass runs.

2. **Reproduce the stale diagnostic:** save a fix, observe the Problems panel,
   and check the log. Confirm: (a) whether deferral actually triggers on a
   single save + auto-format, (b) how many passes fire and at what intervals,
   (c) whether a "real" (non-deferred) pass ever fires afterward.

3. **Verify server behavior with empty results:** create a test where a rule
   deliberately emits nothing on one pass and emits diagnostics on the next.
   Observe whether the server clears or retains between passes.

4. **Check `_fileEditHistory` lifecycle:** on "Restart Analysis Server",
   `_fileEditHistory` is a static in-memory map. On a cold restart it is EMPTY,
   so the rapid-edit gate CANNOT trip on the first pass after restart. If
   diagnostics are still stale after restart, the cause is NOT
   `deferForRapidEdit` — investigate the server's file-change notification
   mechanism instead.

---

## Suggested Fixes (contingent on investigation)

### If Question 1 = "empty clears the panel":

**Option A: Cache and replay**

When deferring, replay the last valid diagnostic set for that file instead of
emitting nothing. Requires tracking diagnostics per-file per-pass — the current
architecture reports diagnostics inline (not collected), so this needs a
collection layer.

**Option D: Raise the deferral threshold (band-aid)**

Raise the gate from 3 passes / 2 seconds to a higher threshold (e.g., 5
passes / 1 second) so a single save + auto-format doesn't trigger deferral.
Reduces frequency but doesn't eliminate the bug.

### If Question 1 = "nothing = retain previous":

The bug is NOT `deferForRapidEdit`. Investigate:
- Whether the server schedules idle re-analysis after rapid edits.
- Whether the plugin receives file-change notifications correctly.
- Whether the analysis_server_plugin framework has a known bug with stale
  diagnostics.

### Non-viable options (corrected from initial report):

**~~Option B: Skip registration during deferral~~** — registration happens once
at startup (`registerNodeProcessors`), not per pass. The per-node visitor
short-circuits, not the registration. This misunderstands the lifecycle.

**~~Option C: Force re-analysis after deferral~~** — the docstring already notes
"The plugin cannot force a settle-pass." No API exists for this. Would need
investigation to confirm.

---

## Impact

- Every developer using saropa_lints in VS Code is affected.
- The fix-verify loop is broken: developers cannot tell if a fix worked without
  reloading VS Code.
- Bulk lint sweeps (80+ diagnostics) require repeated VS Code reloads, costing
  5–10 minutes per sweep in restart overhead.
- Agent-assisted fixes cannot be verified by checking the Problems panel.

---

## Environment

- saropa_lints: current HEAD
- analysis_server_plugin: 0.3.14
- Dart SDK: current stable
- VS Code: current stable
- Observed on: Windows 11, contacts app (3957-file workspace)
