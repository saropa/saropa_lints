# Fix: health history test silent false-positive pass

The `loadHealthHistory` unit test contained `if (points.isEmpty) return`, which caused the test to pass without asserting anything when the function returned no data. Since the test runs against this repo (which has many git tags), an empty result indicates a broken function, not a valid "no data" state — the bail-out masked any regression.

## Finish Report (2026-07-17)

### Defect

`test/project_health/health_history_test.dart` line 23 had a defensive early-return on empty results. This pattern — flagged by project policy as a false-positive test anti-pattern (see `feedback_positive_parser_tests`) — allowed `loadHealthHistory` to return `[]` for any reason (broken git archive, broken size scan, broken tag listing) and the test would still report green.

### Fix

Replaced the bail-out with:

- `expect(points, isNotEmpty)` — the function must return data for a tagged repo.
- `expect(p.codeLoc, greaterThan(0))` — the `codeLoc` field was previously untested.
- `expect(p.codeLoc, lessThanOrEqualTo(p.loc))` — code-only lines can never exceed total lines.

### Verification

`dart test test/project_health/health_history_test.dart` — both tests passed (exit code 0). The `--no-pub` flag is not available on `dart test` (only `flutter test`); omitted accordingly.

### Files changed

| File | Change |
|------|--------|
| `test/project_health/health_history_test.dart` | Replaced silent bail-out with positive assertions; added `codeLoc` coverage |
| `CHANGELOG.md` | Added maintenance entry |
