# Fix: project_vibrancy_cli_test teardown flaked on the Windows temp-dir lock

The `project vibrancy mvp` test group failed intermittently with `PathAccessException`
(OS errno 32, "the process cannot access the file because it is being used by another
process") when its `tearDown` deleted the per-test temp directory. The teardown is now
resilient to the transient lock, so the suite no longer flakes on Windows.

## Finish Report (2026-06-25)

### Defect

`test/cli/project_vibrancy_cli_test.dart` seeds an ephemeral pub package under
`Directory.systemTemp` in `setUp` and removes it in `tearDown` via
`deleteSync(recursive: true)`. On Windows the analyzer keeps file handles open for a
brief moment after a scan completes, so an immediate recursive delete races those open
handles and throws `PathAccessException` (errno 32). The failure surfaced during the
publish flow's fast-test stage:

```
project vibrancy mvp suspicious_coverage when complexity high and only trivial tests [E]
  PathAccessException: Deletion failed, path = '...\build\test_tmp\pv_mvp_b42c85af'
  (OS Error: The process cannot access the file because it is being used by another
  process, errno = 32)
  test\cli\project_vibrancy_cli_test.dart 45:17  main.<fn>.<fn>
```

The error is non-deterministic — it depends on whether the analyzer's handles have
closed by the time teardown runs — so the test is a flake rather than a logic defect.
Three `group` blocks (`pv_mvp_`, `pv_prog_`, `pv_sup_`) each carried an identical
unguarded `deleteSync`, so any of them could trip the same lock.

### Fix

Added a single top-level helper `_deleteTempDirWithRetry(Directory)` and routed all
three teardowns through it. The helper retries the recursive delete up to five times
with a 50 ms blocking pause between attempts, catching `FileSystemException` (the
superclass of `PathAccessException`). If the lock outlives the retries it returns
silently rather than failing the test — `Directory.systemTemp` entries are reaped by
the OS later, so a leaked temp dir is harmless and is the correct trade against a
spurious red suite.

### Verification

`dart test test/cli/project_vibrancy_cli_test.dart` → 17/17 passed, including the
previously failing `suspicious_coverage when complexity high and only trivial tests`.

### Files

- `test/cli/project_vibrancy_cli_test.dart` — new `_deleteTempDirWithRetry` helper;
  three `tearDown` bodies collapsed to call it.
- `CHANGELOG.md` — Maintenance entry under `[14.2.2]` (test harness only, no user impact).
