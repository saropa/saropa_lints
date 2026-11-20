"""Best-effort VRAM report with per-app tips, shown before a Qwen run.

Why: qwen3:8b + its KV cache fills an 8 GB card almost exactly, so a browser or
editor holding 0.5-1 GB of VRAM decides whether parallel requests fit. This
prints who holds VRAM and how to release it. Report only — never kills or
changes anything. Every probe is best-effort: no nvidia-smi / non-Windows /
counter failure => returns None / prints nothing, never raises.
"""
from __future__ import annotations

import json
import subprocess
import sys

# Apps below this much dedicated VRAM are not worth mentioning.
_MIN_REPORT_MB = 100

# Process name (lowercase, no .exe) -> how to stop it using the GPU.
_TIPS: dict[str, str] = {
    "code": (
        "VS Code: Command Palette > 'Preferences: Configure Runtime Arguments', set "
        '"disable-hardware-acceleration": true in argv.json, then restart VS Code.'
    ),
    "firefox": (
        "Firefox: Settings > General > Performance > untick 'Use recommended performance "
        "settings' and 'Use hardware acceleration when available', then restart."
    ),
    "chrome": "Chrome: Settings > System > turn off 'Use graphics acceleration when available'.",
    "msedge": "Edge: Settings > System and performance > turn off 'Use graphics acceleration'.",
    "discord": "Discord: User Settings > Advanced > turn off 'Hardware Acceleration'.",
    "slack": "Slack: Preferences > Advanced > turn off 'Hardware acceleration'.",
    "teams": "Teams: Settings > General > tick 'Disable GPU hardware acceleration'.",
    "dwm": "Desktop Window Manager: always present; lower the display resolution/refresh rate to shrink it.",
}

# One PowerShell call: GPU dedicated memory per PID joined to process name.
_PS = (
    "$s=(Get-Counter '\\GPU Process Memory(*)\\Dedicated Usage' -ErrorAction Stop)"
    ".CounterSamples; $o=@{}; foreach($x in $s){ if($x.InstanceName -match '^pid_(\\d+)_')"
    "{ $o[[int]$Matches[1]]+=$x.CookedValue } }; $o.GetEnumerator()|ForEach-Object{ "
    "$p=Get-Process -Id $_.Key -ErrorAction SilentlyContinue; if($p){ [pscustomobject]"
    "@{name=$p.ProcessName;pid=$_.Key;mb=[math]::Round($_.Value/1MB)} } }|ConvertTo-Json -Compress"
)


def parse_apps(raw: str) -> dict[str, int]:
    """JSON from ``_PS`` -> {process name: total MB}, dropping tiny users."""
    try:
        data = json.loads(raw) if raw.strip() else []
    except ValueError:
        return {}
    if isinstance(data, dict):  # PowerShell emits a bare object for one row
        data = [data]
    totals: dict[str, int] = {}
    for row in data:
        try:
            name = str(row["name"]).lower()
            totals[name] = totals.get(name, 0) + int(row["mb"])
        except (KeyError, TypeError, ValueError):
            continue
    return {n: mb for n, mb in totals.items() if mb >= _MIN_REPORT_MB}


def _run(cmd: list[str]) -> str | None:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def _totals() -> tuple[int, int] | None:
    """(used MB, total MB) from nvidia-smi, or None."""
    out = _run(["nvidia-smi", "--query-gpu=memory.used,memory.total",
                "--format=csv,noheader,nounits"])
    try:
        used, total = (int(v) for v in (out or "").splitlines()[0].split(","))
    except (ValueError, IndexError):
        return None
    return used, total


def format_report(used: int, total: int, apps: dict[str, int]) -> list[str]:
    """Human lines: totals, top VRAM holders (largest first), a tip per known app."""
    lines = [f"[vram] {used} / {total} MB used, {total - used} MB free "
             f"(qwen3:8b needs ~6.7 GB; each extra parallel request ~0.5 GB)."]
    for name, mb in sorted(apps.items(), key=lambda kv: -kv[1]):
        lines.append(f"[vram]   {name}: {mb} MB")
        tip = _TIPS.get(name)
        if tip:
            lines.append(f"[vram]     tip: {tip}")
    # Windows' per-process counter reports memory ALLOCATED on the GPU, which
    # WDDM may overcommit (excess is paged to system RAM). When the sum exceeds
    # the card, say so: the per-app figures are then an upper bound, not resident MB.
    if sum(apps.values()) > total:
        lines.append("[vram] note: per-app figures total more than the card holds — "
                     "Windows counts allocations, and the excess is paged to RAM "
                     "(slows the GPU). Closing the largest holders frees real VRAM.")
    return lines


def print_vram_report() -> None:
    """Print the report; silent when the GPU cannot be queried."""
    totals = _totals()
    if totals is None:
        return
    apps: dict[str, int] = {}
    if sys.platform == "win32":
        apps = parse_apps(_run(["powershell", "-NoProfile", "-Command", _PS]) or "")
    for line in format_report(totals[0], totals[1], apps):
        print(line, flush=True)
