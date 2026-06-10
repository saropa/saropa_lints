# BUG: `avoid_string_substring` — regex-`hasMatch` format guards and loop-index slices flagged as out-of-bounds

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_string_substring`
File: `lib/src/rules/code_quality/code_quality_avoid_rules.dart` (lines ~1030, ~1052, ~1060)
Severity: False positive
Rule version: v3 | Since: (pre-v13) | Updated: v13.12.2

---

## Summary

Three structurally-safe substring patterns the heuristic cannot prove, grouped
here because they share the same shortcoming: the bounds proof exists, but it
lives somewhere the source-text/arg-name heuristic does not look.

1. **Regex format guard.** `if (!pattern.hasMatch(key)) return null;` then
   `key.substring(0, 2)` — the regex `^\d{4}` (etc.) guarantees `key.length >= 2`,
   but the rule has no way to read inside a `RegExp` literal, and the guard
   condition mentions neither a substring arg name (the indices are literals)
   nor a `.length`/`startsWith` on the receiver.

2. **Loop-index slice where the bound is a `.length` arg.** Inside
   `while (i < source.length) { ... source.substring(start, i) }`, the substring
   `(start, i)` is bounded by the loop, but because `i`/`start`/`source.length`
   either aren't both collected (see the property-access bug) or the slice is a
   *post-loop* read of indices the loop computed, the loop-condition heuristic
   does not match.

3. **Cross-function index invariant.** `op.substring(2)` is safe because the
   *caller* gated it behind `if (op.startsWith('X-'))`; `password.substring(i, j + 1)`
   in `_makeBruteforce(int i, int j, String password)` is safe because the
   caller passes match offsets into `password`. `_isGuardedByLengthCheck`
   returns `false` the moment it hits a `FunctionBody` (line 1067–1069), so a
   guarantee one frame up is invisible.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_string_substring'" lib/src/rules/
# => lib/src/rules/code_quality/code_quality_avoid_rules.dart:991:    'avoid_string_substring',

# Negative — not defined in the drift advisor
grep -rn "avoid_string_substring" ../saropa_drift_advisor/lib/src/ ../saropa_drift_advisor/extension/src/
# => 0 matches (config-only toggle in its analysis_options.yaml:108)
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_avoid_rules.dart:974`
**Rule class:** `AvoidSubstringRule` — registered in `lib/saropa_lints.dart:326`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
final RegExp _dateKeyPattern = RegExp(r'^\d{4}$');

// Case 1 — regex format guard guarantees length.
int? monthFromKey(String key) {
  if (!_dateKeyPattern.hasMatch(key)) return null;
  return int.tryParse(key.substring(0, 2)); // LINT — regex guarantees len 4
}

// Case 2 — slice read AFTER a length-bounded while loop.
String readToken(String source, int start) {
  int i = start;
  while (i < source.length && !_isWhitespace(source[i])) {
    i++;
  }
  return source.substring(start, i); // LINT — start <= i <= source.length
}

// Case 3 — cross-function invariant (caller guarantees prefix).
String protocol(String op) => op.substring(2); // LINT — but every caller did `if (op.startsWith('X-'))`
```

**Frequency:** Always, for these three structural patterns. The bounds proof is
real but lives in a regex literal (Case 1), in loop control flow that has
already mutated the index (Case 2), or in the caller (Case 3).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Case 1 & 2: no diagnostic (provably in-bounds). Case 3: arguably a true positive — the safety is an undocumented caller contract the analyzer cannot see. |
| **Actual** | All three flagged with `[avoid_string_substring] substring() throws RangeError ...`. |

---

## AST Context

```
// Case 2 — the slice is a sibling AFTER the WhileStatement, not inside it.
MethodDeclaration (readToken)
  └─ Block
      ├─ VariableDeclarationStatement (int i = start)
      ├─ WhileStatement (i < source.length && ...)   ← guard lives here
      └─ ReturnStatement
          └─ MethodInvocation source.substring(start, i)   ← reported
```

`_isGuardedByLengthCheck` ascends from the `substring` through the `Block`. The
`WhileStatement` is a *preceding sibling*, not an *ancestor*, so the
`current is WhileStatement` branch (line 1052) is never visited for this node.
The loop bounded `i` to `<= source.length`, but that post-condition is not
expressed as an ancestor the walk can see.

---

## Root Cause

- **Case 1 (regex):** `_conditionGuardsLength` (line 1081) and
  `_conditionInvolvesArgs` (line 1108) operate on source text and arg names. A
  `RegExp(r'^\d{4}$').hasMatch(key)` guard contains no `.length`/`startsWith` on
  the receiver and no substring-arg identifier (the indices `0, 2` are
  literals), so neither matcher fires. The rule cannot, in general, prove a
  length lower-bound from a regex without parsing the pattern — this is a known
  hard case.

- **Case 2 (post-loop slice):** the `WhileStatement` handling at line 1052 only
  helps when the substring is *inside* the loop body (the loop is an ancestor).
  A slice taken after the loop reads indices the loop established, but the walk
  sees the loop only as a sibling, never as `current`.

- **Case 3 (cross-function):** lines 1067–1069 deliberately return `false` at a
  `FunctionBody` boundary. Correct for soundness, but it means caller-guaranteed
  invariants (`startsWith('X-')` one frame up; match offsets passed into the
  function) always lint.

---

## Suggested Fix

This report documents three patterns of differing tractability — a single fix
is not appropriate for all three:

- **Case 1 (regex):** out of scope for a cheap heuristic. Recommend recognizing
  a narrow, common shape: an early-exit `if (!<ident>.hasMatch(<receiver>))
  return ...;` immediately preceding the substring, treated as a
  format-validated guard (analogous to the `startsWith` early-exit). This admits
  the developer's clear validation intent without parsing the regex. Lower
  priority — these sites are few and the developers already validated.

- **Case 2 (post-loop slice):** extend `_isGuardedByLengthCheck` so that when a
  substring arg (e.g. `i`) was the loop variable of a *preceding* `WhileStatement`/
  `ForStatement` sibling whose condition bounds it against the receiver's
  `.length`, the slice is treated as guarded. Requires looking at preceding
  siblings in the enclosing `Block`, similar to `_hasPrecedingEarlyExitGuard`.

- **Case 3 (cross-function):** genuinely not provable intra-procedurally; keep
  the `FunctionBody` short-circuit. These remain true positives by the rule's
  definition — recommend the downstream code add a defensive length check or an
  `// ignore:` with rationale rather than changing the rule.

---

## Fixture Gap

The fixture should include:

1. `if (!pattern.hasMatch(key)) return null;` then `key.substring(0, 2)` — desired **NO** lint (if Case 1 fix adopted).
2. `while (i < s.length) i++;` then `s.substring(start, i)` — desired **NO** lint (Case 2 fix).
3. `op.substring(2)` with no in-function guard — expect **LINT** (Case 3 stays a true positive; documents the boundary).

---

## Notes on flagged sites

- `wikimedia_date_key_utils.dart:62` / `:76` — Case 1 (regex `_dateKeyPattern` guard).
- `common_colored_json.dart:137` — Case 2, slice inside a `while (i < source.length)` body (`source.substring(start, i)`).
- `common_colored_json.dart:202` / `:214` — Case 2, post-loop slice (`source.substring(openingQuoteIndex, i)` / `(start, i)` after the bounding while).
- `vcard_import_utils.dart:963` (`op.substring(2)`) — Case 3, caller-guaranteed `startsWith('X-')`. **True positive by the rule's definition** (cross-function); listed for completeness.
- `zxcvbn_scoring.dart:212` (`password.substring(i, j + 1)`) — Case 3, vendored zxcvbn password-strength library; `i`/`j` are match offsets passed in by the caller. **True positive by the rule's definition** (cross-function), safe in the vendored code's contract. The vendored zxcvbn slices (`zxcvbn_matching.dart:247`, `:493–495`) are covered by the property-access-args bug report instead, since those fail on arg collection rather than function boundary.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: >=3.9.0 <4.0.0
- analyzer: >=9.0.0 <13.0.0
- Triggering project/file: `d:\src\contacts` — `lib/service/wikimedia/wikimedia_date_key_utils.dart:62`, `:76`, `lib/components/primitive/json/common_colored_json.dart:137`, `:202`, `:214`, `lib/database/file_backup/import/vcard_import_utils.dart:963`, `lib/utils/zxcvbn/src/zxcvbn_scoring.dart:212`
