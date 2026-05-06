# Task: `require_parameter_documentation`

## Summary
- **Rule Name**: `require_parameter_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Parameters must be documented with `[paramName]` in Dart doc comments. Undocumented parameters make APIs harder to use correctly.

This rule aims to enforce parameter documentation for public APIs.

## Description (from ROADMAP)

> Parameters must be documented with `[paramName]`.

## Code Examples

### Bad (should trigger)

```dart
/// Creates a user with the given name.
User create(String name, {int age}); // LINT: age not documented
```

### Good (should not trigger)

```dart
/// Creates a user with the given name.
/// [name] The display name.
/// [age] Optional age; defaults to 0.
User create(String name, {int age});
```

## Detection: True Positives

- **Goal**: For each public method/function, ensure every parameter (including optional named/positional) appears in a `[paramName]` doc reference.
- **Approach**: Parse doc comment for `[identifier]` sections; collect parameter names from `MethodDeclaration`/`FunctionDeclaration`; report missing params.
- **Edge cases**: Constructors, extension methods, overrides (may inherit doc). Consider excluding private members or allow "inherited" when overriding.

## False Positives

- **Risk**: Params documented in prose without `[paramName]` (e.g. "The [name] parameter is required") flagged.
- **Mitigation**: INFO severity; consider accepting prose that clearly references the param name. Document that `[paramName]` is the preferred form.
- **Allowlist**: Generated code, example.

## External References

- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation) — `[paramName]` convention
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file; use `addMethodDeclaration`/`addFunctionDeclaration`; parse doc once per node. Use comment_utils if available (CODE_INDEX).

## Notes & Issues

- Align with `require_return_documentation` and `require_exception_documentation` for consistent doc rules. Check comment_utils for parsing.
