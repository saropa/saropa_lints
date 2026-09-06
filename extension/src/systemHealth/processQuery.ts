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

/**
 * True when the process is a Dart analysis server. Matches multiple
 * patterns to survive Dart SDK binary renames:
 * - `language-server` (current LSP binary name)
 * - `analysis_server` (snapshot-based invocation)
 * - `--protocol=lsp` (protocol flag present regardless of binary name)
 */
export function isAnalysisServerProcess(p: DartProcessInfo): boolean {
  const cmd = p.commandLine ?? '';
  return cmd.includes('language-server')
    || cmd.includes('analysis_server')
    || cmd.includes('--protocol=lsp');
}

/** True when the process is a saropa_lints scan daemon or CLI scan. */
export function isSaropaProcess(p: DartProcessInfo): boolean {
  const cmd = p.commandLine ?? '';
  return cmd.includes('saropa_lints:scan_daemon') || cmd.includes('saropa_lints:scan');
}

/** True when the process is specifically the long-lived scan daemon. */
export function isScanDaemonProcess(p: DartProcessInfo): boolean {
  return (p.commandLine ?? '').includes('saropa_lints:scan_daemon');
}

/**
 * Max label length for tooltip display — long labels break VS Code
 * tooltip layout. Known labels are all well under this; the guard
 * catches unexpected command lines that reach the fallback path.
 */
const MAX_LABEL_LENGTH = 30;

/**
 * Derive a short human-readable label from a dart process command line.
 * Used in the tooltip per-process breakdown so users can identify what
 * each process is without reading raw command strings.
 *
 * Known labels are all static strings well under MAX_LABEL_LENGTH.
 * The guard exists for the fallback path where an unrecognized process
 * might produce a longer label in a future extension of this function.
 */
export function processLabel(p: DartProcessInfo): string {
  const cmd = p.commandLine ?? '';
  // Saropa-owned processes — most specific matches first.
  if (cmd.includes('saropa_lints:scan_daemon')) return 'scan daemon';
  if (cmd.includes('saropa_lints:scan')) return 'scan CLI';
  if (cmd.includes('saropa_lints')) return 'saropa_lints';
  // Dart analysis server — delegate detection to the shared predicate.
  if (isAnalysisServerProcess(p)) {
    // Flag uncapped heap — an uncapped server can grow without bound and
    // is the single most common cause of high system-wide Dart RSS.
    const capped = cmd.includes('--old_gen_heap_size');
    return capped ? 'analysis server' : 'analysis server (no heap cap)';
  }
  // Flutter daemon (long-lived tooling process).
  if (cmd.includes('flutter_tools.snapshot') && /\bdaemon\b/.test(cmd)) {
    return 'Flutter daemon';
  }
  // Build-related processes.
  if (cmd.includes('frontend_server') || cmd.includes('frontend_compiler')) {
    return 'frontend compiler';
  }
  if (cmd.includes('build_runner')) return 'build runner';
  // Fallback — generic label, truncated for tooltip width safety.
  return 'dart process';
}

/** Truncate a process label if it exceeds tooltip width constraints. */
export function truncateLabel(label: string): string {
  if (label.length <= MAX_LABEL_LENGTH) return label;
  return label.slice(0, MAX_LABEL_LENGTH - 1) + '…';
}

/**
 * Unicode block characters for sparkline rendering, from lowest to tallest.
 * Eight levels give enough visual resolution for a 30-sample tooltip line
 * without needing a full chart library.
 */
const SPARK_CHARS = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];

/**
 * Render a series of numeric samples as a single-line Unicode sparkline.
 * Returns an empty string when there are fewer than 2 data points (a
 * single dot has no shape to show). Exported for testing.
 */
export function renderSparkline(samples: readonly number[]): string {
  if (samples.length < 2) return '';
  // Reduce instead of Math.min/max spread — spread hits the call stack
  // limit around 10k+ elements. Safe at 30 today, but future-proof.
  let min = samples[0];
  let max = samples[0];
  for (const v of samples) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  // Flat line — all values identical, render mid-height bars.
  if (max === min) return SPARK_CHARS[3].repeat(samples.length);
  const range = max - min;
  return samples
    .map((v) => {
      // Map each value to a bar index (0–7). Clamp to handle rounding.
      const idx = Math.min(Math.floor(((v - min) / range) * SPARK_CHARS.length), SPARK_CHARS.length - 1);
      return SPARK_CHARS[idx];
    })
    .join('');
}

/**
 * Minimum number of recent samples needed before leak detection kicks in.
 * 10 samples ≈ 10 minutes at the default 60-second poll.
 */
const LEAK_WINDOW = 10;

/**
 * How many of the last LEAK_WINDOW samples must be rising (each ≥ its
 * predecessor) to flag a possible leak. 8/10 tolerates brief GC dips
 * without missing a sustained upward trend.
 */
const LEAK_THRESHOLD = 8;

/**
 * Detect monotonically rising RSS that may indicate a memory leak.
 * Returns true when at least LEAK_THRESHOLD of the last LEAK_WINDOW
 * consecutive comparisons show a non-decreasing trend. Exported for testing.
 *
 * A "rising comparison" is samples[i] >= samples[i-1] (non-strict: flat
 * segments count as "not falling", which is conservative — a leak that
 * plateaus briefly before resuming still triggers).
 */
export function detectMonotonicGrowth(samples: readonly number[]): boolean {
  if (samples.length < LEAK_WINDOW) return false;
  // Only inspect the most recent window.
  const window = samples.slice(-LEAK_WINDOW);
  let risingCount = 0;
  for (let i = 1; i < window.length; i++) {
    if (window[i] >= window[i - 1]) risingCount++;
  }
  // LEAK_WINDOW samples yield LEAK_WINDOW-1 comparisons.
  return risingCount >= LEAK_THRESHOLD;
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
  let saropaRss = 0;
  let saropaCount = 0;
  const orphanPids: number[] = [];
  const orphanScanDaemonPids: number[] = [];
  let legitimateCount = 0;

  for (const p of processes) {
    totalRss += p.workingSetSize;
    // Separate saropa_lints processes from system-wide dart totals.
    if (isSaropaProcess(p)) {
      saropaRss += p.workingSetSize;
      saropaCount++;
    }
  }

  // Flutter daemons + scan daemons both need orphan detection.
  const flutterDaemons = processes.filter(isDaemonProcess);
  const scanDaemons = processes.filter(isScanDaemonProcess);

  // Collect unique parent PIDs so each is queried only once.
  const allOrphanCandidates = [...flutterDaemons, ...scanDaemons];
  const parentPids = [...new Set(allOrphanCandidates.map((d) => d.parentProcessId))];
  const parentMap = new Map<number, MinimalProcess | undefined>();
  await Promise.all(
    parentPids.map(async (pid) => {
      parentMap.set(pid, await queryProcessById(pid));
    }),
  );

  // Check Flutter daemon orphans (existing behavior).
  for (const d of flutterDaemons) {
    if (isParentAlive(parentMap.get(d.parentProcessId), d.creationDate)) {
      legitimateCount++;
    } else {
      orphanPids.push(d.processId);
    }
  }

  // Check scan daemon orphans — a VS Code crash leaves these running.
  for (const d of scanDaemons) {
    if (!isParentAlive(parentMap.get(d.parentProcessId), d.creationDate)) {
      orphanScanDaemonPids.push(d.processId);
    }
  }

  return {
    totalRssBytes: totalRss,
    processCount: processes.length,
    orphanedDaemonPids: orphanPids,
    legitimateDaemonCount: legitimateCount,
    saropaRssBytes: saropaRss,
    saropaProcessCount: saropaCount,
    orphanedScanDaemonPids: orphanScanDaemonPids,
    // Keep the full list for per-process tooltip breakdown.
    processes,
    timestamp: Date.now(),
  };
}
