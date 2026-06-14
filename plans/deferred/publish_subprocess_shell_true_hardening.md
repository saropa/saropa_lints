# Deferred: `shell=True` hardening in the publish subprocess calls

**Source:** Codebase audit 2026-06-12 (Workstream H, item H6). Pulled out of `plans/history/2026.06/2026.06.14/CODEBASE_AUDIT_2026.06.12.md` into this standalone deferred doc.
**Status:** ASSESSED — intentionally not changed. Low priority / defense-in-depth.
**Severity:** Low (no known exploit path in the publish context).

## The finding

Every git/`gh` subprocess call in `scripts/modules/_git_ops.py` passes `shell=get_shell_mode()`, which returns `True` on Windows (`scripts/modules/_utils.py` `get_shell_mode`). Examples: `_push_with_retry` / `_attempt_push_with_rebase`, `create_git_tag`, `tag_exists_on_remote`, `extract_repo_path`, and the `gh run watch` call.

With `shell=True` AND a **list** argument on Windows, Python hands the list to `cmd.exe`. Interpolated values flow into some of these commands:
- `tag_name = f"v{version}"` (`create_git_tag`, ~line 144/318)
- the branch name from `get_current_branch`
- remote-derived strings in `tag_exists_on_remote` / `extract_repo_path`

A branch or tag name containing shell metacharacters would be interpreted by `cmd.exe` rather than passed literally.

## Why it is NOT being changed now

1. **No attacker-controlled input in the publish context.** `version` is validated as semver before the tag is built; the branch is the repo's own current branch. There is no path by which an untrusted string reaches these commands during a normal release.
2. **Blanket-removing `shell=True` risks breaking the Windows release path.** `get_shell_mode()` returns `True` partly so Windows can resolve `.bat` shims (e.g. `flutter.bat`) and PATH-based tool lookup. Flipping git/`gh` calls to `shell=False` is a behavior change to the critical, hard-to-test release pipeline (the project's history emphasizes not destabilizing publish — see the v13.12.6/.7 incidents). The marginal security gain does not justify that risk.

## If this is ever pursued — the safe approach

Do NOT blanket-flip `get_shell_mode()`. Instead:
1. For the specific calls that interpolate a branch/tag name, **validate** the value against a strict allowlist before use, e.g. tags must match `^v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$` and branches `^[\w./-]+$`; abort the publish with a clear error otherwise.
2. OR, for git/`gh` only (both are real executables, not `.bat`), pass `shell=False` for those specific calls while leaving `flutter`/`.bat` invocations on `get_shell_mode()`. Verify on Windows that `git`/`gh` still resolve via PATH (they do for standard installs).
3. Add a `scripts/modules/tests/` regression test that a tag/branch containing a metacharacter is rejected (validation path) or passed literally (shell=False path).

## Pointers

- `scripts/modules/_git_ops.py` — all the git/`gh` `subprocess.run(..., shell=use_shell)` sites.
- `scripts/modules/_utils.py` — `get_shell_mode()`.
- The `gh run watch` timeout crash (separate, already FIXED in the same audit) is documented in the main audit plan under Workstream H.
