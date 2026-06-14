"""British-English spelling guard for the git pre-commit and Claude hooks.

Scans the touched file(s) for British spellings using the shared scanner
(``scripts/modules/_us_spelling.py``) and exits non-zero with the hits on
stderr when any are found.

Why this exists: British spellings kept reaching pub.dev because the only
mechanical check ran at publish time and was bypassable (the ``[I]gnore``
prompt). This guard moves the check to *write* time (Claude Edit/Write,
via a PostToolUse hook) and *commit* time (git pre-commit), where it is
early and non-interactive. See ``bugs/british_english_recurrence_attempts.md``.

Two invocation modes, one script:
  * **git pre-commit** passes staged file paths as command-line arguments.
  * **Claude PostToolUse** passes a JSON payload on stdin; the edited file
    is read from ``tool_input.file_path``.

Exit codes: 0 = clean, 2 = British spelling(s) found. Exit 2 is meaningful
to Claude Code (stderr is fed back to the model) and is also a plain
non-zero failure that blocks the git commit.

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

# The repo root is two levels up: scripts/hooks/spelling_guard.py.
# Deriving it from __file__ (not cwd) keeps the import working no matter
# where git or the editor launches the hook from.
_REPO_ROOT = Path(__file__).resolve().parents[2]
if str(_REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(_REPO_ROOT))

# Imported after sys.path is fixed so `scripts.modules` resolves when this
# file is run as a plain script rather than `python -m`.
from scripts.modules._us_spelling import (  # noqa: E402
    SpellingHit,
    scan_paths,
)


def _paths_from_stdin() -> list[str]:
    """Pull the edited file path out of a Claude Code PostToolUse payload.

    Edit / Write / MultiEdit all report the target under
    ``tool_input.file_path``. Returns an empty list when stdin carries no
    payload (e.g. the git hook path, which uses argv instead) or the JSON
    is not a hook envelope, so a malformed/absent payload never blocks.
    """
    # ``isatty`` guards against blocking on an interactive terminal when
    # the script is run by hand with no piped input.
    if sys.stdin.isatty():
        return []
    data = sys.stdin.read()
    if not data.strip():
        return []
    try:
        payload = json.loads(data)
    except json.JSONDecodeError:
        return []
    tool_input = payload.get("tool_input") or {}
    file_path = tool_input.get("file_path")
    return [file_path] if file_path else []


def _within_repo(path_str: str) -> bool:
    """Whether [path_str] resolves to a file inside this repo.

    The PostToolUse hook fires on every Edit/Write, including edits to files
    OUTSIDE this repo (e.g. the user's global ``~/.claude/CLAUDE.md``). This
    guard enforces a repo-local policy, so scanning an external file is both
    out of scope and a false-positive source — the global config legitimately
    contains British words inside its own banned-spelling reference table.
    Restricting to repo paths keeps the gate fully active for repo files while
    leaving external edits alone. Git pre-commit only ever passes repo paths,
    so it is unaffected.
    """
    try:
        resolved = Path(path_str).resolve()
    except OSError:
        return False
    try:
        resolved.relative_to(_REPO_ROOT)
        return True
    except ValueError:
        return False


def _format_hits(hits: list[SpellingHit]) -> str:
    """Render hits as one ``path:line  uk -> us`` line each for stderr."""
    lines = [
        f"  {hit.file}:{hit.line_number}  "
        f"{hit.uk_word} -> {hit.us_word}"
        for hit in hits
    ]
    return "\n".join(lines)


def main() -> int:
    # argv wins (git hook); fall back to a stdin payload (Claude hook).
    paths = list(sys.argv[1:]) or _paths_from_stdin()
    # Only scan files inside this repo; an Edit to an external file (e.g. the
    # global ~/.claude/CLAUDE.md) must not be policed by this repo's gate.
    paths = [p for p in paths if _within_repo(p)]
    if not paths:
        return 0

    hits = scan_paths(paths, _REPO_ROOT)
    if not hits:
        return 0

    sys.stderr.write(
        "British English spelling(s) found - US English is a hard rule "
        "for this repo:\n"
        + _format_hits(hits)
        + "\n\nFix the spelling(s) above before committing. This gate is "
        "intentionally non-bypassable; do not add an ignore path.\n"
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
