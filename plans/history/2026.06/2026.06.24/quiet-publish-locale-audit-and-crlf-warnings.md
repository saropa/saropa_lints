# Quiet publish-flow noise: locale audit table + git CRLF warnings

The publish workflow flooded its log with two classes of non-actionable output: the extension locale audit echoed its full per-locale table and coverage matrix (~80 info lines) even when every locale passed, and the commit step printed git's per-file "CRLF will be replaced by LF" stderr warning (one line per touched file, dozens on a locale regen). Both buried the meaningful result. This change collapses each to a concise summary while preserving genuine warnings and errors.

## Finish Report (2026-06-24)

### Scope
Publish tooling only (scope C). Two Python modules under `scripts/modules/` and a CHANGELOG Maintenance entry. No Dart rules, analyzer behavior, extension TypeScript, or i18n catalog touched.

### Defect 1 — locale audit dumps full table on a clean pass
`audit_extension_locales` in `scripts/modules/_extension_publish.py` ran `generate_locales.py --mode audit --fail-on-missing`, then on success (return code 0, i.e. every locale fully covered) echoed every stdout line via `print_info`. On a clean audit that is the entire per-locale table plus the coverage matrix — roughly 80 lines — which buried the actual outcome.

Fix: the success branch now filters stdout to the two lines that carry the result — the "fully translated" confirmation and the dated audit report path (`*_i18n_translation_audit.md`) — and prints only those. The failure branch is unchanged: gaps and low-quality lines still surface as warnings there, because a non-zero exit routes through the existing `print_warning` path above the success branch.

### Defect 2 — git CRLF warnings flood the commit step
`git_commit_and_push` in `scripts/modules/_git_ops.py` staged with `run_command(["git", "add", "-A"], ...)`, which does not capture output, so git's per-file `warning: in the working copy of '<file>', CRLF will be replaced by LF...` lines streamed straight to the terminal — one per touched file, dozens after a locale regeneration. These are expected: the step sets `core.autocrlf true` immediately afterward, so the normalization is intended, not an error.

Fix: the staging call now uses `subprocess.run` with `capture_output=True`. Its stderr is scanned; lines containing `"CRLF will be replaced by LF"` are counted and collapsed into a single `Normalized N files (CRLF -> LF)` info line, while any other stderr line still prints as a warning. A non-zero exit prints the captured stderr and fails the step as before. The surrounding `print_info` / `print_success` calls reproduce the prior `run_command` log framing.

### Verification
- `python -m py_compile` clean on both edited modules.
- CRLF counting branch exercised against the exact stderr from the failing run: 35 CRLF warning lines collapse to one count line; a non-CRLF `fatal:` line passes through to the warning path.
- No unit tests exist for these publish-orchestration glue functions (they shell out to git and `generate_locales.py`); behavior is verified by inspection and the counting-logic simulation above.

### Files
- `scripts/modules/_extension_publish.py` — filter audit stdout to summary lines on success.
- `scripts/modules/_git_ops.py` — capture staging stderr, collapse CRLF warnings to a count.
- `CHANGELOG.md` — two `[Unreleased]` Maintenance entries.
