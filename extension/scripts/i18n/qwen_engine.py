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
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from collections import deque

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
_daemon_pid: int | None = None


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


def _kill_all_ollama() -> None:
    if sys.platform == "win32":
        subprocess.run(
            ["taskkill", "/IM", "ollama.exe", "/F"],
            capture_output=True, timeout=10, check=False,
        )
    else:
        subprocess.run(
            ["pkill", "-f", "ollama serve"],
            capture_output=True, timeout=10, check=False,
        )


def _wait_for_port_down(timeout_s: float = 8.0) -> bool:
    deadline = time.monotonic() + timeout_s
    while time.monotonic() < deadline:
        if not _endpoint_up(timeout_s=1.0):
            return True
        time.sleep(0.5)
    return False


def restart_ollama(*, log=print) -> bool:
    global _restarts_this_run, _daemon_pid  # noqa: PLW0603
    ollama = shutil.which("ollama")
    if not ollama:
        log("    [stall] cannot restart — ollama not on PATH")
        return False
    if _restarts_this_run >= _MAX_RESTARTS_PER_LOCALE:
        log("    [stall] restart cap reached — skipping")
        return False

    try:
        subprocess.run(
            [ollama, "stop", _model_tag()],
            capture_output=True, timeout=10, check=False,
        )
    except subprocess.TimeoutExpired:
        pass
    time.sleep(0.5)

    if _daemon_pid is not None:
        if sys.platform == "win32":
            subprocess.run(
                ["taskkill", "/PID", str(_daemon_pid), "/F"],
                capture_output=True, timeout=10, check=False,
            )
        else:
            subprocess.run(
                ["kill", "-9", str(_daemon_pid)],
                capture_output=True, timeout=10, check=False,
            )
    else:
        _kill_all_ollama()
    time.sleep(1.0)

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
            _daemon_pid = proc.pid
            _reset_circuit()
            _restarts_this_run += 1
            log(
                f"    [stall] Ollama restarted "
                f"({_restarts_this_run}/{_MAX_RESTARTS_PER_LOCALE})"
            )
            return True

        if attempt == 0:
            log("    [stall] our daemon exited (port conflict) — killing rival and retrying")
            _kill_all_ollama()
            _wait_for_port_down(timeout_s=8.0)

    log("    [stall] could not start daemon — port repeatedly claimed by another instance")
    _restarts_this_run += 1
    return False


def _ensure_ready() -> tuple[bool, str]:
    global _daemon_pid  # noqa: PLW0603
    ollama = shutil.which("ollama")
    if not ollama:
        return False, (
            "Ollama is not installed — install from https://ollama.com/download, "
            "then re-run (the model pull is automatic)"
        )

    sys.stderr.write(
        f"[Ollama/Qwen] model selection: {_model_selection_note()}\n"
    )

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
        if proc.poll() is not None:
            sys.stderr.write(
                "[Ollama/Qwen] WARNING: our daemon exited (port conflict?) "
                "— restarting\n"
            )
            if not restart_ollama(log=lambda m: sys.stderr.write(m + "\n")):
                return False, "Could not start Ollama — another instance keeps reclaiming port"
        else:
            _daemon_pid = proc.pid

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
        "keep_alive": "30m",
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
