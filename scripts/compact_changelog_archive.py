#!/usr/bin/env python3
"""Mechanical concision pass for CHANGELOG_ARCHIVE.md.

Inside ### Added / ### Changed / ### Fixed / ### Removed (optional Extension
suffix), each top-level `-` bullet is:
- stripped of markdown links to repo source paths;
- stripped of `lib/...`, `test/...`, `extension/...` inline code paths;
- trimmed of trailing Flutter/Dart/PR parentheticals;
- soft-capped (~360 chars) at a prior sentence boundary with a short suffix.

Nested `  -` lines immediately under a **Pubspec validation** parent are
removed and the parent line notes that eleven rules exist (one sentence).
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCHIVE = ROOT / "CHANGELOG_ARCHIVE.md"

SECTION = re.compile(
    r"^### (Added|Changed|Fixed|Removed|Breaking)( \(Extension\))?\s*$"
)
VERSION_OR_DETAILS = re.compile(r"^## \[|^<details>")
LINK_INTERNAL = re.compile(
    r"\[([^\]]+)\]\((?:\./)?(?:lib/|test/|tool/|bin/|extension/|scripts/|example/)[^)]*\)"
)
LINK_GH_TREE = re.compile(
    r"\[([^\]]+)\]\(https://github\.com/saropa/saropa_lints/blob/[^)]+\)"
)
INLINE_PATH = re.compile(r"`(?:lib|test|tool|bin|extension|scripts|example)/[^`]+`")
TRAIL = re.compile(
    r"\s*\((?:Flutter [^)]+|Dart [^)]+|PR #\d+)\)\s*"
)


def tidy_bullet(body: str) -> str:
    s = body.strip()
    prev = None
    while prev != s:
        prev = s
        s = LINK_INTERNAL.sub(r"\1", s)
        s = LINK_GH_TREE.sub(r"\1", s)
    s = INLINE_PATH.sub("", s)
    s = TRAIL.sub("", s)
    s = re.sub(r" {2,}", " ", s).strip()
    if len(s) > 360:
        chunk = s[:340]
        if "." in chunk:
            chunk = chunk[: chunk.rfind(".") + 1]
        else:
            chunk = chunk.rsplit(" ", 1)[0] + "."
        s = chunk
    low = s.lower()
    if "no action required" not in low and not re.search(
        r"\b(update|rename|migrate|breaking|must|need to)\b", low
    ):
        s = s.rstrip(":").rstrip()
        if not s.endswith("."):
            s += "."
        s += " No action required."
    return s


def process(text: str) -> str:
    lines = text.splitlines()
    out: list[str] = []
    in_list = False
    skip_children = False

    for line in lines:
        if VERSION_OR_DETAILS.match(line):
            in_list = False
            skip_children = False
            out.append(line)
            continue

        if SECTION.match(line):
            in_list = True
            skip_children = False
            out.append(line)
            continue

        if line.startswith("### "):
            in_list = False
            skip_children = False
            out.append(line)
            continue

        if line.startswith("<details>"):
            in_list = False
            skip_children = False
            out.append(line)
            continue

        if in_list and (line.startswith("  - ") or line.startswith("    -")):
            if skip_children:
                continue
            out.append(line)
            continue

        if in_list and line.startswith("- "):
            skip_children = False
            body = line[2:]
            if "**Pubspec validation" in body or "pubspec validation diagnostics" in body.lower():
                merged = (
                    "**Pubspec validation diagnostics**: Eleven inline checks on `pubspec.yaml` "
                    "(ordering, ignores, l10n hints, workspace resolution, etc.) with quick fixes "
                    "where applicable. No action required."
                )
                out.append("- " + merged)
                skip_children = True
            else:
                out.append("- " + tidy_bullet(body))
                skip_children = False
            continue

        out.append(line)

    return "\n".join(out) + "\n"


def main() -> int:
    if not ARCHIVE.exists():
        print("missing", ARCHIVE, file=sys.stderr)
        return 1
    data = ARCHIVE.read_text(encoding="utf-8")
    new_data = process(data)
    ARCHIVE.write_text(new_data, encoding="utf-8", newline="\n")
    print("updated", ARCHIVE, len(data), "->", len(new_data))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
