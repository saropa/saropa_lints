# Stylistic concern: `no_magic_number_in_tests` / `no_magic_string_in_tests` — severity miscalibrated for test code

## Summary

The `no_magic_number_in_tests` (2,641 hits) and `no_magic_string_in_tests` (2,110 hits) rules flag virtually every inline literal in test files, including self-documenting test inputs, boundary values, and expected outputs. These two rules alone account for **4,751 of 5,871 total lint issues (81%)** in a well-maintained utility library, overwhelming genuinely actionable warnings with noise.

The rules correctly detect what they claim — unexplained literals in test code — but the threshold for "unexplained" is too aggressive, treating standard test patterns as code smells.

## Scale of impact

| Rule | Count | % of all issues |
|------|------:|---:|
| `no_magic_number_in_tests` | 2,641 | 45% |
| `no_magic_string_in_tests` | 2,110 | 36% |
| **Combined** | **4,751** | **81%** |
| All other rules combined | 1,120 | 19% |

These two rules generate more noise than all other 75 enabled rules combined.

## What gets flagged

### Numbers that are self-documenting in context

```dart
// date_constant_extensions_test.dart — every number flagged
test('returns true when the date is the Unix epoch date', () {
  expect(DateTime.utc(1970).isUnixEpochDate, isTrue);
  //                  ^^^^ FLAGGED: "Unexplained numeric literal"
});

test('returns false when the date is not the Unix epoch date', () {
  expect(DateTime.utc(1970, 1, 2).isUnixEpochDate, isFalse);
  //                  ^^^^ ^ ^ all FLAGGED
  expect(DateTime.utc(1969, 12, 31).isUnixEpochDate, isFalse);
  //                  ^^^^  ^^  ^^ all FLAGGED
});
```

The test name says "Unix epoch date." The year 1970 IS the Unix epoch. This is not a magic number — it is the specific value under test, and its meaning is immediately clear from context.

The rule's suggested fix:
```dart
const expectedEpochYear = 1970;
const expectedEpochMonth = 1;
const expectedEpochDay = 2;
const previousYear = 1969;
const decemberMonth = 12;
const lastDayOfDecember = 31;

test('returns true when the date is the Unix epoch date', () {
  expect(DateTime.utc(expectedEpochYear).isUnixEpochDate, isTrue);
});

test('returns false when the date is not the Unix epoch date', () {
  expect(DateTime.utc(expectedEpochYear, expectedEpochMonth, expectedEpochDay).isUnixEpochDate, isFalse);
  expect(DateTime.utc(previousYear, decemberMonth, lastDayOfDecember).isUnixEpochDate, isFalse);
});
```

This is **longer, harder to scan, and less clear** than the original. The indirection adds no value when the test name already explains the purpose.

### Strings that ARE the thing being tested

```dart
// base64_utils_test.dart:8 — FLAGGED
test('compresses and returns Base64 string', () {
  final compressed = Base64Utils.compressText('Hello, World!');
  //                                          ^^^^^^^^^^^^^^^ FLAGGED
  expect(compressed, isNotNull);
});

// base64_utils_test.dart:32 — FLAGGED
test('compresses unicode text', () {
  final compressed = Base64Utils.compressText('Hello 世界 🌍');
  //                                          ^^^^^^^^^^^^^^^ FLAGGED
});
```

`'Hello, World!'` is not a magic string. It is a test fixture — an arbitrary input whose specific value doesn't matter. The test name says "compresses and returns Base64 string." Extracting it to `const testInput = 'Hello, World!'` adds indirection without clarity.

### Month/day names that are their own documentation

```dart
// date_constants_test.dart — FLAGGED
test('1. January', () => expect(MonthUtils.monthLongNames[1], 'January'));
//                                                              ^^^^^^^^^ FLAGGED

test('2. February', () => expect(MonthUtils.monthLongNames[2], 'February'));
//                                                               ^^^^^^^^^^ FLAGGED
```

The expected output `'January'` IS the value being verified. The test name says "1. January." Extracting to `const expectedJanuary = 'January'` is tautological.

### Boundary values where the number IS the boundary

```dart
// base64_utils_test.dart:24 — FLAGGED
test('compresses long text', () {
  final longText = 'a' * 10000;
  //                     ^^^^^ FLAGGED
});
```

The number 10000 is an arbitrary "large enough" value for a stress test. Naming it `const largeTextLength = 10000` adds no semantic information.

## The core problem

The rules treat ALL literals in test files as equally suspicious, making no distinction between:

| Category | Example | Is it a problem? |
|----------|---------|:-:|
| **Arbitrary fixture data** | `'Hello, World!'`, `'test input'` | No — any string would do |
| **The value under test** | `1970` for Unix epoch, `'January'` for month name | No — it IS the expected answer |
| **Boundary values** | `0`, `1`, `-1`, `12`, `24` | No — these are universal boundaries |
| **Self-documenting constants** | `DateTime.utc(2000, 2, 29)` for leap year | No — the context explains it |
| **Truly opaque numbers** | `42`, `1337`, `0xDEADBEEF` | Yes — genuinely unexplained |

The last category is the only one where extraction to a named constant improves readability, but it represents a tiny fraction of the flagged cases.

## Suggested improvements

### Option A: Add common exemptions (recommended)

Exempt patterns that are universally self-documenting:

1. **Small integers** (-1 through 31) — these are almost always boundary values, indices, or day/month numbers
2. **Common years** (1970, 2000, 2024, etc.) — date test fixtures
3. **Integers used in `DateTime` constructors** — `DateTime.utc(1970, 1, 2)` is always a date
4. **Strings that appear in the test name** — if the test is named `'1. January'` and the expected value is `'January'`, it's self-documenting
5. **Strings used as direct `expect()` inputs** — `expect(compress('Hello'), isNotNull)` — the string is an arbitrary input
6. **Round numbers** used as size/count — `10000`, `1000`, `100`

### Option B: Downgrade to hint severity

Change severity from `info` to `hint` so these don't appear in the Problems panel by default. Developers who want stricter magic-literal enforcement can upgrade severity in their `analysis_options.yaml`.

### Option C: Require opt-in for test files

Disable these rules for `*_test.dart` files by default. Let projects opt in with:
```yaml
saropa_lints:
  rules:
    no_magic_number_in_tests: true
    no_magic_string_in_tests: true
```

### Option D: Threshold-based (only flag repeated literals)

Only flag a literal if it appears 3+ times in the same test file, suggesting it should be extracted to avoid repetition. A literal used once or twice is likely context-specific.

## What NOT to change

The `no_magic_number` and `no_magic_string` rules for **lib code** (non-test files) are correctly calibrated — they found 26 and 25 issues respectively, all legitimate. The problem is specifically with the `_in_tests` variants.

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **Rule versions:** `no_magic_number_in_tests` v3, `no_magic_string_in_tests` v4
- **saropa_lints version:** (current)
- **Project:** saropa_dart_utils — 29 test files, 4,751 combined violations from these two rules
---

## Resolution

**Fixed in v5.0.0.** Numbers: expanded allowed integers to -1 through 31, added round numbers (10000, 100000, 1000000), and added exemptions for DateTime constructor arguments and `expect()` call arguments (rule v4). Strings: added exemptions for strings inside `expect()` calls and strings passed as arguments to non-test-framework functions (test fixture data) (rule v5). Extracted shared `isInExpectCall()` utility to `literal_context_utils.dart`.
