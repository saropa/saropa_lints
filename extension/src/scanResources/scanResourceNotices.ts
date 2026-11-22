/**
 * Builds the notifications shown when a scan is slowing itself down, when the
 * machine is too tight for a heavy scan, or when a lighter scan finished and
 * a deeper one could follow.
 *
 * Every notice pairs a clear statement of what happened with the fixes the
 * user can apply in one click. This module is pure — it returns data
 * (`messageKey`, `params`, `actions`); `scanResourceUi.ts` renders and acts.
 * Keeping the decisions here makes them unit-testable and keeps wording and
 * action sets consistent across every entry point (baseline scan, daemon
 * start, mid-scan pressure).
 */
import type { MachinePressure, MachineSnapshot } from './machineResources';
import type { ScanSummary, ScanThrottleEvent } from './scanEvents';
import {
  canHostDeepScan,
  estimateDeepScan,
  type DeepScanEstimate,
  type PerformanceProfile,
} from './scanResourceSettings';

export type NoticeActionId =
  | 'gentleProfile'
  | 'openSettings'
  | 'runFast'
  | 'runDeep'
  | 'runDeepAnyway'
  | 'resume'
  | 'cancelScan'
  | 'turnOffTypeResolution'
  | 'startAnyway'
  | 'notNow'
  | 'neverAskDeep';

export interface NoticeAction {
  readonly id: NoticeActionId;
  /** l10n key for the button label. */
  readonly labelKey: string;
}

export interface Notice {
  readonly severity: 'info' | 'warning';
  /** l10n key for the message. */
  readonly messageKey: string;
  readonly params: Readonly<Record<string, string>>;
  readonly actions: readonly NoticeAction[];
}

const ACTION_LABEL: Readonly<Record<NoticeActionId, string>> = {
  gentleProfile: 'scanResources.action.gentleProfile',
  openSettings: 'scanResources.action.openSettings',
  runFast: 'scanResources.action.runFast',
  runDeep: 'scanResources.action.runDeep',
  runDeepAnyway: 'scanResources.action.runDeepAnyway',
  resume: 'scanResources.action.resume',
  cancelScan: 'scanResources.action.cancelScan',
  turnOffTypeResolution: 'scanResources.action.turnOffTypeResolution',
  startAnyway: 'scanResources.action.startAnyway',
  notNow: 'scanResources.action.notNow',
  neverAskDeep: 'scanResources.action.neverAskDeep',
};

function actions(...ids: NoticeActionId[]): NoticeAction[] {
  return ids.map((id) => ({ id, labelKey: ACTION_LABEL[id] }));
}

/** "3.9 GB" for >= 1 GB, otherwise "640 MB". */
export function formatMb(mb: number): string {
  if (mb >= 1024) return `${(mb / 1024).toFixed(1)} GB`;
  return `${Math.max(0, Math.round(mb))} MB`;
}

/**
 * The scan shed workers because the machine got tight. Offers the gentle
 * profile (unless already on it) and the settings page.
 */
export function throttledNotice(event: ScanThrottleEvent, profile: PerformanceProfile): Notice {
  return {
    severity: 'warning',
    messageKey: 'scanResources.throttled',
    params: { from: String(event.from), to: String(event.to), reason: event.reason },
    actions: profile === 'gentle' ? actions('openSettings') : actions('gentleProfile', 'openSettings'),
  };
}

/** The scan stopped early to protect the machine; results are partial. */
export function abortedNotice(reason: string, profile: PerformanceProfile): Notice {
  return {
    severity: 'warning',
    messageKey: 'scanResources.aborted',
    params: { reason },
    actions: profile === 'gentle' ? actions('openSettings') : actions('gentleProfile', 'openSettings'),
  };
}

/**
 * Before a deep (type-aware) baseline scan: null when there is room, else a
 * notice explaining why not, with the lighter alternative first.
 */
export function deepPreflightNotice(
  machine: MachineSnapshot,
  reserveMb: number,
  fileCount: number,
): Notice | null {
  if (canHostDeepScan(machine, reserveMb)) return null;
  const est: DeepScanEstimate = estimateDeepScan(fileCount);
  return {
    severity: 'warning',
    messageKey: 'scanResources.deepNotEnoughMemory',
    params: {
      needed: formatMb(est.memoryMb),
      free: formatMb(machine.freeMb),
      reserve: formatMb(reserveMb),
    },
    actions: actions('runFast', 'runDeepAnyway'),
  };
}

/** The deep scan is paused because free memory fell below the reserve. */
export function deepPausedNotice(pressure: MachinePressure): Notice {
  return {
    severity: 'warning',
    messageKey: 'scanResources.deepPaused',
    params: { free: formatMb(pressure.freeMb), reserve: formatMb(pressure.reserveMb) },
    actions: actions('resume', 'cancelScan', 'openSettings'),
  };
}

/**
 * The fast scan finished: report it, and offer the deep scan when the
 * machine can host it (with a time/memory estimate so the choice is
 * informed). When it cannot, say so instead of offering a button that would
 * hurt the machine.
 */
export function fastDoneNotice(
  summary: Pick<ScanSummary, 'filesScanned' | 'elapsedMs'>,
  issues: number,
  machine: MachineSnapshot,
  reserveMb: number,
  offerDeep: boolean,
): Notice {
  const params = {
    files: String(summary.filesScanned),
    issues: String(issues),
    seconds: (summary.elapsedMs / 1000).toFixed(1),
  };
  if (!offerDeep) {
    return { severity: 'info', messageKey: 'scanResources.fastDone', params, actions: [] };
  }
  if (!canHostDeepScan(machine, reserveMb)) {
    return {
      severity: 'info',
      messageKey: 'scanResources.fastDoneDeepUnavailable',
      params: { ...params, free: formatMb(machine.freeMb), needed: formatMb(estimateDeepScan(summary.filesScanned).memoryMb) },
      actions: [],
    };
  }
  const est = estimateDeepScan(summary.filesScanned);
  return {
    severity: 'info',
    messageKey: 'scanResources.fastDoneOfferDeep',
    params: { ...params, minutes: String(est.minutes), memory: formatMb(est.memoryMb) },
    actions: actions('runDeep', 'notNow', 'neverAskDeep'),
  };
}

/**
 * The deep daemon (several GB) would start on a machine that is already
 * tight. The daemon is skipped for now; the user can switch to lighter
 * scanning permanently or override once.
 */
export function daemonLowMemoryNotice(machine: MachineSnapshot, reserveMb: number): Notice {
  return {
    severity: 'warning',
    messageKey: 'scanResources.daemonLowMemory',
    params: {
      free: formatMb(machine.freeMb),
      needed: formatMb(estimateDeepScan(0).memoryMb),
      reserve: formatMb(reserveMb),
    },
    actions: actions('turnOffTypeResolution', 'startAnyway', 'openSettings'),
  };
}

/** True when a pressure level is bad enough to interrupt heavy work. */
export function isPressureCritical(pressure: MachinePressure): boolean {
  return pressure.level === 'critical';
}
