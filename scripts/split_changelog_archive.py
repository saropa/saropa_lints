#!/usr/bin/env python3
"""Split CHANGELOG_ARCHIVE.md into changelog/archive/<major>.<minor>.x.md files.

Idempotent: re-reads existing per-line files plus any new release sections in
CHANGELOG_ARCHIVE.md, merges them (newest first), and rewrites the index.
"""
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARCHIVE = ROOT / "CHANGELOG_ARCHIVE.md"
OUT_DIR = ROOT / "changelog" / "archive"
HEADING = re.compile(r"^## \[(\d+)\.(\d+)\.(\d+)(?:[-+][^\]]*)?\]")
REPO = "https://github.com/saropa/saropa_lints/blob/main"


def sections(text: str):
    """Yield ((major, minor, patch), heading_line, body) for release sections."""
    cur, buf, fence = None, [], False
    for line in text.splitlines():
        if line.startswith("```"):
            fence = not fence
        m = None if fence else HEADING.match(line)
        if m:
            if cur:
                yield cur[0], cur[1], "\n".join(buf).rstrip() + "\n"
            cur, buf = (tuple(int(g) for g in m.groups()), line), [line]
        elif cur:
            buf.append(line)
    if cur:
        yield cur[0], cur[1], "\n".join(buf).rstrip() + "\n"


def main() -> int:
    texts = [ARCHIVE.read_text(encoding="utf-8")]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    texts += [p.read_text(encoding="utf-8") for p in OUT_DIR.glob("*.md")]
    seen: dict[str, tuple] = {}
    for t in texts:
        for ver, head, body in sections(t):
            seen.setdefault(head, (ver, body))  # first occurrence wins
    groups: "OrderedDict[tuple, list]" = OrderedDict()
    for head, (ver, body) in sorted(seen.items(), key=lambda kv: kv[1][0], reverse=True):
        groups.setdefault(ver[:2], []).append((ver, body))
    for (maj, mnr), items in groups.items():
        out = OUT_DIR / f"{maj}.{mnr}.x.md"
        out.write_text(
            f"# Changelog Archive: {maj}.{mnr}.x\n\n<!-- cspell:disable -->\n\n"
            + "\n".join(b for _, b in items),
            encoding="utf-8", newline="\n")
    rows = "\n".join(
        f"- [{maj}.{mnr}.x](changelog/archive/{maj}.{mnr}.x.md) — "
        f"{len(items)} release(s), {items[-1][0][2] if False else ''}"
        f"{maj}.{mnr}.{min(i[0][2] for i in items)}–{maj}.{mnr}.{max(i[0][2] for i in items)}"
        for (maj, mnr), items in groups.items())
    ARCHIVE.write_text(
        "# Changelog Archive\n\nArchived releases, one file per major.minor line "
        "in [changelog/archive/](changelog/archive/). Search the whole record with "
        "`grep -r <term> changelog/archive/`. See "
        f"[CHANGELOG.md]({REPO}/CHANGELOG.md) for the latest versions.\n\n"
        + rows + "\n", encoding="utf-8", newline="\n")
    print(f"{len(seen)} releases -> {len(groups)} files")
    return 0


if __name__ == "__main__":
    sys.exit(main())
