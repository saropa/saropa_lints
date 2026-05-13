/**
 * Counts non-saropa analyzer diagnostics surfaced in the VS Code Problems panel.
 *
 * The Findings Dashboard reports only saropa_lints custom-rule violations; users
 * comparing it to the Problems panel see a gap composed of built-in Dart SDK
 * lints (and any third-party `custom_lint` plugins, e.g. riverpod_lint) plus
 * analyzer-side `todo` diagnostics. This module reads live diagnostics from
 * `vscode.languages.getDiagnostics()` and subtracts saropa's known count so the
 * dashboard can surface the residual as supplementary context — without ever
 * touching the health score, KPI filters, or the violations list itself.
 *
 * Why subtraction (not a positive allowlist): saropa rules flow through the
 * Dart analyzer plugin and surface in VS Code with `source === "dart"`, the
 * same `source` used by built-in lints and other `custom_lint` plugins. There
 * is no public diagnostic field that distinguishes saropa rules from SDK
 * lints at the VS Code API level, so subtraction is the only viable strategy.
 * Premise violation (a saropa rule reporting under a different source) would
 * surface as inflated supplementary counts — clamped to >= 0 by `Math.max`.
 */

import * as vscode from 'vscode';

/** Live counts of analyzer diagnostics that are NOT saropa custom-rule violations. */
export interface SupplementaryDiagnosticCounts {
  /**
   * Non-TODO analyzer diagnostics on `.dart` files after subtracting saropa's
   * own count. Includes built-in SDK lints AND third-party `custom_lint`
   * plugins (riverpod_lint, etc.); the label on the dashboard must be honest
   * about this — never call this bucket "Dart SDK lints" alone.
   */
  otherAnalyzerCount: number;
  /**
   * Analyzer-side TODO diagnostics on `.dart` files (`code === "todo"`).
   * Counted independently of `otherAnalyzerCount` so the dashboard can offer
   * separate toggles. Distinct from the file-system `todosAndHacksScanner`,
   * which the dashboard surfaces via its own pill.
   */
  analyzerTodosCount: number;
  /**
   * Whether the workspace has any `.dart` files visible to VS Code. Drives
   * whether the scanner-promo pill is worth rendering — promoting a TODO
   * scanner in a workspace with no Dart code is just noise.
   */
  hasDartFiles: boolean;
}

/**
 * Injectable signature for `vscode.languages.getDiagnostics()`. Tests pass a
 * stub; production callers omit the argument and the function uses the live
 * VS Code API.
 */
export type GetDiagnosticsFn = () => [vscode.Uri, readonly vscode.Diagnostic[]][];

/**
 * Returns `true` when `code` represents a `todo` diagnostic.
 *
 * VS Code's `Diagnostic.code` is `string | number | { value; target } |
 * undefined` — the built-in Dart `todo` lint reports it as a string `"todo"`,
 * but custom_lint and some plugins wrap codes in the link-target object form.
 * Handle both shapes so the count is accurate regardless of how the plugin
 * happened to construct the diagnostic.
 */
function isTodoCode(code: vscode.Diagnostic['code']): boolean {
  if (typeof code === 'string') return code === 'todo';
  if (typeof code === 'number') return false;
  if (code && typeof code === 'object' && 'value' in code) {
    const value = code.value;
    return typeof value === 'string' && value === 'todo';
  }
  return false;
}

/**
 * Count analyzer diagnostics from `.dart` files that are not saropa
 * violations, split into TODO and non-TODO buckets.
 *
 * @param saropaViolationCount Saropa's own `totalAfterDisable` count — what's
 *   currently shown in the Findings Dashboard. Used as the subtrahend so the
 *   supplementary line only surfaces the *gap*. Clamped at 0 if the live
 *   diagnostic buffer hasn't caught up to a fresh `violations.json` yet.
 * @param getDiagnostics Optional override for testing — defaults to the live
 *   VS Code API call. The function reads VS Code's already-computed
 *   diagnostic state so the call is cheap; no analysis is triggered here.
 */
export function countSupplementaryDiagnostics(
  saropaViolationCount: number,
  getDiagnostics: GetDiagnosticsFn = () => vscode.languages.getDiagnostics(),
): SupplementaryDiagnosticCounts {
  let totalDart = 0;
  let analyzerTodosCount = 0;
  let hasDartFiles = false;

  for (const [uri, diagnostics] of getDiagnostics()) {
    // `.dart` files only — saropa never reports against non-Dart files, and a
    // user's project may include diagnostics from other languages we shouldn't
    // attribute to the analyzer bucket.
    if (!uri.path.endsWith('.dart')) continue;
    hasDartFiles = true;

    for (const d of diagnostics) {
      // `source === "dart"` covers built-in Dart lints, analyzer todos, and
      // any analyzer-plugin contributions (saropa, riverpod_lint, etc.).
      // Excludes saropa's other VS Code extensions (Package Vibrancy, Drift
      // Advisor) which set their own source strings.
      if (d.source !== 'dart') continue;
      totalDart++;
      if (isTodoCode(d.code)) analyzerTodosCount++;
    }
  }

  // Subtract saropa AND analyzer-todo counts to avoid double-counting: saropa
  // never produces `code === "todo"` diagnostics, so the TODO bucket is purely
  // additive to the saropa total.
  const nonTodoDart = totalDart - analyzerTodosCount;
  const otherAnalyzerCount = Math.max(0, nonTodoDart - saropaViolationCount);

  return {
    otherAnalyzerCount,
    analyzerTodosCount,
    hasDartFiles,
  };
}
