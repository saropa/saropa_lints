# TODO — Rule metadata completeness residuals

**Created:** 2026-06-12
**Split from:** `OUTSTANDING_ITEMS_AUDIT.md` §4 (audit archived to `history/2026.06/2026.06.12/`)
**Subsystem:** rule metadata schema + lifecycle
**Source plan:** `history/2026.04/2026.04.28/PLAN_RULE_METADATA_AND_QUALITY.md`

The metadata schema, CWE/OWASP mapping, per-rule CI threshold gate
([bin/quality_gate.dart](../bin/quality_gate.dart)), and baseline comparison
([bin/baseline.dart](../bin/baseline.dart), [bin/diagnostic_baseline.dart](../bin/diagnostic_baseline.dart))
all shipped. These are the gaps.

## Status legend
- **[OPEN — verified]** getter exists, populated nowhere — confirmed in the 2026-06-11 audit.
- **[OPEN — needs per-item confirm]** triage against code before treating as done.

---

## 4.1 Accuracy measurement gate that reads `accuracyTarget` **[IN PROGRESS 2026-06-24]**

Premise correction: `accuracyTarget` is **not** unpopulated. It is a derived getter
([saropa_lint_rule.dart:2288](../lib/src/saropa_lint_rule.dart#L2288)) computed from `ruleType`, and
it is already serialized into [extension/media/rules_catalog.json](../extension/media/rules_catalog.json)
and read by the extension. So every rule with a `ruleType` already carries a target. The actual gap is
that **nothing measures a rule's real accuracy against that target** — the `*_expect_lint_contract_test.dart`
integrity tests only assert that a fixture *declares* an `expect_lint` marker; they never run the rule to
confirm it fires (or that it does not over-fire).

The consumer to build is an accuracy report/gate, not a metadata backfill.

### Design — `bin/accuracy_report.dart` (+ `lib/src/report/accuracy_report.dart` core)

Mirrors the `quality_gate` split: a testable library core plus a thin CLI that exits non-zero on breach
so CI can gate on it.

1. **Targets** — enumerate `allSaropaRules`; per rule read `rule.code.name` + `rule.accuracyTarget`
   (`expectZeroFalsePositives` for bug/codeSmell, `minTruePositiveRate` ~0.8 for vulnerability/securityHotspot).
2. **Ground truth** — parse every `// expect_lint: <rule>` marker under `example/lib/` (1,383 markers).
   Marker on its own line → diagnostic expected on the next line; trailing marker → same line. Comma-separated
   rule lists supported.
3. **Actual** — run `ScanRunner` (the [scan.dart](../lib/scan.dart) programmatic API) over the fixtures and
   collect `(rule, file, line)` per diagnostic. Use `runResolved()` so type/instance-creation rules fire.
4. **Per-rule tally** — TP = expected marker that fired; FN = expected marker that did not fire (under-firing);
   FP-candidate = diagnostic with no matching marker (over-firing).
5. **Compare to target & report** — bug/codeSmell: any FP-candidate is a target miss; vulnerability/securityHotspot:
   `TP/(TP+FN) < minTruePositiveRate` is a miss. Emit JSON + text summary; exit 1 on breach.

### FP attribution risk (decided)

A fixture file holds other rules' bad examples too, so an unmarked hit is only a true FP if the fixture's
`expect_lint` markers are exhaustive — which is not yet proven. Therefore:

- **FN (missed expected lint) → hard fail.** Unambiguous: the rule was asserted to fire and did not.
- **FP-candidate (unmarked hit) → report only, never hard-fail** until the fixture set is proven exhaustive.

Controlled by `--fail-on fn|fp|none` (default `fn`).

## 4.2 `certIds` sparse/empty **[OPEN — verified — by design]**

By design. Populate per-rule where a clear CERT/CWE mapping exists.

Action: opportunistic — when touching a security rule with an obvious CERT/CWE id, add it. No bulk
backfill pass warranted on its own.

## 4.3 Rule-lifecycle enforcement **[DONE 2026-06-12]**

`RuleStatus` (ready / beta / deprecated) exists. Confirmation found the enforcement was wired in the
interactive `init` path (`init_runner.dart`) but **missing in the headless `runWriteConfig` path** —
the one the VS Code extension and CI use — so a beta/deprecated rule sitting in a selected tier was
enabled in extension/CI-written configs while `init` excluded it.

Closed by extracting the filter into a shared `lifecycleFilteredRules(enabled)` helper
(`lib/src/init/rule_metadata.dart`) and applying it in both `init_runner` and `runWriteConfig`, so
the two paths can no longer drift. Beta/deprecated rules are excluded by default; an explicit
`analysis_options_custom.yaml` RULE OVERRIDES entry re-enables one. The runtime gate (the plugin
registers all rules and gates per-rule on the config's enabled set) needs no change — excluding the
rule from the generated config is sufficient. See the Finish Report below.

---

## Finish Report (2026-06-12)

### Lifecycle filter shared between the interactive and headless config paths

Rules carry a `RuleStatus` of `ready`, `beta`, or `deprecated`. Beta rules may carry more false
positives or change behavior, and deprecated rules are slated for removal, so neither should land in
a config the user did not hand-pick. The interactive `init` path applied this exclusion, but the
headless `runWriteConfig` path — the one the VS Code extension and CI use to generate
`analysis_options.yaml` — applied only the tier, stylistic, platform, and package filters. A beta or
deprecated rule that sat in a selected tier was therefore enabled in every extension- or CI-written
config, while `init` excluded the same rule: a silent divergence between the two generators.

#### What changed

- **`lifecycleFilteredRules(Set<String> enabled)`** (lib/src/init/rule_metadata.dart) — a shared
  helper returning the beta/deprecated subset of an enabled set. Both config generators call it, so
  the filter is defined once and cannot drift.
- **`runWriteConfig`** (lib/src/init/write_config_runner.dart) — applies the filter after the
  platform/package filters and before the plugins section is generated. Rules a user explicitly
  enabled via RULE OVERRIDES survive, because those overrides were already captured into
  `permanentOverrides` and are re-applied through `userCustomizations` at generation time.
- **`init_runner`** (lib/src/init/init_runner.dart) — its inline beta/deprecated loop was replaced
  with the shared helper; the per-status counts it logs are unchanged.
- An unused `analyzer_compat` import in `rule_metadata.dart` (pre-existing, surfaced by
  `dart analyze --fatal-infos` on the edited file) was removed so the touched file passes the CI
  gate. No symbol from it was referenced.

#### Verification

- `dart test test/init/write_config_test.dart`: 7 passing, including 2 new cases — a beta tier rule
  (`avoid_api_key_in_code`, the one beta rule, in `essentialRules`) is absent from `essential`
  output, and an explicit RULE OVERRIDES opt-in re-enables it.
- `dart analyze --fatal-infos`: "No issues found!" across the package (the CI gate the publish
  script mirrors).

#### Scope note

The runtime plugin registers every rule and gates per-rule on the config's enabled set, so excluding
a rule from the generated config is the complete fix — no analyzer-runtime change is required. This
closes §4.3; §4.1 (`accuracyTarget`) and §4.2 (`certIds`) remain consumer-gated and untouched.
