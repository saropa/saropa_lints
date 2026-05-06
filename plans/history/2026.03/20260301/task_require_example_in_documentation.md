# Task: `require_example_in_documentation`

## Summary
- **Rule Name**: `require_example_in_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Complex public classes should include usage examples in their doc comments. Examples improve discoverability and reduce misuse.

This rule aims to encourage example snippets for non-trivial public APIs.

## Description (from ROADMAP)

> Complex public classes should include usage examples.

## Code Examples

### Bad (should trigger)

```dart
/// Handles pagination state and loading; use with [PaginationController].
class PaginationState { ... } // LINT: complex public class, no example
```

### Good (should not trigger)

```dart
/// Handles pagination state and loading.
///
/// Example:
/// ```dart
/// final state = PaginationState(controller: c);
/// await state.loadNext();
/// ```
class PaginationState { ... }
```

## Detection: True Positives

- **Goal**: Detect public classes (and optionally top-level functions) that are "complex" (e.g. multiple methods, non-trivial API) and have no example block in doc (e.g. no ```dart ... ``` in doc).
- **Approach**: Heuristic for "complex" (e.g. method count, has public members); parse doc for fenced code block (```dart or ```). Report when complex and no example.
- **Edge cases**: Mixins, abstract classes, enums; consider different thresholds. Exclude single-method or data-only classes.

## False Positives

- **Risk**: Simple classes or classes with obvious API flagged; examples in separate doc file.
- **Mitigation**: INFO severity; define "complex" narrowly (e.g. ≥ 3 public methods or has optional params). Document threshold. Allow link to external example.
- **Allowlist**: Generated, example, models/DTOs.

## External References

- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file; class declaration visitor; parse doc for code blocks. Prefer simple heuristics for complexity.

## Notes & Issues

- "Complex" is heuristic; document clearly. Consider reusing complexity logic from `require_complex_logic_comments` if shared. Check comment_utils for code block detection.
