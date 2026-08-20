# PLAN: Two-lane architecture — light in-process lane + daemon lane

**Status: Implemented and RSS-validated (2026-08-20). Shipping as the
default in 15.2.0.**

Steps (a)–(e) below are landed and tested. Step (f) — the RSS measurement
that decides whether the light lane is kept — turned out to be measurable
locally after all (see acceptance criterion 1): `dart language-server`
against a path dependency on local source has no cache fence, only the
compiled VS Code extension does. **Result: light lane adds +0.6% RSS vs
+77.2% for the full lane. The memory claim is now a measured result, not a
hypothesis — `light` is now the default lane when the `lane:` key is absent**
(revised 2026-08-20; see acceptance criterion 1 for the decision history).
Remaining gap: no lane-picker UI in the extension — users who want `lane:
full` still set it by hand in `analysis_options.yaml`. Not a blocker for
15.2.0 since `light` now covers the config-untouched case, but tracked as
open work below.

Two corrections found during implementation, recorded so they are not
re-learned:

1. **`getRulesFromRegistry(const {})` does not build the registry.** The
   name→factory map is a lazy `final` accessed only inside that function's
   loop body, so an empty request initializes nothing — and lane membership,
   published as a side effect of that build, stayed empty. An empty lane set
   makes both the in-process gate and the daemon exclusion silently no-op.
   Fixed by an explicit `ensureRuleRegistryBuilt()`; every caller that needs
   membership without rule instances must use it.
2. **`thisOrAncestorOfType` is NOT an element API.** The audit's first pass
   flagged 7 light-lane rules for it; every call site parameterizes it with a
   syntax type and it only walks the AST parent chain. The rules were
   correctly declared and the audit pattern was wrong. It is excluded, with a
   do-not-re-add note, in `test/integrity/rule_lane_test.dart`.

**Origin:** handover `docs/handover/20260820_0520_hot_rules_47pct_two_lane_next.md`,
task 1 (user-approved direction). Successor to
[PLAN_scan_only_diagnostics.md](PLAN_scan_only_diagnostics.md), whose three lanes
all shipped 2026-08-15. Do not re-litigate the split — build it.

---

## What already exists (do not rebuild)

| Piece | Where | State |
|---|---|---|
| Scan daemon (warm `AnalysisContextCollection`, NDJSON stdin/stdout, RSS recycle ceiling, `listFiles`) | `bin/scan_daemon.dart`, `lib/src/scan/scan_daemon_args.dart` | Shipped |
| Extension daemon client/manager (spawn, respawn-on-recycle, warming state) | `extension/src/scanOnSave/scanDaemonClient.ts`, `scanDaemonManager.ts` | Shipped |
| Save-triggered scan → `DiagnosticCollection` (debounce, coalescing, severity display filter, re-filter cache) | `extension/src/scanOnSave/scanOnSaveController.ts` | Shipped |
| On-demand whole-project baseline scan (chunked, cancelable) | `extension/src/scanOnSave/baselineScanRunner.ts` | Shipped |
| In-process plugin default-OFF (commented `plugins:` block via sentinels; 14.5.9 OFF-sentinel kill switch) | `lib/src/init/config_writer.dart`, `extension/src/setup.ts`, `lib/src/native/config_loader.dart` | Shipped |
| Warm-collection scan methods | `ScanRunner.buildProjectCollection`, `runResolvedWithCollection` (`lib/src/scan/scan_runner.dart`) | Shipped |

## The remaining gap

Today the in-process choice is binary:

- **OFF (default):** zero in-process rules. Memory solved (analysis server at its
  ~3 GB no-plugin baseline on contacts). But no in-editor squiggles at all —
  feedback arrives only on save, ~seconds later, and only for saved files.
- **FULL (opt-in, uncomment the `plugins:` block):** all tier rules in-process.
  Measured 7.8–13.6 GB analysis-server RSS on contacts, OOM crashes
  (evidence table in PLAN_scan_only_diagnostics.md). The extension's
  severity toggles filter DISPLAY only — rules still execute in the server and
  the resolved element model still bloats. This is the configuration the
  maintainer is living with and the source of the "still slow and MEMORY
  bloated" complaint.

The two-lane architecture adds the missing middle configuration:

- **LIGHT (new):** in-process plugin runs ONLY severe + syntactic + cheap rules
  (in-editor squiggles for the issues that matter most, at near-baseline memory);
  the daemon lane delivers everything else on save, exactly as today.

## Why LIGHT should hold memory near the no-plugin baseline (the hypothesis)

Root cause of the in-process bloat (measured, PLAN_scan_only_diagnostics.md):
rules touching resolved types (308 call sites across 68 rule files) force the
analyzer's **lazy** cross-library type resolution, and the analyzer retains that
resolved model for the whole project. Lazy is the operative word: element models
materialize when accessed. A lane restricted to rules that never access
element/static-type APIs makes no such accesses, so the server should retain
only what it retains for its own diagnostics (~3 GB baseline on contacts).

This is a hypothesis until measured post-publish (the compiled-plugin cache
fence blocks local in-IDE verification). The plan's acceptance criterion 1 is
the test. If it fails — i.e. even a syntactic-only plugin bloats the server —
the LIGHT lane is dead and OFF remains the only sane default; record the
measurement and stop.

**Trap:** `usesTypeResolution` is a *declarative* override (default `false` at
`lib/saropa_lints.dart` `SaropaLintRule.usesTypeResolution`) — nothing enforces
that a rule declaring `false` truly never touches the element model. Step (a)
below audits the candidate set against actual element/staticType usage before
trusting the flag.

## Lane membership (census 2026-08-20, 2,332 rules, `d:\tmp\lane_census.dart`)

Selection predicate for the LIGHT lane:
`severity ∈ {ERROR, WARNING} && !usesTypeResolution && cost ∈ {trivial, low}`.

| Bucket | Count |
|---|---|
| ERROR, syntactic, trivial/low | 36 |
| WARNING, syntactic, trivial/low | 164 |
| **LIGHT lane total** | **200** |
| (variant: also allow `medium` cost) | 415 |
| All severe (warn/error) rules, any kind | 1,054 |

Ship 200 first. The `medium`-cost expansion (415) is a follow-up decision AFTER
criterion 1 passes at 200 — do not start there.

The predicate is defined ONCE in Dart (new `bool isLightLaneRule(SaropaLintRule)`
beside the tier sets in `lib/src/tiers.dart` or a sibling `lane.dart`) and used
by BOTH sides: the plugin's effective-rule computation AND the daemon/scan
exclusion (dedup below). No hand-maintained rule-name list, no TS-side copy —
the extension never needs to know which rules are in the lane.

## Design

### 1. Config key

`lane: light | full` under the plugin's YAML section in `analysis_options.yaml`
(same place `version`/`diagnostics`/tier config already live; parsed by
`loadNativePluginConfig` / `lib/src/native/config_loader.dart`). Absent key =
`full` (backward compatible: anyone who uncommented the block today keeps
today's behavior). OFF stays what it is: the sentinel-commented `plugins:`
block — `lane` is only consulted when the plugin loads at all.

### 2. Where the filter executes (fence-compliant)

**NOT at `Plugin.register`** — fenced: `register()` runs before the project
root is knowable; a prior register-time gate silently killed every rule for
file-picker users (doc comment at `registerSaropaLintRules`,
campaign-skill fence table). All rules stay registered unconditionally.

The gate lives where per-rule enablement already lives: `loadNativePluginConfig`
computes the effective enabled set once the root is known; when `lane: light`,
it intersects that set with the light-lane names
(`enabled = enabled ∩ {r | isLightLaneRule(r)}`). `_wrapCallback`
(`lib/src/native/saropa_context.dart`) then skips non-enabled rules exactly as
today — zero new hot-path cost, no new mechanism.

### 3. Dedup between lanes

With LIGHT active, a warning-level syntactic finding would otherwise appear
twice: once from the plugin (analyzer diagnostics) and once from the daemon
scan (extension `DiagnosticCollection`). Fix on the Dart side: the daemon scan
request gains an optional `"excludeLane": "light"` field
(`bin/scan_daemon.dart` → `ScanRunner`), which drops light-lane rules from the
scan's rule set via the same `isLightLaneRule` predicate. The extension sends
the field only when the workspace's `analysis_options.yaml` has the plugin
block live AND `lane: light` (it already parses that file for tier and
sentinel state). Plugin OFF or `lane: full` → field omitted → daemon scans
everything, exactly as today.

### 4. Extension surface

- Setup/enable flow offers the lane choice when (re)generating the `plugins:`
  block: OFF (default) / LIGHT / FULL, with the measured memory cost of each in
  the description. `config_writer.dart` writes `lane: light` into the block.
- All new strings through `l10n()` + `en.json` from the first commit
  (`.claude/rules/i18n.md`).

## Implementation steps

- **(a) Predicate + audit.** `isLightLaneRule` in Dart; unit test pinning the
  200-name set (snapshot test so membership changes are deliberate). Audit:
  cross-check the 200 candidates against actual element-model usage (grep their
  rule files for `staticType`, `element`, `declaredElement`,
  `elementFromAstIdentifier` etc.); any hit → fix the rule's
  `usesTypeResolution` declaration (which drops it from the lane) — the
  declaration bug is the defect, not the lane.
- **(b) Config.** `lane` key parsing in `config_loader.dart` + enabled-set
  intersection in `loadNativePluginConfig`; tests beside existing config-loader
  tests.
- **(c) Daemon exclusion.** `excludeLane` request field → `ScanRunner` rule-set
  filter; scan CLI flag `--exclude-lane light` for parity/testing; tests in
  `test/scan/`.
- **(d) Extension.** Lane detection from `analysis_options.yaml`, request field
  wiring in `scanDaemonClient.ts`/`scanDaemonManager.ts`, lane choice in the
  enable flow, i18n strings; `tsc` + extension test suite.
- **(e) Docs + CHANGELOG.** Lane table with measured numbers in README/doc;
  CHANGELOG bullet.
- **(f) Publish, then measure** (criterion 1) — **superseded, see below.**
  In-IDE behavior via the VS Code extension's compiled plugin is still
  unverifiable locally (the extension resolves saropa_lints from pub cache,
  not local source). But criterion 1 does NOT require the extension: it only
  requires `dart language-server` running against a project with a path
  dependency on local source, which has no such fence. Measured directly —
  see below. Everything else (in-editor UX polish, extension liveness gate)
  remains verified by unit tests + scan CLI only until publish.

## Acceptance criteria (fill with measurements)

1. **Memory (the decisive one) — MEASURED 2026-08-20, PASS.**
   `dart language-server --protocol=lsp` against `D:\src\contacts` (path
   dependency on local saropa_lints, uncommitted lane code), peak RSS after
   settling (script: `d:\tmp\measure_lane_rss.py`):

   | Scenario | Peak RSS | vs baseline |
   |---|---|---|
   | Plugin OFF (baseline) | 2,522 MB | — |
   | `lane: full` | 4,470 MB | +77.2% |
   | `lane: light` | 2,538 MB | **+0.6%** |

   Threshold was +15% (2,900 MB); light lane landed at +16 MB. Hypothesis
   confirmed — resolution-free rules do not trigger the cross-library element
   cascade. Full lane's +77% matches the OOM mechanism from
   PLAN_scan_only_diagnostics.md. **Decision (revised 2026-08-20): `light` is
   the default** when the `lane:` key is absent — the measurement makes it
   safe (near-zero memory cost), and users who already uncomment the
   `plugins:` block without an explicit `lane:` deserve in-editor squiggles by
   default rather than an easy-to-miss opt-in. `lane: full` remains available
   for anyone who wants full in-process coverage and accepts its cost.
2. In-editor squiggles without a save: a known warning-level syntactic
   violation (e.g. a platform-gate rule from the light set) squiggles once
   edits settle (`deferForRapidEdit`'s 2s window), not only after a save —
   not "while typing"; see the "live" correction in the 2026-08-20 handover.
3. No duplicates: the same violation never appears twice in the Problems panel
   (plugin + scan sources) with LIGHT active.
4. Daemon lane unchanged: save-to-Problems latency and baseline scan behave as
   before; scans with `excludeLane` report the full complement minus exactly
   the 200.
5. `lane: full` and OFF behave byte-identically to today (regression pin).

## Fences honored (campaign skill is authoritative)

- No register-time gating — filter at config/enabled-set level, gate at
  `_wrapCallback`.
- No analyzer dependency bump.
- No local in-IDE verification claims — post-publish only.
- No concurrent dart invocations from the package cwd.
- No rule-object leak hunting — the memory story is the retained resolved
  model, addressed structurally here.
- Balanced mode / RSS valve / tier caps: legacy, untouched, no further
  investment (per PLAN_scan_only_diagnostics.md).

## References

- `docs/handover/20260820_0520_hot_rules_47pct_two_lane_next.md` — origin task,
  47% per-rule reduction leaving the flat tail this plan addresses.
- `plans/PLAN_scan_only_diagnostics.md` — measured RSS table, lanes 1–3.
- `.claude/skills/saropa-lints-performance-campaign/` — fences, terminology.
- `d:\tmp\lane_census.dart` — throwaway census script behind the 200/415 counts.
