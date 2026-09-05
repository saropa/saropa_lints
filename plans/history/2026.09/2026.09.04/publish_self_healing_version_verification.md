# Publish Self-Healing Version Verification

The publish script's preflight version check failed on every pre-release publish because `set_extension_version()` received raw pub.dev versions (e.g. `16.0.0-beta.2`) instead of the converted extension version (e.g. `16.1.914`). The function wrote whatever string it was given, leaving callers responsible for a conversion step that three of four call sites forgot.

## Finish Report (2026-09-04)

### Root cause

`set_extension_version()` in `_extension_publish.py` was a dumb string-replace setter — it wrote whatever `version` argument it received into `package.json` without calling `extension_version_for()`. Four call sites existed; only `package_extension()` remembered to wrap the argument. The other three (two publish modes in `_publish_workflow.py`, one orphaned-version-bump reset) passed raw pub.dev versions, producing a mismatch that the preflight check then caught and refused.

A secondary bug: the odd-minor fix (commit 6bb85fe6) introduced `int(minor) | 1` for pre-release versions but never updated 5 test expectations in `test_prerelease_version.py`, leaving the test suite red since that commit.

### Changes

| File | Change |
|------|--------|
| `scripts/modules/_extension_publish.py` | `set_extension_version()` now calls `extension_version_for()` internally — callers pass the raw pub.dev version and conversion is guaranteed. Added idempotency guard: skips the write when the file already has the correct version (cleaner git diffs on publish retries). |
| `scripts/modules/_publish_workflow.py` | Removed `extension_version_for()` wrapping from all three call sites (now redundant). Fixed log message to print converted version after reset. |
| `scripts/modules/_git_ops.py` | `_verify_versions_on_disk()` self-heals package.json mismatches (writes correct version instead of failing). Extracted `_heal_committed_package_json()` helper from `_verify_versions_in_commit()` — uses `run_command()` instead of raw `subprocess.run`, checks `.returncode` properly. Added `_is_head_pushed()` guard: refuses to amend HEAD if it has already been pushed to origin (prevents history divergence). Moved `extension_version_for` and `set_extension_version` from lazy inline imports to top-level (no circular dependency). |
| `scripts/modules/tests/test_prerelease_version.py` | Updated 5 test expectations to use odd-minor values (e.g. `16.1.913` not `16.0.913`). Added 2 idempotency tests pinning that `extension_version_for(extension_version_for(v)) == extension_version_for(v)` for both pre-release and stable versions. |
| `extension/package.json` | Reverted version to `16.0.0-beta.1` (last published tag). |
| `CHANGELOG.md` | Added maintenance entry for the preflight self-heal fix. |

### Design decisions

- **Self-converting setter over N-site wrapping**: The class of bug ("caller forgot to convert") is structurally impossible once the setter does it. The self-heal logic in `_verify_versions_on_disk` and `_verify_versions_in_commit` remains as defense-in-depth for git/filesystem races.
- **Amend-after-push guard**: `_is_head_pushed()` checks `git merge-base --is-ancestor HEAD origin/<branch>` before amending. If HEAD is already pushed, the self-heal refuses and prints a manual-fix instruction. Prevents the history-divergence scenario flagged by code review.
- **Idempotency guard in setter**: `set_extension_version()` reads the current version before writing and skips the write if it already matches. Prevents unnecessary file writes on publish retries.
- **`run_command()` over raw `subprocess.run`**: Consistent with every other git call in the file — centralizes logging and error formatting. `run_command` returns `CompletedProcess`, checked via `.returncode`.
- **Push-before-verify ordering documented**: `_verify_versions_in_commit` runs from `create_git_tag` (step 13), after `git_commit_and_push` (step 12) has already pushed HEAD. The `_is_head_pushed()` guard is essential — documented in the docstring so future maintainers understand why the amend path refuses when HEAD is on the remote.
- **`_is_head_pushed()` hardened**: Handles detached HEAD (returns False — safe to amend during rebase/cherry-pick) and unreachable remote (returns False — conservative fallback). Both edge cases documented in docstring.
- **`extension_version_for()` idempotency contract explicit**: Docstring documents that converted versions have no `-` and hit the stable pass-through path, so `extension_version_for(extension_version_for(v)) == extension_version_for(v)`.
- **Dry-run mode for `set_extension_version()`**: `dry_run=True` returns the converted version string without touching the file — useful for preflight checks that need the expected version without side effects. Returns `""` when package.json is missing.

### Verification

19/19 `test_prerelease_version.py` tests pass (13 original + 2 idempotency + 4 dry-run). The self-healing path was confirmed by the original failure scenario: package.json had `16.0.0-beta.2` (raw), preflight expected `16.1.914` (converted) — with the fix, the setter writes `16.1.914` and the self-heal auto-corrects any residual mismatch.
