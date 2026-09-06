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
