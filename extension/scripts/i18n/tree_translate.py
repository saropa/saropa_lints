"""Recursive translation utilities for nested JSON structures."""

from __future__ import annotations

from typing import Any, Protocol


class _TranslateFn(Protocol):
    def translate_text(self, text: str) -> str: ...


def translate_tree(node: Any, translator: _TranslateFn) -> Any:
    if isinstance(node, dict):
        return {key: translate_tree(value, translator) for key, value in node.items()}
    if isinstance(node, list):
        return [translate_tree(item, translator) for item in node]
    if isinstance(node, str):
        return translator.translate_text(node)
    return node


def collect_unique_strings(node: Any, out: set[str]) -> None:
    """Gather every string leaf (for deduped machine translation)."""
    if isinstance(node, dict):
        for value in node.values():
            collect_unique_strings(value, out)
    elif isinstance(node, list):
        for item in node:
            collect_unique_strings(item, out)
    elif isinstance(node, str):
        out.add(node)


def apply_string_map(node: Any, mapping: dict[str, str]) -> Any:
    """Replace string leaves using *mapping* (English → target)."""
    if isinstance(node, dict):
        return {key: apply_string_map(value, mapping) for key, value in node.items()}
    if isinstance(node, list):
        return [apply_string_map(item, mapping) for item in node]
    if isinstance(node, str):
        return mapping.get(node, node)
    return node

