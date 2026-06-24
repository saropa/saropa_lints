# Findings dashboard — group by Tier and Pack(s)

The Findings dashboard and Issues view could group findings by severity, file,
impact, rule, OWASP, rule type, and rule status, but not by lint tier or by rule
pack — the two axes that map findings onto the project's configuration surface.
This change adds Tier and Pack(s) as grouping dimensions, sourced entirely from
bundled rule metadata so they work on an existing report without re-analysis.

## Finish Report (2026-06-23)

### Scope

VS Code extension (TypeScript) plus one Dart tooling edit (the rule-pack
registry generator). No lint rule, analyzer, `tiers.dart`, or `example/` change.

### Problem

`GroupByMode` exposed seven dimensions. A `Violation` carried `impact`, `owasp`,
`metadata.ruleType`, and `metadata.ruleStatus`, but no tier or pack information,
so neither could be grouped on. Pack membership was available client-side via the
generated `RULE_PACK_DEFINITIONS` (`packId → ruleCodes`), but no per-rule tier map
existed on the extension side — the export's `config.tier` is the project's single
selected tier, not a per-rule property.

### Approach

Tier and pack are resolved client-side from generated registries, mirroring how
OWASP grouping reads the embedded per-violation `owasp` field. This needs no
plugin re-scan and works on a stale `violations.json`.

- **Tier source (new generated registry).** `tool/generate_rule_pack_registry.dart`
  gained `_writeRuleTierDefinitionsTs`, which projects `tiers.dart` into
  `extension/src/rulePacks/ruleTierDefinitions.ts` as
  `RULE_TIER_BY_CODE: Record<ruleCode, introducingTier>` for all defined rules
  (2325 at time of writing). The introducing tier is the lowest cumulative tier
  whose `*OnlyRules` set contains the rule (essential → recommended → professional
  → comprehensive → pedantic; `stylistic` sits outside the chain). `tiers.dart`
  remains the single source of truth; the TS file is its generated projection,
  regenerated alongside the pack registry. Running the generator produced only the
  new file — no churn to the other generated artifacts.
- **Pack source (existing registry).** Pack grouping reverse-indexes
  `RULE_PACK_DEFINITIONS` into `ruleCode → packLabels[]`.

An alternative — adding `tier` to the Dart per-rule metadata export snapshot — was
rejected: it would require a re-scan to populate and a Dart runtime change, whereas
the generated registry is symmetric with how packs already work and has neither
cost.

### Changes

- `extension/src/views/ruleGroupingMeta.ts` (new) — shared helpers `tierForRule()`
  (single key; `unknown` fallback for a rule absent from the registry, e.g. a
  report from a newer plugin than the extension) and `packsForRule()` (multi-key,
  memoized reverse index, sorted labels, `No pack` fallback). Pack membership is
  roster membership; SDK/dependency gates are intentionally not applied because a
  finding only exists if the rule already fired.
- `issuesTreeGrouping.ts` — added `'tier'` and `'pack'` to the `GroupByMode` union
  and `VIOLATIONS_GROUP_BY_MODES` (the single source of truth shared with the
  dashboard and Issues tree).
- `issuesTreeModel.ts` and `issuesTree.ts` — both `extractViolationGroupKeys` /
  `extractGroupKeys` copies emit tier (single) and pack (multi) keys; both
  `formatGroupLabel` copies title-case tier ids and pass pack labels through.
- `issuesTree.ts` — a duplicate local `GroupByMode` definition that had diverged
  from the shared one (the proximate cause of a compile mismatch) was replaced with
  a re-export of the single source, so future modes flow to every consumer without
  editing a second list.
- `violations-dashboard-top.ts` — `groupBySelectOptions` labels record gains tier
  and pack (localized).
- `issuesViewCommands.ts` — the group-by quick-pick gains Tier and Pack(s) entries
  (matching the surrounding non-localized quick-pick convention).
- `extension/src/i18n/locales/en.json` — `findingsDash.groupBy.tier` /
  `.pack` keys.
- `extension/tsconfig.test.json` — added the new test file to the explicit include
  allowlist (this config uses an enumerated include list, not a glob).

### Multi-key semantics

Pack grouping is multi-key by design, exactly like OWASP: a rule belonging to N
packs appears under all N group rows, so group totals can exceed the finding count.
This is consistent with the existing OWASP behavior and is documented at the helper.

### Tests

`extension/src/test/views/ruleGroupingMeta.test.ts` (new) pins: tier single-key and
its `unknown` fallback, pack multi-key (asserted against a registry-derived
multi-pack rule, with sorted labels) and its `No pack` fallback, and agreement
between `extractViolationGroupKeys` and the helpers. The pack assertions derive
their fixtures from the registries themselves rather than hardcoded rule names, so
they survive rules moving between tiers/packs. 6 passing in isolation; the touched
view files' tests (`ruleGroupingMeta`, `issuesTree`, `violationsDashboardHtml`)
run 59 passing together. Extension `check-types` is clean.

### Localization follow-up (not run)

The two new `en.json` keys leave the translated locale catalogs stale. Catalog
regeneration is performed by the NLLB-backed
`extension/scripts/generate_translations.py`, which is not run as part of this
change; the publish coverage gate (`generate_locales.py --fail-on-missing`) blocks
a release with English placeholders, so the gap cannot ship silently.
