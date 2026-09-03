# Audit Hardening Round 3 — POSIX Kill, Deferred Payload, SARIF CI

Third hardening pass on the audit CLI extension infrastructure. Added unit test
coverage for two previously untested subsystems (process kill and >10 MB deferred
payload handling), documented unstated assumptions, and shipped a GitHub Actions
CI recipe for SARIF upload.

## Finish Report (2026-09-02)

### What changed

**POSIX process-group kill tests** (`extension/src/test/audit/killAuditProcessTree.test.ts`):
5 unit tests covering Linux (`kill -pid`), macOS (same path), fallback on ESRCH,
Windows delegation to `killProcessTree`, and no-pid edge case. `killAuditProcessTree`
exported as `@internal` from `audit-command.ts` for test access.

**Deferred-payload tests** (`extension/src/test/audit/deferredPayload.test.ts`):
6 unit tests covering inline path (small payload), temp-file write (large payload),
prior-file cleanup, selective deletion, non-existent directory, and non-array input.
`maybeWriteDeferredPayload`, `cleanupDeferredPayloads`, `MAX_INLINE_BYTES` exported
as `@internal` from `audit-report-panel.ts`. Shared `buildOversizedDiagnostics()`
helper extracted to deduplicate two near-identical array builders.

**Unstated-assumption documentation:**
- Circular-fallback risk comment in `audit-report-panel.ts:179–186` — documents
  that the fallback inlines a too-large payload which may hang the webview.
- SARIF 2.1.0 §3.8 spec reference in `sarif_writer.dart:64–66` confirming
  `properties` bag compatibility with GitHub code-scanning.

**GitHub Actions CI recipe** (`doc/guides/cli.md`): `audit` section with example
workflow using `--since`, `--format sarif`, `upload-sarif@v3`, plus baseline
comparison variant. Uses shallow base-branch fetch (not `fetch-depth: 0`).

**Build wiring:**
- `extension/tsconfig.test.json` — 8 entries added to `include` array for audit
  source and test files.
- `extension/package.json` — `"out-test/test/audit/**/*.test.js"` added to mocha
  test glob.

### Bugs fixed during review

1. **CI recipe `fetch-depth: 0` was a full-history clone** — changed to shallow
   base-branch fetch to avoid cloning repos with long histories. Adds an extra
   `git fetch` step but avoids the O(full-history) cost.

2. **Duplicated array-builder logic in deferred payload tests** — extracted shared
   `buildOversizedDiagnostics()` helper, eliminating two near-identical 10-line
   blocks.

### Deferred

- **`@internal` enforcement** — exports are comment-only convention with no ESLint
  rule enforcing it. Acceptable risk; could add a barrel-export guard later.
- **Integration-level cancellation test** — wiring the cancellation token through
  the full `spawnAuditCli` → cancel → kill path requires mocking infrastructure
  that has no precedent in this test suite.
- **Integration test for deferred payload → webview wiring** — tests prove
  `maybeWriteDeferredPayload` writes/cleans files, but not that `openAuditReport`
  correctly wires the returned URI into the webview.
### Verification

- `tsc -p tsconfig.test.json` compiles clean.
- `mocha "out-test/test/audit/**/*.test.js"` — 11/11 passing.
- Cross-cutting code review confirmed no interaction bugs between hardening and
  SARIF changes; diagnostic map shapes are compatible throughout the pipeline.

## Finish Report (2026-09-02) — Double-Stringify Fix + Review Pass

### What changed

**Double-JSON.stringify elimination** — the diagnostics array was being serialized
twice on the small-payload path: once in `maybeWriteDeferredPayload` for the size
check (then discarded), and again in `buildAuditReportHtml` via `jsonForScriptBlock`
for the inline embed. Fixed by serializing once in `openAuditReport` and threading
the string to both consumers.

- `openAuditReport` (`audit-report-panel.ts`) now calls `JSON.stringify(diagnostics)`
  upfront and passes the result to both `maybeWriteDeferredPayload` (which now accepts
  `string | null` instead of extracting and serializing internally) and
  `buildAuditReportHtml` (new `serializedDiagnostics` parameter).
- `buildAuditReportHtml` (`audit-report-html.ts`) uses the pre-serialized string with
  `escapeJsonStringForScriptBlock` (HTML-safe escaping only) instead of re-serializing
  via `jsonForScriptBlock`.

**Shared escaping extraction** (`html-utils.ts`) — `escapeJsonStringForScriptBlock`
extracted from `jsonForScriptBlock`, which now delegates to it. Applies the four
HTML-safe replacements (`<`, `&`, U+2028, U+2029) to an already-serialized JSON
string.

**Pre-existing incomplete escaping fix** (`report-html-data.ts`) —
`buildPackageDataScript` hand-rolled only the `<` replacement, missing `&`,
U+2028, and U+2029. Switched to the shared `escapeJsonStringForScriptBlock`.

**Options interface refactor** (`audit-report-html.ts`) — `buildAuditReportHtml`
signature reduced from 5 positional params to 2 (`auditJson` + `AuditReportRenderContext`)
to comply with the project's ≤3-parameter convention. The `AuditReportRenderContext`
interface documents the CONTRACT that `serializedDiagnostics` must be derived from
the same `auditJson['diagnostics']` the function reads as an object — making the
two-sources-of-truth relationship explicit.

**Unit tests for `escapeJsonStringForScriptBlock`** (`html-utils.test.ts`) — 6 tests
covering `<` breakout, `&` escaping, U+2028/U+2029 separators, safe passthrough,
and equivalence with `jsonForScriptBlock`.

### Verification

- `tsc -p tsconfig.test.json --noEmit` — clean.
- `mocha "out-test/test/audit/**/*.test.js" "out-test/test/vibrancy/views/html-utils.test.js"` — 25/25 passing.
- 8-angle code review + low re-review: no correctness bugs.
