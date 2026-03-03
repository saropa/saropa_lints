# Prefer Parallel Tests

**GitHub:** [https://github.com/saropa/saropa_lints/issues/44](https://github.com/saropa/saropa_lints/issues/44)

**Opened:** 2026-01-23T14:02:11Z

---

## Detail

### Problem  
Independent integration tests can run in parallel with --concurrency, reducing total CI time for large test suites.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing test independence and CI configuration.
- **CI diversity:** Different systems and flags for parallelism.
- **False positives:** Some tests may have hidden dependencies.

### Desired Outcome  
- Detect integration tests that could run in parallel.
- Warn about potential inefficiency.
- Suggest configuring parallelism for independent tests.

### References  
- See ROADMAP.md section: "prefer_parallel_tests"

---

## Roadmap task spec (merged from bugs/roadmap/task_prefer_parallel_tests.md)

# Task: `prefer_parallel_tests`

## Summary
- **Rule Name**: `prefer_parallel_tests`
- **Tier**: Comprehensive
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.4 Testing Rules

## Problem Statement

Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites.

This rule aims to improve code quality, security, or maintainability by enforcing a specific practice. Implementation must reliably detect true violations while avoiding false positives.

## Description (from ROADMAP)

> Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites.

## Code Examples

### Bad (should trigger)

```dart
// Example violation: code that the rule should report.
// TODO: Replace with concrete example for `prefer_parallel_tests`.
```

### Good (should not trigger)

```dart
// Compliant code that must not be flagged.
// TODO: Replace with concrete example for `prefer_parallel_tests`.
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
- Add package/docs links relevant to `prefer_parallel_tests` (e.g. bloc, riverpod, hive).

## Quality & Performance

- **Analyzer cost**: Prefer targeted registry callbacks (e.g. `addMethodDeclaration`) over full unit traversal where possible.
- **Caching**: Use `ProjectContext` for project-level checks (e.g. `usesPackage('x')`) to avoid repeated work.
- **Early exit**: Skip files or nodes that cannot violate (e.g. no Bloc usage) before running heavy logic.
- **Test requirement**: Add at least one true-positive and one false-positive fixture (or test that runs the linter and asserts).

## Notes & Issues

- Before implementing: confirm no overlap with existing rules in [CODE_INDEX.md](../../CODE_INDEX.md).
- Checklist: exact-match or type checks (no `.contains()` on names); consider all AST shapes; document edge cases.

