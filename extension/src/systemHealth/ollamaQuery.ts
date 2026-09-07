/**
 * Best-effort Ollama daemon introspection for the Machine Health dashboard.
 *
 * Model-host processes (`llama-server.exe`/`ollama.exe`) are already detected
 * as OS processes by `orphanHosts.ts`, which is enough to know *that* memory
 * is committed. This module adds the one thing the process table cannot say:
 * *which model* is loaded, so the dashboard can offer a named "Unload
 * {model}" action instead of only a process-level kill. Every call degrades
 * to "unknown" on any failure — a dead or absent daemon is the common case
 * (most sessions never touch translation), not an error worth surfacing.
 */

import { execFile } from 'node:child_process';
import * as http from 'node:http';

/** Default Ollama REST port; not configurable today because nothing else in this project overrides it. */
const OLLAMA_PORT = 11434;
const REQUEST_TIMEOUT_MS = 2_000;

/** One entry from Ollama's `/api/ps` (currently-loaded models). */
export interface LoadedModel {
  name: string;
  /** Resident size in bytes, as reported by Ollama. */
  sizeBytes: number;
}

/**
 * Query which models are currently loaded in the Ollama daemon.
 * Returns an empty array when the daemon is unreachable or the response is
 * malformed — indistinguishable from "no daemon running" for this feature's
 * purposes, since both mean there is nothing to offer an unload button for.
 */
export function queryLoadedModels(): Promise<LoadedModel[]> {
  return new Promise((resolve) => {
    const req = http.get(
      { host: '127.0.0.1', port: OLLAMA_PORT, path: '/api/ps', timeout: REQUEST_TIMEOUT_MS },
      (res) => {
        let body = '';
        res.on('data', (chunk: Buffer) => { body += chunk.toString(); });
        res.on('end', () => {
          try {
            const parsed = JSON.parse(body) as { models?: Array<{ name?: string; size?: number }> };
            // `models` absent means the daemon answered but nothing is
            // loaded (idle Ollama) — same empty-array result as "daemon not
            // running" below, since both mean "no unload button to offer".
            const models = (parsed.models ?? []).map((m) => ({
              name: String(m.name ?? 'unknown'),
              sizeBytes: Number(m.size ?? 0),
            }));
            resolve(models);
          } catch {
            // Malformed JSON from a non-Ollama service squatting on the port
            // is indistinguishable from "no daemon" here — degrade the same way.
            resolve([]);
          }
        });
      },
    );
    // The common case: no Ollama daemon running at all (ECONNREFUSED).
    // Resolving [] rather than propagating the error keeps every caller
    // (recommendations, dashboard queryData) from needing its own try/catch
    // around what is, for most sessions, an expected "nothing here" result.
    req.on('error', () => resolve([]));
    // A 2s timeout matters because this runs on every dashboard refresh —
    // an unresponsive (not refusing) port must not stall the whole panel.
    req.on('timeout', () => { req.destroy(); resolve([]); });
  });
}

/**
 * Unload a model immediately via `ollama stop`, rather than the `keep_alive:
 * 0` HTTP flag — the CLI command is idempotent and does not require
 * constructing a generate request just to set a teardown flag. Requires
 * `ollama` on PATH; resolves false (not a thrown error) when it is not,
 * since a missing CLI is a normal outcome on a machine that never installed
 * Ollama standalone.
 */
export function unloadModel(modelName: string): Promise<boolean> {
  return new Promise((resolve) => {
    execFile('ollama', ['stop', modelName], { timeout: 10_000 }, (err) => resolve(!err));
  });
}
