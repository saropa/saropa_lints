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

# ASCII sentinel wrappers for shielded tokens (placeholders + brand terms).
# History: the shield first used Unicode noncharacters (U+FDD0/U+FDD1), then PUA
# code points (U+E000/U+E001). Google Translate mangles BOTH in non-Latin
# scripts -- it strips the wrappers and leaves residue ("0", "q0q") that shipped
# as visible garbage (e.g. Arabic "...q0q {target}"). A plain ASCII token
# round-trips cleanly in every script we ship (measured 48/48 vs 35/48 for PUA
# across ar/he/hi/ja/ru/th/tl/zh). "ZZ" is absent from the catalog, so there is
# no collision risk; the strict integrity check in _fetch_translation rejects
# any result where the exact sentinel failed to survive anyway.
_SHIELD_OPEN = "ZZ"
_SHIELD_CLOSE = "ZZ"

# Brand / proper-noun terms MT must NEVER translate or transliterate. Google
# rendered "Saropa" in local scripts in 124 locale strings; the company name has
# one spelling worldwide. Shielded exactly like placeholders so the engine
# cannot touch it. Longest-first if this grows, to avoid a shorter term
# shielding inside a longer one.
_DO_NOT_TRANSLATE = ("Saropa",)
# Detects leftover sentinel residue from this or any past shield scheme so cached
# values poisoned by the old noncharacter/PUA shields get re-fetched: ASCII core
# "ZZ<n>ZZ", PUA "q<n>q", and the raw marker code points.
_SHIELD_RESIDUE_RE = re.compile(r"ZZ\d+ZZ|q\d+q|[﷐﷑]")

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


# Word-boundary patterns for brand terms (no letter on either side) so "Saropa"
# is shielded but a hypothetical "Saropas" would not be half-shielded.
_BRAND_PATTERNS: dict[str, re.Pattern[str]] = {
    term: re.compile(rf"(?<![A-Za-z]){re.escape(term)}(?![A-Za-z])")
    for term in _DO_NOT_TRANSLATE
}


def _sentinel(index: int) -> str:
    """The shield token for slot *index* (e.g. ``ZZ0ZZ``)."""
    return f"{_SHIELD_OPEN}{index}{_SHIELD_CLOSE}"


def shield_placeholders(text: str) -> tuple[str, list[str]]:
    """Shield ``{tokens}`` AND do-not-translate brand terms with ASCII sentinels.

    Returns ``(masked, originals)`` where ``originals[i]`` is the substring that
    sentinel ``i`` stands for. Placeholders are shielded first, then brand terms,
    so MT can neither rename an interpolation key nor transliterate the brand.
    """
    originals: list[str] = []

    def repl(m: re.Match[str]) -> str:
        originals.append(m.group(0))
        return _sentinel(len(originals) - 1)

    masked = _PLACEHOLDER_FULL.sub(repl, text)
    for term in _DO_NOT_TRANSLATE:
        masked = _BRAND_PATTERNS[term].sub(repl, masked)
    return masked, originals


def _shield_brand_only(text: str) -> tuple[str, list[str]]:
    """Shield only brand terms, leaving ``{braces}`` raw.

    Used by the raw-brace fallback in ``_fetch_translation``: Google preserves
    literal ``{tokens}`` better than sentinels for some placeholder-leading
    strings, but the brand must STILL be protected on that path.
    """
    originals: list[str] = []

    def repl(m: re.Match[str]) -> str:
        originals.append(m.group(0))
        return _sentinel(len(originals) - 1)

    masked = text
    for term in _DO_NOT_TRANSLATE:
        masked = _BRAND_PATTERNS[term].sub(repl, masked)
    return masked, originals


def unshield_placeholders(translated: str, originals: list[str]) -> str:
    """Restore shielded tokens from their sentinels."""
    out = translated
    for i, orig in enumerate(originals):
        out = out.replace(_sentinel(i), orig)
    return out


def _sentinels_intact(translated: str, count: int) -> bool:
    """True when every sentinel ``0..count-1`` survived MT exactly once.

    Stricter than checking the placeholder names: MT sometimes strips a sentinel
    wrapper and leaves residue while a later restore re-appends the real token,
    which passed the loose check and shipped garbage (Arabic "...q0q {target}").
    Requiring the exact sentinel to round-trip rejects those outright.
    """
    return all(translated.count(_sentinel(i)) == 1 for i in range(count))


def _placeholders_preserved(source: str, candidate: str) -> bool:
    """True when *candidate* carries exactly the same ``{tokens}`` as *source*.

    Set comparison, not ordered: languages legitimately reorder placeholders.
    A mismatch means MT dropped, renamed, or leaked a token and the candidate
    must not be trusted.
    """
    return set(_PLACEHOLDER_FULL.findall(source)) == set(_PLACEHOLDER_FULL.findall(candidate))


def _cache_value_is_clean(source: str, cached: str) -> bool:
    """True when a cached translation is safe to serve without re-fetching.

    Rejects three poison classes so they heal on the next run with the current
    engine: placeholder loss/rename, leaked shield residue from any past scheme
    (``q0q`` / ``ZZ0ZZ`` / PUA chars), and brand corruption (a do-not-translate
    term in *source* missing from *cached* because MT transliterated it).
    """
    if not _placeholders_preserved(source, cached):
        return False
    if _SHIELD_RESIDUE_RE.search(cached):
        return False
    for term in _DO_NOT_TRANSLATE:
        if _BRAND_PATTERNS[term].search(source) and term not in cached:
            return False
    return True


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
    # Pure brand: the whole string is a do-not-translate term plus spacing /
    # separators. MT can only echo or transliterate it, so keep English
    # ("Saropa", "Saropa "). Counting these as missing forever is noise — the
    # brand has one spelling worldwide.
    brandless = s
    for term in _DO_NOT_TRANSLATE:
        brandless = _BRAND_PATTERNS[term].sub("", brandless)
    if brandless != s and re.fullmatch(r"[\s·—…▶↪]*", brandless):
        return True
    # Single-letter label wrapping placeholders: once the {tokens} are removed
    # nothing translatable remains, and MT only renames the token ("L{line}" ->
    # "L{Linie}"). Keep the English label. Residue must be exactly one ASCII
    # letter so real phrases ("of {total}") are unaffected.
    residue = re.sub(r"[\s\W_]+", "", _PLACEHOLDER_FULL.sub("", s), flags=re.UNICODE)
    if _PLACEHOLDER_FULL.search(s) and len(residue) == 1 and residue.isascii() and residue.isalpha():
        return True
    return False


def _translate_with_retry(gt: object, payload: str) -> str | None:
    """`_translate_masked_with_timeout` wrapped in TooManyRequests backoff.

    Returns the raw translated string, or None on hard failure / repeated
    rate-limiting. Re-raises ``KeyboardInterrupt`` so callers can save the
    partial cache and exit cleanly.
    """
    try:
        from deep_translator.exceptions import TooManyRequests  # type: ignore[import-untyped]
    except ImportError:  # deep-translator absent — nothing specific to back off on
        TooManyRequests = ()  # type: ignore[assignment]
    for attempt in range(4):
        try:
            raw = _translate_masked_with_timeout(gt, payload)
            if raw is not None:
                return raw
        except TooManyRequests:  # type: ignore[misc]
            time.sleep(6.0 + float(attempt) * 3.0)
        except KeyboardInterrupt:
            raise
        except Exception:  # noqa: BLE001 — any other engine failure is non-retryable here
            return None
    return None


def _accept(text: str, candidate: str) -> bool:
    """True when *candidate* is a usable translation: placeholders intact, no
    leaked sentinel residue, and actually different from the English source."""
    return (
        candidate is not None
        and candidate.strip() != ""
        and candidate != text
        and _placeholders_preserved(text, candidate)
        and not _SHIELD_RESIDUE_RE.search(candidate)
    )


def _fetch_translation(gt: object, text: str) -> str | None:
    """Translate *text* preserving every ``{token}`` and brand term, or give up.

    Two stages, because Google handles shielded tokens inconsistently:
      1. Shield placeholders + brand with ASCII sentinels, translate, and accept
         only if every sentinel round-tripped EXACTLY (``_sentinels_intact``) and
         the unshielded result has no residue and changed the text.
      2. Otherwise retry with RAW ``{braces}`` (which Google preserves better for
         placeholder-leading strings) while STILL shielding the brand, so the
         brand can never be transliterated on this path either.

    Returns a clean translation, or — when MT only ever echoes the source — the
    identical-but-clean source so the coverage gate flags it for curation rather
    than shipping garbage. ``None`` when the engine returned nothing usable.
    """
    masked, holders = shield_placeholders(text)
    n = len(holders)
    shielded = _translate_with_retry(gt, masked)
    echoed_clean: str | None = None
    if shielded is not None and shielded.strip() and _sentinels_intact(shielded, n):
        restored = unshield_placeholders(shielded, holders)
        if _accept(text, restored):
            return restored
        # MT echoed the source unchanged (or only the brand differs); remember it
        # as a clean last resort but try the raw-brace path first.
        if restored == text and not _SHIELD_RESIDUE_RE.search(restored):
            echoed_clean = restored

    # Raw-brace fallback (brand still shielded).
    brand_masked, brand_holders = _shield_brand_only(text)
    if _PLACEHOLDER_FULL.search(text) or brand_holders:
        raw = _translate_with_retry(gt, brand_masked)
        if raw is not None and raw.strip() and _sentinels_intact(raw, len(brand_holders)):
            cand = unshield_placeholders(raw, brand_holders)
            if _accept(text, cand):
                return cand

    return echoed_clean


def machine_translate(text: str, locale: str, *, cache: dict[str, str]) -> str:
    """Translate *text* from English to *locale*; update *cache* in memory."""
    if locale == "en" or should_skip_machine_translate(text):
        return text
    google_lang = LOCALE_TO_GOOGLE.get(locale)
    if not google_lang:
        return text

    ck = _cache_key(locale, text)
    cached = cache.get(ck)
    # Self-heal: serve the cache only when the entry is clean. Poisoned entries
    # (placeholder loss, leaked sentinel residue, transliterated brand) are
    # re-fetched with the current engine instead of shipped. Without this the old
    # noncharacter/PUA-shield corruption and brand transliteration would survive
    # in the cache forever.
    if cached is not None and _cache_value_is_clean(text, cached):
        return cached

    if not _mt_env_enabled():
        # No network allowed; a poisoned cache entry can't be healed, so fall back
        # to English (the coverage gate flags it) rather than ship garbage.
        return text

    try:
        from deep_translator import GoogleTranslator  # type: ignore[import-untyped]
    except ImportError:
        return text

    gt = GoogleTranslator(source="en", target=google_lang)
    out = _fetch_translation(gt, text)
    if isinstance(out, str) and out.strip():
        cache[ck] = out
        time.sleep(_MT_REQUEST_GAP_SEC)
        return out
    return text


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
        cached = cache.get(_cache_key(locale, text))
        # Re-fetch when absent OR when the cached entry is poisoned (placeholder
        # loss, leaked sentinel residue, transliterated brand). Skipping poisoned
        # entries here would leave them broken because prefetch never revisits them.
        if cached is not None and _cache_value_is_clean(text, cached):
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
    except ImportError:
        return

    pending = list(_iter_pending_texts(locale, texts, cache=cache, dict_table=dict_table))
    if not pending:
        return

    gt = GoogleTranslator(source="en", target=google_lang)
    for src in pending:
        # Shared fetch path: PUA-shield with raw-brace fallback, same as
        # machine_translate, so cached results are identical regardless of which
        # entry point warmed them. _translate_with_retry re-raises
        # KeyboardInterrupt for the caller to save the partial cache.
        out = _fetch_translation(gt, src)
        if isinstance(out, str) and out.strip():
            cache[_cache_key(locale, src)] = out
        time.sleep(_MT_REQUEST_GAP_SEC)

