# Task: `avoid_js_rounded_ints`

## Summary
- **Rule Name**: `avoid_js_rounded_ints`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Web Compatibility

## Problem Statement
JavaScript (and by extension, Dart compiled to JavaScript via `dart2js` or the DDC compiler used in Flutter Web) uses IEEE 754 double-precision floating-point for all numeric values. Unlike the Dart VM which has a true 64-bit integer type, JavaScript has no native integer type.

IEEE 754 double-precision can exactly represent integers only up to 2^53 = 9,007,199,254,740,992. Beyond this threshold — called the "JavaScript safe integer limit" — integers are rounded to the nearest representable double. The error may be silent: the integer literal appears valid in Dart, compiles without error, but at runtime on the web the value is silently wrong.

For example:
```dart
const bigId = 9999999999999999; // 10^16 — exceeds 2^53
```

On the Dart VM: `bigId` is exactly `9999999999999999`.
On Flutter Web: `bigId` is `10000000000000000` (silently rounded up by 1).

This is a real source of data corruption bugs in Flutter Web applications that handle large IDs (database primary keys, financial amounts, cryptographic values, Unix timestamps in microseconds).

The fix is to use `BigInt` for large integers that must be exact, `String` for IDs that happen to be large numbers (UUIDs stored as integer-like strings), or `double` when approximate representation is acceptable.

## Description (from ROADMAP)
Flag integer literals in Dart code that exceed `9007199254740992` (2^53, the JavaScript safe integer maximum), as these values will be silently rounded when the code is compiled to JavaScript for web targets, potentially causing data corruption or logic errors.

## Trigger Conditions
The rule triggers when:
1. An `IntegerLiteral` is found in source code.
2. The literal's value exceeds `9007199254740992` (2^53).
3. The code is not inside a `dart:io` or VM-only import guard.

It does NOT trigger when:
- The value is at or below `9007199254740992`.
- The literal is in a file under `lib/native/`, `lib/vm/`, or in a conditional import block for native-only code.
- The literal is annotated with a suppression comment.
- The literal appears in a test file testing the exact boundary condition.

## Implementation Approach

### AST Visitor
```dart
context.registry.addIntegerLiteral((node) {
  _checkIntegerLiteral(node, reporter);
});
```

### Detection Logic

**Step 1 — Get the literal value:**

```dart
const _jsSafeMax = 9007199254740992; // 2^53

void _checkIntegerLiteral(IntegerLiteral node, ErrorReporter reporter) {
  final value = node.value;

  // node.value is null for literals that overflow Dart's int (> 2^63-1)
  // Those are already a compile error in VM mode, handle separately
  if (value == null) return;

  if (value > _jsSafeMax) {
    reporter.atNode(node, code);
  }
}
```

**Step 2 — Handle negative literals:**

Negative integer literals in Dart are represented as a `PrefixExpression` with `-` operator and a positive `IntegerLiteral` operand. The rule should check the parent:

```dart
void _checkIntegerLiteral(IntegerLiteral node, ErrorReporter reporter) {
  final value = node.value;
  if (value == null) return;

  // For negative literals: the actual value is -(node.value)
  // The safe range is -2^53 to 2^53
  final parent = node.parent;
  final effectiveValue = (parent is PrefixExpression &&
          parent.operator.type == TokenType.MINUS)
      ? -value
      : value;

  if (effectiveValue.abs() > _jsSafeMax) {
    // Report on the parent prefix expression if negative
    if (parent is PrefixExpression) {
      reporter.atNode(parent, code);
    } else {
      reporter.atNode(node, code);
    }
  }
}
```

**Step 3 — Detect web-relevant context (optional, reduces false positives):**

If the file contains `dart:io` import and no web-specific imports, the code may be VM-only. Conversely, if the file imports `dart:html`, `package:flutter/foundation.dart`, or similar, it is likely web-relevant.

For simplicity and safety, report on ALL files by default — the developer can suppress for VM-only files. Document this in the correctionMessage.

**Step 4 — Handle hexadecimal literals:**

Hexadecimal integer literals (e.g., `0xFFFFFFFFFFFFFFFF`) also resolve to `IntegerLiteral` nodes. The `node.value` property already returns the numeric value regardless of representation. No special handling needed.

**Step 5 — Detect arithmetic expressions that could exceed the limit (advanced, optional):**

Simple binary arithmetic on near-limit values (`_jsSafeMax ~/ 2 * 3`) could overflow, but detecting this requires constant folding or flow analysis. Defer this to a future enhancement. Focus the initial implementation on literal values only.

## Code Examples

### Bad (triggers rule)
```dart
// Large integer IDs — common source of web bugs
const userId = 9999999999999999;       // LINT — exceeds 2^53
const transactionId = 10000000000000001; // LINT

// Database auto-increment IDs in large-scale systems
class Invoice {
  final int id;               // May hold values > 2^53 at runtime — not caught here
  static const int maxId = 18446744073709551615; // LINT — far exceeds 2^53
}

// Timestamp in microseconds
const epoch2030 = 1893456000000000; // LINT — microsecond precision for 2030-01-01

// Financial amounts in smallest unit (e.g., satoshis for Bitcoin)
const totalSatoshis = 21000000 * 100000000; // = 2.1 * 10^15, LINT
```

### Good (compliant)
```dart
// Use BigInt for exact large integer representation
final userId = BigInt.parse('9999999999999999');

// Use String for IDs that are purely nominal (no arithmetic performed)
const transactionId = '10000000000000001';

// Use double for approximate values where precision loss is acceptable
const approximateValue = 9.999999999999999e15;

// Values below the safe limit are fine
const safeId = 9007199254740992;     // OK — exactly at the limit
const smallId = 1234567890;          // OK — well within safe range

// Conditional import pattern for VM-only code
// In a file that's only ever compiled for native targets:
const vmOnlyConstant = 9999999999999999; // OK if suppressed appropriately
// ignore: avoid_js_rounded_ints — VM-only code, never compiled to JS
```

## Edge Cases & False Positives
- **VM-only code**: Code in `lib/src/native/`, `bin/`, or files only imported under `dart:io` conditional imports will never run on JavaScript. The rule cannot determine compile target from the source alone, so it will report on these files. The `// ignore:` escape hatch is the solution.
- **Constants evaluated at compile time**: Dart constant folding may produce a large value from smaller constants: `const result = 9007199254740993 - 1;` — the computed constant is `9007199254740992`, which is safe. But the literal `9007199254740993` would trigger the rule. Consider whether to report on the literal or the computed constant.
- **Negative integers**: `-9999999999999999` is also unsafe. The rule checks the parent `PrefixExpression` for the minus sign. Ensure the check covers this case.
- **Hexadecimal literals**: `0x1FFFFFFFFFFFFF` = `9007199254740991` (2^53 - 1, safe). `0x20000000000000` = `9007199254740992` (exactly 2^53, safe). `0x20000000000001` triggers. The node.value check works for hex literals.
- **Double literals that are integer-valued**: `9.007199254740993e15` is not an `IntegerLiteral` — it is a `DoubleLiteral`. This rule only covers `IntegerLiteral`. Double literals are inherently approximate and a separate concern.
- **Test files**: Test assertions that check exact large integer values are valid and should not be flagged. Consider excluding test files, or at least documenting that test files should use `// ignore:`.
- **`BigInt` operations**: `BigInt.from(9999999999999999)` — even though 9999999999999999 appears as an `IntegerLiteral` argument, the `BigInt.from()` constructor will receive the already-rounded value on JavaScript. Use `BigInt.parse('9999999999999999')` instead. The rule cannot detect the `BigInt.from(largeInt)` anti-pattern without type analysis of the parent context — this is a potential enhancement.

## Unit Tests

### Should Trigger (violations)
```dart
// Literals exceeding 2^53
const a = 9007199254740993;          // LINT — 2^53 + 1
const b = 9999999999999999;          // LINT — far above limit
const c = 18446744073709551615;      // LINT — max uint64
const d = 10000000000000000;         // LINT — 10^16

// Hex equivalents
const e = 0x20000000000001;          // LINT — exceeds 2^53
```

### Should NOT Trigger (compliant)
```dart
// Safe integer literals (at or below 2^53)
const safe1 = 9007199254740992;      // OK — exactly 2^53
const safe2 = 9007199254740991;      // OK — 2^53 - 1
const safe3 = 1000000000;            // OK — 10^9
const safe4 = 0;                     // OK
const safe5 = -9007199254740992;     // OK — -2^53

// Double literal — not an IntegerLiteral, not checked
const d = 9.999999999999999e15;      // OK — DoubleLiteral

// BigInt.parse — correct approach
final big = BigInt.parse('9999999999999999'); // OK
```

## Quick Fix
Suggest two alternative representations depending on use case:

**Option 1 — Replace with `BigInt.parse('...')`:**
```dart
// Before: const bigId = 9999999999999999;
// After:  final bigId = BigInt.parse('9999999999999999');
```

**Option 2 — Replace with a string literal:**
```dart
// Before: const userId = 9999999999999999;
// After:  const userId = '9999999999999999';
```

Since the appropriate fix depends on usage (arithmetic requires `BigInt`, nominal IDs work as strings), provide both options as separate quick fix entries:

```dart
@override
List<Fix> getFixes() => [
  _ReplaceWithBigIntParseFix(),
  _ReplaceWithStringLiteralFix(),
];
```

Each fix offers priority 80 and 75 respectively, with `BigInt.parse` as the primary recommendation.

## Notes & Issues
- The value `9007199254740992` (2^53) is `Number.MAX_SAFE_INTEGER + 1` in JavaScript. Values up to and including `9007199254740992` are representable exactly. Values strictly greater than `9007199254740992` are not guaranteed to be exact. The threshold in the rule should be `> 9007199254740992`, not `>= 9007199254740992`.
- Double-check: `9007199254740992` = `2^53`. JavaScript's `Number.MAX_SAFE_INTEGER` = `2^53 - 1` = `9007199254740991`. Values from `9007199254740991` downward are safe. Values from `9007199254740993` upward are unsafe. `9007199254740992` itself can be represented exactly (it is a power of 2), but `9007199254740993` cannot. The rule should trigger for values `> 9007199254740992`.
- This rule is particularly relevant for Flutter Web applications that use database IDs from PostgreSQL or MySQL `BIGINT` columns, which can produce values exceeding `2^53`.
- Consider adding a companion rule `avoid_js_rounded_int_arithmetic` that flags operations like `largeValue * multiplier` where constant folding can determine the result exceeds the limit.
- The Comprehensive tier placement reflects that this rule requires some JavaScript/web knowledge to understand and is not relevant to pure Dart VM projects.
- Ensure the `LintCode.problemMessage` includes the literal value and the JS safe maximum in the message text to help developers understand immediately why it was flagged.
