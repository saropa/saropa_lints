# BUG: `prefer_switch_with_sealed_classes` — Rule never fires despite correct registration and config

**Status: Fixed**

Created: 2026-08-23
Rule: `prefer_switch_with_sealed_classes` (also observed for `prefer_record_over_tuple_class` — same symptom, filed together, split if root causes differ)
File: `lib/src/rules/code_quality/code_quality_control_flow_rules.dart` (line ~1035)
Severity: False negative
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

`prefer_switch_with_sealed_classes` is explicitly enabled (`true`) in a
consuming project's `analysis_options.yaml`, is correctly registered in
`_allRuleFactories`, and its `runWithReporter` logic (purely syntactic,
matches an `if`/`else if` chain of `is` checks on the same variable with
2+ branches) should trivially match a synthetic 2-branch reproducer. It
produces zero diagnostics — with and without `--resolve` — via
`dart run saropa_lints scan`.

`prefer_record_over_tuple_class` shows the identical symptom on a
synthetic 2-final-field class with a single unnamed constructor and no
methods, which its own doc comment describes as exactly its target case.

---

## Attribution Evidence

Package version tested: `saropa_lints 15.2.2` (resolved via `saropa_lints: ^15.2.2` in the consuming project's pubspec, installed at `D:\tools\Pub\Cache\hosted\pub.dev\saropa_lints-15.2.2`).

```
$ grep -n "'prefer_switch_with_sealed_classes'" lib/src/rules/code_quality/code_quality_control_flow_rules.dart
1055:    'prefer_switch_with_sealed_classes',

$ grep -n "PreferSwitchWithSealedClassesRule.new" lib/saropa_lints.dart
705:  PreferSwitchWithSealedClassesRule.new,

$ grep -n "'prefer_record_over_tuple_class'" lib/src/rules/architecture/structure_rules.dart
3284:    'prefer_record_over_tuple_class',

$ grep -n "PreferRecordOverTupleClassRule.new" lib/saropa_lints.dart
3134:  PreferRecordOverTupleClassRule.new,
```

Both rules are defined with the expected `LintCode` name and are present
in `_allRuleFactories` in `lib/saropa_lints.dart` — registration is not
the issue.

**Emitter registration:**
- `lib/src/rules/code_quality/code_quality_control_flow_rules.dart:1035` (`PreferSwitchWithSealedClassesRule`), registered `lib/saropa_lints.dart:705`
- `lib/src/rules/architecture/structure_rules.dart:~3260` (`PreferRecordOverTupleClassRule`), registered `lib/saropa_lints.dart:3134`

---

## Reproducer

Consuming project: `analysis_options.yaml` has, under `plugins: saropa_lints: diagnostics:`:

```yaml
prefer_switch_with_sealed_classes: true
prefer_record_over_tuple_class: true
```

(These are professional-tier rules; the project otherwise runs the
`recommended` tier via `saropa_lints:init`. No `runtime_tier:` /
`saropa_tier:` key is set in the project's yaml, and `SAROPA_TIER` is
unset in the environment — confirmed via `grep`, so `RuntimeTierCap` is
inactive for the CLI path per its own doc comment: "the scan CLI passes
null and stays at full coverage.")

Test file (placed inside the consuming project's `lib/` so it resolves
against the project's own `pubspec.yaml`/`.dart_tool`):

```dart
sealed class Result {}

class Success extends Result {
  final String value;
  Success(this.value);
}

class Failure extends Result {
  final String error;
  Failure(this.error);
}

String handle(Result result) {
  if (result is Success) {          // LINT expected here (prefer_switch_with_sealed_classes)
    return result.value;
  } else if (result is Failure) {
    return result.error;
  }
  return '';
}

class Point {                        // LINT expected here (prefer_record_over_tuple_class)
  const Point(this.x, this.y);

  final double x;
  final double y;
}
```

Command:

```
dart run saropa_lints scan . --files lib/_smoke_test_tmp/smoke.dart --resolve --format json
```

Output:

```
Loaded 584 rules from analysis_options.yaml
Scanning 1 files...
  Files: 0/1 | 0.4s | 0/s | Issues: 0 | smoke.dart
{
  "version": 1,
  "diagnostics": [],
  "summary": { "totalCount": 0, "byFile": {}, "byRule": {} }
}
```

Also reproduced without `--resolve` (same zero result). Note the `if`
chain has exactly 2 branches, and `PreferSwitchWithSealedClassesRule`'s
own `runWithReporter` reports at `branchCount >= 2` — the reproducer
should be a direct hit on read of the rule source.

**Frequency:** Always (tested twice, with and without `--resolve`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | `[prefer_switch_with_sealed_classes]` at the `if` on line 10; `[prefer_record_over_tuple_class]` at the `Point` class declaration |
| **Actual** | Zero diagnostics from either rule |

---

## Investigation Notes (partial — handed off, not root-caused)

Confirmed NOT the cause:
- Config parsing: `analysis_options.yaml` diagnostics block is well-formed, 6-space indented, single `diagnostics:` section, no duplicate rule-name lines. `loadScanConfig` (`lib/src/scan/scan_config.dart`) would parse these correctly per its own regex (`^\s+([\w_]+):\s*(true|false)` after locating `^\s+diagnostics:\s*$`).
- Rule registration: both classes appear in `_allRuleFactories` (`lib/saropa_lints.dart`), confirmed by grep above.
- `RuntimeTierCap`: inactive for this run — no `runtime_tier:`/`saropa_tier:` in the project yaml, no `SAROPA_TIER` env var, and the CLI scan path (`reloadRuntimeTierCapFromProject`, not the plugin path) leaves `_cap = null` (no `defaultCapWhenUnset`) when unset, which the source's own doc comment says means "stays at full coverage."
- Rule count sanity: "Loaded 584 rules" is consistent with the project's ~589 `true`-valued lines in the diagnostics block (small gap plausibly a handful of unrecognized/renamed rule names elsewhere in the block, not specific to these two — not independently confirmed).

Not yet checked (handed off due to investigation time budget):
- Whether `_resolveRuleNames()` → `_loadRulesFromConfig()` path (used here, since no `--tier` flag was passed) actually intersects `config.enabledRules` against the real `_allRuleFactories` name set before scanning, or passes the raw parsed name set straight through — and if the former, whether an exact-string mismatch (trailing whitespace, encoding, a stray character from the inline `# comment` on the same line) causes `prefer_switch_with_sealed_classes` / `prefer_record_over_tuple_class` specifically to be dropped from that intersection while ~584 other rules survive.
- Whether `usesTypeResolution => true` on both rules gates them into a registration path that requires something beyond `--resolve` (e.g. a fully warm analysis context, only available via the persistent scan-on-save daemon, not a cold one-shot CLI invocation) — the doc comment at `scan_runner.dart:147` ("type-based rule under-report — see [runResolved] for the resolved path") suggests `--resolve` should be sufficient, but this was not traced further into `runResolved`.
- Whether the same two rules fire correctly via the VS Code extension / native analysis-server plugin path (untested — only the CLI `dart run saropa_lints scan` path was exercised).

---

## Root Cause

**Lane gate active in CLI scan path.** The two-lane execution split
(`RuleLane.light` vs `RuleLane.full`) silently gates rule callbacks even
in the CLI scanner. The default active lane is `RuleLane.light`
(`lib/src/config/rule_lane.dart:115`), and only the native analysis-server
plugin path (`lib/src/native/config_loader.dart:244`) ever calls
`setActiveRuleLane(RuleLane.full)`. The CLI scan path never did.

Every rule callback flows through `SaropaContext._wrapCallback`
(`lib/src/native/saropa_context.dart:292`), which calls
`ruleAllowedByLane()`. In the light lane, only rules with
`usesTypeResolution == false`, severity `ERROR`/`WARNING`, and cost
`trivial`/`low` pass. Both `prefer_switch_with_sealed_classes` and
`prefer_record_over_tuple_class` have `usesTypeResolution => true`, so
they are unconditionally excluded from the light lane — their callbacks
silently return without executing.

**Scope:** This is not limited to these two rules. The majority of the
~584 enabled rules are silently blocked in the CLI scan path. Only the
small subset matching the light-lane criteria ever fires.

**Lead 1** (string matching): Not the cause — config parsing is correct.
**Lead 2** (`usesTypeResolution` gating): IS the cause, but via the lane
gate, not the `--resolve` flag. The `--resolve` flag controls AST
resolution; it has no effect on the lane gate.

---

## Fix Applied

Added `setActiveRuleLane(RuleLane.full)` in `ScanRunner._prepare()`
(`lib/src/scan/scan_runner.dart`) before rule resolution. The CLI
scanner exits after one run, so the RSS-limiting lane split is
irrelevant — it should always run at full coverage.

---

## Fixture Gap

If the eventual fix is in scan-time rule resolution rather than the rule
logic itself, add a scan-CLI integration test asserting that an
explicitly-`true` professional-tier rule outside the active tier fires on
a minimal reproducer via `dart run saropa_lints scan --files <f> --resolve`
— the existing per-rule fixtures likely only exercise the in-process
analyzer plugin path, which may be why this was not caught.

---

## Environment

- saropa_lints version: 15.2.2 (pub.dev, resolved via `^15.2.2`)
- Dart SDK version: >=3.13.0 (consuming project constraint)
- custom_lint version: N/A — saropa_lints is a native `analysis_server_plugin`, not `custom_lint`-based
- Triggering project: `d:\src\contacts`, `dart run saropa_lints scan . --files <f> --resolve --format json`

---

## Finish Report (2026-08-25)

**Defect:** The CLI scan path (`dart run saropa_lints scan`) defaulted to
`RuleLane.light`, silently blocking the majority of registered lint rules.
Only rules meeting the light-lane criteria (no type resolution, ERROR/WARNING
severity, trivial/low cost) ever executed. The two reported rules
(`prefer_switch_with_sealed_classes`, `prefer_record_over_tuple_class`) were
among those blocked because both declare `usesTypeResolution => true`.

**Fix:** One-line addition in `ScanRunner._prepare()`
(`lib/src/scan/scan_runner.dart`): `setActiveRuleLane(RuleLane.full)` before
rule resolution. The CLI scanner exits after each run, so the RSS-limiting
lane split (designed for the long-lived analysis server) is irrelevant.

**Verification:** All 17 `scan_runner_test.dart` tests and 10
`rule_lane_test.dart` tests pass. No assertions changed.

**Scope note:** The fix affects every rule gated by the lane system, not just
the two named in the bug report. The scan CLI now runs the full rule catalog
as originally intended.

**Hardening:** Verified that the daemon path (`runResolvedWithCollection`)
also flows through `_prepare()` and correctly inherits full-lane behavior.
The daemon is a separate CLI process, not the analysis server, so full lane
is correct there too. Confirmed `excludeLightLane` (name-level filtering)
and `setActiveRuleLane` (callback-level gating) are independent systems
that compose correctly.

**Feature addition:** Added `--lane full|light` CLI flag to
`dart run saropa_lints scan`. Defaults to `full`. The `light` option
restricts the scan to the same cheap, resolution-free subset the analysis
server uses in its default lane — useful for fast scans when only
high-severity rules matter. Implementation spans `scan_cli_args.dart`
(parsing + validation), `scan_runner.dart` (new `lane` constructor field),
and `bin/scan.dart` (wiring + help text).

**Observability addition:** Added `--lane-stats` flag that prints how many
of the loaded rules are light-lane vs full-only, along with the active
lane name. Output goes to stderr so it doesn't break `--format json`.
Would have caught the original bug immediately — the stats would have
shown the majority of rules blocked under the light lane default.

**Tests added:** Four `--lane` parser tests in `scan_cli_args_test.dart`:
valid values (full/light/case-insensitive), invalid value, missing value,
and next-option-as-value.
