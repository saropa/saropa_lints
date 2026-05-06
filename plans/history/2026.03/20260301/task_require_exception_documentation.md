# Task: `require_exception_documentation`

## Summary
- **Rule Name**: `require_exception_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Methods that throw must document exceptions. Callers need to know which exceptions to catch and under what conditions.

This rule aims to enforce exception documentation for public APIs that can throw.

## Description (from ROADMAP)

> Methods that throw must document exceptions.

## Code Examples

### Bad (should trigger)

```dart
/// Loads config from file.
Config load() {
  throw FileNotFoundException(path); // LINT: throws not documented
}
```

### Good (should not trigger)

```dart
/// Loads config from file.
/// Throws [FileNotFoundException] if path does not exist.
Config load() { ... }
```

## Detection: True Positives

- **Goal**: Detect methods/functions that throw (explicit throw, or call to methods that throw) and have no doc mention of exceptions (e.g. "Throws", "throws").
- **Approach**: AST: find throw expressions and rethrows; optionally track called methods that throw. Require doc to contain throw-related wording and optionally exception type names.
- **Edge cases**: Delegating to another method (doc may say "see otherMethod"); overrides; async (Future rejection). Consider excluding test files.

## False Positives

- **Risk**: Internal or implementation-detail throws flagged; "may throw" in prose not recognized.
- **Mitigation**: INFO severity; accept "Throws", "may throw", "throws on ...". Allow "Propagates exceptions from X". Document accepted phrasing.
- **Allowlist**: Generated, example.

## External References

- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file AST; traverse body for throw/rethrow; parse doc once. Consider limiting to public API.

## Notes & Issues

- Full "methods that throw" may require flow analysis; start with explicit throw in same body and doc check. Check CODE_INDEX for throw/catch utilities.
