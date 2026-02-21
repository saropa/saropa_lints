# `require_https_only_test` false positive: HTTP URLs in URL utility test data

## Status: OPEN

## Summary

The `require_https_only_test` rule (v3) fires on HTTP URL string literals in `test/url/url_extensions_test.dart`, a test file for URL manipulation utilities. The tests exercise methods like `isValidUrl`, `isValidHttpUrl`, `isSecure`, `extractDomain`, `replaceHost`, and `removeQuery` — all of which **must** handle both HTTP and HTTPS URLs. The rule flags `'http://example.com'` test data strings as security concerns, but these are string literals used in pure function assertions. No network connection is made. HTTP test data is essential for comprehensive URL utility testing.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/test/url/url_extensions_test.dart
owner:    _generated_diagnostic_collection_name_#2
code:     require_https_only_test
severity: 2 (info)
message:  [require_https_only_test] HTTP URL detected in test file. Consider
          using HTTPS even in test data. {v3}
          Replace http:// with https:// or disable this rule for test files.
lines:    46, 285, 302, 315, 320, 355, 371, 378, 528
          (9 violations)
```

## Affected Source

File: `test/url/url_extensions_test.dart` — URL utility tests requiring HTTP protocol test data

### Violation 1: URL scheme preservation test (line 46)

```dart
test('8. Scheme preserved', () {
  final Uri uri = Uri.parse('http://example.com?x=1');  // ← triggers
  final Uri result = uri.removeQuery();
  expect(result.scheme, 'http');
});
```

This test verifies that `removeQuery()` preserves the original URI scheme. If the test used HTTPS, it would not test scheme preservation for HTTP URLs — a critical edge case.

### Violation 2: HTTP URL parsing test (line 285)

```dart
test('8. HTTP URL', () {
  final Uri? result = UrlUtils.tryParse('http://example.com');  // ← triggers
  expect(result, isNotNull);
  expect(result?.scheme, 'http');
});
```

This test verifies that `tryParse` correctly handles HTTP URLs. Replacing with HTTPS would eliminate HTTP protocol coverage entirely.

### Violations 3-5: URL validation and domain extraction (lines 302, 315, 320, 355)

```dart
// isValidUrl must accept HTTP URLs
test('2. Valid HTTP', () =>
    expect(UrlUtils.isValidUrl('http://example.com'), isTrue));  // ← triggers

// isValidHttpUrl — method is literally named for HTTP testing
test('2. Valid HTTP', () =>
    expect(UrlUtils.isValidHttpUrl('http://example.com'), isTrue));  // ← triggers

// Domain extraction must work with HTTP URLs
test('8. IP address', () =>
    expect(UrlUtils.extractDomain('http://192.168.1.1'), '192.168.1.1'));  // ← triggers
```

A URL validation utility that cannot validate HTTP URLs would be incomplete. The method `isValidHttpUrl` literally requires HTTP inputs to test correctly.

### Violation 6: Security check tests (lines 371, 378)

```dart
test('2. HTTP is not secure', () =>
    expect(Uri.parse('http://example.com').isSecure, isFalse));  // ← triggers

test('9. HTTP with port', () =>
    expect(Uri.parse('http://example.com:8080').isSecure, isFalse));  // ← triggers
```

These tests verify the `isSecure` getter correctly identifies HTTP URLs as **not** secure. This is the most ironic false positive: the test is explicitly asserting that HTTP is insecure, which is exactly the security awareness the rule is trying to promote, yet the rule flags it anyway.

### Violation 7: Scheme preservation in host replacement (line 528)

```dart
test('4. Scheme preserved', () {
  final Uri result = Uri.parse('http://example.com').replaceHost('new.com');  // ← triggers
  expect(result.scheme, 'http');
});
```

This verifies that `replaceHost` preserves the original scheme. Using HTTPS would not test HTTP scheme preservation.

## Root Cause

The rule uses a simple pattern match to detect `http://` strings in test files, without analyzing:

1. **Whether the string is test fixture data** — These are string literals inside `test()` and `expect()` calls, not configuration or production URLs
2. **Whether the test is specifically testing HTTP handling** — Many of these tests exist precisely to verify HTTP URL behavior
3. **Whether any network request is made** — These are pure string/URI manipulation tests with zero network I/O
4. **The semantic purpose of the URL** — Testing `isSecure` with HTTP URLs is the correct test design; the rule flags the exact input needed to verify security detection

The rule's own diagnostic message acknowledges the issue: "or disable this rule for test files." This self-referential escape hatch suggests the rule authors recognized that test files legitimately need HTTP URLs.

## Why This Is a False Positive

1. **URL utility tests MUST test HTTP URLs** — A URL validation/parsing library that only tests HTTPS has incomplete coverage. HTTP URLs exist in the real world, and utilities must handle them correctly.

2. **No network connection is made** — Every flagged line is a string literal passed to `Uri.parse()` or a static method. No HTTP request is ever sent. The security risk the rule warns about (insecure data transmission) does not exist.

3. **Tests verify security detection** — Several flagged tests (e.g., `isSecure` tests) explicitly verify that HTTP URLs are identified as insecure. Removing the HTTP test data would reduce security test coverage.

4. **String literals are not runtime URLs** — These are compile-time string constants used as test inputs. They are equivalent to any other test fixture data (like testing email validation with invalid emails).

5. **Tests for HTTP-to-HTTPS conversion require HTTP input** — If the library had a `toHttps` method, testing it would require providing HTTP URLs as input. You cannot test a conversion without the source format.

6. **The rule's own correction says "disable for test files"** — The rule acknowledges it should not apply to test files, yet it fires in test files by default.

## Scope of Impact

Any project that includes URL handling utilities and tests them will trigger this rule. Affected test scenarios include:

| Test Type | Why HTTP Input Is Required |
|-----------|---------------------------|
| URL validation (`isValidUrl`) | Must verify HTTP URLs are accepted |
| HTTP-specific validation (`isValidHttpUrl`) | The entire method is about HTTP |
| Security detection (`isSecure`) | Must verify HTTP is detected as insecure |
| Protocol parsing | Must verify HTTP protocol is parsed correctly |
| Scheme preservation | Must verify HTTP scheme is not altered |
| Domain extraction | Must verify extraction works for HTTP URLs |
| URL conversion (HTTP-to-HTTPS) | Requires HTTP input to convert |

This affects every Flutter/Dart project with URL utility tests, HTTP client tests, or network configuration tests.

## Recommended Fix

### Approach A: Do not fire in test files by default (recommended)

The rule's own message suggests disabling for test files. Make this the default behavior:

```dart
context.addStringLiteral((StringLiteral node) {
  // Skip test files — HTTP URLs in tests are fixture data, not production URLs
  final String? filePath = context.filePath;
  if (filePath != null && (filePath.contains('/test/') || filePath.contains('_test.dart'))) {
    return;
  }

  // ... existing HTTP detection logic ...
});
```

### Approach B: Skip strings inside `test()` and `expect()` calls

Only flag HTTP URLs that appear in production-like contexts, not inside test assertions:

```dart
// Check if the string literal is inside a test() or expect() call
AstNode? parent = node.parent;
while (parent != null) {
  if (parent is MethodInvocation) {
    final String methodName = parent.methodName.name;
    if (methodName == 'test' || methodName == 'expect' ||
        methodName == 'group' || methodName == 'setUp') {
      return;  // Inside test infrastructure — skip
    }
  }
  parent = parent.parent;
}
```

**Recommendation:** Approach A is the simplest and most correct. The rule is designed to catch production code using HTTP URLs. Test files are not production code — they are verification infrastructure that must exercise all protocol variants. The rule's own diagnostic already suggests this approach.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Testing URL validation accepts HTTP — test fixture data.
test('validates http url', () {
  expect(isValidUrl('http://example.com'), isTrue);
});

// GOOD: Testing security detection identifies HTTP as insecure.
test('http is not secure', () {
  expect(Uri.parse('http://example.com').isSecure, isFalse);
});

// GOOD: Testing HTTP-to-HTTPS conversion requires HTTP input.
test('converts http to https', () {
  expect('http://example.com'.toHttps, equals('https://example.com'));
});

// GOOD: Testing protocol parsing detects HTTP scheme.
test('parses http scheme', () {
  final Uri uri = Uri.parse('http://example.com');
  expect(uri.scheme, 'http');
});

// GOOD: Testing domain extraction from HTTP URL.
test('extracts domain from http', () {
  expect(extractDomain('http://localhost:3000'), 'localhost');
});
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Hardcoded HTTP URL in production code — not test data.
// expect_lint: require_https_only_test
const String apiBaseUrl = 'http://api.example.com/v1';

// BAD: HTTP URL in non-test configuration.
// expect_lint: require_https_only_test
final String webhookUrl = 'http://hooks.example.com/notify';
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v3)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (published Dart utility package)
- **Trigger file:** `test/url/url_extensions_test.dart`
- **Trigger lines:** 46, 285, 302, 315, 320, 355, 371, 378, 528
- **Violation count:** 9 violations in a single test file
- **HTTP URLs used in:** `Uri.parse()`, `UrlUtils.tryParse()`, `UrlUtils.isValidUrl()`, `UrlUtils.isValidHttpUrl()`, `UrlUtils.extractDomain()` test inputs
- **Network I/O:** None — all tests are pure string/URI manipulation

## Severity

Low — info-level diagnostic. The false positive is noisy (11 violations in one file) and the correction advice ("Replace http:// with https://") would break the tests by eliminating HTTP protocol coverage. The most critical irony is that the `isSecure` tests — which explicitly verify that HTTP is detected as insecure — are themselves flagged for using HTTP. Following the rule's advice would remove the security verification that the rule is trying to promote. This paradox undermines developer trust in the rule's judgment.
