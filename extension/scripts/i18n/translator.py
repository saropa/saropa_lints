"""Translation engine with placeholder-safe fallback behavior."""

from __future__ import annotations

import re
from typing import Dict

from dictionaries import TRANSLATIONS
from mt_fallback import machine_translate


PLACEHOLDER_RE = re.compile(r"\{([A-Za-z0-9_]+)\}")


def restore_placeholders(source: str, translated: str) -> str:
    """Keep ``{tokens}`` aligned with *source* when the engine drops or splits them.

    Compares the SET of placeholder names rather than the ordered list:
    legitimate translations often reorder placeholders (e.g. Bengali, Japanese
    and Korean swap subject/object positions relative to English), and that
    reordering must not trigger a "restore missing tokens" pass.
    """
    source_names = set(PLACEHOLDER_RE.findall(source))
    translated_names = set(PLACEHOLDER_RE.findall(translated))
    if source_names == translated_names:
        return translated

    restored = translated
    for name in source_names:
        token = "{" + name + "}"
        if token not in restored:
            restored += f" {token}"
    return restored


def _placeholder_names(s: str) -> set[str]:
    # Set, not list — a translation may reorder ``{count}`` and ``{ruleCount}``
    # and still be correct. Order-based comparisons false-positive on legitimate
    # word-order differences across languages.
    return set(PLACEHOLDER_RE.findall(s))


def _leading_garbled_before_first_placeholder(source: str, out: str) -> bool:
    """True when *source* starts with a placeholder but *out* has visible text first.

    Catches MT that turns ``{direct} direct, …`` into ``0 direct, 1 transitive {direct} …``.
    """
    if "{" not in source or "{" not in out:
        return False
    lead_src = source[: source.index("{")]
    if lead_src.strip():
        return False
    lead_out = out[: out.index("{")]
    return bool(lead_out.strip())


class DictionaryTranslator:
    def __init__(self, locale: str) -> None:
        self.locale = locale
        self._table: Dict[str, str] = TRANSLATIONS.get(locale, {})

    def translate_text(self, text: str) -> str:
        if not text:
            return text
        translated = self._table.get(text, text)
        return restore_placeholders(source=text, translated=translated)


class HybridTranslator:
    """Curated dictionary first, then optional machine translation + cache."""

    def __init__(self, locale: str, mt_cache: dict[str, str]) -> None:
        self.locale = locale
        self._table: Dict[str, str] = TRANSLATIONS.get(locale, {})
        self._mt_cache = mt_cache

    def translate_text(self, text: str) -> str:
        if not text:
            return text
        # Track provenance: curated dictionary entries are trusted human work
        # and must not be second-guessed by the MT-garbage guards below.
        # Many real translations legitimately put a word before the first
        # placeholder (Arabic "منذ {day} يوم", Ukrainian "{day} дн. тому",
        # Turkish "{day} g önce") — applying the leading-garbled guard to
        # those drops correct human translations back to English.
        from_dictionary = text in self._table
        if from_dictionary:
            translated = self._table[text]
        else:
            translated = machine_translate(text, self.locale, cache=self._mt_cache)
        out = restore_placeholders(source=text, translated=translated)
        # Placeholder-rename guard always applies — a curated entry with
        # mismatched {tokens} is a typo the user wants surfaced, not silently shipped.
        if _placeholder_names(text) != _placeholder_names(out):
            return text
        # Leading-garbled guard is MT-only. The pattern it catches
        # ("{direct} direct, …" → "0 direct, 1 transitive {direct} …") is
        # a Google Translate placeholder-shielding failure that cannot occur
        # in human-curated dictionary entries.
        if not from_dictionary and _leading_garbled_before_first_placeholder(text, out):
            return text
        return out
