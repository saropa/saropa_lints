#!/usr/bin/env python3
"""Meta NLLB-200-3.3B offline machine-translation engine for the extension i18n pipeline.

This is the high-quality engine: a single 3.3B-parameter model (FLORES-200,
200+ languages) run locally via CTranslate2. It is dramatically better than
Google Translate on low-resource languages (Bengali, Hindi, Swahili, Filipino,
Urdu) where the free web engine produces near-gibberish, and it never rate-
limits or phones home. The trade-off is a one-time ~7 GB download and slow
per-string inference (~1-3 keys/sec on CUDA, slower on CPU). The extension
pipeline uses it as the PRIMARY engine and falls back to Google only for
strings/locales NLLB cannot handle (see mt_fallback.py).

Provenance: lifted from the contacts project's battle-tested NLLB core
(``scripts/.shared/arb_translate/fill_arb_machine_translate.py``). Every tuning
parameter here (greedy decode, 80-token input gate, 10 s per-call timeout,
sentence-split routing, CPU-int8 fallback, repetition penalties) encodes a
specific production incident from that pipeline — the comments name the failure
each one prevents. The contacts ARB-runner coupling (cross-locale orphan-thread
drain, consecutive/cumulative circuit breakers, per-sentence progress hooks) is
intentionally NOT ported: it existed to survive a 15,000-key × 50-locale loop
that this extension's few-hundred-string run does not have. The input-length
gate plus sentence-split — the actual source of long-call wedges — ARE ported,
so the orphan problem they guarded against rarely arises here.

Model reuse: the model directory resolves to the SAME default as contacts
(``<drive>:\\tools\\meta_nllb``) and honors the same ``SAROPA_NLLB_MODEL_DIR``
override, so a model already downloaded for contacts is reused with no second
download.

Environment variables (all shared with the contacts pipeline):
  SAROPA_NLLB_MODEL_DIR     Override the model/cache directory.
  SAROPA_NLLB_PACKAGES_DIR  Override where pip --target installs ctranslate2 etc.
  SAROPA_NLLB_DEVICE        ``auto`` (default), ``cuda``, or ``cpu``.
  SAROPA_NLLB_ENABLED=1     Allow first-time download without an interactive prompt.
  SAROPA_SKIP_NLLB=1        Disable NLLB entirely (pipeline uses Google only).
  SAROPA_NLLB_STRING_TIMEOUT  Per-call wall-clock cap in seconds (default 10, clamped [5,300]).
  SAROPA_NLLB_MAX_INPUT_TOKENS  Source-token gate (default 80; 0 disables).

Public API:
  nllb_lang_code(locale)   -> FLORES-200 code or None.
  nllb_model_available()   -> True when packages import AND model is cached (no download, no load).
  nllb_translate(text, locale) -> translated string, or None to fall back.

CLI:
  py -3 extension/scripts/i18n/nllb_engine.py            # status
  py -3 extension/scripts/i18n/nllb_engine.py --setup    # download model (~7 GB, prompts)
"""

from __future__ import annotations

import importlib.util
import os
import re
import sys
import threading
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Module state — loaded model/tokenizer and one-shot install/error flags.
# ---------------------------------------------------------------------------

# Cache the loaded model + tokenizer so we don't reload on every string.
_translator: object | None = None
_tokenizer: object | None = None
# Track pip-install state to avoid repeated subprocess calls.
_installed: bool | None = None
# Session cache for the "is the model on disk?" probe so a per-string pipeline
# doesn't re-run the huggingface snapshot check hundreds of times.
_available: bool | None = None
# Log NLLB load/translate errors once per process — repeating them per string
# would bury the actual translation output.
_error_logged: bool = False
# Set True after the first interactive decline so the download prompt fires at
# most once per session, not once per untranslated string.
_user_declined: bool = False
# Every input that was past the token gate AND could not be split (sentence then
# clause) — i.e. the strings NLLB genuinely could not handle. Recorded in full
# (locale, token count, source) so the run report names each one instead of
# hiding all but the first behind a once-only log. Cleared via reset_long_inputs.
_long_inputs: list[tuple[str, int, str]] = []
# Configured model directory — resolved lazily on first use.
_model_dir: str | None = None

# The HF model ID used for all NLLB operations (float16-quantized CTranslate2
# build — same artifact the contacts pipeline downloads, so the on-disk cache
# is shared when the model directory matches).
_NLLB_MODEL_ID = "JustFrederik/nllb-200-3.3B-ct2-float16"

# Default per-string wall-clock cap. Greedy decode (beam_size=1) +
# max_decoding_length<=256 finishes typical inputs in well under 1 s on a
# CUDA 3070 and under 5 s on paragraph inputs, so 10 s is generous head-room
# while still bailing in seconds (not minutes) on a degenerate input.
# Contacts bug history (2026-05-27): an initial beam_size=5 / cap=512 / 30 s
# budget made every long bio time out and fall back to English even though
# the timeout fired correctly — the parameter budget was simply too generous
# to ever produce a real translation under the wall clock.
_DEFAULT_STRING_TIMEOUT_SEC = 10.0

# Maximum source-token length sent to NLLB as a single call. Paragraph-scale
# inputs push greedy decode past the per-call timeout AND, once a long call
# times out, its abandoned worker keeps CTranslate2's internal mutex held so
# the next few short strings queue behind it and time out too. Skip long
# inputs at the gate (routing them through the sentence splitter first); only
# genuinely unsplittable over-long sentences fall back to Google. Default 80
# source tokens (~280-400 chars of English) suits RTX-3070-class hardware;
# raise to 150 for stronger GPUs, set 0 to disable the gate.
_DEFAULT_MAX_SOURCE_TOKENS = 80

# Abbreviations the sentence splitter must NOT treat as sentence ends. A
# procedural scan compares the word before a candidate boundary against this
# set (Python stdlib ``re`` cannot express the variable-width lookbehind in a
# single pattern). Anything missed falls through as a longer pseudo-sentence —
# NLLB attempts it and may hit the length gate, leaving one English fragment
# rather than dropping the whole paragraph.
_SENTENCE_ABBREVS_PLAIN: frozenset[str] = frozenset((
    "Mr", "Mrs", "Ms", "Dr", "Sr", "Jr", "St", "Mt", "Lt", "Sgt", "Cpt",
    "Gen", "Rev", "Hon", "Prof",
    "vs", "etc", "e.g", "i.e",
    "U.S", "U.K", "E.U", "Ph.D", "M.D", "B.A", "M.A",
    "Inc", "Ltd", "Co", "Corp", "LLC",
    "No", "Vol", "pp", "Ch", "Sec", "Fig", "Eq", "Ref",
    "Jan", "Feb", "Mar", "Apr", "Jun", "Jul", "Aug", "Sep", "Sept", "Oct", "Nov", "Dec",
))

# Characters that can follow a sentence-terminal "."/"!"/"?" and still mark a
# real boundary: a capital letter, or one of the four common opening-quote
# glyphs (ASCII single/double + curly U+2018/U+201C) for quoted-speech starts.
_SENTENCE_OPENERS: frozenset[str] = frozenset('"\'‘“')
_SENTENCE_LAST_WORD_RE = re.compile(r"([A-Za-z](?:[A-Za-z.]*[A-Za-z])?)\Z")

# NLLB uses FLORES-200 language codes (BCP-47 base + script tag). This map is
# comprehensive (all 200+ NLLB languages, not just shipped locales) so a future
# locale addition works without a code change. Copied verbatim from contacts so
# the two pipelines agree on every code.
# Reference: https://github.com/facebookresearch/flores/blob/main/flores200/README.md
_NLLB_LANG_MAP: dict[str, str] = {
    # --- Currently shipped extension locales ---
    "ar": "arb_Arab",    # Modern Standard Arabic
    "bn": "ben_Beng",    # Bengali
    "de": "deu_Latn",    # German
    "es": "spa_Latn",    # Spanish
    "fa": "pes_Arab",    # Persian (Western Farsi)
    "fil": "tgl_Latn",   # Filipino / Tagalog
    "fr": "fra_Latn",    # French
    "he": "heb_Hebr",    # Hebrew
    "hi": "hin_Deva",    # Hindi
    "id": "ind_Latn",    # Indonesian
    "it": "ita_Latn",    # Italian
    "ja": "jpn_Jpan",    # Japanese
    "ko": "kor_Hang",    # Korean
    "pl": "pol_Latn",    # Polish
    "pt": "por_Latn",    # Portuguese
    "ru": "rus_Cyrl",    # Russian
    "sw": "swh_Latn",    # Swahili
    "th": "tha_Thai",    # Thai
    "tr": "tur_Latn",    # Turkish
    "uk": "ukr_Cyrl",    # Ukrainian
    "ur": "urd_Arab",    # Urdu
    "vi": "vie_Latn",    # Vietnamese
    "zh": "zho_Hans",    # Chinese (Simplified)
    # --- Additional FLORES-200 languages (alphabetical by BCP-47) ---
    "af": "afr_Latn", "am": "amh_Ethi", "as": "asm_Beng", "ay": "ayr_Latn",
    "az": "azj_Latn", "be": "bel_Cyrl", "bg": "bul_Cyrl", "bm": "bam_Latn",
    "bs": "bos_Latn", "ca": "cat_Latn", "cs": "ces_Latn", "cy": "cym_Latn",
    "da": "dan_Latn", "el": "ell_Grek", "et": "est_Latn", "eu": "eus_Latn",
    "fi": "fin_Latn", "ga": "gle_Latn", "gl": "glg_Latn", "gu": "guj_Gujr",
    "ha": "hau_Latn", "hr": "hrv_Latn", "hu": "hun_Latn", "hy": "hye_Armn",
    "ig": "ibo_Latn", "is": "isl_Latn", "jv": "jav_Latn", "ka": "kat_Geor",
    "kk": "kaz_Cyrl", "km": "khm_Khmr", "kn": "kan_Knda", "ku": "kmr_Latn",
    "ky": "kir_Cyrl", "lb": "ltz_Latn", "lg": "lug_Latn", "ln": "lin_Latn",
    "lo": "lao_Laoo", "lt": "lit_Latn", "lv": "lvs_Latn", "mg": "plt_Latn",
    "mi": "mri_Latn", "mk": "mkd_Cyrl", "ml": "mal_Mlym", "mn": "khk_Cyrl",
    "mr": "mar_Deva", "ms": "zsm_Latn", "mt": "mlt_Latn", "my": "mya_Mymr",
    "ne": "npi_Deva", "nl": "nld_Latn", "no": "nob_Latn", "nb": "nob_Latn",
    "nn": "nno_Latn", "ny": "nya_Latn", "or": "ory_Orya", "pa": "pan_Guru",
    "ps": "pbt_Arab", "qu": "quy_Latn", "ro": "ron_Latn", "rw": "kin_Latn",
    "sd": "snd_Arab", "si": "sin_Sinh", "sk": "slk_Latn", "sl": "slv_Latn",
    "sn": "sna_Latn", "so": "som_Latn", "sq": "als_Latn", "sr": "srp_Cyrl",
    "st": "sot_Latn", "su": "sun_Latn", "sv": "swe_Latn", "ta": "tam_Taml",
    "te": "tel_Telu", "tg": "tgk_Cyrl", "tl": "tgl_Latn", "tk": "tuk_Latn",
    "tt": "tat_Cyrl", "ug": "uig_Arab", "uz": "uzn_Latn", "wo": "wol_Latn",
    "xh": "xho_Latn", "yo": "yor_Latn", "zu": "zul_Latn",
    # Chinese variants
    "zh-CN": "zho_Hans", "zh-TW": "zho_Hant", "zh-HK": "zho_Hant",
}


def nllb_lang_code(locale: str) -> str | None:
    """Map a BCP-47 / ISO 639-1 locale to its FLORES-200 code, or None.

    Tries the exact locale first (so ``zh-CN`` resolves distinctly from a bare
    ``zh``), then the base language before any region/script suffix.
    """
    exact = _NLLB_LANG_MAP.get(locale)
    if exact:
        return exact
    base = locale.split("-")[0].split("_")[0]
    return _NLLB_LANG_MAP.get(base)


def _diag(msg: str) -> None:
    """Write a one-line NLLB diagnostic to stderr.

    The extension pipeline has no tqdm progress bar to coordinate with (unlike
    the contacts ARB runner), so a plain stderr write is correct here.
    """
    sys.stderr.write(msg.rstrip("\n") + "\n")
    sys.stderr.flush()


def _record_long_input(locale: str, src_len: int, text: str) -> None:
    """Note a string NLLB could not handle (over the gate, unsplittable)."""
    _long_inputs.append((locale, src_len, text))
    _diag(
        f"[nllb] {locale}: {src_len} tokens, unsplittable — reporting (not silently "
        f"dropped): {text[:60].replace(chr(10), ' ')!r}",
    )


def long_inputs() -> list[tuple[str, int, str]]:
    """The (locale, token count, source) of every over-gate unsplittable input."""
    return list(_long_inputs)


def reset_long_inputs() -> None:
    """Clear the over-gate input log. Call once at the start of a run."""
    _long_inputs.clear()


# ---------------------------------------------------------------------------
# Model directory + persisted config
# ---------------------------------------------------------------------------

def _default_model_dir() -> str:
    """Default NLLB directory: ``<root-drive>/tools/meta_nllb``.

    Uses the root drive of this file's location so the 13 GB model lands on a
    drive with space, not the user's home. Identical to the contacts default,
    so a model downloaded there is reused here without a second download.
    """
    script_drive = Path(__file__).resolve().anchor  # "D:\\" or "/"
    return str(Path(script_drive) / "tools" / "meta_nllb")


def _config_path() -> Path:
    """Path to the file that persists the chosen model directory.

    Stored in the i18n ``.cache`` dir (alongside ``mt_strings.json``) so it
    survives between runs but stays out of the model tree.
    """
    return Path(__file__).resolve().parent / ".cache" / "nllb_config.txt"


def _load_saved_dir() -> str | None:
    cfg = _config_path()
    if cfg.is_file():
        saved = cfg.read_text(encoding="utf-8").strip()
        if saved:
            return saved
    return None


def _save_dir(directory: str) -> None:
    cfg = _config_path()
    cfg.parent.mkdir(parents=True, exist_ok=True)
    cfg.write_text(directory + "\n", encoding="utf-8")


def _resolve_model_dir() -> str:
    """Resolve the model directory — env, session cache, saved config, default.

    Priority: ``SAROPA_NLLB_MODEL_DIR`` env > already-resolved this session >
    saved config file > default path. Deliberately NEVER prompts: this is called
    by the availability probe on every translation run, and an interactive
    ``input()`` there would block a long ``generate_locales`` run on an invisible
    question. Point ``SAROPA_NLLB_MODEL_DIR`` at a custom location, or run
    ``--setup`` (which persists the choice) to override the default.
    """
    global _model_dir  # noqa: PLW0603

    env = os.environ.get("SAROPA_NLLB_MODEL_DIR", "").strip()
    if env:
        _model_dir = env
        return env
    if _model_dir is not None:
        return _model_dir
    saved = _load_saved_dir()
    if saved:
        _model_dir = saved
        return saved
    _model_dir = _default_model_dir()
    return _model_dir


# ---------------------------------------------------------------------------
# pip bootstrap (ctranslate2 / sentencepiece / huggingface_hub) into --target
# ---------------------------------------------------------------------------

def _packages_dir() -> str:
    """Directory pip installs the NLLB runtime into (``<model_dir>/packages``).

    ``SAROPA_NLLB_PACKAGES_DIR`` overrides it, decoupling the packages location
    from the model so a poisoned packages dir (corrupt ACL, AV-quarantined
    file) can be abandoned without re-downloading the 13 GB model.
    """
    env = os.environ.get("SAROPA_NLLB_PACKAGES_DIR", "").strip()
    if env:
        return env
    return str(Path(_resolve_model_dir()) / "packages")


def _add_packages_to_path() -> None:
    """APPEND the packages dir to sys.path when it actually carries our payload.

    Append, not prepend — this is the load-bearing choice. ``ctranslate2`` and
    ``sentencepiece`` exist ONLY in this --target dir, so appending still lets
    ``find_spec`` / ``import`` locate them. But for a name that ALSO exists in
    system site-packages (``typing_extensions``, ``certifi``, …), append makes
    the system copy win. That matters because a ``pip install --target`` here
    can leave a single file with a broken / AV-quarantined ACL (real incident:
    ``typing_extensions.py``, Errno 13). Prepending put that locked file ahead
    of the clean system copy, so the next unrelated import that touched
    ``typing_extensions`` — including the Google fallback's
    ``deep_translator -> bs4 -> typing_extensions`` chain — crashed with a
    PermissionError. Appending routes every collision to the clean system file,
    so one locked file in this dir can no longer poison the whole process.

    The ``has_payload`` guard additionally skips a dir stranded by a crashed
    install (orphan files, no real package dirs) so it is never added at all.
    """
    pkg_path = Path(_packages_dir())
    if not pkg_path.is_dir():
        return
    has_payload = (
        (pkg_path / "ctranslate2").is_dir()
        or (pkg_path / "sentencepiece").is_dir()
        or (pkg_path / "huggingface_hub").is_dir()
    )
    if not has_payload:
        return
    pkg_dir = str(pkg_path)
    if pkg_dir not in sys.path:
        sys.path.append(pkg_dir)


def _add_nvidia_dll_path(pkg_dir: str) -> None:
    """Make nvidia-cublas-cu12 DLLs findable by ctranslate2 at inference time.

    ctranslate2 detects CUDA but does not declare cuBLAS as a dependency, and
    the DLL is lazy-loaded at translate time — so it must be on the Windows DLL
    search path (both PATH and ``add_dll_directory``, since different loaders
    use different orders). Checks the --target dir, site-packages, and the
    ctranslate2 install root.
    """
    candidate_roots: list[Path] = [Path(pkg_dir)]
    try:
        import site
        for sp in site.getsitepackages():
            candidate_roots.append(Path(sp))
    except Exception:  # noqa: BLE001
        pass
    ct2_spec = importlib.util.find_spec("ctranslate2")
    if ct2_spec and ct2_spec.origin:
        candidate_roots.append(Path(ct2_spec.origin).parent.parent)

    for root in candidate_roots:
        for d in (
            root / "nvidia" / "cublas" / "bin",
            root / "nvidia" / "cuda_nvrtc" / "bin",
            root / "nvidia" / "cublas" / "lib",
        ):
            if d.is_dir():
                d_str = str(d)
                current_path = os.environ.get("PATH", "")
                if d_str not in current_path:
                    os.environ["PATH"] = d_str + os.pathsep + current_path
                try:
                    os.add_dll_directory(d_str)
                except (OSError, AttributeError):
                    pass


def _ensure_cuda_deps(pkg_dir: str) -> None:
    """Install nvidia-cublas-cu12 if CUDA is present but cuBLAS is missing.

    Non-fatal: the CUDA->CPU cascade in ``_ensure_model`` handles a failed
    install; this just gives GPU users acceleration without manual setup.
    """
    try:
        import ctranslate2  # type: ignore[import-untyped]
        if ctranslate2.get_cuda_device_count() == 0:
            return
    except Exception:  # noqa: BLE001
        return

    _add_nvidia_dll_path(pkg_dir)
    import ctypes
    try:
        ctypes.CDLL("cublas64_12.dll")
        return  # Already available.
    except OSError:
        pass

    _diag(f"[nllb] CUDA detected but cuBLAS missing — installing nvidia-cublas-cu12 into {pkg_dir} (~553 MB)...")
    import subprocess
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--target", pkg_dir, "nvidia-cublas-cu12"],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        _diag(f"[nllb] cuBLAS install failed (GPU unavailable, falling back to CPU): {result.stderr.strip()[:200]}")
    else:
        _add_nvidia_dll_path(pkg_dir)
        _diag("[nllb] cuBLAS installed — GPU acceleration ready.")


def _ensure_installed() -> bool:
    """Ensure ctranslate2 + sentencepiece + huggingface_hub are importable.

    Installs missing packages via ``pip install --target <model_dir>/packages``
    so nothing touches system site-packages or the C: drive. Returns True when
    all three import afterwards.
    """
    global _installed  # noqa: PLW0603
    if _installed is not None:
        return _installed

    _add_packages_to_path()
    ct2 = importlib.util.find_spec("ctranslate2")
    sp = importlib.util.find_spec("sentencepiece")
    hf = importlib.util.find_spec("huggingface_hub")
    if ct2 is not None and sp is not None and hf is not None:
        pkg_dir = _packages_dir()
        Path(pkg_dir).mkdir(parents=True, exist_ok=True)
        _ensure_cuda_deps(pkg_dir)
        _installed = True
        return True

    missing = []
    if ct2 is None:
        missing.append("ctranslate2")
    if sp is None:
        missing.append("sentencepiece")
    if hf is None:
        missing.append("huggingface_hub")

    pkg_dir = _packages_dir()
    Path(pkg_dir).mkdir(parents=True, exist_ok=True)
    _diag(f"[nllb] Installing {', '.join(missing)} into {pkg_dir}...")
    import subprocess
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--target", pkg_dir, *missing],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        _diag(f"[nllb] pip install failed (exit {result.returncode}): {result.stderr.strip()[:300]}")
        _installed = False
        return False

    _add_packages_to_path()
    ok = (
        importlib.util.find_spec("ctranslate2") is not None
        and importlib.util.find_spec("sentencepiece") is not None
        and importlib.util.find_spec("huggingface_hub") is not None
    )
    if ok:
        _ensure_cuda_deps(pkg_dir)
    _installed = ok
    return ok


# ---------------------------------------------------------------------------
# Model availability + load
# ---------------------------------------------------------------------------

def _is_model_cached() -> bool:
    """True when the model is already on disk (no network needed).

    Uses ``snapshot_download(local_files_only=True)`` which raises when the
    snapshot is absent. Requires huggingface_hub importable (so the packages
    bootstrap must have run first).
    """
    _add_packages_to_path()
    try:
        from huggingface_hub import snapshot_download  # type: ignore[import-untyped]
        snapshot_download(
            repo_id=_NLLB_MODEL_ID, cache_dir=_resolve_model_dir(),
            local_files_only=True,
        )
        return True
    except Exception:  # noqa: BLE001
        return False


def nllb_model_available() -> bool:
    """True when NLLB can translate WITHOUT a download — packages import and
    model is cached. Cached per session. Never prompts, downloads, or loads.

    Returns False (and does not error) when the runtime isn't installed or the
    model isn't downloaded; the caller then falls back to Google. Disabled
    outright by ``SAROPA_SKIP_NLLB=1``.
    """
    global _available  # noqa: PLW0603
    if os.environ.get("SAROPA_SKIP_NLLB", "").strip() == "1":
        return False
    if _available is not None:
        return _available
    # Packages must import for the HF cache probe to work. Don't trigger a pip
    # install here (that's a heavy side effect for a probe) — only report.
    _add_packages_to_path()
    if importlib.util.find_spec("huggingface_hub") is None:
        _available = False
        return False
    _available = _is_model_cached()
    return _available


def _prompt_download() -> bool:
    """Ask once (TTY only) before a ~7 GB download. Non-TTY returns False."""
    global _user_declined  # noqa: PLW0603
    if _user_declined or not sys.stderr.isatty():
        return False
    default_dir = _default_model_dir()
    _diag(
        "\n    NLLB-200-3.3B — higher-quality offline MT.\n"
        "    One-time download: ~7 GB (cached for future runs).\n"
        f"    Default location: {default_dir}\n",
    )
    try:
        answer = input("    Download NLLB model now? [y/N] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        _user_declined = True
        return False
    if answer in ("y", "yes"):
        return True
    _user_declined = True
    return False


def _ensure_model() -> bool:
    """Load (downloading on first use) the NLLB model + tokenizer. Cached after first success.

    Device cascade, best quality first: CUDA float16 -> CPU int8 (~4 GB RAM) ->
    CPU float16 (~14 GB RAM). Each candidate is probe-translated before being
    accepted, because cuBLAS/MKL failures only surface at inference time, not
    at construction. A non-cached model prompts on a TTY (or proceeds when
    ``SAROPA_NLLB_ENABLED=1``); non-interactive runs without that flag decline.
    """
    global _translator, _tokenizer, _error_logged  # noqa: PLW0603
    if _translator is not None and _tokenizer is not None:
        return True
    if not _ensure_installed():
        return False

    try:
        import ctranslate2  # type: ignore[import-untyped]
        import sentencepiece  # type: ignore[import-untyped]

        _add_nvidia_dll_path(_packages_dir())
        model_dir = _resolve_model_dir()

        if not _is_model_cached():
            force = os.environ.get("SAROPA_NLLB_ENABLED", "").strip() == "1"
            if not force and not _prompt_download():
                return False
            Path(model_dir).mkdir(parents=True, exist_ok=True)
            _diag(f"    Downloading NLLB-200-3.3B (~7 GB, one-time) into {model_dir}. Ctrl+C to abort.")

        from huggingface_hub import snapshot_download  # type: ignore[import-untyped]
        try:
            model_path = snapshot_download(
                repo_id=_NLLB_MODEL_ID, cache_dir=model_dir, local_files_only=True,
            )
        except Exception:  # noqa: BLE001 — not cached, do the real download
            model_path = snapshot_download(repo_id=_NLLB_MODEL_ID, cache_dir=model_dir)

        # SentencePiece tokenizer (tiny) first — needed by the load probe.
        sp = sentencepiece.SentencePieceProcessor()
        sp.Load(str(Path(model_path) / "sentencepiece.bpe.model"))
        # Probe with a real sentence; single tokens trigger NLLB repetition
        # degeneration that looks broken even when real translations work.
        probe_tokens = sp.Encode("The quick brown fox jumps over the lazy dog.", out_type=str)

        def _try_load(dev: str, compute: str = "default") -> bool:
            label = dev if compute == "default" else f"{dev}/{compute}"
            _diag(f"[nllb] Loading NLLB-200-3.3B on {label}...")
            try:
                translator = ctranslate2.Translator(
                    model_path,
                    device=dev,
                    compute_type=compute,
                    inter_threads=min(4, os.cpu_count() or 1) if dev == "cpu" else 1,
                )
                # Probe inference catches cuBLAS / MKL failures that only
                # surface at translate time, before the main string loop.
                translator.translate_batch(
                    [["eng_Latn"] + probe_tokens],
                    target_prefix=[["deu_Latn"]],
                    beam_size=1,
                    max_decoding_length=10,
                )
                global _translator  # noqa: PLW0603
                _translator = translator
                _diag(f"[nllb] Model loaded ({label}).")
                return True
            except (RuntimeError, OSError, MemoryError) as err:
                _diag(f"[nllb] {label} failed: {err}")
                return False

        device_pref = os.environ.get("SAROPA_NLLB_DEVICE", "auto")
        has_cuda = (
            ctranslate2.get_cuda_device_count() > 0 if device_pref == "auto"
            else device_pref == "cuda"
        )
        attempts = ([("cuda", "default")] if has_cuda else []) + [("cpu", "int8"), ("cpu", "default")]
        for dev, compute in attempts:
            if _try_load(dev, compute):
                _tokenizer = sp
                return True

        _diag("[nllb] All device configurations failed.")
        return False
    except PermissionError as exc:
        # Usual cause: an interrupted ``pip install --target`` left a file with
        # a broken/AV-locked ACL that shadows the system package on import.
        pkg_dir = _packages_dir()
        _diag(
            f"[nllb] PermissionError during model load: {exc}\n"
            f"[nllb] A file under {pkg_dir} has a broken ACL or is AV-locked. Recovery (elevated PowerShell):\n"
            f"[nllb]   takeown /F {pkg_dir} /R /A /D Y\n"
            f"[nllb]   icacls {pkg_dir} /reset /T\n"
            f"[nllb]   Remove-Item {pkg_dir} -Recurse -Force\n"
            "[nllb] Then rerun; pip repopulates the dir cleanly.",
        )
        _translator = None
        _tokenizer = None
        return False
    except Exception as exc:  # noqa: BLE001
        if not _error_logged:
            _diag(f"[nllb] Model load failed ({type(exc).__name__}): {exc}")
            _error_logged = True
        # Don't cache failure — may be transient (disk space, network).
        _translator = None
        _tokenizer = None
        return False


# ---------------------------------------------------------------------------
# Per-call timeout + sentence splitting + translate
# ---------------------------------------------------------------------------

def _translate_batch_with_deadline(
    source_tokens: list[list[str]],
    target_prefix: list[list[str]],
    deadline_sec: float,
    **batch_kwargs: object,
) -> list | None:
    """Run ctranslate2 ``translate_batch`` in a daemon thread with a wall-clock cap.

    ctranslate2 has no timeout / cancel API; a rare degenerate input can run
    the beam search for minutes. The daemon-thread + join-with-deadline pattern
    lets a single bad string fall back to Google instead of wedging the run.
    The abandoned worker keeps running (it cannot be cancelled) but the
    input-length gate below keeps such long calls rare, so — unlike the
    contacts ARB runner — no cross-locale orphan-drain machinery is needed at
    this scale. Returns the result list, or None on timeout. Re-raises any
    worker exception on the main thread for the caller's error log.
    """
    box: list[object] = []

    def run() -> None:
        try:
            box.append(_translator.translate_batch(  # type: ignore[union-attr]
                source_tokens, target_prefix=target_prefix, **batch_kwargs,
            ))
        except Exception as exc:  # noqa: BLE001 — re-raised on main thread
            box.append(exc)

    th = threading.Thread(target=run, daemon=True)
    th.start()
    th.join(timeout=deadline_sec)
    if th.is_alive() or not box:
        return None
    item = box[0]
    if isinstance(item, Exception):
        raise item
    return item if isinstance(item, list) else None


def _split_into_sentences(text: str) -> list[str]:
    """Split an English paragraph into sentences; an empty join is byte-identical
    to the source. Procedural scan with an abbreviation guard (stdlib ``re``
    cannot express the variable-width abbreviation lookbehind). Returns a
    single-element list when no boundary is found, which the caller treats as
    "not worth splitting" so its fallback engages and recursion terminates.
    """
    if not text:
        return []
    sentences: list[str] = []
    start = 0
    i = 0
    n = len(text)
    while i < n:
        if text[i] not in ".!?":
            i += 1
            continue
        # Run of terminators ("..." / "?!" / "!!").
        j = i
        while j < n and text[j] in ".!?":
            j += 1
        # Need whitespace then a capital / opening quote to be a real boundary.
        if j >= n or text[j] not in " \t\n\r":
            i = j
            continue
        k = j
        while k < n and text[k] in " \t\n\r":
            k += 1
        if k >= n or not (text[k].isupper() or text[k] in _SENTENCE_OPENERS):
            i = j
            continue
        # Abbreviation guard: the word ending right before the terminator run.
        m = _SENTENCE_LAST_WORD_RE.search(text[:i])
        last_word = m.group(1) if m else ""
        if last_word in _SENTENCE_ABBREVS_PLAIN:
            i = j
            continue
        # Single capital + period is a name initial ("James T. Kirk"), not a break.
        if len(last_word) == 1 and last_word.isupper():
            i = j
            continue
        # Cut at k so trailing whitespace stays with the preceding sentence.
        sentences.append(text[start:k])
        start = k
        i = k
    if start < n:
        sentences.append(text[start:])
    return [s for s in sentences if s.strip()]


def _translate_via_sentences(text: str, target: str) -> str | None:
    """Translate a paragraph sentence-by-sentence and rejoin — the path for
    inputs over the per-call length gate.

    NLLB greedy decode cannot finish a 200-token paragraph under the deadline,
    but individual 30-80-token sentences finish in 1-3 s. Each sentence routes
    back through ``nllb_translate`` so the timeout + length gate apply per
    sentence; one bad sentence stays English while the rest translate. Returns
    the joined translation, or None when every sentence failed or the join just
    echoes the source. Recursion is at most two levels (an unsplittable long
    sentence makes the splitter return ``[sentence]`` -> None).
    """
    sentences = _split_into_sentences(text)
    if len(sentences) <= 1:
        return None

    out_parts: list[str] = []
    any_translated = False
    for sentence in sentences:
        core = sentence.rstrip()
        trailing_ws = sentence[len(core):]
        if not core:
            out_parts.append(sentence)
            continue
        translated_one = nllb_translate(core, target)
        if translated_one is not None and translated_one.strip().lower() != core.strip().lower():
            out_parts.append(translated_one + trailing_ws)
            any_translated = True
        else:
            out_parts.append(sentence)

    if not any_translated:
        return None
    joined = "".join(out_parts).strip()
    if joined.lower() == text.strip().lower():
        return None
    return joined


# Clause boundaries for a single sentence that is still over the per-call token
# gate. Ordered strongest-first: paragraph/line breaks (markdown link blocks and
# bullet lists), then dash/semicolon/colon/comma clauses. The clause patterns
# require trailing whitespace so a URL ("https://…") or dotted version ("1.2.3")
# — which have no space after their ':' / ',' — is never split mid-token. Each
# pattern captures the separator so re.split keeps it; whitespace-only pieces are
# preserved verbatim on rejoin, making an empty translation byte-identical.
_PHRASE_PATTERNS = (
    r"(\n+)",
    r"((?<=[—–])\s+)",
    r"((?<=[;:])\s+)",
    r"((?<=,)\s+)",
)


def _split_into_phrases(text: str) -> list[str]:
    """Split one over-long sentence on the strongest clause boundary present.

    Returns the re.split parts (content interleaved with captured separators) at
    the first boundary that yields 2+ non-blank pieces, else ``[text]`` so the
    caller stops recursing and reports the input instead of looping.
    """
    for pat in _PHRASE_PATTERNS:
        parts = re.split(pat, text)
        if sum(1 for p in parts if p.strip()) > 1:
            return parts
    return [text]


def _translate_via_phrases(text: str, target: str) -> str | None:
    """Translate a single over-long sentence clause-by-clause and rejoin.

    The path for an input past the length gate that ``_split_into_sentences``
    could not break (one long sentence, a comma list, a markdown link block).
    Each clause routes back through ``nllb_translate`` so the gate + timeout apply
    per clause and a still-long clause splits again; whitespace/separator pieces
    pass through untouched. Returns ``None`` (caller reports + falls back) when no
    boundary exists or nothing translated. Tradeoff: a clause carries less context
    than a whole sentence, so prose may translate slightly less fluently than the
    list/parenthetical inputs this mainly targets.
    """
    parts = _split_into_phrases(text)
    if sum(1 for p in parts if p.strip()) <= 1:
        return None

    out_parts: list[str] = []
    any_translated = False
    for part in parts:
        if not part.strip():
            out_parts.append(part)  # separator / whitespace — keep verbatim
            continue
        core = part.rstrip()
        trailing_ws = part[len(core):]
        translated_one = nllb_translate(core, target)
        if translated_one is not None and translated_one.strip().lower() != core.strip().lower():
            out_parts.append(translated_one + trailing_ws)
            any_translated = True
        else:
            out_parts.append(part)

    if not any_translated:
        return None
    joined = "".join(out_parts).strip()
    if joined.lower() == text.strip().lower():
        return None
    return joined


def nllb_translate(text: str, locale: str) -> str | None:
    """Translate *text* (English) into *locale* via NLLB. None to fall back.

    Lazy-loads the model on first call. Returns None — letting the caller fall
    back to Google — when NLLB is disabled, the locale is unmapped, the model
    can't load, the input exceeds the length gate and won't split, the call
    times out, or the model echoes the source unchanged.
    """
    global _error_logged  # noqa: PLW0603

    if os.environ.get("SAROPA_SKIP_NLLB", "").strip() == "1":
        return None
    plain = (text or "").strip()
    if not plain:
        return None
    target = nllb_lang_code(locale)
    if not target:
        return None
    if not _ensure_model():
        return None

    # Multi-sentence routing FIRST, regardless of length: translating a
    # paragraph as one call risks a timeout whose abandoned worker then holds
    # CTranslate2's mutex and stalls following calls. Per-sentence calls each
    # finish well inside the deadline. Single-sentence inputs (most UI labels)
    # fall through with only the regex-scan overhead.
    if len(_split_into_sentences(plain)) > 1:
        split_result = _translate_via_sentences(plain, locale)
        if split_result is not None:
            return split_result
        # Fall through for one single-shot attempt before the caller's fallback.

    deadline = float(
        os.environ.get("SAROPA_NLLB_STRING_TIMEOUT", str(_DEFAULT_STRING_TIMEOUT_SEC)).strip()
        or _DEFAULT_STRING_TIMEOUT_SEC,
    )
    deadline = max(5.0, min(deadline, 300.0))

    try:
        # NLLB expects the source language tag as the first subword.
        source_tokens = ["eng_Latn"] + _tokenizer.Encode(plain, out_type=str)  # type: ignore[union-attr]
        src_len = len(source_tokens)

        try:
            max_src = int(
                os.environ.get("SAROPA_NLLB_MAX_INPUT_TOKENS", str(_DEFAULT_MAX_SOURCE_TOKENS)).strip()
                or _DEFAULT_MAX_SOURCE_TOKENS,
            )
        except ValueError:
            max_src = _DEFAULT_MAX_SOURCE_TOKENS
        if max_src > 0 and src_len > max_src:
            # Too long for one call. Break it down: first on sentence boundaries,
            # then (for a single long sentence / comma list / link block) on clause
            # boundaries, so NLLB keeps the work instead of dropping to Google.
            split_result = _translate_via_sentences(plain, locale)
            if split_result is not None:
                return split_result
            phrase_result = _translate_via_phrases(plain, locale)
            if phrase_result is not None:
                return phrase_result
            # Genuinely unsplittable atom over the gate: record EVERY occurrence
            # (not just the first) so the run report names every string NLLB could
            # not handle, instead of hiding all but one behind a once-only log.
            _record_long_input(locale, src_len, plain)
            return None

        # max_decoding_length scales with input (3x, floor 20, cap 256) to allow
        # script expansion without giving short inputs a long runway that NLLB
        # fills with repetitions. Greedy (beam_size=1) keeps long low-resource
        # translations inside the wall clock; repetition_penalty + no_repeat
        # stop degenerate loops.
        max_out = max(20, min(src_len * 3, 256))
        results = _translate_batch_with_deadline(
            [source_tokens],
            [[target]],
            deadline_sec=deadline,
            beam_size=1,
            max_decoding_length=max_out,
            repetition_penalty=1.2,
            no_repeat_ngram_size=3,
        )
        if results is None:
            truncated = plain[:80].replace("\n", " ").replace("\r", " ")
            ellipsis = "…" if len(plain) > 80 else ""
            _diag(f"[nllb] translate_batch timed out > {deadline:.0f}s on target={locale!r}, input={truncated!r}{ellipsis}; falling back")
            return None

        # Detokenize: the first output token is the target language tag.
        output_tokens = results[0].hypotheses[0]
        if output_tokens and output_tokens[0] == target:
            output_tokens = output_tokens[1:]
        translated = _tokenizer.Decode(output_tokens)  # type: ignore[union-attr]
        if translated and translated.strip() and translated.strip() != plain:
            return translated.strip()
    except Exception as exc:  # noqa: BLE001
        if not _error_logged:
            _diag(f"[nllb] Translation failed ({type(exc).__name__}): {exc}")
            _error_logged = True
    return None


# ---------------------------------------------------------------------------
# CLI — status / setup / probe
# ---------------------------------------------------------------------------

def _probe() -> int:
    """Empirically test which placeholder-mask scheme NLLB preserves per locale.

    Translates the SAME sentence three ways — raw ``{braces}``, the Google
    ``ZZ0ZZ`` shield, and the NLLB ``__PH0__`` mask — into several scripts and
    reports, for each, whether both markers survived the round-trip verbatim. The
    pipeline can only trust a scheme that SURVIVES across locales; this is the
    evidence the mask choice in mt_fallback (``__PH__``) is the right one, and the
    check this assistant cannot run itself. Loads + runs the model, so it must be
    invoked explicitly by an operator.
    """
    if not _ensure_model():
        print("NLLB model not ready — run --setup first.")
        return 1
    variants = [
        ("raw {braces}", "Show {count} of {total} packages", ["{count}", "{total}"]),
        ("ZZ sentinel", "Show ZZ0ZZ of ZZ1ZZ packages", ["ZZ0ZZ", "ZZ1ZZ"]),
        ("__PH__ underscore", "Show __PH0__ of __PH1__ packages", ["__PH0__", "__PH1__"]),
    ]
    print("Probing placeholder-mask survival through NLLB (both markers must survive verbatim):\n")
    survival: dict[str, int] = {label: 0 for label, _, _ in variants}
    locales = ("ar", "hi", "zh", "ru", "de", "fr")
    for locale in locales:
        print(f"=== {locale} ===")
        for label, masked, markers in variants:
            out = nllb_translate(masked, locale)
            if out is None:
                print(f"  {label:18}: (echoed / no output)")
                continue
            ok = all(m in out for m in markers)
            if ok:
                survival[label] += 1
            print(f"  {label:18}: {'SURVIVED' if ok else 'LOST    '} | {out[:70]}")
        print()
    print("Survival across locales (higher = safer mask):")
    for label, _, _ in variants:
        print(f"  {label:18}: {survival[label]}/{len(locales)}")
    print(
        "\nmt_fallback uses the '__PH__ underscore' mask for NLLB. If a different "
        "scheme scores higher here, update _nllb_mask accordingly.",
    )
    return 0


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="NLLB-200-3.3B engine — status / setup / probe.")
    parser.add_argument("--setup", action="store_true", help="Download + load the model (~7 GB; prompts on TTY).")
    parser.add_argument("--probe", action="store_true", help="Test which placeholder mask NLLB preserves (loads + runs the model).")
    args = parser.parse_args()

    if args.probe:
        os.environ.setdefault("SAROPA_NLLB_ENABLED", "1")
        return _probe()

    if args.setup:
        # Allow the download to proceed without a second env-var hurdle when the
        # operator explicitly asked for setup on a non-interactive shell.
        os.environ.setdefault("SAROPA_NLLB_ENABLED", "1")
        ok = _ensure_model()
        print("NLLB model ready." if ok else "NLLB setup did not complete (see messages above).")
        return 0 if ok else 1

    # Default: report status without downloading or loading.
    model_dir = _resolve_model_dir()
    cached = nllb_model_available()
    print(f"NLLB model dir : {model_dir}")
    print(f"Model cached   : {'yes' if cached else 'no'}")
    if not cached:
        print("Run with --setup to download (~7 GB), or set SAROPA_NLLB_MODEL_DIR to an existing meta_nllb dir.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
