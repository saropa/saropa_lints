# INFRA: US-spelling dictionary misses 22 common British words

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-12
Type: Infrastructure (coverage gap)
Component: `scripts/modules/_us_spelling.py` — `UK_TO_US` dictionary
Severity: Medium (silent misses — British spellings in these words pass every gate)

---

## Summary

The `UK_TO_US` dictionary that backs every American-English gate (publish
audit, git pre-commit hook, Claude write-time hook — all via the shared
`scan_paths`/`scan_file` in `_us_spelling.py`) is missing 22 common British
spellings. Any of these words can land in source and slip through all three
gates, because a word the dictionary does not know about is not a hit. This is
the "for coverage" follow-up to the 2026-06-12 enforcement work
([[british_english_recurrence_attempts]]): the gates are now early and
non-bypassable, but they only catch words the list contains.

---

## Missing words (verified 2026-06-12)

Cross-checked against the global American-English banned list. Present in the
banned list, absent from `UK_TO_US`:

```
realise, analyse, paralyse, capitalise, labelled, labelling, travelled,
fuelled, practise, dialogue, aluminium, whilst, amongst, spelt, dreamt,
burnt, leapt, aeroplane, kerb, tyre, plough, storey
```

22 words. Notable: `dialogue` is missing even though `catalogue` and
`analogue` are present (the `-ogue → -og` group is incomplete); `realise`,
`analyse`, `capitalise` are missing from the `-ise/-yse` group; `labelled` /
`travelled` / `fuelled` are missing from the doubled-consonant group (the
`-ing` forms `travelling` exist but not the `-ed` forms).

Reproduce:

```bash
PYTHONUTF8=1 py -3 -c "from scripts.modules._us_spelling import UK_TO_US; \
banned=['realise','analyse','paralyse','capitalise','labelled','labelling',\
'travelled','fuelled','practise','dialogue','aluminium','whilst','amongst',\
'spelt','dreamt','burnt','leapt','aeroplane','kerb','tyre','plough','storey']; \
print([w for w in banned if w not in UK_TO_US])"
```

---

## Suggested Fix

Add the 22 entries to the appropriate groups in `UK_TO_US`
(`scripts/modules/_us_spelling.py`, around lines 43–107). Mind the existing
`_initialize_spellings()` auto-derivation: it already generates `-s`, and for
`-ise`/`-our` stems the `-ed`/`-ing`/`-r` forms — so adding the base `realise`
also yields `realised`/`realising`. For doubled-consonant words the derivation
does NOT expand tense forms, so `labelled` and `labelling` must both be listed
explicitly (as `cancelled`/`cancelling` already are).

Caution on false positives for the dialect-overlapping ones:
- `practise` (verb) vs `practice` (noun) — both spellings are valid English
  depending on part of speech; flagging `practise → practice` is correct for
  American English but verify it does not over-fire in prose.
- `storey` (building floor) vs `story` — only the floor sense is British;
  acceptable since the US form `story` covers both.
- `kerb`/`tyre`/`plough` are unambiguous and safe.

After adding, extend `scripts/modules/tests/test_us_spelling.py` with a
positive case for at least the previously-missed groups (`dialogue`,
`realise`, `labelled`) so the gap cannot silently reopen.

---

## Source-of-truth note

When the consumer-facing lint rule lands
([[feature_lint_rule_prefer_us_english_spelling]]), this same list must be the
single source both the Python audit and the Dart rule consume. Widening it
here first means the rule ships complete rather than re-deriving a second,
drifting copy.

---

## Changes Made

### `scripts/modules/_us_spelling.py`

- Added all 22 missing words to the `UK_TO_US` literal, grouped by spelling
  pattern. The `-yse` verbs (`analyse`/`paralyse`) have their `-ed`/`-ing`
  forms listed explicitly because the auto-derivation only expands `-ise`.
- Added post-derivation overrides: `storeys` → `stories` (the blunt `+s`
  rule would produce `storys`), and `pop()` of `analyses`/`paralyses` so the
  correct American noun plurals are not mis-flagged.

### `scripts/modules/tests/test_us_spelling.py`

- Added 7 tests: positive cases for the previously-missed groups
  (`dialogue`, `realise`, derived `realised`, `labelled`), the unambiguous
  verb `analysed`, and the two ambiguity guards (`analyses` stays silent,
  `storeys` maps to `stories`).

## Tests

`python -m unittest scripts.modules.tests.test_us_spelling` — 21 pass.
Coverage check confirms all 22 words resolve and `analyses`/`paralyses` are
absent from the dictionary.

## Environment

- saropa_lints version: 13.12.6 (in progress)
- File: `scripts/modules/_us_spelling.py`
- Tests: `scripts/modules/tests/test_us_spelling.py`

---

## Finish Report (2026-06-12)

### Scope

(C) developer tooling — the American-English spelling dictionary and its
tests. No analyzer-plugin logic, no shipped rule behavior. Bundled in the
same commit: the write-time and commit-time American-English enforcement
that this coverage work completes (a git pre-commit hook, a Claude editor
hook, and removal of the publish gate's bypass), plus the eight British
spellings that the old publish-only gate let reach `lib/` rule docstrings
and lint messages.

### What changed and why

The American-English gate is only as complete as the word list behind it.
The `UK_TO_US` dictionary in `scripts/modules/_us_spelling.py` was missing
22 common British spellings, so any of them could pass every gate
unnoticed — including `dialogue` while the rest of the `-ogue` group was
present, and the entire `-yse` verb family. All 22 were added, grouped by
spelling pattern.

Two derivation hazards were handled. The module auto-derives inflected
forms, but only expands `-ise` stems, so the `-yse` verbs (`analyse`,
`paralyse`) carry their `-ed`/`-ing` forms explicitly. The blunt `+s` rule
also produces two wrong results: it would turn the British `storeys` into
`storys` (corrected to `stories` by a post-derivation override), and it
would map `analyses`/`paralyses` to the `-yze` form even though those are
the correct American plurals of `analysis`/`paralysis` — those derived
entries are removed so valid American text is not mis-flagged.

### Enforcement context (bundled)

Enforcement moved from publish-time-only to three layers: a Claude
`PostToolUse` hook scans each edited file as it is written, a git
`pre-commit` hook scans staged files and blocks the commit, and the
publish gate no longer offers an "ignore and ship" choice. All three reuse
one scanner entry point (`scan_paths`) over the single `UK_TO_US`
dictionary. The recurrence history is recorded in
`bugs/british_english_recurrence_attempts.md`.

### Verification

`python -m unittest scripts.modules.tests.test_us_spelling` — 21 pass
(7 added: positive cases for `dialogue`, `realise`, the derived `realised`,
and `labelled`; the unambiguous verb `analysed`; and the two ambiguity
guards proving `analyses` stays silent and `storeys` maps to `stories`).
A coverage check confirms all 22 words resolve and that
`analyses`/`paralyses` are absent from the dictionary. A full-tree scan of
the repository reports zero British spellings.

### Outstanding

A consumer-facing lint rule that exposes this same check to downstream
projects is tracked separately in
`bugs/feature_lint_rule_prefer_us_english_spelling.md`. When it lands, the
`UK_TO_US` list must remain the single source both the Python audit and the
Dart rule consume.
