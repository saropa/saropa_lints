# Require Infinite Scroll Error Recovery

**GitHub:** [https://github.com/saropa/saropa_lints/issues/37](https://github.com/saropa/saropa_lints/issues/37)

**Opened:** 2026-01-23T14:01:27Z

---

## Detail

### Problem  
Failed page loads in infinite scroll lists need a retry option. Without error recovery, users may be unable to access data if a single page fails to load.

### Why This Is Complex  
- **Pattern detection:** Requires analyzing error handling in infinite scroll logic.
- **UI feedback:** Error states and retry options may be implemented in various ways.
- **False positives:** Some apps may handle errors outside the scroll component.

### Desired Outcome  
- Detect infinite scroll without error state and retry button.
- Warn about missing retry options for failed page loads.
- Suggest best practices for error recovery in infinite scroll lists.

### References  
- See ROADMAP.md section: "require_infinite_scroll_error_recovery"

---

## Roadmap task spec (merged from bugs/roadmap/task_require_infinite_scroll_error_recovery.md)

# Task: `require_infinite_scroll_error_recovery`

## Summary
- **Rule Name**: `require_infinite_scroll_error_recovery`
- **Tier**: Recommended
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.35 Dependency Injection, Logging, Pagination & Scroll

## Problem Statement

Failed page loads need retry. Detect infinite scroll without error state and retry button.

This rule aims to improve code quality, security, or maintainability by enforcing a specific practice. Implementation must reliably detect true violations while avoiding false positives.

## Description (from ROADMAP)

> Failed page loads need retry. Detect infinite scroll without error state and retry button.

## Code Examples

### Bad (should trigger)

```dart
// Example violation: code that the rule should report.
// TODO: Replace with concrete example for `require_infinite_scroll_error_recovery`.
```

### Good (should not trigger)

```dart
// Compliant code that must not be flagged.
// TODO: Replace with concrete example for `require_infinite_scroll_error_recovery`.
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
- Add package/docs links relevant to `require_infinite_scroll_error_recovery` (e.g. bloc, riverpod, hive).

## Quality & Performance

- **Analyzer cost**: Prefer targeted registry callbacks (e.g. `addMethodDeclaration`) over full unit traversal where possible.
- **Caching**: Use `ProjectContext` for project-level checks (e.g. `usesPackage('x')`) to avoid repeated work.
- **Early exit**: Skip files or nodes that cannot violate (e.g. no Bloc usage) before running heavy logic.
- **Test requirement**: Add at least one true-positive and one false-positive fixture (or test that runs the linter and asserts).

## Notes & Issues

- Before implementing: confirm no overlap with existing rules in [CODE_INDEX.md](../../CODE_INDEX.md).
- Checklist: exact-match or type checks (no `.contains()` on names); consider all AST shapes; document edge cases.
