# Harden Publish Script — Version Verification Gates

The publish script (`scripts/modules/_git_ops.py`) could silently create a release commit and tag with the wrong `pubspec.yaml` version. The upstream version-write guard in `apply_version_and_rename_unreleased()` compared against a startup snapshot and skipped the write when the snapshot matched the target — but a prior partial run or manual revert could leave pubspec at the old version, producing a tagged commit that `pub.dev` rejects.

## Finish Report (2026-08-31)

### Root Cause

`_version_changelog.py:680` guards `set_version_in_pubspec()` with `if version_to_sync != pubspec_version:`, where `pubspec_version` is read once at script startup. If the file was subsequently reverted (stash pop, checkout, partial prior run), the guard evaluates to "already correct" and skips the write. Downstream steps (package.json bump, commit, tag, push) proceed with the intended version string but the committed `pubspec.yaml` carries the old version. `pub.dev` then rejects the publish because the tarball's pubspec version doesn't match the tag.

### Fix

Two verification gates added to `_git_ops.py`, each checking both `pubspec.yaml` and `extension/package.json`:

1. **`_verify_versions_on_disk`** — called after `git add -A` in `git_commit_and_push()`, before the commit. Reads `pubspec.yaml` via `get_version_from_pubspec()` (lazy import to avoid circular dependency with `_version_changelog`) and reads `extension/package.json` directly. Returns `False` (halting the pipeline) if either version doesn't match.

2. **`_verify_versions_in_commit`** — called at the top of `create_git_tag()`, before tag creation. Reads `HEAD:pubspec.yaml` and `HEAD:extension/package.json` from the committed tree via `git show`. Returns `False` if either version is wrong. Uses the strict `_VERSION_RE` semver pattern (duplicated from `_version_changelog` with a comment noting the sync requirement) instead of a loose `\S+` match.

Both gates produce clear error messages identifying the expected vs. actual version per file.

### Hardening (circular import, regex, package.json)

- **Circular import:** `_version_changelog` imports `tag_exists_on_remote` from `_git_ops`. Adding a top-level import of `get_version_from_pubspec` from `_version_changelog` into `_git_ops` would cause an `ImportError` when `_git_ops` loads first (the imported name isn't defined yet in the partially-loaded module). Fixed by using a lazy import inside `_verify_versions_on_disk`.
- **Regex tightened:** The commit-tree check uses `_VERSION_RE` (strict semver: `\d+\.\d+\.\d+` with optional pre-release) instead of `\S+`, preventing false matches on trailing YAML artifacts.
- **`package.json` gate:** Both checkpoints now also verify `extension/package.json` version when the file exists, preventing the same class of mismatch for the VS Code extension.

### Files Changed

- `scripts/modules/_git_ops.py` — added `_read_package_json_version`, `_VERSION_RE`, `_verify_versions_on_disk`, `_verify_versions_in_commit`; two gate call sites in `git_commit_and_push` and `create_git_tag`.
- `CHANGELOG.md` — entry under `[15.2.7] — Unreleased` Maintenance section.

### Verification

Run the publish script against a test scenario where pubspec.yaml is at version N but the publish target is N+1, without the upstream version write executing. The pipeline should halt at the pre-commit gate with: `pubspec.yaml version mismatch: expected X, found Y`. Similarly, manually set `extension/package.json` to a wrong version and confirm the gate catches it.
