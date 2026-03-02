"""
Strip AI attribution lines from commit messages.

Use when needed: import and call strip_commit_message(msg), or run as a script
(stdin → stdout) for filter-branch or pipes.

  from scripts.modules.strip_commit_msg_trailers import strip_commit_message
  cleaned = strip_commit_message(commit_message)

  python -m scripts.modules.strip_commit_msg_trailers  # stdin → stdout
"""

from __future__ import annotations

import re
import sys

# Strip: Made-with Cursor, Co-Authored-By Claude/Anthropic/Cursor/Copilot/GPT/OpenAI, tool attribution
SKIP_PATTERNS = [
    re.compile(r"^Made-with:\s*Cursor\s*$", re.I),
    re.compile(r"^Co-Authored-By:\s*.*[Cc]laude.*$"),  # Claude Opus 4.6, Claude Sonnet 4.5, etc.
    re.compile(r"^Co-Authored-By:\s*.*[Aa]nthropic.*$"),
    re.compile(r"^Co-Authored-By:\s*.*noreply@anthropic\.com.*$", re.I),
    re.compile(r"^Co-Authored-By:\s*.*(?:Cursor|Copilot|GPT|OpenAI|noreply@github).*$", re.I),
    re.compile(r"^Generated with\s+.*(?:Cursor|Claude).*$", re.I),
]


def strip_commit_message(message: str) -> str:
    """Return message with AI attribution lines removed.

    Used by publish (git_ops) and by the CLI (stdin → stdout).
    """
    msg = message.replace("\r\n", "\n").replace("\r", "\n")
    lines = msg.split("\n")
    out = []
    for line in lines:
        line_clean = line.rstrip()
        if any(p.match(line_clean) for p in SKIP_PATTERNS):
            continue
        out.append(line)
    while len(out) > 1 and out[-1].strip() == "":
        out.pop()
    result = "\n".join(out)
    if out:
        result += "\n"
    return result


def main() -> None:
    """Read commit message from stdin, write stripped message to stdout."""
    msg = sys.stdin.read()
    sys.stdout.write(strip_commit_message(msg))


if __name__ == "__main__":
    main()
