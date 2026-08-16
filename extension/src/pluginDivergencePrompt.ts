/**
 * Ask the user to reconcile the two Saropa Lints delivery states when they
 * disagree in a way nobody plausibly intended.
 *
 * There are two independent switches, and the sidebar now shows both:
 *   - `saropaLints.enabled` gates scan-on-save delivery (cheap, out-of-process);
 *   - the `plugins:` block in analysis_options.yaml gates the in-process
 *     analyzer plugin (live squiggles, several GB of resident memory).
 *
 * Making both visible fixed the lie, but it does nothing to help a user who
 * looks at the row and cannot tell which state they actually meant. This prompt
 * closes that gap for the two combinations that are NOT a legitimate default,
 * and stays silent for everything else — a nag on every activation would be a
 * worse defect than the drift it reports.
 */

import * as vscode from 'vscode';
import { getPluginsIntegrationState, wasPluginDisabledByExtension } from './setup';
import { l10n } from './i18n/runtime';

/** The only two divergences worth interrupting a user for. */
type Divergence = 'enabled-but-plugin-off' | 'disabled-but-plugin-on';

/**
 * Records which divergence the user has already answered for this root.
 *
 * Keyed by root and storing the divergence KIND rather than a bare boolean, so
 * dismissing "scan-on-save only, thanks" does not also silence the opposite
 * (and more expensive) "the multi-GB plugin is loading while you think lints
 * are off" case if the project later drifts the other way.
 */
function dismissedKey(root: string): string {
  return `saropaLints.divergencePromptDismissed:${root}`;
}

/**
 * Classify the two switches, returning undefined when the combination is
 * expected.
 *
 * Deliberately silent cases, each for a concrete reason:
 *  - `absent`: integration was never set up. The setup/init flow owns that
 *    conversation; a second prompt about it would be noise.
 *  - enabled + `disabled` WITHOUT an ownership claim: this is the shipped
 *    default for every brand-new project (`write_config` writes new files
 *    sentinel-wrapped because the in-process plugin costs several GB). Prompting
 *    here would interrupt every new user on first activation to ask about a
 *    state we chose for them on purpose. The ownership claim is what turns the
 *    same on-disk shape into real drift: it means OUR Disable took a live block
 *    away and the matching Enable never gave it back.
 *  - disabled + `disabled`, enabled + `live`: both switches agree.
 */
function classify(context: vscode.ExtensionContext, root: string): Divergence | undefined {
  const enabled = vscode.workspace.getConfiguration('saropaLints').get<boolean>('enabled', true) ?? true;
  const state = getPluginsIntegrationState(root);
  if (state === 'absent') return undefined;

  if (enabled && state === 'disabled') {
    return wasPluginDisabledByExtension(context, root) ? 'enabled-but-plugin-off' : undefined;
  }
  // Off + a live block is never a default we produce: Disable comments the
  // block out. It is reachable through a git checkout, a merge, or a manual
  // `dart run saropa_lints:init` — and it is the expensive direction, because
  // the plugin loads on the next analysis-server start while the UI says off.
  if (!enabled && state === 'live') return 'disabled-but-plugin-on';
  return undefined;
}

/** Message + action labels for one divergence, all routed through l10n. */
function promptFor(kind: Divergence): { message: string; reconcile: string; keep: string } {
  return kind === 'enabled-but-plugin-off'
    ? {
        message: l10n('notify.divergence.enabledButPluginOff'),
        reconcile: l10n('notify.divergence.actionRestorePlugin'),
        keep: l10n('notify.divergence.actionKeepScanOnly'),
      }
    : {
        message: l10n('notify.divergence.disabledButPluginOn'),
        reconcile: l10n('notify.divergence.actionTurnOffPlugin'),
        keep: l10n('notify.divergence.actionKeepPluginOn'),
      };
}

/**
 * Show the reconciliation prompt at most once per root per divergence kind.
 *
 * Exported for the caller in activate(); returns the divergence it surfaced (or
 * undefined) so tests can assert the classification without driving the UI.
 */
export async function surfacePluginDivergence(
  context: vscode.ExtensionContext,
  root: string,
): Promise<Divergence | undefined> {
  const kind = classify(context, root);
  if (!kind) return undefined;
  if (context.workspaceState.get<string>(dismissedKey(root)) === kind) return undefined;

  const { message, reconcile, keep } = promptFor(kind);
  const choice = await vscode.window.showInformationMessage(message, reconcile, keep);

  // Record BEFORE acting, and record on every outcome including a bare close.
  // A user who dismisses the notification without choosing has still answered
  // ("not now"), and re-asking on the next activation is precisely the nag this
  // is supposed to avoid. Reconciling clears the divergence anyway, so the
  // stored key simply never matches again in that direction.
  await context.workspaceState.update(dismissedKey(root), kind);

  if (choice === reconcile) {
    await vscode.commands.executeCommand(
      kind === 'enabled-but-plugin-off' ? 'saropaLints.reenablePlugin' : 'saropaLints.disable',
    );
  }
  return kind;
}
