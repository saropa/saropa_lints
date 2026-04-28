/**
 * Rule metadata for tooltips and docs. Used by the Issues tree violation tooltip (W3).
 * Optional short descriptions can be added here; otherwise tooltip shows rule name + link.
 */

/** Base URL for rule documentation (ROADMAP and repo). */
export const RULE_DOC_BASE_URL = 'https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md';
let relatedRulesByRule: Record<string, string[]> = {};
let conflictingRulesByRule: Record<string, string[]> = {};
let supersedesRulesByRule: Record<string, string[]> = {};
let tagsByRule: Record<string, string[]> = {};

export function setRelatedRulesMetadata(
  byRule: Record<string, string[]> | undefined,
): void {
  relatedRulesByRule = byRule ?? {};
}

export function getRelatedRules(ruleName: string): string[] {
  return relatedRulesByRule[ruleName] ?? [];
}

export function setConflictingRulesMetadata(
  byRule: Record<string, string[]> | undefined,
): void {
  conflictingRulesByRule = byRule ?? {};
}

export function getConflictingRules(ruleName: string): string[] {
  return conflictingRulesByRule[ruleName] ?? [];
}

export function setSupersedesRulesMetadata(
  byRule: Record<string, string[]> | undefined,
): void {
  supersedesRulesByRule = byRule ?? {};
}

export function getSupersedesRules(ruleName: string): string[] {
  return supersedesRulesByRule[ruleName] ?? [];
}

export function setRuleTagsMetadata(
  byRule: Record<string, { tags?: string[] }> | undefined,
): void {
  if (!byRule) {
    tagsByRule = {};
    return;
  }
  tagsByRule = Object.fromEntries(
    Object.entries(byRule).map(([rule, metadata]) => [
      rule,
      Array.isArray(metadata.tags) ? metadata.tags.filter((t): t is string => typeof t === 'string') : [],
    ]),
  );
}

export function getSameTagRules(ruleName: string, limit = 5): string[] {
  const sourceTags = new Set(tagsByRule[ruleName] ?? []);
  if (sourceTags.size === 0) return [];
  return Object.keys(tagsByRule)
    .filter((candidate) => candidate !== ruleName)
    .map((candidate) => {
      const tags = tagsByRule[candidate] ?? [];
      const overlap = tags.reduce((acc, tag) => acc + (sourceTags.has(tag) ? 1 : 0), 0);
      return { candidate, overlap };
    })
    .filter((row) => row.overlap > 0)
    .sort((a, b) => b.overlap - a.overlap || a.candidate.localeCompare(b.candidate))
    .slice(0, limit)
    .map((row) => row.candidate);
}

/**
 * Optional one-line description for a rule. Returns undefined if not known.
 * Extension can ship a small map; for now we rely on message + "More" link.
 */
export function getRuleDescription(_ruleName: string): string | undefined {
  return undefined;
}

/**
 * URL to point users to rule documentation (ROADMAP or search).
 * @param _ruleName Reserved for future rule-specific anchors/fragments.
 */
export function getRuleDocUrl(_ruleName: string): string {
  return RULE_DOC_BASE_URL;
}
