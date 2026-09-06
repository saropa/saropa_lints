/**
 * Orphaned model-host detection for the activation preflight.
 *
 * WHY THIS EXISTS: on 2026-09-05 three `llama-server.exe` processes left
 * behind by the translation tooling were found holding 37 GB of committed
 * memory between them. Their parents had already exited, their working sets
 * were fully paged out, and they had been accumulating for two days. Windows
 * logged a low-virtual-memory condition roughly 40 times and VS Code's
 * renderer, GPU and extension host crashed repeatedly. Nothing was watching,
 * so nobody noticed. See
 * `bugs/infra_translation_engine_orphans_llama_server_processes.md`.
 *
 * The existing {@link buildSnapshot} path already answers the same question
 * for Dart and scan daemons ("is this process's parent still alive?"), so
 * this module deliberately reuses that definition of "orphan" rather than
 * inventing an age heuristic. An age heuristic would be wrong in both
 * directions: a legitimately long-running model host is not a leak, and a
 * five-minute-old process whose parent already died is.
 *
 * Everything here is process-table arithmetic with no `vscode` dependency so
 * the selection rules — including the self-protection guard — are unit
 * testable without an extension host.
 */

import { execFile } from 'node:child_process';

/** Cap on PowerShell stdout, matching processQuery.ts. */
const MAX_BUFFER = 4 * 1024 * 1024;

/**
 * Image names considered model hosts.
 *
 * `llama-server.exe` is the process that actually holds a loaded model in
 * committed memory and is the one that was orphaned in the incident.
 * `ollama.exe` is its parent daemon; it is cheap on its own but a dead-parent
 * `ollama.exe` with nothing left to serve is the same leak one level up.
 */
export const MODEL_HOST_PROCESS_NAMES: readonly string[] = [
  'llama-server.exe',
  'ollama.exe',
];

/** Image name of the model host proper — used for the "no live client" test. */
const MODEL_SERVER_NAME = 'llama-server.exe';

/** One row of the Windows process table, narrowed to what orphan selection needs. */
export interface HostProcessInfo {
  processId: number;
  parentProcessId: number;
  /** Image name, lower-cased by the parser so comparisons need no folding. */
  name: string;
  /** Commit charge in bytes (WMI `PageFileUsage`, which is reported in KB). */
  committedBytes: number;
  /** Process start time in epoch milliseconds; 0 when it could not be parsed. */
  createdAtMs: number;
}

/**
 * Inputs to {@link selectOrphanedHosts}. Passed as one object rather than four
 * positional arguments to stay within the project's three-parameter limit and
 * because every field is meaningless without the others.
 */
export interface OrphanSelectionInput {
  /** Every model-host process currently on the machine. */
  candidates: readonly HostProcessInfo[];
  /** PIDs of all live processes, used for the dead-parent test. */
  livePids: ReadonlySet<number>;
  /**
   * Epoch ms at which the current extension host started. Anything created at
   * or after this instant belongs to the running session and is never an
   * orphan from an earlier one — see the self-protection note below.
   */
  sessionStartMs: number;
  /** PIDs that must never be selected regardless of any other signal. */
  protectedPids: ReadonlySet<number>;
}

/** Result of a preflight scan: the orphans plus the memory they are holding. */
export interface OrphanHostScan {
  orphans: HostProcessInfo[];
  totalCommittedBytes: number;
}

/**
 * SELF-PROTECTION GUARD. Terminating a process is destructive and
 * irreversible, so a candidate is rejected outright when it could belong to
 * the running session:
 *
 *  1. Its PID is explicitly protected (the extension host itself and its
 *     parent — killing either takes VS Code down with it).
 *  2. It started at or after this extension host did. A model host this
 *     session launched cannot be an orphan of an *earlier* session by
 *     definition, and the whole point of the preflight is to reap what
 *     previous sessions left behind. A zero `createdAtMs` means the start
 *     time could not be read, and an unreadable start time must fail closed:
 *     we would rather leak memory than kill something live.
 */
function isProtected(p: HostProcessInfo, input: OrphanSelectionInput): boolean {
  if (input.protectedPids.has(p.processId)) return true;
  if (p.createdAtMs === 0) return true;
  return p.createdAtMs >= input.sessionStartMs;
}

/**
 * True when an `ollama.exe` daemon still has a live model host beneath it.
 *
 * The daemon is only reported when it has "no live client" — an `ollama.exe`
 * whose `llama-server.exe` child is still running is mid-serve, and killing
 * it would strand exactly the child this feature exists to prevent stranding.
 */
function hasLiveModelServerChild(
  daemon: HostProcessInfo,
  candidates: readonly HostProcessInfo[],
): boolean {
  return candidates.some(
    (c) => c.name === MODEL_SERVER_NAME && c.parentProcessId === daemon.processId,
  );
}

/**
 * Select the model-host processes that are orphans of an earlier session.
 *
 * The orphan test is the same one the Dart-daemon path uses: the parent PID is
 * no longer in the live process table. Age is deliberately not part of it.
 */
export function selectOrphanedHosts(
  input: OrphanSelectionInput,
): HostProcessInfo[] {
  return input.candidates.filter((p) => {
    if (isProtected(p, input)) return false;
    // Parent still running means something owns this process; not an orphan.
    if (input.livePids.has(p.parentProcessId)) return false;
    // A daemon that is still serving a model host is doing its job.
    if (p.name !== MODEL_SERVER_NAME) {
      return !hasLiveModelServerChild(p, input.candidates);
    }
    return true;
  });
}

/** Sum the commit charge of a set of orphans, for the "is this worth acting on" figure. */
export function totalCommittedBytes(orphans: readonly HostProcessInfo[]): number {
  return orphans.reduce((sum, p) => sum + p.committedBytes, 0);
}

/**
 * Epoch ms at which this extension host process started.
 *
 * Derived from `process.uptime()` rather than a module-load timestamp because
 * the preflight is deferred past activation — a load-time constant would drift
 * by however long activation took, and the guard needs the real process start.
 */
export function extensionHostStartMs(): number {
  return Date.now() - process.uptime() * 1000;
}

/** PIDs that must never be terminated: this process and whatever spawned it. */
export function protectedSessionPids(): Set<number> {
  const pids = new Set<number>([process.pid]);
  if (typeof process.ppid === 'number' && process.ppid > 0) {
    pids.add(process.ppid);
  }
  return pids;
}

/** Parse one CIM row into a {@link HostProcessInfo}, tolerating missing fields. */
function parseHostRow(item: unknown): HostProcessInfo {
  const p = item as Record<string, unknown>;
  return {
    processId: Number(p['ProcessId'] ?? 0),
    parentProcessId: Number(p['ParentProcessId'] ?? 0),
    // Lower-cased once here so every later comparison is a plain equality.
    name: String(p['Name'] ?? '').toLowerCase(),
    // WMI reports PageFileUsage in kilobytes; the UI works in bytes.
    committedBytes: Number(p['PageFileUsage'] ?? 0) * 1024,
    createdAtMs: parseCimDate(String(p['CreationDate'] ?? '')),
  };
}

/**
 * WMI's ConvertTo-Json emits DateTime as the .NET `/Date(1234567890000)/`
 * form, which `new Date()` does not understand. Mirrors the same helper in
 * processQuery.ts; duplicated rather than exported across modules because
 * that file's copy is private and this one parses a different row shape.
 */
export function parseCimDate(raw: string): number {
  const match = /\/Date\((\d+)\)\//.exec(raw);
  if (match) return Number(match[1]);
  const ts = Date.parse(raw);
  return Number.isNaN(ts) ? 0 : ts;
}

/** Run a PowerShell one-liner and resolve its parsed JSON rows, or [] on any failure. */
function runCimQuery(script: string): Promise<unknown[]> {
  return new Promise((resolve) => {
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: 15_000, maxBuffer: MAX_BUFFER },
      (err, stdout) => {
        if (err || !stdout.trim()) {
          resolve([]);
          return;
        }
        try {
          const raw: unknown = JSON.parse(stdout);
          resolve(Array.isArray(raw) ? raw : [raw]);
        } catch {
          // A malformed table is indistinguishable from an empty one for our
          // purposes: both mean "we cannot prove anything is an orphan".
          resolve([]);
        }
      },
    );
  });
}

/** Enumerate every model-host process on the machine. Windows-only; [] elsewhere. */
export async function queryModelHostProcesses(): Promise<HostProcessInfo[]> {
  if (process.platform !== 'win32') return [];
  const filter = MODEL_HOST_PROCESS_NAMES.map((n) => `Name = '${n}'`).join(' OR ');
  const script =
    `Get-CimInstance Win32_Process -Filter "${filter}" ` +
    '| Select-Object ProcessId, ParentProcessId, Name, PageFileUsage, CreationDate ' +
    '| ConvertTo-Json -Compress';
  const rows = await runCimQuery(script);
  return rows.map(parseHostRow);
}

/**
 * Every live PID on the machine.
 *
 * The whole table is needed because an orphan's parent is typically a shell,
 * a Python process, or Code.exe — never another model host — so the candidate
 * list cannot answer "is the parent alive?" on its own.
 */
export async function queryLivePids(): Promise<Set<number>> {
  if (process.platform !== 'win32') return new Set();
  const rows = await runCimQuery(
    'Get-CimInstance Win32_Process | Select-Object ProcessId | ConvertTo-Json -Compress',
  );
  const pids = new Set<number>();
  for (const row of rows) {
    const pid = Number((row as Record<string, unknown>)['ProcessId'] ?? 0);
    if (pid > 0) pids.add(pid);
  }
  return pids;
}

/** Query the machine and apply {@link selectOrphanedHosts} to what comes back. */
export async function scanOrphanedHosts(): Promise<OrphanHostScan> {
  const [candidates, livePids] = await Promise.all([
    queryModelHostProcesses(),
    queryLivePids(),
  ]);
  const orphans = selectOrphanedHosts({
    candidates,
    livePids,
    sessionStartMs: extensionHostStartMs(),
    protectedPids: protectedSessionPids(),
  });
  return { orphans, totalCommittedBytes: totalCommittedBytes(orphans) };
}

/**
 * Terminate a process AND its children.
 *
 * `/T` is not optional here: the incident's root cause was a force kill
 * without it, which reaped `ollama.exe` and left its `llama-server.exe` child
 * running with the model still committed. Reclaiming an orphan with the same
 * broken kill would simply move the leak down one level.
 */
export function killProcessTree(pid: number): Promise<boolean> {
  return new Promise((resolve) => {
    execFile(
      'taskkill',
      ['/PID', String(pid), '/T', '/F'],
      { timeout: 10_000 },
      (err) => resolve(!err),
    );
  });
}
