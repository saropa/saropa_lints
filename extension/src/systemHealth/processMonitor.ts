import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import type { DartProcessSnapshot } from './types';
import { HealthLevel } from './types';
import { buildSnapshot, formatBytes, queryDartProcesses } from './processQuery';

const BYTES_PER_GB = 1_073_741_824;

export interface SystemHealthConfig {
  enabled: boolean;
  pollIntervalSeconds: number;
  warningThresholdGB: number;
  criticalThresholdGB: number;
  warningOrphanCount: number;
  criticalOrphanCount: number;
  showNotifications: boolean;
}

export function readSystemHealthConfig(): SystemHealthConfig {
  const cfg = vscode.workspace.getConfiguration('saropaLints.systemHealth');
  return {
    enabled: cfg.get<boolean>('enabled', true),
    pollIntervalSeconds: cfg.get<number>('pollIntervalSeconds', 60),
    warningThresholdGB: cfg.get<number>('warningThresholdGB', 4),
    criticalThresholdGB: cfg.get<number>('criticalThresholdGB', 6),
    warningOrphanCount: cfg.get<number>('warningOrphanCount', 1),
    criticalOrphanCount: cfg.get<number>('criticalOrphanCount', 4),
    showNotifications: cfg.get<boolean>('showNotifications', true),
  };
}

export function classifyHealth(
  snapshot: DartProcessSnapshot,
  config: SystemHealthConfig,
): HealthLevel {
  const rssGB = snapshot.totalRssBytes / BYTES_PER_GB;
  // Both Flutter daemon and scan daemon orphans count toward the threshold.
  const orphans = snapshot.orphanedDaemonPids.length + snapshot.orphanedScanDaemonPids.length;
  if (rssGB >= config.criticalThresholdGB || orphans >= config.criticalOrphanCount) {
    return HealthLevel.Critical;
  }
  if (rssGB >= config.warningThresholdGB || orphans >= config.warningOrphanCount) {
    return HealthLevel.Warning;
  }
  return HealthLevel.Healthy;
}

export type SnapshotListener = (
  snapshot: DartProcessSnapshot,
  level: HealthLevel,
) => void;

export class ProcessMonitor implements vscode.Disposable {
  private timer: ReturnType<typeof setInterval> | undefined;
  private lastNotificationTime = 0;
  private disposed = false;
  private readonly listeners: SnapshotListener[] = [];
  private lastSnapshot: DartProcessSnapshot | undefined;

  start(): void {
    if (this.disposed) return;
    this.stop();
    const config = readSystemHealthConfig();
    if (!config.enabled || process.platform !== 'win32') return;

    const pollMs = Math.max(config.pollIntervalSeconds, 10) * 1000;
    this.poll();
    this.timer = setInterval(() => this.poll(), pollMs);
  }

  stop(): void {
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = undefined;
    }
  }

  onSnapshot(listener: SnapshotListener): void {
    this.listeners.push(listener);
  }

  getLastSnapshot(): DartProcessSnapshot | undefined {
    return this.lastSnapshot;
  }

  private async poll(): Promise<void> {
    if (this.disposed) return;
    try {
      const processes = await queryDartProcesses();
      const snapshot = await buildSnapshot(processes);
      this.lastSnapshot = snapshot;
      const config = readSystemHealthConfig();
      const level = classifyHealth(snapshot, config);

      for (const fn of this.listeners) fn(snapshot, level);

      if (level === HealthLevel.Critical && config.showNotifications) {
        this.showCriticalNotification(snapshot);
      }
    } catch {
      // Next poll will retry.
    }
  }

  private showCriticalNotification(snapshot: DartProcessSnapshot): void {
    const now = Date.now();
    if (now - this.lastNotificationTime < 5 * 60 * 1000) return;
    this.lastNotificationTime = now;

    const size = formatBytes(snapshot.totalRssBytes);
    // Include both Flutter daemon and scan daemon orphans in the count.
    const totalOrphans = snapshot.orphanedDaemonPids.length + snapshot.orphanedScanDaemonPids.length;
    const orphaned = String(totalOrphans);
    const msg = l10n('systemHealth.notification.critical', { size, orphaned });
    const cleanUp = l10n('systemHealth.action.cleanUp');
    const optimize = l10n('systemHealth.action.optimizeAnalysis');
    const dontShow = l10n('systemHealth.action.dontShowAgain');

    void vscode.window.showWarningMessage(msg, cleanUp, optimize, dontShow).then((choice) => {
      if (choice === cleanUp) {
        void vscode.commands.executeCommand('saropaLints.killOrphanedDaemons');
      } else if (choice === optimize) {
        void vscode.commands.executeCommand('saropaLints.openAnalysisOptimizer');
      } else if (choice === dontShow) {
        void vscode.workspace
          .getConfiguration('saropaLints.systemHealth')
          .update('showNotifications', false, vscode.ConfigurationTarget.Global);
      }
    });
  }

  dispose(): void {
    this.disposed = true;
    this.stop();
    this.listeners.length = 0;
  }
}
