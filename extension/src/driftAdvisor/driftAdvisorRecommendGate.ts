/**
 * Pure gate for the "install the standalone Saropa Drift Advisor extension"
 * recommendation toast. The standalone extension owns the richer Problems-panel
 * experience; when a Drift Advisor server is connected but the extension is not
 * installed, this surfaces ONE toast suggesting it.
 *
 * Kept `vscode`-free so the four-way AND rule is unit-testable; the impure shell
 * that reads live extension/server/flag state lives in
 * `driftAdvisorRecommendNudge.ts` (same split as `suiteAwarenessGate` vs
 * `suiteAwarenessNudge`).
 */

/** Inputs to the once-gated decision; all booleans so the rule reads as one line. */
export interface DriftRecommendInputs {
  /** The standalone Saropa Drift Advisor extension is already installed. */
  standaloneInstalled: boolean;
  /** A Drift Advisor server is currently connected (issues are being fetched). */
  serverConnected: boolean;
  /** This workspace already saw the recommendation. */
  alreadySurfaced: boolean;
  /** The user turned proactive nudges off. */
  proactiveNudgesDisabled: boolean;
}

/**
 * Recommend the standalone extension only when it is missing, a server really is
 * connected (so the recommendation is relevant right now), the suggestion has not
 * been shown here before, and proactive nudges are on. Any one false suppresses it —
 * this is the whole gate, kept pure so a test pins it.
 */
export function shouldRecommendDriftAdvisor(inputs: DriftRecommendInputs): boolean {
  return (
    !inputs.standaloneInstalled &&
    inputs.serverConnected &&
    !inputs.alreadySurfaced &&
    !inputs.proactiveNudgesDisabled
  );
}
