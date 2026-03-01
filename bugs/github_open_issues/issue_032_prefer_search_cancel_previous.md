# Prefer Search Cancel Previous

**GitHub:** [https://github.com/saropa/saropa_lints/issues/32](https://github.com/saropa/saropa_lints/issues/32)

**Opened:** 2026-01-23T14:00:52Z

---

## Detail

### Problem  
When a new search is started, the previous search request should be cancelled to avoid race conditions and wasted resources. This is especially important for networked or async search operations.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing how search requests are managed and cancelled.
- **API diversity:** Different libraries and patterns for cancellation (e.g., CancelToken, abort controller).
- **False positives:** Some searches are intentionally allowed to run concurrently.

### Desired Outcome  
- Detect search logic without cancellation of previous requests.
- Warn about potential race conditions and inefficiency.
- Suggest implementing cancellation for async search operations.

### References  
- See ROADMAP.md section: "prefer_search_cancel_previous"

---

## Roadmap task spec (merged from bugs/roadmap/task_prefer_search_cancel_previous.md)

# Task: `prefer_search_cancel_previous`

## Summary
- **Rule Name**: `prefer_search_cancel_previous`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.35 Dependency Injection, Logging, Pagination & Scroll

## Problem Statement

Cancel previous search request when new search starts. Detect search without CancelToken or similar mechanism.

This rule aims to improve code quality, security, or maintainability by enforcing a specific practice. Implementation must reliably detect true violations while avoiding false positives.

## Description (from ROADMAP)

> Cancel previous search request when new search starts. Detect search without CancelToken or similar mechanism.

## Code Examples

### Bad (should trigger)

```dart
// Example violation: code that the rule should report.
// TODO: Replace with concrete example for `prefer_search_cancel_previous`.
```

### Good (should not trigger)

```dart
// Compliant code that must not be flagged.
// TODO: Replace with concrete example for `prefer_search_cancel_previous`.
```

## Detection: True Positives

- **Goal**: Reliably detect all real violations of the practice.
- **Approach**: Prefer type/element checks and exact-match sets over substring or `toSource()` matching (see [bugs/history/false_positives/string_contains_false_positive_audit.md](../../history/false_positives/string_contains_false_positive_audit.md)).
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
- Add package/docs links relevant to `prefer_search_cancel_previous` (e.g. bloc, riverpod, hive).

## Quality & Performance

- **Analyzer cost**: Prefer targeted registry callbacks (e.g. `addMethodDeclaration`) over full unit traversal where possible.
- **Caching**: Use `ProjectContext` for project-level checks (e.g. `usesPackage('x')`) to avoid repeated work.
- **Early exit**: Skip files or nodes that cannot violate (e.g. no Bloc usage) before running heavy logic.
- **Test requirement**: Add at least one true-positive and one false-positive fixture (or test that runs the linter and asserts).

## Notes & Issues

- Before implementing: confirm no overlap with existing rules in [CODE_INDEX.md](../../CODE_INDEX.md).
- Checklist: exact-match or type checks (no `.contains()` on names); consider all AST shapes; document edge cases.
