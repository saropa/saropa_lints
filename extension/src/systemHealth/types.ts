// One row from the Windows process query (WMI/tasklist), covering a
// single dart.exe/analysis-server process.
export interface DartProcessInfo {
  processId: number;
  parentProcessId: number;
  workingSetSize: number;
  creationDate: string;
  commandLine: string;
}

// Point-in-time rollup used to populate the panel's summary bar and to
// decide which pids get the "orphan" pill (parentProcessId no longer alive).
export interface DartProcessSnapshot {
  totalRssBytes: number;
  processCount: number;
  orphanedDaemonPids: number[];
  legitimateDaemonCount: number;
  /** RSS from saropa_lints-spawned processes (scan daemon, CLI scans). */
  saropaRssBytes: number;
  /** Count of saropa_lints-spawned processes currently alive. */
  saropaProcessCount: number;
  /** Orphaned scan daemon PIDs (parent process no longer alive). */
  orphanedScanDaemonPids: number[];
  /** All enumerated processes, kept for per-process tooltip breakdown. */
  processes: DartProcessInfo[];
  timestamp: number;
}

export const enum HealthLevel {
  Healthy = 'healthy',
  Warning = 'warning',
  Critical = 'critical',
}

/**
 * Why {@link classifyHealth} left the Healthy band.
 *
 * The status bar has one line of text and must name the thing that actually
 * tripped: an orphan-driven Critical that renders an RSS figure reads as
 * "this memory number is the crisis" even when that number is tiny and
 * perfectly healthy. Carrying the trigger alongside the level lets the
 * status bar pick the right sentence instead of guessing.
 */
export const enum HealthTrigger {
  /** Healthy — nothing to report. */
  None = 'none',
  /** Aggregate Dart process RSS crossed a configured threshold. */
  Memory = 'memory',
  /** Orphaned daemon count crossed a configured threshold; RSS may be fine. */
  Orphans = 'orphans',
}

/** A health level together with the reason it was reached. */
export interface HealthAssessment {
  level: HealthLevel;
  trigger: HealthTrigger;
  /** Combined Flutter-daemon + scan-daemon orphan count behind the trigger. */
  orphanCount: number;
}

/**
 * Point-in-time snapshot of the VS Code extension host Node.js process
 * memory, from `process.memoryUsage()`. Tracked separately from Dart
 * processes because the host's own heap exhaustion was the root cause
 * of the 2026-09-05 crash — the existing WMI monitor was blind to it.
 */
export interface ExtensionHostMemory {
  /** Resident set size — total memory allocated to the Node.js process. */
  rssBytes: number;
  /** V8 heap actually in use. */
  heapUsedBytes: number;
  /** V8 heap allocated (including free regions waiting for GC). */
  heapTotalBytes: number;
  /** Memory used by C++ objects bound to JS (Buffers, etc.). */
  externalBytes: number;
  /** SharedArrayBuffer + ArrayBuffer memory. */
  arrayBuffersBytes: number;
  /** Millisecond timestamp when the sample was taken. */
  timestamp: number;
}
