# BUG: saropa_lints native plugin — analysis server RSS grows to ~10 GB

**Status: Fixed — verified on the live contacts analyzer after the 14.3.0 publish.**

Created: 2026-06-28
Last updated: 2026-06-28 (FIXED — 14.3.0 in-editor essential cap confirmed loaded and RSS controlled)

---

## Resolution (verified)

Shipped in **14.3.0**. The native plugin now defaults to the **essential** tier
in-editor when no tier is configured (`reloadRuntimeTierCapForPlugin` →
`RuntimeTierCap._reload(..., RuleTier.essential)`), plus a hard RSS valve
(`MemoryPressureHandler.isOverHardLimit`) that short-circuits rule callbacks and
evicts caches past the limit. Full coverage still runs out-of-process via
`dart run saropa_lints scan`.

**Why earlier in-place verification failed:** the analyzer caches a *compiled*
plugin build keyed by source path. Source edits, version bumps, pub.dev→path
switches, and clearing `.plugin_manager` all reused the stale build (a deeper
incremental-compile kernel cache survives the directory clear). Only a
brand-new published version in a fresh pub-cache location forces a clean rebuild
— which is why this could not be confirmed until 14.3.0 was published and
installed.

**Verification (contacts analyzer, post-14.3.0 install + VS Code restart):**

```
plugin.log 2026-06-28T17:20:11Z:
  Runtime tier cap: essential (from default in-process cap ...)
  Runtime tier cap applied: enabled rule count 1135 → 281.
  Config loaded from D:/src/contacts — enabledRules: 281
```

- Enabled rules in-editor dropped 1135 → 281 (essential band).
- Post-restart `dart language-server` RSS settled at **1.79 GB** — inside the
  plugin-OFF base range (1.6–2.3 GB), no longer climbing toward the 10 GB hang.
- The pre-restart 6.7 GB orphan process was a leftover, killed manually.

---

### Original investigation (kept for history)
Severity: Critical — saturates RAM, hangs the IDE / VS Code extension host. Makes large projects undevelopable with the plugin enabled.
Plugin model: native `analysis_server_plugin` (in-process; NOT custom_lint).

Companion: `infra_native_plugin_resolution_audit.md` — per-site resolution work-list, now demoted to a CPU/hygiene reference (it is **not** the memory lever; see Findings).

---

## Summary

With the saropa_lints native plugin enabled, the Dart **analysis server**
(`dart.exe language-server`) grows to multiple GB and keeps climbing over an
editing session until it saturates RAM and hangs the editor. Reproduces on the
saropa_lints repo itself (it dogfoods the plugin) and on the large downstream
project (Saropa Contacts, ~3957 files). This is a plugin-wide memory
characteristic, not a single rule.

---

## Measured findings (this session — direct measurement, not hypothesis)

All numbers are live `WorkingSet64` of the VS Code `dart language-server`
processes, sampled with `Get-Process`, on this machine.

| Condition | Analysis-server RSS |
|---|---|
| Plugin **OFF** (base Dart analysis), settled | **1.6 GB** and **2.3 GB** (two open projects) |
| Plugin **ON**, after an editing session | **5.0 GB** / **3.8 GB**, observed climbing to **5.8 GB** |
| Plugin **ON**, fresh restart, while analyzing | 0.24 → 1.6 → **4.3 GB** and still climbing |

Derived facts:

1. **Base Dart analysis is 1.6–2.3 GB** on these projects — inherent analyzer
   cost, not attributable to saropa_lints.
2. **The plugin adds ~1.5–3.4 GB over base, and it GROWS over a session** toward
   the ~10 GB hang. The growth (not just a high baseline) is the defining
   symptom.
3. **The rule LOGIC is cheap.** Running the full enabled rule set over the whole
   repo via the **out-of-process scan** (`bin/scan.dart`, which uses
   `parseString` — purely syntactic, no element resolution) peaks at **~46 MB**.
   So the rules themselves are not the memory hog.
4. **The cost is specific to the in-process analysis-server path.** The
   difference between the 46 MB scan and the multi-GB language-server is that the
   server runs rules over **fully resolved** units (element model + type system
   + SDK closure). The plugin running rules in that context forces the analyzer
   to materialize and retain element-model state well beyond what base analysis
   keeps.

## What was ruled OUT (by code audit, earlier this session)

- **No reference leak in plugin code.** No static field and no rule instance
  field anywhere in `lib/` retains `AstNode` / `Element` / `CompilationUnit` /
  `ResolvedUnitResult`. ~2300 rule classes were swept; every mutable
  collection/node field lives on a per-file `RecursiveAstVisitor` helper that is
  discarded after the file. `ImpactTracker` / reporter store only strings and
  self-clean on re-analysis.
- **Resolution-call reduction is NOT the memory lever.** Rules run *after* the
  analyzer has resolved the unit, so reading `.element` / `.staticType` on local
  nodes is a free field access. The only memory-relevant reaches are
  cross-library (`allSupertypes`, `.element.library.uri`), which are exactly the
  cases that cannot be dropped without false positives. The full per-site
  work-list (companion file) is therefore a CPU/hygiene exercise, not the fix.

## Root cause (status)

Narrowed, not pinned. The multi-GB growth is the **analyzer retaining resolved
element/AST state because the in-process plugin runs many rules over resolved
units across the whole project**, and that retained state accumulates as more of
the project resolves over a session. The exact dominant retained object type is
still unconfirmed — that requires a heap snapshot of the analysis-server isolate
(see Next steps). It is genuinely the in-process integration, since the same
rules out-of-process cost 46 MB.

---

## Fixes written this session — and why they are UNVERIFIED

All of the following are in source, compile, and pass unit tests, but **none
could be confirmed running in a live analyzer** (see Delivery blocker):

1. **Default the in-process plugin to essential tier** when no tier is
   configured (`reloadRuntimeTierCapForPlugin` in
   `lib/src/config/runtime_tier_cap.dart`, called from
   `lib/src/native/config_loader.dart`). Intent: run far fewer rules in-process
   so the analyzer materializes less resolved state; full coverage runs
   out-of-process via `dart run saropa_lints scan`. **Unverified** that capping
   rules actually lowers the resident set.
2. **Hard RSS safety valve** (`MemoryPressureHandler.isOverHardLimit` in
   `lib/src/project_context_throttle_memory.dart`, gate in
   `lib/src/native/saropa_context.dart`). Reads real `ProcessInfo.currentRss`;
   pauses all rule callbacks when RSS crosses a cap (default 6144 MB,
   `SAROPA_LINTS_MAX_RSS_MB`, hysteresis). A backstop, not a cure.
3. **Wired the dead cache-relief subsystem** (`initializeCacheManagement` in
   `Plugin.start`; `recordFileProcessed` per new file). Bounds only the plugin's
   own (sub-GB) string caches.

## Delivery blocker (critical — discovered this session)

**Edited plugin source does NOT load into the running analyzer.** Proven from
`reports/.saropa_lints/plugin.log`: after editing source, clearing
`C:\Users\craig\AppData\Local\.dartServer\.plugin_manager`, AND restarting the
analysis server, the latest session still logs `registered 2327 rules`,
`enabledRules: 705`, and **zero** occurrences of the tier-cap line my new code
writes. The analyzer runs a **cached compiled build** of the plugin; a VS Code
restart and a `.plugin_manager` wipe were both insufficient to pick up the
edits.

Implication: the reliable way a plugin change reaches an editor is a **version
bump + reinstall/pin** (the version change is what invalidates the analyzer's
plugin build). Local source hot-reload of a native analyzer plugin did not work
here. This blocks both shipping AND in-dev verification of the fixes above.

## Immediate stopgaps (not fixes)

- Disable the plugin in a project's `analysis_options.yaml` (comment the WHOLE
  `plugins:` subtree, including the nested `diagnostics:` block — commenting only
  the header orphans `diagnostics:` and produces invalid YAML that terminates
  the analyzer). Restart the analyzer; RSS drops to the 1.6–2.3 GB base.
- Run rules out-of-process on demand: `dart run saropa_lints scan .` (~46 MB).

---

## Next steps (ordered)

1. **Make plugin edits actually load (unblocks everything).** Determine the real
   rebuild trigger for the native `analysis_server_plugin` build cache. Prime
   suspect: it keys on the plugin package version, not source mtime. Test: bump
   `version:` in `pubspec.yaml`, `dart pub get`, restart analyzer; confirm
   `plugin.log` shows the new tier-cap line. Until this works, no fix can be
   verified or shipped.
2. **Verify whether the essential cap reduces RSS.** Once edits load (step 1),
   measure language-server RSS with the plugin capped to essential vs.
   uncapped, same project. If essential ≈ base → the cost is rule-count-driven
   and the in-process-essential + out-of-process-scan design is the fix. If
   essential still climbs → rule count is not the driver; go to step 3.
3. **Heap snapshot of the analysis-server isolate** to pin the dominant retained
   type. Capture: add `"dart.analyzerVmServicePort": 8956` to VS Code settings,
   reload, open Dart DevTools against that port → Memory → heap snapshot → sort
   by Retained Size. The top classes name the real target.
4. **Ship via release** once a fix is verified (version bump → consumers pin →
   analyzer rebuilds). Do not rely on hot-reload.

## Environment

- saropa_lints: workspace source (self-dogfood) / `14.2.4` downstream pin.
- Plugin model: native `analysis_server_plugin`.
- Triggering projects: saropa_lints itself; Saropa Contacts (`D:\src\contacts`, ~3957 files).
- OS: Windows 11 Pro (10.0.22631).

---

## Finish Report (2026-06-28)

### Defect

With the native `analysis_server_plugin` enabled, the Dart analysis server
(`dart.exe language-server`) grew to multiple GB over an editing session and
saturated RAM, hanging the editor on large projects. Because the plugin runs
in-process, executing a rule requires the analysis server to hold the file's
fully resolved element + AST model resident; running the full enabled rule set
across a large project (e.g. Saropa Contacts at ~3957 files, 1135 enabled rules)
kept the whole project's resolved model in the editor's own process. Base Dart
analysis measured 1.6–2.3 GB; the plugin added 1.5–3.4 GB and climbed toward a
~10 GB hang. The rule logic itself is cheap — the full set run out-of-process
(syntactic `parseString`, no resolution) peaks at ~46 MB — so the cost is the
in-process retention of resolved state, not the rules.

### Fix (shipped in 14.3.0)

Three changes bound the in-process footprint while preserving full coverage
out-of-process:

1. **In-editor tier default.** A new `reloadRuntimeTierCapForPlugin(projectRoot)`
   wraps `RuntimeTierCap._reload(..., RuleTier.essential)`; the config loader
   calls it on the plugin path. When a project has configured no explicit tier
   (no `SAROPA_TIER`, no `saropa_tier`/`runtime_tier` in
   `analysis_options*.yaml`), the in-process plugin caps to the essential set
   instead of resolving and running every enabled rule. An explicit tier always
   overrides the default. The out-of-process scan path
   (`reloadRuntimeTierCapFromProject`, no default cap) stays uncapped, so
   `dart run saropa_lints scan` still runs full coverage.
2. **RSS safety valve.** `MemoryPressureHandler.isOverHardLimit` (in
   `project_context_throttle_memory.dart`) reads real RSS via
   `ProcessInfo.currentRss`, self-throttled every 200 files with a 512 MB
   recovery hysteresis and a default 6144 MB limit
   (`SAROPA_LINTS_MAX_RSS_MB` override). Rule callbacks short-circuit while over
   the limit, so the plugin stops adding work before the server saturates.
3. **Cache eviction wired up.** The previously inert cache-management path is
   now started from `Plugin.start()`, registering evictable caches (e.g. the
   import-graph tracker) with priorities so pressure events reclaim them.

### Verification

Unit tests: `test/config/runtime_tier_cap_test.dart` extended with three cases
pinning the fix (plugin path defaults to essential when unconfigured; explicit
yaml tier overrides the default; scan path stays uncapped). All 8 tests pass.

Live: in-editor verification was impossible until publish because the analyzer
caches a compiled plugin build keyed by source path — source edits, version
bumps, pub.dev→path switches, and clearing `.plugin_manager` all reused a stale
build (a deeper incremental-compile kernel cache survives the directory clear).
After publishing 14.3.0 and installing it into Saropa Contacts, the contacts
analyzer log at `2026-06-28T17:20:11Z` showed
`Runtime tier cap: essential (from default in-process cap ...)` and
`enabled rule count 1135 → 281`, and the post-restart language-server RSS
settled at 1.79 GB — inside the plugin-OFF base range, no longer climbing.

### Companion / follow-up

`infra_native_plugin_resolution_audit.md` remains an open CPU/code-hygiene
work-list (per-site `.element`/`.staticType` narrowing). It was demoted this
investigation: resolution reduction is not the memory lever, so it does not
block this bug and is tracked separately.
