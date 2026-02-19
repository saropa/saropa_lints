# Task: `banned_usage`

## Summary
- **Rule Name**: `banned_usage`
- **Tier**: Professional
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.61 Code Quality Rules

## Problem Statement

Teams often need to ban specific patterns, not just specific APIs:
- "Never use `print()` in production code"
- "Never use `dart:html` (use a platform abstraction instead)"
- "Never use `List.from()` (use spread syntax instead)"
- "Never call `context.read()` inside `build()` — use `context.watch()` or `context.select()`"

Unlike `avoid_banned_api` (which focuses on layer boundaries and source package filtering), `banned_usage` is a simpler, more general configurable rule for banning any identifier, function, or class.

## Description (from ROADMAP)

> Configurable rule to ban specific APIs, classes, or patterns.

## Relationship to `avoid_banned_api`

`banned_usage` and `avoid_banned_api` appear to overlap. Before implementing, clarify the distinction:
- `avoid_banned_api`: Layer boundary enforcement with file include/exclude patterns and source package filtering
- `banned_usage`: Simpler general-purpose ban list (no file filtering, just "never use X")

Consider **merging** the two into a single powerful configurable rule. **NOTE:** Discuss this with the team before implementing.

## Implementation Approach

### Configuration
```yaml
custom_lint:
  rules:
    banned_usage:
      entries:
        - identifier: 'print'
          reason: 'Use Logger.debug() instead'
        - identifier: 'dart:html'
          reason: 'Use platform-abstracted alternatives'
        - identifier: 'List.from'
          reason: 'Use spread syntax [...list] instead'
          allowedFiles:
            - 'test/**'
```

### AST Visitor Pattern

```dart
context.registry.addSimpleIdentifier((node) {
  for (final ban in _configuredBans) {
    if (ban.matches(node)) {
      reporter.atNode(node, _createCodeWithReason(ban.reason));
      return;
    }
  }
});
```

`ban.matches(node)`: check if the identifier's name or qualified name matches the ban entry.

## Code Examples

### Config + Bad (Should trigger)
```yaml
banned_usage:
  entries:
    - identifier: 'print'
      reason: 'Use Logger.d() instead in production code'
```

```dart
void logUserAction(String action) {
  print('User did: $action');  // ← trigger: print is banned
}
```

### Good (Should NOT trigger)
```dart
// Using the allowed alternative
void logUserAction(String action) {
  Logger.d('User did: $action');  // ✓ allowed
}
```

## Edge Cases & False Positives

| Scenario | Expected Behaviour | Notes |
|---|---|---|
| No configuration | **No-op** — rule is disabled without config | |
| Banned identifier used as string literal `'print'` | **Suppress** — not actual usage | |
| Banned class used in comment | **Suppress** | |
| Banned identifier matched as substring | **Suppress** — must be whole word | e.g., `_print` should not match ban on `print` |
| Test file with `allowedFiles: ['test/**']` | **Suppress** | |
| Generated file | **Suppress by default** | |
| Overloaded identifier name (different packages) | **Be specific** — match qualified name where possible | `package:foo/bar.dart::print` vs `dart:core::print` |

## Unit Tests

### Violations
1. `print('hello')` with `print` banned → 1 lint with reason message
2. `dart:html` import with it banned → 1 lint

### Non-Violations
1. No config → no lint
2. `print` in `allowedFiles` pattern → no lint
3. String `'print'` (not a call) → no lint

## Quick Fix

No automated fix — replacement depends on the ban reason.

The problem message should include the configured reason:
```
[banned_usage] Usage of 'print' is banned. Use Logger.d() instead in production code.
```

## Notes & Issues

1. **Potential merge with `avoid_banned_api`**: These two rules are very similar. Before implementing separately, consider if they can be unified with `avoid_banned_api` supporting an optional `allowedFiles` parameter (already has it) and `banned_usage` being a simpler alias without source-package filtering.
2. **`print` ban is the most common use case** — this is the most obvious candidate for demonstrating the rule's value in the README.
3. **Qualified name vs. bare identifier**: `print` in Dart is `dart:core::print`. Users may configure `print` expecting it to match `dart:core`'s print but not a custom `print` function. Clarify the matching semantics.
