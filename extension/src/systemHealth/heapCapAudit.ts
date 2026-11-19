/**
 * One-shot audit of the Dart analysis server's VM heap cap.
 *
 * Dart-Code launches the analysis server with whatever VM flags are in
 * `dart.analyzerVmAdditionalArgs`; `--old_gen_heap_size=<MB>` is the one
 * lever that caps its worst-case memory growth (see `HEAP_CAP_FLAG` in
 * `processQuery.ts`). Two failure modes go unnoticed without this check:
 * no cap at all (the server can grow until the machine swaps), or a cap
 * left over from a bigger machine that now exceeds half the RAM of the
 * one it's actually running on — the 2026-09 incident was an 8 GB Mac
 * with a workspace-level 6144 MB cap plus a ~3 GB scan daemon, both
 * running unaware of the other.
 *
 * This module checks once per activation (deferred well past startup, and
 * only for Dart projects), computes the recommended cap for this
 * machine's RAM, and offers to apply it in one click. Follows the same
 * shape as `watcherExcludeAudit.ts`: a pure computation this file wraps
 * with the `vscode` notification/config-write glue, gated by stored state
 * so it never nags once dismissed for the current situation.
 */
import * as os from 'node:os';
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import {
  assessHeapCap,
  parseHeapCapMb,
  pickWriteTarget,
  recommendHeapCapMb,
  withHeapCap,
  writeTargetToConfigurationTargetValue,
  type HeapCapInspectResult,
  type HeapCapWriteTarget,
} from './heapCap';

const BYTES_PER_GB = 1_073_741_824;

/**
 * GlobalState key holding the "situation" (recommended MB + current cap)
 * the user last dismissed with "Don't ask again". Comparing against the
 * *current* situation on each run means a materially different machine
 * (different RAM) or a changed cap re-arms the prompt automatically,
 * without needing a separate "reset" action.
 */
const DISMISSED_KEY = 'heapCapAudit.dismissedSituation';

/** Format bytes as a whole-or-half GB string, e.g. "8 GB" or "2.5 GB". */
function formatGb(bytes: number): string {
  const gb = bytes / BYTES_PER_GB;
  const rounded = Math.round(gb * 10) / 10;
  return `${Number.isInteger(rounded) ? rounded : rounded.toFixed(1)} GB`;
}

/** Encode the current cap situation as a string for the dismissal-state comparison. */
function situationKey(recommendedMb: number, capMb: number | undefined): string {
  return `${recommendedMb}:${capMb ?? 'none'}`;
}

/** Human-readable name for where the current (too-high) cap is set, for the notification text. */
function locationLabel(target: HeapCapWriteTarget): string {
  switch (target) {
    case 'workspaceFolder':
      return l10n('systemHealth.heapCap.locationWorkspaceFolder');
    case 'workspace':
      return l10n('systemHealth.heapCap.locationWorkspace');
    default:
      return l10n('systemHealth.heapCap.locationGlobal');
  }
}

/** Local mirror of `vscode.WorkspaceConfiguration.inspect()`'s shape, narrowed to what {@link pickWriteTarget} needs. */
function toInspectResult(
  inspected: ReturnType<vscode.WorkspaceConfiguration['inspect']> | undefined,
): HeapCapInspectResult | undefined {
  if (!inspected) return undefined;
  return {
    globalValue: inspected.globalValue as string[] | undefined,
    workspaceValue: inspected.workspaceValue as string[] | undefined,
    workspaceFolderValue: inspected.workspaceFolderValue as string[] | undefined,
  };
}

/**
 * Run the heap-cap audit and show a notification if the current situation
 * is 'none' or 'tooHigh'. Called once per session from `activate()` via a
 * deferred `setTimeout`, only when a Dart project is open.
 */
export async function auditHeapCap(context: vscode.ExtensionContext): Promise<void> {
  const totalBytes = os.totalmem();
  const config = vscode.workspace.getConfiguration('dart');
  const inspected = config.inspect<string[]>('analyzerVmAdditionalArgs');
  const currentArgs = config.get<string[]>('analyzerVmAdditionalArgs', []);
  const capMb = parseHeapCapMb(currentArgs);
  const assessment = assessHeapCap({ capMb, totalBytes });

  // Nothing to recommend — a cap is set and leaves enough headroom.
  if (assessment === 'ok') return;

  const recommendedMb = recommendHeapCapMb(totalBytes);
  const situation = situationKey(recommendedMb, capMb);

  // Respect a previous "Don't ask again" for this exact situation. Guard:
  // corrupted globalState after a crash can throw on get; treat that as
  // "not dismissed" so the audit still fires, matching watcherExcludeAudit.
  try {
    if (context.globalState.get<string>(DISMISSED_KEY) === situation) {
      return;
    }
  } catch {
    // globalState corrupted — fall through and run the audit.
  }

  const target = pickWriteTarget(toInspectResult(inspected));
  const recommendedGb = formatGb(recommendedMb * 1024 * 1024);
  const totalGb = formatGb(totalBytes);

  const message =
    assessment === 'none'
      ? l10n('systemHealth.heapCap.noneMessage', {
          totalGb,
          recommendedGb,
        })
      : l10n('systemHealth.heapCap.tooHighMessage', {
          totalGb,
          capGb: formatGb((capMb ?? 0) * 1024 * 1024),
          location: locationLabel(target),
          freeGb: formatGb(totalBytes - (capMb ?? 0) * 1024 * 1024),
          recommendedGb,
        });

  const applyLabel = l10n('systemHealth.heapCap.apply', { gb: recommendedGb });
  const notNowLabel = l10n('systemHealth.heapCap.notNow');
  const dontAskLabel = l10n('systemHealth.heapCap.dontAskAgain');

  const choice = await vscode.window.showWarningMessage(
    message,
    applyLabel,
    notNowLabel,
    dontAskLabel,
  );

  if (choice === applyLabel) {
    const updated = withHeapCap(currentArgs, recommendedMb);
    await config.update(
      'analyzerVmAdditionalArgs',
      updated,
      writeTargetToConfigurationTargetValue(target) as vscode.ConfigurationTarget,
    );

    const restartLabel = l10n('machineDashboard.heapCap.restartNow');
    const restartChoice = await vscode.window.showInformationMessage(
      l10n('machineDashboard.heapCap.applied', { mb: String(recommendedMb) }),
      restartLabel,
    );
    if (restartChoice === restartLabel) {
      // dart.restartAnalysisServer is Dart-Code's own command — a VM flag
      // change only takes effect on the next server process.
      void vscode.commands.executeCommand('dart.restartAnalysisServer');
    }
  } else if (choice === dontAskLabel) {
    try {
      await context.globalState.update(DISMISSED_KEY, situation);
    } catch {
      // Best-effort — worst case the prompt reappears next session.
    }
  }
  // "Not now" (or closing the toast) stores nothing, so the audit re-runs
  // next session as long as the situation persists.
}
