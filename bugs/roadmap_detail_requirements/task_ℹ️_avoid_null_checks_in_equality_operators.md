# Task: `avoid_null_checks_in_equality_operators`

## Summary
- **Rule Name**: `avoid_null_checks_in_equality_operators`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
In Dart with sound null safety, the canonical `operator ==` implementation follows a
well-established pattern:

```dart
@override
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  if (other is! MyClass) return false;
  return field == other.field;
}
```

A frequent mistake is adding a redundant `if (other == null) return false;` check
before or after the `is!` type test. This check is redundant because:

1. The `is!` type test already returns `false` for `null` — `null` does not satisfy any
   non-nullable type test.
2. The Dart runtime never calls `operator ==` with `null` as `other` when the receiver
   is non-null, because `null == x` is handled via the null's own `operator ==`
   (short-circuited at the language level).
3. Under sound null safety, `other` is typed as `Object` (non-nullable), so a null check
   is logically impossible at compile time (though the analyzer may not always warn).

The redundant check adds noise, may mislead readers into thinking the type test alone
is insufficient, and is a carry-over from pre-null-safety Dart code.

## Description (from ROADMAP)
Flag explicit `other == null` or `other is Null` checks inside `operator ==` bodies when
a subsequent `is!` type test already covers the null case.

## Trigger Conditions
1. The enclosing method is `operator ==` with parameter type `Object` or `Object?`.
2. The method body contains an `if (other == null) return false;` statement (or
   `if (null == other) return false;`).
3. The method body also contains an `if (other is! SomeType) return false;` statement
   (or an equivalent `if (!(other is SomeType)) return false;`).
4. `SomeType` is a non-nullable type — so the `is!` check already excludes `null`.
5. The null check appears before or after the `is!` check (both orderings are redundant
   but the pre-`is!` ordering is the most common).

## Implementation Approach

### AST Visitor
```dart
context.registry.addMethodDeclaration((node) { ... });
```
Filter to methods where `node.name.lexeme == '=='` and `node.isOperator`.

### Detection Logic
1. Filter `MethodDeclaration` nodes to those representing `operator ==`.
2. Extract the name of the single parameter (`other` by convention, but may differ).
3. Scan the method body for `IfStatement` nodes containing:
   - A `BinaryExpression` `param == null` or `null == param` → this is the redundant
     null-check candidate.
   - A `IsExpression` with `notOperator != null` using the same parameter → this is the
     type-check that makes null check redundant.
4. Also match `if (other is Null)` or `if (other.runtimeType == Null)` as the null check.
5. If both patterns are found in the same method body, report the null-check `IfStatement`
   as the violation.
6. Report the null-check statement node (not the whole method).

## Code Examples

### Bad (triggers rule)
```dart
@override
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  if (other == null) return false;     // redundant — is! covers null
  if (other is! Point) return false;
  return x == other.x && y == other.y;
}
```

```dart
@override
bool operator ==(Object other) {
  if (other == null || other is! Config) return false;  // null check redundant
  return id == other.id;
}
```

### Good (compliant)
```dart
// Modern canonical form — no redundant null check
@override
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  if (other is! Point) return false;
  return x == other.x && y == other.y;
}
```

```dart
// Also fine — combined condition without null check
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    (other is Point && x == other.x && y == other.y);
```

## Edge Cases & False Positives
- **Nullable parameter `Object? other`**: In rare cases (e.g., overriding from a
  non-null-safe library), `other` may be typed `Object?`. A null check is then not
  fully redundant from the analyzer's perspective, though the `is!` still covers it.
  Apply the rule conservatively: only flag when parameter type is `Object` (non-nullable).
- **No accompanying `is!` check**: If the method has a null check but no `is!` check
  (e.g., uses `runtimeType` comparison instead), the null check is still technically
  redundant under null safety, but the pattern is unusual enough to skip flagging to
  avoid false positives. Document this as a known limitation.
- **`runtimeType == Null`**: An alternative null check. Detect this pattern in addition
  to `== null`.
- **Null check guarding a cast**: `if (other == null) return false; final p = other as Point;`
  — the `as` cast would throw on null anyway, so the check is still redundant, but the
  fix (replacing with `is!`) is a slightly larger refactor. Consider flagging with a note
  rather than an auto-fix.
- **Pre-null-safety code** (rare in active codebases): This rule should not be enabled
  for packages that still use `// @dart=2.9` language version comments.
- **Operator `==` with multiple return paths**: If the null check and the type check are
  in different branches of a complex conditional, static analysis is required to determine
  redundancy — be conservative and skip.

## Unit Tests

### Should Trigger (violations)
```dart
class Rect {
  final int w, h;
  const Rect(this.w, this.h);

  @override
  bool operator ==(Object other) {
    if (other == null) return false;   // LINT
    if (other is! Rect) return false;
    return w == other.w && h == other.h;
  }
}

class Id {
  final String value;
  const Id(this.value);

  @override
  bool operator ==(Object other) {
    if (null == other) return false;   // LINT (yoda form)
    if (other is! Id) return false;
    return value == other.value;
  }
}
```

### Should NOT Trigger (compliant)
```dart
// ok: no null check, modern form
class Token {
  final String raw;
  const Token(this.raw);

  @override
  bool operator ==(Object other) =>
      other is Token && raw == other.raw;

  @override
  int get hashCode => raw.hashCode;
}

// ok: uses runtimeType instead of is! — skip (not flagged, see limitations)
class Legacy {
  @override
  bool operator ==(Object other) {
    if (other == null) return false;
    if (other.runtimeType != runtimeType) return false;
    return true;
  }
}
```

## Quick Fix
**Remove the redundant null-check `if` statement.**

```dart
// Before
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  if (other == null) return false;
  if (other is! Point) return false;
  return x == other.x;
}

// After
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  if (other is! Point) return false;
  return x == other.x;
}
```

The fix deletes the null-check `IfStatement` node and its trailing newline.

## Notes & Issues
- Coordinate with `avoid_redundant_null_check` (task 5 in this batch) — that rule handles
  general redundant null checks outside `operator ==`; this rule is specialized to the
  equality operator pattern.
- The combined form `if (other == null || other is! MyClass) return false;` is harder to
  auto-fix without rewriting the whole condition. The fix can simplify to
  `if (other is! MyClass) return false;` by removing the `|| other == null` fragment.
  This requires editing a sub-expression, not removing a statement — implement with
  `addSimpleReplacement` on the binary expression sub-node.
- Consider adding a secondary check: if the null check is present but NO `is!` check
  exists, flag with a different message suggesting the developer add the `is!` pattern
  and remove the null check together.
