"""Optional machine translation fallback for locale generation.

Used when an English string has no curated dictionary entry. Results are cached
under ``.cache/mt_strings.json`` so repeat runs are offline.

Primary engine: Qwen 3 via local Ollama (``qwen_engine.py``). Google Translate
(``deep-translator``) is the per-string fallback when Qwen returns None.

Enable: ``pip install deep-translator`` and ``SAROPA_I18N_MACHINE_TRANSLATE=1``.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import threading
import time
from collections.abc import Callable
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

# Brand / proper-noun terms MT must NEVER translate or transliterate. Each has one
# spelling worldwide (like "Google" or "Apple"). Shielded exactly like placeholders
# so the engine cannot touch it. MT had translated the *non-Saropa* half of the
# product name ("Saropa Lints" -> "Saropa Fusseln/Pelusas/糸くず/…") and the tool
# names ("VS Code" -> "VS Kodu/код VS", "pub.dev" -> "पब.डेव", "OWASP" -> "オワスプ")
# across 300+ locale strings because only "Saropa" itself was on this list.
# ORDER MATTERS: longest / most specific first, so a shorter term cannot shield
# inside a longer one — "Saropa Lints" must be masked as a unit before bare
# "Saropa" can grab the "Saropa" inside it.
# Code identifiers (file names, config keys, package names, CLI invocations) are
# ALSO included: MT had transliterated/translated them too — "violations.json" ->
# "الانتهاكات.json", "saropa_lints" -> "सरोपा_लिंट्स", "dart analyze" -> "تحليل الأسهم"
# ("dart" read as the projectile). A code identifier is literal in every language.
_DO_NOT_TRANSLATE = (
    # Longest / most specific first.
    "workspace.textDocuments",
    "analysis_options",
    "dev_dependencies",
    "violations.json",
    "pubspec.yaml",
    "pubspec.lock",
    "build_runner",
    "saropa_lints",
    "dart analyze",
    "dart format",
    "Drift Advisor",
    "Saropa Lints",
    "VS Code",
    "pub.dev",
    "GitHub",
    "Flutter",
    "OWASP",
    "Daemon",
    "SPDX",
    "Dart",
    "RSS",
    "PID",
    "OSV",
    "Saropa",
)
# Detects leftover sentinel residue from this or any past shield scheme so cached
# values poisoned by the old noncharacter/PUA shields get re-fetched: ASCII core
# "ZZ<n>ZZ", PUA "q<n>q", and the raw marker code points.
_SHIELD_RESIDUE_RE = re.compile(r"ZZ\d+ZZ|q\d+q|[﷐﷑]")

# LLM control tokens that must never appear in a cached translation. Rejects the
# value so it heals on the next run. Covers Qwen, Llama, ChatML, and Mistral
# chat-template tokens.
_LLM_CONTROL_TOKENS = [
    "/no_think", "/think",
    "<|endoftext|>", "<|im_start|>", "<|im_end|>",
    "<|im_sep|>", "<|endofprompt|>",
    "<|assistant|>", "<|user|>", "<|system|>",
    "[INST]", "[/INST]", "<<SYS>>", "<</SYS>>",
]
_LLM_CONTROL_RE = re.compile(
    "|".join(re.escape(t) for t in _LLM_CONTROL_TOKENS),
)

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


# ---------------------------------------------------------------------------
# Persistent per-key engine provenance (sidecar to the value cache).
#
# Records the actual producing engine per cache key so a run can upgrade
# low-quality entries and protect manual overrides from re-translation.
# Engines: 'qwen*', 'google', 'english', 'manual', legacy 'nllb'.
# ---------------------------------------------------------------------------
_PROVENANCE_PATH = _CACHE_DIR / "mt_provenance.json"
_provenance: dict[str, str] = {}

# Provenance values that rank BELOW Qwen and are therefore re-translation
# candidates in 'upgrade' mode. 'qwen*' and 'manual' are never re-translated.
# Includes legacy 'nllb' entries from before the engine swap.
_LOW_QUALITY_PROVENANCE = frozenset({"google", "english", "legacy", "nllb", ""})

# Flush the value cache + provenance to disk every N translated strings so a long
# single-locale run survives a hard kill (or the cooperative stop) without losing
# more than this many strings of work.
_CHECKPOINT_EVERY = 25


def load_provenance() -> None:
    """Load the provenance sidecar into the module dict. Call once per run."""
    _provenance.clear()
    if _PROVENANCE_PATH.is_file():
        try:
            raw = json.loads(_PROVENANCE_PATH.read_text(encoding="utf-8"))
            if isinstance(raw, dict):
                _provenance.update({str(k): str(v) for k, v in raw.items()})
        except (json.JSONDecodeError, OSError):
            pass


def save_provenance() -> None:
    _CACHE_DIR.mkdir(parents=True, exist_ok=True)
    _PROVENANCE_PATH.write_text(
        json.dumps(_provenance, ensure_ascii=False, indent=0) + "\n", encoding="utf-8",
    )


def provenance_of(locale: str, text: str) -> str | None:
    """Engine that produced the cached translation for (locale, text), or None."""
    primary = _primary_engine(locale) or "google"
    return _provenance.get(_cache_key(locale, text, primary))


# ---------------------------------------------------------------------------
# Cooperative cancellation. The entry point installs a SIGINT handler that calls
# request_stop(); the prefetch loop checks stop_requested() between strings.
# ---------------------------------------------------------------------------
_stop_requested = False


def request_stop() -> None:
    global _stop_requested  # noqa: PLW0603
    _stop_requested = True


def clear_stop() -> None:
    global _stop_requested  # noqa: PLW0603
    _stop_requested = False


def stop_requested() -> bool:
    return _stop_requested


# ---------------------------------------------------------------------------
# Mode pruning + key management. Translation 'modes' are expressed as a pre-run
# cache prune followed by the normal gap-fill: removing an entry turns it back
# into a gap the next prefetch re-translates. This reuses ALL the gap-fill logic
# instead of threading a mode flag through every fetch.
# ---------------------------------------------------------------------------

def prune_low_quality(
    cache: dict[str, str], locale: str, texts: list[str], dict_table: dict[str, str],
) -> int:
    """'upgrade' mode: drop cached entries for *locale* whose provenance ranks
    below Qwen, so the next run re-translates them via Qwen. No-op unless Qwen is
    the locale's primary engine. Returns the number removed.
    """
    if _primary_engine(locale) != "qwen":
        return 0
    removed = 0
    for text in texts:
        if not text or text in dict_table:
            continue
        key = _cache_key(locale, text, "qwen")
        if key in cache and _provenance.get(key, "") in _LOW_QUALITY_PROVENANCE:
            cache.pop(key, None)
            _provenance.pop(key, None)
            removed += 1
    return removed


def low_quality_entries(
    cache: dict[str, str], locale: str, texts: list[str], dict_table: dict[str, str],
) -> list[str]:
    """Audit counterpart to prune_low_quality: return source strings whose cached
    translation ranks below Qwen. Empty unless Qwen is the primary engine.
    """
    if _primary_engine(locale) != "qwen":
        return []
    found: list[str] = []
    for text in texts:
        if not text or text in dict_table:
            continue
        key = _cache_key(locale, text, "qwen")
        if key in cache and _provenance.get(key, "") in _LOW_QUALITY_PROVENANCE:
            found.append(text)
    return found


def prune_all(
    cache: dict[str, str], locale: str, texts: list[str], dict_table: dict[str, str],
) -> int:
    """'all' mode: drop every cached entry for *locale* EXCEPT manual overrides
    (the operator set those deliberately), forcing a full re-translate. Returns
    the number removed.
    """
    primary = _primary_engine(locale) or "google"
    removed = 0
    for text in texts:
        if not text or text in dict_table:
            continue
        key = _cache_key(locale, text, primary)
        if key in cache and _provenance.get(key, "") != "manual":
            cache.pop(key, None)
            _provenance.pop(key, None)
            removed += 1
    return removed


def cache_set(cache: dict[str, str], locale: str, english: str, value: str) -> str:
    """Manually override the translation for (locale, english). Marks provenance
    'manual' so upgrade/force runs never overwrite it. Returns the cache key."""
    primary = _primary_engine(locale) or "google"
    key = _cache_key(locale, english, primary)
    cache[key] = value
    _provenance[key] = "manual"
    return key


def cache_unset(cache: dict[str, str], locale: str, english: str) -> bool:
    """Remove the cached translation + provenance for (locale, english) so it is
    re-translated next run. Returns True if an entry existed."""
    primary = _primary_engine(locale) or "google"
    key = _cache_key(locale, english, primary)
    existed = key in cache or key in _provenance
    cache.pop(key, None)
    _provenance.pop(key, None)
    return existed


def cache_lookup(cache: dict[str, str], locale: str, english: str) -> tuple[str | None, str | None]:
    """Return (value, provenance) for (locale, english), or (None, None)."""
    primary = _primary_engine(locale) or "google"
    key = _cache_key(locale, english, primary)
    return cache.get(key), _provenance.get(key)


def cache_lookup_any(
    cache: dict[str, str], locale: str, english: str
) -> tuple[str | None, str | None]:
    """Engine-agnostic lookup: return a cached value from ANY engine's keyspace.

    Probes Qwen, legacy NLLB, and Google keyspaces so coverage counts are
    independent of which engine happens to be available right now.
    """
    for engine in ("qwen", "nllb", "google"):
        key = _cache_key(locale, english, engine)
        value = cache.get(key)
        if value is not None:
            return value, _provenance.get(key)
    return None, None


def _cache_key(locale: str, text: str, engine: str = "google") -> str:
    h = hashlib.sha256(f"v2|{locale}\n{text}".encode("utf-8")).hexdigest()
    # Google/legacy entries keep the bare ``locale:hash`` form; other engines
    # (qwen, nllb) namespace by name so translations coexist.
    return f"{locale}:{h}" if engine == "google" else f"{engine}:{locale}:{h}"


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

    Rejects four poison classes so they heal on the next run with the current
    engine: placeholder loss/rename, leaked shield residue from any past scheme
    (``q0q`` / ``ZZ0ZZ`` / PUA chars), brand corruption (a do-not-translate
    term in *source* missing from *cached* because MT transliterated it), and
    LLM control tokens leaked into the translation output.
    """
    if not _placeholders_preserved(source, cached):
        return False
    if _SHIELD_RESIDUE_RE.search(cached):
        return False
    if _LLM_CONTROL_RE.search(cached):
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


_SKIP_EXACT: frozenset[str] = frozenset({
    "Daemon",
    "PID",
    "RSS",
})


def should_skip_machine_translate(text: str) -> bool:
    s = text.strip()
    if not s:
        return True
    if s in _SKIP_EXACT:
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
    # Emoji/symbol + placeholder only ("⚠ {size}", "🔴 {size}").
    # Require at least one non-ASCII char so ASCII-only prefixes like "* {x}"
    # are not silently skipped.
    if re.fullmatch(r"[^\w{}]+\s*(\{[A-Za-z0-9_]+\}\s*)+", s) and re.search(r"[^\x00-\x7f]", s):
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
    # Brand + placeholders + separators only ("Saropa Lints: {message}",
    # "Saropa Lints {label}: {from} → {to}"): once the shielded brand AND the
    # {tokens} are stripped, only punctuation/whitespace remains, so MT can only
    # echo the source — yet the unchanged echo is counted as Missing forever. The
    # pure-brand case above misses this because a placeholder survives brand
    # stripping; the single-letter-label case below misses it because the brand
    # leaves more than one letter once tokens are removed. Gate on "no alphanumeric
    # remains" (any script) so a real word next to the brand still translates.
    if brandless != s:
        non_brand_residue = _PLACEHOLDER_FULL.sub("", brandless)
        if not any(ch.isalnum() for ch in non_brand_residue):
            return True
    # Placeholders + punctuation/whitespace only ("{category} ({count})",
    # "{symbol} ({count})"): once {tokens} are stripped, no translatable word
    # remains — MT can only echo or corrupt the template. Copy verbatim.
    residue = re.sub(r"[\s\W_]+", "", _PLACEHOLDER_FULL.sub("", s), flags=re.UNICODE)
    if _PLACEHOLDER_FULL.search(s) and not any(ch.isalnum() for ch in residue):
        return True
    # Single-letter label wrapping placeholders: once the {tokens} are removed
    # nothing translatable remains, and MT only renames the token ("L{line}" ->
    # "L{Linie}"). Keep the English label. Residue must be exactly one ASCII
    # letter so real phrases ("of {total}") are unaffected.
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


def _fetch_translation(translate_fn, text: str) -> str | None:
    """Translate *text* preserving every ``{token}`` and brand term, or give up.

    Engine-agnostic: *translate_fn* takes a (possibly shielded) string and
    returns the engine's raw output or ``None``. Google and Qwen both plug in
    here so the shield / validate / echo handling stays identical across engines.

    Two stages, because engines handle shielded tokens inconsistently:
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
    shielded = translate_fn(masked)
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
        raw = translate_fn(brand_masked)
        if raw is not None and raw.strip() and _sentinels_intact(raw, len(brand_holders)):
            cand = unshield_placeholders(raw, brand_holders)
            if _accept(text, cand):
                return cand

    return echoed_clean


def _qwen_active_for(locale: str) -> bool:
    """True when the local Qwen/Ollama engine is available for this locale."""
    if os.environ.get("SAROPA_SKIP_QWEN", "").strip() == "1":
        return False
    try:
        import qwen_engine  # local sibling module (extension/scripts/i18n)
    except ImportError:
        return False
    if qwen_engine.qwen_lang_code(locale) is None:
        return False
    return qwen_engine.qwen_model_available()


def _primary_engine(locale: str) -> str | None:
    """Primary MT engine for *locale*: ``"qwen"`` when Ollama is available,
    else ``"google"``, else ``None`` (no engine can handle the locale)."""
    if locale == "en":
        return None
    if _qwen_active_for(locale):
        return "qwen"
    if LOCALE_TO_GOOGLE.get(locale):
        return "google"
    return None


def active_engine_name(locale: str) -> str | None:
    """Public name of the primary engine for *locale* (``"qwen"`` / ``"google"`` /
    ``None``), for callers that want to log which engine a run will use."""
    return _primary_engine(locale)


def describe_engine_availability() -> str:
    """One-line human summary of which MT engine the run will use."""
    if os.environ.get("SAROPA_SKIP_QWEN", "").strip() == "1":
        return "Qwen disabled (SAROPA_SKIP_QWEN=1) — using Google Translate."
    try:
        import qwen_engine
    except ImportError:
        return "Qwen engine module not found — using Google Translate."
    if qwen_engine.qwen_model_available():
        tag = qwen_engine._model_tag()
        return f"Qwen ({tag}) available — primary engine (Google fallback per string)."
    return (
        "Qwen/Ollama not available — using Google Translate. For higher quality "
        "install Ollama from https://ollama.com/download (model pull is automatic)."
    )


def _google_fetch(locale: str, text: str) -> str | None:
    """Translate via Google (deep-translator), preserving placeholders + brand.

    Returns a clean translation, an echoed-clean source, or ``None``. Sleeps the
    free-tier pacing gap only after an accepted result so we never throttle on a
    failed call.
    """
    google_lang = LOCALE_TO_GOOGLE.get(locale)
    if not google_lang:
        return None
    try:
        from deep_translator import GoogleTranslator  # type: ignore[import-untyped]
    except ImportError:
        return None
    gt = GoogleTranslator(source="en", target=google_lang)
    out = _fetch_translation(lambda m: _translate_with_retry(gt, m), text)
    if isinstance(out, str) and out.strip():
        time.sleep(_MT_REQUEST_GAP_SEC)
    return out


def _qwen_fetch(locale: str, text: str) -> str | None:
    """Translate via the local Qwen/Ollama model, preserving placeholders + brand.

    Uses the same ``_fetch_translation`` shield/validate path as Google so
    placeholder + brand handling stays identical. Returns ``None`` — so the
    caller falls back to Google — when Qwen returns nothing usable.
    """
    try:
        import qwen_engine  # local sibling module
    except ImportError:
        return None
    out = _fetch_translation(
        lambda masked: qwen_engine.qwen_translate(masked, locale),
        text,
    )
    return out


# Per-locale, per-run tally of which engine actually produced each served
# string. Keyed locale -> engine -> count. Engines: 'qwen', 'google',
# 'english' (no engine produced a real translation), 'cached' (served from a
# prior run's cache; original engine not re-derived).
_engine_stats: dict[str, dict[str, int]] = {}


def _record_engine(locale: str, engine: str) -> None:
    _engine_stats.setdefault(locale, {})
    _engine_stats[locale][engine] = _engine_stats[locale].get(engine, 0) + 1


def engine_stats_for(locale: str) -> dict[str, int]:
    """Engine tally for *locale* this run (see ``_engine_stats``)."""
    return dict(_engine_stats.get(locale, {}))


# Every string Qwen did not produce — served by Google or left English instead.
# Entries: (locale, engine 'google'|'english', source text).
_fallback_log: list[tuple[str, str, str]] = []


def _record_fallback(locale: str, engine: str, text: str) -> None:
    _fallback_log.append((locale, engine, text))


def fallback_log() -> list[tuple[str, str, str]]:
    """Every (locale, engine, source) Qwen could not translate this run."""
    return list(_fallback_log)


def reset_engine_stats() -> None:
    """Clear the per-run engine tally and fallback log. Call once per run start."""
    _engine_stats.clear()
    _fallback_log.clear()


def _translate_one(locale: str, text: str, *, cache: dict[str, str], primary: str) -> str:
    """Translate one string under *primary* (Qwen or Google) with Google fallback."""
    key = _cache_key(locale, text, primary)
    cached = cache.get(key)
    if cached is not None and _cache_value_is_clean(text, cached):
        _record_engine(locale, "cached")
        return cached

    # Promote a clean legacy translation (NLLB/Google) to the current engine's
    # keyspace so "gaps only" doesn't re-translate the entire catalog after an
    # engine swap. The value is served as-is; "upgrade" mode prunes these later.
    any_cached, any_prov = cache_lookup_any(cache, locale, text)
    if any_cached is not None and _cache_value_is_clean(text, any_cached):
        cache[key] = any_cached
        _provenance[key] = any_prov or "legacy"
        _record_engine(locale, "cached")
        return any_cached

    if stop_requested():
        return text

    if not _mt_env_enabled():
        _record_engine(locale, "english")
        return text

    out: str | None = None
    used = "english"
    if primary == "qwen":
        out = _qwen_fetch(locale, text)
        if out is not None:
            used = "qwen"
        else:
            out = _google_fetch(locale, text)
            if isinstance(out, str) and out.strip():
                used = "google"
    else:
        out = _google_fetch(locale, text)
        if isinstance(out, str) and out.strip():
            used = "google"

    if isinstance(out, str) and out.strip():
        cache[key] = out
        eng = "english" if out == text else used
        _provenance[key] = eng
        _record_engine(locale, eng)
        if eng == "english" or (eng == "google" and primary == "qwen"):
            _record_fallback(locale, eng, text)
        return out
    _record_engine(locale, "english")
    _record_fallback(locale, "english", text)
    return text


def machine_translate(text: str, locale: str, *, cache: dict[str, str]) -> str:
    """Translate *text* from English to *locale*; update *cache* in memory.

    Uses the local Qwen/Ollama model as the primary engine when available,
    falling back to Google per string.
    """
    if locale == "en" or should_skip_machine_translate(text):
        return text
    primary = _primary_engine(locale)
    if primary is None:
        return text
    return _translate_one(locale, text, cache=cache, primary=primary)


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
    so both apply identical filter rules — keep them in lockstep here. Pending is
    measured against the locale's PRIMARY engine key (Qwen when available, else
    Google).
    """
    primary = _primary_engine(locale)
    if primary is None:
        return
    for text in texts:
        if not text or text in dict_table or should_skip_machine_translate(text):
            continue
        # Check primary engine key first, then fall back to any engine's keyspace.
        # After engine swap (NLLB→Qwen), the primary key is empty but a valid
        # translation exists under the old engine's key — that is NOT a gap.
        cached = cache.get(_cache_key(locale, text, primary))
        if cached is not None and _cache_value_is_clean(text, cached):
            continue
        # Probe legacy keyspaces so "gaps only" doesn't re-translate everything.
        any_cached, _ = cache_lookup_any(cache, locale, text)
        if any_cached is not None and _cache_value_is_clean(text, any_cached):
            continue
        yield text


def count_pending_translations(
    locale: str,
    texts: list[str],
    *,
    cache: dict[str, str],
    dict_table: dict[str, str],
) -> int:
    """How many strings prefetch would translate. 0 when MT is disabled."""
    if locale == "en" or not _mt_env_enabled():
        return 0
    if _primary_engine(locale) is None:
        return 0
    return sum(1 for _ in _iter_pending_texts(locale, texts, cache=cache, dict_table=dict_table))


def prefetch_machine_translations(
    locale: str,
    texts: list[str],
    *,
    cache: dict[str, str],
    dict_table: dict[str, str],
    progress: Callable[[int, int, str], None] | None = None,
) -> None:
    """Translate strings missing from *dict_table* and *cache* (sequential, rate-limited).

    Raises ``KeyboardInterrupt`` so the caller can save the partial cache and
    exit cleanly. Anything fetched before interrupt is already in *cache*.

    *progress*, when supplied, is called after each string with
    ``(done, total, source)`` so the caller can render a live throughput / ETA
    bar. Presentation lives in the caller (``generate_locales``) — this loop owns
    only the per-string completion signal, not how it is displayed. The source
    string is passed so the caller can size throughput by word count (the
    operator-requested "words per minute").
    """
    if locale == "en" or not _mt_env_enabled():
        return
    primary = _primary_engine(locale)
    if primary is None:
        return

    pending = list(_iter_pending_texts(locale, texts, cache=cache, dict_table=dict_table))
    if not pending:
        return

    total = len(pending)
    for i, src in enumerate(pending):
        if stop_requested():
            break
        _translate_one(locale, src, cache=cache, primary=primary)
        if progress is not None:
            progress(i + 1, total, src)
        # Periodic checkpoint so a hard kill mid-locale loses at most
        # _CHECKPOINT_EVERY strings of work, not the whole locale.
        if (i + 1) % _CHECKPOINT_EVERY == 0:
            save_mt_cache(cache)
            save_provenance()

