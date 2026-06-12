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

## 4.1 `accuracyTarget` null for every rule **[OPEN — verified — consumer-gated]**

The getter exists; nothing populates it. Intentional until an audit/report consumes it.

Action: do **not** bulk-populate speculatively. Populate only when a consumer (a quality report or
gate that reads `accuracyTarget`) is built — populate as part of that consumer's work.

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
