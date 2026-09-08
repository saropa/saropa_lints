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

/**
 * Thrown when a data endpoint returns 401/403. Distinguishes "wrong or missing
 * token" from "server genuinely has zero issues" — both would otherwise look
 * identical (an empty array) to callers.
 */
export class DriftAuthError extends Error {
  constructor() {
    super('Drift Advisor server rejected the request: invalid or missing auth token');
    this.name = 'DriftAuthError';
  }
}

/** Build Authorization header from the given token, if present. */
function authHeaders(authToken?: string): Record<string, string> | undefined {
  if (!authToken) return undefined;
  return { Authorization: `Bearer ${authToken}` };
}

/** Throw DriftAuthError on 401/403; other non-OK statuses are handled by the caller. */
function assertNotAuthFailure(res: Response): void {
  if (res.status === 401 || res.status === 403) throw new DriftAuthError();
}

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
async function fetchIssuesEndpoint(baseUrl: string, authToken?: string): Promise<DriftIssueRaw[]> {
  const headers = authHeaders(authToken);
  const res = await fetch(`${baseUrl}${ISSUES_ENDPOINT}`, headers ? { headers } : undefined);
  assertNotAuthFailure(res);
  if (!res.ok) return [];
  const data = (await res.json()) as { issues?: DriftIssueRaw[] };
  const arr = Array.isArray(data?.issues) ? data.issues : [];
  return arr.filter((i): i is DriftIssueRaw => i && typeof i.table === 'string' && typeof i.message === 'string');
}

/** Fetch index-suggestions and anomalies and merge into stable shape. */
async function fetchLegacyEndpoints(baseUrl: string, authToken?: string): Promise<DriftIssueRaw[]> {
  const headers = authHeaders(authToken);
  const opts = headers ? { headers } : undefined;
  const [indexRes, anomaliesRes] = await Promise.all([
    fetch(`${baseUrl}${INDEX_SUGGESTIONS_ENDPOINT}`, opts),
    fetch(`${baseUrl}${ANOMALIES_ENDPOINT}`, opts),
  ]);
  assertNotAuthFailure(indexRes);
  assertNotAuthFailure(anomaliesRes);
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
 * otherwise uses index-suggestions and analytics/anomalies. When authToken is provided,
 * sends it as a Bearer token on every request (required for non-loopback servers).
 *
 * Callers should read the token via `getDriftAuthToken()` from `./auth.ts` —
 * the single source of truth for the saropaLints.driftAdvisor.authToken setting.
 */
export async function fetchIssues(server: DriftServerInfo, authToken?: string): Promise<DriftIssueRaw[]> {
  if (server.capabilities.includes('issues')) {
    return fetchIssuesEndpoint(server.baseUrl, authToken);
  }
  return fetchLegacyEndpoints(server.baseUrl, authToken);
}
