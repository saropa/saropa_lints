> **========================================================**
> **DUPLICATE -- DO NOT IMPLEMENT (SDK LINT)**
> **========================================================**
>
> Dart SDK provides a built-in `avoid_dynamic_calls` lint in
> `package:lints`. Enable in analysis_options.yaml instead:
>
>     linter:
>       rules:
>         avoid_dynamic_calls: true
>
> Reimplementing as custom_lint would be slower and duplicate
> first-party SDK functionality.
>
> **========================================================**

# Task: `avoid_dynamic_calls`

## Summary
- **Rule Name**: `avoid_dynamic_calls`
- **Tier**: Recommended
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §2 Miscellaneous Rules

## Problem Statement

Calling methods or accessing properties on `dynamic` typed values bypasses Dart's type system, losing all type safety benefits:
1. No compile-time verification of method existence
2. No IDE autocomplete
3. Runtime `NoSuchMethodError` crashes instead of compile-time errors
4. Poor performance (dynamic dispatch vs. static dispatch)

Common sources: `json.decode()` result used without casting, `Map<String, dynamic>` accessed without `as T`, `Object` downcast not checked.

## Description (from ROADMAP)

> Avoid dynamic calls; prefer static typing for safety.

## Trigger Conditions

1. `(dynamic).method()` — calling a method on a `dynamic` value
2. `(dynamic).property` — accessing a property on a `dynamic` value
3. `(dynamic)[key]` — index access on a `dynamic` value

**Note**: Dart's built-in `avoid_dynamic_calls` lint already exists. Check if it can be configured to WARNING severity. If so, this rule may be redundant.

## Implementation Approach

### Overlap with Built-in Rule
**CRITICAL CHECK**: Dart SDK has `avoid_dynamic_calls` as an official lint rule. Before implementing, verify:
1. Is it available in the Dart version this package targets?
2. Can it be configured to WARNING severity?
3. If yes to both, this rule is redundant.

If custom implementation is needed:

```dart
context.registry.addMethodInvocation((node) {
  final targetType = node.realTarget?.staticType;
  if (targetType == null) return;
  if (targetType is! DynamicType) return;
  reporter.atNode(node, code);
});
```

## Code Examples

### Bad (Should trigger)
```dart
// Dynamic from jsonDecode
final data = jsonDecode(response.body);
final name = data['name'];  // ← trigger: data is dynamic
data.doSomething();  // ← trigger: dynamic method call

// Uncast dynamic
void process(dynamic value) {
  value.toString();  // ← trigger (though toString() IS safe)
  value.specialMethod();  // ← trigger
}
```

### Good (Should NOT trigger)
```dart
// Properly cast
final data = jsonDecode(response.body) as Map<String, dynamic>;
final name = data['name'] as String;  // ✓ typed access

// Using a typed model
final response = MyResponse.fromJson(jsonDecode(body));  // ✓
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `dynamic.toString()` | **Suppress** — `toString()` is available on all types | Whitelist `toString`, `hashCode`, `runtimeType` |
| `dynamic.runtimeType` | **Suppress** | |
| `(Object).method()` (not dynamic) | **Suppress** — Object is typed | Only flag `dynamic` type, not `Object` |
| Generated code | **Suppress** | |
| `noSuchMethod` implementations | **Complex** — intentional dynamic dispatch | |

## Unit Tests

### Violations
1. Method call on `dynamic` typed variable → 1 lint
2. Property access on `dynamic` → 1 lint

### Non-Violations
1. Method call on typed variable → no lint
2. `dynamic.toString()` → no lint
3. Cast before use `(value as Foo).method()` → no lint

## Quick Fix

No automated fix — proper typing requires knowing the intended type.

## Notes & Issues

1. **CHECK BUILT-IN RULE FIRST**: `avoid_dynamic_calls` is an official Dart lint. If it's available and configurable to WARNING, this custom rule is redundant.
2. **`toString()` on dynamic is harmless** — `Object` defines `toString()`, `hashCode`, `runtimeType`, `==`, `noSuchMethod`. These should be suppressed to avoid annoying false positives.
3. **`json.decode` pattern**: The most common source of `dynamic` is `json.decode()`. A companion rule or quick fix that suggests immediate casting would be valuable.
