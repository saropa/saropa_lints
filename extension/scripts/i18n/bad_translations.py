#!/usr/bin/env python3
"""Detect (and optionally purge) machine translations that are mechanically wrong.

No network, no MT engine, stdlib only. Three entry points share one detector:

  * CLI report   python bad_translations.py            -> per-locale counts + candidates file
  * CLI gate     python bad_translations.py --check    -> exit 1 if any HARD flag ships
  * Auto-prune   prune_bad_cache_entries() is called by generate_locales.py on every
                 generation run, so a flagged cache entry becomes a gap that the normal
                 gap-fill re-translates -- no manual purge step.

HARD flags are unambiguous defects (safe to auto-delete). SOFT flags are heuristics
that need a human glance, so they are reported but never auto-purged.
Measured failure classes this targets (see project_i18n_mt_engine memory): NLLB bare
"ZZ" sentinel leaks, "⁇" for em-dash, hallucinated continuations on short labels,
Qwen word-sense errors on domain terms (via the blocklist).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))  # sibling imports work whether run as script or module

from verify_locales import (  # noqa: E402  (path tweak above must run first)
    BACKTICK, PH, URL, WORD, discover, flatten, placeholder_problems, suspicious,
)

EXT = HERE.parent.parent
BLOCKLIST_PATH = HERE / "bad_translations_blocklist.json"

# Leaked shield sentinel (any digit-dropped variant), the "⁇" an engine emits for
# characters it cannot render, the raw shield code points, and LLM chat-template
# tokens. A bare "ZZ" is only a leak when English did not contain it.
#  "_PH0_" / "PH1__" / Cyrillic "ПХ0" are placeholder-shield variants an engine
# echoed back as text (seen in tr/uk/sw/ko output).
_LEAK_RE = re.compile(r"ZZ|q\d+q|⁇|[﷐﷑]|<\||\|>|\[/?INST\]|/no_think|_?PH\d+_*|ПХ\d")

# Characters that prove a locale's output is in its own script. A string that is
# real English prose but has none of these was left untranslated or mangled.
_SCRIPT_RANGES = {
    "ar": "؀-ۿ", "fa": "؀-ۿ", "ur": "؀-ۿ", "he": "֐-׿",
    "hi": "ऀ-ॿ", "bn": "ঀ-৿", "th": "฀-๿",
    "ja": "぀-ヿ一-鿿", "zh": "一-鿿", "ko": "가-힣ᄀ-ᇿ",
    "ru": "Ѐ-ӿ", "uk": "Ѐ-ӿ",
}
_SCRIPT_RE = {loc: re.compile(f"[{rng}]") for loc, rng in _SCRIPT_RANGES.items()}

# Output more than this many times the English length (plus slack) is a model
# running on past the source (hallucinated continuation), not a translation.
_BLOWUP_FACTOR = 4
_BLOWUP_SLACK = 10
# Low floor on purpose: NLLB's measured failure was hallucinated continuations on
# SHORT labels ("Refresh" -> a full invented sentence), so short sources must count.
_MIN_EN_LEN_FOR_BLOWUP = 3


def _brand_terms() -> tuple[str, ...]:
    """Do-not-translate terms, imported lazily so the CLI works without mt_fallback."""
    try:
        from mt_fallback import _DO_NOT_TRANSLATE
        return tuple(_DO_NOT_TRANSLATE)
    except Exception:  # noqa: BLE001 -- detector must degrade, never crash a run
        return ("Saropa", "Dart", "Flutter", "VS Code", "GitHub")


def _strip_literals(s: str) -> str:
    """Remove placeholders, code spans, URLs and brand names so only prose remains."""
    s = BACKTICK.sub(" ", s)
    s = URL.sub(" ", s)
    s = PH.sub(" ", s)
    for term in _brand_terms():
        s = s.replace(term, " ")
    return s


def load_blocklist(path: Path = BLOCKLIST_PATH) -> list[dict]:
    """Known-wrong renderings: {locale, en_regex, bad_regex}. Missing file = empty."""
    if not path.is_file():
        return []
    return json.loads(path.read_text(encoding="utf-8")).get("entries", [])


def detect(en: str, loc: str, locale: str, blocklist: list[dict]) -> list[tuple[str, str]]:
    """Return [(severity, reason)] for one translation; severity is 'hard' or 'soft'."""
    out: list[tuple[str, str]] = []
    if not loc.strip():
        # Empty output for a non-empty source is never valid.
        return [("hard", "empty")] if en.strip() else []

    # Leaked sentinels / control tokens. A token is excused only if English itself
    # contains it (e.g. a source that legitimately says "PH2" or "ZZ").
    for m in _LEAK_RE.finditer(loc):
        # Strip the "_" wrapper the regex adds so "PH2" in English excuses "_PH2_".
        if m.group(0).strip("_") in en:
            continue
        out.append(("hard", f"leak:{m.group(0)}"))
        break

    # Placeholder / code span / link drift versus English.
    for msg in placeholder_problems(en, loc):
        out.append(("hard", f"placeholder:{msg}"))

    prose = _strip_literals(en)
    letters = WORD.findall(prose)
    # Wrong script: real English prose in, none of the locale's script out.
    rx = _SCRIPT_RE.get(locale)
    # Require >=2 words (WORD = 3+ letter runs): a lone acronym/token ("URL",
    # "JSON") is legitimately kept in Latin by a correct translation; flagging it
    # made prune delete it on every run so the pending count never settled.
    if rx and loc != en and len(letters) >= 2 and not rx.search(loc):
        out.append(("hard", "wrong-script"))

    # Hallucinated continuation: output vastly longer than the source.
    # Compare PROSE to PROSE: placeholders/brands are stripped from both sides, or a
    # placeholder-heavy source ("{pkg} {to} needs {dep} {range}") looks short in
    # English but long in the locale and false-flags a correct translation.
    n_en = len(prose.strip())
    n_loc = len(_strip_literals(loc).strip())
    if n_en >= _MIN_EN_LEN_FOR_BLOWUP and n_loc > _BLOWUP_FACTOR * n_en + _BLOWUP_SLACK:
        out.append(("hard", f"blowup:{n_loc}>{_BLOWUP_FACTOR}x{n_en}"))

    # Known-wrong renderings of domain terms (data-driven; add entries as found).
    for entry in blocklist:
        if entry.get("locale") not in (locale, "*"):
            continue
        if re.search(entry["en_regex"], en, re.I) and re.search(entry["bad_regex"], loc):
            out.append(("hard", f"blocklist:{entry['bad_regex']}"))

    # Short-label heuristics (verify_locales) are noisy -> soft, never auto-purged.
    sus = suspicious(en, loc)
    if sus:
        out.append(("soft", f"label:{sus[1]}"))
    return out


def prune_bad_cache_entries(
    cache: dict[str, str], locale: str, texts: list[str], dict_table: dict[str, str],
) -> int:
    """Auto-prune hook: drop cached translations with a HARD flag so the next
    gap-fill re-translates them. Checks every engine namespace, since the cache
    key depends on the engine that produced the entry. Returns number removed."""
    from mt_fallback import _cache_key, _provenance  # lazy: heavy module
    blocklist = load_blocklist()
    removed = 0
    for text in texts:
        if not text or text in dict_table:
            continue  # curated dictionary entries are never machine output
        for engine in ("qwen", "nllb", "google"):
            key = _cache_key(locale, text, engine)
            val = cache.get(key)
            if val is None:
                continue
            if _provenance.get(key) == "manual":
                continue  # manual overrides are authoritative, never auto-deleted
            if any(sev == "hard" for sev, _ in detect(text, val, locale, blocklist)):
                cache.pop(key, None)
                _provenance.pop(key, None)
                removed += 1
    return removed


def scan_shipped(ext: Path) -> dict[str, list[dict]]:
    """Scan shipped locale files (runtime + manifest) -> {locale: [finding]}."""
    blocklist = load_blocklist()
    fams, locales = discover(ext)
    found: dict[str, list[dict]] = {l: [] for l in locales}
    for fam, (src, pathfn) in fams.items():
        en = flatten(json.loads(src.read_text(encoding="utf-8")))
        for locale in locales:
            p = pathfn(locale)
            if not p.is_file():
                continue
            loc_map = flatten(json.loads(p.read_text(encoding="utf-8")))
            for key, ev in en.items():
                lv = loc_map.get(key)
                if not isinstance(lv, str) or not isinstance(ev, str):
                    continue
                for sev, reason in detect(ev, lv, locale, blocklist):
                    found[locale].append({"family": fam, "key": key, "severity": sev,
                                          "reason": reason, "en": ev, "value": lv})
    return found


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--check", action="store_true", help="exit 1 if any HARD flag ships")
    ap.add_argument("--purge", action="store_true",
                    help="delete HARD-flagged entries from the MT cache (next generate refills)")
    ap.add_argument("--out", default=r"D:\tmp\bad_translations.json", help="candidates JSON")
    ap.add_argument("--ext", default=str(EXT))
    args = ap.parse_args(argv)

    found = scan_shipped(Path(args.ext))
    hard = Counter()
    soft = Counter()
    for locale, items in found.items():
        for it in items:
            (hard if it["severity"] == "hard" else soft)[locale] += 1
    print(f"{'locale':8}{'hard':>6}{'soft':>6}")
    for locale in sorted(found):
        print(f"{locale:8}{hard[locale]:>6}{soft[locale]:>6}")
    total_hard = sum(hard.values())
    print(f"TOTAL hard={total_hard} soft={sum(soft.values())}")

    if args.out and not args.check:
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(found, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"candidates -> {out}")

    if args.purge:
        # Purge works on the cache (the generator's source of truth); the shipped
        # files are rewritten from it on the next generate run.
        import shutil
        from mt_fallback import (
            _CACHE_PATH, load_mt_cache, load_provenance, save_mt_cache, save_provenance,
        )
        # Cache is gitignored, so a deletion is otherwise unrecoverable. Keep a
        # timestamp-free single backup beside it; a wrong purge can be undone by
        # copying it back.
        if _CACHE_PATH.is_file():
            backup = _CACHE_PATH.with_suffix(".json.bak")
            shutil.copyfile(_CACHE_PATH, backup)
            print(f"cache backup -> {backup}")
        cache = load_mt_cache()
        load_provenance()
        removed = 0
        for locale, items in found.items():
            # Only English sources that carry a HARD flag are candidates; the prune
            # re-runs the detector on the CACHED value, so a clean cache entry stays.
            texts = sorted({it["en"] for it in items if it["severity"] == "hard"})
            removed += prune_bad_cache_entries(cache, locale, texts, {})
        save_mt_cache(cache)
        save_provenance()
        print(f"purged {removed} cache entr{'y' if removed == 1 else 'ies'}; "
              "run generate_translations.py to refill them")
    if args.check:
        return 1 if total_hard else 0
    return 0


if __name__ == "__main__":
    sys.exit(main())
