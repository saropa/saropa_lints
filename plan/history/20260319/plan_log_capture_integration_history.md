# Completed: Log Capture integration (extension API + consumer manifest)

**Plan:** [plan_log_capture_integration.md](plan_log_capture_integration.md)  
**Completed:** 2026-03-19

## Summary

Saropa Lints side of the optional Log Capture integration is fully implemented: extension public API and Dart consumer manifest. All additive; no breaking changes.

1. **Extension public API** — `activate()` returns a `SaropaLintsApi` object. Other extensions use `vscode.extensions.getExtension('saropa.saropa-lints')?.exports` to call: `getViolationsData()`, `getViolationsPath()`, `getHealthScoreParams()`, `runAnalysis()`, `runAnalysisForFiles(files)`, `getVersion()`. Interface in `api.ts`; implementation in `extension.ts`. No `package.json` "api" key (VS Code uses activate return value). Health score constants exported from `healthScore.ts`; comment references Dart `health_score_constants.dart` for sync.

2. **runAnalysisForFiles** — In `setup.ts`: normalizes paths (relative→absolute, dedupe, sort, cap 50), uses same dart/flutter and `runInWorkspace` as `runAnalysis`. Optional `showProgress` (default false for API callers). Logs to report writer; no progress UI when invoked via API unless requested.

3. **Consumer manifest** — After every `ViolationExporter.write`, `reports/.saropa_lints/consumer_contract.json` is written with: `schemaVersion`, `healthScore` (impactWeights, decayRate), and `tierRuleSets` (rule names per tier: essential, recommended, professional, comprehensive, pedantic, stylistic). Single source for health score: `lib/src/report/health_score_constants.dart`; `_writeAtomicFile` shared for violations.json and consumer_contract.json.

4. **Docs** — VIOLATION_EXPORT_API.md: "Consumer manifest" section (location, when written, schema, tierRuleSets, example). Extension README: "API for other extensions" (usage snippet, method table, link to VIOLATION_EXPORT_API). CHANGELOG: Extension and Package entries under [Unreleased].

**Files changed:**  
Extension: `api.ts` (new), `extension.ts`, `healthScore.ts`, `setup.ts`, `README.md`.  
Package: `health_score_constants.dart` (new), `violation_export.dart`, `test/violation_export_test.dart`.  
Docs: `VIOLATION_EXPORT_API.md`, `CHANGELOG.md`.

---

## Review (for AI reviewer)

- **Logic:** API delegates to existing readers/setup; consumer contract built from constants and tiers; no branching errors. runAnalysisForFiles: empty files or no root → false; paths sorted before cap for deterministic behavior.
- **Race conditions:** None; single-threaded. Export and manifest writes are sequential in same process.
- **Modularity:** API surface in `api.ts`; setup helpers reused; `_writeAtomicFile` shared; tierRuleSets built in one place.
- **Duplication:** Path/cmd logic in runAnalysis and runAnalysisForFiles is duplicated but small; extracting would add indirection for little gain.
- **Performance:** tierRuleSets: 6 × getRulesForTier (set ops), done once per export. runAnalysisForFiles cap 50 avoids CLI length issues. No recursion.
- **User messages:** API is programmatic; runAnalysisForFiles shows no UI by default. Existing runAnalysis messages unchanged.
- **Comments:** api.ts and healthScore.ts reference plan/sync; violation_export _writeAtomicFile doc updated; setup runAnalysisForFiles JSDoc describes cap and progress.
- **Tests:** violation_export_test.dart asserts consumer_contract.json exists with schemaVersion, healthScore (weights, decayRate), tierRuleSets (all six tiers, non-empty lists). Extension has no new unit test (would require full VS Code env); Dart tests cover manifest.
- **Framework:** Follows existing extension and Dart patterns; no new animations/transitions (API and file I/O only). Progress handled by existing withProgress when showProgress true.
