# BUG: `avoid_datetime_constructor` — False positive when components are sourced from a valid DateTime

**Status: Fixed**

Created: 2026-08-28
Rule: `avoid_datetime_constructor`
File: `lib/src/rules/data/json_datetime_rules.dart` (line ~2002)
Severity: False positive
Rule version: current | Since: early
Suppression count in downstream project: **73** (80% FP rate in sample of 10)

---

## Summary

The rule flags all `DateTime()` / `DateTime.utc()` constructor calls to prevent
invalid date component combinations. However, the most common pattern (80% of
suppressions) is re-deriving a DateTime from another valid DateTime's own
`.year`, `.month`, `.day` fields — e.g., extracting just the date portion or
applying day arithmetic. Components sourced from an already-valid DateTime
cannot produce an invalid date (and `day ± N` is intentional rollover arithmetic
that Dart documents and supports).

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_datetime_constructor'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:2002:    'avoid_datetime_constructor',
# lib/src/rules/data/json_datetime_rules.dart:2112:    'avoid_datetime_constructor',
```

**Emitter registration:** `lib/src/rules/data/json_datetime_rules.dart:2002`

---

## Reproducer

```dart
// Pattern 1: extract date-only from an existing DateTime
DateTime stripTime(DateTime dateTime) {
  // LINT — but should NOT lint (false positive)
  // All components come from dateTime, which is already valid
  return DateTime.utc(
    dateTime.year,
    dateTime.month,
    dateTime.day,
    0,
  );
}

// Pattern 2: day arithmetic on a valid DateTime
DateTime previousDay(DateTime dateTime) {
  // LINT — but should NOT lint (false positive)
  // day-1 relies on Dart's documented rollover behavior
  return DateTime.utc(
    dateTime.year,
    dateTime.month,
    dateTime.day - 1,
    0,
  );
}

// Pattern 3: genuinely risky — user-supplied integers (SHOULD lint)
DateTime fromUserInput(int year, int month, int day) {
  return DateTime(year, month, day); // LINT — correct
}
```

**Frequency:** Always — fires on every `DateTime()` constructor regardless of
argument provenance.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when all date components are property accesses on a `DateTime`-typed expression |
| **Actual** | `[avoid_datetime_constructor] Avoid using DateTime constructor directly` reported on the constructor |

---

## AST Context

```
MethodDeclaration (stripTime)
  └─ ReturnStatement
      └─ InstanceCreationExpression (DateTime.utc)  ← node reported here
          └─ ArgumentList
              └─ PrefixedIdentifier (dateTime.year)   ← DateTime getter
              └─ PrefixedIdentifier (dateTime.month)  ← DateTime getter
              └─ PrefixedIdentifier (dateTime.day)    ← DateTime getter
              └─ IntegerLiteral (0)
```

---

## Root Cause

### Hypothesis A: Rule flags constructor without inspecting argument sources

The rule registers on `InstanceCreationExpression` for `DateTime` / `DateTime.utc`
and flags unconditionally. It does not inspect whether the positional arguments
(year, month, day) are property accesses on a `DateTime`-typed expression, which
would indicate the components are already validated by the source DateTime.

---

## Suggested Fix

When the constructor is `DateTime()` or `DateTime.utc()`, inspect the first
three positional arguments (year, month, day). If all three resolve to property
accesses (`.year`, `.month`, `.day`) on an expression whose `staticType` is
`DateTime` (or `DateTime?`), suppress the diagnostic — the components are
sourced from a valid DateTime.

Allow `± intLiteral` on the day component (e.g., `dateTime.day - 1`) since
Dart's DateTime constructor documents rollover behavior for out-of-range day
values.

---

## Fixture Gap

The fixture should include:

1. **All components from valid DateTime** — expect NO lint
2. **Components from DateTime with day arithmetic (±N)** — expect NO lint
3. **Mixed sources (some from DateTime, some from int vars)** — expect LINT
4. **All components from raw int variables** — expect LINT
5. **Components from nullable DateTime with null-assert** — expect NO lint

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 73 sites
