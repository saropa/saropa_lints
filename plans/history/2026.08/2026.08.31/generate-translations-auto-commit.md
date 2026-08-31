# generate_translations.py — auto-commit after generation

The `generate_translations.py` wrapper script ran the NLLB/Qwen translation
pipeline but left generated locale files as uncommitted dirty state, requiring
a manual `git add` + `git commit` after every run.

## Finish Report (2026-08-31)

**Change:** Added `_git_commit_translations()` to
`extension/scripts/generate_translations.py`. After a successful generation
run, the function stages `extension/src/i18n/locales/` and
`locale_coverage.json`, checks whether anything actually changed via
`git diff --cached --quiet`, and commits with a message identifying which
locales were regenerated. Each `git add` call checks its return code and
aborts with an error message on failure — preventing silent swallowing of
staging errors.

**Files modified:**

- `extension/scripts/generate_translations.py` — new `_git_commit_translations` function; `main()` calls it on success.
- `CHANGELOG.md` — maintenance entry added.

**Scope:** Scripts only. No Dart rules, extension TypeScript, or user-facing
strings touched. No tests affected.
