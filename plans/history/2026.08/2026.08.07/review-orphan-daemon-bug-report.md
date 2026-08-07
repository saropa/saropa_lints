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

5. **PID reuse guard** — The orphan-detection logic now cross-checks
   `CreationDate`: if the process occupying the parent PID was created
   *after* the daemon, it is a recycled PID and the daemon is orphaned.
   Applied to both the manual script and the scheduled task script.

6. **Scheduled task escaping** — Replaced inline PowerShell one-liner
   with a two-step approach: save the cleanup script to
   `$env:USERPROFILE\.flutter_daemon_cleanup.ps1`, then register the
   task with `-File` instead of `-Command`. Eliminates nested quote
   escaping that could break across PowerShell versions.

7. **daemon.shutdown verified** — Confirmed `daemon.shutdown` is the
   correct JSON-RPC method name in Flutter SDK source
   (`packages/flutter_tools/lib/src/commands/daemon.dart`).

8. **Dart SDK version confirmed** — `dart --version` returns 3.12.2
   stable, matching the Environment section.

9. **Job Object concept documented** — Added
   `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` as the recommended permanent
   fix for flutter_agent_lens, with implementation pointers (Win32 API
   calls, Node.js packages).

### Scope

Documentation only — no lint rules, tests, or code affected.
