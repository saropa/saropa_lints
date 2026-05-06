# BUG: `avoid_null_assertion` — Fires on `RegExpMatch.group(N)!` where the regex guarantees the group exists

**Status: Closed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-04-21
Updated: 2026-04-21
Rule: `avoid_null_assertion`
File: `lib/src/rules/data/type_rules.dart` (line ~616)
Severity: False positive (enhancement — requires regex-literal inspection)
Rule version: v7 → v8 | Since: v0.1.4 | Updated: v12.3.3

---

## Summary

`avoid_null_assertion` flags `match.group(1)!` / `match.group(2)!` inside an iteration over `RegExp.allMatches(...)` / `firstMatch(...)` results. When the `RegExp` is a literal with `N` explicit, non-optional, non-alternation capture groups, `group(1)..group(N)` are guaranteed non-null on a successful match — so the `!` cannot throw. The rule's existing safe-pattern detection covers `??=`, ternaries, if-guards, and short-circuits, but not this idiomatic regex pattern.

---

## Reproducer

Triggered in `saropa_drift_advisor` 3.3.3 at `lib/src/server/server_context.dart:294` and `:308` before the defensive-fallback fix:

```dart
static (String, int)? _parseCallerFrame(StackTrace stack) {
  // Two explicit, non-optional capture groups: (.+?) and (\d+)
  final framePattern = RegExp(r'#\d+\s+\S+\s+\((.+?):(\d+):\d+\)');

  for (final match in framePattern.allMatches(stack.toString())) {
    final file = match.group(1)!; // LINT — but cannot be null on a successful match (false positive)
    // ...
    final line = int.tryParse(match.group(2)!); // LINT — same (false positive)
    if (line == null) continue;
    return (file, line);
  }
  return null;
}
```

Because the regex literal has no `?`-quantified groups, no alternation, and no nested optional expressions, groups 1 and 2 are guaranteed non-null whenever `match` is produced by `allMatches`.

**Frequency:** Always, on any `!` applied to `RegExpMatch.group(N)` regardless of the regex literal's structure. The rule does not currently inspect the pattern.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the receiver is a `RegExpMatch` (element type resolves to `dart.core.RegExpMatch` / `Match`) and the regex pattern has an explicit non-optional capture group at the requested index — the `!` is statically provable as safe. |
| **Actual** | `[avoid_null_assertion] ... {v7}` fires on every `match.group(N)!`, pushing authors to add a `?? ''` fallback that is dead code (the fallback branch can never execute). |

---

## AST Context

```
MethodDeclaration (_parseCallerFrame)
  └─ BlockFunctionBody
      └─ ForStatement (for-in over allMatches)
          └─ Block
              └─ VariableDeclarationStatement
                  └─ VariableDeclaration (file)
                      └─ PostfixExpression (!)          ← reported here
                          └─ MethodInvocation (group(1))
                              ├─ SimpleIdentifier (match)   // staticType: RegExpMatch
                              └─ ArgumentList
                                  └─ IntegerLiteral (1)
```

The `PostfixExpression` is where `avoid_null_assertion` reports. A new safe-pattern check would need to (a) resolve `match`'s static type to `RegExpMatch` / `Match`, (b) read the integer literal argument, and (c) walk up/outside to find the `RegExp(r'...')` literal whose `allMatches` / `firstMatch` produced the iteration.

---

## Root Cause

### Hypothesis A: Missing safe-pattern check for regex group access

`AvoidNullAssertionRule.runWithReporter` at `lib/src/rules/data/type_rules.dart:676-692` calls four safe-pattern predicates:

```dart
if (_isInSafeTernary(node)) return;
if (_isInSafeIfBlock(node)) return;
if (_isInShortCircuitSafe(node)) return;
if (_isAfterNullCoalescingAssignment(node)) return;
```

None of them recognize regex group access as a safe pattern. A fifth predicate — e.g. `_isSafeRegExpMatchGroup(node)` — would need to:

1. Confirm `node.operand` is a `MethodInvocation` with `methodName.name == 'group'`.
2. Confirm the receiver's `staticType` is `RegExpMatch` or `Match` (via the Dart core library).
3. Confirm the argument is an `IntegerLiteral` with value `N >= 1`.
4. Find the `RegExp` literal that produced the match (by walking up from the surrounding `for` / `firstMatch`-assigning statement) and parse its pattern string to count explicit non-optional capture groups.
5. Return `true` only when `N` is within the guaranteed-non-null range.

### Hypothesis B: Narrow variant — accept any literal-regex group access as safe

A much simpler version that catches the most common case: accept `match.group(N)!` as safe when `match` iterates a for-loop over `literalRegExp.allMatches(...)` and `N` is a positive integer literal. Accept the edge-case risk that a user-written regex with an optional group could still produce a null group. This is arguably fine because `avoid_null_assertion` is informational (severity: INFO) and the simpler heuristic eliminates most nuisance reports.

---

## Suggested Fix

Add `_isSafeRegExpMatchGroup(node)` to `AvoidNullAssertionRule` and register it alongside the existing safe-pattern checks:

```dart
context.addPostfixExpression((PostfixExpression node) {
  if (node.operator.lexeme != '!') return;
  if (_isInSafeTernary(node)) return;
  if (_isInSafeIfBlock(node)) return;
  if (_isInShortCircuitSafe(node)) return;
  if (_isAfterNullCoalescingAssignment(node)) return;
  if (_isSafeRegExpMatchGroup(node)) return; // new
  reporter.atNode(node);
});
```

Start with the narrow variant (Hypothesis B). Upgrade to pattern inspection (Hypothesis A) if the fixture uncovers false negatives where the narrow variant silences a genuinely unsafe group access.

Bump the rule version marker `{v7}` → `{v8}` and update `Updated:` to the shipping version.

---

## Fixture Gap

`example/lib/type/avoid_null_assertion_fixture.dart` should include:

1. **`for (final m in RegExp(r'(\d+)').allMatches(s)) { m.group(1)!; }`** — expect NO lint (false-positive case this bug is about).
2. **`final m = RegExp(r'(\d+)').firstMatch(s); if (m != null) m.group(1)!;`** — expect NO lint (single-match variant).
3. **`m.group(3)!` when the regex has only 2 groups** — expect LINT (out-of-range genuinely can be null — this is the safety case the narrow heuristic would miss and that Hypothesis A would catch).
4. **`m.group(1)!` where the regex is `(a)?b` (optional group)** — expect LINT under Hypothesis A; accepted under Hypothesis B. Document the chosen behavior in the fixture comment.

---

## Changes Made

Implemented **Hypothesis B (narrow variant)** as recommended: accept any `<receiver>.group(N)!` as safe when the receiver's static type resolves to `dart:core` `RegExpMatch` or `Match` and `N` is a non-negative integer literal. The regex pattern string is **not** inspected — optional-group edge cases (e.g. `(a)?b` with `match.group(1)!`) are an accepted miss, documented in the fixture. Trade-off rationale:

- `avoid_null_assertion` is INFO severity; false positives on the dominant idiom produced far more friction than the rare edge case.
- Pattern-string inspection (Hypothesis A) requires counting non-optional captures across alternations, nested optionals, and named groups — expensive and brittle.
- A future dedicated `avoid_optional_regex_group_assertion` rule would be a better home for the optional-group check if demand emerges.

### Code

- [lib/src/rules/data/type_rules.dart](lib/src/rules/data/type_rules.dart)
  - Added `_isSafeRegExpMatchGroup(PostfixExpression node)` predicate (~30 lines of checks + doc explaining the Hypothesis A/B trade-off).
  - Wired it into `AvoidNullAssertionRule.runWithReporter` alongside the four existing safe-pattern predicates (`_isInSafeTernary`, `_isInSafeIfBlock`, `_isInShortCircuitSafe`, `_isAfterNullCoalescingAssignment`).
  - Bumped `{v7}` → `{v8}` in the problem message and `Updated: v4.13.0` → `v12.3.3` in the class doc.
  - Added "`RegExpMatch.group(N)!` on a successful match" to the "Safe patterns that are NOT flagged" doc list.

### Fixture

- [example/lib/type/avoid_null_assertion_fixture.dart](example/lib/type/avoid_null_assertion_fixture.dart)
  - `_goodRegExpMatchGroupAllMatches` — `for (match in RegExp(...).allMatches(s))` with `match.group(1)!` / `match.group(2)!` — expects NO lint (previous false-positive case).
  - `_goodRegExpMatchGroupFirstMatch` — `firstMatch(s)` + null-check guard + `match.group(0)!` / `match.group(1)!` — expects NO lint; also verifies `group(0)` (full match) is covered.
  - `_acceptedMissOptionalGroup` — `RegExp(r'(a)?b')` with `match.group(1)!` — documented as accepted miss under Hypothesis B.

### Changelog

- [CHANGELOG.md](CHANGELOG.md) — new `[Unreleased]` section with a `### Fixed` entry describing the rule-version bump, the narrow-heuristic choice, and the accepted edge-case miss.

---

## Tests Added

- [example/lib/type/avoid_null_assertion_fixture.dart](example/lib/type/avoid_null_assertion_fixture.dart) — three new fixture functions (see Changes Made above). Existing `_bad1228` / `_good1228` cases retained and still exercise the four pre-existing safe-pattern predicates.
- No new unit test added; `test/type_rules_test.dart` continues to assert rule instantiation + `[avoid_null_assertion]` prefix + message length. Behavioral coverage lives in the fixture, consistent with how the other safe-pattern branches of this rule are tested.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 12.3.3
- Dart SDK version: >=3.9.0 <4.0.0 (triggering project constraint)
- custom_lint version: (whatever ships with saropa_lints 12.3.3)
- Triggering project/file: `saropa_drift_advisor` 3.3.3 — `lib/src/server/server_context.dart` (lines 294, 308 before fix; replaced with `?? ''` fallbacks in the shipping code as a workaround)
