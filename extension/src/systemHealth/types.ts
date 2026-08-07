export interface DartProcessInfo {
  processId: number;
  parentProcessId: number;
  workingSetSize: number;
  creationDate: string;
  commandLine: string;
}

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
