# `require_error_case_tests` false positive on defensive try-catch source code

## Status: FIXED (v4.14.5)

## Resolution

Expanded `_errorCaseKeywords` from 12 to 30 keywords, adding defensive
behavior terms (`safely`, `graceful`, `default`, `defensive`, `zero`),
lifecycle conditions (`dispose`, `closed`, `disconnect`), failure conditions
(`timeout`, `cancel`, `overflow`), input validation (`malformed`, `corrupt`),
and access control (`denied`, `unauthorized`, `reject`). Refactored the
keyword if-chain into a static `Set<String>` with `Set.any()` lookup.

Test names like "returns zero when unattached" and "handles multiple
positions safely" now match keywords `zero` and `safely`, preventing
false positives on defensive code.

## Problem

The `require_error_case_tests` rule fires on test files whose corresponding source code uses defensive `try-catch` with fallback returns — a pattern where no exceptions propagate to the caller, so there are no error paths to test from the consumer's perspective.

The rule **only analyzes the test file** (checking for matchers like `throwsA` and test-name keywords like "error", "throw", etc.). It never examines the source file being tested. This means it cannot distinguish between:

1. A test file that's missing error cases for source code that throws (genuine warning)
2. A test file that correctly omits error cases because the source code never throws (false positive)

The rule's own correction message acknowledges this scenario — _"If the source code has no error-throwing paths (e.g. pure enums, defensive try/catch with fallback returns), suppress with `// ignore_for_file`"_ — but forces manual suppression instead of detecting it automatically.

## Severity

**Medium** — Noise on well-tested defensive code erodes developer trust. Every extension method or utility with defensive try-catch will trigger this, producing widespread false positives across projects that follow the "never throw, always fallback" pattern.

## Reproducer

### Source file (never throws to caller)

**File:** `D:\src\contacts\lib\utils\layout\scroll_utils.dart`

All 3 public methods catch `Object` and return fallback values:

```dart
double get safeOffset {
  try {
    if (!hasClients) return 0.0;
    final ScrollPosition? primaryPosition = positions.firstOrNull;
    if (primaryPosition == null) return 0.0;
    return primaryPosition.pixels;
  } on Object catch (error, stack) {
    debugException(error, stack);
    return 0.0;  // ← fallback, never throws
  }
}

Future<bool> jumpTop({double offset = 0}) async {
  try {
    if (!hasClients) return false;
    await animateTo(offset, curve: Curves.easeOut, duration: ...);
    return true;
  } on Object catch (error, stack) {
    debugException(error, stack);
    return false;  // ← fallback, never throws
  }
}

Future<bool> handleDragHorizontalScroll({...}) async {
  try {
    if (!hasClients) return false;
    // ... swipe logic ...
    return false;
  } on Object catch (error, stack) {
    debugException(error, stack);
    return false;  // ← fallback, never throws
  }
}
```

### Test file (correctly tests fallback behavior, not exceptions)

**File:** `D:\src\contacts\test\utils\layout\scroll_utils_test.dart`

```dart
void main() {  // ← WARNING fires here
  group('ScrollControllerExtensions.safeOffset', () {
    test('returns zero when unattached', () {
      final ScrollController controller = ScrollController();
      expect(controller.safeOffset, 0.0);  // tests the fallback
      controller.dispose();
    });

    testWidgets('handles multiple attached positions safely', (WidgetTester tester) async {
      // ... tests defensive behavior with multiple positions ...
    });
  });
}
```

The tests ARE testing defensive behavior (the "returns zero when unattached" test exercises the `!hasClients` guard path). But since there's no `throwsA` matcher and no "error"/"exception" keyword in the test names, the rule fires.

## Root Cause

### Location

**File:** `lib/src/rules/testing_best_practices_rules.dart`, lines 2764–2819

### The detection logic

The rule checks only 3 things in the **test file**:

1. **Matcher calls** (lines 2768–2778): `throwsA`, `throwsException`, etc.
2. **Expect patterns** (lines 2781–2789): `expect(..., isA<Exception>())` string matching
3. **Test name keywords** (lines 2796–2807): `throw`, `error`, `fail`, `invalid`, `exception`, `null`, `empty`, `boundary`, `edge`, `negative`, `fallback`, `missing`

### Why it fails

The rule never derives or analyzes the corresponding source file. It has no awareness of whether the source code:
- Catches all exceptions internally (defensive pattern)
- Throws exceptions to callers (error-path pattern)
- Has no executable paths at all (pure data/enum)

Additionally, the keyword detection has a gap: test names describing defensive fallback behavior without the exact keywords (e.g., "returns zero when unattached", "handles multiple positions safely") are not matched.

### The contradiction

The correction message at line 2732–2735 explicitly lists "defensive try/catch with fallback returns" as a valid reason to suppress. This means the rule recognizes that such source code doesn't need error-case tests — yet it makes no attempt to detect this pattern and fires anyway.

## Suggested Fix

### Option A: Analyze the source file (recommended)

Derive the source file path from the test file path and check for defensive try-catch patterns:

```dart
// In the post-analysis callback, before reporting:
if (!hasErrorCaseTest && mainFunction != null) {
  // Derive source path: test/foo/bar_test.dart → lib/foo/bar.dart
  final String sourcePath = path
      .replaceFirst(RegExp(r'[/\\]test[/\\]'), '/lib/')
      .replaceFirst('_test.dart', '.dart');

  // Check if source file exists and has defensive patterns
  if (await _sourceHasDefensiveTryCatch(sourcePath)) {
    return; // Don't report — source never throws to caller
  }

  reporter.atToken(mainFunction!.name, code);
}
```

Where `_sourceHasDefensiveTryCatch` checks if every public method body wraps its logic in `try { ... } on Object catch (...) { return fallbackValue; }` (i.e., catch-all with a return statement, not a rethrow).

### Option B: Expand keyword detection (simpler, partial fix)

Add more test-name keywords that cover defensive behavior testing:

```dart
// Add to the keyword list at lines 2796-2807:
firstArg.contains('unattached') ||
firstArg.contains('no client') ||
firstArg.contains('safely') ||
firstArg.contains('graceful') ||
firstArg.contains('default') ||
firstArg.contains('returns zero') ||
firstArg.contains('returns false') ||
firstArg.contains('defensive')
```

This is fragile and non-exhaustive but would reduce false positives.

### Option C: Detect fallback-testing patterns in assertions

Recognize that tests asserting fallback return values (0.0, false, null, empty list) under failure conditions ARE error-case tests:

```dart
// A test that asserts a default/fallback value is testing defensive behavior
if (methodName == 'expect') {
  final String source = node.toSource();
  if (source.contains('0.0') ||
      source.contains('false') ||
      source.contains('isNull') ||
      source.contains('isEmpty') ||
      source.contains('isEmpty')) {
    // Check if test name suggests a non-happy-path scenario
    // (e.g., controller not attached, missing data, etc.)
    hasErrorCaseTest = true;
  }
}
```

## Scope of False Positives

This pattern is pervasive in projects that follow "defensive coding" conventions. Any source code following this project's mandatory error handling pattern (from `CLAUDE.md` / coding standards):

```dart
try {
  // Implementation
} on Object catch (error, stack) {
  debugException(error, stack);
  return fallbackValue;
}
```

...will produce a false positive in its corresponding test file if the test correctly tests fallback behavior rather than exception-throwing behavior.

## Environment

- **saropa_lints version:** 4.14.5
- **Trigger project:** `D:\src\contacts`
- **Rule file:** `lib/src/rules/testing_best_practices_rules.dart`, lines 2661–2821
- **Files affected:**
  - `test/utils/layout/scroll_utils_test.dart` (confirmed)
  - Likely any other test file whose source uses the defensive try-catch pattern
