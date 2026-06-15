/**
 * Shared primitives for the Findings (Violations) dashboard section builders.
 *
 * Holds the input/suppression types every section reads, the HTML escaper, the
 * 3-bucket severity order, and the relative-time formatter — extracted from
 * violationsDashboardHtml.ts so the per-section builder modules (hero, KPI,
 * toolbar, tables, charts, panels) depend on one small shared module instead of
 * re-importing each other. The dashboard composer re-exports the two suppression
 * types so existing consumers (violationsWideReportView, tests) import them
 * unchanged.
 */

import { l10n } from '../i18n/runtime';
import type { Violation } from '../violationsReader';
import type { DashboardSection } from './issuesTreeModel';
import type { GroupByMode } from './issuesTreeGrouping';

/** Analyzer-side suppression counts from `violations.json` (same source as the Suppressions tree). */
export interface AnalyzerSuppressionsSlice {
  total: number;
  byKind: readonly [string, number][];
  byRule: readonly [string, number][];
  byFile: readonly [string, number][];
}

/** Workspace-stored hides applied to the Issues / Findings list (not analyzer ignores). */
export interface ViewSuppressionsSlice {
  active: boolean;
  folderCount: number;
  fileCount: number;
  ruleCount: number;
  ruleInFileEntryCount: number;
  severityCount: number;
  impactCount: number;
  sampleFolders: readonly string[];
  sampleFiles: readonly string[];
  sampleRules: readonly string[];
  /** Short lines like `lib/a.dart: rule_x, rule_y` for per-file rule hides. */
  sampleRuleInFileLines: readonly string[];
}

export interface ViolationsDashboardHtmlInput {
  /** Violations matching current filters (deduped), for JSON copy. */
  exportViolations: Violation[];
  totalRawAfterDisable: number;
  filteredCount: number;
  truncatedSource: boolean;
  maxSourceViolations: number;
  pageSize: number;
  groupBy: GroupByMode;
  textFilter: string;
  severities: readonly string[];
  impacts: readonly string[];
  sections: DashboardSection[];
  todoHackSnapshot: {
    enabled: boolean;
    capped: boolean;
    todos: Array<{ file: string; line: number; snippet: string }>;
    hacks: Array<{ file: string; line: number; snippet: string }>;
  };
  driftAdvisorSnapshot: {
    integrationEnabled: boolean;
    connected: boolean;
    serverLabel?: string;
    issues: Array<{ source: string; severity: string; message: string; file?: string; line?: number }>;
  };
  severityCounts: Record<string, number>;
  impactCounts: Record<string, number>;
  analyzerSuppressions: AnalyzerSuppressionsSlice;
  viewSuppressions: ViewSuppressionsSlice;
  /** ISO 8601 timestamp from `violations.json`; powers the "Last run …" status pill. */
  reportTimestamp?: string;
  /** Extension semver (e.g. "1.4.2") shown next to the title as a muted build stamp. */
  extensionVersion?: string;
  /** Highest-volume rule across the export (post-disable, pre-filter), for KPI subtitle. */
  topRule?: { name: string; count: number };
  /** Distinct files contributing at least one finding, for KPI subtitle. */
  filesAffected?: number;
  /** Count of enabled rules in the current tier; powers status-line breadth pill. */
  enabledRuleCount?: number;
  /**
   * Top-N rules by violation count for the noisy-rule triage table.
   * Sourced from `exportViolations` so the ranking reflects what the user
   * is currently seeing in the findings table (post-disable, post-suppress,
   * post-filter). Each row carries severity so the user can decide whether
   * the noise is from an INFO-level stylistic rule or a real WARNING.
   */
  topRules?: ReadonlyArray<{
    name: string;
    count: number;
    severity: string;
    /**
     * Representative finding message for the rule (first occurrence). Shown
     * when the row is expanded so the user can read what the rule flags
     * without scrolling down to the findings table. Optional: callers (and
     * tests) that only need the count ranking may omit it — the row then
     * renders as a plain, non-expandable row.
     */
    message?: string;
    /**
     * Files contributing this rule's findings, highest-count first and capped
     * host-side, each with a representative (lowest) line so the expander can
     * deep-link into the source. Optional for the same reason as `message`.
     */
    files?: ReadonlyArray<{ file: string; count: number; line: number }>;
  }>;
  /**
   * State for the file-system TODO/HACK scanner *promo* pill in the status
   * line. When the scanner is off and the workspace has Dart files, a muted
   * promo pill invites enabling it; the ON-state "{N} TODO · {N} HACK" pill is
   * rendered in buildStatusLine from todoHackSnapshot.
   *
   * (The analyzer-findings/TODO supplementary pills were removed once the
   * dashboard became holistic — those diagnostics now appear directly in the
   * main findings list, so there is no longer a gap to surface.)
   */
  scanner?: {
    /** Workspace setting `saropaLints.todosAndHacks.workspaceScanEnabled`. */
    enabled: boolean;
    /**
     * Whether the workspace has any `.dart` files — gates the promo so it is
     * not advertised in a workspace with no Dart code.
     */
    hasDartFiles: boolean;
  };
  /**
   * True only for the very first paint of a freshly-opened panel. The hero's
   * entrance animation (`hero-in`) plays only on the first paint; subsequent
   * live rebuilds suppress it. Each `webview.html` reassignment reloads the
   * document and would otherwise replay the fade/slide every time the analyzer
   * republishes — the "constant header flicker" this guards against. Defaults
   * to animating (omitted / true) so standalone callers and tests keep the
   * entrance animation.
   */
  firstPaint?: boolean;
}

export const SEVERITY_ORDER: readonly string[] = ['error', 'warning', 'info'];

export function escapeHtml(s: string): string {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/** Relative time (e.g. "2m ago"). Resilient to clock drift / future stamps. */
export function formatRelative(iso: string | undefined): string | undefined {
  if (!iso) return undefined;
  const parsed = Date.parse(iso);
  if (!Number.isFinite(parsed)) return undefined;
  const diffMs = Date.now() - parsed;
  if (diffMs < 0) return l10n('findingsDash.time.justNow');
  const sec = Math.floor(diffMs / 1000);
  if (sec < 45) return l10n('findingsDash.time.justNow');
  const min = Math.floor(sec / 60);
  if (min < 60) return l10n('findingsDash.time.minutesAgo', { min: String(min) });
  const hr = Math.floor(min / 60);
  if (hr < 24) return l10n('findingsDash.time.hoursAgo', { hr: String(hr) });
  const day = Math.floor(hr / 24);
  return l10n('findingsDash.time.daysAgo', { day: String(day) });
}
