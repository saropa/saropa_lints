/**
 * VS Code side of live-analysis tuning: writes the recommendation into
 * `analysis_options_custom.yaml`, then offers the analysis-server restart
 * that applies it. Offers are shown at most once per workspace.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { readMachineSnapshot } from './machineResources';
import { formatMb } from './scanResourceNotices';
import {
  applyRecommendationToContent,
  shouldOfferSmallMachineTuning,
  type PluginMemoryRecommendation,
} from './pluginMemoryConfig';

const SMALL_MACHINE_OFFERED_KEY = 'saropaLints.scanResources.smallMachineOffered';

export type ApplyResult = 'written' | 'missing' | 'failed';

/** Writes [rec] into the project's custom config. Never throws. */
export async function applyPluginMemoryConfig(
  root: string,
  rec: PluginMemoryRecommendation,
): Promise<ApplyResult> {
  const uri = vscode.Uri.joinPath(vscode.Uri.file(root), 'analysis_options_custom.yaml');
  let content: string;
  try {
    content = Buffer.from(await vscode.workspace.fs.readFile(uri)).toString('utf8');
  } catch {
    return 'missing';
  }
  try {
    await vscode.workspace.fs.writeFile(
      uri,
      Buffer.from(applyRecommendationToContent(content, rec), 'utf8'),
    );
    return 'written';
  } catch {
    return 'failed';
  }
}

/**
 * Asks whether to apply [rec] to live analysis; on yes, writes it and offers
 * the restart that makes it take effect. [messageKey] picks the wording
 * (after choosing the gentle profile vs. proactive small-machine offer).
 */
export async function offerPluginTuning(
  root: string,
  rec: PluginMemoryRecommendation,
  messageKey: 'scanResources.plugin.offerAfterProfile' | 'scanResources.plugin.offerSmallMachine',
  params: Record<string, string> = {},
): Promise<void> {
  const apply = l10n('scanResources.action.applyPlugin');
  const noThanks = l10n('scanResources.action.noThanks');
  const choice = await vscode.window.showInformationMessage(
    l10n(messageKey, { limit: formatMb(rec.maxRssMb), ...params }),
    apply,
    noThanks,
  );
  if (choice !== apply) return;
  const result = await applyPluginMemoryConfig(root, rec);
  if (result === 'missing') {
    void vscode.window.showInformationMessage(l10n('memoryPressure.notification.runInit'));
    return;
  }
  if (result === 'failed') {
    void vscode.window.showWarningMessage(l10n('scanResources.plugin.writeFailed'));
    return;
  }
  const restart = l10n('scanResources.action.restartAnalysisServer');
  const next = await vscode.window.showInformationMessage(
    l10n('scanResources.plugin.applied', { limit: formatMb(rec.maxRssMb) }),
    restart,
  );
  if (next === restart) {
    await vscode.commands.executeCommand('dart.restartAnalysisServer');
  }
}

/**
 * Proactive, once-per-workspace offer on small machines whose config sets
 * neither limit. Silent on any problem: this is a courtesy, never a blocker.
 */
export async function maybeOfferSmallMachineTuning(
  state: vscode.Memento,
  root: string | undefined,
): Promise<void> {
  try {
    if (!root || state.get<boolean>(SMALL_MACHINE_OFFERED_KEY, false)) return;
    const uri = vscode.Uri.joinPath(vscode.Uri.file(root), 'analysis_options_custom.yaml');
    let content: string;
    try {
      content = Buffer.from(await vscode.workspace.fs.readFile(uri)).toString('utf8');
    } catch {
      return; // not initialised for Saropa Lints yet — nothing to tune
    }
    const machine = readMachineSnapshot();
    const rec = shouldOfferSmallMachineTuning(machine, content);
    if (!rec) return;
    await state.update(SMALL_MACHINE_OFFERED_KEY, true);
    await offerPluginTuning(root, rec, 'scanResources.plugin.offerSmallMachine', {
      total: formatMb(machine.totalMb),
    });
  } catch {
    // Courtesy only.
  }
}
