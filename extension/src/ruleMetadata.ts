/**
 * Rule metadata for tooltips and docs. Used by the Issues tree violation tooltip (W3).
 * Optional short descriptions can be added here; otherwise tooltip shows rule name + link.
 */

/** Base URL for rule documentation (ROADMAP and repo). */
export const RULE_DOC_BASE_URL = 'https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md';
let relatedRulesByRule: Record<string, string[]> = {};
let conflictingRulesByRule: Record<string, string[]> = {};

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
