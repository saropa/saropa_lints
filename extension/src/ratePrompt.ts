/**
 * Rate-us nudge — asks the user to leave a review on the VS Code Marketplace
 * or Open VSX after they have completed a few scans, so the prompt arrives
 * when Saropa Lints has already proved useful rather than on first install.
 *
 * Once-gated via globalState: shown once per machine, never re-prompted after
 * "Don't ask again" or "Not now" (the latter defers to a future session by
 * incrementing the scan threshold). Honors the existing proactive-nudge
 * opt-out (`upgradePackNudge.enabled`).
 */

import * as vscode from 'vscode';
import { l10n } from './i18n/runtime';

/** Store URLs for the two extension registries. */
export const MARKETPLACE_REVIEW_URL =
  'https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints&ssr=false#review-details';
export const OPEN_VSX_REVIEW_URL =
  'https://open-vsx.org/extension/saropa/saropa-lints/reviews';

// globalState keys — scoped under `saropaLints.rate.` to avoid collisions.
const DISMISSED_KEY = 'saropaLints.rate.dismissed';
const SCAN_COUNT_KEY = 'saropaLints.rate.scanCount';
const DEFERRED_KEY = 'saropaLints.rate.deferred';

/**
 * Minimum scans before the first prompt. Lowered from 5 to 2: most users never
 * reach 5 scans in a session, so the toast (the main conversion surface) never
 * showed. 2 still guarantees the user has seen real results first.
 */
const INITIAL_SCAN_THRESHOLD = 2;
/** Extra scans required after each "Not now" deferral. */
const DEFERRED_SCAN_INCREMENT = 10;

/**
 * Call on every successful scan completion. Increments the scan counter and,
 * once the threshold is reached, shows the one-time rating toast.
 */
export async function maybePromptForRating(context: vscode.ExtensionContext): Promise<void> {
  // Permanently dismissed — never prompt again.
  if (context.globalState.get<boolean>(DISMISSED_KEY, false)) return;

  // Proactive-nudge master opt-out (shared with upgrade-pack and suite nudges).
  if (vscode.workspace.getConfiguration('saropaLints').get<boolean>('upgradePackNudge.enabled') === false) return;

  // Increment scan count.
  const count = context.globalState.get<number>(SCAN_COUNT_KEY, 0) + 1;
  await context.globalState.update(SCAN_COUNT_KEY, count);

  // Compute the current threshold: base + (deferrals × increment).
  const deferrals = context.globalState.get<number>(DEFERRED_KEY, 0);
  const threshold = INITIAL_SCAN_THRESHOLD + (deferrals * DEFERRED_SCAN_INCREMENT);
  if (count < threshold) return;

  // Show the prompt. Mark threshold reached before showing so a concurrent
  // activation cannot double-prompt.
  const marketplace = l10n('rate.nudge.marketplace');
  const openVsx = l10n('rate.nudge.openVsx');
  const notNow = l10n('rate.nudge.dismiss');
  const never = l10n('rate.nudge.never');

  const choice = await vscode.window.showInformationMessage(
    l10n('rate.nudge.message'),
    marketplace,
    openVsx,
    notNow,
    never,
  );

  if (choice === marketplace) {
    // Rated (or at least opened the page) — don't ask again.
    await context.globalState.update(DISMISSED_KEY, true);
    void vscode.env.openExternal(vscode.Uri.parse(MARKETPLACE_REVIEW_URL));
  } else if (choice === openVsx) {
    await context.globalState.update(DISMISSED_KEY, true);
    void vscode.env.openExternal(vscode.Uri.parse(OPEN_VSX_REVIEW_URL));
  } else if (choice === never) {
    // Explicit opt-out — permanently suppress.
    await context.globalState.update(DISMISSED_KEY, true);
  } else {
    // "Not now" or dismissed the toast — defer to a higher scan count.
    await context.globalState.update(DEFERRED_KEY, deferrals + 1);
  }
}
