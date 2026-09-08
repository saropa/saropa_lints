/**
 * Workspace readiness indicator — combines hazard scan, watcher exclude
 * audit, and host memory into a single status bar presence.
 * Pure computation in `computeReadiness`; live gathering in `gatherReadiness`.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { getUncoveredHazards } from './workspaceHazardScan';
import { findMissingExcludes } from './watcherExcludeAudit';
import type { ExtensionHostMemory } from './types';
import { formatBytes } from './processQuery';

// ── Readiness levels ──────────────────────────────────────────────────

/** Traffic-light levels: Green → nothing to report, Yellow → minor
 *  issues, Red → at least one critical issue requiring attention. */
export const enum ReadinessLevel {
  Green = 'green',
  Yellow = 'yellow',
  Red = 'red',
}

// ── Data interfaces ───────────────────────────────────────────────────

/** Per-dimension counts and the overall level, returned by computeReadiness. */
export interface WorkspaceReadiness {
  /** Overall readiness level — the worst of the three dimensions. */
  level: ReadinessLevel;
  /** Number of large files not excluded from the file watcher. */
  hazardFileCount: number;
  /** Number of recommended watcher-exclude patterns not configured. */
  missingExcludeCount: number;
  /** True when extension host RSS exceeds the warning threshold. */
  hostMemoryWarning: boolean;
  /** Total count of issues (sum of all dimensions). */
  totalIssues: number;
}

// ── Pure computation ──────────────────────────────────────────────────

/** Compute the workspace readiness assessment from three input signals.
 *
 *  Hazard files are always Red — they caused the 2026-09-05 crash.
 *  Host memory critical is Red (the extension host itself is at risk).
 *  Missing excludes alone are Yellow (preventive, not actively dangerous). */
export function computeReadiness(
  hazardFileCount: number,
  missingExcludeCount: number,
  hostMemoryWarning: boolean,
): WorkspaceReadiness {
  const totalIssues =
    hazardFileCount + missingExcludeCount + (hostMemoryWarning ? 1 : 0);

  // Red: large unexcluded files or host memory exceeded — both can crash.
  const isRed = hazardFileCount > 0 || hostMemoryWarning;
  // Yellow: missing excludes are preventive but not immediately dangerous.
  const isYellow = !isRed && missingExcludeCount > 0;

  const level = isRed
    ? ReadinessLevel.Red
    : isYellow
      ? ReadinessLevel.Yellow
      : ReadinessLevel.Green;

  return {
    level,
    hazardFileCount,
    missingExcludeCount,
    hostMemoryWarning,
    totalIssues,
  };
}

// ── Live data collection ──────────────────────────────────────────────

/** Gather the three signals from their respective modules and return
 *  the current workspace readiness. Reads VS Code config and workspace
 *  state — not pure, but keeps the gathering in one place. */
export async function gatherReadiness(
  hostMemory: ExtensionHostMemory | undefined,
): Promise<WorkspaceReadiness> {
  const hazardCount = (await getUncoveredHazards()).length;
  const missingCount = findMissingExcludes().length;

  // Check host memory against the configured threshold.
  let hostWarn = false;
  if (hostMemory) {
    const cfg = vscode.workspace.getConfiguration('saropaLints.systemHealth');
    const thresholdGB = cfg.get<number>('extensionHostWarningGB', 1);
    // Convert RSS bytes to GB for comparison.
    hostWarn = hostMemory.rssBytes / 1_073_741_824 >= thresholdGB;
  }

  return computeReadiness(hazardCount, missingCount, hostWarn);
}

// ── Quick-pick items for the command ──────────────────────────────────

/** Individual issue entry shown in the readiness quick-pick. */
interface ReadinessIssue {
  label: string;
  detail: string;
  /** Command to run when the user picks this item, if any. */
  command?: string;
}

/** Build the list of actionable issues for the readiness quick-pick.
 *  Each item explains the problem and offers a fix action. */
export function buildIssueItems(
  readiness: WorkspaceReadiness,
  hostMemory: ExtensionHostMemory | undefined,
): ReadinessIssue[] {
  const items: ReadinessIssue[] = [];

  // Hazard files — critical, link to the hazard scan command.
  if (readiness.hazardFileCount > 0) {
    items.push({
      label: l10n('workspaceReadiness.issue.hazardFiles', {
        count: String(readiness.hazardFileCount),
      }),
      detail: l10n('workspaceReadiness.issue.hazardFilesDetail'),
    });
  }

  // Missing watcher excludes — yellow, offer to add them.
  if (readiness.missingExcludeCount > 0) {
    items.push({
      label: l10n('workspaceReadiness.issue.missingExcludes', {
        count: String(readiness.missingExcludeCount),
      }),
      detail: l10n('workspaceReadiness.issue.missingExcludesDetail'),
    });
  }

  // Host memory warning — critical, link to process health.
  if (readiness.hostMemoryWarning && hostMemory) {
    items.push({
      label: l10n('workspaceReadiness.issue.hostMemory', {
        size: formatBytes(hostMemory.rssBytes),
      }),
      detail: l10n('workspaceReadiness.issue.hostMemoryDetail'),
      command: 'saropaLints.showProcessHealth',
    });
  }

  return items;
}

// ── Command handler ───────────────────────────────────────────────────

/** Show the full readiness report as a quick-pick with actionable items.
 *  Registered as `saropaLints.showWorkspaceReadiness`. */
export async function showWorkspaceReadiness(
  hostMemory: ExtensionHostMemory | undefined,
): Promise<void> {
  const readiness = await gatherReadiness(hostMemory);

  // All clear — nothing to report.
  if (readiness.level === ReadinessLevel.Green) {
    void vscode.window.showInformationMessage(
      l10n('workspaceReadiness.allClear'),
    );
    return;
  }

  const issues = buildIssueItems(readiness, hostMemory);

  // Show a quick-pick so the user can act on individual issues.
  const picked = await vscode.window.showQuickPick(
    issues.map((i) => ({ label: i.label, detail: i.detail, meta: i })),
    { title: l10n('workspaceReadiness.quickPickTitle'), placeHolder: l10n('workspaceReadiness.quickPickPlaceholder') },
  );

  // If the picked item has a command, execute it.
  if (picked?.meta.command) {
    void vscode.commands.executeCommand(picked.meta.command);
  }
}

// ── Status bar integration helper ─────────────────────────────────────

/** Return a short status bar string when readiness is Yellow or Red,
 *  or undefined when everything is Green (nothing to show). */
export function readinessStatusBarText(
  readiness: WorkspaceReadiness,
): string | undefined {
  if (readiness.level === ReadinessLevel.Green) return undefined;

  // Use a warning or critical prefix depending on the level.
  const count = String(readiness.totalIssues);
  return readiness.level === ReadinessLevel.Red
    ? l10n('workspaceReadiness.statusBar.red', { count })
    : l10n('workspaceReadiness.statusBar.yellow', { count });
}
