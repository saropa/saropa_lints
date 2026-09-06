# BUG: Infrastructure — Diagnostics go stale after code fix or `// ignore:` addition

**Status: Open — root cause confirmed for `// ignore:` case; code-fix case
needs channel identification**

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

## Two Independent Diagnostic Channels

saropa_lints delivers diagnostics to VS Code through TWO independent channels:

**Channel 1 — In-process plugin (light lane, ~200 rules)**
Runs inside the Dart analysis server via `analysis_server_plugin`. Diagnostics
flow: rule callback → `DiagnosticReporter` → `RecordingDiagnosticListener` →
`AnalysisErrorsParams(path, errors)` notification → analysis server → LSP →
VS Code. Source in Problems panel: `"dart"`.

The Dart analyzer natively handles `// ignore:` directives — Channel 1 honors
them correctly.

**Channel 2 — Scan-on-save (~2100+ rules)**
Runs in an external `dart run saropa_lints:scan` process triggered on save by
`scanOnSaveController.ts`. Diagnostics flow: scan CLI → JSON stdout →
`scanOnSaveRunner.ts` parse → `_applyDiagnostics` →
`vscode.DiagnosticCollection.set()`. Source in Problems panel:
`"saropa_lints"`.

### Why "Restart Analysis Server" doesn't help

"Restart Analysis Server" kills and restarts the Dart analysis server (Channel
1) but does NOT touch the scan-on-save `DiagnosticCollection` (Channel 2).
Channel 2 diagnostics persist until the next scan replaces them. Only
"Developer: Reload Window" reloads the extension and clears its collection.

### Event dispatch is NOT the issue

The Dart SDK's `PluginManager` forwards `analysis.updateContent` and
`analysis.handleWatchEvents` to ALL plugins uniformly (confirmed via SDK
source). The notification channel (`PluginIsolateChannel`) has no filtering,
batching, or dropping. Known SDK issue #61684 reports 6-7× performance
degradation with plugins — in a 3957-file workspace, Channel 1 re-analysis may
take minutes (slow, not stuck).

---

## Confirmed Root Cause: Scan CLI does not honor `// ignore:` directives

`lib/src/scan/stale_ignore_detector.dart` line 4 states explicitly:

> "The scan CLI does not honor `// ignore:` directives — rules report
> regardless."

This is the root cause for the `// ignore:` reproducer: the user adds
`// ignore: saropa_lints/rule_name`, saves, the scan-on-save re-runs the file,
and the scan CLI **re-reports the diagnostic because it ignores the directive**.
The `DiagnosticCollection` is updated with the same diagnostic, so the
Problems panel and squiggles persist.

The in-process plugin (Channel 1) honors `// ignore:` via the Dart analyzer's
native processing. But Channel 2 (scan-on-save, covering ~2100 rules) does
not. For any rule that runs in BOTH channels, Channel 1 clears the diagnostic
while Channel 2 re-reports it — the diagnostic persists.

For rules that run ONLY in Channel 2 (the majority — any rule not in the light
lane), `// ignore:` directives have no effect at all.

---

## Code-Fix Case: Root Cause Partially Identified

When the user FIXES the code (not `// ignore:`), the scan-on-save pipeline
should work: `_applyDiagnostics` (`scanOnSaveController.ts:935`) correctly
clears diagnostics for files with zero issues (lines 939-945). If diagnostics
still persist after a code fix + save:

- **Hung scan:** If `_scanInFlight` is `true` from a previous scan that never
  completed (timeout, crash, Dart build lock), all subsequent saves queue into
  `_rescanQueued` but the queued scan never runs. Check: Command Palette →
  "Saropa Lints: Scan On Save — Diagnose" — if `scan in flight: true` and
  `pending files: 0`, a hung scan is blocking.

- **Balanced-mode file cache:** NOT the cause — `FileContentCache.hasChanged()`
  uses a content hash. Fixed code has different content → returns `true` →
  rules re-run. `FileBudgetTracker` exempts files modified within 24 hours.

- **Memory pressure:** `MemoryPressureHandler.isOverHardLimit` at
  `saropa_context.dart:283` silences ALL rules when RSS exceeds the cap.
  In a 3957-file workspace this could be persistently tripped, producing empty
  results that clear diagnostics (the opposite symptom). Not the cause of
  persistence.

---

## Fix Path

### Fix 1: Scan CLI must honor `// ignore:` directives (CONFIRMED)

The scan CLI needs to parse `// ignore:` and `// ignore_for_file:` directives
and suppress matching diagnostics before reporting. The `stale_ignore_detector`
already parses these directives (for stale-ignore detection) — the same parsing
can be reused to filter diagnostics before output.

### Fix 2: Clear scan-on-save diagnostics on "Restart Analysis Server"

`scanOnSaveController` should listen for `dart.restartAnalysisServer` and clear
its `DiagnosticCollection`. Currently it only clears when
`saropaLints.enabled` changes (`scanOnSaveController.ts:459-460`).

### Fix 3: Identify hung-scan cause (code-fix case)

If diagnostics persist after code fixes (not just `// ignore:`), diagnose
whether the scan-on-save pipeline is running at all. The "Diagnose" command
output is the first step.

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

---

## Gap closed: the scan CLI does NOT honor `// ignore:` directives

Confirmed by construction on 2026-09-05, without running anything.

The scan CLI contains no ignore-suppression logic. `bin/scan.dart`,
`lib/src/scan/scan_runner.dart` and `lib/src/scan/scan_rule_context.dart`
contain no code that parses `// ignore:` comments to suppress a diagnostic —
the only matches in those files are their own ignore comments and one unrelated
comment about redirecting callback output.

The only place the scan path parses ignore comments is
`lib/src/scan/stale_ignore_detector.dart`, and it exists to serve
`--find-stale-ignores` / `--fix-stale-ignores`, not suppression.

That detector proves the point on its own. It builds a map of which rules fired
on which line, then marks an ignore stale when no diagnostic with that rule name
fired on the target line (`stale_ignore_detector.dart:195-218`). The feature can
only work if the scan emits diagnostics on ignored lines. If the scan honored
`// ignore:`, every ignore would suppress its own diagnostic, nothing would ever
fire on an ignored line, and every ignore in the project would be reported as
stale. The feature would be useless rather than merely wrong, so its existence
and correctness are evidence that suppression does not happen upstream of it.

This confirms root cause (c) without needing Step 1 of the Fix Path to
distinguish the channel. It also predicts a second, related symptom worth
checking: a line correctly suppressed under the in-process plugin should show a
diagnostic under scan-on-save, because the plugin runs inside the Dart analyzer
and inherits its native `// ignore:` handling, while the scan CLI is an external
process that inherits nothing.

### What this does not yet establish

Whether anything downstream filters ignored diagnostics before they reach the
Problems panel. The extension's scan-on-save controller logs
`N raw finding(s), M published after severity filter` — a severity filter, not
an ignore filter — so on current evidence nothing recovers the suppression, but
that path was not read line by line.

Step 1 of the Fix Path (checking the `source` field on a stale diagnostic to
identify the channel) is still worth doing, because it distinguishes which
producer emitted the stale diagnostic. It is no longer needed to confirm (c).
