# Bug: `avoid_hardcoded_config` should use reduced severity in test files

## Summary

The `avoid_hardcoded_config` rule fires at WARNING level on hardcoded URLs in test files, where these values are intentional test fixture data — not deployment-specific configuration that should be externalized. Test files routinely contain literal URLs, ports, and paths as inputs to the code under test. The rule's advice to "use String.fromEnvironment, dotenv, or a config service" is inapplicable to test data.

## Severity

**Medium** - WARNING-level false positives in test files create noise and encourage blanket `// ignore` comments, reducing the rule's effectiveness in production code where it matters.

## Affected Rule

- **Rule**: `avoid_hardcoded_config`
- **File**: `lib/src/rules/config_rules.dart` (line 44)
- **Tier**: `essentialRules` (in `lib/src/tiers.dart`, line 465)
- **Current severity**: `DiagnosticSeverity.WARNING` (all file types)

## Reproduction

In any test file that uses URLs as test input data:

```dart
// test/lib/utils/web/web_utils_test.dart
test('should strip UTM from URL with port', () {
  final String url = 'http://example.com:8080/path?utm_source=test&id=123'; // WARNING: avoid_hardcoded_config
  final String result = WebUtils.stripUtm(url);
  expect(result, equals('http://example.com:8080/path?id=123'));
});
```

The URL is test input data exercising a pure function. There is no configuration to externalize — the string literal is the correct and only way to express this test case.

## Proposed Fix

Split `avoid_hardcoded_config` into context-aware severity levels based on file type:

1. **Production code** (`lib/`): Keep current WARNING severity in `essentialRules` tier.
2. **Test code** (`test/`): Reduce to INFO severity and move to a higher tier (e.g., `recommendedOnlyRules` or `professionalOnlyRules`).

### Implementation options

**Option A: File-type aware severity (preferred)**

Add file-type detection in the rule to emit INFO instead of WARNING when the file path is under `test/`:

```dart
final DiagnosticSeverity severity = isTestFile(node)
    ? DiagnosticSeverity.INFO
    : DiagnosticSeverity.WARNING;
```

**Option B: Separate rule variant for tests**

Create an `avoid_hardcoded_config_test` variant with INFO severity, placed in a higher tier. The base rule would skip test files, and the test variant would cover them at reduced severity.

## Rationale

- Hardcoded URLs/ports in test files are test fixture data, not deployment configuration
- The correction message ("use String.fromEnvironment, dotenv, or a config service") is wrong for test data — you don't externalize unit test inputs
- WARNING severity on test fixtures trains developers to ignore the rule
- INFO level still surfaces the lint for awareness without blocking or cluttering
- A higher tier lets teams opt out of test-file config linting without losing production protection

## Examples of legitimate hardcoded config in test files

- URL parsing/validation test inputs (`'http://example.com:8080/path'`)
- URL manipulation tests (UTM stripping, query parameter handling)
- API endpoint format validation (`'https://api.example.com/v1/users'`)
- Deep link pattern matching tests (`'myapp://settings/profile'`)
- Config parsing tests that need raw input strings
- Error handling tests with malformed URLs
