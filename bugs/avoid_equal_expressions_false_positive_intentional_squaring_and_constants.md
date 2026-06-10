# BUG: `avoid_equal_expressions` — Intentional Squaring and Binary-Unit Constants

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_equal_expressions`
File: `lib/src/rules/data/equality_rules.dart` (line ~56)
Severity: Medium — false positive on correct mathematical expressions; forces `// ignore:` workaround
Rule version: v6 | Since: v0.1.4 | Updated: v13.12.1

---

## Summary

The rule fires on binary expressions where both operands are textually identical.
The rule's own doc comment and `LintCode` message (line ~57) explicitly state that arithmetic
operators (`*`, `+`, etc.) are excluded because `N op N` is a routine legitimate value — `x * x`
(squaring), `1024.0 * 1024.0` (1 MiB), `60 * 60` (seconds per hour). The `flaggableOps` set
(line ~75) correctly omits `TokenType.STAR`. Despite this documented exclusion, `// ignore:`
workarounds were applied in Saropa Contacts on 2026-06-09, indicating that the rule was firing
on these patterns at the time against the installed plugin version. This report records the false
positive for tracking purposes, identifies the exact detection condition involved, and provides
fixture cases to prevent regression if the `flaggableOps` set is ever widened.
Worked around with `// ignore: avoid_equal_expressions` on 2026-06-09.

---

## Attribution Evidence

Attribution confirmed by the parent session before this report was filed (positive grep performed
by the calling agent). The rule is defined in `saropa_lints` at the location below. Because the
diagnostic owner is the analysis-server plugin (`_generated_diagnostic_collection_name_#N`) rather
than a sibling repo such as `saropa_drift_advisor`, negative attribution grep is not required.

```
# Positive — rule IS defined here
grep -rn "'avoid_equal_expressions'" lib/src/rules/
# Result:
lib/src/rules/data/equality_rules.dart:56: 'avoid_equal_expressions',
```

**Emitter registration:** `lib/src/rules/data/equality_rules.dart:56`
**Rule class:** `AvoidEqualExpressionsRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

```dart
// Intentional squaring — area of a square side
final double area = side * side;              // LINT reported — but intentional square

// Binary-unit constant — bytes per mebibyte
const double bytesPerMiB = 1024.0 * 1024.0;  // LINT reported — intentional binary-unit constant

// Euclidean distance squared
final double distSq = dx * dx + dy * dy;      // LINT reported on dx*dx — correct geometry formula
```

**Frequency:** Always — fires whenever the multiplication operator has identical left and right
operands (single identifier or numeric literal on both sides).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — arithmetic operators with identical operands are explicitly excluded by the rule's design (`flaggableOps` does not include `TokenType.STAR`) |
| **Actual** | `[avoid_equal_expressions] Both sides of a comparison or logical binary expression are identical...` reported on `side * side`, `1024.0 * 1024.0`, and `dx * dx` |

---

## AST Context

For `side * side`:

```
VariableDeclarationStatement
  └─ VariableDeclarationList
      └─ VariableDeclaration (area)
          └─ BinaryExpression                  ← node reported here
              ├─ SimpleIdentifier (side)        ← leftOperand, toSource() == "side"
              ├─ Token (*)                      ← operator, type == TokenType.STAR
              └─ SimpleIdentifier (side)        ← rightOperand, toSource() == "side"
```

For `1024.0 * 1024.0`:

```
VariableDeclarationStatement
  └─ VariableDeclarationList
      └─ VariableDeclaration (bytesPerMiB)
          └─ BinaryExpression                  ← node reported here
              ├─ DoubleLiteral (1024.0)         ← leftOperand, toSource() == "1024.0"
              ├─ Token (*)                      ← operator, type == TokenType.STAR
              └─ DoubleLiteral (1024.0)         ← rightOperand, toSource() == "1024.0"
```

---

## Root Cause

The detection logic is in `AvoidEqualExpressionsRule.runWithReporter` (line ~64).

The rule registers for `BinaryExpression` nodes via `context.addBinaryExpression`. For each node
it evaluates two conditions:

1. `flaggableOps.contains(node.operator.type)` (line ~84) — rejects arithmetic and `!=` operators.
2. `leftSource == rightSource` (line ~89) — reports when both operand sources are identical.

The `flaggableOps` set (lines ~75-83) is:

```dart
const Set<TokenType> flaggableOps = <TokenType>{
  TokenType.EQ_EQ,
  TokenType.GT,
  TokenType.LT,
  TokenType.GT_EQ,
  TokenType.LT_EQ,
  TokenType.AMPERSAND_AMPERSAND,
  TokenType.BAR_BAR,
};
```

`TokenType.STAR` (multiplication) is **absent** from this set. The early-return guard
`if (!flaggableOps.contains(node.operator.type)) return;` at line ~84 should therefore prevent
any `*` expression from reaching the `reporter.atNode` call.

The false positive implies one of the following was true at the time the `// ignore:` workarounds
were applied:

**Hypothesis A — Plugin version mismatch.** The installed plugin (IDE / analysis server cache)
was running an older version of the rule (pre-v6, before the arithmetic exclusion was added).
The `flaggableOps` guard or the doc-comment exemption may have been added at or between v4 and v6
(the version history shows "Updated: v13.12.1" at the rule class header). If the analysis server
was running a cached older binary, the arithmetic exclusion would not be active.

**Hypothesis B — `STAR` inadvertently included in an intermediate commit.** A version of
`flaggableOps` between v4 and v6 may have briefly included `TokenType.STAR`, causing the false
positive, then removed it. The `// ignore:` workarounds were added against that intermediate
version and have not been reviewed since.

**Hypothesis C — `toSource()` mismatch for complex sub-expressions.** For expressions like
`dx * dx + dy * dy`, the outer `+` node's operands are `dx * dx` and `dy * dy`. The `+` operator
(`TokenType.PLUS`) is not in `flaggableOps`, so the outer node is skipped. But the inner `dx * dx`
node IS a `BinaryExpression` with `STAR`; it should also be skipped. If `STAR` was transiently
in `flaggableOps`, both inner `*` nodes would fire. This is consistent with Hypothesis A/B.

The current rule source at v6 / v13.12.1 correctly excludes arithmetic. The `// ignore:`
workarounds applied on 2026-06-09 may be stale if the plugin version in Saropa Contacts was
updated between the workaround application and this report. This should be verified by removing
the ignores and running `dart analyze`; if no diagnostic fires the ignores are vestigial and
should be removed.

---

## Suggested Fix

The current `flaggableOps` implementation at v6 is the correct fix. Verify that:

1. No intermediate version of `flaggableOps` between v4 and v6 inadvertently included
   `TokenType.STAR`, `TokenType.PLUS`, or other arithmetic tokens.
2. The rule's `CHANGELOG` / commit history explicitly records when arithmetic exclusion was
   added (to help downstream consumers know which plugin version first behaves correctly).
3. If arithmetic operators ARE re-added to `flaggableOps` in a future version for any reason
   (e.g., flagging `x || x` and accidentally including `x + x`), the fixture cases below
   must block the regression.

If the workarounds in Saropa Contacts are verified to be stale (the diagnostic no longer fires at
the current plugin version), they should be removed and this report closed.

---

## Fixture Gap

The fixture at `example*/lib/data/avoid_equal_expressions_fixture.dart` should include explicit
`// OK` cases for the arithmetic patterns that the rule intentionally exempts:

1. **Single-identifier squaring** — expect NO lint.
   ```dart
   final double area = side * side;          // OK — intentional square
   ```

2. **Numeric-literal binary-unit constant** — expect NO lint.
   ```dart
   const double mib = 1024.0 * 1024.0;      // OK — binary-unit constant
   ```

3. **Euclidean distance formula** — expect NO lint on the inner `*` nodes.
   ```dart
   final double distSq = dx * dx + dy * dy; // OK — correct geometry
   ```

4. **Squaring inside a larger expression** — expect NO lint.
   ```dart
   final double rms = (a * a + b * b) / 2;  // OK — sum of squares
   ```

5. **Comparison with identical operands** — expect LINT (verifying the positive case still works).
   ```dart
   if (value == value) {}  // LINT — comparison, not arithmetic
   ```

6. **`&&` with identical operands** — expect LINT.
   ```dart
   final bool r = x && x;  // LINT — logical, not arithmetic
   ```

These cases are missing from the current fixture, which means a regression to the false-positive
behavior would not be caught by `dart test` until a downstream project reports it.

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: as used by Saropa Contacts on 2026-06-09
- custom_lint version: n/a (saropa_lints is a native analysis_server plugin)
- Triggering project/file: Saropa Contacts — geometry/math utilities, 2026-06-09
- Workaround applied: `// ignore: avoid_equal_expressions -- intentional squaring / binary-unit constant`
