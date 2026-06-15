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
import { l10n } from './i18n/runtime';

// ── Constants ────────────────────────────────────────────────────────────

const STATE_KEY = 'saropaLints.upgradeCheck';
/**
 * Minimum gap between successive pub.dev fetches per workspace.
 *
 * **Why this is short (1h) and not 24h.** Earlier the gate was 24h, which
 * meant the extension would not even *fetch* pub.dev within 24 hours of a
 * dismiss — so a brand-new version published the next morning was invisible
 * until the timer expired. The version-aware skip below
 * (`lastKnownLatest === latestVersion`) already prevents re-prompting for
 * the *same* version after dismiss, so the time gate's only remaining job
 * is anti-thrash on rapid VS Code reloads. 1h is plenty for that.
 */
const ANTI_THRASH_INTERVAL_MS = 60 * 60 * 1000; // 1 hour
/** Network-failure cooldown — slightly shorter than ANTI_THRASH so we recover quickly. */
const RETRY_INTERVAL_MS = 30 * 60 * 1000;       // 30 minutes
const PUB_API_URL = 'https://pub.dev/api/packages/saropa_lints';
const CHANGELOG_URL = 'https://pub.dev/packages/saropa_lints/changelog';

// ── Throttle state ───────────────────────────────────────────────────────

interface UpgradeCheckState {
  /**
   * Timestamp (ms) of the most recent successful fetch, used purely as an
   * anti-thrash floor for the *next* fetch (not a "don't notify until"
   * gate). Renamed in concept from the earlier `nextCheckDueMs` because
   * the throttle is now "per anti-thrash window OR per newly-published
   * version" — the latter always bypasses the former (see
   * [shouldFetchNow] and [shouldPromptForVersion]).
   */
  nextCheckDueMs: number;
  /** Latest version seen on pub.dev — prevents re-notifying after dismiss. */
  lastKnownLatest: string;
}

/**
 * Whether enough time has elapsed since the last fetch to fetch again.
 * Pure for testability — no `Date.now()` or vscode dependencies inside.
 *
 * Returns `true` when we have no prior state (first run) or the
 * `nextCheckDueMs` deadline has passed. The "did the version change"
 * question is answered AFTER the fetch (see [shouldPromptForVersion])
 * — we cannot answer that without contacting pub.dev, so the only
 * thing this gate guards is "don't hammer pub.dev on rapid VS Code
 * reloads."
 *
 * Legacy state written under the old 24h throttle stays in effect
 * until its deadline elapses (one-time degraded wait of up to 24h);
 * the next write replaces it with the new 1h semantics, so this is a
 * self-healing migration.
 */
export function shouldFetchNow(
  saved: UpgradeCheckState | undefined,
  now: number,
): boolean {
  if (!saved) return true;
  return now >= saved.nextCheckDueMs;
}

/**
 * Whether to prompt the user about [latestVersion] given prior state.
 * Returns `false` when the user has already dismissed exactly this
 * version (we know because `lastKnownLatest` matches), `true`
 * otherwise. A newly-published version naturally returns `true` here
 * because it cannot match the previously-dismissed value — that is the
 * "per version" half of the throttle promise.
 */
export function shouldPromptForVersion(
  saved: UpgradeCheckState | undefined,
  latestVersion: string,
): boolean {
  if (!saved) return true;
  return saved.lastKnownLatest !== latestVersion;
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

  // Anti-thrash gate: skip the fetch if we made one within the last
  // ANTI_THRASH_INTERVAL_MS. This is NOT "don't notify until X" — once
  // the fetch runs, [shouldPromptForVersion] decides whether to prompt
  // based on the version itself, so a freshly-published release breaks
  // through even if the user dismissed an older version recently.
  const saved = context.workspaceState.get<UpgradeCheckState>(STATE_KEY);
  if (!shouldFetchNow(saved, Date.now())) {
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
      // Non-fatal: shorter cooldown so we retry sooner. Preserve any
      // previously-known latest so a transient outage doesn't erase the
      // dismiss memory.
      await persistState(context, RETRY_INTERVAL_MS, saved?.lastKnownLatest ?? installed.version);
      return;
    }
    const json: any = await resp.json();
    latestVersion = json?.latest?.version;
    if (!latestVersion) return;
  } catch {
    // Network failure: same preserve-the-dismiss-memory pattern as above.
    await persistState(context, RETRY_INTERVAL_MS, saved?.lastKnownLatest ?? installed.version);
    return;
  }

  // Compare versions.
  const status = compareVersions(installed.version, latestVersion);
  if (status === 'up-to-date' || status === 'unknown') {
    await persistState(context, ANTI_THRASH_INTERVAL_MS, latestVersion);
    return;
  }

  // Already dismissed THIS exact version — quiet, but record latest seen.
  // A newer version will fail this check naturally and re-prompt.
  if (!shouldPromptForVersion(saved, latestVersion)) {
    await persistState(context, ANTI_THRASH_INTERVAL_MS, latestVersion);
    return;
  }

  // Persist before showing notification so concurrent activations don't double-fire.
  await persistState(context, ANTI_THRASH_INTERVAL_MS, latestVersion);

  // Show notification.
  const updateLabel = status === 'major' ? l10n('notify.misc.upgradeCheckerMajorUpdate')
    : status === 'minor' ? l10n('notify.misc.upgradeCheckerMinorUpdate')
      : l10n('notify.misc.upgradeCheckerPatchUpdate');

  // Capture action labels in consts so the post-dialog comparison stays in
  // lock-step with the localized button text shown to the user.
  const upgradeAction = l10n('notify.misc.actionUpgrade');
  const viewChangelogAction = l10n('notify.misc.actionViewChangelog');
  const dismissAction = l10n('notify.misc.actionDismiss');
  const choice = await vscode.window.showInformationMessage(
    l10n('notify.misc.upgradeCheckerAvailable', {
      label: updateLabel,
      from: installed.version,
      to: latestVersion,
    }),
    upgradeAction,
    viewChangelogAction,
    dismissAction,
  );

  if (choice === upgradeAction) {
    await performUpgrade(workspaceRoot, latestVersion);
  } else if (choice === viewChangelogAction) {
    await vscode.env.openExternal(vscode.Uri.parse(CHANGELOG_URL));
  }
}

/**
 * Force an upgrade check now, bypassing BOTH throttles.
 *
 * The normal [checkForUpgrade] is gated twice: an anti-thrash time window
 * (won't re-fetch pub.dev within the hour) and a dismiss memory (won't
 * re-prompt for a version the user already dismissed). Both are correct for
 * the passive background check but make it impossible to re-trigger the
 * notification on demand — there is no way to "see the upgrade prompt again"
 * after dismissing it once.
 *
 * This clears the persisted throttle state, then runs the check. With no
 * saved state, [shouldFetchNow] and [shouldPromptForVersion] both return
 * true, so the prompt reappears whenever a newer version genuinely exists on
 * pub.dev. It still shows nothing when the project is already up to date —
 * that is the honest outcome, not a bug. Wired to the "Scanned X ago" pill in
 * the Package Dashboard and the `saropaLints.checkForUpdatesNow` command so
 * users (and tests) have a deterministic path to re-surface the prompt.
 */
export async function forceUpgradeCheck(
  context: vscode.ExtensionContext,
  workspaceRoot: string,
): Promise<void> {
  await context.workspaceState.update(STATE_KEY, undefined);
  await checkForUpgrade(context, workspaceRoot);
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
          l10n('notify.misc.upgradeCheckerPubspecNotFound'),
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
          l10n('notify.misc.upgradeCheckerCancelled', {
            version: latestVersion,
            cmd: pubCmd,
          }),
        );
        return;
      }
      if (!ok) {
        void vscode.window.showErrorMessage(
          l10n('notify.misc.upgradeCheckerPubGetFailed', {
            detail: stderr || l10n('notify.misc.upgradeCheckerCheckOutput'),
          }),
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
        l10n('notify.misc.upgradeCheckerUpgraded', { version: latestVersion }),
      );
    },
  );
}
