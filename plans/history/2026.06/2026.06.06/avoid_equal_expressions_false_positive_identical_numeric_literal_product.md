# BUG: `avoid_equal_expressions` — flags intentional identical-literal products like `1024 * 1024`

**Status: Fixed**

Resolution: `runWithReporter` now restricts the identical-operand check to an
allowlist of comparison and logical operators (`==`, `<`, `>`, `<=`, `>=`,
`&&`, `||`); all arithmetic/shift/bitwise operators are skipped. Rule version
bumped v5 → v6. Verified via scan CLI: `1024 * 1024`, `60 * 60`, `x * x`,
`1 << 1`, `n + n` no longer flag; `a == a`, `w > w`, `flag && flag`,
`flag || flag` still flag. Fixture updated; CHANGELOG `[Unreleased]` entry added.

Created: 2026-06-06
Rule: `avoid_equal_expressions`
File: `lib/src/rules/data/equality_rules.dart` (line ~60, `runWithReporter`)
Severity: False positive
Rule version: v5

---

## Summary

`avoid_equal_expressions` fires on ANY binary expression whose left and right
source text are identical — including arithmetic operators. `1024 * 1024`
(1 MiB), `60 * 60` (seconds/hour), `1000 * 1000`, etc. are deliberate constant
expressions, not the copy-paste comparison bug the rule targets, yet each is
reported as a warning.

## Attribution Evidence

Positive — the rule is defined in saropa_lints:

```
$ grep -rn "'avoid_equal_expressions'" lib/src/rules/
lib/src/rules/data/equality_rules.dart:48:    'avoid_equal_expressions',
```

The implementation flags on raw source-text equality with no operator filter
beyond skipping `!=`:

```dart
context.addBinaryExpression((BinaryExpression node) {
  // Skip != as it might be intentional for NaN checks
  if (node.operator.type == TokenType.BANG_EQ) return;
  final String leftSource = node.leftOperand.toSource();
  final String rightSource = node.rightOperand.toSource();
  if (leftSource == rightSource) {
    reporter.atNode(node);
  }
});
```

## Reproducer

```dart
// LINT (false positive) — intentional unit constants
final int oneMebibyte = 1024 * 1024;          // bytes in 1 MiB
final int secondsPerHour = 60 * 60;           // 3600
final bool big = byteCount >= 1024 * 1024;     // inner 1024*1024 flagged

// SHOULD STILL LINT — genuine copy-paste comparison bugs
if (a == a) { }        // always true
if (width > width) { } // always false
if (x && x) { }        // redundant
```

## Expected vs Actual

| Expression | Expected | Actual |
|---|---|---|
| `1024 * 1024` | OK (intentional constant) | LINT |
| `60 * 60` | OK | LINT |
| `a == a` | LINT | LINT |
| `width > width` | LINT | LINT |

## AST Context

```
BinaryExpression  (operator: *)
  leftOperand:  IntegerLiteral 1024
  rightOperand: IntegerLiteral 1024
```

The rule message itself frames the defect around comparison/logical operators
("always produces the same result (true for ==, false for >, <)…copy-paste
bug where the developer intended to compare two different values"), but the
matcher runs on every `BinaryExpression`, so arithmetic operators with equal
literal operands are swept in.

## Root Cause

Source-text equality is the right signal for *comparison* and *logical*
operators (`==`, `>`, `<`, `>=`, `<=`, `&&`, `||`, `&`, `|`, `^`) where two
identical operands are almost always a bug. It is the WRONG signal for
*arithmetic* operators (`*`, `+`, `-`, `/`, `%`, `<<`, `>>`) where `N op N`
is a routine, meaningful value (a square, a doubling, a unit conversion).

## Suggested Fix

Restrict the identical-operand check to the operator classes where it
indicates a bug. Skip arithmetic operators when both operands are numeric
literals (or, more conservatively, skip arithmetic operators entirely — a
self-arithmetic on a *variable* like `x * x` is a legitimate square too):

```dart
context.addBinaryExpression((BinaryExpression node) {
  final TokenType op = node.operator.type;
  if (op == TokenType.BANG_EQ) return;
  // Identical operands are only a defect for comparison/logical operators.
  // Arithmetic (N * N, N + N, …) is a legitimate constant/value.
  const Set<TokenType> flaggableOps = <TokenType>{
    TokenType.EQ_EQ, TokenType.GT, TokenType.LT, TokenType.GT_EQ,
    TokenType.LT_EQ, TokenType.AMPERSAND_AMPERSAND, TokenType.BAR_BAR,
  };
  if (!flaggableOps.contains(op)) return;
  if (node.leftOperand.toSource() == node.rightOperand.toSource()) {
    reporter.atNode(node);
  }
});
```

## Fixture Gap

Add fixtures asserting NO lint for `1024 * 1024`, `60 * 60`, `n + n`,
`x * x`, `1 << 1`, and asserting the lint still fires for `a == a`,
`w > w`, `x && x`, `flag || flag`.

## Affected sites in Saropa Contacts (inline-ignored pending this fix)

- `lib/views/contact/contact_avatar_crop_screen.dart:207` — `bytes >= 1024 * 1024`
- `lib/views/contact/contact_avatar_crop_screen.dart:208` — `bytes / (1024 * 1024)`

## Finish Report (2026-06-06)

This work will be reviewed by another AI.

### Scope
(A) Dart lint rules / analyzer plugin. Single-rule false-positive fix.

### Root cause
`AvoidEqualExpressionsRule.runWithReporter` matched raw source-text equality
on every `BinaryExpression`, skipping only `!=`. Arithmetic operators with
identical operands (`1024 * 1024`, `60 * 60`, `x * x`, `1 << 1`, `n + n`) are
legitimate values, not the copy-paste comparison bug the rule targets.

### Fix
Restricted the matcher to an allowlist of operators where identical operands
are genuinely a defect — comparison (`==`, `<`, `>`, `<=`, `>=`) and logical
(`&&`, `||`). All arithmetic / shift / bitwise operators are now skipped. `!=`
remains excluded (canonical NaN check). Rule version bumped v5 → v6 (problem
message + DartDoc updated to document the operator scoping and the arithmetic
carve-out).

### Files changed
- `lib/src/rules/data/equality_rules.dart` — operator allowlist guard, message
  rewrite, DartDoc update, version v5 → v6.
- `example/lib/equality/avoid_equal_expressions_fixture.dart` — added no-lint
  arithmetic cases (`1024 * 1024`, `60 * 60`, `byteCount >= 1024 * 1024`,
  `byteCount / (1024 * 1024)`, `x * x`, `1 << 1`, `n + n`) and added still-lint
  logical-operator cases (`flag && flag`, `flag || flag`).
- `CHANGELOG.md` — `[Unreleased]` Fixed entry (merged into the shared section).

### Verification
- `dart analyze lib/src/rules/data/equality_rules.dart` → No issues found.
- `dart test test/rules/data/equality_rules_test.dart` → all 31 tests pass.
- Scan CLI (`dart run saropa_lints scan ... --tier comprehensive`) on a
  reproducer: exactly 4 hits — `a == a`, `width > width`, `flag && flag`,
  `flag || flag`; ZERO hits on the 6 arithmetic expressions. Confirms both the
  false-positive removal and that genuine bugs still flag.

### Test note
This repo's `*_test.dart` files are instantiation pins only — there is no
executable `analyzeCode` harness here and CI does not run fixtures, so the
behavioral guarantee lives in the fixture plus the scan-CLI check above. The
existing instantiation test still passes (message still contains the
`[avoid_equal_expressions]` prefix and exceeds the length floor).

### Outstanding
None. `avoid_equal_expressions` is not listed in `ROADMAP.md` (no roadmap edit
needed) and has no README count impact (a fix, not a new rule). `tiers.dart`
assignment unchanged (still in `comprehensive` set).
