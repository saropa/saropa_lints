# BUG: `prefer_no_commented_out_code` — fires on a prose sentence that embeds an inline function-call example

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-13
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

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- Fill in when a fix is written. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.7
- Dart SDK version: 3.12.1 (stable)
- custom_lint version: (transitive via saropa_lints ^13.12.7)
- Triggering project/file: `saropa_dart_utils/lib/num/num_locale_utils.dart:32`
