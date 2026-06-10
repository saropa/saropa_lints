/**
 * Proactive "run the upgrade lints" nudge.
 *
 * When the workspace depends on a package at a version that a semver-gated rule
 * pack targets (e.g. dio >= 5.0.0 -> dio_5) but that pack is not enabled, offer
 * to enable it once. This surfaces migration lints right after a `pub upgrade`
 * instead of leaving them undiscovered.
 *
 * Accuracy: unlike the Rule Packs table (which only checks pubspec.yaml for the
 * dependency name), this reads the resolved version from pubspec.lock and
 * applies the same `>=` gate the Dart plugin enforces, so a project on dio 4.x
 * is not nudged about the dio_5 pack.
 *
 * Once-gating: every pack offered (enabled or dismissed) is recorded per
 * workspace so the prompt never reappears for the same pack.
 */
import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';

import { getProjectRoot } from '../projectRoot';
import { readRulePacksEnabled, writeRulePacksEnabled } from './rulePackYaml';
import { applicableDisabledPacks, parseLockVersions } from './upgradePackNudgeLogic';

/** Packs already offered (enabled or dismissed) in this workspace. */
const OFFERED_PACKS_KEY = 'saropaLints.upgradePackNudge.offered';

/**
 * Offer to enable any applicable-but-disabled dependency-gated pack, once per
 * pack per workspace. Safe to call on activation and on pubspec.lock change.
 */
export async function maybeOfferUpgradePacks(
  context: vscode.ExtensionContext,
): Promise<void> {
  const enabledSetting = vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('upgradePackNudge.enabled');
  if (enabledSetting === false) return;

  const root = getProjectRoot();
  if (!root) return;

  let lockContent: string;
  try {
    lockContent = fs.readFileSync(path.join(root, 'pubspec.lock'), 'utf-8');
  } catch {
    // No lockfile yet (pub get not run) — nothing to resolve against.
    return;
  }

  const lockVersions = parseLockVersions(lockContent);
  const enabled = new Set(readRulePacksEnabled(root));
  const offered = new Set(context.workspaceState.get<string[]>(OFFERED_PACKS_KEY, []));

  const candidates = applicableDisabledPacks(lockVersions, enabled).filter(
    (def) => !offered.has(def.id),
  );
  if (candidates.length === 0) return;

  // Record the offer up front so dismissing (or ignoring) never re-prompts.
  for (const def of candidates) offered.add(def.id);
  await context.workspaceState.update(OFFERED_PACKS_KEY, [...offered]);

  const labels = candidates.map((def) => def.label).join(', ');
  const detail =
    candidates.length === 1
      ? `${labels} migration lints match your resolved package version.`
      : `${candidates.length} migration packs match your resolved package versions: ${labels}.`;
  const choice = await vscode.window.showInformationMessage(
    `Saropa Lints: ${detail} Enable the upgrade lints?`,
    'Enable',
    'Dismiss',
  );
  if (choice !== 'Enable') return;

  for (const def of candidates) enabled.add(def.id);
  const ok = writeRulePacksEnabled(root, [...enabled].sort((a, b) => a.localeCompare(b)));
  if (!ok) {
    void vscode.window.showErrorMessage(
      'Saropa Lints: could not write analysis_options.yaml (rule_packs).',
    );
    return;
  }

  const run = vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('runAnalysisAfterConfigChange');
  if (run !== false) {
    await vscode.commands.executeCommand('saropaLints.runAnalysis');
  }
  void vscode.window.showInformationMessage(
    `Saropa Lints: enabled ${candidates.length} upgrade pack(s): ${labels}.`,
  );
}
