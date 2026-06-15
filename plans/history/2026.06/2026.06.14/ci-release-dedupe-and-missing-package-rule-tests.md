# CI release-commit dedupe + six missing package-rule tests

Cutting a release pushed the `Release vX.Y.Z` commit to `main` and the matching `vX.Y.Z` tag in the same step, so three workflows fired at once on the v14.0.0 release: the `ci` run (on the branch push), `publish` (on the tag), and `announce-release` (on the GitHub Release). The `ci` run failed while the other two succeeded, because its tier-integrity step asserted `144 != 150` — six rule categories existed under `lib/src/rules/packages/` with no corresponding test file, and a regression guard requires every category to carry one. Adding those tests surfaced a second, pre-existing defect: three of the six rules shipped diagnostic messages of 124–128 characters, below the project's documented 200-character minimum that every other rule meets.

## Finish Report (2026-06-14)

### Scope

- **(A)** Dart lint rules / analyzer plugin — six new `test/rules/packages/*_rules_test.dart` files; three `lib/src/rules/packages/*_rules.dart` message edits.
- **(C)** docs/scripts — `.github/workflows/ci.yml` dedupe guard; `CHANGELOG.md` entry.

### Section 1 — Critical Note

Stated in chat.

### Section 2 — Scope

Touches (A) and (C). No extension/TypeScript code changed.

### Section 3 — Deep Review

- **Logic & Safety.** The three message edits are string-literal changes only; they preserve the `[code_name]` prefix and the `{v2}` integrity marker and do not alter detection logic. The six test files are instantiation pins — they construct each rule and assert the code-name, message-contract, and fix-presence invariants; no production code paths are exercised beyond construction.
- **Architecture & Adherence.** The new tests mirror the established package-test shape (the `testRule` helper used by `connectivity_plus_rules_test.dart` and peers): a `Rule Instantiation` group plus a `Fix Presence` group. The `Rule Instantiation` group name is required — the metrics scanner keys on that literal marker to credit a category as tested.
- **Linter-Specific Integrity.** No rules were added, moved, or re-tiered; `tiers.dart` and `LintImpact` assignments are unchanged. Fix-presence assertions match each rule's actual `fixGenerators` (`prefer_uuid_v4` has a fix; the other five have none, each with a one-line reason the edit cannot be made mechanically).
- **Workflow guard.** The `ci.yml` job guard reads `github.event.head_commit.message`, which is populated for `push` events; on `pull_request` the guard short-circuits on `github.event_name != 'push'`, so PR CI is never affected. The release commit is independently validated by `publish.yml` (analyze + test + dry-run on the identical tagged commit) and by the local publish script, which mirrors the full gate before tagging — so skipping the redundant main-push run drops no coverage.

### Section 4 — Testing Validation

**A. Existing-test audit.** Grep of `test/` for the seven affected rule codes returned two pre-existing files beyond the six new ones:
- `test/rules/packages/package_specific_rules_test.dart` — pins `problemMessage.length` `greaterThan(50)` and `contains('[code]')`. The expanded messages (now 200+ chars) still satisfy both; no assertion breaks.
- `test/integrity/false_positive_fixes_test.dart` — no content match for the three edited codes (matched a different code in the grep alternation); unaffected.

**B. New tests.** Six instantiation-pin files added, one per previously-untested package category, each asserting code-name equality, the `[code]` prefix, the >200-char message length, a non-null correction message, and the correct fix-presence state.

**Runs:**
- `dart test` on the six new files plus `package_specific_rules_test.dart` → 52 tests, all passed.
- `python -m unittest discover -s scripts/modules/tests -t .` → 96 tests, OK (the `144 != 150` failure is resolved; the count now reconciles at 150).
- `dart analyze` on the three edited rule files and six new test files → No issues found.

### Section 5 — Extension Localization

SKIPPED [A-NOT-IN-SCOPE] — no `extension/` user-facing code changed.

### Section 6 — Project Maintenance & Tracking

- CHANGELOG updated under `[Unreleased]`: a `### Changed` bullet for the three expanded diagnostic messages (user-visible in the IDE), and two `Maintenance` bullets for the new tests and the CI dedupe.
- README verified — no updates needed (no new rules; rule/fix counts unchanged).
- pubspec / pubspec.lock — not touched (no release or dependency change).
- ROADMAP — no entries to remove (no rules completed or added).
- guides reviewed.
- No bug archive — task did not close a `bugs/*.md` file.

### Section 7 — Persisted Report

Finish report saved: plans/history/2026.06/2026.06.14/ci-release-dedupe-and-missing-package-rule-tests.md

### Diff summary (core changes)

- `lib/src/rules/packages/flutter_keyboard_visibility_rules.dart` — `require_keyboard_visibility_dispose` message expanded to describe the uncanceled subscription firing after dispose, the unmounted-State `setState` throw, and the retained-listener leak.
- `lib/src/rules/packages/openai_rules.dart` — `avoid_openai_key_in_code` message expanded to describe binary extraction of the plain-string key, requests billed to the account, and quota/rate-limit exhaustion until rotation.
- `lib/src/rules/packages/speech_to_text_rules.dart` — `require_speech_stop_on_dispose` message expanded to describe the microphone held after screen close, battery drain, the recording indicator, and other apps blocked from audio.
- `test/rules/packages/{envied,flutter_keyboard_visibility,google_fonts,openai,speech_to_text,uuid}_rules_test.dart` — new instantiation-pin tests.
- `.github/workflows/ci.yml` — each of the three jobs (`analyze`, `test`, `extension-manifest-nls`) gains `if: github.event_name != 'push' || !startsWith(github.event.head_commit.message, 'Release v')`, skipping the redundant main-push run on release commits.
- `CHANGELOG.md` — `[Unreleased]` Changed + Maintenance entries.

### Outstanding work

None. The dedupe guard takes effect on the next release commit; it cannot be exercised until a release is cut, but its expression is validated by YAML parse and by the unaffected PR/normal-push paths.
