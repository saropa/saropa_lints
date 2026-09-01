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

### Further Hardening

- **`VERSION_RE` extracted to `_utils.py`:** Single source of truth for the semver regex pattern. Both `_git_ops.py` and `_version_changelog.py` import `VERSION_RE as _VERSION_RE` from `_utils`, eliminating the duplicated constant and sync risk. The alias preserves the private naming convention at each call site.
- **package.json regex tightened:** `_read_package_json_version` and the commit-tree check now use `_VERSION_RE` inside the JSON value match (`"version": "({_VERSION_RE})"`) instead of the permissive `[^"]+`, rejecting non-semver values that would silently pass the old check.
- **Visible output for all outcomes:** Both gates now print a status line for every file checked — success, mismatch (error), or missing/unparseable (warning). The operator sees exactly what was verified in the publish log.

### Visible Preflight Step

`run_preflight_version_check()` — a public function in `_git_ops.py` that prints a `PREFLIGHT: VERSION VERIFICATION` header banner and delegates to `_verify_versions_on_disk`. Wired into `run_full_publish()` in `_publish_workflow.py` as its own timed step, running after `set_extension_version` and before badge validation / CI gate / extension packaging. This gives the operator an early, prominent signal before expensive downstream steps run. The step uses `_run_step_with_retry` so a mismatch can be fixed and retried without restarting the entire publish.

### Files Changed

- `scripts/modules/_utils.py` — added `VERSION_RE` constant.
- `scripts/modules/_git_ops.py` — added `_read_package_json_version`, `_verify_versions_on_disk`, `_verify_versions_in_commit`, `run_preflight_version_check`; two gate call sites in `git_commit_and_push` and `create_git_tag`; imports `VERSION_RE` from `_utils`.
- `scripts/modules/_version_changelog.py` — removed local `_VERSION_RE` definition, imports `VERSION_RE` from `_utils`.
- `scripts/modules/_publish_workflow.py` — imported `run_preflight_version_check`, wired it as a timed step after version sync.
- `CHANGELOG.md` — entry under `[15.2.7] — Unreleased` Maintenance section.

### Verification

Run the publish script — the log should show a `PREFLIGHT: VERSION VERIFICATION` banner with `Verified pubspec.yaml version is X` and `Verified extension/package.json version is X` lines. To test the mismatch path: temporarily set pubspec.yaml to a wrong version after the version-sync step; the preflight should halt with `pubspec.yaml version mismatch: expected X, found Y` and offer retry. The two downstream gates (after staging and before tagging) provide additional safety nets.
