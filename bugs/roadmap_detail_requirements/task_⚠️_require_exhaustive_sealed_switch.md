# Task: `require_exhaustive_sealed_switch`

## Summary
- **Rule Name**: `require_exhaustive_sealed_switch`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §4.1 Dart 3.x Feature Rules

## Problem Statement

Sealed classes in Dart 3.0 create closed type hierarchies. When switching on a sealed type, the switch should be exhaustive — handling all possible subtypes. If new subtypes are added, the switch should be updated.

Dart 3 switch expressions ARE exhaustive by default (compile error if not). However, `switch` **statements** with `default:` may silently miss new subtypes that are added later. Additionally, switch expressions using `_` wildcard patterns suppress exhaustiveness errors while looking exhaustive.

This rule focuses on:
1. `switch` statements on sealed types that use `default:` instead of explicitly handling each case
2. `switch` expressions using `_` wildcard on sealed types (which defeats the exhaustiveness check)

## Description (from ROADMAP)

> Switch on sealed types must handle all cases.

## Trigger Conditions

1. `switch` STATEMENT (not expression) on a sealed type with a `default:` case → warn to use explicit cases
2. `switch` expression on a sealed type with `_ => ...` wildcard → warn

**Note**: Dart 3's switch EXPRESSIONS on sealed types already give compile errors for non-exhaustive switches. This rule addresses the weaker `switch` statement form and wildcard suppressions.

## Implementation Approach

```dart
context.registry.addSwitchStatement((node) {
  final selectorType = node.expression.staticType;
  if (!_isSealedType(selectorType)) return;
  if (_hasDefaultCase(node)) {
    reporter.atNode(_getDefaultCase(node)!, code);
  }
});

context.registry.addSwitchExpression((node) {
  final selectorType = node.expression.staticType;
  if (!_isSealedType(selectorType)) return;
  if (_hasWildcardPattern(node)) {
    reporter.atNode(_getWildcardCase(node)!, code);
  }
});
```

`_isSealedType`: check if the type's declaration has the `sealed` modifier.

## Code Examples

### Bad (Should trigger)
```dart
sealed class Shape {}
class Circle extends Shape {}
class Square extends Shape {}
class Triangle extends Shape {}

void area(Shape shape) {
  switch (shape) {
    case Circle():
      return pi * r * r;
    case Square():
      return side * side;
    default:  // ← trigger: new Triangle was added and is silently ignored
      return 0;
  }
}

// Switch expression with wildcard — defeats exhaustiveness
final area = switch (shape) {
  Circle() => pi * r * r,
  Square() => side * side,
  _ => throw UnimplementedError(),  // ← trigger: wildcard on sealed type
};
```

### Good (Should NOT trigger)
```dart
// Exhaustive switch statement ✓
void area(Shape shape) {
  switch (shape) {
    case Circle():
      return pi * r * r;
    case Square():
      return side * side;
    case Triangle():
      return base * height / 2;
    // No default: — Dart will warn if Triangle is removed from sealed class
  }
}

// Exhaustive switch expression ✓
final area = switch (shape) {
  Circle() => pi * r * r,
  Square() => side * side,
  Triangle() => base * height / 2,
};
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| Abstract (not sealed) class with default | **Suppress** — non-sealed classes can have unknown subtypes | Only fire on `sealed` classes |
| `default:` in switch on non-sealed type | **Suppress** | |
| Sealed class where some cases are private | **Trigger** — the rule should check all cases regardless | |
| Sealed class across packages | **Trigger** — sealed classes are always in same library | |
| Generated code | **Suppress** | |
| Switch with `case _: throw AssertionError()` | **Trigger** — still a wildcard | Some teams use this idiom intentionally; may need to be suppressible |

## Unit Tests

1. Switch statement on sealed type with `default:` → 1 lint
2. Switch expression on sealed type with `_` wildcard → 1 lint
3. Switch expression without wildcard on sealed type → no lint
4. Switch statement with explicit all-cases on sealed type → no lint
5. Switch on non-sealed abstract class with default → no lint

## Quick Fix

Offer "Replace `default` with explicit cases":
```dart
// This requires knowing the sealed class subtypes — may not be automatable
// Suggest adding each subtype case manually
```

## Notes & Issues

1. **Dart 3 switch expressions are ALREADY exhaustive by requirement** — this rule adds value for `switch` STATEMENTS and wildcard expressions only.
2. **The default-case warning** is about future-proofing: if a new subtype is added to the sealed class, the switch will silently use the default case instead of failing to compile.
3. **`_isSealedType`**: Requires checking if `selectorType?.element?.declaration` has a `sealed` modifier. Check the Dart analysis API for how to detect the `sealed` keyword.
