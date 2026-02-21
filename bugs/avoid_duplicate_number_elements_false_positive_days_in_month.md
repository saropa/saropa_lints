# `avoid_duplicate_number_elements` false positive: List literal with intentionally repeated values

## Status: OPEN

## Summary

The `avoid_duplicate_number_elements` rule (v2) fires on a `List<int>` literal representing the number of days in each month of the year. The list `[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]` correctly contains repeated values because multiple months share the same day count (seven months have 31 days, four months have 30 days). The rule treats this as a "copy-paste error or logic mistake," but in a `List`, duplicate values at different indices are perfectly valid and necessary -- each index represents a distinct month.

The rule's own diagnostic message even acknowledges this exact use case: "If intentional (e.g., days-in-month arrays), suppress with `// ignore`." This self-acknowledgment confirms the rule is known to produce false positives on this common pattern.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/datetime/date_time_utils.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_duplicate_number_elements
severity: 4 (warning)
message:  [avoid_duplicate_number_elements] Duplicate numeric element in
          collection literal typically indicates a copy-paste error or logic
          mistake. In Sets, the duplicate is silently ignored, producing a
          smaller collection than expected. {v2}
          Remove the duplicate numeric element. If intentional (e.g.,
          days-in-month arrays), suppress with // ignore.
line:     293
```

## Affected Source

File: `lib/datetime/date_time_utils.dart` line 293

```dart
class DateTimeUtils {
  // ...

  /// Returns the number of days in the given month and year.
  ///
  /// Takes into account leap years for February.
  static int monthDayCount({required int year, required int month}) {
    if (month < minMonth || month > maxMonth) {
      throw ArgumentError('Month must be between 1 and 12');
    }

    const List<int> daysInMonth = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    //                                  Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
    //
    // Duplicate values:
    //   31 appears 7 times (Jan, Mar, May, Jul, Aug, Oct, Dec) -- 7 months have 31 days
    //   30 appears 4 times (Apr, Jun, Sep, Nov) -- 4 months have 30 days
    //   28 appears 1 time  (Feb) -- unique
    //
    // ALL duplicates are intentional and correct.

    if (month == 2 && isLeapYear(year: year)) {
      return daysInFebLeapYear;
    }

    return daysInMonth[month - 1];
  }
}
```

This is one of the most well-known constant arrays in programming. The days-in-month pattern `[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]` appears in virtually every date/time library across all programming languages.

## Root Cause

The rule flags duplicate numeric values in collection literals. Its primary concern is valid for `Set` literals, where duplicates are silently dropped by the Dart runtime:

```dart
// Genuine bug: Set silently drops the duplicate 7
const Set<int> primes = {2, 3, 5, 7, 7, 11};  // → {2, 3, 5, 7, 11} — 5 elements, not 6
```

However, the rule also fires on `List` literals, where duplicates at different indices are **semantically distinct** -- each index maps to a different conceptual entity (month, day of week, etc.). In a `List<int>`:

- `daysInMonth[0]` is January (31 days)
- `daysInMonth[6]` is July (31 days)
- Both are 31, but they represent different months -- this is not a copy-paste error

The rule does not distinguish between:

| Collection Type | Duplicate Behavior | Risk |
|---|---|---|
| `Set<int>` | Silently dropped -- smaller collection than expected | **High** -- likely bug |
| `List<int>` | Preserved at different indices -- correct behavior | **None** -- intentional |

The rule fires a `warning`-level diagnostic (severity 4) on a `List` literal where the "fix" (removing duplicates) would produce an **incorrect** calendar.

## Why This Is a False Positive

1. **This is a `List`, not a `Set`** -- duplicate values at different indices are valid and necessary. Each element represents a distinct month.

2. **The rule's own message acknowledges the false positive** -- the correction text says "If intentional (e.g., days-in-month arrays), suppress with `// ignore`." If the rule knows this pattern is legitimate, it should not fire at `warning` severity.

3. **The suggestion to "Remove the duplicate numeric element" is wrong** -- removing duplicate values from `[31, 28, 31, 30, ...]` would produce `[31, 28, 30]`, an incorrect and useless list.

4. **Warning severity is too high for an acknowledged false positive** -- the rule fires at `warning` (severity 4), not `info`. Warnings typically indicate likely bugs, but the rule's own message admits this pattern is commonly intentional.

5. **This is a universally recognized constant** -- the days-in-month array is one of the most common lookup tables in software. Any linter that flags it as a "logic mistake" will lose developer trust.

## Scope of Impact

Any `List` literal with intentionally repeated numeric values will trigger this false positive. Common patterns:

```dart
// Days in month (the exact pattern flagged here)
const List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

// Quarterly mapping (which quarter each month belongs to)
const List<int> monthToQuarter = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4];

// Weekday patterns (e.g., working hours per day)
const List<int> hoursPerDay = [8, 8, 8, 8, 8, 4, 0];  // Mon-Fri: 8, Sat: 4, Sun: 0

// Musical intervals (semitones from root)
const List<int> majorScale = [0, 2, 4, 5, 7, 9, 11];  // no duplicates, but minor scale:
const List<int> harmonicMinorScale = [0, 2, 3, 5, 7, 8, 11];

// Color palette indices
const List<int> rowColors = [0, 1, 0, 1, 0, 1];  // alternating

// Grid layout column spans
const List<int> columnSpans = [2, 1, 1, 2, 1, 1];  // mixed layout

// Pixel data / bitmap patterns
const List<int> checkerboard = [0, 1, 0, 1, 1, 0, 1, 0];
```

All of these are legitimate `List` literals where duplicate values are intentional and correct.

## Recommended Fix

### Approach A: Only fire on `Set` literals (recommended)

The rule's core value proposition -- catching silently dropped duplicates -- only applies to `Set` literals. For `List` literals, duplicates are preserved and are almost always intentional.

```dart
void checkCollectionLiteral(CollectionLiteral node) {
  // Only flag Set literals where duplicates are silently dropped
  if (node is! SetOrMapLiteral || !node.isSet) return;

  // ... existing duplicate detection logic ...
}
```

### Approach B: Downgrade severity for `List` literals

If the rule should still fire on Lists as a "code smell" hint, downgrade from `warning` to `info` (or even `hint`) for `List` contexts:

```dart
if (node is ListLiteral) {
  // Use info severity -- duplicates in Lists are often intentional
  reporter.atNode(node, code: infoCode);
} else if (node is SetOrMapLiteral && node.isSet) {
  // Use warning severity -- duplicates in Sets are usually bugs
  reporter.atNode(node, code: warningCode);
}
```

### Approach C: Skip Lists with 7+ elements

Short lists with duplicates (e.g., `[1, 1]`) are more suspicious than long lists with repeated patterns. A heuristic threshold:

```dart
// Lists with many elements and repeated values are typically lookup tables
if (node is ListLiteral && node.elements.length >= 7) return;
```

**Recommendation:** Approach A is the cleanest fix. The rule's entire justification ("In Sets, the duplicate is silently ignored, producing a smaller collection than expected") does not apply to Lists. For Lists, Approach B is an acceptable alternative.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Days-in-month lookup table -- intentional duplicates.
const List<int> daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

// GOOD: Quarter mapping -- intentional grouping.
const List<int> monthQuarter = [1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4];

// GOOD: Alternating pattern.
const List<int> pattern = [0, 1, 0, 1, 0, 1];

// GOOD: Working hours per weekday.
const List<int> hours = [8, 8, 8, 8, 8, 4, 0];
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Set with duplicate -- silently drops element.
// expect_lint: avoid_duplicate_number_elements
const Set<int> primes = {2, 3, 5, 7, 7, 11};  // 7 is duplicated -- likely typo

// BAD: Set with duplicate zero.
// expect_lint: avoid_duplicate_number_elements
const Set<int> flags = {0, 1, 2, 0};  // 0 is duplicated -- likely typo
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v2)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\saropa_dart_utils` (pure Dart utility library, not a Flutter app)
- **Trigger file:** `lib/datetime/date_time_utils.dart` line 293
- **Trigger expression:** `const List<int> daysInMonth = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]`
- **Collection type:** `List<int>` (NOT `Set`)
- **Total violations from this rule:** 1 (per current violation batch)
- **Rule severity:** warning

## Severity

Medium -- warning-level diagnostic on a single line, but the warning is fundamentally wrong for `List` literals. The rule's suggestion to "Remove the duplicate numeric element" would produce an incorrect calendar, which is the opposite of the rule's intent (preventing logic mistakes). The rule's own correction text acknowledges days-in-month as a known false positive, which suggests the rule should be scoped to `Set` literals where the concern is valid.
