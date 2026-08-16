# Fix: Scan diagnostic single-character range causes VS Code highlight noise

The scan-on-save pipeline serialized only `line`/`column` for each diagnostic, and the extension created a 1-character VS Code `Range` (column to column+1). Clicking a finding in the Problems panel selected that single character, triggering VS Code's "highlight all occurrences" feature — every matching letter in the file lit up. For a common letter like "s", hundreds of highlights appeared.

The fix threads `endLine`/`endColumn` through the entire diagnostic pipeline: the Dart scan runner computes them from `lineInfo.getLocation(offset + length)`, the JSON serializer emits them, the TypeScript interface accepts them (optional, for backward compat), and the VS Code diagnostic constructor uses the full span. Legacy scan output without end fields falls back to the original column+1 behavior.

## Finish Report (2026-08-16)

### Files Changed

**Dart (scan pipeline):**
- `lib/src/scan/scan_diagnostic.dart` — added `endLine`, `endColumn` required fields.
- `lib/src/scan/scan_runner.dart` — computes end position via `lineInfo.getLocation(d.offset + d.length)`.
- `lib/src/scan/scan_json.dart` — emits `endLine`/`endColumn` in JSON output.

**Extension (VS Code integration):**
- `extension/src/scanOnSave/scanOnSaveRunner.ts` — added optional `endLine?`/`endColumn?` to `ScanOnSaveDiagnostic`.
- `extension/src/scanOnSave/scanOnSaveController.ts` — `toVscodeDiagnostic` now uses full span range with fallback.

**Tests:**
- `extension/src/test/scanOnSave/scanOnSaveController.test.ts` — 3 new tests: full-span, fallback, multi-line.
- `test/scan/scan_json_test.dart` — new file, 2 tests: end-field serialization, summary counts.

### Verification

- Extension tests: all 3 new tests pass (1737 total passing, 13 pre-existing failures unrelated).
- Dart tests: 2/2 new tests pass.
- No existing assertions broken by the change.

### Risks

- `d.offset + d.length` passed to `lineInfo.getLocation()` — no bounds check. If a rule emits a length that extends past EOF, this would throw. The existing `d.offset` lookup has the same latent risk, so this is not a regression.
- JSON schema version (`kScanJsonVersion`) stays at 1 despite the new fields. The TS side treats them as optional, so backward/forward compat is preserved; a version bump would be cosmetic only.
