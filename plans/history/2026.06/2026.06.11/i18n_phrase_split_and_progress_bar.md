# i18n: semicolon/colon phrase splitting + WPM/ETA progress bar

**Triggered by:** While translating Thai (`th`), the NLLB engine logged
`translate_batch timed out > 10s on target='th', input='Run project-wide checks that single-file analysis cannot do: unused files, circu…'; falling back`.
The user asked to (1) split phrases naturally by semicolons and colons, and (2) have
the progress bar report words-per-minute and an ETA. Build tooling only
(`extension/scripts/i18n/`); excluded from the `.vsix`, no pub.dev/Marketplace impact.

## Finish Report (2026-06-11)

### 1. Critical note



### 2. Scope

**(C) docs/scripts only** — Python build tooling under `extension/scripts/i18n/`
(translation pipeline). No Dart lint rules, no analyzer plugin, no TypeScript
webview code touched. LINTER-variant Sections keyed to (A) are marked SKIPPED below.

### 3. Deep review

- **Root cause.** The timed-out string had no sentence terminator (`.!?`) and was
  under the 80-token gate, so it never reached `_translate_via_phrases` (that path
  ran only for over-gate strings). It went straight to a single-shot greedy decode
  that degenerated into repetition on the comma list and burned the full 10s
  deadline before bouncing to Google.
- **Logic & safety.** Added `_has_strong_phrase_boundary()` (semicolon/colon/dash/
  line-break followed by whitespace; bare comma, URL `:`/`.`, and dotted versions
  excluded). `nllb_translate` now pre-splits a terminator-less, strong-boundary
  string before the single-shot call, and the timeout handler clause-splits as a
  last resort. Recursion terminates: each clause re-enters `nllb_translate`; an
  unsplittable clause makes `_split_into_phrases` return `[text]` → `None`.
  An `attempted_phrase_split` flag prevents the over-gate block and the timeout
  handler from re-running the (expensive) clause split that the proactive branch
  already ran for the same null result.
- **Architecture.** Reused the existing `_split_into_phrases` / `_translate_via_phrases`
  machinery — no parallel splitter. The progress concern is split cleanly: the
  prefetch loop owns only the per-string completion signal (`progress(done, total,
  source)`); presentation (bar, WPM, ETA, TTY vs. checkpoint) lives entirely in the
  caller `generate_locales._TranslationProgress`.
- **Performance.** Proactive splitting avoids the 10s-per-string timeout waste that
  would otherwise recur across 24 locales × hundreds of strings. ETA extrapolates
  from string-completion fraction (robust to uneven per-string word counts); WPM is
  reported from the word tally as the operator-requested metric.
- **Linter-specific integrity.** SKIPPED [A-NOT-IN-SCOPE] — no Dart rules, tiers,
  `LintImpact`, or quick fixes involved.
- **Refactoring.** No out-of-scope code smells touched.

### 4. Testing validation

- **A. Existing-test audit.** Grepped `tests/` for every changed symbol
  (`prefetch_machine_translations`, `_translate_via_phrases`, `_split_into_phrases`,
  `nllb_translate`, `progress`). Matches in `test_phrase_split.py`,
  `test_mt_provenance_modes.py`, `test_nllb_engine.py`, `test_nllb_wiring.py`. None
  pinned behavior I changed — `_split_into_phrases`/`_translate_via_phrases` bodies
  are untouched, and `progress` is a new optional parameter (default `None`,
  backward-compatible). All 5 existing files pass unchanged.
- **B. New tests.** Extended `test_phrase_split.py` with `TestStrongPhraseBoundary`
  (colon/semicolon/dash/newline qualify; comma, URL, version do not) and
  `TestSubGateRouting` (a sub-gate colon string routes to the phrase splitter and
  the single-shot path is never called — model stubbed). Added `test_progress.py`
  covering `_fmt_duration` (unknown → `--:--`, mm:ss, h:mm:ss), bar geometry incl.
  zero-total guard, and the prefetch callback firing once per pending string with a
  monotonic `done` (plus the `progress=None` backward-compat path).
- **Run result.** `py -3 tests/test_*.py` — all 6 files pass both with ambient
  `SAROPA_SKIP_NLLB=1` and without it (the routing test neutralizes that env var
  internally). No model loads and no network is touched in any test.
- `py -3 -m py_compile` clean on all three changed scripts.

### 5. Extension l10n validation

SKIPPED [C-NOT-IN-SCOPE] — no `extension/src/` UI code, no `en.json` / `package.nls.json`
source-key changes. This task edits the translation *engine* scripts, which produce
the locale catalogs; it adds no user-facing strings and changes no catalog keys, so
no regeneration is required.

### 6. Project maintenance

- CHANGELOG: added a Maintenance `<details>` bullet under `[Unreleased]` describing
  the sub-gate semicolon/colon splitting and the WPM/ETA progress bar.
- README verified — no updates needed (no rule-count or product-fact change).
- `pubspec` / `pubspec.lock`: unchanged (no release/dependency change).
- Roadmap: no lint entries affected.
- guides reviewed — none describe this internal tooling.
- No bug archive — task did not close a `bugs/*.md` file (originated from a chat-reported timeout).

### 7. Persist finish report

Finish report saved: plans/history/2026.06/2026.06.11/i18n_phrase_split_and_progress_bar.md

### 9. Files changed

- `extension/scripts/i18n/nllb_engine.py` — `_has_strong_phrase_boundary()` +
  `_STRONG_PHRASE_BOUNDARY_RE`; proactive strong-boundary routing and timeout-handler
  clause-split in `nllb_translate`; `attempted_phrase_split` de-dup guard.
- `extension/scripts/i18n/mt_fallback.py` — optional `progress` callback on
  `prefetch_machine_translations`, fired per string; `Callable` import.
- `extension/scripts/i18n/generate_locales.py` — `import time`; `_fmt_duration()`;
  `_TranslationProgress` reporter; wired into the per-locale prefetch call.
- `extension/scripts/i18n/tests/test_phrase_split.py` — strong-boundary + sub-gate
  routing tests.
- `extension/scripts/i18n/tests/test_progress.py` — new test file (formatter, bar,
  prefetch callback).
- `CHANGELOG.md` — Maintenance bullet.
- `plans/history/2026.06/2026.06.11/i18n_phrase_split_and_progress_bar.md` — this report.

### Outstanding work

None functionally. On-device/real-run verification of the live bar rendering and of
the colon-split translation quality is a manual step (see "What to test"); the logic
is unit-verified but the actual NLLB inference path is not exercised by the suite
(by design — the model never loads in tests).
