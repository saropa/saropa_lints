/**
 * Builds the Findings Dashboard's `ViolationsData` model from LIVE VS Code
 * diagnostics (`vscode.languages.getDiagnostics()`) instead of the batch
 * `reports/.saropa_lints/violations.json` export.
 *
 * Why this exists. The dashboard previously read the JSON file, which is only
 * written by an explicit (and expensive) analysis run. Between runs the file
 * goes stale, so the dashboard could show "0 findings / grade A" while the
 * Problems panel showed dozens of live findings — the same diagnostics, two
 * sources, free to diverge. Reading the exact array the Problems panel reads
 * makes the two structurally identical: they cannot disagree. It also costs
 * zero analysis — the Dart Analysis Server already produced these diagnostics
 * for the Problems panel; this only reads the result, it never triggers a run.
 *
 * Holistic by design. Every analyzer diagnostic on a `.dart` file becomes a
 * Violation regardless of which linter produced it (saropa_lints, built-in SDK
 * lints, riverpod_lint, …). VS Code exposes no field that identifies the source
 * plugin — all custom_lint and SDK lints report `source === "dart"` — and a
 * combined view is more useful than a saropa-only one anyway.
 *
 * Phase #1a. Findings, severity, file, line, and rule come straight from the
 * Diagnostic. Per-rule enrichment (correctionMessage, OWASP, tier-aware
 * metadata) is phase #1b, sourced from a bundled rule catalog — absent here,
 * exactly the way a legacy export without those fields is already tolerated
 * downstream by the dashboard renderer.
 */

import * as path from 'path';
import * as vscode from 'vscode';
import type {
  BySeverity,
  IssuesByRule,
  Violation,
  ViolationsData,
} from './violationsReader';

/**
 * Injectable signature for `vscode.languages.getDiagnostics()`. Production
 * callers use the default; unit tests pass a deterministic stub.
 */
export type GetDiagnosticsFn = () => [vscode.Uri, readonly vscode.Diagnostic[]][];

type SeverityBucket = 'error' | 'warning' | 'info';

/**
 * Map a VS Code `DiagnosticSeverity` onto the dashboard's 3-bucket vocabulary.
 * Information and Hint both collapse to `info` — the severity filter and KPI
 * cards only know error/warning/info (the post-2026-05-03 collapse).
 */
function severityToBucket(severity: vscode.DiagnosticSeverity): SeverityBucket {
  switch (severity) {
    case vscode.DiagnosticSeverity.Error:
      return 'error';
    case vscode.DiagnosticSeverity.Warning:
      return 'warning';
    default:
      return 'info';
  }
}

/**
 * Extract a stable rule name from `Diagnostic.code`, which VS Code types as
 * `string | number | { value; target } | undefined`. custom_lint wraps codes in
 * the link-target object form to attach a help link; SDK lints use a bare
 * string. Fall back to the diagnostic `source` (then a constant) so a code-less
 * diagnostic still groups somewhere instead of vanishing from the holistic view.
 */
function ruleFromCode(diag: vscode.Diagnostic): string {
  const code = diag.code;
  if (typeof code === 'string') return code;
  if (typeof code === 'number') return String(code);
  if (code && typeof code === 'object' && 'value' in code) {
    return String(code.value);
  }
  return diag.source ?? 'unknown';
}

/**
 * Strip the leading `[rule_name] ` prefix saropa rules prepend to every message
 * (a hard project invariant) so the rendered text matches the JSON-export shape,
 * which carries the bare message. Messages without the prefix (SDK lints, other
 * plugins) are left untouched.
 */
function stripRulePrefix(message: string): string {
  return message.replace(/^\[[^\]]*\]\s*/, '');
}

/**
 * Produce the dashboard model from the live diagnostic stream.
 *
 * `getDiagnostics` is injectable so unit tests can pass a deterministic stub;
 * production callers omit it and read the live VS Code API. `tier` is the user's
 * configured tier (a live setting, never a stale file) — passed through so the
 * status pill stays accurate without reading `violations.json`.
 */
export function buildViolationsDataFromDiagnostics(
  root: string,
  getDiagnostics: GetDiagnosticsFn = () => vscode.languages.getDiagnostics(),
  tier?: string,
): ViolationsData {
  const violations: Violation[] = [];

  for (const [uri, diagnostics] of getDiagnostics()) {
    // Dashboard scope is Dart source — the lint rules target Dart and the JSON
    // export was Dart-only. Skip diagnostics on non-Dart files (pubspec,
    // markdown, the extension's own TS) so the holistic view stays on topic.
    if (!uri.fsPath.endsWith('.dart')) continue;

    // Root-relative, forward-slashed: matches the format
    // `saropaLints.openFileAndFocusIssues` resolves via `path.resolve(root, …)`
    // and the Issues tree produces via `path.relative(root, …)`. A mismatch
    // here silently breaks click-to-source navigation.
    const file = path.relative(root, uri.fsPath).replaceAll('\\', '/');

    for (const diag of diagnostics) {
      const bucket = severityToBucket(diag.severity);
      violations.push({
        file,
        line: diag.range.start.line + 1,
        rule: ruleFromCode(diag),
        message: stripRulePrefix(diag.message),
        severity: bucket,
        // 3-bucket impact mirrors severity post-collapse, so impact == severity
        // for live findings (there is no richer impact field on a Diagnostic).
        impact: bucket,
      });
    }
  }

  const bySeverity: BySeverity = {};
  const issuesByRule: IssuesByRule = {};
  const filesWithIssues = new Set<string>();
  for (const v of violations) {
    const sev = (v.severity ?? 'info') as keyof BySeverity;
    bySeverity[sev] = (bySeverity[sev] ?? 0) + 1;
    issuesByRule[v.rule] = (issuesByRule[v.rule] ?? 0) + 1;
    filesWithIssues.add(v.file);
  }

  return {
    // Live read — the model reflects the analyzer's current state, so the
    // freshness pill always reads "just now" rather than a stale export time.
    timestamp: new Date().toISOString(),
    violations,
    summary: {
      totalViolations: violations.length,
      filesWithIssues: filesWithIssues.size,
      bySeverity,
      // 3-bucket impact mirrors severity (see per-violation note above).
      byImpact: { ...bySeverity },
      issuesByRule,
    },
    // enabledRuleCount and rich per-rule metadata are phase #1b (bundled
    // catalog). tier comes from the live setting, not a stale file.
    config: tier ? { tier } : undefined,
  };
}
