# Task: `require_https_only_test`

## Summary
- **Rule Name**: `require_https_only_test`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md — 1.5 Security Rules, Security & Configuration (Test Files)

## Problem Statement

HTTP URLs in test files are typically test fixtures, not real endpoints. Reports at INFO severity so teams can disable independently from production `require_https_only`.

This rule aims to improve code quality and security hygiene by flagging HTTP URLs in test files while allowing teams to treat test fixtures differently from production config.

## Description (from ROADMAP)

> HTTP URLs in test files are typically test fixtures, not real endpoints. Reports at INFO severity so teams can disable independently from production `require_https_only`.

## Code Examples

### Bad (should trigger)

```dart
// In a test file: HTTP URL that may be mistaken for production config.
final baseUrl = 'http://localhost:8080'; // LINT: test file HTTP
```

### Good (should not trigger)

```dart
// HTTPS in test or fixture URL with clear test intent.
final baseUrl = 'https://example.com';
// Or test-only fixture constant.
```

## Detection: True Positives

- **Goal**: Detect string literals containing `http://` (not `https://`) in files classified as test files (e.g. `*_test.dart`, `test/**`).
- **Approach**: Use `ProjectContext.isTestFile(path)` to scope; scan string literals for `http://` with word/scheme boundary to avoid false matches.
- **Edge cases**: Exclude generated files; consider `package:test` and `package:flutter_test` usage as test context.

## False Positives

- **Risk**: Legitimate test fixtures (e.g. `http://localhost`, mock server URLs) flagged when team accepts them.
- **Mitigation**: INFO severity allows per-project disable; consider allowlisting `localhost`, `127.0.0.1` or document as known exception.
- **Allowlist**: Generated code, example apps under `example/`.

## External References

- [Dart Lint Rules](https://dart.dev/tools/linter-rules)
- [OWASP Mobile](https://owasp.org/www-project-mobile-top-10/)
- [custom_lint](https://pub.dev/packages/custom_lint)

## Quality & Performance

- Use `ProjectContext` for test-file detection; prefer `addStringLiteral` or similar targeted callback.
- Early exit for non-test files.

## Notes & Issues

- Confirm no overlap with `require_https_only` (production rule); this is the test-file counterpart at INFO.
