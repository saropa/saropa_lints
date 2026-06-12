/**
 * Live-sourced `ViolationsData` for the status-bar score and the Issues tree.
 *
 * Why this exists. Those two surfaces read the batch `reports/.saropa_lints/
 * violations.json` export, which is only written by an explicit (expensive)
 * analysis run. Between runs the file goes stale, so the status bar could show
 * "grade A / 0 findings" while the Problems panel showed dozens of live ones —
 * the same diagnostics, two sources, free to diverge. The Findings (wide) report
 * already reads live diagnostics via {@link buildViolationsDataFromDiagnostics};
 * routing the status bar + Issues tree through the SAME source makes all three
 * structurally identical — they cannot disagree — and costs zero analysis (the
 * Dart Analysis Server already produced these diagnostics for the Problems
 * panel; this only reads the result).
 *
 * Holistic, like the wide report. Every analyzer diagnostic on a `.dart` file is
 * included regardless of producer (saropa_lints, SDK lints, riverpod_lint, …),
 * because VS Code exposes no field identifying the source plugin and the
 * Problems-panel-aligned view is the point. This is a deliberate widening from
 * the saropa-only JSON export, consistent with the already-shipped wide report.
 *
 * Injectable for tests. `getDiagnostics`, `tier`, and `disabled` are optional
 * parameters; production callers omit them (live VS Code API + workspace config
 * + on-disk disabled set), unit tests pass deterministic stubs so neither the
 * `vscode` config API nor the filesystem is touched.
 */

import * as vscode from 'vscode';
import {
  applyRuleCatalog,
  buildViolationsDataFromDiagnostics,
  type GetDiagnosticsFn,
} from './liveDiagnosticsModel';
import {
  filterDisabledFromData,
  type RuleMetadataData,
  type ViolationsData,
} from './violationsReader';
import { readDisabledRules } from './configWriter';
import { getRuleCatalog } from './ruleCatalog';

/**
 * Resolve the user's configured tier without reading a stale file. Only called
 * when the caller did not inject a tier (i.e. in production); kept in one place
 * so the default ('recommended') matches every other live-config read.
 */
function resolveTier(): string | undefined {
  return vscode.workspace.getConfiguration('saropaLints').get<string>('tier');
}

/**
 * Raw live findings (no disabled-rule filtering). The Issues tree consumes this:
 * it does its own disabled / text / suppression filtering downstream, so it must
 * receive the unfiltered set. Always returns data (never null) — live diagnostics
 * are always current, and an empty result means "clean", not "no report yet".
 */
export function readLiveViolations(
  root: string,
  getDiagnostics?: GetDiagnosticsFn,
  tier: string | undefined = resolveTier(),
  catalog: Record<string, RuleMetadataData> = getRuleCatalog(),
): ViolationsData {
  // Enrich the bare diagnostic model with per-rule metadata so the Issues-panel
  // rule-type/status filters and security-hotspot review work off the live
  // source. The catalog defaults to the bundled one; tests inject a stub.
  return applyRuleCatalog(
    buildViolationsDataFromDiagnostics(root, getDiagnostics, tier),
    catalog,
  );
}

/**
 * Live findings with disabled rules removed and summary counts recomputed — the
 * shape the status-bar score wants (a disabled rule should not drag the grade).
 * Mirrors the former `readVisibleViolations` (file read + `filterDisabledFromData`)
 * but sourced from live diagnostics.
 */
export function readVisibleLiveViolations(
  root: string,
  getDiagnostics?: GetDiagnosticsFn,
  tier?: string,
  disabled: Set<string> = readDisabledRules(root),
): ViolationsData {
  return filterDisabledFromData(readLiveViolations(root, getDiagnostics, tier), disabled);
}

/**
 * Drop-in for `hasViolations(root)` against the live source — gates the Issues
 * tree's empty state. Counts the raw (unfiltered) set to match the tree, which
 * renders disabled-rule findings under its own filter toggles.
 */
export function hasLiveViolations(
  root: string,
  getDiagnostics?: GetDiagnosticsFn,
): boolean {
  const data = readLiveViolations(root, getDiagnostics);
  return (data.summary?.totalViolations ?? data.violations.length) > 0;
}
