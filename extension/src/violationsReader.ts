/**
 * Read reports/.saropa_lints/violations.json and expose summary + violations.
 */

import * as path from 'path';
import * as fs from 'fs';

export interface OwaspData {
  mobile?: string[];
  web?: string[];
}

export interface AccuracyTargetData {
  expectZeroFalsePositives?: boolean;
  minTruePositiveRate?: number;
  description?: string;
}

export interface RuleMetadataData {
  ruleType?: string;
  ruleStatus?: string;
  cweIds?: number[];
  certIds?: string[];
  tags?: string[];
  accuracyTarget?: AccuracyTargetData;
}

export interface Violation {
  file: string;
  line: number;
  rule: string;
  message: string;
  severity?: string;
  impact?: string;
  correction?: string;
  /** OWASP categories this violation maps to (D1: Security Posture). */
  owasp?: OwaspData;
  /** Rule metadata snapshot at export time. */
  metadata?: RuleMetadataData;
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

/** Issue-weighted summary breakdowns by metadata. */
export interface MetadataIssueBreakdown {
  [key: string]: number;
}

/** Suppression counts broken down by how the diagnostic was silenced. */
export interface SuppressionsByKind {
  ignore?: number;
  ignoreForFile?: number;
  baseline?: number;
}

/** Aggregate suppression data included in the violations.json summary. */
export interface SuppressionsSummary {
  total?: number;
  byKind?: SuppressionsByKind;
  /** Rule name → suppression count. */
  byRule?: Record<string, number>;
  /** Relative file path → suppression count. */
  byFile?: Record<string, number>;
}

export interface ViolationsData {
  /** ISO 8601 timestamp when the analysis was run. */
  timestamp?: string;
  violations: Violation[];
  summary?: {
    totalViolations?: number;
    filesAnalyzed?: number;
    filesWithIssues?: number;
    bySeverity?: BySeverity;
    byImpact?: ByImpact;
    /** Rule name → issue count. Use for triage grouping. */
    issuesByRule?: IssuesByRule;
    /** Issue-weighted totals by semantic rule type. */
    byRuleType?: MetadataIssueBreakdown;
    /** Issue-weighted totals by lifecycle status. */
    byRuleStatus?: MetadataIssueBreakdown;
    /** Counts of diagnostics suppressed by ignore comments or baseline. */
    suppressions?: SuppressionsSummary;
  };
  config?: {
    tier?: string;
    enabledRuleCount?: number;
    /** Full list of enabled rule names. */
    enabledRuleNames?: string[];
    /** Stylistic rule names (opt-in). Present when export includes rule metadata. */
    stylisticRuleNames?: string[];
    /** Rule names that have at least one quick-fix generator. */
    rulesWithFixes?: string[];
    /** Rule name -> metadata snapshot for enabled/triggered rules. */
    ruleMetadataByRule?: Record<string, RuleMetadataData>;
    /** Rule name -> curated related rule names for discoverability surfaces. */
    relatedRulesByRule?: Record<string, string[]>;
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
      timestamp: typeof raw.timestamp === 'string' ? raw.timestamp : undefined,
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
            byRuleType:
              summary.byRuleType &&
              typeof summary.byRuleType === 'object' &&
              !Array.isArray(summary.byRuleType)
                ? summary.byRuleType
                : undefined,
            byRuleStatus:
              summary.byRuleStatus &&
              typeof summary.byRuleStatus === 'object' &&
              !Array.isArray(summary.byRuleStatus)
                ? summary.byRuleStatus
                : undefined,
            suppressions:
              summary.suppressions &&
              typeof summary.suppressions === 'object' &&
              !Array.isArray(summary.suppressions)
                ? {
                    total: typeof summary.suppressions.total === 'number'
                      ? summary.suppressions.total
                      : undefined,
                    byKind:
                      summary.suppressions.byKind &&
                      typeof summary.suppressions.byKind === 'object'
                        ? summary.suppressions.byKind
                        : undefined,
                    byRule:
                      summary.suppressions.byRule &&
                      typeof summary.suppressions.byRule === 'object' &&
                      !Array.isArray(summary.suppressions.byRule)
                        ? summary.suppressions.byRule
                        : undefined,
                    byFile:
                      summary.suppressions.byFile &&
                      typeof summary.suppressions.byFile === 'object' &&
                      !Array.isArray(summary.suppressions.byFile)
                        ? summary.suppressions.byFile
                        : undefined,
                  }
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
            rulesWithFixes: Array.isArray(raw.config.rulesWithFixes)
              ? raw.config.rulesWithFixes
              : undefined,
            ruleMetadataByRule:
              raw.config.ruleMetadataByRule &&
              typeof raw.config.ruleMetadataByRule === 'object' &&
              !Array.isArray(raw.config.ruleMetadataByRule)
                ? raw.config.ruleMetadataByRule
                : undefined,
            relatedRulesByRule:
              raw.config.relatedRulesByRule &&
              typeof raw.config.relatedRulesByRule === 'object' &&
              !Array.isArray(raw.config.relatedRulesByRule)
                ? Object.fromEntries(
                    Object.entries(raw.config.relatedRulesByRule)
                      .filter(([, v]) => Array.isArray(v))
                      .map(([k, v]) => [
                        k,
                        (v as unknown[]).filter((x): x is string => typeof x === 'string'),
                      ]),
                  )
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

/**
 * Return a copy of ViolationsData with violations for disabled rules removed
 * and summary counts recomputed from the filtered violations array.
 *
 * Pass-through when `disabled` is empty (no allocation).
 */
export function filterDisabledFromData(
  data: ViolationsData,
  disabled: Set<string>,
): ViolationsData {
  if (disabled.size === 0) return data;

  const filtered = data.violations.filter((v) => !disabled.has(v.rule));

  // Recompute summary counts from filtered violations.
  const bySeverity: BySeverity = {};
  const byImpact: ByImpact = {};
  const issuesByRule: IssuesByRule = {};
  const filesWithIssues = new Set<string>();

  for (const v of filtered) {
    const sev = (v.severity ?? 'info').toLowerCase() as keyof BySeverity;
    bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;

    const imp = (v.impact ?? 'low').toLowerCase() as keyof ByImpact;
    byImpact[imp] = (byImpact[imp] ?? 0) + 1;

    issuesByRule[v.rule] = (issuesByRule[v.rule] ?? 0) + 1;
    filesWithIssues.add(v.file);
  }

  return {
    ...data,
    violations: filtered,
    summary: {
      ...data.summary,
      totalViolations: filtered.length,
      filesWithIssues: filesWithIssues.size,
      bySeverity,
      byImpact,
      issuesByRule,
      byRuleType: computeByRuleType(filtered, data.config?.ruleMetadataByRule),
      byRuleStatus: computeByRuleStatus(filtered, data.config?.ruleMetadataByRule),
    },
  };
}

function computeByRuleType(
  violations: Violation[],
  metadataByRule: Record<string, RuleMetadataData> | undefined,
): MetadataIssueBreakdown {
  const result: MetadataIssueBreakdown = {};
  for (const v of violations) {
    const type = metadataByRule?.[v.rule]?.ruleType ?? v.metadata?.ruleType ?? 'unspecified';
    result[type] = (result[type] ?? 0) + 1;
  }
  return result;
}

function computeByRuleStatus(
  violations: Violation[],
  metadataByRule: Record<string, RuleMetadataData> | undefined,
): MetadataIssueBreakdown {
  const result: MetadataIssueBreakdown = {};
  for (const v of violations) {
    const status = metadataByRule?.[v.rule]?.ruleStatus ?? v.metadata?.ruleStatus ?? 'ready';
    result[status] = (result[status] ?? 0) + 1;
  }
  return result;
}
