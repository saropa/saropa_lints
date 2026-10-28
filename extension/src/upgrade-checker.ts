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
import { getPubVersions, PubVersionsCache } from './compat/pubVersions';
import { compareVersions } from './vibrancy/services/changelog-service';
import { l10n } from './i18n/runtime';
import { VERSIONS_CACHE_KEY } from './compat/upgradeGate';
import { readConfiguredPluginVersion, type ConfiguredPluginVersion } from './analysisOptionsVersion';

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
 * Read the lock-resolved version and the version configured under
 * `plugins: saropa_lints:` in analysis_options.yaml, side by side.
 * Either side is null when its file is missing or has no matching entry.
 */
export function readVersions(workspaceRoot: string): {
  installed: { version: string; source: string } | null;
  configured: ConfiguredPluginVersion | null;
} {
  const readIfExists = (name: string): string | null => {
    const p = path.join(workspaceRoot, name);
    return fs.existsSync(p) ? fs.readFileSync(p, 'utf-8') : null;
  };
  const lock = readIfExists('pubspec.lock');
  return {
    installed: lock ? readInstalledVersion(lock) : null,
    configured: readConfiguredPluginVersion(readIfExists('analysis_options.yaml')),
  };
}

/**
 * Replace the saropa_lints version constraint in pubspec.yaml. Only the
 * `dev_dependencies:` / `dependencies:` sections are searched (never
 * `dependency_overrides:` or a nested key), and only a direct child of the
 * section is rewritten. Preserves line endings (CRLF on Windows) to avoid git
 * noise. Returns null when no such line exists.
 */
export function applyPubspecConstraint(content: string, newVersion: string): string | null {
  const lines = content.split('\n');
  let inSection = false;
  let childIndent: number | undefined;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].replace(/\r$/, '');
    if (/^\S/.test(line)) {
      // New top-level key (comments at column 0 start with '#').
      if (line.startsWith('#')) continue;
      inSection = /^(dev_dependencies|dependencies)\s*:\s*(#.*)?$/.test(line);
      childIndent = undefined;
      continue;
    }
    if (!inSection || line.trim() === '' || /^\s*#/.test(line)) continue;
    const indent = /^\s*/.exec(line)![0].length;
    childIndent ??= indent;
    if (indent !== childIndent) continue;
    const m = /^(\s+saropa_lints\s*:\s*).*?(\r?)$/.exec(lines[i]);
    if (m) {
      // m[2] restores \r if the original line had CRLF, preventing EOL corruption.
      lines[i] = `${m[1]}^${newVersion}${m[2]}`;
      return lines.join('\n');
    }
  }
  return null;
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
  const { installed, configured } = readVersions(workspaceRoot);
  if (!installed) return;
  if (configured && configured.raw !== installed.version) {
    console.log(
      `[saropa_lints] analysis_options plugin version ${configured.raw}` +
      `${configured.isRange ? ' (range)' : ''} vs pubspec.lock ${installed.version}`,
    );
  }

  // Skip path/git dependencies — developer is using a local or pinned version.
  if (installed.source === 'path' || installed.source === 'git') return;

  // Fetch throttle: only contact pub.dev if the anti-thrash window has
  // elapsed. Within the window we fall through and prompt using
  // `latestVersion` as seeded above (cached or legacy) instead of
  // returning — the fetch throttle must never silence a due prompt.
  if (shouldFetchNow(saved, Date.now())) {
    try {
      const result = await getPubVersions({
        store: {
          get: () => context.globalState.get<PubVersionsCache>(VERSIONS_CACHE_KEY),
          set: (c) => context.globalState.update(VERSIONS_CACHE_KEY, c),
        },
      });
      if (result.stale) {
        // Non-fatal: shorter cooldown so we retry sooner. Preserve any
        // previously-cached latest so a transient outage doesn't blank
        // out an otherwise-due prompt.
        await persistState(context, RETRY_INTERVAL_MS, latestVersion, saved?.dismissedVersion);
      } else {
        if (result.latest) {
          latestVersion = result.latest;
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

  // Offer only a version the compatibility recommender accepts for this
  // project (Dart SDK, meta pin). The solver is not run here; it runs when
  // the user clicks Upgrade. Loaded lazily: the controller imports modules
  // that import this one.
  const { offeredVersion } = await import('./compat/compatController');
  const offered = await offeredVersion(context, workspaceRoot, installed.version);
  if (!offered) return;
  latestVersion = offered;

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
    await performUpgrade(workspaceRoot, latestVersion, context);
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
  offered: string,
  context: vscode.ExtensionContext,
): Promise<void> {
  const { computeCompat, applyCompatNow, describeOutcome } = await import('./compat/compatController');
  const { decideOnUpgrade } = await import('./compat/upgradeGate');
  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: `Upgrading Saropa Lints to ${offered}`,
      // Cancellable: pub resolution can take 30s+; the token kills the child
      // process tree on cancel.
      cancellable: true,
    },
    async (progress, token) => {
      // Ask the pub solver now (on demand). If it cannot resolve the offered
      // version, show the compatibility card instead of failing after pub get.
      let rec: Awaited<ReturnType<typeof computeCompat>>['rec'];
      try {
        rec = (await computeCompat(context, workspaceRoot, true)).rec;
      } catch (err) {
        void vscode.window.showErrorMessage(
          l10n('compat.card.loadFailed', { detail: err instanceof Error ? err.message : String(err) }),
        );
        return;
      }
      if (token.isCancellationRequested) return;
      if (decideOnUpgrade(rec, offered) === 'openCard') {
        await vscode.commands.executeCommand('saropaLints.configureCompatibility');
        return;
      }

      // Edit both files, pub get, align the plugin version, init config;
      // restores both files if pub get fails.
      const outcome = await applyCompatNow(workspaceRoot, rec, token, progress);
      const { text, isError } = describeOutcome(outcome);
      if (isError) void vscode.window.showErrorMessage(text);
      else void vscode.window.showInformationMessage(text);
    },
  );
}
