# False positives: `avoid_similar_names` flags idiomatic short variable names and DateTime/Duration conventions

## Summary

The `avoid_similar_names` rule produces false positives in two common patterns:

1. **Single-character variables in tightly scoped formatting code** — Any two single-letter variable names have an edit distance of exactly 1, so the rule flags every combination. Standard date/time abbreviations (`y`, `m`, `d`, `h`, `s`) all trigger each other despite being universally understood and confined to a 7-line getter.

2. **Dart API singular/plural pairs** — Variables named after Duration constructor parameters (`hours`, `minutes`, `seconds`, `milliseconds`) differ by exactly one character from the DateTime properties they're assigned from (`hour`, `minute`, `second`, `millisecond`). These are not confusable — they are the canonical names from Dart's own standard library, and developers expect to see them used together.

## Reproduction

### Case 1: Single-character date/time formatting variables

**File:** `saropa_dart_utils/lib/datetime/date_time_calendar_extensions.dart`

```dart
// Lines 97-105
String get toSerialString {
  final String y = year.toString().padLeft(4, '0');   // ← flagged
  final String m = month.toString().padLeft(2, '0');  // ← flagged
  final String d = day.toString().padLeft(2, '0');    // ← flagged (reported diagnostic)
  final String h = hour.toString().padLeft(2, '0');   // ← flagged
  final String min = minute.toString().padLeft(2, '0');
  final String s = second.toString().padLeft(2, '0'); // ← flagged
  return '$y$m${d}T$h$min$s';
}
```

**Reported diagnostic** (line 90, column 18-19, variable `d`):

```
[avoid_similar_names] Variable name differs from another in-scope variable
by only one or two characters. Near-identical names increase the risk of
accidentally using the wrong variable, producing subtle bugs that pass code
review because the names look correct at a glance. {v4}
```

**Why this is a false positive:**

- All six variables (`y`, `m`, `d`, `h`, `min`, `s`) are universally understood abbreviations for year, month, day, hour, minute, second.
- They are used in a 7-line getter whose sole purpose is formatting a date serial string — the context makes each variable's meaning immediately obvious.
- Every pair of single-character names has edit distance = 1, so the rule fires on **at least 4 of the 5 single-char variables** (the second member of each flagged pair). This produces a cascade of warnings for code that is perfectly clear.
- This is a standard pattern found in date formatting code across the Dart/Flutter ecosystem.

**The same cascade occurs in the adjacent getter** (`toSerialStringDay`, lines 108-114) which uses the subset `y`, `m`, `d`.

### Case 2: Duration parameter names vs DateTime property names

```dart
// Lines 146-199 — alignDateTime method
final int hours;
if (alignment.inDays > 0) {
  hours = hour;       // local var `hours` assigned from DateTime property `hour`
} else {
  hours = alignment.inHours > 0 ? hour % alignment.inHours : 0;
}

int minutes;
if (alignment.inHours > 0) {
  minutes = minute;   // local var `minutes` assigned from DateTime property `minute`
} else {
  minutes = alignment.inMinutes > 0 ? minute % alignment.inMinutes : 0;
}

int seconds;
// ... same pattern for seconds/second, milliseconds/millisecond
```

These local variables are named `hours`, `minutes`, `seconds`, `milliseconds` because they are passed directly to the `Duration` constructor:

```dart
final Duration correction = Duration(
  hours: hours,             // Duration parameter = hours
  minutes: minutes,         // Duration parameter = minutes
  seconds: seconds,
  milliseconds: milliseconds,
  microseconds: microseconds,
);
```

**Why `hours`/`hour` should not be flagged:**

- `hour` is a Dart `DateTime` property (singular: the hour component of a time).
- `hours` is a Dart `Duration` named parameter (plural: a count of hours).
- This singular/plural distinction is defined by the Dart standard library itself — developers are _expected_ to write `hours = hour` when bridging between DateTime and Duration.
- The same pattern applies to `minutes`/`minute`, `seconds`/`second`, `milliseconds`/`millisecond`, and `microseconds`/`microsecond`.
- If the rule only compares locally declared variables (as the current `_VariableCollector` does), these may not trigger today. But if the rule is ever expanded to include property accesses or parameters in scope — which would be a natural enhancement — this pattern will produce widespread false positives across any DateTime/Duration code.

## Root cause analysis

The `_areTooSimilar` method uses edit distance = 1 as the threshold for names ≤ 5 characters:

```dart
// code_quality_rules.dart — lines 2988-2991
if (a.length <= 5 && b.length <= 5) {
  final int distance = _editDistance(a.toLowerCase(), b.toLowerCase());
  if (distance == 1) return true;
}
```

**Problem 1: All single-character names are edit distance 1 from each other.**

Any substitution of one character for another is exactly 1 edit. So `y`, `m`, `d`, `h`, `s` are ALL "too similar" to each other. The rule effectively bans using more than one single-character variable in the same scope — even when the names are drawn from well-known domain conventions.

**Problem 2: No exemption for well-known abbreviation sets.**

Date/time formatting code universally uses `y`/`m`/`d`/`h`/`min`/`s`. Loop variables use `i`/`j`/`k`. Coordinate code uses `x`/`y`/`z`. These are not "near-identical names that look correct at a glance" — they are distinct, domain-standard abbreviations that developers read fluently.

**Problem 3: No consideration of scope size.**

A 7-line getter where all variables are used exactly once on adjacent lines is not the same risk as a 50-line function where `value1` and `valuel` are used 20 lines apart. The rule applies the same threshold regardless of scope size.

## Suggested improvements

### Option A: Exempt single-character variables from edit distance comparison

Single-character names are a deliberate choice — developers use them in tight scopes for brevity. The confusable-character check (`1`/`l`, `0`/`O`) already catches the genuinely dangerous cases. Edit distance is not meaningful for 1-character names since it always equals 1 for any pair.

```dart
// Proposed change in _areTooSimilar:
if (a.length <= 5 && b.length <= 5) {
  // Single-char names: only flag confusable chars, not edit distance
  if (a.length == 1 && b.length == 1) return false;
  final int distance = _editDistance(a.toLowerCase(), b.toLowerCase());
  if (distance == 1) return true;
}
```

### Option B: Maintain an allowlist of well-known abbreviation families

Exempt known sets of short names that commonly appear together:

| Family | Names | Context |
|--------|-------|---------|
| Date/time | `y`, `m`, `d`, `h`, `min`, `s`, `ms` | Formatting, serialization |
| DateTime/Duration | `hour`/`hours`, `minute`/`minutes`, `second`/`seconds` | Bridging Dart's own APIs |
| Loops | `i`, `j`, `k` | Nested iteration |
| Coordinates | `x`, `y`, `z`, `w` | Geometry, graphics |
| Dimensions | `r`, `g`, `b`, `a` | Color channels |

### Option C: Require minimum scope size

Only flag similar names when the enclosing block exceeds a threshold (e.g., > 15 statements or > 20 lines). In a 7-line getter, there is no realistic risk of using the wrong variable.

### Option D: Exempt singular/plural pairs for Dart standard library names

When one name is the plural of another and both correspond to Dart's `DateTime`/`Duration` API names, do not flag. This could be pattern-matched:

```dart
// If one name ends with 's' and the other is the same without 's',
// and both match known Dart API property/parameter names → exempt
final knownPairs = {'hour', 'minute', 'second', 'millisecond', 'microsecond'};
```

## What should still be flagged

The rule correctly catches genuinely confusable names:

```dart
// These SHOULD be flagged — visually ambiguous
final value1 = 1;
final valuel = 2;  // 1 vs l

final item0 = 'a';
final itemO = 'b';  // 0 vs O

// These SHOULD be flagged — unclear short names with no domain convention
final val = 1;
final var_ = 2;  // Confusing in context
```

## Scale of impact

In `date_time_calendar_extensions.dart` alone, the rule produces **at least 4 false positives** in `toSerialString` and **at least 2 more** in `toSerialStringDay`. Any codebase with date formatting, coordinate math, or nested loop indexing will encounter the same issue.

## Environment

- **OS:** Windows 11 Pro 10.0.22631
- **Rule version:** v4
- **saropa_lints version:** (current)
- **Project:** saropa_dart_utils
- **File:** `lib/datetime/date_time_calendar_extensions.dart`
- **Diagnostic severity:** INFO (severity 2 in VS Code)
