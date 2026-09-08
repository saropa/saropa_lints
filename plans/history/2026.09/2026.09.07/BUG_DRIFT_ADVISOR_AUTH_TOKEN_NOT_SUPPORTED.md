# BUG: Drift Advisor integration sends no credentials — auth-protected servers invisible

**Status: Fixed**

Created: 2026-09-07
Component: Drift Advisor integration
Severity: High (integration silently reports "no server" for all authenticated servers)

---

## Summary

The Drift Advisor discovery probe (`tryHealth`) and the issues/anomalies client (`client.ts`) send no `Authorization` header, and there is no VS Code setting through which a user could supply a token. When a Drift Advisor server requires auth (the documented default for non-loopback binds), the integration goes permanently dark.

The server-side fix (in `saropa_drift_advisor`) now exempts `GET /api/health` from auth and returns `{ "authRequired": true }` in the reduced payload, so detection works. But the issues, index-suggestions, and anomalies endpoints still require credentials, so the integration detects the server but cannot fetch data.

---

## Companion Issue

Server-side fix: `saropa_drift_advisor` bug `BUG_INFRA_AUTH_TOKEN_BLOCKS_SIBLING_SERVER_DISCOVERY.md`.

---

## Required Changes

1. **New VS Code setting** `saropaLints.driftAdvisor.authToken` (string, secret) — the Bearer token for the Drift Advisor server.
2. **`discovery.ts` → `tryHealth`** — Parse `authRequired` from the health response. When true, report "Drift Advisor found at host:port, requires auth token" instead of "no server". Store the `authRequired` flag on `DriftServerInfo`.
3. **`client.ts`** — When `authToken` is configured, add `Authorization: Bearer <token>` to all four `fetch` calls (issues, index-suggestions, anomalies, and any future endpoints).
4. **Tree view** — Show a distinct node when a server is detected with `authRequired: true` but no token is configured, guiding the user to set `saropaLints.driftAdvisor.authToken`.

---

## Impact

Every user running an authenticated Drift Advisor server (the documented default for non-loopback binds) cannot use the Saropa Lints integration until this is implemented.

---

## Finish Report (2026-09-07)

### Changes Made

**types.ts** — `DriftHealthResponse` gained `authRequired?: boolean`. `DriftServerInfo` gained `authRequired?: boolean` and a required `host: string` field (extracted at discovery time, replacing repeated URL re-parsing).

**discovery.ts** — `tryHealth()` now reads `data.authRequired` from the health JSON and propagates it onto the returned `DriftServerInfo`. The `host` parameter is also stored directly.

**auth.ts** (new) — Extracted `getDriftAuthToken()` as the single source of truth for reading `saropaLints.driftAdvisor.authToken` from VS Code settings. Kept in a separate module so `client.ts` remains vscode-free and testable without mocks.

**client.ts** — `fetchIssues()` accepts an optional `authToken` parameter, threaded to all three fetch call sites (`/api/issues`, `/api/index-suggestions`, `/api/analytics/anomalies`) via an `authHeaders()` helper that builds the `Authorization: Bearer <token>` header.

**driftAdvisorTree.ts** — `getChildren()` checks `server.authRequired` + token absence and shows a localized guidance node (`l10n('driftAdvisor.authRequired')`) when the server needs auth but no token is configured. Pre-existing hardcoded English placeholder strings were also localized to `l10n()` calls. Server label now uses `server.host` instead of hardcoded `127.0.0.1`.

**extension.ts / violationsWideReportView.ts** — Both `fetchIssues` call sites read the token via `getDriftAuthToken()` and pass it through. The wide report's `serverLabel` also uses `server.host`.

**package.json** — New `saropaLints.driftAdvisor.authToken` string setting with NLS description in `package.nls.json`.

**en.json** — Four new i18n keys under `driftAdvisor.*` namespace: `authRequired`, `discovering`, `noServerFound`, `integrationOff`.

### Hardening Pass (post-review)

Code review (medium) surfaced a DRY violation (auth-token read duplicated in three places, one missing the `undefined` fallback) and a hand-rolled host-extraction regex duplicating the codebase's established `new URL().hostname` convention. Fixed by:

- Extracting `getDriftAuthToken()` into a new `driftAdvisor/auth.ts` module (kept separate from `client.ts` so the client stays vscode-free and testable without mocks), used by all three call sites (`extension.ts`, `violationsWideReportView.ts`, `driftAdvisorTree.ts`).
- Storing `host` directly on `DriftServerInfo` at discovery time instead of re-parsing `baseUrl` with a regex on every tree render.
- Localizing the three pre-existing hardcoded English placeholder strings in `driftAdvisorTree.ts` (`discovering`, `noServerFound`, `integrationOff`) that were flagged by the i18n convention check.
- Trimming a three-sentence CHANGELOG bullet down to one, per the project's bullet-density rule.

### Feature: Auth-failure surfacing (unrequested, added during reflection gate)

Added a `DriftAuthError` class in `client.ts`, thrown when any data endpoint (`/api/issues`, `/api/index-suggestions`, `/api/analytics/anomalies`) returns 401/403. Previously these were swallowed as `[]`, making a bad token indistinguishable from a genuinely clean project.

`extension.ts` now catches `DriftAuthError` specifically and calls a new `DriftAdvisorTreeProvider.setAuthFailed(server)` method, which keeps the server node visible (it IS reachable) while showing a `l10n('driftAdvisor.authFailed')` placeholder with a click-through command to `workbench.action.openSettings` scoped to `saropaLints.driftAdvisor.authToken`. The pre-existing "auth required, no token configured" placeholder was given the same click-through command.

### Dashboard parity (second hardening pass)

Extended the same auth-failure surfacing to the Findings Dashboard, closing the gap noted in the first pass: `DriftAdvisorSnapshot` (both the `violationsWideReportView.ts` definition and the shared `violations-dashboard-shared.ts` input type) gained `authRequired?: boolean` and `authFailed?: boolean`. `loadDriftAdvisorSnapshot()` now checks `server.authRequired` before fetching (mirroring the tree view's gate) and catches `DriftAuthError` separately from other fetch failures. `violations-dashboard-top.ts`'s status-line pill builder gained two new states — "Drift needs token" and "Drift auth failed" (both `pill warn`, reusing the existing pill styling) — checked ahead of the existing connected/offline branches. Four new `findingsDash.status.*` l10n keys back the new pill text and tooltips.

The dashboard pill is informational only (not clickable) — reaching Settings from the dashboard still requires the tree view or Command Palette, consistent with how the existing offline/connected pills behave.

### Tests Added

- `discovery.test.ts`: 3 tests — `authRequired` propagation, `authRequired` absence, `host` field storage.
- `client.test.ts`: 4 tests — Authorization header sent/omitted correctly, `DriftAuthError` thrown on 401 from `/api/issues`, `DriftAuthError` thrown on 403 from legacy endpoints.
- `violationsDashboardHtml.test.ts`: 5 tests — no pill when integration disabled, offline pill, connected pill, auth-required pill (and that it suppresses the offline pill), auth-failed pill (and that it suppresses the connected pill).

All 65 tests in the affected suites pass (discovery, client, violationsDashboardHtml). Both `tsconfig.json` and `tsconfig.test.json` compile clean.

### Known Gaps (out of scope)

1. **HTTP-only Bearer token**: The `baseUrl` is always `http://`, and the token is sent in cleartext. Off-box (LAN) deployments are vulnerable to credential sniffing. An HTTPS option or warning for non-loopback hosts would mitigate this.

2. **Dashboard pill is not clickable**: Unlike the tree view's placeholders, the dashboard's auth-required/auth-failed pills do not open Settings on click — matches the existing (non-interactive) pill convention for offline/connected states, but is a smaller affordance than the tree view offers for the same problem.

3. **No live verification**: All work in this bug was verified by `tsc`/`mocha` only — no Extension Development Host session was launched. Visual layout, both themes, and narrow-width rendering of the new tree placeholders and dashboard pills remain unverified.
