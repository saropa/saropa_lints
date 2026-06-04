# BUG: `avoid_missing_enum_constant_in_map` — false positive on intentionally-sparse maps whose reads are null-handled (or iterate-only)

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-03
Rule: `avoid_missing_enum_constant_in_map`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (class `AvoidMissingEnumConstantInMapRule`, line ~143; reports at line ~204)
Severity: Medium — fires on a deliberate, safe data pattern (sparse lookup tables), forcing either a `// ignore:` workaround or noise-padding the map with zero-valued entries. High friction in data-heavy files (one project file has ~16 such maps).
Rule version: v3 | Since: ≤ v13.11.11 | Updated: —

---

## Summary

`avoid_missing_enum_constant_in_map` flags any enum-keyed map literal that omits some constants. It decides purely from the **literal's shape** and never considers how the map is **read**. For an intentionally-sparse lookup table — where absence of a key is a meaningful default and the read site handles the missing value safely — the rule's stated harm ("silently returns null for the missing key… unexpected null values or fallback behavior at runtime") cannot occur. Flagging those maps is a false positive.

Two safe read patterns this rule wrongly flags:
- **Iterate-only:** the map is consumed via `.entries` / `.values` / `.keys` / `.forEach` and never indexed by an enum key. A "missing key returns null" event is structurally impossible.
- **Null-handled keyed read:** the map IS indexed, but the result is nullable-typed and explicitly null-checked (`final int? x = m[k]; if (x != null) …` / `m[k] ?? default`). The "unexpected null" is expected and handled.

---

## Attribution Evidence

```text
# Rule IS defined here
lib\src\rules\code_quality\code_quality_variables_rules.dart:147:    'avoid_missing_enum_constant_in_map',
# Reported via reporter.atNode(node) on the SetOrMapLiteral
lib\src\rules\code_quality\code_quality_variables_rules.dart:204:        reporter.atNode(node);
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:143` (`AvoidMissingEnumConstantInMapRule`), registered in `lib/src/rules/all_rules.dart`.
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart`, owner `_generated_diagnostic_collection_name_#2`, code `avoid_missing_enum_constant_in_map`.

---

## Reproducer

```dart
enum Species { dog, cat, fish, snake, turtle }

class AnswerOption {
  const AnswerOption(this.affinities);
  final Map<Species, int> affinities;
}

// Sub-pattern A — ITERATE-ONLY. The sparse map is only ever walked via
// .entries; no key lookup ever happens, so "missing key -> null" cannot
// occur. Rule still LINTS the literal. FALSE POSITIVE.
const AnswerOption severeAllergy = AnswerOption(<Species, int>{
  Species.fish: 3,
  Species.snake: 3,
  Species.turtle: 3,
}); // LINT fires here — but should NOT.

int tally(Iterable<AnswerOption> picks) {
  int total = 0;
  for (final AnswerOption o in picks) {
    for (final MapEntry<Species, int> e in o.affinities.entries) {
      total += e.value; // absent species simply never appear
    }
  }
  return total;
}

// Sub-pattern B — NULL-HANDLED KEYED READ. The map is indexed, but the
// result is nullable-typed and null-checked; absence is the documented
// "no cap" default. Rule LINTS the literal. FALSE POSITIVE.
const Map<Species, int> caps = <Species, int>{
  Species.dog: 10,
  Species.cat: 5,
}; // LINT fires here — but should NOT.

bool overCap(Species s, int n) {
  final int? cap = caps[s];        // nullable by design
  return cap != null && n > cap;   // null == "no cap", handled
}
```

**Frequency:** Always, for any enum-keyed map literal missing ≥1 constant — regardless of read safety.

Real-world sites (downstream `saropa/contacts`):
- `lib/data/contact/pet_quiz_lifestyle_data.dart` and `pet_quiz_routine_data.dart` — ~16 sparse affinity maps, all consumed iterate-only by `lib/utils/contact/pet/pet_quiz_scoring_utils.dart:35-38` (`affinities.entries`).
- `lib/views/home/home_tab.dart:1353` (`_capByScope`) — read at line 1801 as `final int? cap = _capByScope[scope];` then `cap != null`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the map is a deliberate sparse table and its reads are null-safe (iterate-only, or nullable-typed + null-checked / `?? default`). |
| **Actual** | `[avoid_missing_enum_constant_in_map]` reported on every enum-keyed literal missing a constant, irrespective of how the map is read. |

---

## AST Context

The rule registers `addSetOrMapLiteral` and reports the literal itself; it inspects only the literal's own keys vs. the enum's constants. It does not look at the enclosing `VariableDeclaration` / argument, the declared value type, or any read site.

```
AnswerOption(<Species,int>{...})           ← argument; rule never inspects
  └─ SetOrMapLiteral <Species,int>{...}    ← node reported here (keys-vs-constants only)
```

The read that determines safety lives in a *different declaration* (often a different file: the affinity literals are in `*_data.dart`, the iteration is in `*_scoring_utils.dart`). A single-file literal-shape check has no visibility into it.

---

## Root Cause

The detection (`runWithReporter`, `code_quality_variables_rules.dart:167-206`) computes `missing = allConstants.difference(usedConstants)` and reports whenever `missing.isNotEmpty`. There is no consideration of:

1. Whether the map is ever indexed by key vs. only iterated.
2. Whether keyed reads are null-handled (nullable result type + null check / `??`).
3. Whether the map is a deliberate sparse weight/lookup table where absence is a defined default.

So the rule equates "incomplete enum map" with "latent silent-null bug," but the two are independent: an incomplete map is only risky if something does an *unhandled* keyed read. The rule fires on shape alone.

---

## Suggested Fix

This is a genuine FP, but be explicit about feasibility — the maintainer owns the trade-off:

- **Hard to auto-detect in general.** The risky read is usually cross-file (literal in a data file, read in a utils/view file). A single-file AST rule cannot prove the read is null-safe, so it cannot reliably auto-suppress sub-pattern A/B at the literal.
- **Cheapest, most reliable remedy: a recognized "intentionally sparse" opt-out** that does not depend on read-site analysis. Options, in rough order of preference:
  1. Honor a per-map marker comment the rule already understands (e.g. treat a literal whose nearest leading line comment contains a sentinel like `sparse-enum-map` as intended), OR
  2. Document `// ignore:` as the supported escape hatch AND fix the suppression bug that currently breaks it for doc-commented declarations — see sibling report `infra_ignore_comment_shadowed_by_doc_comment.md` (a `// ignore:` below a `///` doc comment is silently dropped, which is why downstream `_capByScope` still lints despite a correctly-placed ignore).
- **Narrow same-file auto-skip (partial):** when the map is a *local* whose only references in the same function are iteration (`.entries`/`.values`/`.keys`/`.forEach`) with no `[` index, skip it. Catches sub-pattern A only when the literal and its use share a scope — does NOT help the cross-file data-table case, so it is a partial mitigation at best. State this limitation in the rule doc rather than implying full coverage.

Recommendation: prioritize the suppression-bug fix (sibling report) so `// ignore:` becomes a working, honest escape hatch for these sparse tables; treat full auto-detection as out of scope given the cross-file limitation.

---

## Fixture Gap

The fixture should distinguish "incomplete map with unhandled keyed read" (LINT) from "incomplete map that is safe" (NO lint, once an opt-out exists):

1. **Iterate-only sparse map** (`.entries` consumption, no `[` index) — expect NO lint (intended pattern).
2. **Keyed read, nullable + null-checked** (`final int? x = m[k]; if (x != null)`) — expect NO lint.
3. **Keyed read with `?? default`** — expect NO lint.
4. **Keyed read, force-unwrap `m[k]!` on a missing key** — expect LINT (this is the real bug the rule exists to catch).
5. **Exhaustive map** — expect NO lint (control; already covered by `avoid_missing_enum_constant_in_map_false_positive_complete_maps.md`).

Until an opt-out lands, at minimum add cases 4 and 5 to lock the true-positive vs. complete-map boundary, and record cases 1–3 as known-FP fixtures.

---

## Changes Made

Resolution: the rule cannot prove cross-file read safety from the literal's
shape alone (confirmed in Root Cause / Suggested Fix), so the remedy is the
now-working `// ignore:` escape hatch plus honest in-rule documentation. Full
auto-detection is out of scope.

`lib/src/rules/code_quality/code_quality_variables_rules.dart`
(`AvoidMissingEnumConstantInMapRule`):
- Replaced the rule's dartdoc, which had been copy-pasted from the unrelated
  `Completer.completeError` rule (wrong Bad/Good examples), with correct
  enum-map examples describing the actual silent-null harm.
- Added an **Intentionally-sparse tables** section documenting the supported
  escape hatch: a verified `// ignore: avoid_missing_enum_constant_in_map` on
  the line directly above the declaration, with a one-line reason. States the
  cross-file limitation explicitly rather than implying the rule can detect
  read safety.

The escape hatch is only honest because the sibling suppression bug is fixed:
`infra_ignore_comment_shadowed_by_doc_comment.md` (Status: Fixed) corrected
`IgnoreUtils.hasIgnoreComment` to probe `firstTokenAfterCommentAndMetadata`, so
`// ignore:` is now honored even when the declaration carries a `///` doc
comment (the real-world `_capByScope` case).

Not implemented (deliberately): the narrow same-file iterate-only auto-skip
floated in Suggested Fix. It catches sub-pattern A only when the literal and
its iteration share a function scope — which none of the reported real-world
sites do (affinity literals live in `*_data.dart`, read in
`*_scoring_utils.dart`; `_capByScope` is read in a different method). It would
add AST-walk complexity and regression risk for a case the reports do not hit,
so the escape hatch is the complete remedy here.

---

## Tests Added

`example/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart`:
- Added `_sparseWeights` — an intentionally-sparse enum-keyed map suppressed
  via `// ignore: avoid_missing_enum_constant_in_map`, documenting the escape
  hatch (expect NO lint). The existing `_incompleteColorMap` /
  `_incompleteStatusMap` cases (expect LINT) and the complete-map controls lock
  the true-positive vs. complete-map boundary.

Note: this rule needs enum type resolution, so the standalone `scan` CLI
(unresolved ASTs) cannot exercise it and CI does not run fixtures — the fixture
is documentation of intended behavior. The suppression path itself is covered
by executable unit tests in `test/utils/ignore_utils_test.dart` (added by the
sibling fix).

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.11.11 (path/published parity; downstream `contacts` pins `^13.11.11`)
- Dart SDK version: 3.12.0 (stable)
- custom_lint version: n/a — runs as a native `analysis_server_plugin`
- Triggering project/files: `saropa/contacts` — `lib/data/contact/pet_quiz_lifestyle_data.dart`, `pet_quiz_routine_data.dart` (iterate-only, read in `lib/utils/contact/pet/pet_quiz_scoring_utils.dart`); `lib/views/home/home_tab.dart:1353` (`_capByScope`, null-handled keyed read at line 1801).

---

## Related

- `infra_ignore_comment_shadowed_by_doc_comment.md` — the `// ignore:` suppression bug that prevented the documented escape hatch from working for doc-commented declarations (e.g. `_capByScope`). Fixed in commit `6ad47bbc` and archived under `plans/history/2026.06/2026.06.03/`.

---

## Finish Report (2026-06-03)



### Scope
(A) Dart lint rules / analyzer plugin — dartdoc on an existing rule plus its `example/` fixture, CHANGELOG, and this bug file. No rule logic, tier, severity, message, or registration changed.

### What changed and why
The rule's silent-null harm only occurs on an *unhandled keyed read* (`map[key]`). The reported false positives are intentionally-sparse lookup tables whose reads are null-safe and live in a different file, so a single-file literal-shape rule cannot prove the read is safe — confirmed in Root Cause / AST Context above. Full auto-detection is therefore out of scope (the bug report's own recommendation). The remedy is the now-working `// ignore:` escape hatch (sibling fix `6ad47bbc` made it honor doc-commented declarations) plus honest documentation.

- `lib/src/rules/code_quality/code_quality_variables_rules.dart` — replaced the rule's dartdoc, which had been copy-pasted verbatim from the unrelated `Completer.completeError` rule (wrong Bad/Good examples), with correct enum-map examples and an **Intentionally-sparse tables** section documenting the verified-`// ignore:` escape hatch and the cross-file detection limit. No code path changed.
- `example/lib/code_quality/avoid_missing_enum_constant_in_map_fixture.dart` — added `_sparseWeights`, a sparse enum-keyed map suppressed via `// ignore:`, documenting the escape hatch alongside the existing true-positive (`_incompleteColorMap`, `_incompleteStatusMap` → LINT) and complete-map controls.
- `CHANGELOG.md` — one bullet under `[Unreleased] ### Fixed`.

### Deliberately not done
The narrow same-file iterate-only auto-skip floated in Suggested Fix. It catches sub-pattern A only when the literal and its iteration share one function scope — which **none** of the reported real-world sites do (affinity literals in `*_data.dart` are read in `*_scoring_utils.dart`; `_capByScope` is read in a different method). It would add AST-walk complexity and regression risk for a case the reports never hit, so the escape hatch is the complete remedy.

### Testing
- `dart test test/rules/code_quality/code_quality_rules_test.dart` → All 208 tests passed. The rule's test is an instantiation/registration pin (class + code name); dartdoc/fixture edits cannot break it. Audited: this is the only test file referencing the rule.
- The suppression path my doc relies on is covered by `test/utils/ignore_utils_test.dart` (added by sibling commit `6ad47bbc`).
- This rule needs enum type resolution, so the standalone `scan` CLI (unresolved ASTs) cannot exercise it and CI does not run fixtures — the fixture is documentation of intended behavior, not an executable assertion.

### Reviewer notes
- No tier / `LintImpact` / severity / message change → `tiers.dart` untouched, registration untouched.
- README rule/doc counts unchanged (no rule added) — README verified, no update needed.
- ROADMAP: no entry for this rule (grep clean); no change.
