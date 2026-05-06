# Implemented: Drift Advisor integration (saropa_lints extension) — 2026-03-19

**Plan:** `bugs/plan/plan_saropa_drift_advisor_integration.md` — saropa_lints extension parts fully implemented; plan moved to this folder.

## Summary

- **Settings:** `saropaLints.driftAdvisor.integration` (default off), `portRange` [8642, 8649], `pollIntervalMs` (30s; 0 = no poll), `showInProblems` (diagnostics in Problems view).
- **Discovery:** Port scan + GET /api/health; accepts health with or without `ok`; rejects only when `ok: false`. Timeout per port; timer cleared in `finally` to avoid leaks.
- **Client:** GET /api/issues when capability `"issues"` present; else GET /api/index-suggestions and GET /api/analytics/anomalies, merged into stable issue shape.
- **Mapper:** Table (snake_case → PascalCase), column (snake_case → camelCase); one findDartFiles() per mapIssuesToLocations(); table→location cached. mapIssueToLocation delegates to mapIssuesToLocations.
- **View:** Drift Advisor tree under Saropa Lints sidebar (when Dart project); placeholder when integration off or no server; server node + issue nodes when connected; click opens file at line.
- **Diagnostics:** Source "Saropa Drift Advisor", codes `drift_advisor_index_suggestion`, `drift_advisor_anomaly`; optional via showInProblems.
- **Commands:** Refresh (guard against concurrent refresh), Open in Browser (when connected). Context key `saropaLints.driftAdvisor.connected`.
- **Polling:** Optional interval when integration on and pollIntervalMs > 0; rescheduled on config change.
- **Docs:** CHANGELOG, README, ABOUT_SAROPA.md (Drift Advisor integration bullet).
- **Tests:** discovery.test.ts (health 200/ok, ok:false, 404, discoverServer); client.test.ts (fetchIssues with issues capability, empty, invalid filtered). Run: `npm run test` in extension.

**Not in this repo:** Drift Advisor server GET /api/issues and capabilities in health (implement in saropa_drift_advisor when needed).

**Files:** extension/package.json (view, commands, config, menus), extension/src/driftAdvisor/*.ts (types, discovery, client, mapper, driftAdvisorTree), extension/src/extension.ts (view, diag collection, refresh/openInBrowser, poll, context), extension/src/test/driftAdvisor/*.test.ts, extension/tsconfig.test.json, ABOUT_SAROPA.md, README.md, CHANGELOG.md.
