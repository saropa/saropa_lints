/**
 * Coalesced startup suggestion nudge.
 *
 * On activation (and after a `pubspec.lock` change) a project may have several
 * applicable-but-disabled rule packs plus a possibly-missing init step. Surfacing
 * each as its own toast meant two or more notifications fired seconds apart; VS
 * Code's newest-on-top stacking pushed the earlier ones out of view and they
 * auto-collapsed into the notification center before the user could read them —
 * the "terrible UX" this module exists to fix.
 *
 * Instead we show exactly ONE notification summarizing the count and route its
 * "Review" action to the Suggestions view, which lists every applicable pack
 * individually (init step + sdk packs + lockfile-resolved upgrade packs, all from
 * {@link computeConfigSuggestions}). The activity-bar badge on that view is the
 * durable backstop: even after the single toast collapses, the count persists
 * there, so nothing is lost.
 *
 * Once-gating: the set of suggestion ids already surfaced is recorded per
 * workspace, so the toast never re-nags about packs the user has already seen,
 * but a NEW pack brought into range by a later `pub upgrade` still triggers it.
 */
import * as vscode from 'vscode';

import { computeConfigSuggestions } from '../config/configSuggestions';
import { getProjectRoot } from '../projectRoot';
import { l10n } from '../i18n/runtime';

/** Suggestion ids already surfaced (so the toast does not re-nag) in this workspace. */
const SURFACED_IDS_KEY = 'saropaLints.startupSuggestion.surfaced';

/**
 * Re-entrancy guard. The activation timer and the pubspec.lock watcher can both
 * fire within the same window; without this guard two concurrent calls each read
 * the surfaced-set before either writes it back, and BOTH pass the freshness
 * check — which is exactly how two competing toasts appeared. A single in-flight
 * flag collapses that race to one toast.
 */
let inFlight = false;

/**
 * Show one coalesced toast when the project has applicable-but-disabled rule
 * packs (or a missing init step) the user has not been told about yet. Safe to
 * call on activation and on pubspec.lock change.
 */
export async function maybeShowStartupSuggestion(
  context: vscode.ExtensionContext,
): Promise<void> {
  // Honors the existing proactive-nudge opt-out so users who turned it off stay off.
  const enabledSetting = vscode.workspace
    .getConfiguration('saropaLints')
    .get<boolean>('upgradePackNudge.enabled');
  if (enabledSetting === false) return;

  if (inFlight) return;
  inFlight = true;
  try {
    const root = getProjectRoot();
    if (!root) return;

    const suggestions = computeConfigSuggestions(root);
    if (suggestions.length === 0) return;

    const surfaced = new Set(
      context.workspaceState.get<string[]>(SURFACED_IDS_KEY, []),
    );
    // Only prompt when at least one suggestion is new since the last time we
    // surfaced — re-opening a project the user already triaged stays silent.
    const hasFresh = suggestions.some((s) => !surfaced.has(s.id));
    if (!hasFresh) return;

    // Record up front so dismissing (or ignoring) the toast never re-prompts.
    for (const s of suggestions) surfaced.add(s.id);
    await context.workspaceState.update(SURFACED_IDS_KEY, [...surfaced]);

    const choice = await vscode.window.showInformationMessage(
      l10n('startupNudge.message', { count: String(suggestions.length) }),
      l10n('startupNudge.review'),
      l10n('startupNudge.dismiss'),
    );
    if (choice !== l10n('startupNudge.review')) return;

    // Reveal the Suggestions view; each pack is listed there with its own
    // one-click enable, which is where the actual rule_packs write happens.
    await vscode.commands.executeCommand('saropaLints.suggestions.focus');
  } finally {
    inFlight = false;
  }
}
