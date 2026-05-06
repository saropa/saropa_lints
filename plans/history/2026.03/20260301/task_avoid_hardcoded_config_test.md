# Task: `avoid_hardcoded_config_test`

## Summary
- **Rule Name**: `avoid_hardcoded_config_test`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.5 Security Rules, Security and Configuration (Test Files)

## Problem Statement

Hardcoded URLs and keys in test files are typically test fixture data, not deployment configuration. Reports at INFO severity so teams can disable independently from production avoid_hardcoded_config.

## Description (from ROADMAP)

> Hardcoded URLs and keys in test files are typically test fixture data, not deployment configuration. Reports at INFO severity so teams can disable independently from production avoid_hardcoded_config.

## Code Examples

### Bad (should trigger)

```dart
const apiKey = 'sk_live_abc123';
```

### Good (should not trigger)

```dart
const mockApiKey = 'test_key_fixture';
```

## Detection: True Positives

- Use ProjectContext.isTestFile(path). Match string literals that look like URLs or config keys.

## False Positives

- INFO severity. Consider naming heuristics. Allowlist generated code, example/.

## External References

- Dart Lint Rules, OWASP Mobile, custom_lint

## Quality and Performance

- Use ProjectContext for test-file detection. Early exit for non-test files.

## Notes and Issues

- Align with production avoid_hardcoded_config. This is the test-scoped variant at INFO.
