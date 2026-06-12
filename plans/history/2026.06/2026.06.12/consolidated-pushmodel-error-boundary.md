# Consolidated dashboard model push gains an error boundary

The consolidated dashboard's `pushModel()` rebuilds its model and posts it to the
webview. It is invoked from a debounced `setTimeout` and from the diagnostics
listener — paths with no caller able to catch a throw. An unhandled error from
the model build would propagate out of the timer and silently stop the live
refresh loop, leaving the dashboard frozen on stale data with no signal.

## Finish Report (2026-06-12)

### Scope
**(B)** VS Code extension. Defensive hardening to one host-side function;
no Dart rules — Linter-Specific Integrity SKIPPED [A-NOT-IN-SCOPE].

### What changed
[consolidatedView.ts](../../../../extension/src/views/consolidated/consolidatedView.ts)
`pushModel()` now wraps the model build and `postMessage` in try/catch. On a
throw it logs to the developer console and returns, leaving `lastModel` and the
panel intact so the last good model stays on screen and the next diagnostic
change retries. The success path is unchanged.

The log uses `console.error` — a developer-diagnostic string, exempt from
localization.

### Deep review
- **Error boundary:** the guard is scoped to the build + post; a failure no longer
  escapes the debounced timer, so the refresh loop survives a transient model
  error instead of dying silently. This is the "background process must not take
  down the loop" case for the live-refresh path.
- **No behavior change on success:** the model is built and posted exactly as
  before when no error occurs.

### Testing
- **Audited** existing tests: no test references `pushModel` (it is a host-side
  controller function that requires a live `WebviewPanel`); `consolidatedClient`
  and `consolidatedModel` tests cover the client and the pure model and are
  unaffected.
- **Run:** `npm run check-types` clean; `npm test` = **1230 passing / 11 failing**
  (the 11 pre-exist — cross-file CLI harness + a languagePick locale-coverage
  assertion; zero regressions).

### Not verified
The catch branch is not exercised by an automated test (triggering it needs a
model-build throw behind the live panel). The guard is a standard try/catch around
the existing call; the success path is covered by the existing suite.

### Files
- Modified: `extension/src/views/consolidated/consolidatedView.ts`, `CHANGELOG.md`,
  `plans/OUTSTANDING_ITEMS_AUDIT.md`
