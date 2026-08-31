#!/usr/bin/env python3
"""Generate translated extension locale files.

Sets up the environment and invokes generate_locales.py with the correct
Python interpreter. Eliminates shell-specific env var syntax differences
between PowerShell, cmd, and bash.

Translation engine: Qwen 3 via local Ollama (primary), Google Translate
(per-string fallback). See ``extension/scripts/i18n/qwen_engine.py``.

Requires: pip install deep-translator (Google fallback).
          Ollama installed from https://ollama.com/download (model pull is automatic).

Usage (from repo root):
    py -3 extension/scripts/generate_translations.py                    # all locales
    py -3 extension/scripts/generate_translations.py --locales bn,de    # specific locales
    py -3 extension/scripts/generate_translations.py --no-commit        # skip auto-commit
"""

from __future__ import annotations

import os
import signal
import subprocess
import sys
from pathlib import Path

# Import the shared color helper from the i18n package directory. The path
# adjustment lets this wrapper colorize its own header lines consistently
# with the child generate_locales.py output.
sys.path.insert(0, str(Path(__file__).resolve().parent / "i18n"))
from term_color import c  # noqa: E402


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent.parent
    script_dir = Path(__file__).resolve().parent / "i18n"
    generate_script = script_dir / "generate_locales.py"
    if not generate_script.is_file():
        print(c("red", f"ERROR: {generate_script} not found."), file=sys.stderr)
        return 1

    # Strip --no-commit before forwarding args to generate_locales.py,
    # which doesn't understand it.
    no_commit = "--no-commit" in sys.argv[1:]
    forwarded_args = [a for a in sys.argv[1:] if a != "--no-commit"]

    env = os.environ.copy()
    env["PYTHONUTF8"] = "1"
    env["SAROPA_I18N_MACHINE_TRANSLATE"] = "1"

    cmd = [sys.executable, str(generate_script)] + forwarded_args

    locales = _locales_from_args(forwarded_args)
    tag = c("magenta", "generate_translations")
    print(f"[{tag}] {c('gray', 'python=')}{sys.executable}", flush=True)
    print(f"[{tag}] {c('gray', 'locales=')}{c('cyan', locales)}", flush=True)
    if no_commit:
        print(f"[{tag}] {c('yellow', '--no-commit: skipping auto-commit')}", flush=True)

    # Snapshot the working tree BEFORE generation so we can auto-detect
    # every file the pipeline touches, without a hardcoded path list.
    pre_snapshot = _snapshot_worktree(repo_root) if not no_commit else set()

    # Ignore SIGINT so the translation child can handle it cleanly, then
    # restore the default handler before running git (so Ctrl+C can abort
    # a stuck commit rather than being silently swallowed).
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    result = subprocess.run(cmd, env=env, cwd=str(script_dir))
    signal.signal(signal.SIGINT, signal.SIG_DFL)

    if result.returncode != 0:
        return result.returncode

    if no_commit:
        return 0

    # Diff the working tree to find every file the pipeline created or modified.
    post_snapshot = _snapshot_worktree(repo_root)
    changed = post_snapshot - pre_snapshot
    if not changed:
        print(f"[{tag}] {c('gray', 'no translation changes to commit')}", flush=True)
        return 0

    # Commit only the files the pipeline actually touched.
    return _git_commit_translations(repo_root, locales, changed)


def _snapshot_worktree(repo_root: Path) -> set[tuple[str, str]]:
    """Capture (path, content-hash) pairs for every tracked+untracked file.

    Uses `git status --porcelain=v2 -z` for null-delimited, machine-stable
    output that handles filenames with spaces, quotes, and newlines.
    Returns a set of (path, status-line) tuples — comparing before/after
    sets reveals exactly which files the pipeline changed.
    """
    result = subprocess.run(
        ["git", "status", "--porcelain=v2", "-z", "-u"],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
    )
    # Entries are null-separated. Each entry's last field is the path.
    # Rename entries have two paths (old\0new), but the pipeline doesn't
    # rename files so we don't need special handling.
    entries = set()
    if result.stdout:
        for entry in result.stdout.rstrip("\0").split("\0"):
            if entry:
                entries.add(entry)
    return entries


def _git_commit_translations(
    repo_root: Path, locales: str, changed: set[str],
) -> int:
    """Stage and commit the files the translation pipeline touched.

    ``changed`` contains raw porcelain v2 entries — extract the file path
    (last whitespace-delimited field) from each.
    """
    tag = c("magenta", "generate_translations")

    # Extract file paths from porcelain v2 entries. Ordinary changed entries
    # (starting with "1 " or "2 ") have the path as the last space-field.
    # Untracked entries ("? path") have the path after "? ".
    changed_paths: list[str] = []
    for entry in sorted(changed):
        if entry.startswith("? "):
            changed_paths.append(entry[2:])
        else:
            # "1 .M ... path" or "2 ... path" — path is last field.
            changed_paths.append(entry.rsplit(" ", 1)[-1])

    # Snapshot what's already staged so we can detect (and avoid committing)
    # unrelated work that was staged before this script ran. Use -z for
    # null-delimited output — immune to filenames containing newlines.
    pre_staged = _staged_files(repo_root)

    # Stage only the files the pipeline touched.
    for p in changed_paths:
        add_result = subprocess.run(
            ["git", "add", "--", p],
            cwd=str(repo_root),
            capture_output=True,
            text=True,
        )
        if add_result.returncode != 0:
            print(
                c("red", f"ERROR: git add {p} failed:\n{add_result.stderr}"),
                file=sys.stderr,
            )
            return add_result.returncode

    # Compute which files this script actually staged (vs already-staged).
    post_staged = _staged_files(repo_root)
    newly_staged = sorted(post_staged - pre_staged)

    if not newly_staged:
        # Everything the pipeline touched was already staged identically.
        print(f"[{tag}] {c('gray', 'no translation changes to commit')}", flush=True)
        return 0

    # Warn if unrelated files were already staged — we won't touch them.
    if pre_staged:
        print(
            f"[{tag}] {c('yellow', f'note: {len(pre_staged)} pre-staged file(s) left untouched')}",
            flush=True,
        )

    # Build a descriptive commit message.
    if locales == "all (default)":
        msg = "chore: regenerate all translated locales"
    else:
        msg = f"chore: regenerate translations for {locales}"

    # Show hook output (stdout/stderr) so pre-commit failures are visible.
    # Explicit file paths limit the commit to only what this script staged.
    result = subprocess.run(
        ["git", "commit", "-m", msg, "--"] + newly_staged,
        cwd=str(repo_root),
    )
    if result.returncode != 0:
        print(
            c("red", "ERROR: git commit failed (see output above)"),
            file=sys.stderr,
        )
        return result.returncode

    print(f"[{tag}] {c('green', 'committed:')} {msg}", flush=True)
    print(f"[{tag}] {c('gray', f'{len(newly_staged)} file(s)')}", flush=True)
    return 0


def _staged_files(repo_root: Path) -> set[str]:
    """Return the set of currently staged file paths.

    Uses -z for null-delimited output — handles filenames with newlines,
    spaces, and other special characters safely.
    """
    result = subprocess.run(
        ["git", "diff", "--cached", "--name-only", "-z"],
        cwd=str(repo_root),
        capture_output=True,
        text=True,
    )
    if not result.stdout:
        return set()
    # Null-delimited: split on \0, filter empty trailing entry.
    return {p for p in result.stdout.split("\0") if p}


def _locales_from_args(args: list[str]) -> str:
    """Extract --locales value for display, or 'all (default)' if absent."""
    for i, a in enumerate(args):
        if a == "--locales" and i + 1 < len(args):
            return args[i + 1]
        if a.startswith("--locales="):
            return a.split("=", 1)[1]
    return "all (default)"


if __name__ == "__main__":
    raise SystemExit(main())
