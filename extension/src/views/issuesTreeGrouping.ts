/**
 * Issues / Findings grouping mode identifiers (no VS Code dependency — safe for HTML builders and tests).
 */

/**
 * D10: Grouping modes for the Issues tree top level.
 * 'severity' is the default (Error/Warning/Info); other modes flatten
 * across severities and group by the chosen dimension.
 */
export type GroupByMode =
  | 'severity'
  | 'file'
  | 'impact'
  | 'rule'
  | 'owasp'
  | 'ruleType'
  | 'ruleStatus'
  | 'tier'
  | 'pack';

/** All supported Issues / dashboard grouping modes (single source of truth). */
export const VIOLATIONS_GROUP_BY_MODES: readonly GroupByMode[] = [
  'severity',
  'file',
  'impact',
  'rule',
  'owasp',
  'ruleType',
  'ruleStatus',
  'tier',
  'pack',
];
