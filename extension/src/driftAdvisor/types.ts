/**
 * Type definitions for optional Saropa Drift Advisor integration.
 *
 * The Drift Advisor server exposes index suggestions and data-quality anomalies (no file/line).
 * These types describe the stable issue shape (plan §2.1), health response, and server discovery
 * result. The extension maps table/column to Dart file/line via mapper.ts using PascalCase/camelCase
 * heuristics. All types are used only within the extension; no Dart package dependency.
 */

export type DriftIssueSource = 'index-suggestion' | 'anomaly';

export type DriftIssueSeverity = 'error' | 'warning' | 'info';

/** Stable issue shape (matches plan §2.1; server may expose GET /api/issues or we merge from two endpoints). */
export interface DriftIssueRaw {
  source: DriftIssueSource;
  severity: DriftIssueSeverity;
  table: string;
  column: string | null;
  message: string;
  suggestedSql?: string | null;
  type?: string | null;
}

/** Issue with optional file/line from table/column → Dart mapping. */
export interface DriftIssueMapped extends DriftIssueRaw {
  uri?: { fsPath: string };
  line?: number;
  columnIndex?: number;
}

export interface DriftHealthResponse {
  ok?: boolean;
  version?: string;
  capabilities?: string[];
}

export interface DriftIssuesResponse {
  issues: DriftIssueRaw[];
}

/** Result of discovering a Drift Advisor server. */
export interface DriftServerInfo {
  baseUrl: string;
  port: number;
  version?: string;
  capabilities: string[];
}
