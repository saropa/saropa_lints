# FEATURE: `prefer_us_english_spelling` — flag British spellings in consumer code

**Status: Fixed**

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

---

## Finish Report (2026-06-12)

### Scope

(A) Dart analyzer plugin — a new lint rule, its generated data file,
registration, fixture, and unit test.

### What shipped

`prefer_us_english_spelling` is an opt-in stylistic rule that flags British
spellings in Dart comments (line, block, and doc) and in prose string
literals, reporting the exact source span of each offending word at INFO
severity. It lets a downstream project enforce American English in editor
and CI, the same standard the package applies to its own source.

### Design decisions (resolving the open questions above)

- **Scan scope.** Comments and prose string literals only. A string is
  treated as prose only when it contains a space; single-token strings are
  skipped because they are usually identifiers, map keys, enum names, or
  URIs where a British-looking spelling is often an external API contract.
  Identifier scanning was deferred (higher false-positive risk).
- **False-positive guards.** Comments and strings containing a URL (`://`)
  are skipped; comments carrying an existing `ignore` or `cspell` directive
  are skipped; import/export/part URIs are skipped.
- **Single source of truth.** The rule consumes a generated Dart map,
  `lib/src/rules/data/uk_to_us_spellings.dart`, produced from the canonical
  `UK_TO_US` dictionary by `scripts/generate_us_english_rule_data.py`. A
  Python parity test fails the build if the committed Dart file drifts from
  the dictionary, so the rule and the spelling audit cannot diverge.
- **Tier.** Stylistic / opt-in (off by default), because American vs
  British spelling is a house-style preference, not a correctness issue.
- **Quick fix.** Deferred. A reliable case-preserving word replacement
  depends on a fix-producer range API that cannot be runtime-verified in
  this environment, and a mis-targeted replacement would corrupt source.
  Shipping detection without a fix avoids that risk; the fix is tracked as
  remaining work below.

### Files

- `lib/src/rules/stylistic/prefer_us_english_spelling_rule.dart` — the rule.
- `lib/src/rules/data/uk_to_us_spellings.dart` — generated word map.
- `scripts/generate_us_english_rule_data.py` — generator.
- `lib/src/rules/all_rules.dart`, `lib/saropa_lints.dart`,
  `lib/src/tiers.dart` — barrel export, factory, stylistic tier set.
- `example/lib/stylistic/prefer_us_english_spelling_fixture.dart` — fixture.
- `test/rules/stylistic/prefer_us_english_spelling_rule_test.dart` — unit
  test; parity test added to `scripts/modules/tests/test_us_spelling.py`.
- `scripts/modules/_us_spelling.py` — the rule, data, fixture, and test
  files are added to the audit's skip-list (each must contain British forms
  verbatim to do its job).

### Verification

- `dart analyze` on the rule, data, registration, and test files — clean.
- Dart unit test (rule metadata + generated-map spot checks) — 3 pass.
- Python suite incl. the parity guard — 22 pass.
- Registration integrity tests (tier ↔ plugin registry, exampleBad/Good
  pairing) — 30 pass.
- End-to-end via the scan CLI against a sample with British spellings: the
  rule reported 4 hits in a comment (`Initialise`, `colour`, `centre`,
  `dialogue`) and 2 in a prose string (`favourite`, `colour`), and
  correctly did NOT fire on a single-token `'colour'` string or a URL.

### Outstanding

- Quick fix (case-preserving British → American replacement) is not yet
  implemented; tracked here as the sole remaining item for this rule.
- Identifier scanning (e.g. `colourPicker`) remains out of scope by design.
