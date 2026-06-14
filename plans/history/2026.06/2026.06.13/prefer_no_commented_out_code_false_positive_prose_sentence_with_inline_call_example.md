# BUG: `prefer_no_commented_out_code` — fires on a prose sentence that embeds an inline function-call example

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-13
Fixed: 2026-06-13
Rule: `prefer_no_commented_out_code`
File: `lib/src/rules/stylistic/stylistic_rules.dart` (line ~4592, `_reportBlock`)
Severity: False positive
Rule version: v5 | Since: (commented-out-code message {v5}) | Updated: —

---

## Summary

A single prose comment wrapped across three lines is flagged on the one middle
line that happens to contain a function-call **example** (`formatNumberLocale(x, decimalPlaces: 25)`).
The block as a whole is correctly judged prose, but the strong-code carve-out in
`_reportBlock` re-flags that middle line because `_hasStrongCodeIndicators`
matches the inline call. The line is mid-sentence English, not dead code.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'prefer_no_commented_out_code'" lib/src/rules/
# lib/src/rules/stylistic/stylistic_rules.dart:4506:    'prefer_no_commented_out_code',

# Negative — sibling repo only references it as CONFIG, not a definition
grep -rn "prefer_no_commented_out_code" ../saropa_drift_advisor/
# ../saropa_drift_advisor/analysis_options.yaml  (rule toggle only — no rule class)
# ../saropa_drift_advisor/analysis_options_custom.yaml  (rule toggle only)
```

**Emitter registration:** `lib/saropa_lints.dart:540` (`AvoidCommentedOutCodeRule.new`)
**Rule class:** `AvoidCommentedOutCodeRule` — `lib/src/rules/stylistic/stylistic_rules.dart:4467`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#3`

---

## Reproducer

```dart
String formatNumberLocale(num value, {int decimalPlaces = 0}) {
  final String raw = decimalPlaces <= 0
      ? value.round().toString()
      // Clamp to 20: toStringAsFixed throws a RangeError above 20 digits. Without
      // this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in   // LINT (false positive)
      // double_extensions already clamps the same way).
      : value.toStringAsFixed(decimalPlaces.clamp(1, 20));
  return raw;
}
```

The three `//` lines are one English sentence:
"Clamp to 20: toStringAsFixed throws a RangeError above 20 digits. Without this,
`formatNumberLocale(x, decimalPlaces: 25)` crashed (`formatDouble` in
`double_extensions` already clamps the same way)."

Only the middle line is flagged. It begins with the lowercase continuation
"this," and ends with an unclosed "(formatDouble in" — unambiguously a wrapped
prose line, not a statement.

**Frequency:** Always, whenever a wrapped prose comment names a function call
with arguments on a single physical line.

**Real occurrence:** `saropa_dart_utils/lib/num/num_locale_utils.dart:32`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the block is prose; the middle line is a wrapped sentence fragment that merely cites an API call |
| **Actual** | `[prefer_no_commented_out_code]` reported on the middle line |

---

## AST Context

This rule is token-based, not node-based. The relevant unit is the contiguous
`//` comment run (three tokens) attached to the `:` token of the conditional
expression:

```
CompilationUnit
  └─ leading comment chain on a token
      ├─ // Clamp to 20: ... Without                         (prose, not flagged)
      ├─ // this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in   ← reported
      └─ // double_extensions already clamps the same way).  (prose, not flagged)
```

---

## Root Cause

`_reportBlock` (line ~4592) computes `blockIsProse` from the joined block, then
loops each line:

```dart
if (!CommentPatterns.isLikelyCode(content)) continue;
if (blockIsProse && !CommentPatterns.hasStrongCodeIndicators(content)) continue;
reporter.atToken(commentToken);
```

For the middle line, `content` is
`this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in`.

1. `_joinBlockContent` (line ~4618) **excludes** any line with strong code
   indicators from the prose vote, so the middle line is dropped from the join.
   The remaining join (lines 1 + 3) is correctly prose → `blockIsProse == true`.
2. In the per-line loop, `isLikelyCode(content)` is true (the prose guard is
   bypassed because `_hasStrongCodeIndicators` already returned true), and
   `hasStrongCodeIndicators(content)` is true because
   `_functionCallPattern` (`\w\(`) matches `formatNumberLocale(` and the line
   also contains `)`. So the carve-out `!hasStrongCodeIndicators` is `false` and
   the line is **not** skipped → reported.

The strong-code carve-out exists to keep a genuine dead-code statement embedded
inside a prose block flagged. But it cannot distinguish a real statement from a
prose line that merely *mentions* a call. A wrapped prose line that names a
function with arguments trips `_functionCallPattern` + `)` and gets re-flagged
even though the block is prose.

### Hypothesis A: the carve-out needs a prose-continuation guard

When `blockIsProse` is true, a line should only survive the carve-out if it
looks like a *standalone statement*, not a sentence fragment. Signals that this
is prose, not code, on the flagged line:
- starts with a lowercase word that is a prose indicator (`this`, `the`, …) —
  `CommentPatterns.startsWithLowercase` already exists;
- contains multiple prose function words around the call;
- has unbalanced parentheses (`(formatDouble in` has an unclosed `(`), which a
  real statement line would not.

### Hypothesis B: balance check before treating `\w\(` + `)` as strong

`_hasStrongCodeIndicators` treats "an identifier-paren somewhere AND a `)`
somewhere" as a call. Here the `(` and `)` belong to *different* parenthetical
groups (`(x, decimalPlaces: 25)` is closed; `(formatDouble in` is open). A call
detected by `_functionCallPattern` should require its own matching `)` after the
opening paren, not just any `)` on the line.

---

## Suggested Fix

Prefer Hypothesis A as the primary guard (cheapest, targets the real signal):
in `_reportBlock`, when `blockIsProse` is true, additionally skip a line whose
content `CommentPatterns.startsWithLowercase` AND contains ≥2 prose indicators —
i.e. reuse the prose-word count already implemented in `_isLikelyProse` at the
single-line level as a secondary veto on the carve-out. A line that is itself
prose-shaped should not be re-flagged just because it cites a call.

Hypothesis B (paren-balance in `_hasStrongCodeIndicators`) is a complementary
hardening: require the matched call's opening paren to have a later closing
paren *after* it, so `name(... )` counts but `name(...)  text (open` with a
trailing unclosed group does not silently satisfy "contains `)`".

---

## Fixture Gap

The fixture for `prefer_no_commented_out_code` should include:

1. **Wrapped prose sentence citing a call mid-sentence** — expect NO lint:
   ```dart
   // Clamp to 20: toStringAsFixed throws above 20 digits. Without
   // this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in
   // double_extensions already clamps the same way).
   ```
2. **Genuine dead code under a prose lead-in** — expect LINT on the code line
   only (regression guard so the carve-out still works):
   ```dart
   // Old fast path, kept for reference:
   // return value.toStringAsFixed(decimalPlaces);
   ```
3. **Prose line with unbalanced trailing paren** — expect NO lint.

---

## Changes Made

The reproducer had **two** root causes, not the one the report originally
diagnosed. Both were fixed.

1. **Strong-code carve-out re-flagged a prose fragment** (the report's
   Hypothesis A + B, combined). New `CommentPatterns.isWrappedProseFragment`
   in [comment_utils.dart](../lib/src/comment_utils.dart) recognizes a wrapped
   mid-sentence line: it starts with a lowercase continuation word AND either
   carries 2+ English function words OR has unbalanced parentheses (an opening
   paren whose close is on a later physical line). `_reportBlock` in
   [stylistic_rules.dart](../lib/src/rules/stylistic/stylistic_rules.dart#L4592)
   now skips such a line inside a prose block, so a sentence that merely *cites*
   a call is not treated as dead code.

2. **Special-marker regex matched `FIX` as a substring.** The first comment
   line contained `toStringAsFixed`, and the old `specialMarkerPattern` matched
   `FIX` anywhere, so the line was misread as a FIXME marker and dropped from
   the block-level prose vote — leaving `blockIsProse == false`, which defeats
   the carve-out fix above. The pattern now word-bounds every bare-word token
   (`\b(TODO|FIXME|FIX|...)\b`), so markers match only as standalone words.
   This also stopped `prefix`/`suffix`/`fixture`/`affix`/`debugger` from being
   misclassified as markers (a latent defect affecting both rules that use
   `isSpecialMarker`).

Fix 1 alone did not resolve the reproducer; fix 2 was required because the
literal `toStringAsFixed` on the lead-in line suppressed the prose signal.

---

## Tests Added

[test/utils/comment_utils_test.dart](../test/utils/comment_utils_test.dart):

- `CommentPatterns.isWrappedProseFragment` group — the reproducer middle line,
  an unbalanced-paren prose line, and three negative cases (genuine statements
  and a capitalized sentence start) that must NOT be treated as fragments.
- `CommentPatterns.isSpecialMarker` — `FIX` not matched inside
  `toStringAsFixed`/`prefix`/`suffix`/`fixture`/`affix`, `BUG` not matched
  inside `debugger`, standalone `FIX`/`BUG` still matched.

[example/lib/stylistic/prefer_no_commented_out_code_fixture.dart](../example/lib/stylistic/prefer_no_commented_out_code_fixture.dart):
two new GOOD blocks (wrapped sentence citing a call mid-sentence; wrapped line
with a dangling trailing paren) that must NOT trigger.

Verified end-to-end by replicating `_reportBlock`'s decision against the public
`CommentPatterns` API: the reproducer reports no line, while genuine dead code
under a prose lead-in (`return cache.get(key);`, `foo.bar();`) still reports.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.7
- Dart SDK version: 3.12.1 (stable)
- custom_lint version: (transitive via saropa_lints ^13.12.7)
- Triggering project/file: `saropa_dart_utils/lib/num/num_locale_utils.dart:32`

---

## Finish Report (2026-06-13)

### Scope

Dart analyzer-plugin change only. Touched the shared comment-classification
helper and the `prefer_no_commented_out_code` reporting loop, plus their tests,
fixture, and the changelog. No extension, no tier, no rule-registration change.

### What was defective

A wrapped prose comment whose middle physical line cites a function call with
arguments was reported as commented-out code. The reproducer:

```
// Clamp to 20: toStringAsFixed throws a RangeError above 20 digits. Without
// this, formatNumberLocale(x, decimalPlaces: 25) crashed (formatDouble in
// double_extensions already clamps the same way).
```

Only the middle line was flagged, despite being mid-sentence English.

Two independent defects combined to produce it. The bug report identified only
the first; the first fix alone does not resolve the reproducer.

1. **Strong-code carve-out re-flagged a prose fragment.** `_reportBlock` keeps a
   line flagged inside a prose block when it carries "strong" code indicators (a
   call with parentheses, an arrow, or braces). A prose sentence fragment that
   merely names a call (`formatNumberLocale(...)`) satisfies that test and was
   re-flagged.

2. **`specialMarkerPattern` matched marker words as substrings.** The lead-in
   line contains `toStringAsFixed`, and the pattern matched `FIX` anywhere, so
   the line was misread as a FIXME-style marker. Marker lines are excluded from
   the block-level prose vote, so the only remaining prose-voting line fell
   below the prose threshold and `blockIsProse` evaluated `false` — which
   disables the carve-out path entirely, so even a corrected carve-out never
   runs. The same over-match misclassified `prefix`, `suffix`, `fixture`,
   `affix`, and `debugger` everywhere, affecting both rules that consume
   `isSpecialMarker`.

### The fix

In `lib/src/comment_utils.dart`:

- Added `CommentPatterns.isWrappedProseFragment(content)`. It returns true when a
  line begins with a lowercase continuation word AND either carries two or more
  English function words or has unbalanced parentheses (an opening paren whose
  match closes on a later physical line). A genuine one-line statement starts
  with a keyword/identifier, carries no function words, and is paren-balanced, so
  it is not matched.
- Word-bounded the bare-word tokens in `specialMarkerPattern`
  (`\b(TODO|FIXME|FIX|...)\b`), keeping the colon-suffixed directives
  (`ignore:`, `expect_lint:`, etc.) anchored by their trailing colon. Marker
  tokens now match only as whole words.

In `lib/src/rules/stylistic/stylistic_rules.dart`, `_reportBlock` now skips a
line that `isWrappedProseFragment` recognizes when the surrounding block is
prose — a secondary veto on the strong-code carve-out. The veto is gated on
`blockIsProse`, so a genuine commented-out statement under a prose lead-in
(`return cache.get(key);`, `foo.bar();`) still reports.

### Verification

- `dart test test/utils/comment_utils_test.dart` — 78 pass, including new
  `isWrappedProseFragment` cases (the reproducer line, an unbalanced-paren prose
  line, and negative cases for real statements and capitalized sentence starts)
  and new `isSpecialMarker` cases (`FIX` not matched inside
  `toStringAsFixed`/`prefix`/`suffix`/`fixture`/`affix`, `BUG` not inside
  `debugger`, standalone `FIX`/`BUG` still matched).
- `dart test` of the rule-registration, alias, false-positive, quick-fix, and
  defensive-coding suites that reference the rule or the changed symbols — all
  pass; none pinned the changed detection behavior.
- The rule's per-line decision was reproduced against the public
  `CommentPatterns` API: the reproducer reports no line; dead code under a prose
  lead-in still reports; an unbalanced-paren prose line reports nothing.
- `dart analyze` of the changed source and test files — no issues.

The scan CLI's `--tier` path does not load this rule because it lives in
`stylisticRules` (opt-in, not in any tier), so verification used the unit-level
decision replica rather than a tier scan.

### Files changed

- `lib/src/comment_utils.dart` — new `isWrappedProseFragment`; word-bounded
  `specialMarkerPattern`.
- `lib/src/rules/stylistic/stylistic_rules.dart` — prose-fragment veto in
  `_reportBlock`.
- `test/utils/comment_utils_test.dart` — new test groups for both changes.
- `example/lib/stylistic/prefer_no_commented_out_code_fixture.dart` — two GOOD
  blocks (wrapped sentence citing a call; wrapped line with a dangling paren).
- `CHANGELOG.md` — Fixed entry under `[Unreleased]`.

### Outstanding

None. Both defects are fixed and verified.

Finish report appended: bugs/prefer_no_commented_out_code_false_positive_prose_sentence_with_inline_call_example.md (archived path below).
