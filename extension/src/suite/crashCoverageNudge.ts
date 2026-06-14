/**
 * `vscode` glue for crash-to-rule attribution (plan requirement R3). Turns a
 * {@link CrashRuleSuggestion} — a runtime crash family Log Capture observed whose
 * preventing Lints rule is currently disabled — into a one-tap "enable rule X"
 * toast wired to the public `saropaLints.enableRule` deep-link command.
 *
 * The pure mapping and the `log-capture.json` read live in {@link ./crashToRule};
 * this file only decides when to show the toast and gates it so it never nags.
 *
 * Gating: each rule is offered at most once, keyed in `globalState`. The flag is
 * set the moment the toast is shown (offered, not on-accept) so a dismissed toast
 * does not reappear on the next analysis tick — the same once-and-done pattern the
 * other proactive suggestions use. We surface a single toast per invocation (the
 * highest-occurrence un-offered suggestion) rather than a stack of them.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { readDisabledRules } from '../configWriter';
import { findCrashCoveredDisabledRules, type CrashRuleSuggestion } from './crashToRule';

/** globalState key prefix for the per-rule offered flag. */
const OFFERED_KEY_PREFIX = 'suite.crashNudge.offered.';

function offeredKey(ruleId: string): string {
  return `${OFFERED_KEY_PREFIX}${ruleId}`;
}

/**
 * Pick the most useful un-offered suggestion to surface: highest occurrence count
 * first (the family that crashed most in the wild is the most worth covering),
 * then by rule id for a stable, test-friendly order. Returns undefined when every
 * suggestion has already been offered.
 */
function pickSuggestion(
  context: vscode.ExtensionContext,
  suggestions: CrashRuleSuggestion[],
): CrashRuleSuggestion | undefined {
  const unoffered = suggestions.filter(
    (s) => context.globalState.get<boolean>(offeredKey(s.ruleId)) !== true,
  );
  if (unoffered.length === 0) return undefined;
  unoffered.sort((a, b) => b.occurrences - a.occurrences || a.ruleId.localeCompare(b.ruleId));
  return unoffered[0];
}

/**
 * Check Log Capture's crash mirror for a family covered by a disabled rule and,
 * if one is found that has not been offered, show the enable-rule toast once.
 * Tolerant of an absent/malformed mirror (no suggestions → no toast). Safe to call
 * on activation and on every `log-capture.json` change — the gate prevents repeats.
 */
export async function maybeNudgeCrashCoveredRule(
  context: vscode.ExtensionContext,
  root: string,
): Promise<void> {
  const disabled = readDisabledRules(root);
  const suggestions = findCrashCoveredDisabledRules(root, disabled);
  const pick = pickSuggestion(context, suggestions);
  if (!pick) return;

  // Set the offered flag before awaiting the toast so a rapid second change event
  // cannot race in and show the same suggestion twice.
  await context.globalState.update(offeredKey(pick.ruleId), true);

  const enableAction = l10n('suite.crashNudge.enable');
  const choice = await vscode.window.showInformationMessage(
    l10n('suite.crashNudge.message', {
      ruleId: pick.ruleId,
      count: String(pick.occurrences),
    }),
    enableAction,
  );
  if (choice === enableAction) {
    // The public deep-link command takes the documented `{ ruleId }` object form.
    void vscode.commands.executeCommand('saropaLints.enableRule', { ruleId: pick.ruleId });
  }
}
