/**
 * Version-group derivation for the Manage Rule Packs UI.
 *
 * Some packages ship a base pack plus one or more version-locked companion packs
 * (e.g. `dio` + `dio_5`, `riverpod` + `riverpod_2` + `riverpod_3`, `app_links` +
 * `app_links_6`). At most one version of such a package's rules can apply to a
 * project at a time, so the companions form a mutually-exclusive group: enabling
 * one must turn the siblings off.
 *
 * The merge already enforces version *correctness* from the lockfile
 * (`staleVersionGatedCodes` in `lib/src/config/rule_packs.dart`). This module is
 * the UI-side grouping so the user can pick a version explicitly and the written
 * `rule_packs.enabled` list never holds two versions of the same package.
 *
 * A group is keyed by the shared dependency: the gate package of the version
 * companions (`dependencyGate.package`). Members are every pack that either
 * (a) carries a `dependencyGate` for that package, or (b) has an id equal to the
 * package (the ungated base pack). A "group" needs 2+ members — a lone gated
 * pack with no sibling (e.g. `collection_compat`, `go_router_6`,
 * `webview_flutter`) is just a normal toggle, not an exclusive choice.
 */

import type { RulePackDefinition } from './rulePackDefinitions';

/** One mutually-exclusive set of version variants for a single dependency. */
export interface VersionGroup {
  /** Shared dependency / gate package (e.g. `dio`, `riverpod`, `app_links`). */
  readonly dependency: string;
  /**
   * Member pack ids, ordered for display: the base pack (id === dependency)
   * first when present, then the version companions sorted by id. Selecting any
   * one member implies the others are off.
   */
  readonly packIds: readonly string[];
}

/**
 * Derive the version groups from the pack registry.
 *
 * Only dependencies with 2+ member packs are returned — a single gated pack is
 * not an exclusive choice. Result is ordered by dependency name for stable
 * rendering and stable tests.
 */
export function computeVersionGroups(
  defs: readonly RulePackDefinition[],
): VersionGroup[] {
  // Collect the candidate member ids per gate package. Using a Set keyed by id
  // means a base pack that itself carries a gate (e.g. `google_sign_in`,
  // `webview_flutter`, whose id equals its own gate package) is never counted
  // twice when it matches both the id-equals-dependency and the gate branch.
  const byDependency = new Map<string, Set<string>>();
  const add = (dependency: string, packId: string): void => {
    const set = byDependency.get(dependency);
    if (set) {
      set.add(packId);
    } else {
      byDependency.set(dependency, new Set([packId]));
    }
  };

  for (const def of defs) {
    if (def.dependencyGate) {
      add(def.dependencyGate.package, def.id);
    }
  }
  // A base pack whose id matches a gate package joins that package's group.
  for (const def of defs) {
    if (byDependency.has(def.id)) {
      add(def.id, def.id);
    }
  }

  const groups: VersionGroup[] = [];
  for (const [dependency, ids] of byDependency) {
    if (ids.size < 2) continue;
    // Base pack (id === dependency) first; companions follow alphabetically so
    // ordering does not depend on registry insertion order.
    const ordered = [...ids].sort((a, b) => {
      if (a === dependency) return -1;
      if (b === dependency) return 1;
      return a.localeCompare(b);
    });
    groups.push({ dependency, packIds: ordered });
  }

  groups.sort((a, b) => a.dependency.localeCompare(b.dependency));
  return groups;
}

/**
 * Map of pack id → the dependency of the version group it belongs to. Pack ids
 * that are not part of any multi-member version group are absent.
 */
export function versionGroupIndex(
  defs: readonly RulePackDefinition[],
): Map<string, string> {
  const index = new Map<string, string>();
  for (const group of computeVersionGroups(defs)) {
    for (const packId of group.packIds) {
      index.set(packId, group.dependency);
    }
  }
  return index;
}

/**
 * Given the current set of enabled pack ids and a pack just enabled, return the
 * enabled set with the newly-enabled pack's version siblings removed, so at most
 * one version of any package remains. A no-op when `enabledPackId` is not part of
 * a version group. The provider applies this on write so the exclusivity holds in
 * `rule_packs.enabled` even if the client UI is out of sync.
 */
export function enforceSingleVersion(
  defs: readonly RulePackDefinition[],
  enabledIds: readonly string[],
  enabledPackId: string,
): string[] {
  const index = versionGroupIndex(defs);
  const dependency = index.get(enabledPackId);
  if (dependency === undefined) return [...enabledIds];
  // Drop every other member of the same group; keep the just-enabled pack and
  // all unrelated packs untouched.
  return enabledIds.filter(
    (id) => id === enabledPackId || index.get(id) !== dependency,
  );
}
