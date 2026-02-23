# `prefer_cached_getter` false positive: extension getters cannot cache values

## Status: RESOLVED

## Summary

The `prefer_cached_getter` rule (v5) fires on getter definitions inside `extension` declarations, recommending that the getter result be "stored in a local variable if called multiple times." However, Dart extensions **cannot have instance fields** -- there is nowhere to store a cached value. The rule does not distinguish between getters in `ClassDeclaration` nodes (where caching in a field is possible) and getters in `ExtensionDeclaration` nodes (where caching is structurally impossible).

In `saropa_dart_utils`, this produces 10 violations across core extension files, all of which are unfixable without restructuring the code into classes -- defeating the purpose of extensions.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/datetime/date_time_extensions.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_cached_getter
severity: 2 (info)
message:  [prefer_cached_getter] Repeated getter calls recompute expensive
          values each time, wasting CPU cycles when caching would suffice.
          {v5} Store the getter result in a local variable if called multiple
          times.
line:     43 (and 549, 714, 719, 724, 729, 734, 785)
```

```
resource: /D:/src/saropa_dart_utils/lib/datetime/date_time_utils.dart
code:     prefer_cached_getter
severity: 2 (info)
lines:    34, 215
```

## Affected Source

### Extension getter on `DateTime` (line 43)

File: `lib/datetime/date_time_extensions.dart`

```dart
extension DateTimeExtensions on DateTime {
  DateTime? getNthWeekdayOfMonthInYear(int n, int dayOfWeek) {
    if (n < 1) {
      return null;
    }

    final DateTime firstDayOfMonth = DateTime(year, month);  // ← line 43: triggers
    // Rule says: "Store the getter result in a local variable"
    // But `year` and `month` ARE already single property accesses on
    // the DateTime instance -- there is no cheaper way to access them.
    // ...
  }
}
```

### Extension getter for age calculation (line 785)

File: `lib/datetime/date_time_extensions.dart`

```dart
extension DateTimeExtensions on DateTime {
  // ...
  int? ageInYears({DateTime? fromDate}) {
    // ...
    int age = fromDate.year - year;

    // line 785: triggers on `month` and `day` getter access
    if (month > fromDate.month || (month == fromDate.month && day > fromDate.day)) {
      age--;
    }
    return age;
  }
}
```

### Extension getter for alignment (lines 714-734)

File: `lib/datetime/date_time_extensions.dart`

```dart
extension DateTimeExtensions on DateTime {
  DateTime alignDateTime({required Duration alignment, bool roundUp = false}) {
    if (alignment == Duration.zero) {
      return this;
    }

    final Duration correction = Duration(
      hours: alignment.inDays > 0
          ? hour                           // ← line 714: triggers
          : alignment.inHours > 0
          ? hour % alignment.inHours       // triggers
          : 0,
      minutes: alignment.inHours > 0
          ? minute                         // ← line 719: triggers
          : alignment.inMinutes > 0
          ? minute % alignment.inMinutes   // triggers
          : 0,
      seconds: alignment.inMinutes > 0
          ? second                         // ← line 724: triggers
          : alignment.inSeconds > 0
          ? second % alignment.inSeconds   // triggers
          : 0,
      milliseconds: alignment.inSeconds > 0
          ? millisecond                    // ← line 729: triggers
          : alignment.inMilliseconds > 0
          ? millisecond % alignment.inMilliseconds  // triggers
          : 0,
      microseconds: alignment.inMilliseconds > 0 ? microsecond : 0,  // line 734
    );
    // ...
  }
}
```

The `hour`, `minute`, `second`, `millisecond`, and `microsecond` getters are accessed on `this` (the `DateTime` instance). In an extension, `this` refers to the extended type's instance. These are trivial property reads from `DateTime`'s internal fields -- not expensive computations. There is no field in the extension to cache them to, and caching in a local variable would only save nanoseconds for a direct field read.

### Static class context (line 34)

File: `lib/datetime/date_time_utils.dart`

```dart
class DateTimeUtils {
  static int? ageInYears({required DateTime dob, DateTime? dod}) {
    dod ??= DateTime.now();
    // ...
    int age = dod.year - dob.year;   // ← line 34: triggers on `.year` access
    if (dod.month < dob.month || (dod.month == dob.month && dod.day < dob.day)) {
      age--;
    }
    return age;
  }
}
```

Here `dob.year`, `dob.month`, `dob.day` etc. are read from method parameters -- not getters on `this`. The values cannot be cached in instance fields because this is a `static` method. The only option would be local variables, but `dob.year` is already the cheapest possible read (a final field on DateTime).

## Root Cause

The rule detects getters that are accessed multiple times within a method body and recommends caching the result. However:

1. **Extension getters cannot be cached in fields** -- extensions in Dart cannot declare instance fields. The only storage available is local variables within the method, which the developer is already using where appropriate.

2. **The flagged getters are trivial property reads** -- `DateTime.year`, `.month`, `.day`, `.hour`, `.minute`, `.second`, `.millisecond` are all direct field accesses on a `DateTime` object. They are O(1) with no computation. The "wasting CPU cycles" diagnostic is misleading.

3. **The rule does not check the AST node type** -- it does not distinguish `ExtensionDeclaration` from `ClassDeclaration`, treating all getter access sites identically regardless of whether caching is architecturally possible.

4. **Static method context is also affected** -- even in a regular class, `static` methods cannot cache to instance fields, so the rule's suggestion is inapplicable there as well.

## Why This Is a False Positive

1. **Caching is structurally impossible in extensions** -- Dart extensions cannot have instance fields. The rule recommends an action that cannot be performed without abandoning the extension pattern entirely.

2. **The flagged accesses are trivial** -- reading `.year`, `.month`, `.day` from a `DateTime` is a direct field read, not an "expensive" computation. The performance benefit of caching is negligible (nanoseconds at most).

3. **The diagnostic message is misleading** -- "wasting CPU cycles when caching would suffice" implies significant overhead that does not exist for final field reads.

4. **The correction message is ambiguous** -- "Store the getter result in a local variable if called multiple times" is already the standard practice where it matters. For 2-3 accesses of a trivial getter, local variable extraction reduces readability without meaningful performance gain.

5. **All 10 violations in this project are in extensions or static methods** -- 100% false positive rate for this codebase.

## Scope of Impact

Any Dart project using extension methods extensively will encounter this false positive. Extension methods are a core Dart language feature recommended by the Dart team for API discoverability. Common patterns affected:

- Extension getters on `DateTime` (`.year`, `.month`, `.day`, `.hour`)
- Extension getters on `String` (`.length`, `.isEmpty`)
- Extension getters on numeric types
- Extension getters on `Iterable` (`.length`, `.isEmpty`, `.first`, `.last`)
- Static methods accessing parameters multiple times

This is particularly impactful for utility libraries like `saropa_dart_utils` where extensions are the primary API pattern.

## Recommended Fix

### Approach A: Skip `ExtensionDeclaration` nodes (recommended)

Do not fire the rule when the enclosing declaration is an `ExtensionDeclaration`:

```dart
// Before checking getter accesses, verify the enclosing context supports caching
final AstNode? enclosing = node.thisOrAncestorOfType<ExtensionDeclaration>();
if (enclosing != null) return;  // Extensions cannot have fields
```

### Approach B: Also skip static methods

Extend the check to skip static methods, which also cannot cache to instance fields:

```dart
final MethodDeclaration? method = node.thisOrAncestorOfType<MethodDeclaration>();
if (method != null && method.isStatic) return;
```

### Approach C: Only flag expensive getters

Instead of flagging all repeated getter access, only flag getters that involve non-trivial computation (method calls, iterations, allocations). Simple property access on `final` fields should be excluded.

**Recommendation:** Approach A is the minimum fix. Ideally, combine A + B + C for the most accurate results.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Extension getter accessing DateTime properties -- cannot cache.
extension on DateTime {
  bool get isMorning => hour >= 6 && hour < 12;
}

// GOOD: Extension method accessing `this` properties multiple times.
extension on DateTime {
  String get dateOnly =>
      '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

// GOOD: Static method accessing parameter properties multiple times.
class DateUtils {
  static int yearDiff(DateTime a, DateTime b) => b.year - a.year;
}

// GOOD: Simple getter on final fields in a class (trivial computation).
class Point {
  final double x;
  final double y;
  Point(this.x, this.y);
  double get sum => x + y;
}
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Class with mutable fields -- getter recomputes from changing state.
class DataBuffer {
  List<int> data = [];

  // expect_lint: prefer_cached_getter
  int get total => data.fold(0, (a, b) => a + b);
}

// BAD: Expensive computation that should be cached.
class PathParser {
  final String raw;
  PathParser(this.raw);

  // expect_lint: prefer_cached_getter
  List<String> get segments => raw.split('/').where((s) => s.isNotEmpty).toList();
}
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v5)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\saropa_dart_utils` (pure Dart utility library, not a Flutter app)
- **Trigger files:**
  - `lib/datetime/date_time_extensions.dart` lines 43, 549, 714, 719, 724, 729, 734, 785 (8 violations)
  - `lib/datetime/date_time_utils.dart` lines 34, 215 (2 violations)
- **Total violations from this rule:** 10 (all false positives in this project)
- **Rule severity:** info
- **Impact classification:** high (per violation JSON)

## Severity

Medium -- info-level diagnostic with 10 violations. All 10 violations in this project are false positives because every flagged site is either in an extension (cannot have fields) or a static method (cannot access instance fields). The diagnostic recommends an action that is structurally impossible in the affected code, which erodes developer trust. The "wasting CPU cycles" message overstates the cost of trivial property reads from final fields.
