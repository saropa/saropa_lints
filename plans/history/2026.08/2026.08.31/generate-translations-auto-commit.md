# generate_translations.py — auto-commit after generation

The `generate_translations.py` wrapper script ran the NLLB/Qwen translation
pipeline but left generated locale files as uncommitted dirty state, requiring
a manual `git add` + `git commit` after every run.

## Finish Report (2026-08-31)

**Change:** Added `_git_commit_translations()` to
`extension/scripts/generate_translations.py`. After a successful generation
run, the function stages `extension/src/i18n/locales/` and
`locale_coverage.json`, checks whether anything actually changed, and commits
with a message identifying which locales were regenerated.

**Hardening:**

- Pre-staged file protection — snapshots `git diff --cached --name-only`
  before and after staging; only files the script itself added are committed.
  Pre-existing staged work is left untouched with a warning.
- `git add` return-code checking — each staging call aborts with an error
  on failure instead of silently continuing.
- Hook output visibility — `git commit` no longer uses `capture_output=True`,
  so pre-commit hook failures and their messages are shown to the operator.
- Translation paths are a module-level constant (`_TRANSLATION_PATHS`) so
  new pipeline outputs only need one edit.

**New flag:** `--no-commit` skips the auto-commit step. The flag is stripped
before forwarding args to `generate_locales.py`. Useful for CI or review
workflows where the commit should happen separately.

**Files modified:**

- `extension/scripts/generate_translations.py` — `_git_commit_translations`,
  `_TRANSLATION_PATHS` constant, `--no-commit` flag handling.
- `CHANGELOG.md` — maintenance entry added.

**Scope:** Scripts only. No Dart rules, extension TypeScript, or user-facing
strings touched. No tests affected.
