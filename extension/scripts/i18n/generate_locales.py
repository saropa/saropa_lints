#!/usr/bin/env python3
"""Generate extension locale files from English JSON sources.

Usage:
    py -3 extension/scripts/i18n/generate_locales.py              # English placeholders only
    py -3 extension/scripts/i18n/generate_locales.py --translate   # machine-translate via Google
    py -3 extension/scripts/i18n/generate_locales.py --translate --locales bn,de
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Force UTF-8 stdout/stderr so non-Latin translated text (Bengali, Arabic,
# Chinese, etc.) prints correctly on Windows consoles that default to cp1252.
if sys.stdout.encoding != "utf-8":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
if sys.stderr.encoding != "utf-8":
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]

from dictionaries import TRANSLATIONS
from json_io import read_json, write_json
from mt_fallback import load_mt_cache, prefetch_machine_translations, save_mt_cache
from tree_translate import apply_string_map, collect_unique_strings
from translator import HybridTranslator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate extension locale JSON files.")
    parser.add_argument(
        "--locales",
        default=(
            "ar,bn,de,es,fa,fil,fr,he,hi,id,it,ja,ko,nl,pl,pt,ru,sw,th,tr,uk,ur,vi,zh"
        ),
        help=(
            "Comma-separated locale codes (default: full shipped set per "
            "plans/EXTENSION_LOCALIZATION_GUIDE.md primary and secondary tiers)."
        ),
    )
    return parser.parse_args()


def split_locales(raw: str) -> list[str]:
    return [part.strip() for part in raw.split(",") if part.strip()]


def main() -> int:
    args = parse_args()

    locales = split_locales(args.locales)
    if not locales:
        print("No locales provided.")
        return 1

    root = Path(__file__).resolve().parents[2]
    package_en_path = root / "package.nls.json"
    runtime_en_path = root / "src" / "i18n" / "locales" / "en.json"

    package_en = read_json(package_en_path)
    runtime_en = read_json(runtime_en_path)

    mt_cache = load_mt_cache()
    unique_en: set[str] = set()
    collect_unique_strings(package_en, unique_en)
    collect_unique_strings(runtime_en, unique_en)

    sorted_unique = sorted(unique_en)
    for locale in locales:
        print(f"[i18n] {locale}: prefetch…", flush=True)
        prefetch_machine_translations(
            locale,
            sorted_unique,
            cache=mt_cache,
            dict_table=TRANSLATIONS.get(locale, {}),
        )
        translator = HybridTranslator(locale, mt_cache)
        # One ``translate_text`` per distinct English string (MT + cache), not per JSON leaf.
        mapping = {s: translator.translate_text(s) for s in sorted_unique}
        package_out = apply_string_map(package_en, mapping)
        runtime_out = apply_string_map(runtime_en, mapping)

        package_out_path = root / f"package.nls.{locale}.json"
        runtime_out_path = root / "src" / "i18n" / "locales" / f"{locale}.json"

        write_json(package_out_path, package_out)
        write_json(runtime_out_path, runtime_out)
        print(f"[i18n] {locale}: wrote {package_out_path.name}, {runtime_out_path.name}", flush=True)

    save_mt_cache(mt_cache)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

