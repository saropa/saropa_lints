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
 * API exposed by the Saropa Lints extension when activated.
 * Other extensions can use this to read violations, run analysis, or get health score constants
 * without reading violations.json from disk.
 */
export interface SaropaLintsApi {
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
