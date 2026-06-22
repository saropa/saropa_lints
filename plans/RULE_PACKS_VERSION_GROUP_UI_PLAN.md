# Rule Packs — Version-Group UI Plan

Status: Open (split from RULE_PACKS_EXPANSION_PLAN, 2026-06-22)
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
