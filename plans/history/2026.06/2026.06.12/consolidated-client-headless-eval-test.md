# Consolidated dashboard client gains headless execution coverage

The consolidated dashboard's webview client is delivered as a template-literal
string ([getConsolidatedClient](../../../../extension/src/views/consolidated/consolidatedClient.ts))
that runs inside the webview. The compiler never sees that string, so a syntax
slip, a reference error, or a regex literal mangled by template-literal escaping
would ship undetected and surface only as a blank dashboard on a real render.
The client had never executed outside a live webview — its correctness rested on
code review alone.

## Finish Report (2026-06-12)

### Scope
**(B)** VS Code extension — test-only plus build wiring. No production code
changed; the client itself is untouched. Linter-Specific Integrity SKIPPED
[A-NOT-IN-SCOPE].

### What changed
A new test, [consolidatedClient.test.ts](../../../../extension/src/test/consolidatedClient.test.ts),
executes the client string in CI instead of merely asserting substrings against
it. Because the client uses a small, stubbable DOM surface, the test supplies a
minimal recording-DOM harness rather than adding a `jsdom`/`linkedom` dependency:

- **`makeEl`** — a recording element stub with `textContent` (string-coercing,
  like a real DOM setter), `innerHTML`, `style.setProperty`, `classList`,
  `dataset`, `addEventListener`, `appendChild`, and a **caching** `querySelector`
  (so a node patched after creation is the same node a later read sees).
- **`makeHarness` / `runClient`** — injects `document`, `window`, and
  `acquireVsCodeApi` as parameters of a `new Function(...)` built from
  `getConsolidatedClient()`, so the client's free variables bind to the stubs and
  the whole script runs to its initial `postMessage({ type: 'ready' })`.
- **`extractFn`** — pulls a single brace-balanced `function` body out of the
  client and `eval`s it in isolation (the same technique the scanning-state test
  uses), so `esc()` can be called directly.

Six cases: the client loads without throwing and posts `ready`; `esc()` escapes
`& < > "` correctly (proving the regex literals survived template-literal
escaping — the failure class recorded in `reference_webview_template_literal_regex_trap`);
a `model` message patches the gauge value/color, grade, score, label, summary,
and chips; a `model` message builds a group row, sets its navigation dataset, and
hides the empty state; an `occurrences` message renders rows into the matching
group; an empty `model` shows the empty state and hides the group list.

### Why this is a partial, not a full, close of the gap
The harness exercises the data-patch paths (load, `model`, `occurrences`) but not
click / keyboard interaction, which relies on real DOM tree navigation
(`Element.closest`, `parentElement`) the recording stub does not model, and not
the visual render (theme inheritance, layout, the elevated stylesheet). Those
remain for a human launch in the Extension Development Host. The value delivered:
the un-typechecked string now executes in CI, so a syntax/reference error or a
mangled regex literal fails the build instead of shipping.

### Testing
- **Audited** existing tests touching the client — none asserted against
  `getConsolidatedClient` beyond `consolidatedModel.test.ts` (the host-side model,
  unaffected). No existing assertion changed.
- **New:** the six cases above.
- **Harness fidelity note:** one case initially failed because the client assigns
  a raw number to `gaugeScore.textContent`; a real DOM coerces that to a string.
  The stub's `textContent` setter was made string-coercing to match the browser,
  confirming the harness reflects real-DOM behavior rather than the raw assignment.
- **Build wiring:** `tsconfig.test.json` (explicit include allowlist) and the
  `package.json` mocha list both gained the client source + the new test.
- **Run:** `npm run check-types` clean; `npm test` = **1230 passing / 11 failing**.
  The 11 pre-exist (cross-file CLI harness + a languagePick locale-coverage
  assertion); count rose from 1224 to 1230 (the six new cases), zero regressions.

### Files
- New: `extension/src/test/consolidatedClient.test.ts`
- Modified: `extension/tsconfig.test.json`, `extension/package.json`,
  `CHANGELOG.md`, `plans/OUTSTANDING_ITEMS_AUDIT.md`
