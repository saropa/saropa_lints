# Task: `require_return_documentation`

## Summary
- **Rule Name**: `require_return_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Non-void methods must document return value. Callers need to know what to expect from the return type.

This rule aims to enforce return documentation for public APIs.

## Description (from ROADMAP)

> Non-void methods must document return value.

## Code Examples

### Bad (should trigger)

```dart
/// Fetches the user.
User fetchUser(); // LINT: return not documented
```

### Good (should not trigger)

```dart
/// Fetches the user.
/// Returns the [User] or throws if not found.
User fetchUser();
```

## Detection: True Positives

- **Goal**: For each public method/function with non-void return type, ensure doc comment describes the return (e.g. "Returns ..." or "The returned ..." or equivalent).
- **Approach**: Parse doc for return-related phrasing; match against return type (exclude void, Future<void>). Consider getters as "returning" the type.
- **Edge cases**: Overrides that inherit doc; factories; nullable vs non-nullable.

## False Positives

- **Risk**: Return described implicitly ("Fetches and returns the user") not recognized.
- **Mitigation**: INFO severity; accept common patterns (Returns, return value, etc.). Document accepted phrasing in rule doc.
- **Allowlist**: Generated, example, private members if scope limited.

## External References

- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file; targeted method/function visitor; parse doc once per node.

## Notes & Issues

- Pair with `require_parameter_documentation` and `require_exception_documentation`. Check comment_utils for doc parsing.
