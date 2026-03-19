/**
 * Drift Advisor server discovery (port scan + health check).
 *
 * Scans a configurable port range (default 8642–8649), calls GET /api/health on each port,
 * and returns the first server that responds with HTTP 200 and valid JSON. Accepts health
 * payloads with or without an "ok" field; if "ok" is present and false, the server is
 * rejected. No dependency on the Drift Advisor extension or package.
 *
 * Used by the Saropa Lints extension when saropaLints.driftAdvisor.integration is enabled.
 * Timeout per port avoids hanging on closed/firewalled ports.
 */

import type { DriftHealthResponse, DriftServerInfo } from './types';

const DEFAULT_TIMEOUT_MS = 2000;

/**
 * Try GET /api/health on a single port. Returns server info if response is OK and JSON
 * is valid; rejects only when ok is explicitly false. Always clears the timeout to
 * avoid leaks.
 */
export async function tryHealth(port: number, timeoutMs = DEFAULT_TIMEOUT_MS): Promise<DriftServerInfo | null> {
  const url = `http://127.0.0.1:${port}/api/health`;
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return null;
    const data = (await res.json()) as DriftHealthResponse;
    if (data?.ok === false) return null;
    return {
      baseUrl: `http://127.0.0.1:${port}`,
      port,
      version: data.version,
      capabilities: Array.isArray(data.capabilities) ? data.capabilities : [],
    };
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

/**
 * Scan ports from min to max (inclusive) and return the first server found.
 */
export async function discoverServer(
  portMin: number,
  portMax: number,
  timeoutPerPort = DEFAULT_TIMEOUT_MS,
): Promise<DriftServerInfo | null> {
  for (let port = portMin; port <= portMax; port++) {
    const info = await tryHealth(port, timeoutPerPort);
    if (info) return info;
  }
  return null;
}
