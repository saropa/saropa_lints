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
 *
 * Windows uses WMI (`Win32_OperatingSystem`) via PowerShell. macOS uses
 * `sysctl -n hw.memsize` for the total and `vm_stat` for the free estimate.
 * Linux reads `/proc/meminfo`. Every platform funnels through the same
 * `SystemMemorySnapshot` shape and the same undefined-on-failure contract.
 */

import { execFile } from 'node:child_process';
import * as fs from 'node:fs/promises';

const MAX_BUFFER = 1024 * 1024;
const QUERY_TIMEOUT_MS = 10_000;

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
 * Query total/free physical RAM for the current platform; returns undefined
 * on an unsupported platform or on query failure — callers must treat
 * "unknown" as "do not warn", not as "assume healthy" or "assume critical".
 */
export function querySystemMemory(): Promise<SystemMemorySnapshot | undefined> {
  if (process.platform === 'win32') return queryWindowsMemory();
  if (process.platform === 'darwin') return queryDarwinMemory();
  if (process.platform === 'linux') return queryLinuxMemory();
  return Promise.resolve(undefined);
}

/**
 * Windows: total/free physical RAM via WMI. Unchanged from the original
 * Windows-only implementation — kept as its own function so the platform
 * dispatch above stays a flat, obviously-correct switch.
 */
function queryWindowsMemory(): Promise<SystemMemorySnapshot | undefined> {
  return new Promise((resolve) => {
    const script =
      'Get-CimInstance Win32_OperatingSystem ' +
      '| Select-Object TotalVisibleMemorySize, FreePhysicalMemory ' +
      '| ConvertTo-Json -Compress';
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: QUERY_TIMEOUT_MS, maxBuffer: MAX_BUFFER },
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

/** Run `execFile` as a promise that resolves to `undefined` instead of rejecting. */
function execFileSafe(command: string, args: string[]): Promise<string | undefined> {
  return new Promise((resolve) => {
    execFile(
      command,
      args,
      { timeout: QUERY_TIMEOUT_MS, maxBuffer: MAX_BUFFER },
      (err, stdout) => {
        resolve(err ? undefined : stdout);
      },
    );
  });
}

/**
 * Parse `sysctl -n hw.memsize` output: a single integer, the machine's total
 * physical RAM in bytes. Returns undefined for anything that is not a
 * positive integer (empty output, garbage, a zero reading).
 */
export function parseHwMemsize(stdout: string): number | undefined {
  const trimmed = stdout.trim();
  if (!/^\d+$/.test(trimmed)) return undefined;
  const bytes = Number(trimmed);
  if (!Number.isFinite(bytes) || bytes <= 0) return undefined;
  return bytes;
}

/**
 * Parse `vm_stat` output into a page size and a "free" byte count.
 *
 * WHY "free" is Pages free + Pages inactive + Pages speculative, and NOT
 * Pages purgeable on top: macOS deliberately keeps "Pages free" near zero —
 * the kernel would rather hold onto recently-used pages than leave RAM idle,
 * unlike Windows' FreePhysicalMemory, which is a much more literal "unused"
 * count. Using "Pages free" alone would make the default 15% free-memory
 * warning fire permanently on a healthy Mac, which defeats the feature.
 *
 * "Pages inactive" and "Pages speculative" are both reclaimable without
 * swapping (inactive = not recently referenced, dropped under pressure;
 * speculative = spread out for possible readahead, never dirtied) — that
 * combination is the closest POSIX analogue to what FreePhysicalMemory
 * reports on Windows.
 *
 * "Pages purgeable" is deliberately excluded: it is not a fourth, disjoint
 * bucket — purgeable pages already live inside one of active/inactive/
 * speculative (an app marks pages it doesn't need right now as purgeable
 * without moving them out of their current state), so adding it in would
 * double-count memory `vm_stat` already reported above.
 */
export function parseVmStat(stdout: string): { pageSize: number; freeBytes: number } | undefined {
  const headerMatch = stdout.match(/page size of (\d+) bytes/);
  if (!headerMatch) return undefined;
  const pageSize = Number(headerMatch[1]);
  if (!Number.isFinite(pageSize) || pageSize <= 0) return undefined;

  const pageCount = (label: string): number | undefined => {
    // vm_stat lines look like "Pages free:                   5022." — a
    // label, colon, whitespace, digits, then a trailing period.
    const re = new RegExp(label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ':\\s+(\\d+)\\.');
    const m = stdout.match(re);
    return m ? Number(m[1]) : undefined;
  };

  const free = pageCount('Pages free');
  const inactive = pageCount('Pages inactive');
  const speculative = pageCount('Pages speculative');
  if (free === undefined || inactive === undefined || speculative === undefined) {
    return undefined;
  }

  const freeBytes = (free + inactive + speculative) * pageSize;
  return { pageSize, freeBytes };
}

/** macOS: total from `sysctl -n hw.memsize`, free from `vm_stat`, run in parallel. */
async function queryDarwinMemory(): Promise<SystemMemorySnapshot | undefined> {
  const [memsizeOut, vmStatOut] = await Promise.all([
    execFileSafe('sysctl', ['-n', 'hw.memsize']),
    execFileSafe('vm_stat', []),
  ]);
  if (memsizeOut === undefined || vmStatOut === undefined) return undefined;

  const totalBytes = parseHwMemsize(memsizeOut);
  const vmStat = parseVmStat(vmStatOut);
  if (totalBytes === undefined || vmStat === undefined) return undefined;

  const freeBytes = vmStat.freeBytes;
  return { totalBytes, freeBytes, freeFraction: freeBytes / totalBytes };
}

/**
 * Parse `/proc/meminfo` text into a snapshot.
 *
 * `MemAvailable` (present on kernels 3.14+) is used over `MemFree` for the
 * same reason as the macOS choice above: `MemFree` excludes the page cache,
 * which the kernel will happily hand back under pressure, so it understates
 * what is actually usable and would false-positive the low-memory warning.
 * `MemAvailable` is the kernel's own reclaimable-memory estimate.
 *
 * On very old kernels without `MemAvailable`, fall back to
 * `MemFree + Buffers + Cached` — the traditional hand-rolled approximation
 * of the same idea (page cache and buffers are reclaimable). If even those
 * fields are missing, resolve undefined rather than guess.
 */
export function parseMeminfo(text: string): SystemMemorySnapshot | undefined {
  const field = (label: string): number | undefined => {
    const m = text.match(new RegExp(`^${label}:\\s+(\\d+)\\s*kB`, 'm'));
    return m ? Number(m[1]) : undefined;
  };

  const totalKb = field('MemTotal');
  if (totalKb === undefined || totalKb <= 0) return undefined;

  let freeKb = field('MemAvailable');
  if (freeKb === undefined) {
    const memFree = field('MemFree');
    const buffers = field('Buffers');
    const cached = field('Cached');
    if (memFree === undefined || buffers === undefined || cached === undefined) {
      return undefined;
    }
    freeKb = memFree + buffers + cached;
  }

  const totalBytes = totalKb * 1024;
  const freeBytes = freeKb * 1024;
  return { totalBytes, freeBytes, freeFraction: freeBytes / totalBytes };
}

/** Linux: read and parse `/proc/meminfo`. */
async function queryLinuxMemory(): Promise<SystemMemorySnapshot | undefined> {
  let text: string;
  try {
    text = await fs.readFile('/proc/meminfo', 'utf8');
  } catch {
    return undefined;
  }
  return parseMeminfo(text);
}
