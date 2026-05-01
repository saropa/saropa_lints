# IDE Integration Verification — Plan §10 E1-E5

These five checks require an interactive VS Code session. They are **not automated** because the analyzer-plugin → IDE → user surface cannot be exercised from a headless test runner with high fidelity.

Run each step in order, fill in the result column, and commit the updated table. Treat any **FAIL** as a blocker for the milestone in [`plan/TESTING_AND_RELEASE.md`](../../../TESTING_AND_RELEASE.md) §8 row "IDE integration sign-off".

## Prerequisites

- VS Code with the **Saropa Lints** extension installed (Marketplace or local `.vsix`).
- The `saropa_lints` workspace open at the repo root (not a subfolder — the example package needs the path-dep resolution).
- Run `dart pub get` in both the repo root and `example/` once before starting.

## Checklist

| # | Step | Expected | Result | Notes |
|---|------|----------|--------|-------|
| E1 | Open `example/lib/security/avoid_hardcoded_credentials_fixture.dart`. Wait 10s for analysis. | Red squiggle on the BAD line; rule code `avoid_hardcoded_credentials` listed in **View → Problems**. | _PASS / FAIL_ | |
| E2 | Hover the BAD line in E1, click the lightbulb (or `Ctrl+.`). | Menu lists the saropa fix offered by the rule's `fixGenerators`. Capture the exact menu label here. | _PASS / FAIL_ | Menu label: |
| E3 | Click the saropa fix from E2. | Source rewrite matches the producer's intended replacement; the diagnostic clears on next save. | _PASS / FAIL_ | Diff captured in `e3_diff.txt`? |
| E4 | Open the integrated terminal in `example/`, run `dart analyze`. | At least one named saropa rule code (not just compile-time codes like `unused_import`) appears in output. | _PASS / FAIL_ | Codes seen: |
| E5 | Copy a fixture file (e.g. `cp avoid_hardcoded_credentials_fixture.dart /tmp/`), run `dart fix --apply --code=avoid_hardcoded_credentials lib/security/avoid_hardcoded_credentials_fixture.dart` (then revert). | Fix applied; subsequent `dart analyze` no longer flags that line. | _PASS / FAIL_ | |

## Failure triage

- **E1 fails** → analyzer plugin not loading. Check **View → Output → Dart Analysis Server** for `custom_lint plugin started`. See [`doc/troubleshooting.md`](../../../../doc/troubleshooting.md) §1.
- **E2 fails** but E1 passes → fix not registered. Verify the rule's `fixGenerators` getter wires the producer.
- **E3 fails** but E2 passes → producer's `compute(builder)` either returned without an edit or the edit's source range was wrong. Add a regression entry under plan §10 D-followup.
- **E4 fails** but E1 passes → `dart analyze` is not picking up the analyzer plugin (only the IDE is). Check `analysis_options.yaml` `analyzer.plugins`.
- **E5 fails** but E2 passes → `dart fix` cannot reach the producer through the analyzer protocol; this is the `dart fix --apply` integration gap noted in plan §10 D4.

## Recording results

After running, leave this file in place with the **Result** column filled in. If you took screenshots, drop them next to this file as `e1.png`, `e2.png`, etc. Do not commit screenshots larger than 500 KB — link out to a gist instead.

## Date verified

_(filled in by reviewer)_

- Reviewer:
- Date:
- saropa_lints version verified:
- VS Code version:
- Dart SDK version:
