/**
 * Read reports/.saropa_lints/violations.json and expose summary + violations.
 */

import * as path from 'path';
import * as fs from 'fs';

export interface Violation {
  file: string;
  line: number;
  rule: string;
  message: string;
  severity?: string;
  impact?: string;
  correction?: string;
}

export interface BySeverity {
  error?: number;
  warning?: number;
  info?: number;
}

export interface ByImpact {
  critical?: number;
  high?: number;
  medium?: number;
  low?: number;
  opinionated?: number;
}

/** Per-rule violation counts for triage grouping (e.g. Group A/B/C/D by volume). */
export interface IssuesByRule {
  [rule: string]: number;
}

export interface ViolationsData {
  violations: Violation[];
  summary?: {
    totalViolations?: number;
    filesAnalyzed?: number;
    filesWithIssues?: number;
    bySeverity?: BySeverity;
    byImpact?: ByImpact;
    /** Rule name → issue count. Use for triage grouping. */
    issuesByRule?: IssuesByRule;
  };
  config?: {
    tier?: string;
    enabledRuleCount?: number;
    /** Full list of enabled rule names. */
    enabledRuleNames?: string[];
    /** Stylistic rule names (opt-in). Present when export includes rule metadata. */
    stylisticRuleNames?: string[];
  };
}

export function getViolationsPath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'reports', '.saropa_lints', 'violations.json');
}

export function readViolations(workspaceRoot: string): ViolationsData | null {
  const p = getViolationsPath(workspaceRoot);
  if (!fs.existsSync(p)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(p, 'utf-8'));
    const summary = raw.summary;
    return {
      violations: Array.isArray(raw.violations) ? raw.violations : [],
      summary: summary
        ? {
            totalViolations: summary.totalViolations,
            filesAnalyzed: summary.filesAnalyzed,
            filesWithIssues: summary.filesWithIssues,
            bySeverity: summary.bySeverity,
            byImpact: summary.byImpact,
            issuesByRule:
              summary.issuesByRule &&
              typeof summary.issuesByRule === 'object' &&
              !Array.isArray(summary.issuesByRule)
                ? summary.issuesByRule
                : undefined,
          }
        : undefined,
      config: raw.config
        ? {
            tier: raw.config.tier,
            enabledRuleCount: raw.config.enabledRuleCount,
            enabledRuleNames: Array.isArray(raw.config.enabledRuleNames)
              ? raw.config.enabledRuleNames
              : undefined,
            stylisticRuleNames: Array.isArray(raw.config.stylisticRuleNames)
              ? raw.config.stylisticRuleNames
              : undefined,
          }
        : undefined,
    };
  } catch {
    return null;
  }
}

export function hasViolations(workspaceRoot: string): boolean {
  const data = readViolations(workspaceRoot);
  if (!data) return false;
  return (data.summary?.totalViolations ?? data.violations.length) > 0;
}
