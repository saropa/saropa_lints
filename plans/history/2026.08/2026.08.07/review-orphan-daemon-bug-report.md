## Review: infra_orphan_flutter_daemons_leak_memory.md

Bug report for orphaned `flutter daemon` processes accumulating on Windows,
compounding with the analysis server memory issue to exhaust system RAM.

## Finish Report (2026-08-07)

### Changes

Four corrections applied to `bugs/infra_orphan_flutter_daemons_leak_memory.md`:

1. **Hypothesis reordering** — The Windows broken-stdin-pipe hypothesis
   (daemon blocks on event loop and never detects parent death) promoted
   from Hypothesis C to Hypothesis A as the most probable root cause.
   Added explanation of the POSIX vs Windows process lifecycle difference.

2. **PowerShell mitigation script fix** — `Get-Process -ErrorAction
   SilentlyContinue` does not reliably suppress non-terminating errors
   in all PowerShell versions. Replaced with `try { ... -ErrorAction Stop }
   catch {}` pattern.

3. **Added scheduled Task Scheduler mitigation** — Concrete
   `Register-ScheduledTask` script running every 15 minutes to kill
   orphaned daemons, breaking the OOM feedback loop immediately rather
   than deferring to "investigate."

4. **Pinned Flutter SDK version** — Replaced "3.x" with actual version
   `3.44.8 stable (framework 058e0af2c2, 2026-07-23)`.

Also added a diagnostic step to test whether orphaned daemons accept
graceful `daemon.shutdown` JSON-RPC commands before resorting to
force-kill.

### Hardening pass

5. **PID reuse guard** — The orphan-detection logic cross-checks
   `CreationDate`: if the process occupying the parent PID was created
   *after* the daemon, it is a recycled PID and the daemon is orphaned.
   Uses strict `-lt` (not `-le`) so same-second parents are treated as
   alive — false negative is safer than false positive.

6. **Process name coverage** — Filter widened from `dart.exe` only to
   `dart.exe OR dartvm.exe`. Live process inspection confirmed both
   executables run flutter daemons depending on SDK version.

7. **Command-line pattern tightened** — Changed from `*daemon*` to
   `*flutter_tools.snapshot*daemon*` to avoid matching unrelated
   `tooling-daemon` processes (also confirmed live).

8. **Scheduled task escaping** — Replaced inline PowerShell one-liner
   with a two-step approach: save the cleanup script to
   `$env:USERPROFILE\.flutter_daemon_cleanup.ps1`, then register the
   task with `-File` instead of `-Command`. Eliminates nested quote
   escaping that could break across PowerShell versions.

9. **daemon.shutdown diagnostic rewritten** — The original diagnostic
   started a *new* daemon instead of connecting to an existing orphan.
   Replaced with a stdin-close test that confirms whether Hypothesis A
   (broken pipe not detected) is the root cause. Documented that
   orphaned daemons cannot receive stdin commands from another process,
   so graceful shutdown is not a viable cleanup path.

10. **Job Object npm package corrected** — `win32-job-object` does not
    exist on npm. Replaced with `electron-job-addon` (verified on npm,
    native N-API bindings) and `ffi-napi` + `ref-napi` as alternatives.

11. **daemon.shutdown verified** — Confirmed as the correct JSON-RPC
    method name in Flutter SDK source.

12. **Dart SDK version confirmed** — `dart --version` returns 3.12.2
    stable, matching the Environment section.

### Scope

Documentation only — no lint rules, tests, or code affected.
