# False positives: Multiple rules misfire in utility library context

## Resolution

**Fixed (all 6 rules):**
1. `avoid_datetime_comparison_without_precision` — exempt comparisons against const/static fields (heuristic: PascalCase prefix = class)
2. `avoid_unsafe_collection_methods` — added source-text fallback for guard detection
3. `avoid_medium_length_files` — exempt files containing only `abstract final` utility namespace classes
4. `prefer_single_declaration_per_file` — exempt files where all classes are `abstract final` static-only namespaces
5. `avoid_high_cyclomatic_complexity` — raised threshold from 10 to 15 (industry standard)
6. `prefer_no_continue_statement` — exempt early-skip guard pattern (`if (cond) { continue; }` in loop body)

## Summary

Six `saropa_lints` rules produce a total of **14 false positives** when applied to `saropa_dart_utils`, a pure Dart utility package. The rules assume they are analyzing Flutter app code (UI widgets, mutable state, complex architectures) rather than a library of small, independent, stateless utility functions. This report documents each rule, the triggering code, why the diagnostic is incorrect, and suggested improvements.

| # | Rule | Instances | Core issue |
|---|------|-----------|------------|
| 1 | `avoid_datetime_comparison_without_precision` | 1 | Flags intentional exact-epoch check |
| 2 | `avoid_unsafe_collection_methods` | 1 | Ignores preceding length guard |
| 3 | `avoid_medium_length_files` | 1 | Penalizes cohesive utility class |
| 4 | `prefer_single_declaration_per_file` | 1 | Penalizes related constant namespaces |
| 5 | `avoid_high_cyclomatic_complexity` | 8 | Threshold too aggressive for validation/parsing |
| 6 | `prefer_no_continue_statement` | 2 | Alternative increases nesting depth |

---

## 1. `avoid_datetime_comparison_without_precision` (1 instance)

### Triggering code

```dart
// lib/datetime/date_constant_extensions.dart:42
bool get isUnixEpochDateTime => this == DateConstants.unixEpochDate;
```

### Diagnostic output

```
[avoid_datetime_comparison_without_precision] Direct DateTime comparison
may fail due to microsecond differences.
Use difference().abs() < threshold instead.
```

### Why this is a false positive

The entire purpose of `isUnixEpochDateTime` is to check whether a `DateTime` instance is **precisely** the Unix epoch (`1970-01-01T00:00:00.000Z`). Replacing `==` with `difference().abs() < threshold` would be semantically wrong -- it would match dates that are *near* the epoch but not the epoch itself.

The right-hand operand is a compile-time constant (`DateConstants.unixEpochDate`), not a computed or user-supplied value. There is no risk of microsecond drift from arithmetic or timezone conversion.

### Suggested improvement

Exempt `==` comparisons where one operand is a `const` value or a static constant field. Constant-to-value comparisons are intentionally exact and should not be flagged.

---

## 2. `avoid_unsafe_collection_methods` (1 instance)

### Triggering code

```dart
// lib/datetime/date_time_utils.dart:238-239
if (parts.length == 1) {
  return parts.first;
}
```

### Full context

```dart
// Build result parts
final List<String> parts = <String>[];

if (years > 0) {
  parts.add('$years $yearStr');
}
if (months > 0) {
  parts.add('$months $monthStr');
}
if (includeRemainingDays && remainingDaysInt > 0) {
  parts.add('$remainingDaysInt $dayStr');
}

// Handle case where we have no years or months
if (parts.isEmpty) {
  if (includeRemainingDays && remainingDaysInt > 0) {
    return '$remainingDaysInt $dayStr';
  }
  return _zeroDays;
}

// Join parts with 'and' for readability
if (parts.length == 1) {
  return parts.first;  // <-- FLAGGED
} else if (parts.length == 2) {
  return '${parts.first} and ${parts[1]}';
} else {
  // For 3 parts: "X years, Y months, and Z days"
  return '${parts.first}, ${parts[1]}, and ${parts[2]}';
}
```

### Diagnostic output

```
[avoid_unsafe_collection_methods] Using .first can throw StateError on
empty collections. Use .firstOrNull or check isEmpty first.
```

### Why this is a false positive

The `parts.length == 1` guard on the immediately preceding line guarantees the list is non-empty. `.first` cannot throw `StateError` here. The rule does not perform data-flow analysis to detect that the collection's length has already been validated.

### Suggested improvement

Suppress the diagnostic when `.first` (or `.last`) appears inside a block whose condition checks `length == N` (where N >= 1), `length > 0`, `length >= 1`, or `isNotEmpty` on the same variable. This is a common guard pattern.

---

## 3. `avoid_medium_length_files` (1 instance)

### Triggering file

```
lib/datetime/date_time_utils.dart — 374 lines (threshold: 300)
```

### Diagnostic output

```
[avoid_medium_length_files] File has 374 lines (threshold 300).
Consider splitting into smaller files.
```

### Why this is a false positive

`DateTimeUtils` is an `abstract final class` containing only `static` methods. Every method is:

- **Independent** -- no method calls another method in the class
- **Self-contained** -- no shared mutable state
- **Stateless** -- pure functions with no side effects

Splitting into `date_time_conversion_utils.dart`, `date_time_validation_utils.dart`, etc. would scatter related date/time utilities across multiple files, making them harder to discover. Unlike a widget class or service class, a utility namespace benefits from co-location.

### Suggested improvement

Exempt files where the only top-level declaration is an `abstract final class` containing exclusively `static` members (pure utility/constant namespaces). Alternatively, raise the threshold for files that contain no mutable state and no instance members.

---

## 4. `prefer_single_declaration_per_file` (1 instance)

### Triggering file

```dart
// lib/datetime/date_constants.dart
abstract final class DateConstants { ... }      // line 13
abstract final class MonthUtils { ... }         // line 108
abstract final class WeekdayUtils { ... }       // line 157 (approx)
abstract final class SerialDateUtils { ... }    // line 195 (approx)
```

### Diagnostic output

```
[prefer_single_declaration_per_file] File contains multiple top-level
declarations. Prefer one declaration per file.
```

### Why this is a false positive

These four classes are closely related date/time constant namespaces deliberately co-located for discoverability:

- `DateConstants` -- numeric limits (min/max month, year, etc.)
- `MonthUtils` -- month name mappings
- `WeekdayUtils` -- weekday name mappings
- `SerialDateUtils` -- serial date constants

All four are `abstract final` classes with only `static const` members -- they are pure data namespaces, not behavioral classes. A developer looking for "date constants" expects to find them in one file, not scattered across `date_constants.dart`, `month_utils.dart`, `weekday_utils.dart`, and `serial_date_utils.dart`.

Splitting would:
1. Fragment related constants that are used together
2. Increase import boilerplate (4 imports instead of 1)
3. Reduce discoverability with no readability benefit

### Suggested improvement

Exempt files where all top-level declarations are `abstract final class` with only `static const` or `static final` members. These are constant/enum namespaces, not independent classes with behavior that should be separated.

---

## 5. `avoid_high_cyclomatic_complexity` (8 instances)

### Triggering locations

| File | Line | Method | CC |
|------|------|--------|----|
| `date_time_calendar_extensions.dart` | 147 | `alignDateTime` | >10 |
| `date_time_utils.dart` | 190 | `convertDaysToYearsAndMonths` | >10 |
| `date_time_utils.dart` | 342 | `isValidDateParts` | >10 |
| `json_utils.dart` | 68 | `isJson` | >10 |
| `string_between_extensions.dart` | 59 | `removeBetweenAll` | >10 |
| `string_between_extensions.dart` | 113 | `betweenResult` | >10 |
| `string_between_extensions.dart` | 202 | `betweenLast` | >10 |
| `string_text_extensions.dart` | 247 | `pluralize` | >10 |

### Key false positive patterns

#### Pattern A: Linear field validation (`isValidDateParts`)

```dart
// date_time_utils.dart:342-373
static bool isValidDateParts({
  int? year, int? month, int? day,
  int? hour, int? minute, int? second,
  int? millisecond, int? microsecond,
}) {
  if (year != null && (year < 0 || year > DateConstants.maxYear)) return false;
  if (month != null && (month < DateConstants.minMonth || month > DateConstants.maxMonth))
    return false;
  if (day != null) {
    if (month == null) return false;
    final int maxDay = monthDayCount(
      year: year ?? DateConstants.defaultLeapYearCheckYear,
      month: month,
    );
    if (day < 1 || day > maxDay) return false;
  }
  if (hour != null && (hour < 0 || hour > DateConstants.maxHour)) return false;
  if (minute != null && (minute < 0 || minute > DateConstants.maxMinuteOrSecond)) return false;
  if (second != null && (second < 0 || second > DateConstants.maxMinuteOrSecond)) return false;
  if (millisecond != null &&
      (millisecond < 0 || millisecond > DateConstants.maxMillisecondOrMicrosecond))
    return false;
  if (microsecond != null &&
      (microsecond < 0 || microsecond > DateConstants.maxMillisecondOrMicrosecond))
    return false;
  return true;
}
```

This function has 8 independent field validations. Each `if` checks one field against its valid range. The function reads top-to-bottom as a checklist. Extracting each validation into a helper would obscure the simple structure without reducing real complexity.

#### Pattern B: Cascading unit checks (`alignDateTime`)

```dart
// date_time_calendar_extensions.dart:147-197
DateTime alignDateTime({required Duration alignment, bool roundUp = false}) {
  if (alignment == Duration.zero) return this;

  final int hours;
  if (alignment.inDays > 0) {
    hours = hour;
  } else {
    hours = alignment.inHours > 0 ? hour % alignment.inHours : 0;
  }

  int minutes;
  if (alignment.inHours > 0) {
    minutes = minute;
  } else {
    minutes = alignment.inMinutes > 0 ? minute % alignment.inMinutes : 0;
  }

  // ... same pattern for seconds, milliseconds, microseconds
}
```

This is a single algorithm that cascades through time units (days, hours, minutes, seconds, milliseconds). Each block follows the identical pattern. Extracting into helpers would break the cascade into disconnected fragments without improving readability.

#### Pattern C: Grammar rules (`pluralize`)

```dart
// string_text_extensions.dart:247-265
String pluralize(num? count, {bool simple = false}) {
  if (isEmpty || count == 1) return this;
  if (simple) return '${this}s';

  final String lastChar = lastChars(1);
  switch (lastChar) {
    case 's':
    case 'x':
    case 'z':
      return '${this}es';
    case 'y':
      if (length > 2 && this[length - 2].isVowel()) return '${this}s';
      return '${substringSafe(0, length - 1)}ies';
  }

  final String lastTwo = lastChars(2);
  if (lastTwo == 'sh' || lastTwo == 'ch') return '${this}es';
  return '${this}s';
}
```

English pluralization rules are inherently branchy. The `switch` and `if` statements directly encode language rules. There is no way to reduce cyclomatic complexity without either (a) creating an over-engineered lookup table or (b) splitting into multiple methods that each handle one suffix, which would be harder to read than the current 18-line function.

#### Pattern D: Sequential validation (`isJson`)

```dart
// json_utils.dart:68-91
static bool isJson(String? value, {bool testDecode = false, bool allowEmpty = false}) {
  if (value == null || value.length < 2) return false;
  final String trimmed = value.trim();
  final bool isObject = trimmed.startsWith('{') && trimmed.endsWith('}');
  final bool isArray = trimmed.startsWith('[') && trimmed.endsWith(']');
  if (!isObject && !isArray) return false;
  if (isObject && !trimmed.contains(':')) {
    if (!allowEmpty || trimmed != '{}') return false;
  }
  if (isArray && trimmed == '[]') {
    if (!allowEmpty) return false;
  }
  if (!testDecode) return true;
  // ... try-catch decode
}
```

Sequential validation checks for JSON format detection. Each `if` is an independent check. The function is straightforward top-to-bottom despite having a CC > 10.

### Why these are false positives

All 8 instances share a common trait: **high cyclomatic complexity with low cognitive complexity**. The functions are:

- Linear (no deeply nested branches)
- Each branch is independent (not interleaved)
- Readable top-to-bottom without needing to track state
- Short (all under 30 lines)

A CC threshold of 10 is reasonable for methods with interleaved control flow, but too aggressive for:
- Validation functions (independent range checks)
- Parsing functions (sequential boundary checks)
- Grammar/rule engines (inherently branchy domain rules)
- Time-unit cascade algorithms (repetitive but linear patterns)

### Suggested improvements

1. **Raise the threshold to 15** for functions under 30 lines with no nesting deeper than 2 levels
2. **Exempt switch statements** or weight their cases lower (each case adds 1 to CC but not to cognitive load)
3. **Distinguish CC from cognitive complexity** -- consider adopting SonarSource's cognitive complexity metric which weights nested branches higher than sequential ones
4. **Allow per-function suppression** with an `// ignore:` comment rather than requiring restructuring

---

## 6. `prefer_no_continue_statement` (2 instances)

### Triggering code

```dart
// lib/datetime/date_time_range_utils.dart:30-69
bool isNthDayOfMonthInRange(int n, int dayOfWeek, int month, {bool isInclusive = true}) {
  if (month < DateConstants.minMonth || month > DateConstants.maxMonth) {
    return false;
  }

  for (int year = start.year; year <= end.year; year++) {
    final DateTime monthStart = DateTime(year, month);
    final DateTime monthEnd = DateTime(year, month + 1)
        .subtract(const Duration(days: 1));

    // Skip this year if the entire month is outside the range
    if (monthEnd.isBefore(start) || monthStart.isAfter(end)) {
      continue;  // <-- FLAGGED (line 47)
    }

    final DateTime? nthOccurrence = DateTime(year, month)
        .getNthWeekdayOfMonthInYear(n, dayOfWeek);

    // Ensure the nth occurrence is within the target month
    if (nthOccurrence == null || nthOccurrence.month != month) {
      continue;  // <-- FLAGGED (line 58)
    }

    if (nthOccurrence.isBetween(start, end, inclusive: isInclusive)) {
      return true;
    }
  }

  return false;
}
```

### Diagnostic output

```
[prefer_no_continue_statement] Avoid using continue statements.
Restructure with if conditions instead.
```

### Why this is a false positive

The `continue` statements act as **early-skip guards** -- the loop-body equivalent of early-return in functions. They filter out iterations that don't meet preconditions, keeping the "happy path" logic at a low nesting level.

The suggested alternative (inverting conditions into nested `if` blocks) would produce:

```dart
for (int year = start.year; year <= end.year; year++) {
  final DateTime monthStart = DateTime(year, month);
  final DateTime monthEnd = DateTime(year, month + 1)
      .subtract(const Duration(days: 1));

  if (!monthEnd.isBefore(start) && !monthStart.isAfter(end)) {       // depth 2
    final DateTime? nthOccurrence = DateTime(year, month)
        .getNthWeekdayOfMonthInYear(n, dayOfWeek);

    if (nthOccurrence != null && nthOccurrence.month == month) {      // depth 3
      if (nthOccurrence.isBetween(start, end, inclusive: isInclusive)) { // depth 4
        return true;
      }
    }
  }
}
```

This increases nesting depth from **2 to 4**, which would trigger `avoid_deep_nesting`. The two rules contradict each other: eliminating `continue` to satisfy one rule creates the nesting that violates the other.

The `continue`-with-guard pattern is the idiomatic Dart approach for loop filtering. It is analogous to early `return` in functions, which is universally accepted as good practice.

### Suggested improvements

1. **Exempt `continue` statements that act as early-skip guards** -- i.e., `continue` inside an `if` block at the top of a loop body, where the `if` does not contain any other statements
2. **Consider the nesting trade-off** -- if replacing `continue` with inverted `if` would increase nesting depth beyond the `avoid_deep_nesting` threshold, the `continue` should not be flagged
3. **At minimum, document the contradiction** between `prefer_no_continue_statement` and `avoid_deep_nesting` so developers know which to prioritize

---

## Common theme

All six rules share a root assumption: **the code under analysis is application code** (widgets, services, controllers) where complexity suggests architectural problems. In a utility library:

- Files are long because they group related pure functions, not because they have too many responsibilities
- Multiple declarations per file exist for discoverability, not from lack of organization
- High cyclomatic complexity comes from domain rules (validation, parsing, grammar), not from tangled business logic
- `continue` statements reduce nesting in simple filter loops, not mask spaghetti code

The rules would benefit from context-awareness: detecting whether a file contains stateless utility functions (all `static`, no mutable state, no instance members) and adjusting thresholds or exemptions accordingly.

## Environment

- **saropa_lints version:** 5.0.0-beta.15
- **Affected package:** `saropa_dart_utils`
- **OS:** Windows 11 Pro 10.0.22631
- **Total false positives:** 14 across 6 rules
