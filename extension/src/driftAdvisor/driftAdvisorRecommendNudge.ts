/**
 * One-time recommendation toast for the standalone Saropa Drift Advisor extension
 * (`saropa.drift-viewer`). The standalone extension is the canonical owner of the
 * Drift Problems-panel diagnostics and has the richer experience; when a Drift
 * Advisor server is connected through the Lints integration but the standalone
 * extension is not installed, this suggests installing it.
 *
 * Once-gated, like the suite-awareness nudge: a per-workspace flag records that the
 * suggestion was shown, so re-connecting never re-nags. It honors the same
 * proactive-nudge opt-out and stays silent when the standalone extension is already
 * installed (never suggest installing what the user already has).
 *
 * The decision is the pure {@link shouldRecommendDriftAdvisor} predicate; this is
 * the thin impure shell that reads live state and shows the toast.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { ADVISOR_EXTENSION_ID } from '../suite/siblingDeepLinkTargets';
import { shouldRecommendDriftAdvisor, type DriftRecommendInputs } from './driftAdvisorRecommendGate';

/** Per-workspace flag: the standalone-extension recommendation was already shown here. */
const SURFACED_KEY = 'saropaLints.driftAdvisorRecommend.surfaced';

/**
 * Evaluate the gate against live state and, if it passes, show the once-only toast.
 * Safe to call whenever a server connects; records the surfaced flag up front so
 * dismissing (or ignoring) the toast never re-prompts.
 */
export async function maybeRecommendDriftAdvisor(
  context: vscode.ExtensionContext,
  serverConnected: boolean,
): Promise<void> {
  const inputs: DriftRecommendInputs = {
    standaloneInstalled: vscode.extensions.getExtension(ADVISOR_EXTENSION_ID) !== undefined,
    serverConnected,
    alreadySurfaced: context.workspaceState.get<boolean>(SURFACED_KEY, false),
    // Reuse the single proactive-nudge opt-out so "stop nudging me" covers this too.
    proactiveNudgesDisabled:
      vscode.workspace.getConfiguration('saropaLints').get<boolean>('upgradePackNudge.enabled') === false,
  };
  if (!shouldRecommendDriftAdvisor(inputs)) return;

  // Record before showing so an immediate re-connection cannot double-prompt.
  await context.workspaceState.update(SURFACED_KEY, true);

  const install = l10n('suite.driftRecommend.install');
  const choice = await vscode.window.showInformationMessage(
    l10n('suite.driftRecommend.message'),
    install,
    l10n('suite.driftRecommend.dismiss'),
  );
  if (choice === install) {
    // Open the Extensions view filtered to the Drift Advisor extension so the user
    // can install it in one step rather than searching the marketplace by hand.
    void vscode.commands.executeCommand('workbench.extensions.search', ADVISOR_EXTENSION_ID);
  }
}
