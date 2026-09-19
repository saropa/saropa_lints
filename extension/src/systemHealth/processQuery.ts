import { execFile } from 'node:child_process';
import type { DartProcessInfo, DartProcessSnapshot } from './types';

const BYTES_PER_GB = 1_073_741_824;
const MAX_BUFFER = 4 * 1024 * 1024;

// ── Process classification markers ──
// Centralised so that isDaemonProcess, isSaropaProcess, processLabel, and the
// tooltip partition filter all match on the same strings. If the Dart SDK or
// saropa_lints renames a binary, update these constants — not every callsite.
// Exported so tests can verify substring containment invariants directly.

/** Substring present in every Flutter daemon command line. */
export const FLUTTER_TOOLS_MARKER = 'flutter_tools.snapshot';
/** Saropa scan daemon entry point — the long-lived background worker. */
export const SAROPA_SCAN_DAEMON_MARKER = 'saropa_lints:scan_daemon';
/** Saropa CLI scan entry point (one-shot scan, not the daemon). */
export const SAROPA_SCAN_MARKER = 'saropa_lints:scan';
/** Generic saropa_lints marker — matches daemon, scan, and any future entry point. */
export const SAROPA_PACKAGE_MARKER = 'saropa_lints';
/** Current Dart LSP binary name. */
export const ANALYSIS_SERVER_LSP_BINARY = 'language-server';
/** Legacy/snapshot-based analysis server invocation. */
export const ANALYSIS_SERVER_SNAPSHOT = 'analysis_server';
/** Protocol flag that identifies an analysis server regardless of binary name. */
export const ANALYSIS_SERVER_PROTOCOL_FLAG = '--protocol=lsp';
/** Flag that caps the analysis server's old-gen heap. */
export const HEAP_CAP_FLAG = '--old_gen_heap_size';

/**
 * Tooltip partition categories. Every dart process falls into exactly one.
 * The enum drives classifyProcess(), and the boolean predicates
 * (isSaropaProcess, isDaemonProcess) delegate to it — so the ordering
 * logic lives in one place rather than being duplicated and driftable.
 */
export const enum ProcessCategory {
  /** saropa_lints scan daemon or CLI scan. */
  Saropa = 'saropa',
  /** Flutter daemon (flutter_tools.snapshot + \bdaemon\b). */
  Daemon = 'daemon',
  /** Dart analysis server (LSP binary, snapshot, or protocol flag). */
  AnalysisServer = 'analysisServer',
  /** Any other dart process (build runner, frontend compiler, etc.). */
  Other = 'other',
}

/** Result of classifyProcess — the category plus a human-readable label. */
export interface ProcessClassification {
  /** Which tooltip section this process belongs to. */
  readonly category: ProcessCategory;
  /** Short human-readable label for tooltip display. */
  readonly label: string;
}

/**
 * Single source of truth for process classification. Every predicate and
 * processLabel delegates here, so the match ordering (most-specific first)
 * is enforced in one place. The ordering invariant:
 *   SAROPA_SCAN_DAEMON_MARKER before SAROPA_SCAN_MARKER (daemon is a
 *   superset: "saropa_lints:scan_daemon" contains "saropa_lints:scan").
 */
export function classifyProcess(p: DartProcessInfo): ProcessClassification {
  const cmd = p.commandLine ?? '';
  // Saropa-owned — most specific marker first because scan_daemon
  // contains the scan marker as a prefix.
  if (cmd.includes(SAROPA_SCAN_DAEMON_MARKER)) {
    return { category: ProcessCategory.Saropa, label: 'scan daemon' };
  }
  if (cmd.includes(SAROPA_SCAN_MARKER)) {
    return { category: ProcessCategory.Saropa, label: 'scan CLI' };
  }
  if (cmd.includes(SAROPA_PACKAGE_MARKER)) {
    return { category: ProcessCategory.Saropa, label: 'saropa_lints' };
  }
  // Analysis server — multiple patterns to survive binary renames.
  if (cmd.includes(ANALYSIS_SERVER_LSP_BINARY)
    || cmd.includes(ANALYSIS_SERVER_SNAPSHOT)
    || cmd.includes(ANALYSIS_SERVER_PROTOCOL_FLAG)) {
    const capped = cmd.includes(HEAP_CAP_FLAG);
    return {
      category: ProcessCategory.AnalysisServer,
      label: capped ? 'analysis server' : 'analysis server (no heap cap)',
    };
  }
  // Flutter daemon — requires flutter_tools.snapshot AND word-boundary "daemon".
  if (cmd.includes(FLUTTER_TOOLS_MARKER) && /\bdaemon\b/.test(cmd)) {
    return { category: ProcessCategory.Daemon, label: 'Flutter daemon' };
  }
  // Build-related processes fall through to Other with specific labels.
  if (cmd.includes('frontend_server') || cmd.includes('frontend_compiler')) {
    return { category: ProcessCategory.Other, label: 'frontend compiler' };
  }
  if (cmd.includes('build_runner')) {
    return { category: ProcessCategory.Other, label: 'build runner' };
  }
  return { category: ProcessCategory.Other, label: 'dart process' };
}

export function formatBytes(bytes: number): string {
  if (bytes >= BYTES_PER_GB) {
    return `${(bytes / BYTES_PER_GB).toFixed(1)}G`;
  }
  const mb = bytes / (1024 * 1024);
  return `${Math.round(mb)}M`;
}

export interface MinimalProcess {
  processId: number;
  creationDate: string;
}

export function queryDartProcesses(): Promise<DartProcessInfo[]> {
  if (process.platform !== 'win32') {
    return queryDartProcessesPosix();
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

/**
 * Executable basenames treated as "a dart process" on POSIX. Deliberately
 * wider than the Windows filter (dart.exe / dartvm.exe): on macOS/Linux the
 * analysis server, `flutter test` runs, and AOT-compiled tooling frequently
 * execute under `dartaotruntime` or `flutter_tester` rather than the plain
 * `dart`/`dartvm` binary, and those still need to show up for RSS accounting
 * and orphan detection.
 */
const POSIX_DART_IMAGES = new Set(['dart', 'dartvm', 'dartaotruntime', 'flutter_tester']);

// `ps` lstart is a fixed-format "Www Mmm d(d) hh:mm:ss yyyy" string (e.g.
// "Thu Sep 18 10:15:02 2026" — a single-digit day is space-padded to two
// columns, e.g. "Fri Sep  8 21:38:25 2026"). Matched explicitly rather than
// via a plain whitespace split, since the trailing `command` column can
// itself contain runs of spaces.
// lstart is rendered through the C library's locale (a German locale prints
// "Sa. 19 Sep. 08:00:50 2026"), so every `ps` call runs with LC_ALL=C to keep
// the English shape the pattern below expects. Without it, a non-English
// locale makes every line unparseable and the monitor silently sees nothing.
const PS_ENV: NodeJS.ProcessEnv = { ...process.env, LC_ALL: 'C' };

const PS_LSTART_GROUP = '\\S{3}\\s+\\S{3}\\s+\\d{1,2}\\s+\\d{2}:\\d{2}:\\d{2}\\s+\\d{4}';

/**
 * Parse one line of `ps -o pid=,ppid=,rss=,lstart=,command=` output. Returns
 * undefined for a line that doesn't match the expected shape (e.g. a stray
 * blank line). Exported for testing without shelling out to `ps`.
 *
 * The three leading numeric columns are right-justified with variable
 * width, so this can't be a single whitespace split — it consumes them
 * greedily, then anchors on the fixed-width lstart pattern, leaving
 * everything after it (which may contain spaces) as the command.
 */
export function parsePsProcessLine(
  line: string,
): { pid: number; ppid: number; rssKb: number; lstart: string; command: string } | undefined {
  const pattern = new RegExp(`^\\s*(\\d+)\\s+(\\d+)\\s+(\\d+)\\s+(${PS_LSTART_GROUP})\\s+(.*)$`);
  const m = pattern.exec(line);
  if (!m) return undefined;
  return { pid: Number(m[1]), ppid: Number(m[2]), rssKb: Number(m[3]), lstart: m[4], command: m[5] };
}

/**
 * Convert a `ps` lstart string ("Thu Sep 18 10:15:02 2026") to ISO-8601 so
 * it round-trips through the same `Date.parse` fallback that already
 * handles non-CIM date strings in {@link parseCimDate}. Returns '' when the
 * input can't be parsed, matching the "unknown creation date" contract a
 * missing Windows CreationDate already has.
 */
export function parsePsLstart(lstart: string): string {
  // Collapse the double space before a single-digit day ("Sep  8") — V8's
  // Date.parse tolerates it, but normalizing keeps this function's
  // contract unambiguous rather than relying on engine leniency.
  const normalized = lstart.replace(/\s+/g, ' ').trim();
  const ts = Date.parse(normalized);
  return Number.isNaN(ts) ? '' : new Date(ts).toISOString();
}

/**
 * Best-effort basename of a command line's argv[0] (the executable path).
 * `ps command=` prints the full argv, space-joined with no quoting, so an
 * argv[0] containing a literal space is indistinguishable from the start of
 * argv[1] and would mis-split here. Accepted limitation: real Dart/Flutter
 * SDK install paths do not contain spaces in practice.
 */
function argv0Basename(command: string): string {
  const argv0 = command.trimStart().split(' ', 1)[0] ?? '';
  const parts = argv0.split('/');
  return parts[parts.length - 1] ?? '';
}

/**
 * Parse the full stdout of `ps -axww -o pid=,ppid=,rss=,lstart=,command=`
 * into dart processes, filtered to {@link POSIX_DART_IMAGES} by the argv[0]
 * basename — not a substring match on the full command line, which would
 * also match unrelated processes run from e.g. a `~/dart-tools/` checkout.
 * RSS is reported in KB; converted to bytes to match `workingSetSize`
 * elsewhere. Pure/exported so tests can feed captured `ps` samples.
 */
export function parsePsDartProcesses(stdout: string): DartProcessInfo[] {
  const out: DartProcessInfo[] = [];
  for (const line of stdout.split('\n')) {
    if (!line.trim()) continue;
    const parsed = parsePsProcessLine(line);
    if (!parsed) continue;
    if (!POSIX_DART_IMAGES.has(argv0Basename(parsed.command))) continue;
    out.push({
      processId: parsed.pid,
      parentProcessId: parsed.ppid,
      workingSetSize: parsed.rssKb * 1024,
      creationDate: parsePsLstart(parsed.lstart),
      commandLine: parsed.command,
    });
  }
  return out;
}

function queryDartProcessesPosix(): Promise<DartProcessInfo[]> {
  return new Promise((resolve) => {
    // -a: all users' processes, -x: include processes without a controlling
    // tty, -ww: never truncate the command column. `command` must be last
    // since it's the only column that can contain spaces.
    execFile(
      'ps',
      ['-axww', '-o', 'pid=,ppid=,rss=,lstart=,command='],
      { timeout: 15_000, maxBuffer: MAX_BUFFER, env: PS_ENV },
      (err, stdout) => resolve(err || !stdout.trim() ? [] : parsePsDartProcesses(stdout)),
    );
  });
}

/**
 * Parse `ps -o pid=,lstart= -p <pid>` output (a single matched process, no
 * header row). Returns undefined for empty/unparseable output, matching the
 * "process not found" contract of the CIM path. Exported for testing.
 */
export function parsePsSingleProcess(stdout: string): MinimalProcess | undefined {
  const line = stdout.split('\n').find((l) => l.trim());
  if (!line) return undefined;
  const pattern = new RegExp(`^\\s*(\\d+)\\s+(${PS_LSTART_GROUP})\\s*$`);
  const m = pattern.exec(line);
  if (!m) return undefined;
  return { processId: Number(m[1]), creationDate: parsePsLstart(m[2]) };
}

// Queries the OS process table for a single PID. Returns undefined if
// the PID does not exist. Used to check whether a daemon's parent is
// still running — the parent is typically cmd.exe, Code.exe, or
// node.exe, NOT a dart process, so the dart-only list cannot be used.
function queryProcessById(pid: number): Promise<MinimalProcess | undefined> {
  if (process.platform !== 'win32') {
    // `ps -p <pid>` exits 1 with empty stdout when the pid doesn't exist —
    // that's an ordinary "not found" outcome here, not an error. Getting
    // this branch wrong (e.g. omitting a POSIX implementation entirely, as
    // this function used to) makes every daemon look orphaned on macOS/
    // Linux: a failed lookup resolves to undefined -> isParentAlive() ->
    // false for every daemon, which would prompt the user to kill live,
    // healthy processes.
    return new Promise((resolve) => {
      execFile(
        'ps',
        ['-o', 'pid=,lstart=', '-p', String(pid)],
        { timeout: 10_000, maxBuffer: MAX_BUFFER, env: PS_ENV },
        (err, stdout) => resolve(err || !stdout.trim() ? undefined : parsePsSingleProcess(stdout)),
      );
    });
  }
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

/**
 * A parent is alive if its pid exists and it started no later than the
 * daemon (a later start means the pid was reused by an unrelated process).
 * Equal timestamps count as alive: `ps lstart` has one-second resolution, so
 * a daemon spawned in the same second as its parent reads as equal, and a
 * strict `<` would flag a healthy daemon as orphaned. Exported for testing.
 */
export function isParentAlive(
  parent: MinimalProcess | undefined,
  daemonCreation: string,
): boolean {
  if (!parent) return false;
  if (!parent.creationDate || !daemonCreation) return true;
  const parentTs = parseCimDate(parent.creationDate);
  const daemonTs = parseCimDate(daemonCreation);
  if (parentTs === 0 || daemonTs === 0) return true;
  return parentTs <= daemonTs;
}

/** Delegates to classifyProcess — true for flutter_tools.snapshot + daemon. */
export function isDaemonProcess(p: DartProcessInfo): boolean {
  return classifyProcess(p).category === ProcessCategory.Daemon;
}

/** Delegates to classifyProcess — true for any analysis server variant. */
export function isAnalysisServerProcess(p: DartProcessInfo): boolean {
  return classifyProcess(p).category === ProcessCategory.AnalysisServer;
}

/** Delegates to classifyProcess — true for any saropa_lints entry point. */
export function isSaropaProcess(p: DartProcessInfo): boolean {
  return classifyProcess(p).category === ProcessCategory.Saropa;
}

/** True when the process is specifically the long-lived scan daemon. */
export function isScanDaemonProcess(p: DartProcessInfo): boolean {
  return (p.commandLine ?? '').includes(SAROPA_SCAN_DAEMON_MARKER);
}

/**
 * Max label length for tooltip display — long labels break VS Code
 * tooltip layout. Known labels are all well under this; the guard
 * catches unexpected command lines that reach the fallback path.
 */
const MAX_LABEL_LENGTH = 30;

/**
 * Derive a short human-readable label from a dart process command line.
 * Delegates to classifyProcess so the match ordering is never duplicated.
 */
export function processLabel(p: DartProcessInfo): string {
  return classifyProcess(p).label;
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
  if (process.platform !== 'win32') {
    try {
      process.kill(pid, 'SIGKILL');
      return Promise.resolve(true);
    } catch {
      return Promise.resolve(false);
    }
  }
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
