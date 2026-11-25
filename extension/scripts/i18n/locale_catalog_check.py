"""Catalog-level checks the dictionary/cache-based audit cannot see.

Root cause these fix: ``generate_locales.py --mode audit`` builds its per-locale
mapping from dictionaries.py + the MT cache and never opens the shipped locale
JSON files. A key absent from a locale catalog was therefore invisible whenever
the dictionary or cache already held a translation for its English text (as with
``pubGuard.explain.unknown`` = "unknown"). These helpers inspect the catalogs
themselves.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from check_locale_garbage import flatten


def find_missing_keys(en_tree: Any, locale_tree: Any) -> list[str]:
    """Dotted keys present in English but absent from the locale catalog.

    A key also counts as missing when the locale value is not a string or is
    empty while English is non-empty - the runtime falls back to English for
    all of those, exactly as for an absent key. Presence is judged by key,
    never by value, so short or English-identical values cannot hide a gap.
    """
    en_flat = flatten(en_tree)
    loc_flat = flatten(locale_tree)
    missing: list[str] = []
    for key, en_val in en_flat.items():
        if key not in loc_flat:
            missing.append(key)
            continue
        val = loc_flat[key]
        if isinstance(en_val, str) and en_val.strip():
            if not isinstance(val, str) or not val.strip():
                missing.append(key)
    return sorted(missing)


def find_stale_dictionary_entries(
    translations: dict[str, dict[str, str]], english_strings: Iterable[str]
) -> list[tuple[str, str]]:
    """(locale, english) pairs whose English source text no longer exists.

    A reworded English string leaves its curated entry unmatched, so the string
    silently falls back to MT. Passthrough entries (X -> X) are skipped: they
    are harmless when the source disappears.
    """
    live = set(english_strings)
    stale: list[tuple[str, str]] = []
    for locale, entries in translations.items():
        for en_key, tr in entries.items():
            if en_key != tr and en_key not in live:
                stale.append((locale, en_key))
    return sorted(stale)


def find_unbacked_values(
    en_tree: Any, locale_tree: Any, dict_table: dict[str, str]
) -> list[str]:
    """Keys whose locale value differs from English but has no dictionary entry.

    Such hand-written text lives only in the JSON; a regeneration can overwrite
    it with MT output. Warning-level only.
    """
    en_flat = flatten(en_tree)
    loc_flat = flatten(locale_tree)
    out: list[str] = []
    for key, en_val in en_flat.items():
        val = loc_flat.get(key)
        if not isinstance(en_val, str) or not isinstance(val, str):
            continue
        if val != en_val and en_val not in dict_table:
            out.append(key)
    return sorted(out)


def catalog_paths(ext: Path, locale: str) -> list[tuple[Path, Path]]:
    """(english, locale) catalog path pairs for both file families."""
    loc_dir = ext / "src" / "i18n" / "locales"
    return [
        (loc_dir / "en.json", loc_dir / f"{locale}.json"),
        (ext / "package.nls.json", ext / f"package.nls.{locale}.json"),
    ]


def find_extra_keys(en_tree: Any, locale_tree: Any) -> list[str]:
    """Dotted keys present in the locale catalog but not in English.

    Orphans of renamed/removed English keys: harmless at runtime but dead
    weight that hides drift, so they are reported as warnings only.
    """
    en_flat = flatten(en_tree)
    return sorted(k for k in flatten(locale_tree) if k not in en_flat)
