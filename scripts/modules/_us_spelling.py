"""US English spelling checker for project source files.

Scans Dart, Python, YAML, and Markdown files for common British
English spellings and reports the US English alternative. Designed
to run as a standalone check or be called from the publish pipeline.

Version:   1.0
Author:    Saropa
Copyright: (c) 2025-2026 Saropa
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from scripts.modules._utils import (
    Color,
    print_colored,
    print_error,
    print_subheader,
    print_success,
    print_warning,
)

# =============================================================================
# UK -> US SPELLING DICTIONARY
# =============================================================================
# Keys are lowercase British spellings; values are the US equivalent.
# Only includes words likely to appear in source code, comments,
# documentation, and user-facing lint messages.
#
# NOTE: This file is excluded from its own scan via _SKIP_FILES.

UK_TO_US: dict[str, str] = {
    # -our -> -or
    "behaviour": "behavior",
    "colour": "color",
    "favour": "favor",
    "favourite": "favorite",
    "honour": "honor",
    "humour": "humor",
    "labour": "labor",
    "neighbour": "neighbor",
    "savour": "savor",
    # -ise -> -ize
    "apologise": "apologize",
    "authorise": "authorize",
    "categorise": "categorize",
    "customise": "customize",
    "finalise": "finalize",
    "initialise": "initialize",
    "minimise": "minimize",
    "normalise": "normalize",
    "optimise": "optimize",
    "organise": "organize",
    "prioritise": "prioritize",
    "recognise": "recognize",
    "serialise": "serialize",
    "specialise": "specialize",
    "standardise": "standardize",
    "summarise": "summarize",
    "synchronise": "synchronize",
    "utilise": "utilize",
    # -re -> -er
    "centre": "center",
    "fibre": "fiber",
    "litre": "liter",
    "metre": "meter",
    "theatre": "theater",
    # -ence -> -ense
    "defence": "defense",
    "licence": "license",
    "offence": "offense",
    "pretence": "pretense",
    # -ogue -> -og
    "analogue": "analog",
    "catalogue": "catalog",
    # doubled consonants
    "cancelled": "canceled",
    "cancelling": "canceling",
    "counsellor": "counselor",
    "levelled": "leveled",
    "levelling": "leveling",
    "modelled": "modeled",
    "modelling": "modeling",
    "signalling": "signaling",
    "travelling": "traveling",
    # other common differences
    "ageing": "aging",
    "artefact": "artifact",
    "grey": "gray",
    "judgement": "judgment",
    "learnt": "learned",
    "manoeuvre": "maneuver",
    "mould": "mold",
    "programme": "program",
    "sceptical": "skeptical",
}

# Generate derived forms (-s, -ed, -ing) for -our/-ise base words
_derived: dict[str, str] = {}
for _uk, _us in list(UK_TO_US.items()):
    _derived[_uk + "s"] = _us + "s"
    if _uk.endswith("ise"):
        _derived[_uk[:-1] + "ed"] = _us[:-1] + "ed"
        _derived[_uk[:-1] + "ing"] = _us[:-1] + "ing"
        _derived[_uk + "r"] = _us + "r"
        _derived[_uk + "rs"] = _us + "rs"
    if _uk.endswith("our"):
        _derived[_uk + "ed"] = _us + "ed"
        _derived[_uk + "ing"] = _us + "ing"
        _derived[_uk + "able"] = _us + "able"

for _k, _v in _derived.items():
    UK_TO_US.setdefault(_k, _v)

# Clean up module-level temp variables
del _derived, _uk, _us, _k, _v

# Build a single regex that matches any UK spelling as a whole word.
# Sorted longest-first so "behaviours" matches before "behaviour".
_SORTED_UK = sorted(UK_TO_US.keys(), key=len, reverse=True)
_UK_PATTERN = re.compile(
    r"\b(" + "|".join(re.escape(w) for w in _SORTED_UK) + r")\b",
    re.IGNORECASE,
)

# File extensions to scan
_SCAN_EXTENSIONS = {".dart", ".py", ".md", ".yaml", ".yml"}

# Directories to skip entirely
_SKIP_DIRS = {
    ".dart_tool",
    ".git",
    "build",
    "node_modules",
    ".flutter-plugins",
    "bugs",
    "reports",
}

# Specific filenames to skip (e.g. this file's own dictionary)
_SKIP_FILES = {"_us_spelling.py"}

# URL pattern to detect links (skip matches inside URLs)
_URL_PATTERN = re.compile(r"https?://\S+", re.IGNORECASE)

# Substrings indicating a Flutter/Dart API context (skip these)
_API_CONTEXTS = {"colors.grey", "grey.shade", "grey["}

# Pattern for "grey" quoted as a string literal — Flutter API reference
_QUOTED_GREY = re.compile(r"""['"]grey['"]""", re.IGNORECASE)

# Context window for API name lookbehind/lookahead (chars)
_API_CONTEXT_WINDOW = 20
_MAX_CONTEXT_DISPLAY = 80


# =============================================================================
# DATA CLASSES
# =============================================================================


@dataclass
class SpellingHit:
    """A single British spelling found in a file."""

    file: Path
    line_number: int
    line_text: str
    uk_word: str
    us_word: str


# =============================================================================
# SCANNER
# =============================================================================


def _should_skip_dir(path: Path) -> bool:
    """Check if any path component is in the skip list."""
    return any(part in _SKIP_DIRS for part in path.parts)


def _is_inside_url(line: str, match_start: int, match_end: int) -> bool:
    """Check if the match falls within a URL."""
    for url_match in _URL_PATTERN.finditer(line):
        if url_match.start() <= match_start and match_end <= url_match.end():
            return True
    return False


def _is_grey_api_context(line: str, match_start: int) -> bool:
    """Check if a 'grey' match references a Flutter API name.

    Detects Colors.grey, grey.shade, grey[N], quoted 'grey' string
    literals (API name lookups in rule files), and mock definitions.
    """
    start = max(0, match_start - _API_CONTEXT_WINDOW)
    context = line[start:match_start + _API_CONTEXT_WINDOW].lower()
    if any(api in context for api in _API_CONTEXTS):
        return True
    # Check if the specific match is inside quotes (API name reference)
    before = line[max(0, match_start - 1):match_start]
    after = line[match_start + 4:match_start + 5] if match_start + 4 < len(line) else ""
    if before in ("'", '"') and after in ("'", '"'):
        return True
    # Skip Dart identifier definitions (e.g. `static const dynamic grey`)
    if re.search(r"\bgrey\b\s*=", line, re.IGNORECASE):
        return True
    return False


def _preserve_case(uk_found: str, us_base: str) -> str:
    """Apply the casing of the UK word to the US replacement."""
    if uk_found.isupper():
        return us_base.upper()
    if uk_found[0].isupper():
        return us_base[0].upper() + us_base[1:]
    return us_base


def scan_file(file_path: Path) -> list[SpellingHit]:
    """Scan a single file for British spellings."""
    hits: list[SpellingHit] = []
    try:
        content = file_path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return hits

    for line_num, line in enumerate(content.splitlines(), start=1):
        if "cspell" in line.lower():
            continue
        for match in _UK_PATTERN.finditer(line):
            uk_found = match.group(1)
            uk_lower = uk_found.lower()

            if _is_inside_url(line, match.start(), match.end()):
                continue

            if uk_lower == "grey" and _is_grey_api_context(
                line, match.start()
            ):
                continue

            us_word = UK_TO_US.get(uk_lower, "")
            if not us_word:
                continue

            hits.append(
                SpellingHit(
                    file=file_path,
                    line_number=line_num,
                    line_text=line.strip(),
                    uk_word=uk_found,
                    us_word=_preserve_case(uk_found, us_word),
                )
            )
    return hits


def scan_directory(project_dir: Path) -> list[SpellingHit]:
    """Scan all source files in a project for British spellings."""
    all_hits: list[SpellingHit] = []
    for file_path in project_dir.rglob("*"):
        if file_path.suffix not in _SCAN_EXTENSIONS:
            continue
        if _should_skip_dir(file_path):
            continue
        if file_path.name in _SKIP_FILES:
            continue
        all_hits.extend(scan_file(file_path))
    all_hits.sort(key=lambda h: (str(h.file), h.line_number))
    return all_hits


# =============================================================================
# REPORTING
# =============================================================================


def print_spelling_report(
    hits: list[SpellingHit],
    project_dir: Path | None = None,
) -> None:
    """Print a report of British spellings found."""
    print_subheader("US English Spelling Check")

    if not hits:
        print_success("No British English spellings found.")
        return

    print_warning(f"{len(hits)} British spelling(s) found:")
    print()

    by_file: dict[Path, list[SpellingHit]] = {}
    for hit in hits:
        by_file.setdefault(hit.file, []).append(hit)

    for file_path, file_hits in by_file.items():
        rel = (
            file_path.relative_to(project_dir)
            if project_dir
            else file_path
        )
        print_colored(f"  {rel}", Color.CYAN)
        for hit in file_hits:
            print(
                f"    L{hit.line_number}: "
                f"{Color.RED.value}{hit.uk_word}{Color.RESET.value}"
                f" -> "
                f"{Color.GREEN.value}{hit.us_word}{Color.RESET.value}"
            )
            context = hit.line_text
            if len(context) > _MAX_CONTEXT_DISPLAY:
                context = context[:_MAX_CONTEXT_DISPLAY - 3] + "..."
            print(
                f"      {Color.DIM.value}{context}{Color.RESET.value}"
            )
        print()

    # Summary by word
    word_counts: dict[str, int] = {}
    for hit in hits:
        key = f"{hit.uk_word.lower()} -> {hit.us_word.lower()}"
        word_counts[key] = word_counts.get(key, 0) + 1

    if len(word_counts) > 1:
        print_colored("  Summary:", Color.BOLD)
        for word, count in sorted(
            word_counts.items(), key=lambda x: -x[1]
        ):
            print(f"    {word}: {count} occurrence(s)")


def check_us_spelling(
    project_dir: Path | None = None,
) -> list[SpellingHit]:
    """Run the full US spelling check and print results.

    Returns the list of hits for programmatic use.
    """
    if project_dir is None:
        from scripts.modules._utils import get_project_dir
        project_dir = get_project_dir()

    hits = scan_directory(project_dir)
    print_spelling_report(hits, project_dir)
    return hits
