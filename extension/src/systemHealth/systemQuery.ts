/**
 * System-wide (not saropa-owned) physical memory query.
 *
 * WHY THIS EXISTS: every other query in this subsystem (`processQuery.ts`,
 * `orphanHosts.ts`) answers "what is one class of process doing?". Nothing
 * answers "is the machine itself under pressure?" — the Machine Health
 * dashboard and its proactive low-memory warning both need that number, and
 * neither saropa RSS nor the Dart process table can derive it (a fully idle
 * saropa_lints session tells you nothing about a 12 GB analysis server or a
 * stray llama-server.exe eating the rest of the box).
 */

import { execFile } from 'node:child_process';

const MAX_BUFFER = 1024 * 1024;

/** Physical memory snapshot for the whole machine, not just saropa-owned processes. */
export interface SystemMemorySnapshot {
  /** Total physical RAM in bytes. */
  totalBytes: number;
  /** Free physical RAM in bytes. */
  freeBytes: number;
  /** Fraction of total RAM currently free, 0-1. */
  freeFraction: number;
}

/**
 * Query total/free physical RAM via WMI. Windows-only; returns undefined on
 * any other platform or on query failure — callers must treat "unknown" as
 * "do not warn", not as "assume healthy" or "assume critical".
 */
export function querySystemMemory(): Promise<SystemMemorySnapshot | undefined> {
  if (process.platform !== 'win32') return Promise.resolve(undefined);
  return new Promise((resolve) => {
    const script =
      'Get-CimInstance Win32_OperatingSystem ' +
      '| Select-Object TotalVisibleMemorySize, FreePhysicalMemory ' +
      '| ConvertTo-Json -Compress';
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: 10_000, maxBuffer: MAX_BUFFER },
      (err, stdout) => {
        // A failed shell-out (PowerShell missing, WMI disabled by policy) or
        // empty stdout both mean "no answer" — resolve undefined rather than
        // rejecting, since a query failure here must never crash whatever
        // notification loop or dashboard refresh called this.
        if (err || !stdout.trim()) {
          resolve(undefined);
          return;
        }
        try {
          const raw = JSON.parse(stdout) as Record<string, unknown>;
          // WMI reports both fields in kilobytes.
          const totalKb = Number(raw['TotalVisibleMemorySize'] ?? 0);
          const freeKb = Number(raw['FreePhysicalMemory'] ?? 0);
          // A zero/missing total is a malformed row, not a machine with no
          // RAM — treat it the same as a query failure rather than dividing
          // by zero below.
          if (totalKb <= 0) {
            resolve(undefined);
            return;
          }
          const totalBytes = totalKb * 1024;
          const freeBytes = freeKb * 1024;
          resolve({ totalBytes, freeBytes, freeFraction: freeBytes / totalBytes });
        } catch {
          // Malformed JSON is indistinguishable from "no data" for this
          // caller — same undefined-degrades-to-no-warning contract as above.
          resolve(undefined);
        }
      },
    );
  });
}
