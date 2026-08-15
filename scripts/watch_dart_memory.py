#!/usr/bin/env python3
"""
Watch dart.exe memory usage live, for diagnosing the "Lint integration off
but dart.exe stays huge" bug (plans/history/2026.08/2026.08.13/
extension-lint-integration-off-still-analyzes.md).

Pairs with scripts/run_extension_local.py, which builds and launches the
Extension Development Host. This script only watches memory — run both in
separate terminals:

    python scripts/run_extension_local.py D:\\src\\saropa_kykto
    python scripts/watch_dart_memory.py

Then in the launched VS Code window: confirm "Lint integration" is on, let
dart.exe warm up, toggle it off, and watch the numbers below for a drop.

Windows only (uses tasklist). Press Ctrl+C to stop.

Version:   1.0
Author:    Saropa
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time


def _classify(cmdline: str) -> str:
    """Short human label for what a dart.exe process is doing."""
    low = cmdline.lower()
    if "language-server" in low or "analysis_server" in low:
        return "ANALYSIS SERVER"
    if "saropa_lints" in low:
        # e.g. dart run saropa_lints:scan / project_vibrancy / project_health
        for tool in ("scan", "project_vibrancy", "project_health", "write_config", "init"):
            if tool in low:
                return f"saropa_lints:{tool}"
        return "saropa_lints (other)"
    if " analyze" in low:
        return "dart analyze"
    if "flutter_tools" in low:
        return "flutter tool"
    if "frontend_server" in low or "dartdev" in low:
        return "compiler/frontend"
    return "other"


def dart_exe_memory_mb() -> tuple[int, list[tuple[int, int, str, str]]]:
    """Return (total_mb, [(pid, mb, label, cmdline), ...]) for all dart.exe processes.

    Uses CIM instead of tasklist so each process's command line is available —
    without it, the analysis server is indistinguishable from extension-spawned
    scanners, and the whole point is attributing memory to the right feature.
    """
    ps_script = (
        "Get-CimInstance Win32_Process -Filter \"Name='dart.exe'\" | "
        "Select-Object ProcessId,WorkingSetSize,CommandLine | ConvertTo-Json -Compress"
    )
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-Command", ps_script],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    raw = (result.stdout or "").strip()
    total = 0
    procs: list[tuple[int, int, str, str]] = []
    if not raw:
        return 0, []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return 0, []
    if isinstance(data, dict):  # single process → bare object
        data = [data]
    for item in data:
        if not isinstance(item, dict):
            continue
        pid = item.get("ProcessId")
        ws = item.get("WorkingSetSize")
        cmd = item.get("CommandLine") or ""
        if not isinstance(pid, int) or not isinstance(ws, (int, float)):
            continue
        mem_mb = int(ws) // (1024 * 1024)
        procs.append((pid, mem_mb, _classify(cmd), cmd))
        total += mem_mb
    procs.sort(key=lambda p: -p[1])
    return total, procs


def watch(interval_seconds: int) -> None:
    if sys.platform != "win32":
        print("This script only works on Windows (uses tasklist).", file=sys.stderr)
        raise SystemExit(1)

    print("Watching dart.exe memory — Ctrl+C to stop.")
    try:
        while True:
            total, procs = dart_exe_memory_mb()
            timestamp = time.strftime("%H:%M:%S")
            print(f"\n[{timestamp}]  total: {total:,} MB across {len(procs)} dart.exe process(es)")
            for pid, mb, label, cmd in procs:
                # Tail of the command line carries the useful part (tool + project path).
                tail = cmd[-100:] if len(cmd) > 100 else cmd
                print(f"  {mb:>6} MB  pid {pid:<7} {label:<18} …{tail}" if len(cmd) > 100
                      else f"  {mb:>6} MB  pid {pid:<7} {label:<18} {tail}")
            time.sleep(interval_seconds)
    except KeyboardInterrupt:
        print("\nStopped.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--interval", type=int, default=5, help="Seconds between memory readings (default 5)"
    )
    args = parser.parse_args()
    watch(args.interval)


if __name__ == "__main__":
    main()
