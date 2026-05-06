# Bug: `require_https_only` should use reduced severity in test files

## Summary

The `require_https_only` rule fires at WARNING level on HTTP URLs in test files, where insecure URLs are typically test fixtures, not real traffic endpoints. Test files commonly contain `http://` URLs as input data for unit tests (e.g., URL parsing, validation, sanitization). These are never used for actual network communication, so the warning is noisy and misleading.

## Severity

**Medium** - WARNING-level noise in test files erodes trust in the lint and creates unnecessary `// ignore` comment clutter.

## Affected Rule

- **Rule**: `require_https_only`
- **File**: `lib/src/rules/security_rules.dart`
- **Tier**: `essentialRules` (in `lib/src/tiers.dart`, line 381)
- **Current severity**: `DiagnosticSeverity.WARNING` (all file types)

## Reproduction

In any test file that uses HTTP URLs as test data:

```dart
// test/lib/utils/web/web_utils_test.dart
test('should strip UTM parameters from URL', () {
  final String result = WebUtils.stripUtm(
    'http://example.com/path/?utm_source=test&id=1', // WARNING: require_https_only
  );
  expect(result, equals('http://example.com/path/?id=1'));
});
```

The `http://example.com` URL is test fixture data — it is never fetched or used for network communication. The warning adds no security value here.

## Proposed Fix

Split `require_https_only` into context-aware severity levels based on file type:

1. **Production code** (`lib/`): Keep current WARNING severity in `essentialRules` tier.
2. **Test code** (`test/`): Reduce to INFO severity and move to a higher tier (e.g., `recommendedOnlyRules` or `professionalOnlyRules`).

### Implementation options

**Option A: File-type aware severity (preferred)**

Add file-type detection in the rule itself to emit INFO instead of WARNING when the file path matches `test/`:

```dart
final DiagnosticSeverity severity = isTestFile(node)
    ? DiagnosticSeverity.INFO
    : DiagnosticSeverity.WARNING;
```

**Option B: Separate rule variant for tests**

Create a `require_https_only_test` variant with INFO severity, placed in a higher tier. The base `require_https_only` rule would skip test files, and the test variant would cover them at reduced severity.

## Rationale

- HTTP URLs in test files are test data, not security risks
- WARNING severity on test fixtures trains developers to ignore the rule
- INFO level still surfaces the lint for awareness without blocking or cluttering
- A higher tier means teams can opt out of test-file HTTP linting without losing production protection

## Examples of legitimate `http://` in test files

- URL parsing/validation test inputs
- HTTP-to-HTTPS redirect logic under test
- UTM stripping / query parameter manipulation
- Mock server URLs (already excluded for `localhost`, but not for `example.com`)
- Fixture data representing user-submitted or external URLs
