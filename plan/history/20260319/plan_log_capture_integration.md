# Plan: Saropa Lints implementation for Log Capture integration

**Status:** Implemented 2026-03-19 — see [plan_log_capture_integration_history.md](plan_log_capture_integration_history.md)  
**Last updated:** 2026-03-19  
**Consumer:** [Saropa Log Capture](https://github.com/saropa/saropa-log-capture); integration design and full plan: `docs/SAROPA_LINTS_INTEGRATION.md` in that repo.

## Summary

Implement the **saropa_lints side** of the optional tighter integration with Saropa Log Capture:

1. **Extension:** Expose a **public API** from `activate()` so other extensions (Log Capture first) can get violations data, health score parameters, run analysis, and run analysis on specific files without reading `violations.json` from disk. No breaking changes; the file contract `reports/.saropa_lints/violations.json` remains the primary contract.

2. **Dart package (optional phase):** Write a **consumer manifest** (`reports/.saropa_lints/consumer_contract.json`) alongside the violation export so any consumer (including Log Capture when the extension is not installed) can read health score constants and schema version from a single place. Document the manifest in VIOLATION_EXPORT_API.md.

All work is **additive and optional**: Log Capture continues to work with only the file contract; when the API and/or manifest are present, the integration becomes tighter.

---

## 1. Scope: in and out

### 1.1 In scope (this plan)

| Area | Deliverable |
|------|-------------|
| **Extension** | Public API type and implementation: `getViolationsData`, `getViolationsPath`, `getHealthScoreParams`, `runAnalysis`, `getVersion`. |
| **Extension** | `package.json` change to expose the API so other extensions can `getExtension('saropa.saropa-lints')` and use `exports`. |
| **Extension** | `runAnalysisForFiles(files: string[])`: run `dart analyze` (or `flutter analyze`) with a list of file paths so stack-trace files can be refreshed without full-project analysis. |
| **Dart package** | Write `consumer_contract.json` after each violation export (schemaVersion, healthScore.impactWeights, healthScore.decayRate). Optional: tierRuleSets or essentialRuleNames for future tier-based filtering. |
| **Dart package** | Single source for health score constants (Dart or sync with extension); extension and manifest stay in sync. |
| **Docs** | VIOLATION_EXPORT_API.md: consumer_contract.json schema, when it is written, and field semantics. |
| **Docs** | Extension README: "API for other extensions" section (getViolationsData, getHealthScoreParams, runAnalysis, runAnalysisForFiles, getVersion). |

### 1.2 Out of scope (this plan)

- **Log Capture changes:** Implemented in saropa-log-capture repo (see integration doc).
- **Plugin file-scoped export (Option B):** focus_files.txt, violations_focus.json. Deferred to backlog.
- **ScanRunner --files + JSON export (Option C):** `dart run saropa_lints:scan --files ... --output json`. Deferred to backlog.
- **Breaking changes** to violations.json schema or existing extension behavior.

---

*(Sections 2–9: see git history or the completion record in `plan_log_capture_integration_history.md` for full task breakdown and references.)*
