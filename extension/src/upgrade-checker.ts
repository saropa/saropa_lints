/**
 * Background upgrade checker for the saropa_lints package.
 *
 * Runs asynchronously after activation to check if a newer version of
 * saropa_lints is available on pub.dev. Shows a non-intrusive notification
 * with Upgrade / View Changelog / Later / "Don't ask for this version"
 * actions when the installed version is outdated.
 *
 * Prompts on EVERY activation while the project is behind, so a toast that
 * is missed, closed, or collapsed into the notification bell is not the
 * user's only chance to see it. The only thing that silences a version is
 * the user explicitly clicking "Don't ask for this version" — closing the
 * toast, "Later", and "View Changelog" all leave the prompt free to
 * reappear next activation.
 *
 * The pub.dev network fetch is throttled independently of the prompt
 * (at most once per hour per workspace, see [ANTI_THRASH_INTERVAL_MS]) so
 * we never hammer the API on rapid VS Code reloads; within that window we
 * still prompt using the cached latest version from state.
 */

import * as vscode from 'vscode';
import * as fs from 'fs';
import * as path from 'path';
import { fetchWithRetry } from './vibrancy/services/fetch-retry';
import { compareVersions } from './vibrancy/services/changelog-service';
import { resolveDependencies } from './setup';
import { l10n } from './i18n/runtime';

// ── Constants ────────────────────────────────────────────────────────────

const STATE_KEY = 'saropaLints.upgradeCheck';
/**
 * Minimum gap between successive pub.dev *fetches* per workspace. This is a
 * fetch throttle only — it does NOT gate whether we prompt. While inside
 * this window we still prompt (using the cached latest version from state)
 * on every activation; we just skip contacting pub.dev again. That split is
 * the whole point of the design: prompting must survive a missed/closed
 * toast, but hammering pub.dev on rapid VS Code reloads still needs a floor.
 */
const ANTI_THRASH_INTERVAL_MS = 60 * 60 * 1000; // 1 hour
/** Network-failure cooldown — slightly shorter than ANTI_THRASH so we recover quickly. */
const RETRY_INTERVAL_MS = 30 * 60 * 1000;       // 30 minutes
const PUB_API_URL = 'https://pub.dev/api/packages/saropa_lints';
const CHANGELOG_URL = 'https://pub.dev/packages/saropa_lints/changelog';

// ── Throttle state ───────────────────────────────────────────────────────

interface UpgradeCheckState {
  /**
   * Timestamp (ms) of the most recent successful fetch attempt, used purely
   * as an anti-thrash floor for the *next* fetch (not a "don't prompt
   * until" gate — see [ANTI_THRASH_INTERVAL_MS]).
   */
  nextCheckDueMs: number;
  /**
   * Latest version last seen from pub.dev (or, on a network failure, the
   * previous value carried forward). Used to prompt from cache when the
   * anti-thrash window is active or a fetch just failed, so a genuine
   * network hiccup never silences an otherwise-due prompt.
   */
  cachedLatest?: string;
  /**
   * The exact version the user explicitly dismissed via "Don't ask for
   * this version". This is the ONLY thing that suppresses a prompt —
   * showing the toast, closing it, "Later", and "View Changelog" never
   * write this field. A newer version on pub.dev naturally fails the
   * equality check and prompts again.
   */
  dismissedVersion?: string;
}

/**
 * Whether enough time has elapsed since the last fetch to fetch again.
 * Pure for testability — no `Date.now()` or vscode dependencies inside.
 *
 * Returns `true` when we have no prior state (first run) or the
 * `nextCheckDueMs` deadline has passed. This only gates the pub.dev
 * *fetch*; when it returns `false`, [checkForUpgrade] still evaluates
 * `shouldPromptForVersion` against the cached latest version rather than
 * skipping the prompt outright.
 *
 * Legacy state written under the pre-fix schema (`{nextCheckDueMs,
 * lastKnownLatest}`) still satisfies this signature — `nextCheckDueMs`
 * kept the same meaning — so old deadlines are honoured as-is until they
 * elapse, then the next write replaces them with the current shape.
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
 * Returns `false` only when the user explicitly dismissed exactly this
 * version (`dismissedVersion` matches), `true` otherwise.
 *
 * Deliberately does NOT consult the legacy `lastKnownLatest` field: that
 * field recorded "the last version we happened to fetch or show", not a
 * user decision, and treating it as a dismissal was the original bug (a
 * missed/closed toast silenced the version forever). Pre-fix state has no
 * `dismissedVersion`, so it always prompts here — a self-healing migration
 * with no special-casing needed.
 */
export function shouldPromptForVersion(
  saved: UpgradeCheckState | undefined,
  latestVersion: string,
): boolean {
  if (!saved) return true;
  return saved.dismissedVersion !== latestVersion;
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
 * Shows a notification with Upgrade / View Changelog / Later / "Don't ask
 * for this version" actions when outdated. Prompts on every activation
 * while behind — only "Don't ask for this version" silences it, and only
 * for that exact version. Fails silently on network errors — never blocks
 * activation.
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

  const saved = context.workspaceState.get<UpgradeCheckState>(STATE_KEY);

  // Legacy state (pre-fix schema) may carry a `lastKnownLatest` field. We
  // seed the cache from it — nothing more. It must NEVER seed
  // `dismissedVersion`: that was the original bug (a missed/closed toast
  // silenced the version forever). See [shouldPromptForVersion].
  const legacyLatest = (saved as { lastKnownLatest?: unknown } | undefined)?.lastKnownLatest;
  let latestVersion: string | undefined =
    saved?.cachedLatest ?? (typeof legacyLatest === 'string' ? legacyLatest : undefined);

  // Read the resolved version from pubspec.lock.
  const lockPath = path.join(workspaceRoot, 'pubspec.lock');
  if (!fs.existsSync(lockPath)) return;

  const lockContent = fs.readFileSync(lockPath, 'utf-8');
  const installed = readInstalledVersion(lockContent);
  if (!installed) return;

  // Skip path/git dependencies — developer is using a local or pinned version.
  if (installed.source === 'path' || installed.source === 'git') return;

  // Fetch throttle: only contact pub.dev if the anti-thrash window has
  // elapsed. Within the window we fall through and prompt using
  // `latestVersion` as seeded above (cached or legacy) instead of
  // returning — the fetch throttle must never silence a due prompt.
  if (shouldFetchNow(saved, Date.now())) {
    try {
      const resp = await fetchWithRetry(PUB_API_URL);
      if (!resp.ok) {
        // Non-fatal: shorter cooldown so we retry sooner. Preserve any
        // previously-cached latest so a transient outage doesn't blank
        // out an otherwise-due prompt.
        await persistState(context, RETRY_INTERVAL_MS, latestVersion, saved?.dismissedVersion);
      } else {
        const json: any = await resp.json();
        const fetched = json?.latest?.version;
        if (typeof fetched === 'string' && fetched) {
          latestVersion = fetched;
        }
        await persistState(context, ANTI_THRASH_INTERVAL_MS, latestVersion, saved?.dismissedVersion);
      }
    } catch {
      // Network failure: same preserve-the-cache pattern as above.
      await persistState(context, RETRY_INTERVAL_MS, latestVersion, saved?.dismissedVersion);
    }
  }

  // No fetch has ever succeeded and there's nothing cached — stay silent.
  if (!latestVersion) return;

  // Compare versions.
  const status = compareVersions(installed.version, latestVersion);
  if (status === 'up-to-date' || status === 'unknown') return;

  // Already dismissed THIS exact version. A newer version will fail this
  // check naturally and prompt again.
  if (!shouldPromptForVersion(saved, latestVersion)) return;

  // Show notification.
  const updateLabel = status === 'major' ? l10n('notify.misc.upgradeCheckerMajorUpdate')
    : status === 'minor' ? l10n('notify.misc.upgradeCheckerMinorUpdate')
      : l10n('notify.misc.upgradeCheckerPatchUpdate');

  // Major upgrades may need config changes (new/renamed rules, packs) —
  // call that out explicitly and point at the changelog rather than
  // letting the user discover it after `pub get`.
  const message = status === 'major'
    ? l10n('notify.misc.upgradeCheckerAvailableMajor', {
      label: updateLabel,
      from: installed.version,
      to: latestVersion,
    })
    : l10n('notify.misc.upgradeCheckerAvailable', {
      label: updateLabel,
      from: installed.version,
      to: latestVersion,
    });

  // Capture action labels in consts so the post-dialog comparison stays in
  // lock-step with the localized button text shown to the user.
  const upgradeAction = l10n('notify.misc.actionUpgrade');
  const viewChangelogAction = l10n('notify.misc.actionViewChangelog');
  const laterAction = l10n('notify.misc.actionLater');
  const dontAskAction = l10n('notify.misc.actionDontAskForVersion');
  const choice = await vscode.window.showInformationMessage(
    message,
    upgradeAction,
    viewChangelogAction,
    laterAction,
    dontAskAction,
  );

  if (choice === upgradeAction) {
    await performUpgrade(workspaceRoot, latestVersion);
  } else if (choice === viewChangelogAction) {
    await vscode.env.openExternal(vscode.Uri.parse(CHANGELOG_URL));
  } else if (choice === dontAskAction) {
    // The ONLY choice that suppresses future prompts, and only for this
    // exact version. Showing the toast, closing it, "Later", and "View
    // Changelog" all leave the prompt free to reappear next activation.
    await persistState(context, ANTI_THRASH_INTERVAL_MS, latestVersion, latestVersion);
  }
}

/**
 * Force an upgrade check now, bypassing BOTH throttles.
 *
 * The normal [checkForUpgrade] is gated twice: a fetch anti-thrash window
 * (won't re-contact pub.dev within the hour, though it still prompts from
 * cache) and a per-version dismiss memory (won't re-prompt for a version
 * the user explicitly clicked "Don't ask for this version" on). Both are
 * correct for the passive background check but make it impossible to force
 * a *fresh* pub.dev fetch on demand.
 *
 * This clears the persisted state entirely, then runs the check. With no
 * saved state, [shouldFetchNow] and [shouldPromptForVersion] both return
 * true, so a real pub.dev fetch happens and the prompt reappears whenever a
 * newer version genuinely exists — including a version the user previously
 * dismissed. It still shows nothing when the project is already up to
 * date — that is the honest outcome, not a bug. Wired to the "Scanned X
 * ago" pill in the Package Dashboard and the `saropaLints.checkForUpdatesNow`
 * command so users (and tests) have a deterministic path to re-surface the
 * prompt.
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
  cachedLatest: string | undefined,
  dismissedVersion: string | undefined,
): Promise<void> {
  const state: UpgradeCheckState = {
    nextCheckDueMs: Date.now() + intervalMs,
    cachedLatest,
    dismissedVersion,
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
      // `dart`, not `flutter`, for the same reason as the Enable flow: the
      // flutter wrapper boots flutter_tool before pub runs, measured at ~114 s
      // of pure overhead on a large project. resolveDependencies falls back to
      // `flutter pub get` when — and only when — the dart resolve fails on the
      // Flutter SDK itself.
      const { ok, stderr, cancelled, command: pubCmd } = await resolveDependencies(
        workspaceRoot,
        token,
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
