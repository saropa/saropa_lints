import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import type { DartProcessSnapshot, ExtensionHostMemory, HealthAssessment } from './types';
import { HealthLevel, HealthTrigger } from './types';
import {
  buildSnapshot,
  detectMonotonicGrowth,
  formatBytes,
  isAnalysisServerProcess,
  queryDartProcesses,
} from './processQuery';
import { querySystemMemory, type SystemMemorySnapshot } from './systemQuery';

const BYTES_PER_GB = 1_073_741_824;

export interface SystemHealthConfig {
  enabled: boolean;
  pollIntervalSeconds: number;
  warningThresholdGB: number;
  criticalThresholdGB: number;
  warningOrphanCount: number;
  criticalOrphanCount: number;
  showNotifications: boolean;
  /** GB threshold for a single Dart analysis-server process, independent of saropa's own thresholds above. */
  analysisServerWarningGB: number;
  /** Percent of free system-wide RAM below which the whole-machine warning fires. */
  systemMemoryWarningPercent: number;
  /** GB threshold for extension host RSS — fires a status bar warning when exceeded. */
  extensionHostWarningGB: number;
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
    analysisServerWarningGB: cfg.get<number>('analysisServerWarningGB', 4),
    systemMemoryWarningPercent: cfg.get<number>('systemMemoryWarningPercent', 15),
    extensionHostWarningGB: cfg.get<number>('extensionHostWarningGB', 1),
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
  /** Ring buffer of extension host RSS for trend detection (parallels saropaRssHistory). */
  private readonly hostRssHistory: number[] = [];
  /** Last sampled extension host memory, exposed for status bar / tooltip. */
  private lastHostMemory: ExtensionHostMemory | undefined;
  /** Whether a leak-detection notification has already been shown this session. */
  private leakNotificationShown = false;
  // Separate throttle timestamps from lastNotificationTime (the saropa-RSS
  // critical notification) — these two checks are about the *machine* and
  // *any* analysis server, not saropa's own memory, and firing all three
  // notifications off one shared timestamp would let an unrelated saropa
  // alert suppress a genuinely new system-wide warning for 5 minutes.
  // Two-tier throttle: query at 2 min (catch rapid degradation without
  // shelling out every 60s poll), notify at 10 min (don't nag).
  private lastSystemMemoryQueryTime = 0;
  private lastSystemMemoryNotificationTime = 0;
  private lastAnalysisServerNotificationTime = 0;
  /** Last known system memory state, exposed for status bar integration.
   *  Updated on every checkSystemMemory query (every ~2 min). */
  private lastSystemMemory: SystemMemorySnapshot | undefined;

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

  /** Last known system-wide memory state, for status bar / tooltip use. */
  getLastSystemMemory(): SystemMemorySnapshot | undefined {
    return this.lastSystemMemory;
  }

  /** Last sampled extension host process memory, for status bar / tooltip use. */
  getLastHostMemory(): ExtensionHostMemory | undefined {
    return this.lastHostMemory;
  }

  /** Returns a snapshot of the extension host RSS history for trend detection. */
  getHostRssHistory(): readonly number[] {
    return [...this.hostRssHistory];
  }

  /** Trend direction for extension host RSS over recent polls. */
  getHostTrend(): RssTrend {
    return computeRssTrend(this.hostRssHistory.slice(-TREND_WINDOW));
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
      // Sample the extension host's own memory — this is the Node.js process
      // running this extension, which was invisible to the WMI-based Dart
      // monitor during the 2026-09-05 crash.
      this.sampleHostMemory();
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

      // Two checks below are deliberately independent of `assessment` above:
      // that assessment only ever looks at saropa-owned RSS (by design — see
      // its own doc comment), so a machine-wide low-memory condition or an
      // oversized *external* analysis server would otherwise never surface
      // anywhere, even though both are exactly the conditions that preceded
      // the 2026-09-05 incident this whole subsystem exists to catch early.
      if (config.showNotifications) {
        await this.checkSystemMemory(config);
        this.checkAnalysisServerSize(snapshot, config);
      }
    } catch {
      // Next poll will retry.
    }
  }

  /**
   * Sample the Node.js extension host process memory via `process.memoryUsage()`.
   * Cheap (no shell-out, no WMI) and always available — unlike the Dart process
   * query, this never fails on non-Windows platforms.
   */
  private sampleHostMemory(): void {
    const mem = process.memoryUsage();
    this.lastHostMemory = {
      rssBytes: mem.rss,
      heapUsedBytes: mem.heapUsed,
      heapTotalBytes: mem.heapTotal,
      externalBytes: mem.external,
      arrayBuffersBytes: mem.arrayBuffers,
      timestamp: Date.now(),
    };
    // Track RSS in a ring buffer parallel to the saropa one.
    this.hostRssHistory.push(mem.rss);
    if (this.hostRssHistory.length > SPARKLINE_WINDOW) {
      this.hostRssHistory.shift();
    }
  }

  /**
   * Warn when free physical RAM across the whole machine drops below the
   * configured percentage — independent of which process is responsible.
   * Piggybacks on this class's existing poll timer rather than running its
   * own interval, since the two checks share the same "don't spam" needs and
   * a second timer would double the PowerShell shell-out cadence for no benefit.
   */
  private async checkSystemMemory(config: SystemHealthConfig): Promise<void> {
    const now = Date.now();
    // 2-minute query throttle — avoids shelling out every 60s poll on a
    // healthy machine, but still catches a machine going from healthy to
    // critical within a few minutes (10 min would miss rapid degradation).
    if (now - this.lastSystemMemoryQueryTime < 2 * 60 * 1000) return;
    this.lastSystemMemoryQueryTime = now;
    const system = await querySystemMemory();
    // Store for status bar / tooltip consumers regardless of threshold.
    this.lastSystemMemory = system;
    if (!system) return;
    const freePercent = system.freeFraction * 100;
    if (freePercent >= config.systemMemoryWarningPercent) return;
    // 10-minute notification throttle — don't nag; the user needs time to
    // act (close tabs, kill a process) before a repeat nudge is useful.
    if (now - this.lastSystemMemoryNotificationTime < 10 * 60 * 1000) return;
    this.lastSystemMemoryNotificationTime = now;

    const msg = l10n('systemHealth.notification.systemLowMemory', {
      free: formatBytes(system.freeBytes),
      total: formatBytes(system.totalBytes),
    });
    const openDashboard = l10n('systemHealth.action.openMachineDashboard');
    void vscode.window.showWarningMessage(msg, openDashboard).then((choice) => {
      if (choice === openDashboard) {
        void vscode.commands.executeCommand('saropaLints.showMachineDashboard');
      }
    });
  }

  /**
   * Warn when ANY Dart analysis-server process (not just saropa's own,
   * which `assessHealth` already covers) exceeds the configured GB. A 12 GB
   * analysis server from another window is deliberately excluded from the
   * saropa-colored status bar (see `assessHealth`'s doc comment) — this
   * notification is the place that condition is still surfaced at all.
   */
  private checkAnalysisServerSize(snapshot: DartProcessSnapshot, config: SystemHealthConfig): void {
    const now = Date.now();
    if (now - this.lastAnalysisServerNotificationTime < 10 * 60 * 1000) return;
    const warningBytes = config.analysisServerWarningGB * BYTES_PER_GB;
    const oversized = snapshot.processes.filter(
      (p) => isAnalysisServerProcess(p) && p.workingSetSize >= warningBytes,
    );
    if (oversized.length === 0) return;
    this.lastAnalysisServerNotificationTime = now;

    const largest = Math.max(...oversized.map((p) => p.workingSetSize));
    const msg = l10n('systemHealth.notification.analysisServerLarge', { size: formatBytes(largest) });
    const restart = l10n('systemHealth.action.restartAnalysisServer');
    void vscode.window.showWarningMessage(msg, restart).then((choice) => {
      if (choice === restart) {
        void vscode.commands.executeCommand('dart.restartAnalysisServer');
      }
    });
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
        // Must match the registered command in extension.ts — saropaLints.showHealthPanel
        // was never registered, causing the button to silently no-op.
        void vscode.commands.executeCommand('saropaLints.showProcessHealth');
      }
    });
  }

  dispose(): void {
    this.disposed = true;
    this.stop();
    this.listeners.length = 0;
  }
}
