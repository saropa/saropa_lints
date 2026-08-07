# BUG: Infrastructure — Orphaned flutter daemon processes accumulate and leak memory

**Status: Open**

Created: 2026-08-07
Rule: N/A (infrastructure — Flutter tooling, not a lint rule)
File: N/A
Severity: Critical
Rule version: N/A | Since: unknown | Updated: N/A

---

## Summary

Flutter daemon processes (`flutter_tools.snapshot daemon`) accumulate as
orphans throughout the day. Parent processes die but the daemons persist.
On 2026-08-07, 17 of 20 running daemons were orphaned (parent PID dead),
spawning roughly every 10-15 minutes. Combined with the Dart analysis
server, total Dart process memory reached 9.2 GB of 32 GB system RAM,
leaving under 5 GB free and causing OOM crashes in Claude Code's MCP
servers (context7, flutter_agent_lens) and repeated VS Code extension
host restarts (20 restarts in one session).

---

## Attribution Evidence

This is a Flutter SDK / VS Code Dart extension issue, not a saropa_lints
rule bug. Filed here because the impact is observed in the saropa_lints
development environment and the daemon accumulation may be triggered by
the Dart extension's interaction with custom_lint plugin workspaces.

```powershell
# Confirm daemons are flutter_tools.snapshot processes
# NOTE: the executable may be dart.exe OR dartvm.exe depending on SDK version
Get-CimInstance Win32_Process -Filter "Name = 'dart.exe' OR Name = 'dartvm.exe'" |
  Where-Object { $_.CommandLine -like '*flutter_tools.snapshot*daemon*' } |
  Select-Object ProcessId, ParentProcessId, CommandLine
# All match: flutter_tools.snapshot "daemon"
```

---

## Reproducer

1. Open multiple Flutter/Dart workspaces in VS Code throughout a work session.
2. Let Claude Code sessions start and stop (each may trigger daemon spawns
   via flutter_agent_lens MCP server or the Dart extension).
3. After several hours, check running processes:

```
Observed 2026-08-07 at 11:38 AM:
- 20 flutter daemon processes
- 17 orphaned (parent PID no longer exists)
- 3 legitimately parented (2 by Code, 1 by cmd)
- Spawning interval: ~10-15 minutes (07:48 through 11:38)

PID     ParentPID  ParentAlive  Created
12156   27172      DEAD         07:48
27736   16556      DEAD         08:24
21052   23016      DEAD         08:31
27332   2376       DEAD         08:40
11068   16836      DEAD         08:48
31084   8964       DEAD         09:00
25716   19864      DEAD         09:17
24796   6892       DEAD         09:37
2288    31820      DEAD         09:57
24800   3104       DEAD         10:01
33164   29692      DEAD         10:08
31708   31292      DEAD         10:14
14376   16508      DEAD         10:21
32904   18116      DEAD         10:30
20048   7260       DEAD         10:39
37056   32428      DEAD         10:55
34088   1608       DEAD         10:55
32136   28152      Code         11:36  (alive)
14576   28536      Code         11:38  (alive)
27284   30988      cmd          11:38  (alive)
```

**Frequency:** Daily. Orphans accumulate continuously during work sessions.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Flutter daemon exits when its parent process dies, or is reused across sessions |
| **Actual** | Each parent spawn creates a new daemon; when the parent dies, the daemon persists indefinitely |

---

## Root Cause

### Hypothesis A (most likely): Flutter daemon doesn't detect broken stdin on Windows

`flutter daemon` communicates over stdin/stdout. On POSIX, a broken pipe
delivers SIGPIPE or an EOF on the next read. On Windows, child processes
don't receive any signal when the parent dies — stdin only returns EOF if
the daemon is actively reading from it. If the daemon is blocked on a
named pipe, socket, or event loop wait, it never notices the parent is
gone and persists indefinitely. This is a well-known Windows process
lifecycle gap.

### Hypothesis B: flutter_agent_lens MCP server spawns daemons that outlive Claude sessions

The `flutter_agent_lens` MCP server (PID visible in process tree) runs as
a Claude Code MCP server. Each Claude session may launch it, which in turn
spawns a flutter daemon. When the Claude session ends, flutter_agent_lens
dies, but the daemon it spawned persists.

Evidence: the orphan spawn rate (~every 10-15 minutes) correlates with
Claude Code session lifecycle, not VS Code window lifecycle.

### Hypothesis C: VS Code Dart extension spawns daemons on workspace reload

Each VS Code extension host restart (20 restarts observed in one session
due to OOM) spawns a new flutter daemon via the Dart extension. The
previous daemon is not killed on restart.

---

## Suggested Fix

**Immediate mitigation (manual):**

```powershell
# Kill all orphaned flutter daemon processes
# Matches both dart.exe and dartvm.exe (SDK uses either depending on version).
# Uses flutter_tools.snapshot filter to avoid killing tooling-daemon processes.
# PID reuse guard: cross-checks CreationDate — if the process occupying the
# parent PID was created AFTER the daemon, it's a recycled PID, not the real
# parent. WMI CreationDate has ~100ns resolution; using strict -lt (not -le)
# so a same-second parent is treated as alive (false negative is safer than
# false positive here).
Get-CimInstance Win32_Process -Filter "Name = 'dart.exe' OR Name = 'dartvm.exe'" |
  Where-Object { $_.CommandLine -like '*flutter_tools.snapshot*daemon*' } |
  ForEach-Object {
    $daemon = $_
    $orphaned = $true
    try {
      $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($daemon.ParentProcessId)" -ErrorAction Stop
      if ($parent -and $parent.CreationDate -lt $daemon.CreationDate) {
        $orphaned = $false
      }
    } catch {}
    if ($orphaned) { Stop-Process -Id $daemon.ProcessId -Force }
  }
```

**Diagnostic: test whether orphans accept graceful shutdown:**

The `daemon.shutdown` method is confirmed in Flutter SDK source
(`packages/flutter_tools/lib/src/commands/daemon.dart`). However, an
*existing* orphaned daemon cannot be reached via stdin from another
process — its stdin handle belongs to the dead parent. To test whether
the shutdown mechanism works at all:

```powershell
# Start a NEW daemon and immediately send shutdown to verify the protocol
$proc = Start-Process -FilePath 'D:\tools\flutter\bin\flutter.bat' `
  -ArgumentList 'daemon' -PassThru -NoNewWindow -RedirectStandardInput 'NUL'
Start-Sleep -Seconds 2
# If the daemon exits within a few seconds of stdin closing, it detects
# broken pipes and self-terminates. If it persists, Hypothesis A is confirmed.
if (-not $proc.HasExited) {
  Write-Host "CONFIRMED: daemon does NOT exit when stdin closes (Hypothesis A)"
  Stop-Process -Id $proc.Id -Force
} else {
  Write-Host "Daemon exited on stdin close — Hypothesis A is NOT the cause"
}
```

Since orphaned daemons cannot receive stdin commands, graceful shutdown
is not a viable cleanup path. Force-kill is the only option for orphans.

**Immediate mitigation (scheduled — breaks the feedback loop):**

Create a Windows Task Scheduler job that runs every 15 minutes to kill
orphaned daemons before they accumulate enough to trigger OOM.

Save the cleanup script to a stable path first (avoids inline escaping
issues in the task registration):

```powershell
# Step 1: Save cleanup script
$scriptPath = "$env:USERPROFILE\.flutter_daemon_cleanup.ps1"
@'
Get-CimInstance Win32_Process -Filter "Name = 'dart.exe' OR Name = 'dartvm.exe'" |
  Where-Object { $_.CommandLine -like '*flutter_tools.snapshot*daemon*' } |
  ForEach-Object {
    $daemon = $_
    $orphaned = $true
    try {
      $parent = Get-CimInstance Win32_Process -Filter "ProcessId = $($daemon.ParentProcessId)" -ErrorAction Stop
      if ($parent -and $parent.CreationDate -lt $daemon.CreationDate) {
        $orphaned = $false
      }
    } catch {}
    if ($orphaned) { Stop-Process -Id $daemon.ProcessId -Force }
  }
'@ | Set-Content -Path $scriptPath -Encoding UTF8

# Step 2: Register the task
$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes 15)
Register-ScheduledTask -TaskName 'Kill Orphaned Flutter Daemons' `
  -Action $action -Trigger $trigger `
  -Description 'Prevents orphaned flutter daemon accumulation (see infra_orphan_flutter_daemons_leak_memory.md)'
```

**Permanent fixes to investigate:**

1. **flutter_agent_lens — Job Object wrapper**: On Windows, assign spawned
   daemon processes to a Win32 Job Object with
   `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`. When the parent process
   (flutter_agent_lens) exits — cleanly or via crash — the OS kernel
   terminates all Job children automatically. No polling, no scheduled
   tasks, no PID reuse bugs. This is the standard Windows pattern for
   process trees that must die together (used by Chrome, VS Code, Docker).
   Implementation: call `CreateJobObject` + `SetInformationJobObject`
   (with `JOBOBJECT_EXTENDED_LIMIT_INFORMATION`) + `AssignProcessToJobObject`
   before spawning the daemon. Node.js options: `electron-job-addon` (npm,
   native addon with N-API bindings) or direct FFI via `ffi-napi` +
   `ref-napi` calling the Win32 API.
2. **flutter_agent_lens**: Should it also reuse an existing daemon instead
   of spawning a new one? Should it send `daemon.shutdown` on its own exit?
3. **VS Code Dart extension**: File upstream issue if daemon reuse is
   broken on Windows after extension host restarts.
4. **Flutter SDK upstream**: Report that `flutter daemon` doesn't detect
   parent death on Windows (broken stdin pipe not detected when blocked
   on event loop).

---

## Related

- [infra_analysis_server_7gb_memory_with_plugin.md](infra_analysis_server_7gb_memory_with_plugin.md) —
  the analysis server memory issue compounds with daemon orphans to exhaust
  system RAM.

---

## Impact Chain

```
orphan daemons accumulate (9+ GB Dart total)
  → system RAM drops below 5 GB free
    → context7 MCP server OOMs (FATAL ERROR: Zone Allocation failed)
    → flutter_agent_lens fails ("Not enough memory resources")
    → Claude Code extension host crashes
      → VS Code restarts extension host
        → new daemon spawned → orphan count increases
          → feedback loop
```

---

## Environment

- Flutter SDK: 3.44.8 stable (framework 058e0af2c2, 2026-07-23)
- Dart SDK: 3.12.2 (stable)
- VS Code with Dart extension v3.140.0
- flutter_agent_lens MCP server: v1.0.0
- OS: Windows 11 Pro, 32 GB RAM
- Claude Code: v2.1.197 (extension v2.1.224)
