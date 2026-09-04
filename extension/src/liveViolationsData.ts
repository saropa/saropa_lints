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
  readViolations,
  type RuleMetadataData,
  type ViolationsData,
} from './violationsReader';
import { readDisabledRules } from './configWriter';
import { getRuleCatalog } from './ruleCatalog';
import { computeHealthScore, type HealthScoreResult } from './healthScore';

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

/**
 * Health score for live-sourced `ViolationsData`, borrowing only the file-count
 * denominator from the cached `violations.json` export (when one exists).
 *
 * Why this exists. `computeHealthScore`'s density formula divides by
 * `summary.filesAnalyzed` — a real "how many .dart files did the scan cover"
 * count that only a full `dart run` export produces. Live diagnostics
 * (`vscode.languages.getDiagnostics()`) have no equivalent: a clean file with
 * zero diagnostics never appears in the diagnostics map, so there is no way to
 * count "files analyzed" from the live source alone. Fabricating a denominator
 * would silently misgrade the project; always withholding the score once a
 * live source is in play would be a real feature regression versus the
 * cached-report era (the Health row would vanish for every project, not just
 * partial-coverage ones). This borrows `filesAnalyzed`/`filesExpected` from
 * the last export while using LIVE severity counts as the numerator: the
 * score can never lag behind the Problems panel the way a fully
 * cached-report-sourced score could, and the coverage caveat (null on a tiny
 * partial sweep, null when no export has ever run) is unchanged.
 */
export function computeLiveHealthScore(
  root: string,
  liveData: ViolationsData,
): HealthScoreResult | null {
  const cachedSummary = readViolations(root)?.summary;
  if (!cachedSummary?.filesAnalyzed) return null;
  return computeHealthScore({
    ...liveData,
    summary: {
      ...liveData.summary,
      filesAnalyzed: cachedSummary.filesAnalyzed,
      filesExpected: cachedSummary.filesExpected,
    },
  });
}
