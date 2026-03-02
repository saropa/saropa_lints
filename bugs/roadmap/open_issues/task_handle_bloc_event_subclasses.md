# Task: `handle_bloc_event_subclasses`

## Summary
- **Rule Name**: `handle_bloc_event_subclasses`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.62 Bloc/Cubit Rules

## Problem Statement

Ensure all event subclasses are handled in event handlers.

This rule aims to improve code quality, security, or maintainability by enforcing a specific practice. Implementation must reliably detect true violations while avoiding false positives.

## Description (from ROADMAP)

> Ensure all event subclasses are handled in event handlers.

## Code Examples

### Bad (should trigger)

```dart
// Violation: see Problem Statement. Add concrete example before implementing.
```

### Good (should not trigger)

```dart
// Compliant: see Problem Statement. Add concrete example before implementing.
```

## Detection: True Positives

- **Goal**: Reliably detect all real violations of the practice.
- **Detection approach**: Visit the AST nodes that can exhibit the pattern (see Problem Statement); report when the pattern is found. Before implementing: add concrete bad/good examples above and refine this (or mark "Needs design" if the pattern requires cross-file/heuristic work).
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
- Add package/docs links relevant to `handle_bloc_event_subclasses` (e.g. bloc, riverpod, hive).

## Quality & Performance

- **Analyzer cost**: Prefer targeted registry callbacks (e.g. `addMethodDeclaration`) over full unit traversal where possible.
- **Caching**: Use `ProjectContext` for project-level checks (e.g. `usesPackage('x')`) to avoid repeated work.
- **Early exit**: Skip files or nodes that cannot violate (e.g. no Bloc usage) before running heavy logic.
- **Test requirement**: Add at least one true-positive and one false-positive fixture (or test that runs the linter and asserts).

## Notes & Issues

- Before implementing: confirm no overlap with existing rules in [CODE_INDEX.md](../../CODE_INDEX.md).
- Checklist: exact-match or type checks (no `.contains()` on names); consider all AST shapes; document edge cases.
