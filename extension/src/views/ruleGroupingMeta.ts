/**
 * Tier / pack grouping metadata for the Findings dashboard and Issues tree.
 *
 * Both dimensions resolve client-side from the generated registries
 * (ruleTierDefinitions / rulePackDefinitions), so grouping by tier or pack
 * works on an existing violations.json with no plugin re-scan — the same way
 * OWASP grouping reads the embedded per-violation `owasp` field. tiers.dart and
 * the pack registry are the single sources of truth; these registries are their
 * generated TS projections (regenerate with tool/generate_rule_pack_registry.dart).
 */

import { RULE_PACK_DEFINITIONS } from '../rulePacks/rulePackDefinitions';
import { RULE_TIER_BY_CODE } from '../rulePacks/ruleTierDefinitions';

/** Group key for a rule whose tier is absent from the registry (defensive). */
export const TIER_UNKNOWN = 'unknown';
/** Group key for a finding whose rule belongs to no pack. */
export const PACK_NONE = 'No pack';

/**
 * Introducing tier for [rule] (the lowest tier that enables it). Returns
 * [TIER_UNKNOWN] when the rule is missing from the generated map — e.g. a
 * report produced by a newer plugin than the extension, carrying a rule the
 * bundled registry has not learned yet.
 */
export function tierForRule(rule: string): string {
  return RULE_TIER_BY_CODE[rule] ?? TIER_UNKNOWN;
}

/**
 * Reverse index ruleCode → pack labels, built once from RULE_PACK_DEFINITIONS.
 * A rule can belong to several packs (e.g. a security rule that is also in a
 * package pack), so each rule maps to an array — pack grouping is multi-key,
 * matching OWASP. Pack membership here is ROSTER membership: SDK / dependency
 * gates are not applied, because a finding only exists if the rule already
 * fired, so the pack is relevant regardless of gate state.
 *
 * Keyed by the pack's human label (not its id) so it can be used directly as
 * the group-row display string, mirroring how OWASP keys by category id.
 */
let _packsByRule: Map<string, string[]> | undefined;

function packsByRule(): Map<string, string[]> {
  if (_packsByRule) return _packsByRule;
  const index = new Map<string, string[]>();
  for (const pack of RULE_PACK_DEFINITIONS) {
    for (const code of pack.ruleCodes) {
      const list = index.get(code);
      if (list) {
        // A rule listed twice under one pack (should not happen) must not
        // produce a duplicate group key for that finding.
        if (!list.includes(pack.label)) list.push(pack.label);
      } else {
        index.set(code, [pack.label]);
      }
    }
  }
  // Stable, deterministic group ordering: sort each rule's pack labels.
  for (const list of index.values()) list.sort();
  _packsByRule = index;
  return index;
}

/**
 * Pack labels for [rule]. Returns `[PACK_NONE]` when the rule is in no pack so
 * every finding lands in exactly one group when none applies (callers can group
 * unconditionally without a separate empty check).
 */
export function packsForRule(rule: string): string[] {
  const packs = packsByRule().get(rule);
  return packs && packs.length > 0 ? packs : [PACK_NONE];
}
