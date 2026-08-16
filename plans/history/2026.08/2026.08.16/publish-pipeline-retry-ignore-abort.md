# Publish Pipeline: Retry / Ignore / Abort on Failure

The publish script (`scripts/publish.py`) hard-exited via `sys.exit()` on any
pipeline step failure, forcing the developer to restart the entire multi-minute
workflow after fixing a single issue. This was especially painful for late-stage
failures (git tag, GitHub release, extension packaging) where earlier steps had
already completed successfully.

## Finish Report (2026-08-16)

### Changes

**`scripts/modules/_utils.py`** — Added `prompt_step_failure(step_name, *,
allow_ignore=True)`: a reusable interactive prompt that prints
`[R]etry / [I]gnore / [A]bort` and returns the developer's choice. When
`allow_ignore=False`, the Ignore option is hidden and typing 'i' falls
through to abort. Defaults to abort on empty input, EOF, or Ctrl+C for safety.

**`scripts/modules/_publish_workflow.py`** — Added `_run_step_with_retry(step_name,
run_fn, exit_code, *, allow_ignore=True)`: a generic wrapper that loops any
`() -> bool` step function through the RIA prompt on failure. Converted 12+
hard-exit failure points across all pipeline stages:

- Dependency resolution, prerequisites, working tree, remote sync, publish
  workflow commit, formatting, CHANGELOG validation, docs generation,
  pre-publish validation, final CI gate, git commit/push, git tag, pub.dev
  publish, GitHub release, extension packaging (2 sites), audit (non-auto-fixable).

Steps that already had their own interactive failure prompts (dart analyze,
dart test, British spelling) are left as-is — the outer gate only fires when
those inner prompts resolve to "abort."

**`lib/src/rules/stylistic/formatting_rules.dart`** — Removed unused
`import '../../tiers.dart' as tiers'` that was blocking a commit via the
pre-commit lint hook.

### Hardening (post-review)

**Irreversible step guards:** Four critical steps in
`run_commit_tag_publish_release` are marked `allow_ignore=False` so the
developer can only Retry or Abort — never Ignore:

- Git commit & push (downstream steps assume the commit is on the remote)
- Git tag (publishing without a tag breaks release traceability)
- Publish to pub.dev (skipping would create a GitHub release for an
  unpublished version)
- GitHub release (the package is already on pub.dev; a missing release
  leaves no release notes)

**Extension ignore crash guard:** `run_extension_after_publish` now checks
whether the `.vsix` file exists after the RIA loop exits. If the developer
chose Ignore on a packaging failure, the function returns `(None, False)`
with a warning instead of crashing when downstream code tries to install or
publish a non-existent file.

**Missing import fix:** Added `print_error` to the import block in
`_publish_workflow.py` — it was called at three new sites but never imported,
which would have caused a `NameError` on any GitHub release failure, extension
packaging failure, or full-publish extension packaging failure.

### Verification

- Both files pass `python -m py_compile` (syntax clean).
- No automated tests exist for the publish script (interactive CLI workflow).
- No Dart test files reference any changed symbols.
