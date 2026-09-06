#!/usr/bin/env python3
"""Qwen 3 offline machine-translation engine for the extension i18n pipeline.

Calls the local Ollama daemon's native /api/chat endpoint (localhost:11434)
with a GPU-selected model from the Qwen 3 ladder (14B / 8B / 4B). Returns
translated strings or None per item so the caller can fall back to Google.

Ported from the saropa.com website pipeline (``scripts/modules/i18n/i18n_qwen.py``).
Simplified to the 3-function public API that ``mt_fallback.py`` expects:

  qwen_lang_code(locale)       -> BCP-47 code or None (all shipped locales supported)
  qwen_model_available()       -> True when Ollama is up AND model is pulled
  qwen_translate(text, locale) -> translated string, or None to fall back

Environment variables:
  SAROPA_QWEN_MODEL       Pin a specific Ollama model tag (default: auto by VRAM).
  SAROPA_QWEN_TIMEOUT     Per-call timeout in seconds (default 90, clamped [15,600]).
  SAROPA_SKIP_QWEN=1      Disable Qwen entirely (pipeline uses Google only).
  SAROPA_QWEN_KEEP_ALIVE  How long Ollama keeps the model resident between calls
                          (default "5m"). The run unloads explicitly when it
                          finishes, so this only covers gaps mid-run.

Process-hygiene opt-ins (all default OFF — see "Process hygiene" below):
  SAROPA_QWEN_ALLOW_GLOBAL_KILL=1  Permit killing every ``ollama`` process on the
                          machine by image name. DESTRUCTIVE: this terminates
                          daemons other people/tools are serving from. Only set
                          it when you know this machine runs Ollama for nothing
                          but this pipeline.
  SAROPA_QWEN_REAP_ORPHANS=1  Let the preflight terminate orphaned model-host
                          processes it finds instead of refusing to start.

Process hygiene (see bugs/infra_translation_engine_orphans_llama_server_processes.md):
  Ollama's daemon (``ollama``) is not the process that holds the model. It spawns
  a separate model host (``llama-server``) that commits 9-16 GB. Killing only the
  daemon strands that child forever: on Windows ``taskkill /F`` without ``/T``
  does not walk the tree, and on POSIX a plain ``kill`` reaches one PID. Three
  such orphans were once found holding 37 GB and crashing the editor. Every kill
  path in this module therefore terminates the whole tree, and a sweep reaps any
  model host whose parent is gone as a backstop.

  "Parent is gone" is deliberately expensive to prove: a host must be absent
  from the process-table snapshot AND fail a direct liveness probe of its parent
  PID. A snapshot alone is not enough, because a dropped or unparsable row makes
  a live daemon's child look parentless, and killing that is the incident.

  Ownership, not the port, decides what may be stopped. A daemon this run did
  not start is used as-is when it is already serving — an operator running their
  own ``ollama serve`` is a normal, supported setup — but it is never adopted,
  so no teardown path can reach it.
"""

from __future__ import annotations

import atexit
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.request
from collections import deque
from typing import NamedTuple

# ---------------------------------------------------------------------------
# Ollama endpoint
# ---------------------------------------------------------------------------
_OLLAMA_BASE = "http://localhost:11434"

# ---------------------------------------------------------------------------
# LLM output sanitization — strips control tokens that leak into translations
# ---------------------------------------------------------------------------
_LLM_DIRECTIVES = [
    "/no_think", "/think", "/end", "/start",
    "/reset", "/continue", "/stop", "/system",
]
_LLM_DIRECTIVE_RE = re.compile(
    r"\s*(?:" + "|".join(re.escape(d) for d in _LLM_DIRECTIVES) + r")\b",
)
_LLM_CONTROL_TAGS = [
    "<|endoftext|>", "<|im_start|>", "<|im_end|>",
    "<|im_sep|>", "<|endofprompt|>",
    "<|assistant|>", "<|user|>", "<|system|>",
    "[INST]", "[/INST]", "<<SYS>>", "<</SYS>>",
]
_LLM_TAG_RE = re.compile(
    "|".join(re.escape(t) for t in _LLM_CONTROL_TAGS),
)

# ---------------------------------------------------------------------------
# Model ladder — GPU-aware selection
# ---------------------------------------------------------------------------
_QWEN_MODEL_LADDER: list[tuple[str, str, str, float]] = [
    ("qwen3:14b", "qwen3_14b_local", "~9.3 GB", 11.0),
    ("qwen3:8b", "qwen3_8b_local", "~5.2 GB", 6.7),
    ("qwen3:4b", "qwen3_4b_local", "~2.6 GB", 3.6),
]

# Locales the extension ships — Qwen handles all of them.
_SUPPORTED_LOCALES = frozenset({
    "ar", "bn", "de", "es", "fa", "fil", "fr", "he", "hi", "id",
    "it", "ja", "ko", "nl", "pl", "pt", "ru", "sw", "th", "tr",
    "uk", "ur", "vi", "zh",
})

# Language names + script constraints for prompt quality.
_LOCALE_LANGUAGE_NAMES: dict[str, str] = {
    "ar": "Arabic (العربية, Arabic script)",
    "bn": "Bengali (বাংলা, Bengali script)",
    "de": "German (Deutsch, Latin script)",
    "es": "Spanish (Español, Latin script)",
    "fa": "Persian/Farsi (فارسی, Arabic script)",
    "fil": "Filipino/Tagalog (Latin script)",
    "fr": "French (Français, Latin script)",
    "he": "Hebrew (עברית, Hebrew script)",
    "hi": "Hindi (हिन्दी, Devanagari script)",
    "id": "Indonesian (Bahasa Indonesia, Latin script)",
    "it": "Italian (Italiano, Latin script)",
    "ja": "Japanese (日本語, Kanji/Hiragana/Katakana)",
    "ko": "Korean (한국어, Hangul script)",
    "nl": "Dutch (Nederlands, Latin script)",
    "pl": "Polish (Polski, Latin script)",
    "pt": "Portuguese (Português, Latin script)",
    "ru": "Russian (Русский, Cyrillic script)",
    "sw": "Swahili (Kiswahili, Latin script)",
    "th": "Thai (ไทย, Thai script)",
    "tr": "Turkish (Türkçe, Latin script)",
    "uk": "Ukrainian (Українська, Cyrillic script)",
    "ur": "Urdu (اردو, Arabic/Nastaliq script)",
    "vi": "Vietnamese (Tiếng Việt, Latin script)",
    "zh": "Chinese Simplified (简体中文, CJK characters)",
}

# Non-Latin targets get a hard single-script constraint.
_TARGET_SCRIPT_NAME: dict[str, str] = {
    "ar": "Arabic",
    "fa": "Persian (Arabic script)",
    "ur": "Urdu (Arabic script)",
    "bn": "Bengali",
    "he": "Hebrew",
    "hi": "Devanagari",
    "ja": "Japanese (Kanji, Hiragana, or Katakana)",
    "ko": "Korean Hangul",
    "ru": "Cyrillic",
    "uk": "Cyrillic",
    "th": "Thai",
    "zh": "Chinese (Simplified Han)",
}


# ---------------------------------------------------------------------------
# GPU detection + model selection
# ---------------------------------------------------------------------------

def _detect_gpu_vram_gb() -> float | None:
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=10, check=False,
        )
        if out.returncode != 0:
            return None
        first = (out.stdout or "").strip().splitlines()
        return float(first[0].strip()) / 1024.0 if first else None
    except Exception:  # noqa: BLE001
        return None


def _select_qwen_model() -> tuple[str, str, str, str]:
    """Pick (tag, stamp, pull_size, note) for this machine."""
    override = os.environ.get("SAROPA_QWEN_MODEL", "").strip()
    if override:
        for tag, stamp, size, _need in _QWEN_MODEL_LADDER:
            if tag == override:
                return tag, stamp, size, f"pinned via SAROPA_QWEN_MODEL ({tag})"
        safe = re.sub(r"[^a-z0-9]+", "_", override.lower()).strip("_")
        return override, f"{safe}_local", "?", (
            f"pinned via SAROPA_QWEN_MODEL ({override}, unknown size)"
        )
    vram = _detect_gpu_vram_gb()
    if vram is None:
        tag, stamp, size, _need = _QWEN_MODEL_LADDER[1]
        return tag, stamp, size, "no NVIDIA GPU detected — using mid-ladder default"
    for tag, stamp, size, need in _QWEN_MODEL_LADDER:
        if vram >= need:
            return tag, stamp, size, (
                f"GPU {vram:.1f} GB VRAM → {tag} (needs ~{need:.1f} GB)"
            )
    tag, stamp, size, need = _QWEN_MODEL_LADDER[-1]
    return tag, stamp, size, (
        f"GPU {vram:.1f} GB VRAM below smallest requirement — using {tag}"
    )


_qwen_model_cache: tuple[str, str, str, str] | None = None


def _get_qwen_model() -> tuple[str, str, str, str]:
    """Lazy model selection — defers nvidia-smi subprocess until first use."""
    global _qwen_model_cache
    if _qwen_model_cache is None:
        _qwen_model_cache = _select_qwen_model()
    return _qwen_model_cache


def _model_tag() -> str:
    return _get_qwen_model()[0]


def _model_stamp() -> str:
    return _get_qwen_model()[1]


def _model_pull_size() -> str:
    return _get_qwen_model()[2]


def _model_selection_note() -> str:
    return _get_qwen_model()[3]


# ---------------------------------------------------------------------------
# Circuit breaker — sliding window + consecutive counter
# ---------------------------------------------------------------------------
_WINDOW_SIZE: int = 20
_WINDOW_RATIO_THRESHOLD: float = 0.50
_CONSECUTIVE_THRESHOLD: int = 6
_COOLDOWN_KEYS: int = 40
_qwen_state_lock = threading.Lock()
_qwen_window: deque[bool] = deque(maxlen=_WINDOW_SIZE)
_qwen_consecutive_failures: int = 0
_qwen_cooldown_remaining: int = 0


def _reset_circuit() -> None:
    global _qwen_consecutive_failures, _qwen_cooldown_remaining  # noqa: PLW0603
    with _qwen_state_lock:
        _qwen_window.clear()
        _qwen_consecutive_failures = 0
        _qwen_cooldown_remaining = 0


def _record_outcome(success: bool) -> bool:
    global _qwen_consecutive_failures, _qwen_cooldown_remaining  # noqa: PLW0603
    with _qwen_state_lock:
        _qwen_window.append(success)
        if success:
            _qwen_consecutive_failures = 0
            return False
        _qwen_consecutive_failures += 1
        if _qwen_consecutive_failures >= _CONSECUTIVE_THRESHOLD:
            _qwen_cooldown_remaining = _COOLDOWN_KEYS
            _qwen_consecutive_failures = 0
            return True
        if len(_qwen_window) >= _WINDOW_SIZE:
            fail_count = sum(1 for ok in _qwen_window if not ok)
            if fail_count / len(_qwen_window) >= _WINDOW_RATIO_THRESHOLD:
                _qwen_cooldown_remaining = _COOLDOWN_KEYS
                _qwen_consecutive_failures = 0
                _qwen_window.clear()
                return True
        return False


# ---------------------------------------------------------------------------
# Stall detection
# ---------------------------------------------------------------------------
_MAX_RESTARTS_PER_LOCALE: int = 4
_STALL_THRESHOLD_S: float = 120.0
_restarts_this_run: int = 0


def _stall_threshold() -> float:
    raw = os.environ.get("SAROPA_QWEN_TIMEOUT", "90").strip() or "90"
    timeout = max(15.0, min(600.0, float(raw)))
    return max(_STALL_THRESHOLD_S, timeout + 30.0)


def reset_run_state() -> None:
    global _restarts_this_run  # noqa: PLW0603
    _restarts_this_run = 0
    _reset_circuit()


# ---------------------------------------------------------------------------
# Daemon management
# ---------------------------------------------------------------------------
# PID of the daemon THIS run started, or None when we are talking to a daemon
# somebody else started. Ownership is the safety boundary for every teardown
# decision below: we only ever stop a daemon we spawned.
_daemon_pid: int | None = None

# Set once the atexit teardown is registered, so restarts do not stack handlers.
_atexit_registered: bool = False


def _adopt_daemon(pid: int) -> None:
    """Record that this run owns the daemon at ``pid`` and must clean it up.

    Registering teardown at adoption time (rather than at import) means a run
    that never starts a daemon never installs a handler that could touch someone
    else's process. The daemon is spawned fully detached (DETACHED_PROCESS /
    start_new_session), so nothing else ties its lifetime to this script —
    this handler is the only thing that will ever reap it.
    """
    global _daemon_pid, _atexit_registered  # noqa: PLW0603
    _daemon_pid = pid
    if not _atexit_registered:
        atexit.register(shutdown_engine)
        _atexit_registered = True


def _daemon_popen_kwargs(ollama_bin: str) -> dict[str, object]:
    env = os.environ.copy()
    env["OLLAMA_NUM_PARALLEL"] = "1"
    kw: dict[str, object] = {
        "stdout": subprocess.DEVNULL,
        "stderr": subprocess.DEVNULL,
        "stdin": subprocess.DEVNULL,
        "env": env,
    }
    if sys.platform == "win32":
        kw["creationflags"] = 0x00000008 | 0x00000200
    else:
        kw["start_new_session"] = True
    return kw


def _endpoint_up(timeout_s: float = 2.0) -> bool:
    try:
        with urllib.request.urlopen(
            f"{_OLLAMA_BASE}/api/version", timeout=timeout_s
        ) as resp:
            return resp.status == 200
    except Exception:  # noqa: BLE001
        return False


def _has_model(timeout_s: float = 5.0) -> bool:
    try:
        with urllib.request.urlopen(
            f"{_OLLAMA_BASE}/api/tags", timeout=timeout_s
        ) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:  # noqa: BLE001
        return False
    models = data.get("models", [])
    if not isinstance(models, list):
        return False
    return any(str(m.get("name", "")) == _model_tag() for m in models)


# ---------------------------------------------------------------------------
# Process hygiene — tree termination, orphan detection, orphan reaping
#
# WHY this whole section exists: the Ollama daemon is a thin supervisor. The
# memory lives in a separate ``llama-server`` child. Terminating the daemon
# alone leaves that child running with the model committed and no parent left
# to ever reap it, so the leak is permanent for the machine's uptime and
# compounds one orphan per affected run.
# ---------------------------------------------------------------------------

# Image names Ollama has used for its model host across versions. Compared
# case-folded and with any ``.exe`` suffix stripped, so one set covers both
# platforms.
_MODEL_HOST_NAMES = frozenset({
    "llama-server", "ollama_llama_server", "ollama-llama-server",
})

# How long a graceful shutdown gets before escalating to a force kill. A force
# kill is what strands the child in the first place, so it is the last resort,
# not the first move.
_GRACEFUL_WAIT_S: float = 6.0


class _ProcInfo(NamedTuple):
    """One row of a process-table snapshot.

    ``commit_bytes`` is committed/pagefile-backed memory on Windows and RSS on
    POSIX. It is only ever used to *report* how much an orphan is holding, never
    to decide whether to kill it — memory size is not evidence of ownership.
    """

    pid: int
    ppid: int
    name: str
    commit_bytes: int


def _env_flag(name: str) -> bool:
    """True only for an explicit opt-in value.

    Deliberately strict: every flag routed through here gates something that
    terminates processes, so an ambiguous value must read as "no".
    """
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def _normalize_image(name: str) -> str:
    """Reduce an OS process name to a comparable key.

    Windows reports ``llama-server.exe``; POSIX ``ps -o comm=`` may report a
    full path. Strip both so one name set matches on either platform.
    """
    base = os.path.basename((name or "").strip()).lower()
    return base[:-4] if base.endswith(".exe") else base


def _is_model_host(name: str) -> bool:
    """True when this process name is one of Ollama's model hosts."""
    return _normalize_image(name) in _MODEL_HOST_NAMES


def _snapshot_processes() -> list[_ProcInfo] | None:
    """Enumerate live processes with parent PID and memory, or None on failure.

    Returning None rather than an empty list on failure is load-bearing: callers
    must be able to tell "there are no orphans" apart from "I could not look".
    Every kill decision in this module is skipped when we could not look, so an
    enumeration failure can never be mistaken for evidence to terminate.
    """
    try:
        if sys.platform == "win32":
            return _snapshot_processes_windows()
        return _snapshot_processes_posix()
    except Exception:  # noqa: BLE001 — enumeration is best-effort, never fatal
        return None


def _snapshot_processes_windows() -> list[_ProcInfo] | None:
    """Snapshot via CIM. ``wmic`` is removed from current Windows, so use CIM."""
    shell = shutil.which("powershell") or shutil.which("pwsh")
    if not shell:
        return None
    out = subprocess.run(  # noqa: S603
        [
            shell, "-NoProfile", "-NonInteractive", "-Command",
            "Get-CimInstance Win32_Process | Select-Object "
            "ProcessId,ParentProcessId,Name,PageFileUsage | ConvertTo-Json -Compress",
        ],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=60, check=False,
    )
    if out.returncode != 0 or not (out.stdout or "").strip():
        return None
    rows = json.loads(out.stdout)
    # ConvertTo-Json emits a bare object, not an array, when exactly one row
    # matches. Normalizing here keeps the parse below single-shaped.
    if isinstance(rows, dict):
        rows = [rows]
    procs: list[_ProcInfo] = []
    for row in rows:
        try:
            procs.append(_ProcInfo(
                pid=int(row["ProcessId"]),
                # A missing/null ParentProcessId degrades to 0, which is not a
                # usable PID on Windows. That is deliberately safe now:
                # _parent_confirmed_gone rejects ppid <= 0 as "unknown", so an
                # unreadable parent field can never nominate a live daemon's
                # child for termination.
                ppid=int(row.get("ParentProcessId") or 0),
                name=str(row.get("Name") or ""),
                # PageFileUsage is KiB of commit — the figure that actually
                # exhausted the machine in the reported incident.
                commit_bytes=int(row.get("PageFileUsage") or 0) * 1024,
            ))
        except (TypeError, ValueError, KeyError):
            continue  # A malformed row is not worth failing the whole snapshot.
    return procs


def _snapshot_processes_posix() -> list[_ProcInfo] | None:
    """Snapshot via ``ps``. RSS stands in for commit; it is display-only."""
    out = subprocess.run(  # noqa: S603
        ["ps", "-eo", "pid=,ppid=,rss=,comm="],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
        timeout=30, check=False,
    )
    if out.returncode != 0:
        return None
    procs: list[_ProcInfo] = []
    for line in (out.stdout or "").splitlines():
        # comm can contain spaces, so split only the three leading numeric
        # columns and keep the remainder as the name.
        parts = line.split(None, 3)
        if len(parts) < 4:
            continue
        try:
            procs.append(_ProcInfo(
                pid=int(parts[0]), ppid=int(parts[1]),
                name=parts[3].strip(), commit_bytes=int(parts[2]) * 1024,
            ))
        except ValueError:
            continue
    return procs


def find_orphan_model_hosts() -> list[_ProcInfo] | None:
    """Model-host processes whose parent no longer exists. None if unknowable.

    SAFETY — this is the single decision point for "may this process be killed":

    * A host whose parent is still alive is EXCLUDED. That parent is a running
      daemon which may be serving a live client (possibly not us at all), and
      killing its model host is exactly the failure this module exists to
      prevent.
    * PID reuse can only make a dead parent look alive, never the reverse — the
      OS will not hand a recycled PID to nothing. So this test errs toward
      leaving processes alone, which is the safe direction.
    * A failed snapshot yields None, not an empty list, so no caller can read
      "could not look" as "nothing to kill" or as permission to kill.
    * Absence from the snapshot only NOMINATES a host. The kill is authorized
      by [_parent_confirmed_gone], a direct probe that must answer "gone"
      explicitly. Without that second step a dropped or unparsable snapshot row
      would silently promote a live daemon's child to an orphan.

    The probe runs once per candidate, and on a healthy machine there are no
    candidates, so the common case costs nothing beyond the snapshot.
    """
    procs = _snapshot_processes()
    if procs is None:
        return None
    live_pids = {p.pid for p in procs}
    candidates = [
        p for p in procs
        if _is_model_host(p.name) and p.ppid not in live_pids
    ]
    return [p for p in candidates if _parent_confirmed_gone(p.ppid)]


def _describe_orphans(orphans: list[_ProcInfo]) -> str:
    """One-line human summary used by both the preflight and the sweep."""
    total_gb = sum(p.commit_bytes for p in orphans) / (1024 ** 3)
    detail = ", ".join(
        f"PID {p.pid} ({p.commit_bytes / (1024 ** 3):.1f} GB)" for p in orphans
    )
    return f"{len(orphans)} orphaned model host(s) holding {total_gb:.1f} GB — {detail}"


def _pid_liveness(pid: int) -> bool | None:
    """Tri-state single-PID probe: True alive, False CONFIRMED gone, None unknown.

    The third state is the whole point. A two-state probe has to fold "the
    query failed" into one of the answers, and folding it into "gone" is what
    turns a broken ``tasklist`` or a sandboxed ``os.kill`` into permission to
    terminate somebody else's process. Every caller that could kill something
    therefore demands an explicit False; only the polling loop, which merely
    decides how long to wait, treats None as "still there".

    ``pid <= 0`` is rejected outright rather than probed: 0 and negative values
    are not process identifiers on either platform (POSIX reads them as process
    *group* selectors), so there is nothing here to confirm dead.
    """
    if pid <= 0:
        return None
    if sys.platform == "win32":
        try:
            out = subprocess.run(  # noqa: S603
                ["tasklist", "/FI", f"PID eq {pid}", "/NH", "/FO", "CSV"],
                capture_output=True, text=True, encoding="utf-8",
                errors="replace", timeout=10, check=False,
            )
        except (OSError, subprocess.SubprocessError):
            # tasklist missing, blocked, or timed out. We learned nothing.
            return None
        if out.returncode != 0:
            return None
        text = (out.stdout or "").strip()
        # The /FI filter guarantees at most the one matching row, so the CSV
        # quoting is what distinguishes a real row from the "INFO: No tasks are
        # running which match the specified criteria." banner. Matching the
        # quoted PID field avoids the substring trap where a PID's digits also
        # appear inside another column (e.g. "1,242 K" contains "42").
        if not text or text.upper().startswith("INFO:"):
            return False
        return f'"{pid}"' in text
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        # Exists but belongs to another user — alive as far as we are concerned.
        return True
    except OSError:
        # Anything else (EINVAL, a sandbox denying the syscall outright) is an
        # answer we did not get, not an answer of "dead".
        return None
    return True


def _pid_alive(pid: int) -> bool:
    """Two-state view of [_pid_liveness] for the graceful/force wait loop.

    Unknown counts as alive here on purpose: this only gates how long we keep
    polling, and over-waiting is harmless where under-waiting would report a
    kill as successful without evidence.
    """
    return _pid_liveness(pid) is not False


def _parent_confirmed_gone(ppid: int) -> bool:
    """True only when [ppid] is POSITIVELY known not to exist.

    Absence from a process-table snapshot is NOT sufficient evidence on its own.
    A snapshot can lose a row: the Windows parser drops any row whose fields do
    not parse, ``ps`` output can be truncated mid-write, and a parent that
    exited and was replaced between two reads leaves a hole. Every one of those
    makes a *live* daemon's child look parentless, and acting on that would kill
    the model host of a daemon that is serving right now — the exact incident
    this module exists to prevent.

    So the snapshot only nominates candidates; this direct probe is what
    authorizes the kill, and it authorizes it only on an explicit False. Unknown
    and alive both mean "leave it alone".
    """
    return _pid_liveness(ppid) is False


def _wait_pid_gone(pid: int, timeout_s: float) -> bool:
    """Poll until the PID disappears. True if it went away within the budget."""
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if not _pid_alive(pid):
            return True
        time.sleep(0.25)
    return not _pid_alive(pid)


def _terminate_tree(pid: int, *, log=None) -> bool:
    """Terminate a process AND its children, graceful first, force second.

    The tree part is the actual bug fix: ``taskkill /PID n /F`` (no ``/T``)
    terminates one process, so Ollama's ``llama-server`` child outlived every
    kill this module issued. ``/T`` walks the tree; on POSIX the equivalent is
    signalling the process group, which the daemon leads because it is spawned
    with ``start_new_session=True``.

    Graceful first matters for the same reason: a forced kill gives the daemon
    no chance to shut its own child down, so the force path is only reached
    after the polite one has demonstrably failed.
    """
    say = log or (lambda _m: None)
    if sys.platform == "win32":
        # No /F: ask the tree to close. /T is what reaches llama-server.
        subprocess.run(  # noqa: S603
            ["taskkill", "/PID", str(pid), "/T"],
            capture_output=True, timeout=15, check=False,
        )
        if _wait_pid_gone(pid, _GRACEFUL_WAIT_S):
            return True
        say(f"    [ollama] PID {pid} ignored graceful close — forcing tree kill")
        subprocess.run(  # noqa: S603
            ["taskkill", "/PID", str(pid), "/T", "/F"],
            capture_output=True, timeout=15, check=False,
        )
        return _wait_pid_gone(pid, 3.0)

    # POSIX: signal the whole group (negative PID) so the model host dies with
    # the daemon. Fall back to the bare PID if the process is not a group leader
    # (it should be, via start_new_session, but a caller may pass any PID).
    for sig, label in ((signal.SIGTERM, "TERM"), (signal.SIGKILL, "KILL")):
        try:
            os.killpg(pid, sig)
        except (ProcessLookupError, PermissionError, OSError):
            try:
                os.kill(pid, sig)
            except (ProcessLookupError, PermissionError):
                return True
        grace = _GRACEFUL_WAIT_S if sig == signal.SIGTERM else 3.0
        if _wait_pid_gone(pid, grace):
            return True
        say(f"    [ollama] PID {pid} survived SIG{label}")
    return not _pid_alive(pid)


def sweep_orphan_model_hosts(*, log=None, require_daemon_down: bool = True) -> int:
    """Reap model hosts whose parent is gone. Returns how many were terminated.

    This is the only reliable backstop. A daemon that dies any other way — crash,
    Task Manager, an OS shutdown of the wrong process — strands its model host
    identically, and no amount of care on our own kill paths covers that.

    SAFETY: by default this refuses to run while the Ollama endpoint answers,
    because a responding daemon means a live client could be mid-request. Only
    parentless hosts are ever touched (see ``find_orphan_model_hosts``), and a
    snapshot failure aborts the sweep rather than guessing.
    """
    say = log or (lambda _m: None)
    if require_daemon_down and _endpoint_up(timeout_s=1.0):
        # A serving daemon is exactly what must not be disturbed — killing one
        # is what caused the incident this function was written for.
        say("    [ollama] sweep skipped — a daemon is still serving on the port")
        return 0
    orphans = find_orphan_model_hosts()
    if not orphans:
        # None (could not enumerate) and [] (nothing to do) both mean "do not kill".
        return 0
    say(f"    [ollama] reaping {_describe_orphans(orphans)}")
    reaped = 0
    for proc in orphans:
        if _terminate_tree(proc.pid, log=say):
            reaped += 1
        else:
            say(f"    [ollama] could not terminate orphan PID {proc.pid}")
    return reaped


def preflight_orphan_check(*, log=None) -> tuple[bool, str]:
    """Refuse to start when orphaned model hosts are already holding memory.

    Starting another run on top of existing orphans is how three of them reached
    37 GB: each run adds one and nothing ever reports the accumulation. Surfacing
    it here converts a silent leak into a visible, actionable stop.

    Terminating pre-existing orphans is opt-in (``SAROPA_QWEN_REAP_ORPHANS=1``)
    because they were not created by this run — the operator must say so.
    """
    say = log or (lambda _m: None)
    orphans = find_orphan_model_hosts()
    if orphans is None:
        # Could not enumerate. Not a reason to block a translation run; the
        # end-of-run sweep will try again.
        return True, "process table unavailable — orphan preflight skipped"
    if not orphans:
        return True, "no orphaned model hosts"

    summary = _describe_orphans(orphans)
    if _env_flag("SAROPA_QWEN_REAP_ORPHANS"):
        say(f"[Ollama/Qwen] preflight: {summary} — reaping (SAROPA_QWEN_REAP_ORPHANS=1)")
        # These are parentless by definition, so no daemon owns them and the
        # endpoint check would only block a legitimate cleanup here.
        reaped = sweep_orphan_model_hosts(log=say, require_daemon_down=False)
        remaining = find_orphan_model_hosts() or []
        if remaining:
            return False, (
                f"reaped {reaped}, but {_describe_orphans(remaining)} remain — "
                "terminate them manually before re-running"
            )
        return True, f"reaped {reaped} orphaned model host(s) before starting"

    return False, (
        f"{summary}. These are leaked from an earlier run and will keep that "
        "memory committed until they are terminated. Kill them (Windows: "
        "Stop-Process -Name llama-server -Force; POSIX: pkill -f llama-server) "
        "or re-run with SAROPA_QWEN_REAP_ORPHANS=1 to have this script do it."
    )


def _kill_all_ollama(*, log=None) -> bool:
    """Kill every Ollama process on the machine, by image name. OPT-IN ONLY.

    SAFETY: this is machine-wide and cannot tell our daemon from one another
    tool, another user, or an interactive session is actively serving from.
    Killing a serving daemon is precisely what produced the original incident,
    so it is gated behind ``SAROPA_QWEN_ALLOW_GLOBAL_KILL=1`` and is never a
    side effect of a normal run. Returns True only when the kill actually ran.

    When it does run it uses ``/T`` (Windows) and the ``-f`` pattern that also
    matches the model host (POSIX), so it no longer strands children.
    """
    say = log or (lambda _m: None)
    if not _env_flag("SAROPA_QWEN_ALLOW_GLOBAL_KILL"):
        say(
            "    [ollama] refusing machine-wide kill — the daemon on this port "
            "was not started by this run and may be serving another client. "
            "Set SAROPA_QWEN_ALLOW_GLOBAL_KILL=1 if this machine runs Ollama "
            "only for this pipeline."
        )
        return False
    if sys.platform == "win32":
        # /T is the fix: without it llama-server.exe survives its parent.
        subprocess.run(  # noqa: S603
            ["taskkill", "/IM", "ollama.exe", "/T", "/F"],
            capture_output=True, timeout=15, check=False,
        )
    else:
        # SIGTERM first so daemons can stop their own model hosts; the sweep
        # below catches anything that did not.
        subprocess.run(  # noqa: S603
            ["pkill", "-f", "ollama serve"],
            capture_output=True, timeout=15, check=False,
        )
    # Whatever the kill missed is now parentless, so the sweep can reach it.
    sweep_orphan_model_hosts(log=say)
    return True


def _wait_for_port_down(timeout_s: float = 8.0) -> bool:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if not _endpoint_up(timeout_s=1.0):
            return True
        time.sleep(0.5)
    return False


def restart_ollama(*, log=print) -> bool:
    # _daemon_pid is only read here now; ownership is recorded by _adopt_daemon.
    global _restarts_this_run  # noqa: PLW0603
    ollama = shutil.which("ollama")
    if not ollama:
        log("    [stall] cannot restart — ollama not on PATH")
        return False
    if _restarts_this_run >= _MAX_RESTARTS_PER_LOCALE:
        log("    [stall] restart cap reached — skipping")
        return False

    # Graceful step one: ask Ollama to unload the model. This is what actually
    # releases the multi-GB commit, and it lets the daemon retire its own model
    # host instead of us having to terminate it.
    try:
        subprocess.run(  # noqa: S603
            [ollama, "stop", _model_tag()],
            capture_output=True, timeout=10, check=False,
        )
    except subprocess.TimeoutExpired:
        pass
    time.sleep(0.5)

    if _daemon_pid is not None:
        # We started this daemon, so we may stop it — as a TREE. The previous
        # single-PID force kill left llama-server running with the model still
        # committed and no parent to ever reap it.
        _terminate_tree(_daemon_pid, log=log)
    else:
        # We did NOT start the daemon holding this port. Terminating it would
        # kill whatever client it is serving, which is the original incident.
        # _kill_all_ollama is opt-in and no-ops unless the operator allowed it.
        _kill_all_ollama(log=log)
    time.sleep(1.0)

    # Backstop: whatever the teardown above missed is now parentless, so reap it
    # before starting a replacement daemon that would add a second model host.
    sweep_orphan_model_hosts(log=log)

    for attempt in range(2):
        try:
            proc = subprocess.Popen(  # noqa: S603
                [ollama, "serve"], **_daemon_popen_kwargs(ollama),
            )
        except Exception as exc:  # noqa: BLE001
            log(f"    [stall] `ollama serve` failed: {exc}")
            return False

        deadline = time.monotonic() + 30.0
        while time.monotonic() < deadline:
            if _endpoint_up():
                break
            time.sleep(0.5)
        else:
            log("    [stall] Ollama did not come up within 30s after restart")
            _restarts_this_run += 1
            return False

        time.sleep(1.5)

        if proc.poll() is None:
            _adopt_daemon(proc.pid)
            _reset_circuit()
            _restarts_this_run += 1
            log(
                f"    [stall] Ollama restarted "
                f"({_restarts_this_run}/{_MAX_RESTARTS_PER_LOCALE})"
            )
            return True

        if attempt == 0:
            # Another daemon owns the port. Displacing it is machine-wide and
            # opt-in; when it is not allowed, _kill_all_ollama logs why and this
            # retry simply fails, which is the safe outcome.
            log("    [stall] our daemon exited (port conflict) — attempting rival teardown")
            if _kill_all_ollama(log=log):
                _wait_for_port_down(timeout_s=8.0)
                sweep_orphan_model_hosts(log=log)

    log("    [stall] could not start daemon — port repeatedly claimed by another instance")
    _restarts_this_run += 1
    return False


def _ensure_ready() -> tuple[bool, str]:
    ollama = shutil.which("ollama")
    if not ollama:
        return False, (
            "Ollama is not installed — install from https://ollama.com/download, "
            "then re-run (the model pull is automatic)"
        )

    sys.stderr.write(
        f"[Ollama/Qwen] model selection: {_model_selection_note()}\n"
    )

    # Preflight: refuse to add another model host on top of leaked ones. Each
    # run used to silently contribute one more multi-GB orphan; three of them
    # once held 37 GB and crashed the editor. Surfacing it beats compounding it.
    clear, detail = preflight_orphan_check(
        log=lambda m: sys.stderr.write(m + "\n")
    )
    if not clear:
        return False, f"orphaned Ollama model hosts detected — {detail}"

    if not _endpoint_up():
        sys.stderr.write("[Ollama/Qwen] daemon not running — starting...\n")
        try:
            proc = subprocess.Popen(  # noqa: S603
                [ollama, "serve"], **_daemon_popen_kwargs(ollama),
            )
        except Exception as exc:  # noqa: BLE001
            return False, f"`ollama serve` failed: {exc}"

        deadline = time.monotonic() + 30.0
        while time.monotonic() < deadline:
            if _endpoint_up():
                break
            time.sleep(0.5)
        else:
            return False, "Ollama daemon did not come up within 30 s"

        time.sleep(1.5)
        if proc.poll() is None:
            # Ours: record ownership so the end-of-run teardown may stop it.
            _adopt_daemon(proc.pid)
        elif _endpoint_up():
            # Our spawn lost a race for the port, but SOMETHING is serving on
            # it. That is overwhelmingly an operator's own daemon (started by
            # hand, by the Ollama tray app, or by another tool), and refusing
            # the whole run over it was too blunt: a daemon we did not start is
            # still a perfectly good daemon to translate against.
            #
            # The safety property is preserved by omission: _adopt_daemon is
            # deliberately NOT called, so this PID is never recorded as ours
            # and shutdown_engine will neither unload its model nor terminate
            # it. The "right model on the right port" half of the decision is
            # settled by the code immediately below, which probes this same
            # endpoint for the model tag and pulls it if it is absent.
            sys.stderr.write(
                "[Ollama/Qwen] our daemon lost the port to an existing "
                "instance — using that daemon (this run will not stop it)\n"
            )
        else:
            # Nothing is serving AND our spawn died: a genuinely failed start,
            # which is the only case the restart path should have to handle.
            sys.stderr.write(
                "[Ollama/Qwen] WARNING: our daemon exited and nothing is "
                "serving the port — restarting\n"
            )
            if not restart_ollama(log=lambda m: sys.stderr.write(m + "\n")):
                return False, "Could not start Ollama — another instance keeps reclaiming port"

    if not _endpoint_up():
        return False, "Ollama daemon not responding after startup sequence"

    if not _has_model():
        sys.stderr.write(
            f"[Ollama/Qwen] model {_model_tag()} not found "
            f"— pulling ({_model_pull_size()}, one-time)...\n"
        )
        try:
            result = subprocess.run(
                [ollama, "pull", _model_tag()], check=False  # noqa: S603
            )
        except Exception as exc:  # noqa: BLE001
            return False, f"`ollama pull {_model_tag()}` failed: {exc}"
        if result.returncode != 0:
            return False, f"`ollama pull {_model_tag()}` exited {result.returncode}"
        if not _has_model():
            return False, f"Pull completed but {_model_tag()} not found in tags"

    return True, f"Ollama ready, {_model_tag()} loaded"


# ---------------------------------------------------------------------------
# Translation prompt + call
# ---------------------------------------------------------------------------

def _build_prompt(text: str, target_bcp47: str) -> str:
    lang_label = _LOCALE_LANGUAGE_NAMES.get(
        target_bcp47, f"the language with code '{target_bcp47}'",
    )

    _has_brace = "{" in text
    _token_desc = "curly-brace tokens like {name} or {label}" if _has_brace else (
        "placeholder tokens"
    )

    _script_name = _TARGET_SCRIPT_NAME.get(target_bcp47)
    if _script_name:
        _rule4 = (
            "4. CRITICAL: every letter of the output must be a "
            + _script_name + " letter. Translate EVERY word into "
            + _script_name + " — do NOT leave or substitute any word in "
            "Latin, Thai, Arabic, Cyrillic, Korean, Japanese, or any other "
            "script. Spaces, digits, punctuation and placeholder tokens are "
            "the only exceptions.\n"
        )
    else:
        _rule4 = (
            "4. Output MUST use the correct writing system for the target "
            "language; do not switch to another language mid-sentence.\n"
        )

    return (
        "Context: A VS Code extension for Dart/Flutter developers. The extension "
        "provides lint rules, code analysis, and project health tools. Tone "
        "should be professional and clear.\n\n"
        f"Task: Translate the following English text into {lang_label}.\n\n"
        "Strict Rules:\n"
        "1. Return ONLY the translated string output.\n"
        "2. Do NOT include explanations, introduction, markdown notation, "
        "or surrounding quotes.\n"
        f"3. The text may contain placeholder tokens: {_token_desc}. "
        "Copy each one into the translation EXACTLY as written, in the "
        "grammatically correct position. Never translate, remove, or "
        "reformat a token.\n"
        f"{_rule4}\n"
        f"Text: {text}"
    )


def _keep_alive() -> str:
    """Model residency window between calls. Short by design — see _call_ollama."""
    return os.environ.get("SAROPA_QWEN_KEEP_ALIVE", "").strip() or "5m"


def _call_ollama(prompt: str, timeout_s: float) -> str | None:
    global _qwen_cooldown_remaining  # noqa: PLW0603
    with _qwen_state_lock:
        if _qwen_cooldown_remaining > 0:
            _qwen_cooldown_remaining -= 1
            return None

    req_data = {
        "model": _model_tag(),
        "messages": [{"role": "user", "content": prompt}],
        "think": False,
        "stream": False,
        "options": {
            "temperature": 0.1,
            "num_ctx": 2048,
        },
        # WHY not "30m": this is a batch job that knows when it is finished.
        # A half-hour residency meant the model stayed committed long after the
        # last string was translated, for no benefit. A short window still spans
        # the gaps between locales, and shutdown_engine() unloads explicitly at
        # the end rather than waiting for any timer at all.
        "keep_alive": _keep_alive(),
    }
    req = urllib.request.Request(
        f"{_OLLAMA_BASE}/api/chat",
        data=json.dumps(req_data).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    wall_start = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout_s) as response:
            res_data = json.loads(response.read().decode("utf-8"))
            translated = (res_data.get("message") or {}).get("content", "").strip()
    except Exception:
        wall_elapsed = time.monotonic() - wall_start
        tripped = _record_outcome(False)
        if wall_elapsed >= _stall_threshold():
            sys.stderr.write(
                f"    [stall] call hung {wall_elapsed:.0f}s — restarting\n"
            )
            restart_ollama(log=lambda m: sys.stderr.write(m + "\n"))
        elif tripped:
            sys.stderr.write(
                f"    [Qwen] breaker tripped — pausing {_COOLDOWN_KEYS} keys\n"
            )
        raise

    _record_outcome(True)

    # Strip leaked <think> blocks from models that ignore think:false
    translated = re.sub(r"(?s)<think>.*?</think>", "", translated)
    translated = re.sub(r"(?s)<think>.*\Z", "", translated).strip()

    # Strip LLM chat-template directives / control tokens that leak into output
    translated = _LLM_DIRECTIVE_RE.sub("", translated).strip()
    translated = _LLM_TAG_RE.sub("", translated).strip()

    if translated.startswith('"') and translated.endswith('"'):
        translated = translated[1:-1].strip()
    if translated.startswith("'") and translated.endswith("'"):
        translated = translated[1:-1].strip()

    return translated or None


# ---------------------------------------------------------------------------
# Public API — 3 functions mt_fallback.py expects
# ---------------------------------------------------------------------------

# Cached readiness state so repeated calls don't probe Ollama every time.
_ready_checked = False
_ready_result = False


def qwen_lang_code(locale: str) -> str | None:
    """Return the locale code if Qwen supports it, else None."""
    return locale if locale in _SUPPORTED_LOCALES else None


def qwen_model_available() -> bool:
    """True when Ollama is up AND the Qwen model is pulled.

    On first call, attempts to self-provision (start daemon, pull model).
    Result is cached for the session.
    """
    global _ready_checked, _ready_result  # noqa: PLW0603
    if _ready_checked:
        return _ready_result
    _ready_checked = True
    ok, detail = _ensure_ready()
    if ok:
        sys.stderr.write(f"[Qwen] {detail}\n")
        _ready_result = True
    else:
        sys.stderr.write(f"[Qwen] not available: {detail}\n")
        _ready_result = False
    return _ready_result


def qwen_translate(text: str, locale: str) -> str | None:
    """Translate one English string via Qwen/Ollama. Returns None on failure."""
    plain = (text or "").strip()
    if not plain:
        return None

    timeout_s = float(
        os.environ.get("SAROPA_QWEN_TIMEOUT", "90").strip() or "90"
    )
    timeout_s = max(15.0, min(600.0, timeout_s))

    prompt = _build_prompt(plain, locale)
    try:
        translated = _call_ollama(prompt, timeout_s)
    except Exception:  # noqa: BLE001
        return None

    if not translated or translated.lower() == plain.lower():
        return None
    return translated


def unload_model(*, log=None) -> bool:
    """Ask Ollama to evict the model now instead of after the keep-alive timer.

    ``keep_alive: 0`` is Ollama's own supported eviction path, so this frees the
    9-16 GB the model host holds without terminating anything. It is the cheap,
    non-destructive half of teardown and is safe even when other clients are
    connected — the worst case is that they reload the model on their next call.
    """
    say = log or (lambda _m: None)
    if not _endpoint_up(timeout_s=2.0):
        return False
    payload = {"model": _model_tag(), "prompt": "", "keep_alive": 0}
    req = urllib.request.Request(
        f"{_OLLAMA_BASE}/api/generate",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            resp.read()
    except Exception as exc:  # noqa: BLE001 — teardown is best-effort
        say(f"    [ollama] unload request failed: {exc}")
        return False
    say(f"    [ollama] unloaded {_model_tag()}")
    return True


def shutdown_engine(*, log=None) -> None:
    """End-of-run teardown. Registered with atexit the moment we adopt a daemon.

    SAFETY — ownership decides everything here:

    * Daemon we started: unload the model, then terminate the whole tree so the
      model host cannot outlive it, then sweep for anything left parentless.
    * Daemon we did NOT start: touch nothing at all. It may be serving a live
      client, and evicting its model or killing it is the exact failure that
      motivated this code. We only report that we left it alone.

    Best-effort by construction: this runs at interpreter exit, where raising
    would obscure the real exit path, so every step swallows its own errors.
    """
    global _daemon_pid  # noqa: PLW0603
    say = log or (lambda m: sys.stderr.write(m + "\n"))
    pid = _daemon_pid
    if pid is None:
        # Nothing adopted: either we never started a daemon, or teardown already
        # ran. Either way there is no process here we are entitled to stop.
        return
    _daemon_pid = None  # Idempotent: a second atexit pass must be a no-op.
    try:
        unload_model(log=say)
        _terminate_tree(pid, log=say)
        # The daemon is down, so any surviving model host is parentless and the
        # sweep may reap it. This is the backstop for a daemon that died in a
        # way our own kill paths never saw.
        sweep_orphan_model_hosts(log=say)
    except Exception:  # noqa: BLE001 — never raise out of atexit
        pass


def long_inputs() -> list[tuple[str, int, str]]:
    """Compatibility stub — Qwen has no input-length gate like NLLB."""
    return []


def reset_long_inputs() -> None:
    """Compatibility stub."""
    pass


# ---------------------------------------------------------------------------
# CLI — status check
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print(f"Model tag:      {_model_tag()}")
    print(f"Provenance:     {_model_stamp()}")
    print(f"Selection note: {_model_selection_note()}")
    print(f"Ollama on PATH: {shutil.which('ollama') is not None}")
    print(f"Endpoint up:    {_endpoint_up()}")
    if _endpoint_up():
        print(f"Model pulled:   {_has_model()}")
    # Read-only orphan report: the operational check from the bug report, built
    # in, so "is this machine leaking?" never needs a remembered PowerShell line.
    _orphans = find_orphan_model_hosts()
    if _orphans is None:
        print("Orphan hosts:   unknown (could not enumerate processes)")
    elif _orphans:
        print(f"Orphan hosts:   {_describe_orphans(_orphans)}")
        print("                re-run the pipeline with SAROPA_QWEN_REAP_ORPHANS=1 to clear them")
    else:
        print("Orphan hosts:   none")
