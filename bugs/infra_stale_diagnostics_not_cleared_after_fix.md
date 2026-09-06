# BUG: Infrastructure — Diagnostics go stale after code fix or `// ignore:` addition

**Status: Open — root cause unidentified**

Created: 2026-09-05
Rule: ALL rules (infrastructure-level)
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

## Reproducer

1. Open a file with a saropa_lints diagnostic in VS Code Problems panel.
2. Add `// ignore: saropa_lints/rule_name -- reason` on the line above.
3. Save the file.
4. **Expected:** diagnostic disappears from Problems panel within seconds.
5. **Actual:** diagnostic remains indefinitely. Only "Developer: Reload Window"
   clears it. "Dart: Restart Analysis Server" does NOT help.

Same behavior when FIXING the underlying code instead of suppressing.

**Frequency:** Reported as consistent, not yet verified with logging.

---

## Investigation Results

### `deferForRapidEdit` is NOT the root cause

The initial hypothesis blamed `deferForRapidEdit` (3+ passes in 2s → all rule
callbacks become no-ops). Code tracing through the `analysis_server_plugin`
framework (v0.3.14) disproves this:

**Finding 1: Empty pass = clears diagnostics.**
The framework pre-populates every file in a library with an empty diagnostic
list (`plugin_server.dart:549-551`) and sends `AnalysisErrorsParams(path, [])`
for every file (`plugin_server.dart:394-399`). A fresh
`RecordingDiagnosticListener` is created per pass (`plugin_server.dart:418-421`)
with no carryover. An empty pass therefore CLEARS previous diagnostics — it does
not retain them.

**Finding 2: No idle re-analysis exists.**
The plugin framework is purely request-driven. Analysis fires only when the
analysis server sends `analysis.updateContent` (editor buffer changes,
`plugin_server.dart:805`) or `analysis.handleWatchEvents` (disk changes,
`plugin_server.dart:863`). There is no timer, no debounce, no idle-triggered
re-analysis. The docstring claim that "the server's normal idle re-analysis"
would restore diagnostics is incorrect — no such mechanism exists in the plugin
framework.

**Finding 3: Plugin cannot force re-analysis.**
The `Plugin` API (`plugin.dart`) exposes only `register()`, `start()`, and
`shutDown()`. There is no API to request re-analysis of a file.

**The contradiction:** If `deferForRapidEdit` fires, diagnostics should
*disappear* (empty pass clears them). The reported symptom is diagnostics
*persisting*. These are opposite behaviors. `deferForRapidEdit` cannot cause
diagnostics to persist — it can only cause them to transiently disappear.

**On restart:** `_fileEditHistory` is a static in-memory map. On "Restart
Analysis Server", the plugin process restarts with an empty map — the
rapid-edit gate cannot trip on the first pass. If diagnostics are stale after
restart, the cause is definitively not `deferForRapidEdit`.

### What `deferForRapidEdit` DOES cause (separate issue)

During genuine rapid editing (3+ passes in 2s), all diagnostics vanish until
editing stops. Since there is no idle re-analysis mechanism, they only return
when the next file-change event (save, type, external edit) triggers a new
pass. This is a minor UX annoyance but NOT the reported bug — the reported bug
is diagnostics persisting when they should clear.

---

## Actual Root Cause: Unknown

The investigation eliminates `deferForRapidEdit`. Possible causes to
investigate:

### Hypothesis A: Analysis server not forwarding file-change events to plugin

The analysis server may debounce, coalesce, or drop `analysis.updateContent` /
`analysis.handleWatchEvents` requests to the plugin under load. In a 3957-file
workspace, the server may decide the plugin's re-analysis is lower priority
than its own type resolution. If the plugin never receives the change event, it
never re-analyzes, and the old diagnostics persist.

**How to test:** Add logging at the top of `_handleAnalysisUpdateContent` and
`_handleAnalysisWatchEvents` in a local fork of `analysis_server_plugin` to
confirm whether the plugin receives events after saves.

### Hypothesis B: Content overlay vs disk divergence

The analysis server uses "content overlays" for unsaved editor buffers. When
the user saves, the overlay should be replaced by the disk content. If the
overlay is not removed after save, the plugin may re-analyze the stale
(pre-save) content and re-report the same diagnostics.

**How to test:** Log the file content hash at the start of `_analyzeLibrary` to
confirm the plugin sees the post-save content.

### Hypothesis C: Analysis context not invalidating the file

`analysisContext.changeFile(path)` at `plugin_server.dart:902` notifies the
analysis driver that a file changed. `applyPendingFileChanges()` then returns
the set of affected files. If the driver does not consider the file "affected"
(e.g., because the overlay still holds the old content), the file is not
re-analyzed.

**How to test:** Log the return value of `applyPendingFileChanges()` to see
whether the edited file appears in the affected set.

### Hypothesis D: Stale resolved unit served to plugin

The `AnalysisDriver` caches resolved units. If it serves a cached (pre-edit)
resolved unit to the plugin, the rules see old code and re-report the same
diagnostics. The file appears "analyzed" but with stale AST.

**How to test:** Log a hash of the `CompilationUnit.toSource()` to confirm the
AST matches the current file content.

---

## Next Steps

1. Add diagnostic logging to `_wrapCallback` to confirm whether
   `deferForRapidEdit` even fires during a normal save (it likely does NOT —
   a single save + auto-format is only 2 passes, below the threshold of 3).

2. Fork `analysis_server_plugin` locally and add logging to
   `_handleAnalysisUpdateContent`, `_handleAnalysisWatchEvents`,
   `_handleContentChanged`, and `_analyzeLibrary` to trace whether the plugin
   receives file-change events and re-analyzes after a save.

3. If the plugin IS re-analyzing but reporting the same diagnostics: log the
   resolved unit's content hash to verify it sees the updated file.

4. If the plugin is NOT receiving events: the bug is in the analysis server's
   plugin communication, not in saropa_lints — file upstream.

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
