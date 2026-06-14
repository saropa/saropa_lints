/**
 * Pure gate for the suite-awareness nudge (plan requirement R7). Decides whether
 * the "install Log Capture" suggestion should fire, given the project + extension
 * + once-flag state. Kept `vscode`-free so the AND-of-four-conditions rule — the
 * exact thing a regression would quietly break — is unit-testable; the toast shell
 * lives in `suiteAwarenessNudge.ts`.
 */

/** Inputs to the once-gated decision; all booleans so the rule reads as one line. */
export interface SuiteNudgeInputs {
  /** Project dev-depends (or depends) on saropa_drift_advisor. */
  hasDriftAdvisorDep: boolean;
  /** The Log Capture extension is already installed. */
  logCaptureInstalled: boolean;
  /** This workspace already saw the suggestion. */
  alreadySurfaced: boolean;
  /** The user turned proactive nudges off. */
  proactiveNudgesDisabled: boolean;
}

/**
 * Show the suggestion only when the pairing is present, the missing tool really is
 * missing, the user has not seen it before, and proactive nudges are on. Any one
 * false suppresses it — this is the whole gate, kept pure so a test pins it.
 */
export function shouldNudgeSuiteAwareness(inputs: SuiteNudgeInputs): boolean {
  return (
    inputs.hasDriftAdvisorDep &&
    !inputs.logCaptureInstalled &&
    !inputs.alreadySurfaced &&
    !inputs.proactiveNudgesDisabled
  );
}
