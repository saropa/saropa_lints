# BUG: `avoid_large_list_copy` — False positive when `.toList()` is structurally required by ?? / named arg / type context

**Status: Fixed**

Created: 2026-08-28
Rule: `avoid_large_list_copy`
File: `lib/src/rules/core/performance_rules.dart` (line ~2283)
Severity: False positive
Rule version: current
Suppression count in downstream project: **51** (75% FP rate in sample of 8)

---

## Summary

The rule flags `.toList()` as an unnecessary eager copy, but in 75% of
suppressed cases the `.toList()` is structurally required — the result is the
left operand of a `??` expression (which requires matching types on both sides),
a named argument typed as `List<T>` (not `Iterable<T>`), or a switch-case arm
returning into a `List<T>` context. Removing `.toList()` in these positions
causes a compile error.

**40+ existing ignore comments in the downstream project reference this exact
filename** (`saropa_lints/bugs/avoid_large_list_copy_false_positive_named_argument_null_coalesce_property_access.md`)
**but the file was never created.** This report fills that gap.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_large_list_copy'" lib/src/rules/
# lib/src/rules/core/performance_rules.dart:2283:    'avoid_large_list_copy',
```

**Emitter registration:** `lib/src/rules/core/performance_rules.dart:2283`

---

## Reproducer

```dart
// Pattern 1: ?? fallback requires matching types
// LINT — but should NOT lint (false positive)
// Removing .toList() makes the ?? operands type-incompatible
final List<ContactEventItem> events = items
    ?.where((ContactEventItem e) => e.isValid)
    .toList() ?? // FP: left side of ?? must be List, not Iterable
    <ContactEventItem>[];

// Pattern 2: named argument typed as List<T>
void updateContact({required List<String> phones}) {}
// LINT — but should NOT lint (false positive)
updateContact(
  phones: rawPhones.where((String p) => p.isNotEmpty).toList(),
);

// Pattern 3: assignment to List<T> variable
// LINT — but should NOT lint (false positive)
final List<String> filtered = items.where((String s) => s.isNotEmpty).toList();

// Pattern 4: genuinely unnecessary copy (SHOULD lint)
for (final String item in items.toList()) { // LINT — correct, iterable suffices
  print(item);
}
```

**Frequency:** Always — fires on every `.toList()` regardless of type context.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the surrounding type context requires `List<T>` (not `Iterable<T>`) |
| **Actual** | `[avoid_large_list_copy] Avoid unnecessary list copies` reported on `.toList()` |

---

## AST Context

```
VariableDeclarationStatement
  └─ VariableDeclaration (events) : List<ContactEventItem>
      └─ BinaryExpression (??)
          └─ MethodInvocation (.toList())  ← node reported here
              └─ MethodInvocation (.where(...))
                  └─ PrefixedIdentifier (items)
          └─ ListLiteral (<ContactEventItem>[])
```

---

## Root Cause

### Hypothesis A: Rule flags `.toList()` without checking type context

The rule registers on `MethodInvocation` nodes where the method name is
`toList` and fires unconditionally. It does not inspect the parent expression
to determine whether the result flows into a context that requires `List<T>`
rather than `Iterable<T>` — specifically:

- `BinaryExpression` with `??` operator (both sides must match)
- `NamedExpression` in an argument list where the parameter type is `List<T>`
- `VariableDeclaration` with explicit `List<T>` type annotation
- `ReturnStatement` in a function with `List<T>` return type

---

## Suggested Fix

After finding a `.toList()` call, check whether removing it would cause a type
error:

1. **Parent is `BinaryExpression` with `??` operator:** the right operand is a
   `List` literal → `.toList()` is required for type compatibility.
2. **Parent is a `NamedExpression` / positional arg:** resolve the parameter's
   `staticType` — if it is `List<T>` (not `Iterable<T>`), suppress.
3. **Enclosing variable declaration has explicit `List<T>` type:** suppress.
4. **Enclosing function return type is `List<T>`:** suppress.

If none of these apply, flag normally.

---

## Fixture Gap

The fixture should include:

1. **`.toList()` as left operand of `??`** — expect NO lint
2. **`.toList()` feeding a `List<T>` named parameter** — expect NO lint
3. **`.toList()` assigned to `List<T>` variable** — expect NO lint
4. **`.toList()` in a `for-in` loop (iterable suffices)** — expect LINT
5. **`.toList()` result passed to function taking `Iterable<T>`** — expect LINT
6. **`.toList()` in return statement with `List<T>` return type** — expect NO lint

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 51 sites
