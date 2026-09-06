import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import type { DartProcessSnapshot, HealthAssessment } from './types';
import { HealthLevel, HealthTrigger } from './types';
import { buildSnapshot, detectMonotonicGrowth, formatBytes, queryDartProcesses } from './processQuery';

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

/**
 * Classify a snapshot AND record why it was classified that way.
 *
 * Thresholds are compared against saropa-owned RSS only (scan daemon, CLI
 * scans) — NOT the system-wide Dart total. A 12 GB analysis server is not
 * saropa_lints' fault and must not make the saropa_lints indicator red.
 * The system-wide total is still shown in the tooltip as informational.
 *
 * Memory is evaluated before orphans at each level so that when both trip,
 * the trigger reported is the one the numeric status-bar figure describes.
 */
export function assessHealth(
  snapshot: DartProcessSnapshot,
  config: SystemHealthConfig,
): HealthAssessment {
  // Only saropa-owned RSS drives the color — the fix for false attribution
  // where external analysis servers made saropa_lints' status bar go red.
  const rssGB = snapshot.saropaRssBytes / BYTES_PER_GB;
  // Both Flutter daemon and scan daemon orphans count toward the threshold.
  const orphans = snapshot.orphanedDaemonPids.length + snapshot.orphanedScanDaemonPids.length;

  if (rssGB >= config.criticalThresholdGB) {
    return { level: HealthLevel.Critical, trigger: HealthTrigger.Memory, orphanCount: orphans };
  }
  if (orphans >= config.criticalOrphanCount) {
    return { level: HealthLevel.Critical, trigger: HealthTrigger.Orphans, orphanCount: orphans };
  }
  if (rssGB >= config.warningThresholdGB) {
    return { level: HealthLevel.Warning, trigger: HealthTrigger.Memory, orphanCount: orphans };
  }
  if (orphans >= config.warningOrphanCount) {
    return { level: HealthLevel.Warning, trigger: HealthTrigger.Orphans, orphanCount: orphans };
  }
  return { level: HealthLevel.Healthy, trigger: HealthTrigger.None, orphanCount: orphans };
}

/**
 * Level-only view of {@link assessHealth}, kept for callers that genuinely
 * do not care why the level was reached (notifications, panel badges).
 */
export function classifyHealth(
  snapshot: DartProcessSnapshot,
  config: SystemHealthConfig,
): HealthLevel {
  return assessHealth(snapshot, config).level;
}

/**
 * Build the memory/system-health status-bar text for an assessment, or
 * undefined when there is nothing to report.
 *
 * The text must name the trigger. Orphan triggers get their own strings
 * and never show bytes. Memory triggers show the saropa-owned RSS — the
 * number that actually tripped the threshold — not the system-wide total.
 */
export function systemHealthStatusBarText(
  snapshot: DartProcessSnapshot,
  assessment: HealthAssessment,
): string | undefined {
  if (assessment.level === HealthLevel.Healthy) return undefined;

  const critical = assessment.level === HealthLevel.Critical;
  if (assessment.trigger === HealthTrigger.Orphans) {
    const count = String(assessment.orphanCount);
    return critical
      ? l10n('systemHealth.statusBar.criticalOrphans', { count })
      : l10n('systemHealth.statusBar.warningOrphans', { count });
  }

  // Show saropa-owned RSS — this is what the thresholds compare against.
  const size = formatBytes(snapshot.saropaRssBytes);
  return critical
    ? l10n('systemHealth.statusBar.critical', { size })
    : l10n('systemHealth.statusBar.warning', { size });
}

/**
 * Snapshot subscribers receive the full assessment rather than a bare level:
 * re-deriving "was this memory or orphans?" at every call site would let the
 * status bar and the monitor drift apart on the next threshold change.
 */
export type SnapshotListener = (
  snapshot: DartProcessSnapshot,
  assessment: HealthAssessment,
) => void;

/** Trend direction for saropa-owned RSS over recent polls. */
export const enum RssTrend {
  /** Too few samples to determine a trend. */
  Unknown = 'unknown',
  /** RSS is growing across recent polls — possible leak. */
  Rising = 'rising',
  /** RSS is roughly stable. */
  Stable = 'stable',
  /** RSS is shrinking (e.g., cache eviction, process exit). */
  Falling = 'falling',
}

/** Number of recent saropa RSS samples used for trend direction. */
const TREND_WINDOW = 5;

/**
 * Number of recent saropa RSS samples kept for the tooltip sparkline.
 * 30 samples ≈ 30 minutes at the default 60-second poll interval.
 */
const SPARKLINE_WINDOW = 30;

/**
 * A 10% relative change threshold — smaller fluctuations are noise from
 * GC cycles and working-set jitter, not a meaningful trend.
 */
const TREND_THRESHOLD = 0.10;

/**
 * Pure trend computation: split the samples into an older and newer half,
 * compare their averages, and classify the direction. Exported for testing.
 */
export function computeRssTrend(samples: readonly number[]): RssTrend {
  if (samples.length < TREND_WINDOW) return RssTrend.Unknown;
  const mid = Math.floor(samples.length / 2);
  const oldAvg = samples.slice(0, mid).reduce((a, b) => a + b, 0) / mid;
  const newAvg = samples.slice(mid).reduce((a, b) => a + b, 0) / (samples.length - mid);
  if (oldAvg === 0) return RssTrend.Stable;
  const delta = (newAvg - oldAvg) / oldAvg;
  if (delta > TREND_THRESHOLD) return RssTrend.Rising;
  if (delta < -TREND_THRESHOLD) return RssTrend.Falling;
  return RssTrend.Stable;
}

export class ProcessMonitor implements vscode.Disposable {
  private timer: ReturnType<typeof setInterval> | undefined;
  private lastNotificationTime = 0;
  private disposed = false;
  private readonly listeners: SnapshotListener[] = [];
  private lastSnapshot: DartProcessSnapshot | undefined;
  /** Ring buffer of recent saropa RSS values for trend detection. */
  private readonly saropaRssHistory: number[] = [];
  /** Whether a leak-detection notification has already been shown this session. */
  private leakNotificationShown = false;

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

  /** Delegates to the pure computeRssTrend with the most recent samples. */
  getSaropaTrend(): RssTrend {
    // Only the last TREND_WINDOW samples drive the trend arrow — the full
    // buffer is longer (SPARKLINE_WINDOW) to feed the tooltip sparkline.
    return computeRssTrend(this.saropaRssHistory.slice(-TREND_WINDOW));
  }

  /** Returns a snapshot of the RSS history for sparkline rendering. */
  getRssHistory(): readonly number[] {
    // Defensive copy — callers must not mutate the ring buffer.
    return [...this.saropaRssHistory];
  }

  private async poll(): Promise<void> {
    if (this.disposed) return;
    try {
      const processes = await queryDartProcesses();
      const snapshot = await buildSnapshot(processes);
      this.lastSnapshot = snapshot;
      // Record saropa RSS for trend detection and sparkline (ring buffer).
      this.saropaRssHistory.push(snapshot.saropaRssBytes);
      if (this.saropaRssHistory.length > SPARKLINE_WINDOW) {
        this.saropaRssHistory.shift();
      }
      const config = readSystemHealthConfig();
      const assessment = assessHealth(snapshot, config);

      for (const fn of this.listeners) fn(snapshot, assessment);

      if (assessment.level === HealthLevel.Critical && config.showNotifications) {
        this.showCriticalNotification(snapshot);
      }
      // Leak detection: check for monotonic RSS growth even when the
      // absolute value is below the warning threshold. Fires once per
      // session — a persistent leak will eventually trip the threshold,
      // but the early nudge gives the user time to investigate.
      if (!this.leakNotificationShown && config.showNotifications) {
        if (detectMonotonicGrowth(this.saropaRssHistory)) {
          this.leakNotificationShown = true;
          this.showLeakNotification(snapshot);
        }
      }
    } catch {
      // Next poll will retry.
    }
  }

  private showCriticalNotification(snapshot: DartProcessSnapshot): void {
    const now = Date.now();
    if (now - this.lastNotificationTime < 5 * 60 * 1000) return;
    this.lastNotificationTime = now;

    // Show saropa-owned RSS in the notification — consistent with status bar.
    const size = formatBytes(snapshot.saropaRssBytes);
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

  /**
   * Nudge the user when saropa RSS has been rising steadily, even though
   * it hasn't hit the red/yellow threshold yet. Fires once per session.
   */
  private showLeakNotification(snapshot: DartProcessSnapshot): void {
    const size = formatBytes(snapshot.saropaRssBytes);
    const msg = l10n('systemHealth.notification.possibleLeak', { size });
    const openPanel = l10n('systemHealth.action.openPanel');
    const dismiss = l10n('systemHealth.action.dismiss');

    void vscode.window.showInformationMessage(msg, openPanel, dismiss).then((choice) => {
      if (choice === openPanel) {
        void vscode.commands.executeCommand('saropaLints.showHealthPanel');
      }
    });
  }

  dispose(): void {
    this.disposed = true;
    this.stop();
    this.listeners.length = 0;
  }
}
