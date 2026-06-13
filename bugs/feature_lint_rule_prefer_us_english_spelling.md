# FEATURE: `prefer_us_english_spelling` — flag British spellings in consumer code

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-12
Type: New lint rule (feature request)
Proposed rule: `prefer_us_english_spelling`
Proposed tier: Pedantic (opt-in / stylistic — American English is a style choice consumers opt into)
Severity (proposed): INFO

---

## Summary

`saropa_lints` enforces American English on its *own* source via the publish
audit and the new write/commit-time hooks, but ships no lint rule that lets a
**consumer** project enforce US English in *their* code. A
`prefer_us_english_spelling` rule would flag British spellings in Dart
comments, doc comments, and string literals live in the IDE — the same
coverage the internal `scripts/modules/_us_spelling.py` checker gives this
repo, exposed as a rule for downstream users who want the same standard.

This was deferred out of the 2026-06-12 enforcement work
([[british_english_recurrence_attempts]]) because shipping detection to every
consumer is a product-feature decision, not an internal-tooling fix.

---

## Motivation

- Teams that standardize on US English (a common house style) currently have
  no in-editor enforcement; cSpell catches some but is not a `dart analyze`
  gate and is not part of the lint config consumers already adopt.
- The detection logic already exists and is battle-tested in Python
  (`UK_TO_US` dictionary + whole-word + CamelCase passes). A Dart port reuses
  the same word list as the single source of truth.

---

## Scope / Design questions to settle before building

1. **What does it scan?** Comments + doc comments + string literals are the
   safe set. Identifiers (CamelCase embeds like `colourPicker`) are higher
   value but higher false-positive risk (e.g. a field mirroring a third-party
   British API name). Recommend: comments + strings on by default; an
   `includeIdentifiers` option off by default.
2. **String-literal exemptions.** Must skip URLs, import URIs, and references
   to real Flutter/Dart API names that are British (`Colors.grey`, a quoted
   `'grey'` shade lookup) — the Python checker already special-cases `grey`.
3. **Dictionary as source of truth.** The Dart rule and the Python audit must
   share ONE word list, not two drifting copies. Decide how: generate a Dart
   map from `UK_TO_US` at build time, or move the canonical list to a shared
   data file both consume. (Blocked-by/related: [[infra_us_spelling_dictionary_coverage_gaps]] —
   widen the list first so the rule ships complete.)
4. **Quick fix.** Replace the British spelling with the US form, preserving
   case (`Colour` → `Color`). The Python `_preserve_case` logic is the model.
   Must NOT fire inside `// cspell` / `// ignore` exempted lines.
5. **Tier placement.** Pedantic/opt-in: US English is a preference, not a
   correctness or security issue, so it must not land in Essential/Recommended.

---

## Suggested Fix (implementation sketch)

- New rule in `lib/src/rules/stylistic/` (or `lib/src/rules/documentation/`).
- Register in `lib/saropa_lints.dart` `_allRuleFactories` and add to the
  Pedantic/stylistic set in `lib/src/tiers.dart`.
- Reuse the canonical UK→US word list (see source-of-truth decision above).
- Quick fix: case-preserving replacement; skip cspell/ignore lines.
- Fixture in `example/lib/` with BAD (British in comment/string) + OK (US,
  British API name reference, URL) cases; unit test pinning detection + fix.

---

## Fixture Gap

New fixture `example/lib/stylistic/prefer_us_english_spelling_fixture.dart`:

1. `// User cancelled the dialog` — expect LINT (comment)
2. `final msg = 'Saved your colour';` — expect LINT (string literal)
3. `Colors.grey.shade200` — expect NO lint (Flutter API name)
4. `// see https://en.wikipedia.org/wiki/Colour` — expect NO lint (URL)
5. `final color = 'blue';` — expect NO lint (already US)

---

## Environment

- saropa_lints version: 13.12.6 (in progress)
- Related internal tooling: `scripts/modules/_us_spelling.py`,
  `scripts/hooks/spelling_guard.py`
