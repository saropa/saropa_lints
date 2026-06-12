# BUG: `prefer_no_commented_out_code` — fires on the last line of a wrapped prose comment that ends a sentence with `word.`

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-12
Rule: `prefer_no_commented_out_code`
File: `lib/src/comment_utils.dart` (line ~51, `codePattern` first alternative) — emitted by `lib/src/rules/stylistic/stylistic_rules.dart` (`AvoidCommentedOutCodeRule`, line ~4447)
Severity: False positive
Rule version: v5 | Since: — | Updated: —

---

## Summary

A multi-line **prose** comment whose final wrapped line is a single word ending a sentence with a period — e.g. `// result.` — is flagged as commented-out code. The `.` after the word is a sentence terminator, but `codePattern` reads `result.` as member access (`identifier` + `.`).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "prefer_no_commented_out_code" lib/src/rules/
lib/src/rules/stylistic/stylistic_rules.dart:4486:    'prefer_no_commented_out_code',

# Detection helper:
$ grep -rn "isLikelyCode|codePattern" lib/src/comment_utils.dart
lib/src/comment_utils.dart:47:  static final RegExp codePattern = RegExp(
lib/src/comment_utils.dart:111:  static bool isLikelyCode(String? content) {

# Negative — rule is NOT in sibling repos (owner label was the generic
# "_generated_diagnostic_collection_name_#1", so siblings were ruled out)
$ grep -rn "prefer_no_commented_out_code" ../saropa-drift-advisor/ ../saropa-drift-viewer/
# 0 matches
```

**Emitter registration:** `lib/src/rules/stylistic/stylistic_rules.dart:4486` (`_code`)
**Rule class:** `AvoidCommentedOutCodeRule` — registered in `lib/saropa_lints.dart:541`
**Detection logic:** `CommentPatterns.isLikelyCode` → `codePattern` in `lib/src/comment_utils.dart:47`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#1`

---

## Reproducer

Minimal:

```dart
// Dart ints are 64-bit, so the shift chain MUST reach 32: stopping at 16 (the
// 32-bit recipe) leaves inputs above 2^32 with an unfilled high half and a wrong
// result.                                  // LINT — but should NOT lint (prose)
int x = 0;
```

The flagged line in the wild (`saropa_dart_utils`, `lib/num/num_more_extensions.dart:146-149`):

```dart
  // Smear the highest set bit down into every lower bit, then add 1. Dart ints
  // are 64-bit, so the shift chain MUST reach 32: stopping at 16 (the 32-bit
  // recipe) leaves inputs above 2^32 with an unfilled high half and a wrong
  // result.                                // LINT fires on column 3-13 here
```

Even simpler:

```dart
// result.        // LINT — should be OK (any single lowercase word + period)
// value.         // LINT — should be OK
// done.          // LINT — should be OK
```

**Frequency:** Always, when a prose sentence wraps such that its last physical
line is a single identifier-shaped word followed by a period (very common with
auto-wrapped block comments).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `result.` is the tail of an English sentence, not code |
| **Actual** | `[prefer_no_commented_out_code] Commented-out code clutters the codebase…` reported at the `// result.` line |

---

## Root Cause

`codePattern` (lib/src/comment_utils.dart:47) first alternative:

```
r'^[a-zA-Z_$][a-zA-Z0-9_$]*[\.\(\[\{]|'
```

This matches `identifier` immediately followed by one of `. ( [ {`. The intent
(per the doc at line 28) is to catch member access / calls / indexing:
`foo.bar`, `foo(`, `foo[`. But the `.` branch matches `result.` where the dot is
a **sentence-ending period** with nothing after it.

Why the prose guard does not save it: `_isLikelyProse` (line 197) requires
`words.length >= 3` AND 2+ function words. The flagged content is the single
token `result.` — one word — so `_isLikelyProse` returns `false` at the
`words.length < 3` check, and `codePattern.hasMatch('result.')` then returns
`true`.

Key distinction the regex misses: real Dart member access **always has a
selector after the dot** (`foo.bar`, `foo.bar()`). A trailing dot at the end of
the trimmed content is never valid code — it is sentence punctuation.

---

## Suggested Fix

Tighten the `.`-branch of the first alternative so the dot must be followed by an
identifier-start character; leave `(`, `[`, `{` matching bare (those are valid
code openers: `foo(`, `list[`, `obj{...`).

**File:** `lib/src/comment_utils.dart` (line 51)

**Before:**
```dart
// Identifier immediately followed by code punctuation (no space).
r'^[a-zA-Z_$][a-zA-Z0-9_$]*[\.\(\[\{]|'
```

**After:**
```dart
// Identifier immediately followed by code punctuation (no space).
// The dot branch additionally requires a selector after it: `foo.bar` is
// member access, but `result.` (a word ending a wrapped prose sentence with a
// period) is NOT code — a trailing dot with nothing after it is never valid
// Dart. Parens/brackets/braces still match bare (`foo(`, `list[`, `obj{`).
r'^[a-zA-Z_$][a-zA-Z0-9_$]*(?:[\(\[\{]|\.[a-zA-Z_$])|'
```

This keeps every true positive (`foo.bar`, `list.add(item)`, `obj.field = x`)
while dropping `result.`, `value.`, `done.` and similar sentence tails.

Optional belt-and-suspenders (independent of the regex fix): in
`_isLikelyProse`, treat a single trimmed token that ends in `.` / `?` / `!` and
contains no other code punctuation as prose. The regex fix alone is sufficient
for this report.

---

## Fixture Gap

The fixture should include:

1. `// result.` — expect NO lint (single word + sentence period)
2. `// value.` / `// done.` — expect NO lint
3. A 3-line wrapped prose block whose last line is `// result.` — expect NO lint
4. `// foo.bar` — expect LINT (real member access, regression guard)
5. `// list.add(item)` — expect LINT (regression guard)
6. `// obj.field = x` — expect LINT (regression guard)

---

## Environment

- saropa_lints version: (current `lib/` working tree, message tag `{v5}`)
- Triggering project/file: `saropa_dart_utils` — `lib/num/num_more_extensions.dart:149`
- Diagnostic owner: `dart` / `_generated_diagnostic_collection_name_#1`

---

## Fix Applied (2026-06-12) — not yet deployed

Source-level changes are in the working tree; the analyzer plugin has NOT been
rebuilt/deployed, so the `expect_lint` fixture has not been exercised against the
live rule yet.

1. **`lib/src/comment_utils.dart`** (`codePattern`, first alternative) — tightened
   the dot branch to require a selector after the dot:
   - Before: `r'^[a-zA-Z_$][a-zA-Z0-9_$]*[\.\(\[\{]|'`
   - After:  `r'^[a-zA-Z_$][a-zA-Z0-9_$]*(?:[\(\[\{]|\.[a-zA-Z_$])|'`

   `(`, `[`, `{` still match bare (`foo(`, `list[`, `obj{`); only `.` now requires
   an identifier-start char after it, so `result.` / `value.` / `done.` no longer
   match while `foo.bar` / `list.add(item)` / `obj.field = x` still do.

2. **`test/utils/comment_utils_test.dart`** — added unit cases: false-positive
   guards (`result.`, `value.`, `done.` → `isFalse`) and member-access regression
   guards (`foo.bar`, `list.add(item)`, `obj.field = x` → `isTrue`).
   These ran green: `dart test test/utils/comment_utils_test.dart` → All tests
   passed (61).

3. **`example/lib/stylistic/prefer_no_commented_out_code_fixture.dart`** — added
   GOOD (no-lint) examples for the single-word-period tails and a wrapped prose
   block ending in `// result.`. The `expect_lint` fixture verification for these
   requires the rebuilt plugin and is still pending deployment.

### Remaining to verify after deploy
- Rebuild/deploy the analyzer plugin and run the fixture integration so the new
  GOOD examples confirm no diagnostic fires on the live rule.
- Re-check the original wild case (`saropa_dart_utils`
  `lib/num/num_more_extensions.dart:146-149`) shows no diagnostic.

---

## Follow-up: sibling false positive the regex fix does NOT cover

**Status: Fixed** — resolved by the block-level prose evaluation described below
(`_collectBlock` / `_reportBlock` in `AvoidCommentedOutCodeRule`), not by the
trailing-dot regex alone.

The regex fix (`\.[a-zA-Z_$]`) resolves cases where the dot is a sentence
terminator (`result.`, `yearVal. (The…`). It does NOT resolve a prose line that
*references a real API method* by its `identifier.identifier` name, because that
is textually identical to member access.

### Reproducer

`saropa_dart_utils` — `lib/validation/jwt_structure_utils.dart:35-39`:

```dart
    // base64url omits '=' padding, but base64Url.decode requires the length to be
    // a multiple of four — restore the stripped padding before decoding. The
    // outer `% block` keeps this at 0 when the length is already aligned;
    // `block - 0` would otherwise append a spurious full '====' block and make
    // base64Url.decode reject an otherwise-valid token.   // LINT (line 39) — should be OK
```

Verified against the patched `codePattern`:

```
ok    | result.
ok    | yearVal. (The previous year-of-Monday check missed 2025-W53, whose Monday
LINT  | base64Url.decode reject an otherwise-valid token.
```

### Why it still fires

The rule evaluates each `//` line in isolation. Line 39's content is
`base64Url.decode reject an otherwise-valid token.`:

- `codePattern` first alternative matches `base64Url.` + `d` — a real
  member-access shape, so the regex fix correctly leaves it matching.
- `_isLikelyProse` returns `false`: the isolated line has 5 words but only one
  function word (`an`); the guard needs `words.length >= 3` AND 2+ function
  words.

The signal that this is prose lives in the *surrounding lines*, not this one. The
full contiguous comment block (lines 35-39) is overwhelmingly prose (`but`, `the`,
`to`, `before`, `this`, `is`, `when`, `the`, `would`, `otherwise`, `an`, `and`…).

### Suggested fix: evaluate prose across the contiguous comment block

In `AvoidCommentedOutCodeRule.runWithReporter`
(`lib/src/rules/stylistic/stylistic_rules.dart:4495`), the comment-token walk
visits each line comment separately. Gather a run of consecutive single-line
`//` comments (chained via `commentToken.next`, on adjacent lines with no code
between) into one block, join their content, and if
`_isLikelyProse(joinedBlock)` is true, skip every line in the block.

This robustly covers all three cases (the trailing-dot ones AND the in-prose API
reference) because each is a wrapped line of a larger prose block. A per-line
regex can never distinguish `base64Url.decode` in prose from real member access;
only block-level context can.

Alternative (weaker): lower the prose threshold to 1 function word when the line
has 4+ words. Rejected — too aggressive; it would create false negatives on
genuine short commented-out code like `obj.field = value; // an old default`.

### Fixture Gap (follow-up)

7. A contiguous prose block whose middle/last line references an API as
   `identifier.method` (e.g. `// make base64Url.decode reject the token.`) —
   expect NO lint on any line of the block
8. A genuine commented-out member-access statement standing alone
   (`// foo.bar();`) — expect LINT (regression guard, must still fire)

---

## Finish Report (2026-06-12)

### What changed

`prefer_no_commented_out_code` mistook two shapes of wrapped natural-language
prose for commented-out code:

1. A sentence that wrapped such that its final physical line was a single
   identifier-shaped word followed by a sentence period (`// result.`).
2. A prose line that named a real API method mid-sentence
   (`// base64Url.decode reject an otherwise-valid token.`), textually
   identical to member access.

Both stem from the rule evaluating each `//` line in isolation, where the
prose signal that disambiguates the line lives in the surrounding lines.

Two coordinated changes fix this:

- **`lib/src/comment_utils.dart`** — the `codePattern` regex first alternative
  tightened its dot branch from `[\.\(\[\{]` to `(?:[\(\[\{]|\.[a-zA-Z_$])`, so
  a trailing dot with nothing after it (sentence punctuation) no longer reads
  as member access, while `(` / `[` / `{` still match bare. Two heuristics used
  internally by `isLikelyCode` — prose detection and strong-code detection —
  were promoted to public static methods (`isLikelyProse`,
  `hasStrongCodeIndicators`) so the rule can judge a joined block of lines, not
  just one line.

- **`lib/src/rules/stylistic/stylistic_rules.dart`** —
  `AvoidCommentedOutCodeRule` now gathers each maximal run of consecutive
  single-line `//` comments into one block (`_collectBlock`), evaluates the
  joined block for prose (`_reportBlock` / `_joinBlockContent`), and when the
  block is prose suppresses every line except those that are unambiguously code
  on their own (the strong-code carve-out). A dead-code statement embedded in a
  prose comment is excluded from the prose vote so it cannot drag the block's
  signal down and un-skip its genuinely-prose siblings; it is still flagged
  individually. A line-number gap or a doc/block comment ends a run.

### Why this approach

A per-line regex can never separate `base64Url.decode` in prose from real
member access — the two are textually identical. Only block-level context
distinguishes them. The regex tightening alone resolves the trailing-dot class;
the block-level evaluation resolves the in-prose API-reference class and
subsumes the trailing-dot class as a special case (each is a wrapped line of a
larger prose block).

### Verification

- `dart test test/utils/comment_utils_test.dart` → All tests passed (67),
  including new false-positive guards (`result.`, `value.`, `done.` → not code),
  member-access regression guards (`foo.bar`, `list.add(item)`, `obj.field = x`
  → code), the joined-block `base64Url.decode` reproducer (→ prose), the
  isolated-line counterpart (→ not prose), and the strong-code-indicator cases.
- Fixture GOOD examples added in
  `example/lib/stylistic/prefer_no_commented_out_code_fixture.dart` for the
  single-word-period tails, a wrapped block ending in `// result.`, and the
  contiguous prose block referencing `base64Url.decode`.
- The rule's name, code, severity, and registration are unchanged, so the
  instantiation/registration pins in `stylistic_rules_test.dart` and the
  integrity suites remain valid.

### Not yet verified

The live-plugin fixture integration (`expect_lint` run against the rebuilt
analyzer plugin) has not been exercised; the project's scan CLI does not resolve
files outside a package, so it gave no usable signal on the fixture. The unit
tests exercise the detection logic directly and are the authoritative check.
The original wild case (`saropa_dart_utils`
`lib/num/num_more_extensions.dart:146-149`, and
`lib/validation/jwt_structure_utils.dart:35-39`) should be re-checked in-IDE
after the next plugin rebuild.

Finish report appended: bugs/prefer_no_commented_out_code_false_positive_wrapped_prose_ending_in_identifier_period.md (archived path below).
