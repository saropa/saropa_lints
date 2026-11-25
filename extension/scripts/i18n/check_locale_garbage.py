#!/usr/bin/env python3
"""Detect garbage in shipped locale catalogs (leaked prompts, loops, wrong script).

Why this exists: machine translation can emit artifacts that are not a
translation at all - an LLM echoing its own instructions ("Aturan Ketat..."),
a decoder stuck in a loop, or text in the wrong script. The coverage audit
compares dictionary/cache output to English and never inspects the catalogs'
actual text, so these artifacts passed every gate.

Scans src/i18n/locales/<lang>.json (nested) and package.nls.<lang>.json (flat).
Stdlib only, no network. Exit 1 when any finding exists.

Usage:
  python check_locale_garbage.py [--root <extension dir>] [--locales id,he]
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
EXT = HERE.parent.parent

# Single source of truth for leaked MT/LLM prompt fragments. Matched
# case-insensitively, and ONLY in prompt-header position (see _MARKER_RE): at the
# start of the value or at the start of a line, optionally behind a list prefix
# ("1. ", "- "). Each entry is text an instruction-following model echoes back
# from its translation prompt (English or already localized by the model). Add a
# new entry here when a new leak shape is found - nowhere else.
LEAKED_PROMPT_MARKERS: tuple[str, ...] = (
    "strict rule",
    "return only",
    "translate the following",
    "regra estrita",
    "aturan ketat",
    "kembalikan hanya",
    "reglas estrictas",
    "strenge regel",
)

# Header-position matcher: a legitimate translation may contain a phrase like
# "strict rule" mid-sentence; a leaked prompt puts it where the prompt did, at a
# line start. The optional prefix covers numbered/bulleted prompt rules.
_MARKER_RE = re.compile(
    r"(?:^|\n)[ \t]*(?:\d+[.)]\s*|[-*•]\s*)?(?:"
    + "|".join(re.escape(m) for m in LEAKED_PROMPT_MARKERS)
    + ")",
    re.IGNORECASE,
)

# A 1-3 char unit repeated this many times back to back is a decoder loop.
# 8 keeps "1000000" (6 zeros) and normal doubled letters well clear.
MIN_LOOP_REPEATS = 8
_LOOP_RE = re.compile(r"(.{1,3}?)\1{%d,}" % (MIN_LOOP_REPEATS - 1), re.DOTALL)

# Units that may legitimately repeat: spaces, ellipsis/dashes, bullets, box and
# block drawing characters used as rulers/progress bars, "?"/"!" emphasis, and
# "0" (large numbers). A match whose unit consists only of these is ignored.
_BENIGN_LOOP_CHARS = set(
    " .…-_=*#~|/\\0?!"
    "—–•·●"                      # em/en dash, bullet, middle dot, black circle
    "█▓░"                                  # block elements
    "│┃┌┐└┘├┤"    # box drawing
    "─━═"
)

# Script ranges (inclusive code points).
_HAN = ((0x4E00, 0x9FFF), (0x3400, 0x4DBF))                  # incl. CJK Ext-A
_KANA = ((0x3040, 0x30FF),)
_HANGUL = ((0xAC00, 0xD7AF), (0x1100, 0x11FF), (0x3130, 0x318F))  # syllables, Jamo, Compat Jamo
_FULLWIDTH = ((0xFF00, 0xFFEF),)
_CYRILLIC = ((0x0400, 0x052F),)
_HEBREW = ((0x0590, 0x05FF),)
_ARABIC = ((0x0600, 0x06FF), (0x0750, 0x077F), (0xFB50, 0xFDFF), (0xFE70, 0xFEFF))

# Locales allowed to contain each script; everything else is flagged. ja/zh may
# use fullwidth forms (their normal punctuation lives there); ko may not.
_CYRILLIC_LOCALES = {"ru", "uk"}
_HEBREW_FORBIDDEN_IN = {"ar", "fa", "ur"}   # cross-leak from he
_ARABIC_FORBIDDEN_IN = {"he"}               # cross-leak from ar/fa/ur

# ko legitimately keeps the odd single Han character; only a run of this length
# or more that the English source lacks is a leak.
_KO_MIN_HAN_RUN = 2
_HAN_RUN_RE = re.compile("[一-鿿㐀-䶿]{%d,}" % _KO_MIN_HAN_RUN)

# CJK locales: an untranslated Latin sentence is suspect, but technical tokens
# are legitimately Latin. Words in this set (lowercase) are ignored when
# counting Latin words in a ja/zh/ko value.
PROTECTED_TOKENS: frozenset[str] = frozenset({
    "path", "pubspec", "lock", "yaml", "dart", "flutter", "sdk", "saropa",
    "lints", "owasp", "json", "csv", "html", "api", "url", "cli", "npm",
    "pub", "git", "vibrancy", "tier", "cyclonedx", "sbom", "ide", "vs",
    "code", "analyzer", "mcp", "ci", "http", "https",
})
_CJK_LATIN_LOCALES = {"ja", "zh", "ko"}
# A value is an untranslated sentence only when it has at least this many
# unprotected Latin words, those words make up at least this share of the
# value's length, there is no CJK character, AND it reads like prose.
MIN_LATIN_WORDS = 4
MIN_LATIN_SHARE = 0.6
# Prose test: a list of product names ("Isar Hive Firebase Riverpod") has no
# English function word and no sentence punctuation; a sentence has at least one.
_FUNCTION_WORDS = frozenset({
    "the", "and", "to", "of", "in", "is", "for", "with", "or", "this", "that",
    "on", "are", "be", "it", "as", "at", "by", "from", "not", "will", "can",
    "your", "you", "has", "have", "was", "an",
})
_SENTENCE_END_RE = re.compile(r"[.!?:;]\s*$")

# Removed before counting Latin words, each as ONE protected token: code spans,
# placeholders, URLs, file names, and snake_case / dotted / camelCase
# identifiers (rule names such as avoid_print_in_release).
_STRIP_RE = re.compile(
    r"`[^`]*`|\{[A-Za-z_][\w.]*\}|(?:https?|command|file)://\S+"
    r"|\S+\.(?:json|yaml|lock|dart|ts)\b"
    r"|\b[A-Za-z0-9]+(?:_[A-Za-z0-9]+)+\b"
    r"|\b[a-z]+(?:[A-Z][a-z0-9]+)+\b"
)
_WORD_RE = re.compile(r"[A-Za-z]{3,}")


def _in_ranges(ch: str, ranges: tuple[tuple[int, int], ...]) -> bool:
    """True when *ch* falls in any inclusive code-point range."""
    cp = ord(ch)
    return any(lo <= cp <= hi for lo, hi in ranges)


def flatten(node: Any, prefix: str = "") -> dict[str, Any]:
    """Flatten nested dicts AND lists to dotted keys (lists use index keys).

    Lists are expanded item by item so their strings are scanned too; before,
    a list was one non-string value and its contents escaped every check.
    """
    out: dict[str, Any] = {}
    if isinstance(node, dict):
        for k, v in node.items():
            out.update(flatten(v, f"{prefix}{k}."))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            out.update(flatten(v, f"{prefix}{i}."))
    else:
        out[prefix[:-1]] = node
    return out


def _forbidden_scripts(locale: str) -> list[tuple[str, tuple[tuple[int, int], ...]]]:
    """(name, ranges) of scripts that must not appear in *locale*'s text."""
    forbidden: list[tuple[str, tuple[tuple[int, int], ...]]] = []
    if locale not in {"ja", "zh"}:
        # Fullwidth forms only belong to ja/zh punctuation conventions.
        forbidden.append(("fullwidth", _FULLWIDTH))
    if locale not in {"ja", "zh", "ko"}:
        # Han is legitimate in ja/zh; ko gets the run-based rule instead.
        forbidden.append(("Han", _HAN))
    if locale != "ja":
        forbidden.append(("kana", _KANA))
    if locale != "ko":
        forbidden.append(("Hangul", _HANGUL))
    if locale not in _CYRILLIC_LOCALES:
        forbidden.append(("Cyrillic", _CYRILLIC))
    if locale in _HEBREW_FORBIDDEN_IN:
        forbidden.append(("Hebrew", _HEBREW))
    if locale in _ARABIC_FORBIDDEN_IN:
        forbidden.append(("Arabic", _ARABIC))
    return forbidden


def _script_reasons(locale: str, value: str, english: str) -> list[str]:
    """Reasons for characters in a script *locale* must not contain."""
    reasons: list[str] = []
    seen: set[str] = set()
    for name, ranges in _forbidden_scripts(locale):
        # Characters already in the English source are the source's own content.
        stray = [ch for ch in value if _in_ranges(ch, ranges) and ch not in english]
        if stray and name not in seen:
            seen.add(name)
            reasons.append(f"script mismatch for {locale}: {name} {''.join(sorted(set(stray)))[:10]!r}")
    if locale == "ko":
        # Single Han characters are tolerated in ko; a run is a leak.
        runs = [r for r in _HAN_RUN_RE.findall(value) if r not in english]
        if runs:
            reasons.append(f"script mismatch for ko: Han run {runs[0][:10]!r}")
    return reasons


def _looks_like_untranslated_sentence(value: str) -> bool:
    """True for a ja/zh/ko value that is a Latin prose sentence with no CJK."""
    text = _STRIP_RE.sub(" ", value)
    if any(_in_ranges(ch, _HAN + _KANA + _HANGUL) for ch in text):
        return False
    words = [w for w in _WORD_RE.findall(text) if w.lower() not in PROTECTED_TOKENS]
    if len(words) < MIN_LATIN_WORDS:
        return False
    # The Latin words must dominate the value, not sit inside mostly-other text.
    if sum(len(w) for w in words) < MIN_LATIN_SHARE * max(1, len(value)):
        return False
    # Prose, not a list of names: needs a function word or terminal punctuation.
    has_function_word = any(w.lower() in _FUNCTION_WORDS for w in words)
    return has_function_word or bool(_SENTENCE_END_RE.search(value.strip()))


def check_value(locale: str, value: str, english: str = "") -> list[str]:
    """Return reasons *value* is garbage for *locale* (empty list = clean).

    *english* is the source text; anything already present in it (a loop-like
    run, CJK text) is the source's own content and never a finding.
    """
    reasons: list[str] = []
    for m in _MARKER_RE.finditer(value):
        phrase = m.group(0).strip().lstrip("0123456789.)-*• \t").lower()
        # Skip when the English source itself opens a line with the phrase.
        if not _MARKER_RE.search(english):
            reasons.append(f"leaked prompt text {phrase!r}")
        break  # one leak reason per value is enough
    for m in _LOOP_RE.finditer(value):
        unit = m.group(1)
        # Ellipses/dividers/long numbers and runs copied from the source are fine.
        if all(ch in _BENIGN_LOOP_CHARS for ch in unit) or m.group(0) in english:
            continue
        reasons.append(f"repeated unit {unit!r} x{len(m.group(0)) // len(unit)}")
        break
    reasons.extend(_script_reasons(locale, value, english))
    # Identical-to-English values are the missing-translation audit's concern;
    # here only a *changed* value that is still a Latin sentence is suspect.
    if locale in _CJK_LATIN_LOCALES and value != english and _looks_like_untranslated_sentence(value):
        reasons.append(f"untranslated Latin sentence in {locale}")
    return reasons


def scan_catalog(locale: str, locale_tree: Any, en_tree: Any) -> list[tuple[str, str, str]]:
    """Return (key, reason, value) for every garbage string in one catalog."""
    en_flat = flatten(en_tree)
    findings: list[tuple[str, str, str]] = []
    for key, value in flatten(locale_tree).items():
        if not isinstance(value, str):
            continue
        for reason in check_value(locale, value, str(en_flat.get(key, ""))):
            findings.append((key, reason, value))
    return findings


def _read(path: Path) -> Any:
    """Parse one JSON catalog."""
    return json.loads(path.read_text(encoding="utf-8"))


def scan_extension(ext: Path, locales: list[str] | None = None) -> list[tuple[str, str, str, str]]:
    """Scan runtime + manifest catalogs under *ext*; rows are (file, key, reason, value)."""
    loc_dir = ext / "src" / "i18n" / "locales"
    if locales is None:
        locales = sorted(p.stem for p in loc_dir.glob("*.json") if p.stem != "en")
    families = (
        (loc_dir / "en.json", lambda lc: loc_dir / f"{lc}.json"),
        (ext / "package.nls.json", lambda lc: ext / f"package.nls.{lc}.json"),
    )
    rows: list[tuple[str, str, str, str]] = []
    for en_path, path_for in families:
        en_tree = _read(en_path)
        for lc in locales:
            path = path_for(lc)
            if not path.exists():
                continue  # a missing file is the missing-key check's concern
            for key, reason, value in scan_catalog(lc, _read(path), en_tree):
                rows.append((path.name, key, reason, value))
    return rows


def main(argv: list[str] | None = None) -> int:
    """CLI entry: print findings, exit 1 if any."""
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=str(EXT), help="extension directory")
    ap.add_argument("--locales", default="", help="comma-separated subset (default: all)")
    args = ap.parse_args(argv)
    # Findings echo non-Latin text; a cp1252 console would crash on it, which
    # would hide the very findings this tool exists to report.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    locales = [x for x in args.locales.split(",") if x] or None
    rows = scan_extension(Path(args.root), locales)
    for fname, key, reason, value in rows:
        print(f"  {fname}: {key}: {reason}: {value[:80]!r}")
    print(f"locale garbage check: {len(rows)} finding(s)")
    return 1 if rows else 0


if __name__ == "__main__":
    sys.exit(main())
