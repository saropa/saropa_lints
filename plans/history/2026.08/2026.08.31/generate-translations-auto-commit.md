# generate_translations.py — auto-commit after generation

The `generate_translations.py` wrapper script ran the NLLB/Qwen translation
pipeline but left generated locale files as uncommitted dirty state, requiring
a manual `git add` + `git commit` after every run.

## Finish Report (2026-08-31)

**Change:** Added auto-commit to `extension/scripts/generate_translations.py`.
After a successful generation run, the script snapshots the working tree
before and after the pipeline, diffs the two to find every file the pipeline
created or modified, and commits only those files.

**Auto-detection (replaces hardcoded path list):**

The previous version used a `_TRANSLATION_PATHS` constant listing known
output directories. The new version uses `git status --porcelain=v2 -z`
snapshots taken before and after `generate_locales.py` runs. Any file that
appears or changes between snapshots is attributed to the pipeline and
staged for commit. This eliminates the maintenance burden of updating a
hardcoded list when the pipeline adds new output paths.

**Hardening:**

- Pre-staged file protection — `git diff --cached --name-only -z`
  (null-delimited) snapshots the index before and after staging. Only files
  the script itself added are passed to `git commit`. Pre-existing staged
  work is left untouched with a warning. Null delimiters handle filenames
  with spaces, quotes, or newlines.
- `git add` return-code checking — each staging call aborts with an error
  on failure instead of silently continuing.
- Hook output visibility — `git commit` runs without `capture_output`,
  so pre-commit hook failures and their messages are shown to the operator.
- SIGINT restoration — `signal.SIG_DFL` is restored after the translation
  child finishes and before any git calls, so Ctrl+C can abort a stuck
  commit rather than being silently ignored.

**New flag:** `--no-commit` skips the auto-commit step. The flag is stripped
before forwarding args to `generate_locales.py`. Useful for CI or review
workflows where the commit should happen separately.

**Files modified:**

- `extension/scripts/generate_translations.py` — `_git_commit_translations`,
  `_snapshot_worktree`, `_staged_files`, `--no-commit` flag handling.
- `CHANGELOG.md` — maintenance entry updated.

**Scope:** Scripts only. No Dart rules, extension TypeScript, or user-facing
strings touched. No tests affected.
