# Task: `require_complex_logic_comments`

## Summary
- **Rule Name**: `require_complex_logic_comments`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Complex methods must have explanatory comments. Uncommented complex logic is hard to maintain and review.

## Description (from ROADMAP)

> Complex methods must have explanatory comments.

## Code Examples

### Bad (should trigger)

```dart
// No comment; high complexity or length.
void process(Data d) {
  if (d.a) { if (d.b) { } else if (d.c) { } }
  // ... many branches
} // LINT: complex, no comment
```

### Good (should not trigger)

```dart
/// Applies business rules A/B/C and updates state.
void process(Data d) { ... }
```

## Detection: True Positives

- **Goal**: Detect methods that exceed a complexity or line threshold and have no (or trivial) doc/block comment. Compute cyclomatic complexity or statement count; require at least one comment when above threshold.
- **Edge cases**: Setters/getters, overrides; generated code excluded.

## False Positives

- **Mitigation**: INFO severity; document threshold (e.g. complexity >= 10 or lines >= 30). Consider excluding test files.

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Single-file AST; compute complexity or length in one pass. Prefer targeted registry.

## Notes & Issues

- Define "complex" (e.g. cyclomatic complexity >= N). Check CODE_INDEX for existing complexity utilities.
