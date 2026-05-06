"""Recursive translation utilities for nested JSON structures."""

from __future__ import annotations

from typing import Any

from translator import DictionaryTranslator


def translate_tree(node: Any, translator: DictionaryTranslator) -> Any:
    if isinstance(node, dict):
        return {key: translate_tree(value, translator) for key, value in node.items()}
    if isinstance(node, list):
        return [translate_tree(item, translator) for item in node]
    if isinstance(node, str):
        return translator.translate_text(node)
    return node

