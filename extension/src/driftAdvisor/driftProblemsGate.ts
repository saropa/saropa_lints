/**
 * Pure gate for the Drift Advisor Problems-panel publish. Decides whether the Lints
 * integration should publish its anomaly / index-suggestion diagnostics, given
 * whether the standalone Saropa Drift Advisor extension is active and whether the
 * user left the `showInProblems` setting on.
 *
 * Kept `vscode`-free so the suppression rule — the exact thing a regression would
 * quietly break, re-introducing duplicate squiggles — is unit-testable; the impure
 * shell that reads the live extension/config state lives in `driftAdvisorTree.ts`
 * (same split as `suiteAwarenessGate` vs `suiteAwarenessNudge`).
 */

/** Inputs to the publish decision; both booleans so the rule reads as one line. */
export interface DriftProblemsGateInputs {
  /**
   * The standalone Saropa Drift Advisor extension (saropa.drift-viewer) is
   * installed AND active. When active it owns the Problems panel and publishes the
   * same issues, so our copy would duplicate every squiggle.
   */
  standaloneActive: boolean;
  /** The user left `saropaLints.driftAdvisor.showInProblems` on (defaults true). */
  showInProblems: boolean;
}

/**
 * Publish only when the standalone extension is NOT the active owner of these
 * diagnostics and the user has not opted out. Either condition failing suppresses
 * the publish: standalone-active avoids the duplicate, showInProblems-off honors
 * the opt-out. This is the whole gate, kept pure so a test pins it.
 */
export function shouldPublishDriftProblems(inputs: DriftProblemsGateInputs): boolean {
  return !inputs.standaloneActive && inputs.showInProblems;
}
