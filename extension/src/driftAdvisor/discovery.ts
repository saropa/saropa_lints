/**
 * Drift Advisor server discovery (port scan + health check).
 *
 * Probes a configurable set of hosts (default 127.0.0.1) across a configurable
 * port range (default 8642–8649), calls GET /api/health on each endpoint, and
 * returns the first server that responds with HTTP 200 and valid JSON. Accepts
 * health payloads with or without an "ok" field; if "ok" is present and false,
 * the server is rejected. No dependency on the Drift Advisor extension or package.
 *
 * Hosts are configurable so a Drift Advisor server running off-box — e.g. on a
 * phone reached over the LAN via Wi-Fi debugging, or several devices at once —
 * can be probed directly by IP, not just localhost. A host entry may pin an exact
 * port as "host:port" (probed alone); a bare host is scanned across the range.
 * This covers many IPs and many ports from one list.
 *
 * Used by the Saropa Lints extension when saropaLints.driftAdvisor.integration is enabled.
 * Timeout per endpoint avoids hanging on closed/firewalled ports.
 */

import type { DriftHealthResponse, DriftServerInfo } from './types';

const DEFAULT_TIMEOUT_MS = 2000;

/** A concrete host+port to probe, expanded from the configured host list. */
export interface DriftEndpoint {
  host: string;
  port: number;
}

/**
 * Parse a "host:port" entry into its parts, or null when no explicit port is
 * present (a bare host). Only a trailing all-digit port in 1–65535 counts, so
 * bare hostnames and IPv4 addresses pass through untouched. IPv6 literals (which
 * themselves contain colons) are not split — wrap those in an explicit range via
 * a bare entry instead.
 */
export function parseHostPort(entry: string): DriftEndpoint | null {
  const match = /^(.+):(\d{1,5})$/.exec(entry);
  if (!match) return null;
  const host = match[1].trim();
  const port = Number(match[2]);
  if (!host || port < 1 || port > 65535) return null;
  return { host, port };
}

/**
 * Expand the configured host list × the port range into the ordered, de-duplicated
 * set of endpoints to probe. Each "host:port" entry yields exactly that endpoint;
 * each bare host yields one endpoint per port in [portMin, portMax]. Blank entries
 * are skipped. Order follows the host list (so earlier hosts win ties).
 */
export function expandEndpoints(
  hosts: readonly string[],
  portMin: number,
  portMax: number,
): DriftEndpoint[] {
  const out: DriftEndpoint[] = [];
  const seen = new Set<string>();
  const add = (host: string, port: number): void => {
    const key = `${host}:${port}`;
    if (seen.has(key)) return;
    seen.add(key);
    out.push({ host, port });
  };
  for (const raw of hosts) {
    const entry = (raw ?? '').trim();
    if (!entry) continue;
    const explicit = parseHostPort(entry);
    if (explicit) {
      add(explicit.host, explicit.port);
      continue;
    }
    for (let port = portMin; port <= portMax; port++) {
      add(entry, port);
    }
  }
  return out;
}

/**
 * Try GET /api/health on a single port. Returns server info if response is OK and JSON
 * is valid; rejects only when ok is explicitly false. Always clears the timeout to
 * avoid leaks.
 */
export async function tryHealth(
  port: number,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  host = '127.0.0.1',
): Promise<DriftServerInfo | null> {
  const baseUrl = `http://${host}:${port}`;
  const url = `${baseUrl}/api/health`;
  const controller = new AbortController();
  const t = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) return null;
    const data = (await res.json()) as DriftHealthResponse;
    if (data?.ok === false) return null;
    return {
      baseUrl,
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
 * Probe every endpoint expanded from `hosts` × [portMin, portMax] and return the
 * first server found. `hosts` defaults to localhost so existing single-host
 * callers (and tests passing only the port range) behave as before.
 */
export async function discoverServer(
  portMin: number,
  portMax: number,
  timeoutPerPort = DEFAULT_TIMEOUT_MS,
  hosts: readonly string[] = ['127.0.0.1'],
): Promise<DriftServerInfo | null> {
  for (const ep of expandEndpoints(hosts, portMin, portMax)) {
    const info = await tryHealth(ep.port, timeoutPerPort, ep.host);
    if (info) return info;
  }
  return null;
}
