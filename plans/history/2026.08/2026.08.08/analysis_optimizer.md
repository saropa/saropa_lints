# Analysis Optimizer

Large VS Code extension projects (e.g. `D:\src\contacts`, ~3,900 Dart files) push the Dart analysis server to 11+ GB RSS, causing crashes; the previously-shipped "balanced memory mode" (v14.5.1) turned out to reduce CPU work only, not RSS, since the analyzer resolves ASTs for every in-scope file before plugin callbacks run. This work adds an Analysis Optimizer dashboard that recommends `analyzer: exclude:` patterns — the only lever available from the extension side to shrink the analyzer's file scope and therefore its memory footprint.

## What changed

**New module — `extension/src/analysisOptimizer/`:**
- `types.ts` — `FileAnalysisMetrics`, `FolderAnalysisCost`, `ExclusionRecommendation`, `AnalysisOptimizerResult`.
- `scanner.ts` — walks workspace `.dart` files via `vscode.workspace.findFiles`, computes regex-based per-file metrics (line/class/function/import counts, widget/async detection, generated-file suffix detection), and derives per-file edit recency from a single `git log --since=<N days>` walk scoped to the last 30 days.
- `scorer.ts` — `computeFileCost` (line/class/function/import-weighted score with a widget multiplier), `aggregateByFolder` (groups by first two path segments, sorted by cost descending), `generateRecommendations` (default high-priority patterns for generated code and build artifacts, plus dynamic folder-based recommendations for folders that are mostly-generated or have no recent git activity; `lib/`, `lib/src/`, and `bin/` are never recommended).
- `analyzerExcludeYaml.ts` — hand-rolled reader/writer for the `analyzer: exclude:` block in `analysis_options.yaml` (mirrors the existing `rulePackYaml.ts` line-scanning approach, no YAML parser dependency). Supports both block-list and inline-array (`exclude: [a, b]`) syntax on read; writer preserves sibling `analyzer:` children (`language:`, `errors:`, etc.) and replaces only the `exclude:` span.
- `analysisOptimizerWebviewProvider.ts` — editor-column webview panel following the `RulePacksWebviewProvider` pattern: header, KPI strip (files in scope, estimated cost, potential savings), current-exclusions list with per-pattern remove, recommendations table with checkboxes and per-row apply, a folder cost heat-map bar chart, and a collapsible "how it works" explainer. Bulk apply (`applyAll`/`applySelected` with >1 pattern) requires a modal confirmation, matching the existing bulk-pack-enable confirmation in `rulePacksWebviewProvider.ts`.

**Three entry points:**
- Sidebar — new leaf row in the Editor Dashboards section (`sectionedSidebar.ts`), positioned before Package Dashboard.
- Critical-memory toast — `processMonitor.ts`'s `showCriticalNotification` gained an "Optimize Analysis" button alongside the existing "Clean Up" / "Don't Show Again".
- Command palette — `saropaLints.openAnalysisOptimizer`, registered in `extension.ts` and `package.json`/`package.nls.json`.

**Corrected a prior release claim:** the v14.5.1 CHANGELOG bullet for balanced memory mode claimed "~7 GB RSS reduction." That was never true — balanced mode skips plugin rule callbacks on unchanged files, which is CPU work; the analyzer resolves ASTs for the full in-scope file set before plugin callbacks run regardless. The bullet was corrected to describe CPU savings only.

## Review findings and fixes

A delegated code review (general-purpose agent, sonnet) surfaced four issues before this shipped, all fixed:

1. **Data-loss bug** — `parseAnalyzerExcludes` did not parse inline-array syntax (`exclude: [a, b]`), returning `[]` for projects using that style. Since `writeAnalyzerExcludes` merges against the parsed existing list, the first apply/remove action would silently drop the user's pre-existing exclusions. Fixed by adding inline-array parsing; the existing block-replacement writer logic already handled the inline case correctly once the reader was fixed.
2. **Accuracy bug** — `queryGitRecency` made two `git log` calls: a `--since`-scoped pass that floored every recently-touched file's recency at `0`, and a second *unscoped* full-history pass whose result could never override that floor (since `days < existing` can never beat `0`). Any file edited 1–30 days ago was reported as edited "today," and the second unscoped walk was pure wasted work on large repos (unbounded history walk with a 10 MB buffer). Fixed by dropping the first call and computing real day-deltas from a single `--since`-scoped walk.
3. **Design-consistency gap** — bulk exclusion apply had no confirmation, unlike the established pattern in `rulePacksWebviewProvider.ts` (`_confirmSdkBulkEnable`) for bulk config writes. Fixed by adding an equivalent modal confirmation (`_confirmBulkApply`) gated on `patterns.length > 1`.
4. **Zero test coverage** on the three new logic modules. Fixed by adding `scorer.test.ts` (10 cases), `analyzerExcludeYaml.test.ts` (13 cases, including regression tests for findings 1 and the inline-array round-trip), and `scanner.test.ts` (5 cases for the pure `computeFileMetrics` function). All 23 pure-logic tests pass via `tsc -p tsconfig.test.json && mocha`.

## Testing

- `npx tsc --noEmit` on the full extension — clean.
- `tsc -p tsconfig.test.json && mocha out-test/test/analysisOptimizer/{scorer,analyzerExcludeYaml}.test.js` — 23/23 passing.
- `scanner.test.js` cannot currently execute standalone in this local checkout: `scanner.ts` imports the real `vscode` module at runtime, and no `vscode` npm package is present in `node_modules` here. This is a pre-existing environment gap, not a regression — `rulePacksWebviewProvider.test.js` (unmodified, already in the suite) fails identically for the same reason when run in isolation. `computeFileMetrics`, the pure function scanner.test.ts targets, has no vscode dependency itself; the failure is purely a module-load side effect of the file's other top-level import.
- `overviewTreeFlat.test.ts` (sidebar assertions) re-run and confirmed unaffected — the relevant assertion (`Editor dashboards section surfaces the five expected dashboards`) uses `labels.includes(...)`, not an exact-count check, so the new sixth sidebar row does not break it.
- Both `tsconfig.test.json` and the `package.json` `test` script's hand-curated mocha file-glob list were extended to include the new module and test files — without this, `npm test` would silently skip the new suite.

## Hardening round (reflection gate)

After the initial implementation and finish handoff, the user selected all three reflection-gate options (harden, implement the unrequested feature, commit). Four pieces of follow-up work landed:

1. **Write-failure feedback** — `_applyExclusion`/`_removeExclusion`/`_applySelected` now call `showErrorMessage` when `writeAnalyzerExcludes` returns `false` (e.g. missing `analysis_options.yaml`), matching the established error-feedback pattern in `rulePacksWebviewProvider.ts`. Previously these failures were silent no-ops.
2. **Diff preview before applying (the brainstormed unrequested feature)** — new `analyzerExcludeDiffProvider.ts` registers a `vscode.TextDocumentContentProvider` under a `saropa-analyzer-exclude-preview` scheme and opens a `vscode.diff` between the on-disk `analysis_options.yaml` and the proposed post-write content before any write happens. `analyzerExcludeYaml.ts` gained `computeAnalyzerExcludesContent(root, patterns)`, a side-effect-free variant of the writer that returns `{before, after}` instead of touching disk. Wired into every apply path; single applies show the diff informationally, bulk applies show it before the existing confirmation modal.
3. **YAML indent-unit inference** — `replaceOrInsertExcludes` previously hardcoded 2-space/4-space output when inserting a new `exclude:` key. It now infers the indentation unit from the first existing child of `analyzer:` (falling back to 2-space only when `analyzer:` is new or has no other children), preventing a sibling-indent mismatch that most YAML parsers would reject.
4. **Client-script test coverage** — the inline webview script was extracted from `analysisOptimizerWebviewProvider.ts` into a pure module `analysisOptimizerScript.ts` (no `vscode` import), enabling a jsdom-based test (`analysisOptimizerScript.test.ts`, 9 cases) that executes the real script against a hand-built fixture DOM and asserts on the `postMessage` calls it produces for scan/apply/remove/select-all/apply-selected interactions — mirroring the project's established `feature-inventory-dom.test.ts` pattern for proving inline scripts actually work, not just that they parse.

A second delegated review of this round found no blocking issues; one low-severity TOCTOU was flagged (the diff preview and the later write each read `analysis_options.yaml` independently, so an external edit between the two could make the shown diff stale) and documented with a code comment rather than engineered around, since it only matters under concurrent external edits to a single-user local file.

## Testing (final)

- `npx tsc --noEmit` on the full extension — clean, after both rounds.
- `tsc -p tsconfig.test.json && mocha` on `scorer.test.js`, `analyzerExcludeYaml.test.js` (now 14 cases, +1 for indent-unit inference), `analysisOptimizerScript.test.js` (9 cases), and `overviewTreeFlat.test.js` — **44/44 passing**.
- `scanner.test.js` still cannot execute standalone in this local checkout (pre-existing `vscode`-module-resolution gap, unrelated to this work — see original Testing section above).
- `overviewTreeFlat.test.js` re-confirmed unaffected by the sidebar addition.

## Deferred

- **Translation catalog regeneration** (`py -3 extension/scripts/generate_translations.py`) was NOT run — the global HARD STOP on machine-translation pipelines requires explicit in-the-moment authorization for each run, and the user chose to skip it for this session. The 26 locale JSON files are now stale against the new `analysisOptimizer.*` namespace (~65 keys after the hardening round) and the `systemHealth.action.optimizeAnalysis` key. CI's publish coverage gate (`generate_locales.py --fail-on-missing`) will block a release until this is run.
- Balanced-memory-mode deploy/test on `D:\src\contacts` (restart analysis server, observe RSS on initial full pass vs. incremental edits) — carried over from the prior session's handover, not addressed this session; work stayed focused on the Analysis Optimizer per the user's redirection.
- Multi-root workspace handling was not added — `getProjectRoot()` is a shared single-root assumption used identically by every other dashboard in the extension (Lints Config, Package Dashboard, Findings Dashboard); diverging from that convention for one feature would be inconsistent rather than an improvement, so it was left as-is.
- The content-provider `_content` Map in `analyzerExcludeDiffProvider.ts` grows by one entry per apply action for the extension's lifetime (never evicted). Bounded by user click frequency and cleared on window reload; not fixed, noted as a future cheap cleanup if it ever matters.

## Finish Report (2026-08-08)

Implemented the Analysis Optimizer feature end-to-end across two rounds: initial implementation (5 new files, 8 modified files, 3 test files, 23 passing tests) followed by a user-directed hardening round (2 more new files, 4 additional fixes/features, 1 more test file, 44 passing tests total) in response to a request for a UI-surfaced tool to diagnose and mitigate the Dart analyzer's high RSS on large projects. Two rounds of delegated code review caught and fixed: a data-loss bug in YAML exclusion parsing (inline-array syntax silently dropped existing exclusions), a recency-calculation floor bug that made the "active files" warning inaccurate for anything edited more than a few hours ago, a missing bulk-confirmation dialog inconsistent with the existing rule-packs dashboard pattern, silent no-ops on write failure, a hardcoded YAML indent assumption that could corrupt non-2-space files, and zero test coverage on the webview's client-side script. Translation catalog regeneration was explicitly deferred at the user's direction and remains required before any publish.
