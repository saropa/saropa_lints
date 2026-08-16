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
  timestamp: number;
}

export const enum HealthLevel {
  Healthy = 'healthy',
  Warning = 'warning',
  Critical = 'critical',
}
