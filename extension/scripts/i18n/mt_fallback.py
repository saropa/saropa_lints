"""Optional machine translation fallback for locale generation.

Used when an English string has no curated dictionary entry. Batched
``translate_batch`` calls keep regen time reasonable; results are cached under
``.cache/mt_strings.json`` so repeat runs are offline.

Enable: ``pip install deep-translator`` and ``SAROPA_I18N_MACHINE_TRANSLATE=1``.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import threading
import time
from pathlib import Path

# Match `{token}` segments so machine translation cannot rename interpolation keys.
_PLACEHOLDER_FULL = re.compile(r"\{[A-Za-z0-9_]+\}")
_CACHE_DIR = Path(__file__).resolve().parent / ".cache"
_CACHE_PATH = _CACHE_DIR / "mt_strings.json"

# Google Translate target codes (deep-translator / Google).
LOCALE_TO_GOOGLE: dict[str, str] = {
    "ar": "ar",
    "bn": "bn",
    "de": "de",
    "es": "es",
    "fa": "fa",
    "fil": "tl",
    "fr": "fr",
    # ISO 639-1 ``he``; Google / deep-translator expect legacy ``iw``.
    "he": "iw",
    "hi": "hi",
    "id": "id",
    "it": "it",
    "ja": "ja",
    "ko": "ko",
    "nl": "nl",
    "pl": "pl",
    "pt": "pt",
    "ru": "ru",
    "sw": "sw",
    "th": "th",
    "tr": "tr",
    "uk": "uk",
    "ur": "ur",
    "vi": "vi",
    "zh": "zh-CN",
}

def _mt_env_enabled() -> bool:
    # Opt-in: avoids surprise network use from ``generate_locales.py`` in CI.
    return os.environ.get("SAROPA_I18N_MACHINE_TRANSLATE", "0").strip().lower() in {
        "1",
        "true",
        "yes",
        "on",
    }


def load_mt_cache() -> dict[str, str]:
    if not _CACHE_PATH.is_file():
        return {}
    try:
        raw = json.loads(_CACHE_PATH.read_text(encoding="utf-8"))
        return raw if isinstance(raw, dict) else {}
    except (json.JSONDecodeError, OSError):
        return {}


def save_mt_cache(cache: dict[str, str]) -> None:
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    _CACHE_PATH.write_text(json.dumps(cache, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")


def _cache_key(locale: str, text: str) -> str:
    # Bump prefix when MT pipeline changes (invalidate stale cache entries).
    h = hashlib.sha256(f"v2|{locale}\n{text}".encode("utf-8")).hexdigest()
    return f"{locale}:{h}"


def shield_placeholders(text: str) -> tuple[str, list[str]]:
    """Replace ``{tokens}`` with U+FDD0..sentinels so MT cannot rewrite keys."""
    originals: list[str] = []

    def repl(_m: re.Match[str]) -> str:
        originals.append(_m.group(0))
        return f"\ufdd0{len(originals) - 1}\ufdd1"

    return _PLACEHOLDER_FULL.sub(repl, text), originals


def unshield_placeholders(translated: str, originals: list[str]) -> str:
    """Restore ``{tokens}`` from ``shield_placeholders`` sentinels."""
    out = translated
    for i, orig in enumerate(originals):
        out = out.replace(f"\ufdd0{i}\ufdd1", orig)
    return out


def _translate_masked_with_timeout(
    gt: object,
    masked: str,
    *,
    timeout_sec: float = 28.0,
) -> str | None:
    """Run ``gt.translate(masked)`` in a worker thread so hung HTTP cannot stall forever."""
    out: list[str | None] = [None]
    err: list[BaseException | None] = [None]

    def worker() -> None:
        try:
            translated = gt.translate(masked)  # type: ignore[union-attr]
            out[0] = translated if isinstance(translated, str) else None
        except BaseException as exc:  # noqa: BLE001 — propagate any translator failure
            err[0] = exc

    th = threading.Thread(target=worker, daemon=True)
    th.start()
    th.join(timeout=timeout_sec)
    if th.is_alive():
        return None
    if err[0] is not None:
        raise err[0]
    return out[0]


def should_skip_machine_translate(text: str) -> bool:
    s = text.strip()
    if not s:
        return True
    # Letter-grade badges (vibrancy summary); MT would turn "A" into words.
    if len(s) == 1 and s.isalpha() and s.isupper():
        return True
    # Punctuation / ellipsis-only fragments.
    if re.fullmatch(r"[\s\u00b7\u2014\u2026\u25b6\u21aa]+", s):
        return True
    # Pure placeholder lines (rare) — keep English shape.
    if re.fullmatch(r"(\{[A-Za-z0-9_]+\})+", s):
        return True
    return False


def machine_translate(text: str, locale: str, *, cache: dict[str, str]) -> str:
    """Translate *text* from English to *locale*; update *cache* in memory."""
    if locale == "en" or should_skip_machine_translate(text):
        return text
    google_lang = LOCALE_TO_GOOGLE.get(locale)
    if not google_lang:
        return text

    ck = _cache_key(locale, text)
    if ck in cache:
        return cache[ck]

    if not _mt_env_enabled():
        return text

    try:
        from deep_translator import GoogleTranslator  # type: ignore[import-untyped]
        from deep_translator.exceptions import TooManyRequests  # type: ignore[import-untyped]
    except ImportError:
        return text

    masked, holders = shield_placeholders(text)
    raw: str | None = None
    gt = GoogleTranslator(source="en", target=google_lang)
    for attempt in range(4):
        try:
            raw = _translate_masked_with_timeout(gt, masked)
            if raw is not None:
                break
        except TooManyRequests:
            time.sleep(6.0 + float(attempt) * 3.0)
        except Exception:
            raw = None
            break
    if not isinstance(raw, str) or not raw.strip():
        return text
    out = unshield_placeholders(raw, holders)
    cache[ck] = out
    time.sleep(0.22)
    return out


# Pace Google free tier (~5 req/s); ``prefetch`` does one call per string with this gap.
_MT_REQUEST_GAP_SEC = 0.22


def _iter_pending_texts(
    locale: str,
    texts: list[str],
    *,
    cache: dict[str, str],
    dict_table: dict[str, str],
):
    """Yield strings that would require a fresh MT network call.

    Shared by ``count_pending_translations`` and ``prefetch_machine_translations``
    so both apply identical filter rules — keep them in lockstep here.
    """
    for text in texts:
        if not text or text in dict_table or should_skip_machine_translate(text):
            continue
        if _cache_key(locale, text) in cache:
            continue
        yield text


def count_pending_translations(
    locale: str,
    texts: list[str],
    *,
    cache: dict[str, str],
    dict_table: dict[str, str],
) -> int:
    """How many strings prefetch would hit the network for. 0 when MT is disabled."""
    if locale == "en" or not _mt_env_enabled():
        return 0
    if not LOCALE_TO_GOOGLE.get(locale):
        return 0
    return sum(1 for _ in _iter_pending_texts(locale, texts, cache=cache, dict_table=dict_table))


def prefetch_machine_translations(
    locale: str,
    texts: list[str],
    *,
    cache: dict[str, str],
    dict_table: dict[str, str],
) -> None:
    """Translate strings missing from *dict_table* and *cache* (sequential, rate-limited).

    Raises ``KeyboardInterrupt`` so the caller can save the partial cache and
    exit cleanly. Anything fetched before interrupt is already in *cache*.
    """
    if locale == "en" or not _mt_env_enabled():
        return
    google_lang = LOCALE_TO_GOOGLE.get(locale)
    if not google_lang:
        return
    try:
        from deep_translator import GoogleTranslator  # type: ignore[import-untyped]
        from deep_translator.exceptions import TooManyRequests  # type: ignore[import-untyped]
    except ImportError:
        return

    pending = list(_iter_pending_texts(locale, texts, cache=cache, dict_table=dict_table))
    if not pending:
        return

    gt = GoogleTranslator(source="en", target=google_lang)
    for src in pending:
        msk, hld = shield_placeholders(src)
        raw: str | None = None
        for attempt in range(4):
            try:
                raw = _translate_masked_with_timeout(gt, msk)
                if raw is not None:
                    break
            except TooManyRequests:
                time.sleep(6.0 + float(attempt) * 3.0)
            except KeyboardInterrupt:
                # Re-raise so the top-level handler can save the cache; do not
                # swallow it as a generic Exception below.
                raise
            except Exception:
                raw = None
                break
        if isinstance(raw, str) and raw.strip():
            cache[_cache_key(locale, src)] = unshield_placeholders(raw, hld)
        time.sleep(_MT_REQUEST_GAP_SEC)

