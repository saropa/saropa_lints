#!/usr/bin/env python3
"""Show per-locale translation coverage (terminal table + README block).

Reads ``extension/src/i18n/locale_coverage.json`` (written by generate_locales.py
from the same LocaleStats the audit/translate run measures), so the numbers here
cannot drift from the language-picker badges.

  python coverage_report.py            -> print the table (safe to run mid-translation)
  python coverage_report.py --readme   -> also rewrite the marked block in README.md

generate_locales.py calls update_readme() at the end of every coverage write, so the
README stays current without a manual step. Stdlib only; no MT engine, no network.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
EXT = HERE.parent.parent
REPO = EXT.parent
COVERAGE_PATH = EXT / "src" / "i18n" / "locale_coverage.json"
README_PATH = REPO / "README.md"

# Markers delimit the generated block; everything between them is overwritten.
START = "<!-- i18n-coverage:start -->"
END = "<!-- i18n-coverage:end -->"
BAR_WIDTH = 10


def bar(pct: int) -> str:
    """Fixed-width text bar. Text (not an image) so it renders on GitHub, the
    Marketplace, and the terminal alike."""
    filled = max(0, min(BAR_WIDTH, round(BAR_WIDTH * pct / 100)))
    return "█" * filled + "░" * (BAR_WIDTH - filled)


def load(path: Path = COVERAGE_PATH) -> dict:
    """Coverage JSON, or a clear error: an empty/missing file must not render as a
    table of zero locales that reads like 'nothing to translate'."""
    if not path.is_file():
        raise FileNotFoundError(f"{path} not found; run generate_locales.py first")
    data = json.loads(path.read_text(encoding="utf-8"))
    if not data.get("locales"):
        raise ValueError(f"{path} has no locales")
    return data


def overall_pct(locales: dict[str, dict]) -> int:
    """Mean coveragePct over translation targets (English is the source, excluded)."""
    vals = [v["coveragePct"] for k, v in locales.items() if k != "en"]
    return round(sum(vals) / len(vals)) if vals else 100


def render_markdown(data: dict) -> str:
    """README block: overall line + one row per locale, lowest coverage first."""
    locales = data["locales"]
    rows = sorted(
        ((k, v) for k, v in locales.items() if k != "en"),
        key=lambda kv: (kv[1]["coveragePct"], kv[0]),
    )
    date = str(data.get("generated", ""))[:10]
    lines = [
        f"**Overall: {overall_pct(locales)}% translated** across {len(rows)} languages "
        f"(English is the source). Updated {date}.",
        "",
        "| Locale | Coverage | Untranslated |",
        "|--------|----------|-------------:|",
    ]
    for code, v in rows:
        lines.append(f"| `{code}` | {bar(v['coveragePct'])} {v['coveragePct']}% | {v['missing']} |")
    return "\n".join(lines)


def render_text(data: dict) -> str:
    """Terminal table, lowest coverage first."""
    locales = data["locales"]
    out = [f"{'locale':8}{'coverage':>10}  {'':{BAR_WIDTH}}  missing"]
    for code, v in sorted(((k, v) for k, v in locales.items() if k != "en"),
                          key=lambda kv: (kv[1]["coveragePct"], kv[0])):
        out.append(f"{code:8}{v['coveragePct']:>9}%  {bar(v['coveragePct'])}  {v['missing']}")
    out.append(f"OVERALL {overall_pct(locales)}%  (generated {data.get('generated', '?')})")
    return "\n".join(out)


def update_readme(data: dict, readme: Path = README_PATH) -> bool:
    """Replace the marked block in *readme*. Returns False (and changes nothing)
    when the markers are absent, so a README without the block is never mangled."""
    if not readme.is_file():
        return False
    text = readme.read_text(encoding="utf-8")
    pattern = re.compile(re.escape(START) + r".*?" + re.escape(END), re.DOTALL)
    if not pattern.search(text):
        return False
    block = f"{START}\n{render_markdown(data)}\n{END}"
    new = pattern.sub(lambda _m: block, text)
    if new != text:
        readme.write_text(new, encoding="utf-8", newline="")
    return True


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--readme", action="store_true", help="rewrite the README block")
    args = ap.parse_args(argv)
    data = load()
    print(render_text(data))
    if args.readme:
        print("README block updated" if update_readme(data) else
              f"README markers {START} / {END} not found; nothing changed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
