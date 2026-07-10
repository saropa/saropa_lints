# BUG: native plugin runs the full tier on files in flux — rapid-edit gate is dead code

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-07-10
Area: native analysis-server plugin hot path
File: `lib/src/saropa_lint_rule.dart` (rapid-edit gate ~L2888-2933), `lib/src/native/saropa_context.dart` (`_wrapCallback` ~L232-285)
Severity: Performance (high — sustained CPU during active editing on every consumer project)
Since: rapid-edit machinery has existed unwired for its whole lifetime

---

## Summary

While a Dart file is being actively edited, the analysis server re-analyzes it on
essentially every keystroke. Each re-analysis re-runs **every** registered
`saropa_lints` rule (up to the configured tier — hundreds to ~2300 rules, most of
which resolve elements/types, the dominant cost). The plugin shipped a dead-code
"rapid-edit" mechanism intended to run only essential-tier rules while a file is
in flux — but even the essential tier is ~330 element-resolving rules, so
"essentials only" would not have solved the problem. The fix instead **defers all
`saropa_lints` rules** while a file is being rapidly edited; the Dart analyzer
still reports compile/resolution errors live regardless. Without this, interactive
editing on a large project pins CPU re-computing diagnostics the next keystroke
discards.

This also produced the user-visible symptom that started the investigation: a
mid-refactor project (transient compile errors, zero `saropa_lints` violations)
triggered heavy analysis and a misleading "non-zero exit" warning. The warning is
a separate defect (tracked with the extension-side fixes); this bug is the
**resource waste** underneath it.

---

## Mechanism / Root Cause

The plugin is a native `analysis_server_plugin`. Rules register visitor callbacks
once via `SaropaLintRule.registerNodeProcessors` → `SaropaContext`. Every AST-node
callback is wrapped by `SaropaContext._wrapCallback`
([`lib/src/native/saropa_context.dart:232`](../lib/src/native/saropa_context.dart#L232)),
which is the single per-node choke point. It gates on, in order:

1. `MemoryPressureHandler.isOverHardLimit` — hard RSS valve
2. `RuntimeTierCap.ruleAllowedByCap` — cumulative tier cap
3. `_shouldSkipCurrentFile()` — generated/test/pattern file skips

It does **not** consult any "is this file being rapidly edited" signal.

Meanwhile `lib/src/saropa_lint_rule.dart` defines exactly that signal:

- `_isRapidEditMode(path)` ([L2897](../lib/src/saropa_lint_rule.dart#L2897)) —
  "3+ analyses of a file within 2s", doc'd as *"During rapid editing, only
  essential-tier rules run for faster feedback."*
- `_isEssentialTierRule()` ([L2931](../lib/src/saropa_lint_rule.dart#L2931)) —
  "Essential-tier rules run even during rapid editing."

Grep proof both are dead:

```bash
grep -rn "_isRapidEditMode\|_isEssentialTierRule" lib/
# lib/src/saropa_lint_rule.dart:2897:  static bool _isRapidEditMode(String path) {
# lib/src/saropa_lint_rule.dart:2931:  bool _isEssentialTierRule() {
# (definitions only — zero call sites)
```

The architectural boundary matters: the Dart **analysis server**, not the plugin,
decides *when* to re-analyze; a plugin cannot debounce that loop. What the plugin
*can* do is make each in-flux pass cheap by running only essential rules — which
is exactly what the dead code was meant to do.

---

## Why it must NOT fire in batch/CLI runs

The scan / baseline / health CLIs and `dart analyze` route through the **same**
`_wrapCallback` — `scan_runner.dart:246` calls `rule.registerNodeProcessors(...)`.
If the gate fired there it would **under-report** (drop non-essential diagnostics)
because a batch walks each file once. Two independent safeguards keep batch runs
at full fidelity:

1. **Server-only arming.** The gate is inert unless an explicit
   `SaropaLintRule.isAnalysisServer` flag is set, and that flag is set **only** in
   `SaropaLintsPlugin.start()` ([`lib/main.dart`](../lib/main.dart)). No CLI in
   `bin/` instantiates the plugin or calls `start()` (verified), so batch runs
   leave it `false`.
2. **Threshold.** Rapid mode needs 3+ analyses of the *same* file within 2s; a
   one-shot batch walker analyzes each file once, so the threshold is never met
   even if arming were somehow wrong.

---

## The fix

Wire the gate into `_wrapCallback`, memoized per analysis pass so the per-node
hot path does the work once per file per pass, not per node.

- **Defer ALL rules while a file is in flux** (no essential carve-out). Rationale
  above: the essential tier is ~330 element-resolving rules, so "essentials only"
  still pins CPU on code that is still changing; the Dart analyzer covers live
  compile errors either way.
- Record the edit timestamp **exactly once per pass**, keyed on the resolved
  `CompilationUnit` identity (`identityHashCode(node.root)`). Recording per node
  would append thousands of timestamps per pass and permanently pin rapid mode.
- Public surface on `SaropaLintRule`: `static bool isAnalysisServer` (armed in
  the server entry points), and `static bool deferForRapidEdit(path, unitId)`
  (rule-independent — the decision is per file+pass).
- The per-node `identityHashCode(node.root)` walk is itself **guarded by
  `isAnalysisServer`** in `_wrapCallback`, so batch/CLI runs pay none of the
  gate's per-node cost.
- Bound the two new per-file maps alongside the existing `_fileEditHistory`
  cleanup.

### Server entry points armed

`SaropaLintRule.isAnalysisServer = true` is set in **both** server `start()`
paths: `lib/main.dart` (the primary plugin) and the generated composite-plugin
scaffold (`lib/src/init/composite_plugin_scaffold.dart`, so future composite
consumers get the relief too). Existing composite consumers pick it up when they
regenerate their scaffold. No `bin/` CLI or test calls either `start()`.

### Accepted tradeoff (documented at the call site)

While typing, `saropa_lints` diagnostics are deferred and briefly disappear, then
return on the next settled pass (once the 2s window clears and the server
re-analyzes). This is the intended "no lint work on code in flux" behavior. The
plugin cannot force a settle-pass; it relies on the server's normal idle
re-analysis to restore diagnostics after editing stops.

---

## Changes Made

### `lib/src/saropa_lint_rule.dart`
- Add `static bool isAnalysisServer`.
- Add per-pass dedup state (`_lastPassUnitId`, `_fileRapidMode`) +
  `static bool deferForRapidEdit(path, unitId)` (defers all rules in rapid mode).
- Extend the `_fileEditHistory` cleanup to prune the new maps.
- Remove the now-unused `_isEssentialTierRule` and its `essentialRules` import
  (the essential carve-out was dropped).

### `lib/src/native/saropa_context.dart`
- In `_wrapCallback`, after `_shouldSkipCurrentFile`, guard the gate with
  `if (SaropaLintRule.isAnalysisServer)` (skips the per-node root walk in batch
  runs), memoize the deferral decision per pass, and early-return when deferred.

### `lib/main.dart` and `lib/src/init/composite_plugin_scaffold.dart`
- Set `SaropaLintRule.isAnalysisServer = true` in both server `start()` paths.

---

## Tests Added

`test/native/rapid_edit_gate_test.dart`:
- `deferForRapidEdit` trips only after the 3rd pass within the 2s window.
- Inert (never defers) when `isAnalysisServer` is false — batch/CLI fidelity.
- Empty path never defers.

---

## Environment

- saropa_lints version: 14.3.2 (fix)
- Triggering project: any large consumer project under active editing (observed
  on `D:\src\contacts`)

---

## Finish Report (2026-07-10)

### Defect

The native analysis-server plugin re-ran every registered rule on each of the
analysis server's continuous re-analysis passes of a file being edited. A dormant
"rapid-edit" mechanism (`_isRapidEditMode`, `_isEssentialTierRule` in
`saropa_lint_rule.dart`) existed to relieve this but had zero call sites — dead
since it was written. Interactive editing on a large project therefore paid full
per-keystroke rule cost, most of it element/type resolution.

### Resolution

A rapid-edit gate now defers **all** `saropa_lints` rules while a file is in flux
(3+ analysis passes within 2s). The essential-tier carve-out the original dead
code implied was rejected: the essential tier is ~330 element-resolving rules, so
"essentials only" would not have relieved the CPU cost, and the Dart analyzer
surfaces compile/resolution errors live independently of `saropa_lints`.

Mechanics:
- `SaropaLintRule.deferForRapidEdit(path, unitId)` (static, rule-independent)
  records one edit timestamp per analysis pass — keyed on the resolved
  `CompilationUnit` identity so the per-node hot path neither re-records
  (which would permanently pin rapid mode) nor recomputes.
- `SaropaContext._wrapCallback` consults the gate only when
  `SaropaLintRule.isAnalysisServer` is set, so the per-node `node.root` walk is
  skipped entirely in batch runs.
- The flag is armed in both interactive server entry points — `lib/main.dart` and
  the generated composite-plugin scaffold. No `bin/` CLI or test calls either
  `start()`, so scan/baseline/health CLIs and `dart analyze` stay full-fidelity;
  a one-shot walk also never meets the 3-in-2s threshold (second safeguard).

### Boundary

The Dart analysis server, not the plugin, decides when to re-analyze; a plugin
cannot debounce that loop. This fix makes each in-flux pass cost nothing for
`saropa_lints`, which is the available lever. Deferred diagnostics reappear on the
next settled pass once the 2s window clears; the plugin cannot force a settle-pass
and relies on the server's idle re-analysis to restore them.

### Follow-ups (flagged, not done)

- `config_loader.dart` `_nativePluginStarted` is a near-duplicate "server started"
  signal; consolidating it with `isAnalysisServer` would remove the parallel flag.
- Existing composite-plugin consumers gain the relief only after regenerating
  their scaffold.
- Separately diagnosed but NOT implemented: the extension-side false "non-zero
  exit" warning on zero-violation runs, and the `pubspec.lock`-triggered
  auto-analyze surfacing failures as popups.

### Verification

`dart test test/native/rapid_edit_gate_test.dart` (3 pass) and
`test/scan/fixture_lint_integration_test.dart` (7 pass, confirms batch runs still
report every rule including compliant-only and exact-count fixtures).
