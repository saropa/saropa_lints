/**
 * Drift Advisor API client: fetch issues from a discovered server.
 *
 * When the server reports capability "issues", calls GET /api/issues once. Otherwise falls back
 * to GET /api/index-suggestions and GET /api/analytics/anomalies and merges results into the
 * stable issue shape (table, column, message, severity, source). Tolerates varying server
 * response shapes (suggestions vs items, anomalies array vs wrapper) to support current and
 * future Drift Advisor versions.
 */

import type { DriftIssueRaw, DriftServerInfo } from './types';

const ISSUES_ENDPOINT = '/api/issues';
const INDEX_SUGGESTIONS_ENDPOINT = '/api/index-suggestions';
const ANOMALIES_ENDPOINT = '/api/analytics/anomalies';

/** Normalize severity string from server. */
function toSeverity(s: unknown): 'error' | 'warning' | 'info' {
  if (s === 'error' || s === 'warning' || s === 'info') return s;
  return 'warning';
}

/** Build a single issue from index-suggestion payload (shape may vary by server). */
function indexSuggestionToIssue(raw: Record<string, unknown>): DriftIssueRaw {
  const table = typeof raw.table === 'string' ? raw.table : String(raw.table ?? '');
  const column = raw.column != null ? String(raw.column) : null;
  const message = typeof raw.message === 'string' ? raw.message : (raw.reason ?? 'Missing index');
  return {
    source: 'index-suggestion',
    severity: toSeverity(raw.severity),
    table,
    column,
    message: typeof message === 'string' ? message : 'Missing index',
    suggestedSql: typeof raw.suggestedSql === 'string' ? raw.suggestedSql : null,
    type: null,
  };
}

/** Build issues from anomalies payload (shape may vary by server). */
function anomaliesToIssues(raw: Record<string, unknown>): DriftIssueRaw[] {
  const list = Array.isArray(raw.anomalies) ? raw.anomalies : Array.isArray(raw) ? raw : [];
  const table = typeof raw.table === 'string' ? raw.table : '';
  const issues: DriftIssueRaw[] = [];
  for (const item of list) {
    const rec = typeof item === 'object' && item !== null ? (item as Record<string, unknown>) : {};
    const column = rec.column != null ? String(rec.column) : null;
    const type = rec.type != null ? String(rec.type) : null;
    const message = typeof rec.message === 'string' ? rec.message : (type ?? 'Anomaly');
    issues.push({
      source: 'anomaly',
      severity: toSeverity(rec.severity),
      table: typeof rec.table === 'string' ? rec.table : table,
      column,
      message,
      suggestedSql: null,
      type,
    });
  }
  return issues;
}

/** Fetch GET /api/issues (unified endpoint). */
async function fetchIssuesEndpoint(baseUrl: string): Promise<DriftIssueRaw[]> {
  const res = await fetch(`${baseUrl}${ISSUES_ENDPOINT}`);
  if (!res.ok) return [];
  const data = (await res.json()) as { issues?: DriftIssueRaw[] };
  const arr = Array.isArray(data?.issues) ? data.issues : [];
  return arr.filter((i): i is DriftIssueRaw => i && typeof i.table === 'string' && typeof i.message === 'string');
}

/** Fetch index-suggestions and anomalies and merge into stable shape. */
async function fetchLegacyEndpoints(baseUrl: string): Promise<DriftIssueRaw[]> {
  const [indexRes, anomaliesRes] = await Promise.all([
    fetch(`${baseUrl}${INDEX_SUGGESTIONS_ENDPOINT}`),
    fetch(`${baseUrl}${ANOMALIES_ENDPOINT}`),
  ]);
  const out: DriftIssueRaw[] = [];
  if (indexRes.ok) {
    const data = (await indexRes.json()) as unknown;
    const list = Array.isArray(data) ? data : (Array.isArray((data as Record<string, unknown>)?.suggestions)
      ? (data as Record<string, unknown>).suggestions
      : Array.isArray((data as Record<string, unknown>)?.items)
        ? (data as Record<string, unknown>).items
        : []) as Record<string, unknown>[];
    for (const item of list) {
      const obj = typeof item === 'object' && item !== null ? (item as Record<string, unknown>) : {};
      out.push(indexSuggestionToIssue(obj));
    }
  }
  if (anomaliesRes.ok) {
    const data = (await anomaliesRes.json()) as Record<string, unknown>;
    out.push(...anomaliesToIssues(data));
  }
  return out;
}

/**
 * Fetch all issues from the server. Uses GET /api/issues if capabilities include "issues",
 * otherwise uses index-suggestions and analytics/anomalies.
 */
export async function fetchIssues(server: DriftServerInfo): Promise<DriftIssueRaw[]> {
  if (server.capabilities.includes('issues')) {
    return fetchIssuesEndpoint(server.baseUrl);
  }
  return fetchLegacyEndpoints(server.baseUrl);
}
