/**
 * Pure core of the reciprocal deep-links OUT of a Lints finding (plan requirement
 * R5). Decides WHICH sibling jump to offer for a set of finding rule ids; the
 * `vscode` provider in `siblingDeepLinks.ts` turns these targets into editor code
 * actions. Kept `vscode`-free (only `l10n`, which is dependency-free) so the
 * decision is unit-testable.
 *
 * Why so few targets: a static Lints finding carries a file, a line, and a rule —
 * not a table name, a normalized SQL string, or a crash fingerprint. The sibling
 * commands that need those would be called with guessed args, opening the wrong
 * table/query, so they are deliberately omitted. The one command callable
 * correctly from a static finding is `driftViewer.openIssues { category: "drift" }`.
 */

import { l10n } from '../i18n/runtime';

/** Marketplace id of the Drift Advisor extension (canonical: Advisor plan §3). */
export const ADVISOR_EXTENSION_ID = 'saropa.drift-viewer';
/** Marketplace id of the Log Capture extension (sibling repo `saropa/saropa-log-capture`). */
export const LOG_CAPTURE_EXTENSION_ID = 'saropa.saropa-log-capture';

/** A reciprocal deep-link target: a localized title plus a sibling command + args. */
export interface DeepLinkTarget {
  title: string;
  command: string;
  args: unknown[];
}

/** Predicate for "is this extension installed?" — injectable so tests need no VS Code. */
export type IsInstalledFn = (extensionId: string) => boolean;

/**
 * A Drift Lints rule? Matches the id-based test `envelope.deriveCategory` uses for
 * the `drift` category, so the editor lightbulb and the dashboard badge agree on
 * what counts as a Drift finding. Pure string check — no catalog needed.
 */
export function isDriftRuleId(ruleId: string): boolean {
  return ruleId.includes('drift');
}

/**
 * Build the reciprocal deep-link targets for a set of finding rule ids. Returns at
 * most one target (the Advisor runtime-issues jump), and only when some finding is
 * a Drift rule AND the Advisor extension is installed — so a dead action never
 * appears for a tool the user does not have.
 */
export function suiteDeepLinkTargets(
  ruleIds: readonly string[],
  isInstalled: IsInstalledFn,
): DeepLinkTarget[] {
  const hasDriftFinding = ruleIds.some(isDriftRuleId);
  if (!hasDriftFinding || !isInstalled(ADVISOR_EXTENSION_ID)) return [];
  return [
    {
      title: l10n('suite.deepLink.showDriftIssues'),
      command: 'driftViewer.openIssues',
      args: [{ category: 'drift' }],
    },
  ];
}
