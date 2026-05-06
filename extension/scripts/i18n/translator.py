"""Translation engine with placeholder-safe fallback behavior."""

from __future__ import annotations

import re
from typing import Dict

from dictionaries import TRANSLATIONS


PLACEHOLDER_RE = re.compile(r"\{[A-Za-z0-9_]+\}")


class DictionaryTranslator:
    def __init__(self, locale: str) -> None:
        self.locale = locale
        self._table: Dict[str, str] = TRANSLATIONS.get(locale, {})

    def translate_text(self, text: str) -> str:
        if not text:
            return text
        translated = self._table.get(text, text)
        return self._restore_placeholders(source=text, translated=translated)

    @staticmethod
    def _restore_placeholders(source: str, translated: str) -> str:
        source_placeholders = PLACEHOLDER_RE.findall(source)
        translated_placeholders = PLACEHOLDER_RE.findall(translated)
        if source_placeholders == translated_placeholders:
            return translated

        restored = translated
        for token in source_placeholders:
            if token not in restored:
                restored += f" {token}"
        return restored

