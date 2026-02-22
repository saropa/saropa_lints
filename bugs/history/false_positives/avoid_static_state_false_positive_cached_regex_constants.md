# `avoid_static_state` false positive: cached RegExp constants and immutable static finals

## Status: RESOLVED

## Resolution

Skip `static const` unconditionally and `static final` fields with known-immutable types. Retain detection of `static final` mutable collections.

## Summary

The `avoid_static_state` rule (v4) fires 34 times across `saropa_dart_utils`, flagging top-level `final RegExp` fields, `static const String` members inside extensions, `static final DateTime` fields, and `static final Map` caches. Every flagged field is effectively immutable — either a compiled regex, a `const` string literal, a UTC DateTime constructed once, or a lazily-initialized lookup map. None of these are "mutable state" in any meaningful sense.

The diagnostic message recommends replacing these with "scoped state management (Provider, Riverpod, or Bloc)" — Flutter UI state management solutions that are completely irrelevant to a pure Dart utility library with no Flutter widget tree, no hot-reload lifecycle, and no UI thread.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/string/string_extensions.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_static_state
severity: 4 (warning)
message:  [avoid_static_state] Static mutable state persists across hot-reloads
          and tests, causing stale data and inconsistent behavior. Tests fail
          unpredictably due to shared state leaking between runs, and production
          bugs become hard to reproduce across different app sessions and
          isolates. {v4}
          Replace static mutable fields with scoped state management (Provider,
          Riverpod, or Bloc) to ensure proper isolation across tests and
          hot-reloads.
lines:    4:1–4:50 (top-level final RegExp _apostropheRegex)
```

## Affected Source

34 violations across 8 files in `saropa_dart_utils`:

### Top-level `final RegExp` instances (compiled regex caches)

File: `lib/string/string_extensions.dart` lines 4–35

```dart
final RegExp _apostropheRegex = RegExp("['']");
final RegExp _alphaOnlyRegex = RegExp('[^A-Za-z]');
final RegExp _alphaOnlyWithSpaceRegex = RegExp('[^A-Za-z ]');
final RegExp _alphaNumericOnlyRegex = RegExp('[^A-Za-z0-9]');
final RegExp _alphaNumericOnlyWithSpaceRegex = RegExp('[^A-Za-z0-9 ]');
final RegExp _nonDigitRegex = RegExp(r'\D');
final RegExp _regexSpecialCharsRegex = RegExp(r'[.*+?^${}()|[\]\\]');
final RegExp _consecutiveSpacesRegex = RegExp(r'\s+');
final RegExp _latinRegex = RegExp(r'^[a-zA-Z]+$');
final RegExp _splitCapitalizedUnicodeRegex = RegExp(r'(?<=\p{Ll})(?=\p{Lu}|\p{Lt})', unicode: true);
final RegExp _splitCapitalizedUnicodeWithNumbersRegex = RegExp(
  r'(?<=\p{Ll})(?=\p{Lu}|\p{Lt}|\p{Nd})|(?<=\p{Nd})(?=\p{L})',
  unicode: true,
);
final RegExp _singleCharWordRegex = RegExp(r'(?<=^|\s)[\p{L}\p{N}](?=\s|$)', unicode: true);
final RegExp _anyDigitsRegex = RegExp(r'\d');
final RegExp _curlyBracesRegex = RegExp(r'\{.+?\}');
final RegExp _lineBreakRegex = RegExp('\n');
```

### `static const String` members inside extensions

File: `lib/string/string_extensions.dart` lines 39–89

```dart
extension StringExtensions on String {
  static const String accentedQuoteOpening = '\u2018';
  static const String accentedQuoteClosing = '\u2019';
  static const String accentedDoubleQuoteOpening = '\u201C';
  static const String accentedDoubleQuoteClosing = '\u201D';
  static const String ellipsis = '\u2026';
  static const String doubleChevron = '\u00BB';
  static const String apostrophe = '\u2019';
  static const String hyphen = '\u2010';
  static const String softHyphen = '\u00ad';
  static const String newLine = '\n';
  static const String lineBreak = newLine;
  static const String blank = '\u3164';
  static const String zeroWidth = '\u200B';
  static const String nonBreakingSpace = '\u00A0';
  static const String nonBreakingHyphen = '\u2011';
  static const String bullet = '\u2022';
  static const String dot = bullet;
  static const String dotJoiner = ' $bullet ';
}
```

### `static final DateTime` (immutable date constant)

File: `lib/datetime/date_constants.dart` line 70

```dart
class DateConstants {
  static final DateTime unixEpochDate = DateTime.utc(1970);
}
```

### `static final Map` (lazily-initialized immutable lookup)

File: `lib/string/string_diacritics_extensions.dart` lines 8, 60

```dart
extension StringDiacriticsExtensions on String {
  static final Map<String, String> _reverseAccentsMap = _createReverseMap();
  static const Map<String, List<String>> _accentsMap = <String, List<String>>{...};
}
```

### Other affected files

| File | Lines | What |
|------|-------|------|
| `lib/datetime/date_time_utils.dart` | 6, 134, 138 | `final RegExp _yearRegex`; `static const double _avgDaysPerYear`; `static const double _avgDaysPerMonth` |
| `lib/datetime/time_emoji_utils.dart` | 6, 9 | `static const String sunEmoji`; `static const String moonEmoji` |
| `lib/gesture/swipe_properties.dart` | 219, 243 | `static const Map<SwipeMagnitude, double> _swipeMagnitudeThresholds`; `static const Map<SwipeSpeed, double> _swipeSpeedThresholds` |
| `lib/hex/hex_utils.dart` | 7 | `final RegExp _hexRegex = RegExp(r'^[0-9a-fA-F]+$')` |

## Root Cause

The rule flags all `static` and top-level fields that are not `const`. It treats `final` as "mutable" because the field reference is technically not a compile-time constant. However, the rule does not analyze:

1. **Whether the field type is inherently immutable.** `RegExp`, `DateTime`, `int`, `double`, `String`, and `bool` are all immutable types in Dart. A `final RegExp` can never change its pattern or flags after construction.

2. **Whether the initializer is a pure expression.** `RegExp(r'^[0-9a-fA-F]+$')` and `DateTime.utc(1970)` are deterministic, side-effect-free initializations that produce the same value every time. They are functionally equivalent to `const` but cannot use the `const` keyword because `RegExp` and `DateTime` do not have `const` constructors.

3. **Whether the package is a Flutter app.** The diagnostic recommends "Provider, Riverpod, or Bloc" — these are Flutter state management libraries. `saropa_dart_utils` is a pure Dart utility library. It has no widget tree, no `BuildContext`, no hot-reload, and no concept of "app sessions."

4. **Whether `static const` should be exempt.** Several violations are on `static const String` and `static const Map` fields, which are compile-time constants by definition and cannot possibly represent mutable state.

## Why This Is a False Positive

1. **`final` fields cannot be reassigned.** The rule's concern about "mutable state persisting across hot-reloads" is only relevant for non-final fields (e.g., `static int counter = 0;`). A `final RegExp` is assigned exactly once and never changes.

2. **The flagged types are immutable objects.** `RegExp` is immutable — once constructed, its pattern and flags never change. `DateTime.utc(1970)` is an immutable UTC timestamp. `const Map` and `const String` are compile-time constants.

3. **These are standard Dart performance patterns.** Caching compiled regex at the module level is the recommended Dart pattern for performance. Creating a new `RegExp` on every method call would be wasteful and is explicitly discouraged in Dart style guides.

4. **No Flutter dependency in the execution context.** The package has no UI thread, no hot-reload lifecycle, no widget tree. The concept of "stale data across hot-reloads" does not apply. The suggestion to use Provider/Riverpod/Bloc is architecturally impossible.

5. **`static const` is flagged despite being compile-time constant.** Fields like `static const String ellipsis = '\u2026'` are by definition not mutable state. This indicates the rule is not checking for the `const` keyword at all.

## Scope of Impact

This affects any Dart library that uses:

- **Cached `RegExp` instances** at the top level or as static fields (extremely common in string-processing libraries)
- **`static final DateTime`** for well-known dates (Unix epoch, reference dates)
- **`static final Map`** for lazily-initialized lookup tables (diacritics, transliteration, encoding maps)
- **`static const`** fields of any type inside classes or extensions

This is a foundational Dart performance pattern. The Dart SDK itself uses this pattern extensively (e.g., `RegExp` caching in `dart:core` utilities).

## Recommended Fix

### Approach A: Skip `final` fields with known-immutable types (recommended)

Add a set of types known to be immutable. If a `final` or `const` field's type is in this set, skip it:

```dart
static const Set<String> _knownImmutableTypes = <String>{
  'RegExp',
  'DateTime',
  'String',
  'int',
  'double',
  'num',
  'bool',
  'Duration',
  'Uri',
  'Type',
};

// In the visitor:
if (field.isFinal || field.isConst) {
  final String? typeName = field.fields.type?.toSource();
  if (typeName != null && _knownImmutableTypes.any(
    (String t) => typeName.contains(t),
  )) {
    return; // Known-immutable final field — not mutable state
  }
}
```

### Approach B: Always skip `const` fields

At minimum, `static const` and top-level `const` fields must be unconditionally skipped:

```dart
if (field.isConst) return; // Compile-time constant — never mutable
```

### Approach C: Check for Flutter dependency in pubspec.yaml

Only fire the rule (or at least only recommend Provider/Riverpod/Bloc) when the package actually depends on Flutter:

```dart
// If package has no flutter dependency, skip or adjust severity
if (!context.pubspec.dependsOnFlutter) {
  return; // Pure Dart library — no hot-reload, no UI thread
}
```

### Approach D: Only flag fields that are not `final`

The most conservative fix — only flag fields declared with `var`, `late`, or without `final`/`const`:

```dart
if (field.isFinal || field.isConst) return;
// Only flag: static var x = ...; or static late int x;
```

**Recommendation:** Combine Approaches A and B. Skip all `const` fields unconditionally, and skip `final` fields whose type is known-immutable. This eliminates 100% of the false positives in this project while preserving the rule's ability to catch genuinely mutable static state like `static int counter = 0;`.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Top-level final RegExp — immutable compiled regex cache.
final RegExp _good_emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w+$');

// GOOD: Static const String — compile-time constant.
class _good_Constants {
  static const String ellipsis = '\u2026';
  static const String bullet = '\u2022';
}

// GOOD: Static final DateTime — immutable date constant.
class _good_DateConstants {
  static final DateTime epoch = DateTime.utc(1970);
}

// GOOD: Static final Map created by pure function — immutable lookup.
extension _good_DiacriticsExt on String {
  static final Map<String, String> _lookup = _buildLookup();
  static Map<String, String> _buildLookup() => {'a': 'b'};
}

// GOOD: Static const Map — compile-time constant.
class _good_Thresholds {
  static const Map<String, double> values = {'low': 1.0, 'high': 10.0};
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Static non-final mutable counter — this IS problematic shared state.
// expect_lint: avoid_static_state
class _bad_Counter {
  static int count = 0;
}

// BAD: Static non-final list — can be mutated by any caller.
// expect_lint: avoid_static_state
class _bad_Registry {
  static List<String> items = [];
}

// BAD: Top-level non-final mutable state.
// expect_lint: avoid_static_state
var _bad_globalFlag = false;
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v4)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (pure Dart utility library, NOT a Flutter app)
- **Total violations:** 34 across 8 files
- **Highest concentration:** `lib/string/string_extensions.dart` (20 violations — all `final RegExp` and `static const String`)
- **Field types flagged:** `RegExp`, `String`, `DateTime`, `double`, `Map<String, String>`, `Map<String, List<String>>`, `Map<SwipeMagnitude, double>`, `Map<SwipeSpeed, double>`
- **All flagged fields are:** `final` (cannot be reassigned) or `const` (compile-time constant)
- **None are:** `var`, `late`, or non-final

## Severity

Medium-high — warning-level diagnostic with 34 violations in a single library. The false positive rate for this rule in `saropa_dart_utils` is 100% (every violation is a cached immutable value, not mutable state). The recommendation to use Provider/Riverpod/Bloc in a non-Flutter pure Dart library erodes developer trust in the linter. The volume of false positives (34 warnings) makes the rule's output noisy enough to encourage blanket suppression, which would hide any genuinely mutable static state introduced in the future.
