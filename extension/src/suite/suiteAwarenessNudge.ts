/**
 * Suite-awareness nudge (plan requirement R7). A project that already dev-depends
 * on `saropa_drift_advisor` is the recommended pairing for the suite, but its
 * developer may not know the third tool exists. When that dependency is present
 * and the Log Capture extension is not installed, this surfaces ONE toast
 * suggesting it, so a static Drift finding can be correlated with live runtime SQL.
 *
 * Once-gated, like the rule-pack startup nudge: a per-workspace flag records that
 * the suggestion was shown, so re-opening the project never re-nags. It also
 * honors the existing proactive-nudge opt-out and stays silent when Log Capture is
 * already installed (never suggest installing what the user already has).
 *
 * The decision is split into a pure predicate ({@link shouldNudgeSuiteAwareness})
 * so the gating logic is unit-testable without VS Code; the toast itself is the
 * thin impure shell.
 */

import * as vscode from 'vscode';
import { l10n } from '../i18n/runtime';
import { getProjectRoot } from '../projectRoot';
import { hasPubspecDependency } from '../pubspecReader';
import { LOG_CAPTURE_EXTENSION_ID } from './siblingDeepLinkTargets';
import { shouldNudgeSuiteAwareness, type SuiteNudgeInputs } from './suiteAwarenessGate';

/** The dependency whose presence marks a project as a suite-pairing candidate. */
const DRIFT_ADVISOR_PACKAGE = 'saropa_drift_advisor';

/** Per-workspace flag: the suite-awareness toast was already shown here. */
const SURFACED_KEY = 'saropaLints.suiteAwareness.surfaced';

/**
 * Evaluate the gate against live state and, if it passes, show the once-only
 * toast. Safe to call on activation; records the surfaced flag up front so
 * dismissing (or ignoring) the toast never re-prompts.
 */
export async function maybeNudgeSuiteAwareness(context: vscode.ExtensionContext): Promise<void> {
  const root = getProjectRoot();
  if (!root) return;

  const inputs: SuiteNudgeInputs = {
    hasDriftAdvisorDep: hasPubspecDependency(root, DRIFT_ADVISOR_PACKAGE),
    logCaptureInstalled: vscode.extensions.getExtension(LOG_CAPTURE_EXTENSION_ID) !== undefined,
    alreadySurfaced: context.workspaceState.get<boolean>(SURFACED_KEY, false),
    // Reuse the single proactive-nudge opt-out so "stop nudging me" covers this too.
    proactiveNudgesDisabled:
      vscode.workspace.getConfiguration('saropaLints').get<boolean>('upgradePackNudge.enabled') === false,
  };
  if (!shouldNudgeSuiteAwareness(inputs)) return;

  // Record before showing so an immediate re-activation cannot double-prompt.
  await context.workspaceState.update(SURFACED_KEY, true);

  const install = l10n('suite.nudge.install');
  const choice = await vscode.window.showInformationMessage(
    l10n('suite.nudge.message'),
    install,
    l10n('suite.nudge.dismiss'),
  );
  if (choice === install) {
    // Open the Extensions view filtered to Log Capture so the user can install it
    // in one step rather than searching the marketplace by hand.
    void vscode.commands.executeCommand('workbench.extensions.search', LOG_CAPTURE_EXTENSION_ID);
  }
}
