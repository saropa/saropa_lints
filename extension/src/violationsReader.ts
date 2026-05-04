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
  requiresReview?: boolean;
  defaultReviewState?: string;
  accuracyTarget?: AccuracyTargetData;
}

export interface Violation {
  file: string;
  line: number;
  rule: string;
  message: string;
  /** FIX PRIORITY score from export (same formula as report); absent in older exports. */
  priority?: number;
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

/**
 * Severity-keyed counts. Three buckets matching the analyzer's native model.
 * Collapsed from the prior 5-bucket impact taxonomy (critical/high/medium/
 * low/opinionated) on 2026-05-03; see plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md.
 *
 * The interface is named `ByImpact` (not `BySeverity`) for back-compat with
 * the JSON `byImpact` field name; the underlying values now mirror severity.
 */
export interface ByImpact {
  error?: number;
  warning?: number;
  info?: number;
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
    /** Rule name -> curated conflicting/opposite rule names. */
    conflictingRulesByRule?: Record<string, string[]>;
    /** Rule name -> curated superseded/replaced rule names. */
    supersedesRulesByRule?: Record<string, string[]>;
  };
}

export function getViolationsPath(workspaceRoot: string): string {
  return path.join(workspaceRoot, 'reports', '.saropa_lints', 'violations.json');
}

/**
 * Map a legacy 5-bucket impact value onto the 3-bucket severity vocabulary.
 *
 * **Why this exists.** On 2026-05-03 the analyzer-side `LintImpact` enum
 * collapsed from `critical/high/medium/low/opinionated` to `error/warning/
 * info` (commit f6fdba5d, plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md). The
 * dashboard's default `impactsToShow` filter is now
 * `{error, warning, info}` — if a user has a `violations.json` left over
 * from a saropa_lints plugin <13.4.x (or upgraded the extension before
 * re-running analysis with the new plugin), every violation has
 * `impact: critical|high|medium|low|opinionated` and the new filter
 * excludes 100% of them. Symptom: the status pill shows "401 findings"
 * (totalRawAfterDisable, computed before the impact filter) but the
 * Findings table is empty with "No violations match the current filters."
 * Reported as a v13.4.x regression on issue #208.
 *
 * **Mapping.** Mirrors the analyzer-side collapse exactly:
 *  - critical → error
 *  - high, medium → warning
 *  - low, opinionated → info
 *
 * Leaves already-normalized values (`error`, `warning`, `info`) untouched
 * and passes unknown strings through so future taxonomies don't silently
 * drop. Returns `undefined` for `undefined`/`null` so callers can fall
 * back to their own default the way they did before normalization.
 */
export function normalizeLegacyImpact(value: string | undefined | null): string | undefined {
  if (value == null) return undefined;
  switch (value.toLowerCase()) {
    case 'critical':
      return 'error';
    case 'high':
    case 'medium':
      return 'warning';
    case 'low':
    case 'opinionated':
      return 'info';
    default:
      return value.toLowerCase();
  }
}

/**
 * Apply [normalizeLegacyImpact] to a `byImpact`-shaped count map, merging
 * counts where two legacy keys collapse onto one new key (e.g. `low` +
 * `opinionated` both becoming `info`). Used at read time so the dashboard
 * KPI card and donut see the new vocabulary regardless of which plugin
 * version wrote the export.
 */
function normalizeByImpactKeys(
  raw: Record<string, unknown> | undefined,
): ByImpact | undefined {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return undefined;
  const out: ByImpact = {};
  for (const [k, v] of Object.entries(raw)) {
    if (typeof v !== 'number') continue;
    const norm = normalizeLegacyImpact(k);
    if (!norm) continue;
    const key = norm as keyof ByImpact;
    out[key] = (out[key] ?? 0) + v;
  }
  return out;
}

/**
 * Triage UIs (volume groups, zero-issue, stylistic) need a fresh
 * `summary.issuesByRule` and a recent export file. Missing file, old mtime, or
 * a legacy export without per-rule keys should not drive group-level toggles
 * (misleading).
 */
export const VIOLATIONS_EXPORT_STALE_MS = 4 * 60 * 60 * 1000;

export type ViolationsTriageState =
  | { kind: 'ok' }
  | { kind: 'missing' }
  | { kind: 'stale'; ageMs: number }
  | { kind: 'incomplete'; reason: 'no_per_rule' | 'unreadable' };

/**
 * How suitable `violations.json` is for triage (group enable/disable) vs
 * read-only surfaces (raw violation list) that tolerate older exports.
 */
export function getViolationsTriageState(
  workspaceRoot: string,
  data: ViolationsData | null,
): { fileMtimeMs: number | null; triage: ViolationsTriageState } {
  const p = getViolationsPath(workspaceRoot);
  if (!fs.existsSync(p)) {
    return { fileMtimeMs: null, triage: { kind: 'missing' } };
  }
  let mtime: number;
  try {
    mtime = fs.statSync(p).mtimeMs;
  } catch {
    return { fileMtimeMs: null, triage: { kind: 'incomplete', reason: 'unreadable' } };
  }
  if (data == null) {
    return { fileMtimeMs: mtime, triage: { kind: 'incomplete', reason: 'unreadable' } };
  }
  if (Date.now() - mtime > VIOLATIONS_EXPORT_STALE_MS) {
    return { fileMtimeMs: mtime, triage: { kind: 'stale', ageMs: Date.now() - mtime } };
  }
  if (data.summary?.issuesByRule == null) {
    return { fileMtimeMs: mtime, triage: { kind: 'incomplete', reason: 'no_per_rule' } };
  }
  return { fileMtimeMs: mtime, triage: { kind: 'ok' } };
}

export function readViolations(workspaceRoot: string): ViolationsData | null {
  const p = getViolationsPath(workspaceRoot);
  if (!fs.existsSync(p)) return null;
  try {
    const raw = JSON.parse(fs.readFileSync(p, 'utf-8'));
    const summary = raw.summary;
    // Normalize each violation's `impact` to the 3-bucket vocabulary so
    // `violations.json` files written by saropa_lints <13.4.x (legacy
    // 5-bucket impacts: critical/high/medium/low/opinionated) still flow
    // through the dashboard's `impactsToShow = {error, warning, info}`
    // filter. Without this, upgrading the extension before re-running
    // analysis produces "401 findings shown / 0 in the table" — see
    // [normalizeLegacyImpact] for the full rationale.
    const violations: Violation[] = Array.isArray(raw.violations)
      ? (raw.violations as Violation[]).map((v) => {
          const norm = normalizeLegacyImpact(v.impact);
          // Only allocate a new object when normalization actually changes
          // the field — keeps the post-2026-05-03 happy path zero-cost.
          return norm === v.impact ? v : { ...v, impact: norm };
        })
      : [];
    return {
      timestamp: typeof raw.timestamp === 'string' ? raw.timestamp : undefined,
      violations,
      summary: summary
        ? {
            totalViolations: summary.totalViolations,
            filesAnalyzed: summary.filesAnalyzed,
            filesWithIssues: summary.filesWithIssues,
            bySeverity: summary.bySeverity,
            // Re-key the legacy 5-bucket `byImpact` map onto the 3-bucket
            // vocabulary so KPI cards and the donut/bar mix chart agree
            // with the filtered findings table. See [normalizeByImpactKeys].
            byImpact: normalizeByImpactKeys(summary.byImpact),
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
            conflictingRulesByRule:
              raw.config.conflictingRulesByRule &&
              typeof raw.config.conflictingRulesByRule === 'object' &&
              !Array.isArray(raw.config.conflictingRulesByRule)
                ? Object.fromEntries(
                    Object.entries(raw.config.conflictingRulesByRule)
                      .filter(([, v]) => Array.isArray(v))
                      .map(([k, v]) => [
                        k,
                        (v as unknown[]).filter((x): x is string => typeof x === 'string'),
                      ]),
                  )
                : undefined,
            supersedesRulesByRule:
              raw.config.supersedesRulesByRule &&
              typeof raw.config.supersedesRulesByRule === 'object' &&
              !Array.isArray(raw.config.supersedesRulesByRule)
                ? Object.fromEntries(
                    Object.entries(raw.config.supersedesRulesByRule)
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

    // Default to 'info' (was 'low' under the 5-bucket taxonomy) — same idea:
    // the lowest, least-urgent bucket is the safe fallback for rules that
    // didn't tag themselves explicitly.
    const imp = (v.impact ?? 'info').toLowerCase() as keyof ByImpact;
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
