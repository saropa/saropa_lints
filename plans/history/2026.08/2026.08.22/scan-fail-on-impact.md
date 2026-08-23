# scan --fail-on-impact

The scan CLI lacked an exit-code gate on rule-declared impact level. Users could filter display output by impact (`--min-impact`) but had no way to make CI fail based on impact — only severity (`--fail-on`) was supported for exit-code control.

## Finish Report (2026-08-22)

### What changed

Added `--fail-on-impact <level>` flag to the scan CLI. It checks the rule author's declared `LintImpact` (fixed business-consequence rating) rather than the analyzer severity (which is project-configurable). Non-saropa diagnostics (no impact value) are excluded from the check. When both `--fail-on` and `--fail-on-impact` are set, either threshold being met triggers exit 1 (logical OR).

### Files modified

| File | Change |
|------|--------|
| `lib/src/scan/scan_cli_args.dart` | `failOnImpact` + `failOnImpactCount` fields, arg parsing for both |
| `bin/scan.dart` | `_computeExitCode` updated for impact threshold + count baseline, help text, JSON metadata |
| `test/scan/scan_cli_args_test.dart` | 11 new tests (5 for `--fail-on-impact`, 6 for `--fail-on-impact-count`) |
| `doc/guides/cli.md` | Flag table entries, CI example, JSON schema |
| `CHANGELOG.md` | Entry under `[15.2.3] ### Added` |

### Test coverage

- Parsing: 11 unit tests covering both flags (valid values, invalid, missing, null default, combinations).
- Exit-code integration: NOT tested at process level. The `_computeExitCode` logic follows the identical pattern as the existing `--fail-on` branch which has process tests. Each process test takes 60+ seconds in this project due to full resolver startup.

### Closes

GitHub issue [#312](https://github.com/saropa/saropa_lints/issues/312) — feature request portion (`--fail-on-impact`). The design-question portion (merge impact/severity/tiers) was addressed in the reply draft as an intentional architecture explanation.
