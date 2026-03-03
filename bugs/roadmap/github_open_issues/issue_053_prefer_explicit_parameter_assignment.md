# Prefer Explicit Parameter Assignment

**GitHub:** [https://github.com/saropa/saropa_lints/issues/53](https://github.com/saropa/saropa_lints/issues/53)

**Opened:** 2026-01-23T14:03:16Z

---

## Detail

### Problem  
Explicitly assigning constructor parameters to fields improves clarity and maintainability, especially in complex constructors.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing constructor bodies and parameter assignments.
- **Code diversity:** Different styles for parameter assignment.
- **False positives:** Some constructors may use shorthand or other patterns intentionally.

### Desired Outcome  
- Detect constructors without explicit parameter assignment.
- Warn about potential confusion.
- Suggest explicit assignment for clarity.

### References  
- See ROADMAP.md section: "prefer_explicit_parameter_assignment"

---

## Roadmap task spec (merged from bugs/roadmap/task_prefer_explicit_parameter_assignment.md)

# Task: `prefer_explicit_parameter_assignment`

## Summary
- **Rule Name**: `prefer_explicit_parameter_assignment`
- **Tier**: Stylistic
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — Stylistic / Opinionated Rules

## Problem Statement

Prefer explicit parameter assignment in constructors.

This rule aims to improve code quality, security, or maintainability by enforcing a specific practice. Implementation must reliably detect true violations while avoiding false positives.

## Description (from ROADMAP)

> Prefer explicit parameter assignment in constructors.

## Code Examples

### Bad (should trigger)

```dart
// Example violation: code that the rule should report.
// TODO: Replace with concrete example for `prefer_explicit_parameter_assignment`.
```

### Good (should not trigger)

```dart
// Compliant code that must not be flagged.
// TODO: Replace with concrete example for `prefer_explicit_parameter_assignment`.
```

## Detection: True Positives

- **Goal**: Reliably detect all real violations of the practice.
- **Approach**: Prefer type/element checks and exact-match sets over substring or `toSource()` matching.
- **AST coverage**: Consider all AST shapes for the same pattern (e.g. both `MethodDeclaration` and `FunctionDeclaration`) so violations are not missed.
- **Edge cases**: Document which constructs are in scope (e.g. test files, generated code, platform-specific code) and ensure detection is consistent.

## False Positives

- **Risk**: Compliant code flagged as violation erodes trust and leads to suppressions.
- **Mitigation**: Use word boundaries in regexes (e.g. `\\b` so "auth" does not match "Oauth"); avoid `name.contains('X')` for identifiers.
- **Allowlist**: Consider whether tests, generated files, or certain packages should be excluded.
- **Ambiguity**: If the rule is heuristic (e.g. "complex" method), document thresholds and consider INFO severity.

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules) — official lint rule design.
- [Flutter API docs](https://api.flutter.dev/) — for widget/API-specific rules.
- [OWASP Mobile](https://owasp.org/www-project-mobile-top-10/) — for security rules.
- [Dart custom_lint](https://pub.dev/packages/custom_lint) — plugin API and performance.
- Add package/docs links relevant to `prefer_explicit_parameter_assignment` (e.g. bloc, riverpod, hive).

## Quality & Performance

- **Analyzer cost**: Prefer targeted registry callbacks (e.g. `addMethodDeclaration`) over full unit traversal where possible.
- **Caching**: Use `ProjectContext` for project-level checks (e.g. `usesPackage('x')`) to avoid repeated work.
- **Early exit**: Skip files or nodes that cannot violate (e.g. no Bloc usage) before running heavy logic.
- **Test requirement**: Add at least one true-positive and one false-positive fixture (or test that runs the linter and asserts).

## Notes & Issues

- Before implementing: confirm no overlap with existing rules in [CODE_INDEX.md](../../CODE_INDEX.md).
- Checklist: exact-match or type checks (no `.contains()` on names); consider all AST shapes; document edge cases.

