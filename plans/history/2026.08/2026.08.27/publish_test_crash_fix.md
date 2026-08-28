# Publish Test Crash Fix

The publish script's `dart test` step crashed with `STATUS_ACCESS_VIOLATION` (native access violation in the Dart frontend_server compiler) on Windows, preventing release. Two independent root causes combined to make the test suite unrunnable.

## Finish Report (2026-08-27)

### Root Cause 1: Unbounded test concurrency

`_run_dart_test_to_file()` in `scripts/modules/_publish_steps.py` passed `-j <os.cpu_count()>` (24 on the build machine) to `dart test`. Spawning 24 concurrent `frontend_server` compile workers exceeded the Dart VM's internal limits on Windows, causing a native crash (`ExceptionCode=-1073741819`) during the first test file's compilation — before any test logic ran. All 335 test files then reported "Failed to load" with empty error messages.

**Fix:** Replaced the static `-j 24` with auto-tuning: `_auto_tune_concurrency()` probes a single lightweight test file at increasing `-j` levels (4, 6, 8, 10, 12), stopping at the first crash. The result is cached in `build/.dart_test_max_j` keyed by SDK version + CPU count, so the probe runs once per machine/SDK combination. On crash, automatic retries halve the concurrency (`max(tuned_j // 2, 2)`).

### Root Cause 2: Test temp dir inside project tree

`_dart_test_env()` redirected TMP/TEMP to `build/test_tmp/` inside the project. The `dart test` kernel compiler wrote `.dill` cache files there (~5 GB per run, two stale dirs totaling 10.8 GB). This caused two failures:
1. `ScanRunner.discoverDartFiles` scanned the `.dill` files, finding broken imports -> `uri_does_not_exist` at ERROR severity -> the `--fail-on error` test failed deterministically.
2. On C:, the stale kernel dirs exhausted disk space (8.2 GB free, 10.8 GB of cache), causing a cascade of "There is not enough space on the disk" errors mid-suite.

**Fix:** Moved default temp to `<system_temp>/saropa_dart_test` (outside the project tree). Added `SAROPA_TEST_TMP` environment variable for override with runtime validation: if the override resolves inside the project tree, a warning is printed and the default is used instead. Cleaned 10.8 GB of stale kernel cache from `C:\Users\...\AppData\Local\Temp\`.

### Crash detection improvements

Expanded `_log_shows_vm_crash()` to detect three crash families:
- VM heap corruption (`Corrupt heap`, `Invalid cid:`, `raw_object.cc`)
- Front-end compiler crash (`Crash when compiling`, `NamedTypeBuilderImpl`, `Cannot remove from a fixed-length list`)
- Native access violation (null bytes in log from process dying mid-write)

### Also removed from tracking

`plans/known_issues_review.md` — a generated publish-pipeline report that was committed to git. Added to `.gitignore`.

### Verification

Full test suite: `dart test -j 8` with TMP redirected outside project tree -> 9374 passed, 1 skipped, 0 failures.

### Files changed

- `scripts/modules/_publish_steps.py` — auto-tune concurrency, temp dir relocation with validation, crash detection, retry logic
- `.gitignore` — added `plans/known_issues_review.md`
- `CHANGELOG.md` — maintenance entries under `[Unreleased]`
