/**
 * Activation preflight for orphaned model-host processes, plus the user-facing
 * reclaim command.
 *
 * This is a PREFLIGHT, not a poll. {@link ProcessMonitor} already polls for
 * live memory pressure; running a second timer over the whole process table
 * would cost CPU forever to answer a question that only changes when a
 * previous session dies. The leak this guards against accumulates across
 * sessions, so checking once as the session starts is exactly the right
 * cadence — the 2026-09-05 incident went unnoticed for two days precisely
 * because nothing looked at startup.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { formatBytes } from './processQuery';
import {
  killProcessTree,
  scanOrphanedHosts,
  totalCommittedBytes,
  type HostProcessInfo,
  type OrphanHostScan,
} from './orphanHosts';
import { reclaimOrphans, type ReclaimOutcome } from './orphanReclaim';

/**
 * Delay before the preflight runs, in milliseconds.
 *
 * Enumerating every process on the machine shells out to PowerShell and costs
 * roughly a second of CPU. Doing that during `activate()` would charge every
 * user that second of startup latency for a check that is not urgent — the
 * orphans have already been there for hours. Deferring puts it fully off the
 * activation critical path.
 */
const PREFLIGHT_DELAY_MS = 15_000;

/** Command id; also declared in package.json and the command catalog registry. */
export const CHECK_ORPHANS_COMMAND = 'saropaLints.checkOrphanedProcesses';

/** Render one orphan as a line the user can recognize in the confirmation modal. */
function describeOrphan(p: HostProcessInfo): string {
  return l10n('systemHealth.orphanPreflight.listEntry', {
    name: p.name,
    pid: String(p.processId),
    size: formatBytes(p.committedBytes),
  });
}

/**
 * Modal confirmation that NAMES every process it is about to end.
 *
 * Modal (rather than a toast with buttons) because the action cannot be undone
 * and a toast can be dismissed by accident. The detail block lists image name,
 * PID and commit charge per process so the user can cross-check against Task
 * Manager before consenting.
 */
async function confirmReclaim(orphans: readonly HostProcessInfo[]): Promise<boolean> {
  const params = {
    count: String(orphans.length),
    size: formatBytes(totalCommittedBytes(orphans)),
  };
  const confirmLabel = l10n('systemHealth.orphanPreflight.confirmKill');
  const choice = await vscode.window.showWarningMessage(
    l10n('systemHealth.orphanPreflight.confirmTitle', params),
    {
      modal: true,
      detail: `${l10n('systemHealth.orphanPreflight.confirmDetail')}\n${orphans
        .map(describeOrphan)
        .join('\n')}`,
    },
    confirmLabel,
  );
  return choice === confirmLabel;
}

/** Report what the reclaim actually achieved; silence would leave the user guessing. */
function reportOutcome(outcome: ReclaimOutcome): void {
  if (!outcome.confirmed) return;
  if (outcome.killed > 0) {
    void vscode.window.showInformationMessage(
      l10n('systemHealth.orphanPreflight.reclaimed', {
        count: String(outcome.killed),
        size: formatBytes(outcome.reclaimedBytes),
      }),
    );
  }
  if (outcome.failed > 0) {
    void vscode.window.showWarningMessage(
      l10n('systemHealth.orphanPreflight.reclaimFailed', {
        count: String(outcome.failed),
      }),
    );
  }
}

/**
 * Re-scan and offer to reclaim. Always re-queries instead of trusting a
 * snapshot: a PID from a scan seconds ago may already have been recycled by
 * the OS onto an unrelated process, and killing that would be catastrophic.
 */
export async function runOrphanReclaim(): Promise<void> {
  const scan = await scanOrphanedHosts();
  if (scan.orphans.length === 0) {
    void vscode.window.showInformationMessage(
      l10n('systemHealth.orphanPreflight.none'),
    );
    return;
  }
  const outcome = await reclaimOrphans(scan.orphans, {
    confirm: confirmReclaim,
    kill: killProcessTree,
  });
  reportOutcome(outcome);
}

/**
 * Notify that orphans exist and offer the reclaim path.
 *
 * The total commit charge is in the message body because that is the number
 * the user judges on: three processes is unremarkable, 37 GB is not.
 */
function offerReclaim(scan: OrphanHostScan): void {
  const message = l10n('systemHealth.orphanPreflight.found', {
    count: String(scan.orphans.length),
    size: formatBytes(scan.totalCommittedBytes),
  });
  const reclaim = l10n('systemHealth.orphanPreflight.reclaimAction');
  const details = l10n('systemHealth.orphanPreflight.detailsAction');
  void vscode.window
    .showWarningMessage(message, reclaim, details)
    .then((choice) => {
      if (choice === reclaim) {
        void vscode.commands.executeCommand(CHECK_ORPHANS_COMMAND);
      } else if (choice === details) {
        // Leads somewhere rather than dead-ending: the Health Panel shows the
        // same orphan banner alongside the rest of the process picture.
        void vscode.commands.executeCommand('saropaLints.showProcessHealth');
      }
    });
}

/** The one-shot check itself. Stays silent when clean — a clean machine is the norm. */
async function runPreflight(): Promise<void> {
  try {
    const scan = await scanOrphanedHosts();
    if (scan.orphans.length === 0) return;
    offerReclaim(scan);
  } catch {
    // A failed process enumeration is not worth interrupting the user over;
    // the manual command is always available if they suspect a leak.
  }
}

/**
 * Register the command and schedule the deferred one-shot preflight.
 *
 * The timer is disposed with the extension so a window closed inside the delay
 * window does not fire a notification into a disposed host.
 */
export function registerOrphanPreflight(context: vscode.ExtensionContext): void {
  context.subscriptions.push(
    vscode.commands.registerCommand(CHECK_ORPHANS_COMMAND, () => runOrphanReclaim()),
  );

  // Windows-only: the whole detection path is Win32_Process based, matching
  // the rest of systemHealth.
  if (process.platform !== 'win32') return;

  const timer = setTimeout(() => void runPreflight(), PREFLIGHT_DELAY_MS);
  context.subscriptions.push({ dispose: () => clearTimeout(timer) });
}
