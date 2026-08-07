import { execFile } from 'node:child_process';
import type { DartProcessInfo, DartProcessSnapshot } from './types';

const BYTES_PER_GB = 1_073_741_824;
const MAX_BUFFER = 4 * 1024 * 1024;

export function formatBytes(bytes: number): string {
  if (bytes >= BYTES_PER_GB) {
    return `${(bytes / BYTES_PER_GB).toFixed(1)}G`;
  }
  const mb = bytes / (1024 * 1024);
  return `${Math.round(mb)}M`;
}

interface MinimalProcess {
  processId: number;
  creationDate: string;
}

export function queryDartProcesses(): Promise<DartProcessInfo[]> {
  if (process.platform !== 'win32') {
    return Promise.resolve([]);
  }
  return new Promise((resolve) => {
    const script =
      "Get-CimInstance Win32_Process -Filter \"Name = 'dart.exe' OR Name = 'dartvm.exe'\" " +
      '| Select-Object ProcessId, ParentProcessId, WorkingSetSize, CreationDate, CommandLine ' +
      '| ConvertTo-Json -Compress';
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
          const raw = JSON.parse(stdout);
          const arr: unknown[] = Array.isArray(raw) ? raw : [raw];
          resolve(arr.map(parseCimProcess));
        } catch {
          resolve([]);
        }
      },
    );
  });
}

// Queries the OS process table for a single PID. Returns undefined if
// the PID does not exist. Used to check whether a daemon's parent is
// still running — the parent is typically cmd.exe, Code.exe, or
// node.exe, NOT a dart process, so the dart-only list cannot be used.
function queryProcessById(pid: number): Promise<MinimalProcess | undefined> {
  return new Promise((resolve) => {
    const script =
      `Get-CimInstance Win32_Process -Filter "ProcessId = ${pid}" ` +
      '| Select-Object ProcessId, CreationDate ' +
      '| ConvertTo-Json -Compress';
    execFile(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-Command', script],
      { timeout: 10_000, maxBuffer: MAX_BUFFER },
      (err, stdout) => {
        if (err || !stdout.trim()) {
          resolve(undefined);
          return;
        }
        try {
          const raw = JSON.parse(stdout);
          const p = (Array.isArray(raw) ? raw[0] : raw) as Record<string, unknown>;
          resolve({
            processId: Number(p['ProcessId'] ?? 0),
            creationDate: String(p['CreationDate'] ?? ''),
          });
        } catch {
          resolve(undefined);
        }
      },
    );
  });
}

function parseCimProcess(item: unknown): DartProcessInfo {
  const p = item as Record<string, unknown>;
  return {
    processId: Number(p['ProcessId'] ?? p['processId'] ?? 0),
    parentProcessId: Number(p['ParentProcessId'] ?? p['parentProcessId'] ?? 0),
    workingSetSize: Number(p['WorkingSetSize'] ?? p['workingSetSize'] ?? 0),
    creationDate: String(p['CreationDate'] ?? p['creationDate'] ?? ''),
    commandLine: String(p['CommandLine'] ?? p['commandLine'] ?? ''),
  };
}

// WMI ConvertTo-Json emits DateTime as "/Date(1234567890000)/" (.NET JSON
// date format). `new Date()` does not parse this — extract the epoch ms.
function parseCimDate(raw: string): number {
  const match = /\/Date\((\d+)\)\//.exec(raw);
  if (match) return Number(match[1]);
  const ts = Date.parse(raw);
  return Number.isNaN(ts) ? 0 : ts;
}

function isParentAlive(
  parent: MinimalProcess | undefined,
  daemonCreation: string,
): boolean {
  if (!parent) return false;
  if (!parent.creationDate || !daemonCreation) return true;
  const parentTs = parseCimDate(parent.creationDate);
  const daemonTs = parseCimDate(daemonCreation);
  if (parentTs === 0 || daemonTs === 0) return true;
  return parentTs < daemonTs;
}

export function isDaemonProcess(p: DartProcessInfo): boolean {
  const cmd = p.commandLine ?? '';
  if (!cmd.includes('flutter_tools.snapshot')) return false;
  // Match "daemon" as a standalone argument, not as a substring of
  // unrelated tokens like "dart_tooling_daemon".
  return /\bdaemon\b/.test(cmd);
}

export function killProcess(pid: number): Promise<boolean> {
  return new Promise((resolve) => {
    execFile(
      'taskkill',
      ['/pid', String(pid), '/F'],
      { timeout: 10_000 },
      (err) => resolve(!err),
    );
  });
}

export async function buildSnapshot(
  processes: DartProcessInfo[],
): Promise<DartProcessSnapshot> {
  let totalRss = 0;
  const orphanPids: number[] = [];
  let legitimateCount = 0;

  for (const p of processes) {
    totalRss += p.workingSetSize;
  }

  const daemons = processes.filter(isDaemonProcess);

  // Collect unique parent PIDs so each is queried only once.
  const parentPids = [...new Set(daemons.map((d) => d.parentProcessId))];
  const parentMap = new Map<number, MinimalProcess | undefined>();
  await Promise.all(
    parentPids.map(async (pid) => {
      parentMap.set(pid, await queryProcessById(pid));
    }),
  );

  for (const d of daemons) {
    if (isParentAlive(parentMap.get(d.parentProcessId), d.creationDate)) {
      legitimateCount++;
    } else {
      orphanPids.push(d.processId);
    }
  }

  return {
    totalRssBytes: totalRss,
    processCount: processes.length,
    orphanedDaemonPids: orphanPids,
    legitimateDaemonCount: legitimateCount,
    timestamp: Date.now(),
  };
}
