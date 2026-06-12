# US-Spelling Audit: CamelCase Coverage + Plan-History Exemption

The publish-time audit reported two hits, raising the question of whether
`/bin/` should be excluded. `/bin/` is shipped Dart source (CLI entry
points like `dart run saropa_lints:project_vibrancy`) — it must NOT be
excluded. The two reported hits were real US-spelling violations the
audit's word-boundary regex caught in prose, but the audit was also
silently missing a third violation in the same file — a private
exception class named with the British double-l spelling — because the
`\b` boundary does not treat lowercase->uppercase transitions inside an
identifier as a word boundary. This change fixes the original hits,
widens the audit to catch CamelCase embeds, and exempts archived plan
docs that re-trip the gate after their work has shipped.

## Finish Report (2026-05-26)

### Scope

- **(A)** Dart code — three files: a private-class rename + a comment
  fix in `bin/project_vibrancy.dart`, and `cspell:ignore` tags on two
  intentional Dio-API-name references that the new CamelCase pattern
  would otherwise flag.
- **(C)** Python script — extended `scripts/modules/_us_spelling.py`
  with a second pattern for CamelCase-embedded UK words and a
  path-based skip for `plans/history/`. Added a new test module that
  pins both old and new behavior.

### Files changed

| Path | Change |
|---|---|
| `bin/project_vibrancy.dart` | Renamed private `_ScanCancelled` → `_ScanCanceled` (5 refs, file-scope only); fixed prose comment `cancelled` → `canceled`. |
| `lib/src/rules/network/api_network_rules.dart` | Added `cspell:ignore isCancelled` tag on the line that contains the regex literal `\bisCancelled\b` (the lint matches both spellings of the Dio/Java-style getter; the British form is intentional). |
| `example/lib/flutter_mocks.dart` | Same suppression on the `CancelToken.isCancelled` mock; comment rephrased so the explanatory text doesn't itself trip the audit. |
| `scripts/modules/_us_spelling.py` | Added `_UK_CAMEL_PATTERN` (lookahead/lookbehind for lowercase->Uppercase boundary) running alongside the existing `\b`-based `_UK_PATTERN`; added per-line span dedupe; added `_should_skip_plans_history` to exempt archived plan docs; added `test_us_spelling.py` to `_SKIP_FILES`. |
| `scripts/modules/tests/test_us_spelling.py` | NEW — 8 unit tests pinning standalone-word matches, CamelCase embeds, leading-underscore non-match, out-of-dictionary non-match, `cspell` suppression, and per-line span dedupe. |
| `plans/history/2026.05/2026.05.25/PROJECT_HEALTH_DASHBOARD_PLAN.md` | One uncommitted prose fix from earlier (`cancelling` → `canceling`); included because it was one of the original audit hits authorized for fixing. |
| `CHANGELOG.md` | Added Maintenance bullet under `[13.11.0]` describing the audit widen and the `plans/history/` exemption; tagged with HTML `cspell:ignore` comment so the bullet's own example identifiers don't trip the audit. |
| `plans/history/2026.05/2026.05.26/us_spelling_audit_camelcase.md` | NEW — this file. |

### Diff summary (core logic)

1. **`_us_spelling.py` — second regex pass.** The existing
   `_UK_PATTERN = re.compile(r"\b(...)\b", re.IGNORECASE)` cannot see
   British forms inside CamelCase identifiers because `\b` requires a
   word/non-word transition and both sides of a `lower->Upper` split
   inside an identifier are word characters. The fix adds:

       _CAPITALIZED_UK = [w[0].upper() + w[1:] for w in _SORTED_UK]
       _UK_CAMEL_PATTERN = re.compile(
           r"(?<=[a-z])(" + "|".join(re.escape(w) for w in _CAPITALIZED_UK) + r")(?![a-z])"
       )

   `scan_file` now runs both patterns and tracks reported spans on a
   per-line basis so a standalone `Cancelled` after a lowercase letter
   isn't reported twice. The original pattern is unchanged — no
   regression risk for the standalone-word case.

2. **`_us_spelling.py` — path-based skip.** Mirroring the existing
   `_should_skip_path_for_i18n_tooling` helper, `_should_skip_plans_history`
   exempts files under `plans/history/**`. Archived plan docs are
   dated, frozen prose — re-policing them blocks publishes for
   spellings that were already merged and add no risk to shipped
   content. Active plan docs under `plans/` (non-history) are still
   scanned.

3. **`bin/project_vibrancy.dart` — class rename.** `_ScanCancelled` was
   a private file-scope sentinel exception used solely to propagate
   user-initiated scan cancellation out of `runProjectVibrancy` into
   the CLI's `try`/`on` block. Rename has no external surface impact:
   the type is not exported, not in `library` directives, not in any
   test, and has no JSON/proto/marshalling tie to its name.

4. **API-name suppressions.** Two real Dart files reference the
   British spelling `isCancelled` deliberately: the lint rule that
   matches BOTH spellings in user code (it has to, because user code
   in the wild uses both), and the Flutter mock that emulates Dio's
   `CancelToken.isCancelled` getter. Both lines now carry
   `// cspell:ignore isCancelled` so the audit's CamelCase pass skips
   them. The existing scanner skips any line containing the literal
   `cspell` (case-insensitive) — this is the project's existing
   escape-hatch convention.

### Tests

**4A. Existing-test audit.** Grepped `test/` for all symbols touched:
`_ScanCancelled`, `_ScanCanceled`, `isCancelled`, `isCanceled`,
`_us_spelling`, `UK_TO_US`, `_UK_PATTERN`, `scan_directory`,
`SpellingHit`, `project_vibrancy`, `cancelTokenCancellation`,
`api_network_rules`, `CancelToken`. **No existing test references any
renamed or modified symbol.** The cancellation test in
`test/cli/project_vibrancy_cli_test.dart` uses its own sentinel type
`_GateAbort` and exercises the `lib/`-layer
`runProjectVibrancy`, not the `bin/` wrapper. The rename in `bin/` is
invisible to all existing tests.

**4B. New tests added.**
`scripts/modules/tests/test_us_spelling.py` (8 cases):

| Test | What it pins |
|---|---|
| `test_standalone_lowercase_word_is_flagged` | Original `\b`-based detection still works for prose `cancelled`. |
| `test_standalone_capitalized_word_is_flagged` | `Cancelled.` at sentence start fires through the word-boundary pass. |
| `test_camelcase_embedded_word_is_flagged` | `_ScanCancelled` is now caught (the case this change exists for). |
| `test_camelcase_with_multiple_uk_words` | `onColourPickedHandleBehaviour` produces two hits (`Colour`, `Behaviour`). |
| `test_leading_underscore_lowercase_is_not_flagged` | `_cancelled` in `RegExp(r'\b_cancelled\b')` stays silent — the `_` before `c` is not a CamelCase boundary. |
| `test_non_dictionary_word_is_not_flagged` | `CancellationToken` stays silent — `cancellation` is dialect-neutral and not in the dictionary. |
| `test_cspell_tag_suppresses_line` | `// cspell:ignore isCancelled` on the line skips the scan. |
| `test_dedup_prevents_same_span_being_reported_twice` | Mixed-case line `Cancelled by ...; the cancelled flag ...` returns exactly two hits, not four. |

Run: `python -m unittest scripts.modules.tests.test_us_spelling` —
8 pass, 0.022s.

**Affected Dart test files.**
`dart test test/cli/project_vibrancy_cli_test.dart test/rules/network/api_network_rules_test.dart --reporter compact`
— 92 pass, no regressions.

**Full audit.** `python d:\tmp\check_spelling.py` against the project
tree: 0 hits.

**`dart analyze`** on touched Dart files: No issues found.

### Maintenance docs

- `CHANGELOG.md` — added Maintenance bullet under `[13.11.0]`. Entry
  follows the existing template (no user-visible behavior change, no
  required action), and carries an HTML `cspell:ignore` tag so the
  bullet's own example identifiers (`_ScanCancelled`, `OnColourPicked`)
  don't trip the audit they describe.
- `README.md` — verified, no updates needed. Rule count and quick-fix
  count unchanged; no new lint rule.
- `pubspec.yaml` / `pubspec.lock` — NOT touched by this task. The
  uncommitted 13.10.5 → 13.11.0 bump in working tree is another
  workstream's release prep, not part of this change.
- Roadmap — no lint rules added or completed.
- `guides reviewed` — no user-facing product change.
- Bug archival — `No bug archive — task did not close a bugs/*.md file`.

### Persistence

`Finish report saved: plans/history/2026.05/2026.05.26/us_spelling_audit_camelcase.md`
(this file).

### Outstanding work

None. The audit gate is now positively-tested, the originally-reported
hits are closed, and the latent class-name British spelling that the
audit missed is also fixed.
