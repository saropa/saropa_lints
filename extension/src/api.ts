/**
 * Public API for other extensions (e.g. Saropa Log Capture).
 * Consumers get this via: vscode.extensions.getExtension('saropa.saropa-lints')?.exports
 *
 * @see bugs/plan/plan_log_capture_integration.md
 */

import type { ViolationsData } from './violationsReader';

/** Health score parameters: impact weights and decay rate. Must match extension health score formula. */
export interface HealthScoreParams {
  impactWeights: Record<string, number>;
  decayRate: number;
}

/**
 * One tool's contribution to the cross-tool Saropa Suite daily report.
 *
 * Returned by [SaropaLintsApi.getDailySummary]. The Suite (Saropa Workspace)
 * calls each installed tool's `getDailySummary(date)` and stitches the results
 * into a single executive summary + Trouble list. This is the data-out side of
 * the same contract family as the documented `saropaLints.*` deep-link command
 * ids the Suite uses to jump in — treat the shape with the same never-rename
 * discipline: additive changes only, bump [SaropaLintsApi.apiVersion] if the
 * meaning of an existing field changes.
 */
export interface DailySummary {
  /** Constant tool identity so the Suite can label the section. */
  tool: 'saropa-lints';
  /** Echo of the requested day (YYYY-MM-DD) so callers can key the row. */
  date: string;
  /** One plain-language sentence for the caller's executive summary. English. */
  headline: string;
  /**
   * Flat numeric metrics (e.g. `violations`, `critical`, `healthScore`,
   * `outdatedPackages`). A record, not a fixed struct, so a caller tolerates
   * keys being added or absent — a key is omitted when its source is
   * unavailable (e.g. `healthScore` on a partial sweep, `outdatedPackages`
   * before a Package Vibrancy scan has run this session).
   */
  counts: Record<string, number>;
  /**
   * Failure-only items for the caller's Trouble section (error-level
   * violations, a health-score regression). Empty when nothing is wrong.
   */
  trouble: Array<{
    label: string;
    detail?: string;
    /** Deep-link command id the Suite can invoke, e.g. 'saropaLints.focusIssues'. */
    command?: string;
    args?: unknown;
  }>;
  /** Command id to open the fullest local view, e.g. 'saropaLints.openProjectHealthDashboard'. */
  openCommand?: string;
}

/**
 * API exposed by the Saropa Lints extension when activated.
 * Other extensions can use this to read violations, run analysis, or get health score constants
 * without reading violations.json from disk.
 */
export interface SaropaLintsApi {
  /**
   * Version of the cross-tool Suite contract this exports object implements.
   * Lets siblings evolve the shape without breaking older callers. Bump only
   * on a breaking change to [DailySummary] or another Suite-contract member.
   */
  apiVersion: 1;

  /**
   * The Saropa Suite daily-report contribution for `date` (YYYY-MM-DD).
   *
   * Built lazily on call (never at activation) from the current local
   * analysis snapshot, so it never slows startup and transmits nothing.
   * Resolves to `undefined` when no analysis has ever run (no
   * `violations.json`), so the Suite omits this tool's section.
   *
   * apiVersion 1 has no per-day history store: the counts reflect the current
   * snapshot echoed against the requested `date`, with a best-effort
   * day-over-day delta drawn from the run-history the extension already keeps.
   */
  getDailySummary(date: string): Promise<DailySummary | undefined>;

  /** Same shape as readViolations(projectRoot). Null if no project root or read fails. */
  getViolationsData(): ViolationsData | null;

  /** Absolute path to reports/.saropa_lints/violations.json; null if no project root. */
  getViolationsPath(): string | null;

  /** Impact weights and decay rate used by the extension's health score. Null if unavailable. */
  getHealthScoreParams(): HealthScoreParams | null;

  /** Runs full dart/flutter analyze in workspace. Resolves to true if exit code 0. */
  runAnalysis(): Promise<boolean>;

  /** Runs analyze for the given files only. Resolves to true if exit code 0. */
  runAnalysisForFiles(files: string[]): Promise<boolean>;

  /** Extension or package version (e.g. from package.json). Non-empty string. */
  getVersion(): string;
}
