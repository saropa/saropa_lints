# Publish Script Crash Detection Fix

The publish script's test-failure retry logic (`_log_shows_vm_crash` in `_publish_steps.py`) only detected VM heap corruption crashes (`Corrupt heap`, `Invalid cid:`, `raw_object.cc`). Two additional crash families in the Dart `front_end` compiler went undetected, causing the retry to treat them as real test failures rather than transient infrastructure flakes.

## Finish Report (2026-08-27)

### Problem

Two crash modes in the Dart SDK `front_end` compiler during incremental test compilation were not recognized by the publish script's transient-failure detector:

1. **`front_end` compiler exception** — `Crash when compiling: Unsupported operation: Cannot remove from a fixed-length list` in `NamedTypeBuilderImpl.resolveIn`. The test runner loads ~10 tests, then the compiler crashes and all subsequent test files report `Failed to load` with no message.

2. **Native `STATUS_ACCESS_VIOLATION`** — the Dart test runner process dies with a native fault. The log file contains valid test output followed by null bytes (unflushed write buffer). `_read_log_text` returned the text portion but found no crash markers.

Both crashes are triggered by too many concurrent `frontend_server` compile workers. The `-j 8` cap (added in a prior session) reduced frequency but did not eliminate the crashes.

### Root Cause

- `_log_shows_vm_crash()` only checked for four heap-corruption string markers. The `front_end` crash uses entirely different strings (`Crash when compiling`, `NamedTypeBuilderImpl`, `Cannot remove from a fixed-length list`).
- The null-byte check was missing entirely. When the process dies with `STATUS_ACCESS_VIOLATION`, the log contains null bytes but no text markers.
- The null-byte check initially read `raw[:8192]` (the head), but crashes leave null bytes at the tail (unflushed buffer after valid output). Fixed to read last 25% of file (min 8 KB) via `seek()`.
- The `--chain-stack-traces` diagnostic pass had no `-j` cap at all, defaulting to ~12 workers (half of 24 cores), high enough to trigger the same crash.

### Changes

- **`_log_shows_vm_crash()`** (`scripts/modules/_publish_steps.py`): Added null-byte tail detection (reads last 25% of file, min 8 KB, via bounded seek). Added three `front_end` compiler crash markers.
- **`_log_transient_failure_reason()`**: Updated reason string from "Dart VM heap corruption crash" to "Dart VM/compiler crash".
- **`_run_dart_test_to_file()`**: Added `concurrency` parameter for retry-path concurrency reduction.
- **`_run_test_pass()`**: Prints `-j N` in the initial test run line. On compiler crash, automatic retry halves concurrency. Interactive retry loop tracks concurrency across attempts so each crash progressively halves it. The failure prompt shows `[F]ewer workers` when a crash is detected, giving the user explicit control.
- **`_prompt_test_failure()`**: New `is_crash` parameter adds `[F]ewer workers` option (returns `retry_fewer`) that halves `-j` on the next run.
- **`_run_chain_stack_traces_and_check()`**: Added `-j` cap (min of cpu_count, 8). Retry halves concurrency on crash and prints `-j N` in both initial and retry messages.

### Hardening (Reflection Gate)

- Null-byte detection window expanded from fixed 8 KB to proportional (last 25% of file, min 8 KB) to handle large logs where the crash tail is beyond 8 KB.
- The `[F]ewer workers` prompt option gives the user visible, interactive control over concurrency — not buried in a CLI flag. Available only when a crash is detected; absent on non-crash failures.
- Chain-stack-traces diagnostic pass now also halves concurrency on crash retry (was previously fixed at 8).

### Verification

- Null-byte detection confirmed against known native-crash log (`reports/20260827/20260827_075418_dart_test_fast.log`): returns `True`.
- `front_end` crash detection confirmed against known compiler-crash log (`reports/2026.08/2026.08.25/20260825_100720_dart_test_fast_retry.log`): returns `True`.
- Clean analysis log: returns `False` (no false positive).
- Module imports without errors after all changes.
