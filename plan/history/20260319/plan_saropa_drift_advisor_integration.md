# Optional Tighter Integration: saropa_lints ↔ saropa_drift_advisor

**Status:** Plan (saropa_lints extension parts implemented; see plan_saropa_drift_advisor_integration_history.md in this folder)  
**Last updated:** 2025-03-19

## Summary

- **saropa_drift_advisor**: Debug-only HTTP server + VS Code extension for inspecting SQLite/Drift DBs. Exposes REST API (health, tables, schema, index-suggestions, anomalies, performance, snapshots, compare). No CLI. Issues are **index suggestions** (missing indexes) and **anomalies** (data quality: nulls, empty strings, orphaned FKs, duplicates, outliers). Server has **no file/line**; the Drift Advisor extension maps table/column → Dart files via regex (class name, column getters).
- **saropa_lints**: Dart custom lint package (2050+ rules) + VS Code extension (issues tree, config, vibrancy, TODOs & Hacks). No current reference to saropa_drift_advisor.

Integration is **optional**: only relevant when the user has both a Dart/Drift project and (at debug time) a running Drift Advisor server. We want **tighter** integration without hard dependencies or mandatory features.

---

## 1. Strategies for optional but tighter integration

### A. Extension-only, HTTP-based (recommended baseline)

- **saropa_lints extension** optionally discovers Drift Advisor the same way the Drift Advisor extension does: scan ports (e.g. 8642–8649), `GET /api/health`, then call `/api/index-suggestions` and `/api/analytics/anomalies`.
- **No dependency** from saropa_lints on saropa_drift_advisor package or extension at build/install time.
- **Activation**: Only when a Dart project is present and a setting like `saropaLints.driftAdvisor.integration` is enabled (default `true` or `false`; can be "auto" = enable when server found).
- **Data flow**: Fetch issues from Drift Advisor → map to file/line using the **same** table/column → Dart mapping logic (see §2 and §3). Show in a dedicated view and/or merge into Problems/diagnostics with a distinct source/code so they can be filtered.

### B. Single "issues" endpoint on Drift Advisor (reduces round-trips)

- Drift Advisor adds **GET /api/issues** (or `/api/lint`) that returns a single JSON array merging index suggestions + anomalies in a **stable shape** (see §2). saropa_lints extension then does **one** request instead of two, and both extensions can consume the same contract.
- Optional query params: `?sources=index-suggestions,anomalies` to allow filtering.

### C. Shared mapping logic (optional, for consistency)

- The logic that maps (table, column) → (file, range) lives today only in Drift Advisor's extension (`issue-mapper.ts`, `dart-names.ts`). Options:
  - **Keep mapping in each extension**: saropa_lints reimplements a minimal mapper (snake_case ↔ PascalCase/camelCase, find table class and column getter in Dart files). No cross-repo dependency; slight duplication.
  - **Extract to shared npm package**: e.g. `@saropa/drift-issue-mapper`. Both extensions depend on it. Single place for table/column → file/line rules; more setup.
  - **Drift Advisor exposes "resolved" issues with file/line**: Would require Drift Advisor to scan workspace Dart files and run the mapper on the server or in its extension, then expose file/line via API or a side-channel. That's a bigger change and ties the server to the workspace; not recommended.

### D. saropa_lints extension UI surface

- **New view**: e.g. "Drift Advisor" under Saropa Lints sidebar (when `saropaLints.driftAdvisor.integration` is on and a server is found). Shows:
  - Server status (port, health).
  - List of issues (index suggestions + anomalies) with file/line when mapping succeeds; click opens editor.
  - Optional: link to "Open in Drift Advisor" (focus Drift Advisor extension or open browser at `http://localhost:8642`).
- **Diagnostics**: Publish Drift Advisor issues as `Diagnostic`s with `source: "Saropa Drift Advisor"` and a dedicated `code` (e.g. `drift_advisor_index_suggestion`, `drift_advisor_anomaly`) so users can filter them in the Problems view and they appear in the same list as saropa_lints issues.
- **Context/when**: Use a context key e.g. `saropaLints.driftAdvisor.connected` so the view and commands only show when a server is actually connected.

### E. Optional config file (CI / headless)

- For CI or scripted use, Drift Advisor could support an optional config file (e.g. `drift_advisor.yaml` or a section in `analysis_options.yaml`) for port, auth, and which checks to run. saropa_lints could then document "run Drift Advisor server with config X, then run Saropa Lints analysis" to include Drift issues in a report. This is secondary to the extension integration.

---

## 2. Extending saropa_drift_advisor to expose more to this package

### 2.1 Stable "issues" payload and optional GET /api/issues

**Goal:** One clear contract for "all lint-like issues" (index suggestions + anomalies) so saropa_lints (or any client) can consume them in one call.

- **Define a stable JSON shape** for a single "issue" (document in `doc/API.md` and optionally in a small JSON Schema):

  - `source`: `"index-suggestion"` | `"anomaly"`
  - `severity`: `"error"` | `"warning"` | `"info"`
  - `table`: string
  - `column`: string | null (null for e.g. duplicate_rows)
  - `message`: string
  - `suggestedSql`: string | null (for index suggestions)
  - `type`: string | null (for anomalies: `null_values`, `empty_strings`, `orphaned_fk`, `duplicate_rows`, `potential_outlier`)

- **Add GET /api/issues** (or GET /api/lint):
  - Implementation: call existing index-suggestions and anomalies handlers (or their backing logic), merge into the above shape, return `{ "issues": [...] }`.
  - Optional query: `?sources=index-suggestions,anomalies` (default both).
  - Same auth and rate limits as other `/api/*` routes.

- **Document** the shape in API.md and mention that Saropa Lints (and the Drift Advisor extension) can use this for a single-request integration.

### 2.2 Export server "issue" types and analysis helpers (Dart)

**Goal:** If a Dart tool (or a future Dart-based CLI in Drift Advisor) wants to run the same analyses without HTTP, expose a minimal public API.

- **Current state:** Logic lives in `lib/src/server/` (e.g. `AnomalyDetector.getAnomaliesResult`, index suggestions in `AnalyticsHandler` / `IndexAnalyzer`). Not exported from `lib/saropa_drift_advisor.dart`.
- **Options:**
  - Export a **single function** or small class, e.g. `DriftDebugIssues.run(DriftDebugQuery query)` that returns the same merged list of maps (or a list of a new `DriftIssue` class) so consumers don't depend on HTTP. This requires the "issues" shape to be stable (see 2.1).
  - Or: only document and keep the HTTP API as the sole contract (simpler; saropa_lints extension is TypeScript anyway and will use HTTP).

### 2.3 Version and capability in health

**Goal:** saropa_lints can detect whether the server supports `/api/issues` and fall back to two calls if needed.

- **GET /api/health** already returns `version`. Optionally add a small `capabilities` array, e.g. `["issues"]`, when GET /api/issues is implemented. saropa_lints extension can then:
  - If `capabilities` includes `"issues"` → GET /api/issues once.
  - Else → GET /api/index-suggestions and GET /api/analytics/anomalies and merge client-side (same as Drift Advisor extension today).

### 2.4 Keep file/line out of the server

- **Recommendation:** Do **not** add file paths or line numbers to the Drift Advisor server. The server has no notion of the workspace or Dart files. Keeping "file + range" only in the client (Drift Advisor extension or saropa_lints extension) preserves a clear separation and allows both extensions to use the same mapping logic (or their own) without changing the server.

---

## 3. What else can we do?

### 3.1 saropa_lints extension

- **Drift Advisor view** (see §1.D): New tree or list view under Saropa Lints sidebar, visible when integration is on and a server is discovered. Show issues with file/line; refresh on interval or on demand; "Open in browser" / "Focus Drift Advisor" link.
- **Diagnostics** (see §1.D): Register a `DiagnosticCollection` for Drift Advisor issues; source = `"Saropa Drift Advisor"`, codes = `drift_advisor_index_suggestion`, `drift_advisor_anomaly`. Map table/column → file/line using the same algorithm as Drift Advisor (reimplement or depend on a shared package).
- **Settings**: e.g. `saropaLints.driftAdvisor.integration` (bool or "auto"), `saropaLints.driftAdvisor.portRange` (default 8642–8649), `saropaLints.driftAdvisor.pollIntervalMs`, `saropaLints.driftAdvisor.showInProblems` (bool).
- **Discovery**: Reuse the same port-scan + health-check approach as Drift Advisor's `ServerDiscovery` (no need to depend on that extension; implement a minimal scanner in saropa_lints that hits `GET /api/health` on a small port range).
- **About / docs**: In "About Saropa" (or README), add a short "Drift Advisor integration" section: when both extensions are used, Saropa Lints can show Drift Advisor issues in the sidebar and Problems; link to Drift Advisor docs.

### 3.2 saropa_lints package (Dart)

- **No change required** for basic integration: the Dart package is static analysis only; Drift Advisor issues are runtime/debug-time and come from the server. Optional future: a **documented** way to exclude or tag Drift table/column names so that a future "unused table" or "missing index" rule could be informed by Drift Advisor data (e.g. via a generated file or analysis_options). This is speculative and not required for the extension integration.

### 3.3 Drift Advisor extension

- **Optional handshake**: When Drift Advisor extension is installed, it could set a context or expose a simple API (e.g. "current server port") so Saropa Lints doesn't have to scan ports. Not required if port scan is cheap and limited to 8642–8649.
- **Shared diagnostic source**: Both extensions could publish to the same DiagnosticCollection with the same `source` and `code` so that "Saropa Drift Advisor" appears once in the Problems view and both can contribute. Coordination on source/code names is enough.

### 3.4 Documentation and discoverability

- **saropa_lints**: README / walkthrough step for "Optional: Drift Advisor" – enable integration, run app with Drift server, see DB issues in Saropa Lints.
- **saropa_drift_advisor**: README / API.md – "Consumers: VS Code extension, Saropa Lints extension (optional integration)." Document GET /api/issues when added.

### 3.5 CI / headless (later)

- Drift Advisor server could be started in a test or script (e.g. Flutter integration test that opens DB and starts the server), then a script or CI step calls GET /api/issues (or the two endpoints), and fails the build if severity ≥ warning. saropa_lints doesn't need to run that step; it's a separate "Drift quality gate" that can be combined with `dart analyze` (saropa_lints) in the same pipeline.

---

## 4. Implementation order (suggested)

1. **Drift Advisor**: Define the stable issue shape in API.md; add GET /api/issues that merges index-suggestions + anomalies; optionally add `capabilities` to health.
2. **saropa_lints extension**: Add settings for Drift Advisor integration (off by default or "auto"); implement minimal port scan + GET /api/health; if supported, GET /api/issues, else two calls; implement table/column → Dart file/line mapper (or depend on shared package if created); add "Drift Advisor" view and optional diagnostics; set context when connected.
3. **Docs**: Update both READMEs and About Saropa with a short "Drift Advisor integration" section.

This gives optional, tighter integration without hard dependencies and keeps the server free of workspace/file knowledge.
