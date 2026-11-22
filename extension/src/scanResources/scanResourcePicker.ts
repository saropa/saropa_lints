/**
 * "Saropa Lints: Scan Performance…" — shows what this machine looks like,
 * what each performance profile would do on it (worker count and memory
 * budget), marks the recommended one, and applies the user's choice.
 *
 * The recommendation logic is pure ({@link recommendProfile},
 * {@link buildProfileChoices}) and unit-tested; only the QuickPick wiring
 * touches VS Code.
 */
import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import {
  classifyMachinePressure,
  readMachineSnapshot,
  type MachineSnapshot,
} from './machineResources';
import { readScanResourceSettings } from './scanResourceConfig';
import { formatMb } from './scanResourceNotices';
import {
  resolveScanResources,
  type PerformanceProfile,
  type ResolvedScanResources,
  type ScanResourceSettings,
} from './scanResourceSettings';

/**
 * Recommends a profile for a machine: small or busy machines get `gentle`,
 * everything else `balanced`. `fast` is never auto-recommended — it trades
 * desktop responsiveness for speed, which should be the user's call.
 */
export function recommendProfile(machine: MachineSnapshot): PerformanceProfile {
  const pressure = classifyMachinePressure(machine);
  if (machine.cores <= 4) return 'gentle';
  if (machine.totalMb < 8 * 1024) return 'gentle';
  if (pressure.level !== 'ok') return 'gentle';
  return 'balanced';
}

export interface ProfileChoice {
  readonly profile: PerformanceProfile;
  readonly resources: ResolvedScanResources;
  readonly recommended: boolean;
}

/** Resolves every profile against the machine for a project of [fileCount] files. */
export function buildProfileChoices(
  settings: ScanResourceSettings,
  machine: MachineSnapshot,
  fileCount: number,
): ProfileChoice[] {
  const recommended = recommendProfile(machine);
  return (['gentle', 'balanced', 'fast'] as const).map((profile) => ({
    profile,
    // Resolve with the profile's own shape; ignore manual overrides so the
    // choices show what each profile alone would do.
    resources: resolveScanResources(
      { ...settings, profile, maxWorkers: 0, maxMemoryMb: 0 },
      machine,
      fileCount,
    ),
    recommended: profile === recommended,
  }));
}

/** Literal l10n keys (not templated) so the key audit can see they are used. */
function profileLabel(profile: PerformanceProfile): string {
  switch (profile) {
    case 'gentle':
      return l10n('scanResources.picker.profile.gentle');
    case 'balanced':
      return l10n('scanResources.picker.profile.balanced');
    case 'fast':
      return l10n('scanResources.picker.profile.fast');
  }
}

function profileDetail(profile: PerformanceProfile): string {
  switch (profile) {
    case 'gentle':
      return l10n('scanResources.picker.profileDetail.gentle');
    case 'balanced':
      return l10n('scanResources.picker.profileDetail.balanced');
    case 'fast':
      return l10n('scanResources.picker.profileDetail.fast');
  }
}

/** Opens the picker and applies the selection (or opens the settings page). */
export async function showScanPerformancePicker(fileCount: number): Promise<void> {
  const settings = readScanResourceSettings();
  const machine = readMachineSnapshot();
  const choices = buildProfileChoices(settings, machine, fileCount);

  const machineLine = l10n('scanResources.picker.machine', {
    cores: String(machine.cores),
    free: formatMb(machine.freeMb),
    total: formatMb(machine.totalMb),
  });

  interface Item extends vscode.QuickPickItem {
    profile?: PerformanceProfile;
    openSettings?: boolean;
  }
  const items: Item[] = choices.map((c) => ({
    label: `${c.profile === settings.profile ? '$(check) ' : ''}${profileLabel(c.profile)}${
      c.recommended ? ` — ${l10n('scanResources.picker.recommended')}` : ''
    }`,
    description: l10n('scanResources.picker.resources', {
      jobs: String(c.resources.jobs),
      memory: formatMb(c.resources.maxMemoryMb),
    }),
    detail: profileDetail(c.profile),
    profile: c.profile,
  }));
  items.push({
    label: `$(gear) ${l10n('scanResources.picker.openSettings')}`,
    openSettings: true,
  });

  const picked = await vscode.window.showQuickPick(items, {
    title: l10n('scanResources.picker.title'),
    placeHolder: machineLine,
    matchOnDetail: true,
  });
  if (!picked) return;
  if (picked.openSettings) {
    await vscode.commands.executeCommand('workbench.action.openSettings', 'saropaLints.scan');
    return;
  }
  if (picked.profile) {
    await vscode.workspace
      .getConfiguration('saropaLints')
      .update('scan.performanceProfile', picked.profile, vscode.ConfigurationTarget.Global);
  }
}
