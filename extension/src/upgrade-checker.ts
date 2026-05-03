/**
 * Background upgrade checker for the saropa_lints package.
 *
 * Runs asynchronously after activation to check if a newer version of
 * saropa_lints is available on pub.dev. Shows a non-intrusive notification
 * with an "Upgrade" action when the installed version is outdated.
 *
 * Throttled to once per 24 hours per workspace. Dismissed versions are
 * remembered so the notification only reappears when a newer version
 * is published.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { fetchWithRetry } from './vibrancy/services/fetch-retry';
import { compareVersions } from './vibrancy/services/changelog-service';
import { runInWorkspaceAsync, hasFlutterDep } from './setup';

// ── Constants ────────────────────────────────────────────────────────────

const STATE_KEY = 'saropaLints.upgradeCheck';
const CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000; // 24 hours
const RETRY_INTERVAL_MS = 60 * 60 * 1000;      // 1 hour (network failure cooldown)
const PUB_API_URL = 'https://pub.dev/api/packages/saropa_lints';
const CHANGELOG_URL = 'https://pub.dev/packages/saropa_lints/changelog';

// ── Throttle state ───────────────────────────────────────────────────────

interface UpgradeCheckState {
  /** Timestamp (ms) when the next check is allowed. */
  nextCheckDueMs: number;
  /** Latest version seen on pub.dev — prevents re-notifying after dismiss. */
  lastKnownLatest: string;
}

// ── Exported helpers (also used in tests) ────────────────────────────────

/** Extract the resolved saropa_lints version and source from pubspec.lock content. */
export function readInstalledVersion(
  lockContent: string,
): { version: string; source: string } | null {
  // pubspec.lock format: two-space-indented package name, then indented fields.
  // We look for the saropa_lints block and extract version + source.
  const lines = lockContent.split('\n');
  let inBlock = false;
  let version = '';
  let source = '';

  for (const rawLine of lines) {
    const line = rawLine.trimEnd();

    // Package names are indented by exactly two spaces and end with a colon.
    if (/^\s{2}saropa_lints:$/.test(line)) {
      inBlock = true;
      continue;
    }

    // Another package block starts — stop scanning.
    if (inBlock && /^\s{2}\w/.test(line) && !/^\s{4}/.test(line)) {
      break;
    }

    if (!inBlock) continue;

    const versionMatch = line.match(/^\s+version:\s+"([^"]+)"/);
    if (versionMatch) {
      version = versionMatch[1];
    }

    const sourceMatch = line.match(/^\s+source:\s+(\S+)/);
    if (sourceMatch) {
      source = sourceMatch[1];
    }
  }

  if (!version) return null;
  return { version, source };
}

/**
 * Replace the saropa_lints version constraint in pubspec.yaml.
 * Preserves existing line endings (CRLF on Windows) to avoid git noise.
 */
export function updatePubspecConstraint(
  pubspecPath: string,
  newVersion: string,
): boolean {
  if (!fs.existsSync(pubspecPath)) return false;

  const content = fs.readFileSync(pubspecPath, 'utf-8');

  // Match the saropa_lints dependency line. The \r? captures an optional
  // carriage return so we can preserve CRLF endings on Windows.
  const pattern = /^(\s+saropa_lints\s*:\s*).*?(\r?)$/m;
  if (!pattern.test(content)) return false;

  // $2 restores \r if the original line had CRLF, preventing EOL corruption.
  const updated = content.replace(pattern, `$1^${newVersion}$2`);
  fs.writeFileSync(pubspecPath, updated, 'utf-8');
  return true;
}

// ── Main entry point ─────────────────────────────────────────────────────

/**
 * Check whether a newer saropa_lints version is available on pub.dev.
 * Shows a notification with Upgrade / View Changelog actions when outdated.
 * Fails silently on network errors — never blocks activation.
 */
export async function checkForUpgrade(
  context: vscode.ExtensionContext,
  workspaceRoot: string,
): Promise<void> {
  // Respect opt-out setting.
  const enabled = vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('checkForUpdates', true);
  if (!enabled) return;

  // Throttle: skip if the next check isn't due yet.
  const saved = context.workspaceState.get<UpgradeCheckState>(STATE_KEY);
  if (saved && Date.now() < saved.nextCheckDueMs) {
    return;
  }

  // Read the resolved version from pubspec.lock.
  const lockPath = path.join(workspaceRoot, 'pubspec.lock');
  if (!fs.existsSync(lockPath)) return;

  const lockContent = fs.readFileSync(lockPath, 'utf-8');
  const installed = readInstalledVersion(lockContent);
  if (!installed) return;

  // Skip path/git dependencies — developer is using a local or pinned version.
  if (installed.source === 'path' || installed.source === 'git') return;

  // Fetch latest version from pub.dev.
  let latestVersion: string;
  try {
    const resp = await fetchWithRetry(PUB_API_URL);
    if (!resp.ok) {
      // Non-fatal: set a shorter cooldown so we retry sooner.
      await persistState(context, RETRY_INTERVAL_MS, installed.version);
      return;
    }
    const json: any = await resp.json();
    latestVersion = json?.latest?.version;
    if (!latestVersion) return;
  } catch {
    // Network failure: set a shorter cooldown.
    await persistState(context, RETRY_INTERVAL_MS, installed.version);
    return;
  }

  // Compare versions.
  const status = compareVersions(installed.version, latestVersion);
  if (status === 'up-to-date' || status === 'unknown') {
    await persistState(context, CHECK_INTERVAL_MS, latestVersion);
    return;
  }

  // Don't re-notify if user already dismissed this version.
  if (saved?.lastKnownLatest === latestVersion) {
    await persistState(context, CHECK_INTERVAL_MS, latestVersion);
    return;
  }

  // Persist before showing notification so concurrent activations don't double-fire.
  await persistState(context, CHECK_INTERVAL_MS, latestVersion);

  // Show notification.
  const updateLabel = status === 'major' ? 'Major update'
    : status === 'minor' ? 'Minor update'
      : 'Patch update';

  const choice = await vscode.window.showInformationMessage(
    `Saropa Lints ${updateLabel}: ${installed.version} \u2192 ${latestVersion}`,
    'Upgrade',
    'View Changelog',
    'Dismiss',
  );

  if (choice === 'Upgrade') {
    await performUpgrade(workspaceRoot, latestVersion);
  } else if (choice === 'View Changelog') {
    await vscode.env.openExternal(vscode.Uri.parse(CHANGELOG_URL));
  }
}

// ── Internals ────────────────────────────────────────────────────────────

async function persistState(
  context: vscode.ExtensionContext,
  intervalMs: number,
  latestVersion: string,
): Promise<void> {
  const state: UpgradeCheckState = {
    nextCheckDueMs: Date.now() + intervalMs,
    lastKnownLatest: latestVersion,
  };
  await context.workspaceState.update(STATE_KEY, state);
}

async function performUpgrade(
  workspaceRoot: string,
  latestVersion: string,
): Promise<void> {
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: `Upgrading Saropa Lints to ${latestVersion}`,
      // Cancellable: the prior `cancellable: false` combined with a synchronous
      // `spawnSync` for `pub get` blocked the extension host event loop for the
      // full duration of pub resolution (often 30s+), locking up VS Code with no
      // way out. The token below kills the child process tree on cancel.
      cancellable: true,
    },
    async (_progress, token) => {
      // Step 1: Update the version constraint in pubspec.yaml.
      const pubspecPath = path.join(workspaceRoot, 'pubspec.yaml');
      if (!updatePubspecConstraint(pubspecPath, latestVersion)) {
        void vscode.window.showErrorMessage(
          'Saropa Lints: Could not update pubspec.yaml \u2014 saropa_lints entry not found.',
        );
        return;
      }

      // Step 2: Run pub get to resolve the new version. Async + cancellable so the
      // extension host stays responsive while pub fetches and resolves the graph.
      const useFlutter = hasFlutterDep(pubspecPath);
      const pubCmd = useFlutter ? 'flutter' : 'dart';
      const { ok, stderr, cancelled } = await runInWorkspaceAsync(
        workspaceRoot,
        pubCmd,
        ['pub', 'get'],
        { token },
      );
      if (cancelled) {
        // pubspec.yaml constraint already changed; tell the user how to recover.
        // We deliberately don't auto-revert \u2014 they may want to retry pub get.
        void vscode.window.showWarningMessage(
          'Saropa Lints upgrade cancelled. pubspec.yaml was updated to '
          + `^${latestVersion}; run \`${pubCmd} pub get\` to finish, or revert the change.`,
        );
        return;
      }
      if (!ok) {
        void vscode.window.showErrorMessage(
          `Saropa Lints: pub get failed. ${stderr || 'Check Output.'}`,
        );
        return;
      }

      // Bail before kicking off config init if the user cancelled between steps.
      if (token.isCancellationRequested) return;

      // Step 3: Re-initialize config so analysis_options.yaml reflects
      // any new rules or changes in the updated package version.
      // (`initializeConfig` is itself cancellable and async \u2014 see setup.ts.)
      await vscode.commands.executeCommand('saropaLints.initializeConfig');

      void vscode.window.showInformationMessage(
        `Saropa Lints upgraded to ${latestVersion}.`,
      );
    },
  );
}
