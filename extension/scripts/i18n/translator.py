"""Translation engine with placeholder-safe fallback behavior."""

from __future__ import annotations

import re
from typing import Dict

from dictionaries import TRANSLATIONS
from mt_fallback import machine_translate


PLACEHOLDER_RE = re.compile(r"\{([A-Za-z0-9_]+)\}")


def restore_placeholders(source: str, translated: str) -> str:
    """Keep ``{tokens}`` aligned with *source* when the engine drops or splits them."""
    source_names = PLACEHOLDER_RE.findall(source)
    translated_names = PLACEHOLDER_RE.findall(translated)
    if source_names == translated_names:
        return translated

    restored = translated
    for name in source_names:
        token = "{" + name + "}"
        if token not in restored:
            restored += f" {token}"
    return restored


def _placeholder_names(s: str) -> list[str]:
    return PLACEHOLDER_RE.findall(s)


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
        if text in self._table:
            translated = self._table[text]
        else:
            translated = machine_translate(text, self.locale, cache=self._mt_cache)
        out = restore_placeholders(source=text, translated=translated)
        # If interpolation keys were renamed or dropped, ship English instead of a broken template.
        if _placeholder_names(text) != _placeholder_names(out):
            return text
        return out
