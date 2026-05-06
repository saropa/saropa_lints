# Task: `avoid_misleading_documentation`

## Summary
- **Rule Name**: `avoid_misleading_documentation`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.63 Documentation Rules

## Problem Statement

Doc comments must match method name and behavior. Misleading docs erode trust and cause bugs when callers rely on incorrect descriptions.

This rule aims to improve documentation quality by flagging doc comments that contradict the declared API or implementation.

## Description (from ROADMAP)

> Doc comments must match method name and behavior.

## Code Examples

### Bad (should trigger)

```dart
/// Returns the user's email address.
String get userId => _userId; // LINT: doc says email, getter is userId
```

### Good (should not trigger)

```dart
/// Returns the user's unique ID.
String get userId => _userId;
```

## Detection: True Positives

- **Goal**: Heuristically detect obvious mismatches: e.g. doc says "returns X" but method name/return type implies Y; doc says "async" but method is sync.
- **Approach**: Parse doc comment text; compare with method/class name and signature (return type, async). Use simple keyword/entity checks rather than full NLP.
- **Edge cases**: Allow generic wording ("Returns a value"); focus on clear contradictions.

## False Positives

- **Risk**: Subjective or nuanced docs flagged (e.g. "optionally returns" vs nullable return).
- **Mitigation**: INFO severity; narrow rules (e.g. keyword "email" vs identifier "userId"); avoid flagging overloaded terms. Document heuristics in rule doc.
- **Allowlist**: Generated code, example files.

## External References

- [Dart Doc Comments](https://dart.dev/guides/language/effective-dart/documentation)
- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Use `addMethodDeclaration`, `addClassDeclaration`; parse doc once per node. Prefer simple string/signature checks.

## Notes & Issues

- Heuristic rule: document limitations and encourage manual review. Check CODE_INDEX for comment_utils or existing doc-check helpers.
