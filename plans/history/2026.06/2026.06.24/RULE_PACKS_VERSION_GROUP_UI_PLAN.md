# Rule Packs — Version-Group UI Plan

Status: Complete (2026-06-24)
Date: 2026-06-22

## Context

The additive-pack work shipped (see the finish report in
`plans/history/2026.06/2026.06.22/RULE_PACKS_EXPANSION_PLAN.md`). Version
correctness is already enforced by the merge: `staleVersionGatedCodes` in
`lib/src/config/rule_packs.dart` drops a version-locked rule (e.g. a dio 5 rule)
when the lockfile/pubspec proves the project is not on that version. This plan is
the remaining **UI** layer — a manual override so a user can pick a package
version explicitly, not just have it inferred from the lockfile.

This piece was deferred because it is a webview restructure with no test path
runnable in the current environment; the merge already delivers correct behavior
without it.

## Goal

In the Manage Rule Packs webview, render each package that has version variants
(base pack + version companions, e.g. `dio` + `dio_5`, `riverpod` +
`riverpod_2` + `riverpod_3`, `app_links` + `app_links_6`) as an **exclusive
group**: the user picks one version (or none); selecting one visually turns the
siblings off.

## Inputs that already exist

- `kRulePackDependencyGates` (`lib/src/config/rule_packs.dart`) — maps each
  version-companion pack to its dependency + semver constraint. Packs sharing a
  `dependency` form one version group.
- `pickOne` radio rendering — `_buildStylisticGroup` in
  `extension/src/rulePacks/rulePacksWebviewProvider.ts` already renders a
  mutually-exclusive radio set with a "None" option; reuse the markup/CSS.
- Toggle handler + YAML writer — `_handleToggle` /
  `writeRulePacksEnabled` (`rulePackYaml.ts`).

## Work

1. **Group model.** Derive version groups from `kRulePackDependencyGates`
   (packs grouped by `dependency`, plus the ungated base pack of the same name).
   Expose the grouping to the webview (generator emits it, or the provider
   computes it from the registry).
2. **Render.** In the ecosystem pack table, replace the separate version-companion
   rows with one radio group per package, reusing the `pickOne` markup. Show the
   resolved lockfile version as the default selection.
3. **Client script.** Radio change sends a toggle that enables the chosen version
   pack and disables its siblings in the same group.
4. **Provider/YAML.** Enforce that at most one version pack per group is written
   to `rule_packs.enabled`.
5. **l10n.** Any new visible strings go through `l10n()` + `en.json`.
6. **Tests.** Extension tests under `test/rulePacks/` for grouping + exclusive
   selection.

## Non-goals

- No change to the merge — version correctness already lands from the lockfile.
- No new lint rules.

## Finish Report (2026-06-24)

The Manage Rule Packs webview now treats a package's version variants as a
mutually-exclusive choice. Packs that target different majors of one dependency
(`dio` + `dio_5`, `riverpod` + `riverpod_2` + `riverpod_3`, `app_links` +
`app_links_6`, `file_picker` + `file_picker_10` + `file_picker_12`,
`google_sign_in` + `google_sign_in_7`, and the rest) previously rendered as
independent checkbox rows, so `rule_packs.enabled` could list two versions of the
same package at once. The variants are now grouped and pick-one.

### What changed

- **New module `extension/src/rulePacks/versionGroups.ts`** — pure derivation of
  version groups from `RULE_PACK_DEFINITIONS`. A group is keyed by the shared
  dependency (`dependencyGate.package`) and contains every pack that gates on that
  package plus the same-named base pack; a dependency with only one member (e.g.
  `collection_compat`, `go_router_6`, `webview_flutter`) is not a group and stays a
  plain toggle. A base pack that carries its own gate (`google_sign_in`,
  `webview_flutter`) is counted once, not twice. Exposes `computeVersionGroups`,
  `versionGroupIndex`, and `enforceSingleVersion`.
- **Rendering (`rulePacksWebviewProvider.ts`)** — each version-group member row
  carries `data-vgroup="<dependency>"` and a "Pick one version" tag, in both the
  detected ("For your project") table and the domain accordions, since both use the
  shared `_buildPackRow`.
- **Exclusivity enforcement** — `_handleToggle` runs `enforceSingleVersion` on
  write, so enabling one variant drops the package's other variants from
  `rule_packs.enabled` even if the client UI is stale. The client script
  (`configDashboardScript.ts`) also visually clears sibling checkboxes for
  immediate feedback.
- **l10n** — `packs.versionGroup.tag` / `packs.versionGroup.tooltip` added to
  `en.json`; CSS `.pack-vgroup` added to `configDashboardStyles.ts`.
- **Tests** — `extension/src/test/rulePacks/versionGroups.test.ts` (15 cases):
  synthetic registry pins the grouping edge cases (base + companion, base + two
  companions, self-gated base, lone gated pack, ungrouped pack) and the
  exclusivity contract; the live registry confirms the real multi-version packages
  group correctly and every member id resolves.

### Deviation from the original plan

The plan specified rendering each group as a radio set reusing the stylistic
`pickOne` markup. The screen had since been reworked into per-domain accordion
tables where every pack row uses a slider toggle; mixing raw radios into some rows
reads as broken and gives no "none" affordance (a radio cannot be un-checked by
clicking it). The implementation keeps the slider toggle and enforces the
pick-one contract in the client and on write instead. The behavioral contract —
exactly one version of a package enabled at a time, siblings turned off — is
identical.

### Not done here

The two new `en.json` keys are English-only until the translation pipeline is run
(`generate_locales.py --translate` / `generate_translations.py`); that is a
separate, separately-authorized step and the publish coverage gate
(`--fail-on-missing`) will flag the gap until then.
