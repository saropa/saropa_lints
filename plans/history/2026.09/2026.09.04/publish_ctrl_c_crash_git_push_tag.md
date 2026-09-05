# Ctrl-C during git push/tag crashed publish.py with a raw traceback

During a live 16.0.0-beta.2 publish run, the developer pressed Ctrl-C while
`gh run watch` was polling the triggered GitHub Actions workflow, intending
only to stop watching locally — the tag push had already triggered the
workflow, which keeps running on GitHub regardless of whether the local
terminal is attached. Instead, the unhandled `KeyboardInterrupt` propagated
through `publish_to_pubdev_step()` and crashed the whole `publish.py` process
with a raw Python traceback, reporting the "Publish" step as failed even
though nothing about the actual publish had failed.

## Root cause

`publish_to_pubdev_step()` in `scripts/modules/_git_ops.py` ran
`subprocess.run(["gh", "run", "watch", ...])` with no `KeyboardInterrupt`
handler. `subprocess.run()` kills the child process on any exception
(including `KeyboardInterrupt`) before re-raising, so the underlying `gh`
process was cleaned up correctly — but the interrupt itself propagated
unhandled all the way up through `_run_step_with_retry` and out of
`publish.py`'s `main()`, producing a traceback instead of the existing
Retry/Abort recovery prompt every other step failure already goes through.

## Fix

Added a `except KeyboardInterrupt:` handler to `publish_to_pubdev_step()`
alongside its existing `except subprocess.TimeoutExpired:` handler — same
pattern, same rationale: print the run's monitor URL and return `False`,
routing through the normal Retry/Abort prompt (`allow_ignore=False`, since
publish is irreversible) instead of an unhandled crash.

A subsequent code review (`/code-review medium`) flagged the identical
failure class at two more call sites in the same file: the `git push`
inside `_attempt_push_with_rebase()` (raw `subprocess.run`, same as the
`gh run watch` call) and the tag push inside `create_git_tag()` (via the
shared `run_command()` helper in `_utils.py`). Both were fixed the same
way — a scoped `try`/`except KeyboardInterrupt` around each call site,
printing a message noting the push/tag may have already landed on the
remote and to check before retrying, then returning `False` so the
existing Retry/Abort flow in each caller handles it gracefully.

The shared `run_command()` helper itself was deliberately left unmodified:
it is called from dozens of unrelated sites across the publish pipeline,
and adding blanket `KeyboardInterrupt` handling there would change behavior
project-wide for a fix that only needed to cover the one irreversible,
network-bound call actually flagged.

## Files changed

- `scripts/modules/_git_ops.py` — three `KeyboardInterrupt` handlers added:
  `publish_to_pubdev_step()` (`gh run watch`), `_attempt_push_with_rebase()`
  (`git push origin <branch>`), `create_git_tag()` (`git push origin
  <tag>`).

## Verification

- Confirmed via direct invocation that `subprocess.run()` already kills the
  child process on any exception (documented in CPython's implementation),
  so no additional process cleanup was needed in any of the three handlers.
- No existing test coverage exists for any of the three functions — no
  mocking harness for subprocess-based git operations exists in this
  test suite, and building one was judged disproportionate to a three-line
  exception-handling pattern replicated across two more call sites.
- Manual Ctrl-C reproduction during an actual `git push`/tag push was not
  performed (would require a live network operation mid-session); the fix
  was verified by code inspection and by confirming the analogous
  `gh run watch` handler behaves correctly in the already-merged commit
  this one follows the same pattern from.

---

## Finish Report (2026-09-04)

Closes nothing in `bugs/`; SKIPPED [NO-BUG-FIXED] — this fix originated
from a `/code-review medium` finding raised during the reflection-gate
hardening step of a prior `/finish` cycle, not from a filed bug report.

Scope: (C) docs/scripts only — Python publish-pipeline module,
`scripts/modules/_git_ops.py`. No Dart lint rules, no extension
TypeScript, no user-facing behavior change (all three fixes affect only
the developer-facing `publish.py` CLI's error handling during an
already-irreversible git operation).
