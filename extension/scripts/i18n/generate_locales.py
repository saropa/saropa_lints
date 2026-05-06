#!/usr/bin/env python3
"""Generate extension locale files from English JSON sources."""

from __future__ import annotations

import argparse
from pathlib import Path

from json_io import read_json, write_json
from tree_translate import translate_tree
from translator import DictionaryTranslator


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate extension locale JSON files.")
    parser.add_argument(
        "--locales",
        default="nl,ur,fr,de,es,it,pt,ru,ja,ko,zh,ar,hi",
        help=(
            "Comma-separated locale codes "
            "(default: nl,ur,fr,de,es,it,pt,ru,ja,ko,zh,ar,hi)."
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

    for locale in locales:
        translator = DictionaryTranslator(locale)
        package_out = translate_tree(package_en, translator)
        runtime_out = translate_tree(runtime_en, translator)

        package_out_path = root / f"package.nls.{locale}.json"
        runtime_out_path = root / "src" / "i18n" / "locales" / f"{locale}.json"

        write_json(package_out_path, package_out)
        write_json(runtime_out_path, runtime_out)
        print(f"Generated {locale}: {package_out_path.name}, {runtime_out_path.name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

