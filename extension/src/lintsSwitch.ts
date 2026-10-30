/**
 * The single Saropa Lints on/off switch.
 *
 * Two independent facts decide whether lints really run:
 *   - the `saropaLints.enabled` setting (scan-on-save delivery), and
 *   - the live `plugins: saropa_lints:` block in analysis_options.yaml (the
 *     in-process analyzer plugin).
 * "On" means the setting is on AND the plugin block is live OR was never turned
 * off by the extension: a new project's default sentinel-wrapped block is
 * deliberate daemon-only delivery (the in-process plugin costs several GB), so
 * with no ownership record it counts as On and turning On must not load it.
 * "Partly off" shows only when the extension itself turned the block off
 * (ownership record present) or the setting and block otherwise disagree.
 * "Off" means both are off. Pure state logic is exported separately so it is
 * unit-testable.
 */

import * as vscode from 'vscode';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { getProjectRoot } from './projectRoot';
import {
  getPluginsIntegrationState,
  readPluginOwnershipFile,
  wasPluginDisabledByExtension,
  runDisable,
  runReenablePlugin,
  type PluginsIntegrationState,
} from './setup';
import { findPluginEntry, splitScalar } from './analysisOptionsVersion';
import { readInstalledVersion } from './upgrade-checker';
import { l10n } from './i18n/runtime';

export type LintsSwitchState =
  | { kind: 'on' }
  | { kind: 'off' }
  | { kind: 'partial'; off: 'setting' | 'plugin' };

/**
 * Combine the setting, the plugins block and the ownership record into one
 * state. A sentinel-disabled block the extension did not turn off (default
 * daemon-only) counts as plugin on; a missing block counts as plugin off.
 */
export function computeLintsSwitchState(
  enabledSetting: boolean,
  block: PluginsIntegrationState,
  disabledByExtension = false,
): LintsSwitchState {
  const pluginOn = block === 'live' || (block === 'disabled' && !disabledByExtension);
  if (enabledSetting && pluginOn) return { kind: 'on' };
  if (!enabledSetting && !pluginOn) return { kind: 'off' };
  // Setting off with a default (daemon-only) block is the plain Off case.
  if (!enabledSetting && block === 'disabled') return { kind: 'off' };
  return { kind: 'partial', off: enabledSetting ? 'plugin' : 'setting' };
}

/** Context saved at activation so display paths see the workspace ownership record too. */
let switchContext: vscode.ExtensionContext | undefined;

export function initLintsSwitch(ctx: vscode.ExtensionContext | undefined): void {
  switchContext = ctx;
}

/** Reports whether the scan daemon is suspended (debug-panel toggle); a suspended daemon counts as the setting being off. */
let scanSuspendedProvider: (() => boolean) | undefined;

export function setScanSuspendedProvider(fn: (() => boolean) | undefined): void {
  scanSuspendedProvider = fn;
}

/** Read the live state for a project root (context adds the workspace memento to the ownership check). */
export function getLintsSwitchState(root: string, context?: vscode.ExtensionContext): LintsSwitchState {
  const ctx = context ?? switchContext;
  const enabled = (vscode.workspace.getConfiguration('saropaLints').get<boolean>('enabled', true) ?? true)
    && !scanSuspendedProvider?.();
  const owned = ctx ? wasPluginDisabledByExtension(ctx, root) : readPluginOwnershipFile(root);
  return computeLintsSwitchState(enabled, getPluginsIntegrationState(root), owned);
}

/** Short label ("Saropa Lints: Partly off") for the status bar and sidebar. */
export function lintsSwitchLabel(state: LintsSwitchState): string {
  if (state.kind === 'on') return l10n('lintsSwitch.statusOn');
  if (state.kind === 'off') return l10n('lintsSwitch.statusOff');
  return l10n('lintsSwitch.statusPartial');
}

/** Tooltip / description that says in words what is off and what a click does. */
export function lintsSwitchDetail(state: LintsSwitchState): string {
  if (state.kind === 'on') return l10n('lintsSwitch.tooltipOn');
  if (state.kind === 'off') return l10n('lintsSwitch.tooltipOff');
  return state.off === 'setting'
    ? l10n('lintsSwitch.tooltipPartialSetting')
    : l10n('lintsSwitch.tooltipPartialPlugin');
}

/** Dashboard message for a non-On state (the "Lints are off" / partly-off sentence). */
export function lintsSwitchDashboardMessage(state: LintsSwitchState): string {
  if (state.kind === 'off') return l10n('lintsSwitch.dashboardOff');
  if (state.kind === 'partial') {
    return state.off === 'setting'
      ? l10n('lintsSwitch.dashboardPartialSetting')
      : l10n('lintsSwitch.dashboardPartialPlugin');
  }
  return '';
}

// ── Version drift ────────────────────────────────────────────────────────

export interface PluginVersionDrift {
  configured: string;
  pinned: string;
}

/**
 * The exact `version:` under the live plugins block when it differs from the
 * version resolved in pubspec.lock; null when they match, when the value is a
 * range, or when either side is unreadable.
 */
export function detectPluginVersionDrift(root: string): PluginVersionDrift | null {
  try {
    const optionsPath = path.join(root, 'analysis_options.yaml');
    const lockPath = path.join(root, 'pubspec.lock');
    if (!fs.existsSync(optionsPath) || !fs.existsSync(lockPath)) return null;
    const lines = fs.readFileSync(optionsPath, 'utf-8').split(/\r?\n/);
    const entry = findPluginEntry(lines);
    if (!entry || entry.valueLine < 0) return null;
    const parts = splitScalar(lines[entry.valueLine], entry.valueKey);
    const pinned = readInstalledVersion(fs.readFileSync(lockPath, 'utf-8'))?.version;
    if (!parts || !parts.value || !pinned) return null;
    if (!/^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.+-]+)?$/.test(parts.value)) return null;
    return parts.value === pinned ? null : { configured: parts.value, pinned };
  } catch {
    return null;
  }
}

/** Rewrite the `version:` value to the pinned one, keeping quotes, comments and line endings. */
export function syncPluginVersionToPinned(root: string): PluginVersionDrift | null {
  const drift = detectPluginVersionDrift(root);
  if (!drift) return null;
  const file = path.join(root, 'analysis_options.yaml');
  const content = fs.readFileSync(file, 'utf-8');
  // Split keeping terminators so CRLF and LF lines survive unchanged.
  const chunks = content.split(/(\r?\n)/);
  const lines = chunks.filter((_, i) => i % 2 === 0);
  const entry = findPluginEntry(lines);
  if (!entry || entry.valueLine < 0) return null;
  const parts = splitScalar(lines[entry.valueLine], entry.valueKey);
  if (!parts) return null;
  chunks[entry.valueLine * 2] = `${parts.prefix}${parts.quote}${drift.pinned}${parts.quote}${parts.suffix}`;
  fs.writeFileSync(file, chunks.join(''), 'utf-8');
  return drift;
}

// ── Actions ──────────────────────────────────────────────────────────────

/**
 * Turn everything on: the setting, the plugins block, and (when drifted) the
 * version line. If there is no block to restore (integration never set up),
 * hand over to the normal enable flow instead of pretending it worked.
 */
export async function turnLintsOn(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    await runReenablePlugin(context); // reports the no-workspace error
    return;
  }
  const block = getPluginsIntegrationState(root);
  if (block === 'disabled' && !wasPluginDisabledByExtension(context, root)) {
    // Default daemon-only block: only the setting is on the switch. Do not
    // restore the block, which would load the heavy in-process plugin.
    await vscode.workspace.getConfiguration('saropaLints').update('enabled', true, vscode.ConfigurationTarget.Workspace);
  } else {
    await runReenablePlugin(context);
    if (getPluginsIntegrationState(root) !== 'live') {
      await vscode.commands.executeCommand('saropaLints.enable');
    }
  }
  await syncVersionWithMessage(root);
}

/** Sync the version line and tell the user; no-op without drift. */
export async function syncVersionWithMessage(root: string): Promise<boolean> {
  const synced = syncPluginVersionToPinned(root);
  if (!synced) return false;
  void vscode.window.showInformationMessage(l10n('lintsSwitch.driftSynced', { pinned: synced.pinned }));
  return true;
}

/** One click: On turns everything off; Off or Partly off (the Fix) turns everything on. */
export async function toggleLints(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) {
    await runReenablePlugin(context); // reports the no-workspace error
    return;
  }
  if (getLintsSwitchState(root, context).kind === 'on') {
    await runDisable(context);
  } else {
    await turnLintsOn(context);
  }
}
