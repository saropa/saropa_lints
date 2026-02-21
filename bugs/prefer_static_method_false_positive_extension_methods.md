# `prefer_static_method` false positive: extension methods cannot be made static

## Status: OPEN

## Summary

The `prefer_static_method` rule (v4) fires 126 times across `saropa_dart_utils`, flagging nearly every extension method and getter in the library. The rule detects that these methods do not contain an explicit `this` reference and recommends marking them as `static`. However, **Dart extension methods cannot be static** — this is a language constraint. Extension methods always implicitly operate on `this` (the extended type's instance), even when `this` is not written explicitly.

The rule's AST analysis does not recognize that calling `isEmpty`, `length`, `every()`, `any()`, `where()`, `reduce()`, `map()`, `contains()`, `split()`, `substring()`, `toLowerCase()`, and other inherited/extended type methods within an extension body constitutes implicit `this` access. These are all invoked on the receiver object.

This is the highest-impact false positive in this project by violation count (126 violations) and likely affects every Dart project that uses extension methods.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/bool/bool_iterable_extensions.dart
owner:    _generated_diagnostic_collection_name_#2
code:     prefer_static_method
severity: 2 (info)
message:  [prefer_static_method] Method does not reference any instance members
          and could be static. Non-static methods that ignore instance state
          mislead readers into thinking the method depends on object state,
          and they prevent calling the method without an instance. {v4}
          Mark the method as static to communicate that it operates
          independently of instance state and can be called without
          constructing the class.
lines:    55:16–55:23 (getter anyTrue)
```

## Affected Source

126 violations across every extension file in the library (32 files). Representative examples:

### Extension getters on `Iterable<bool>`

File: `lib/bool/bool_iterable_extensions.dart` lines 55, 68

```dart
extension BoolIterableExtensions on Iterable<bool> {
  // Rule says these "do not reference any instance members" — but they DO,
  // via implicit `this` calls to any(), where(), and map() on Iterable<bool>

  bool get anyTrue => any((bool e) => e);       // ← triggers: any() is called on `this`
  bool get anyFalse => any((bool e) => !e);      // ← triggers: any() is called on `this`
  int get countTrue => where((bool e) => e).length;   // ← triggers: where() is on `this`
  int get countFalse => where((bool e) => !e).length; // ← triggers: where() is on `this`
  List<bool> get reverse => map((bool b) => !b).toList(); // ← triggers: map() is on `this`
}
```

The rule sees `any((bool e) => e)` and does not recognize that `any()` is an implicit `this.any()` call on the `Iterable<bool>` receiver.

### Extension methods on `DateTime`

File: `lib/datetime/date_time_extensions.dart` — 28 violations

```dart
extension DateTimeExtensions on DateTime {
  // Every method here operates on `this` (the DateTime instance)
  // but the rule does not recognize implicit this access

  DateTime? getNthWeekdayOfMonthInYear(int n, int dayOfWeek) {
    // Uses: year, month (implicit this.year, this.month)
    final DateTime firstDayOfMonth = DateTime(year, month);  // ← year and month are `this.year` etc.
    // ...
  }

  bool get isUnder13 {
    // Uses: isBefore() (implicit this.isBefore())
    return isBefore(DateTime.now().subtract(const Duration(days: 13 * 365)));
  }
}
```

### Extension methods on `String`

File: `lib/string/string_search_extensions.dart`, `lib/string/string_extensions.dart`, `lib/string/string_case_extensions.dart`, `lib/string/string_between_extensions.dart`, etc.

```dart
extension StringSearchExtensions on String {
  bool isEqualsAny(List<String>? list, {bool isCaseSensitive = true}) {
    if (isEmpty) return false;           // ← isEmpty is `this.isEmpty`
    final String find = toLowerCase();   // ← toLowerCase() is `this.toLowerCase()`
    return list.any((String item) => item.toLowerCase() == find);
  }

  bool isContainsDigits() => _containsDigitsRegex.hasMatch(this);  // ← explicit `this`
}
```

### Extension methods on `Iterable<double>`

File: `lib/double/double_iterable_extensions.dart`

```dart
extension DoubleIterableExtensions on Iterable<double> {
  double? smallestOccurrence() {
    if (isEmpty) return null;  // ← isEmpty is `this.isEmpty`
    return reduce((double value, double element) =>  // ← reduce() is `this.reduce()`
        value.compareTo(element) < 0 ? value : element);
  }
}
```

### Full list of affected files

| File | Violations | Extended type |
|------|-----------|---------------|
| `lib/bool/bool_iterable_extensions.dart` | 5 | `Iterable<bool>` |
| `lib/bool/bool_string_extensions.dart` | 2 | `String` |
| `lib/datetime/date_time_extensions.dart` | 28 | `DateTime` |
| `lib/datetime/date_constant_extensions.dart` | 2 | `DateTime` |
| `lib/datetime/date_time_nullable_extensions.dart` | 3 | `DateTime?` |
| `lib/double/double_extensions.dart` | 2 | `double` |
| `lib/double/double_iterable_extensions.dart` | 4 | `Iterable<double>` |
| `lib/enum/enum_iterable_extensions.dart` | 2 | `Iterable<Enum>` |
| `lib/int/int_extensions.dart` | 3 | `int` |
| `lib/int/int_iterable_extensions.dart` | 3 | `Iterable<int>` |
| `lib/int/int_nullable_extensions.dart` | 2 | `int?` |
| `lib/int/int_string_extensions.dart` | 2 | `String` |
| `lib/iterable/comparable_iterable_extensions.dart` | 3 | `Iterable<T extends Comparable>` |
| `lib/iterable/iterable_extensions.dart` | 6 | `Iterable<T>` |
| `lib/list/list_extensions.dart` | 8 | `List<T>` |
| `lib/list/list_nullable_extensions.dart` | 2 | `List<T>?` |
| `lib/list/list_of_list_extensions.dart` | 2 | `List<List<T>>` |
| `lib/list/make_list_extensions.dart` | 2 | `List<T>` |
| `lib/list/unique_list_extensions.dart` | 3 | `List<T>` |
| `lib/map/map_extensions.dart` | 3 | `Map<K, V>` |
| `lib/num/num_extensions.dart` | 4 | `num` |
| `lib/string/string_between_extensions.dart` | 4 | `String` |
| `lib/string/string_case_extensions.dart` | 5 | `String` |
| `lib/string/string_character_extensions.dart` | 3 | `String` |
| `lib/string/string_diacritics_extensions.dart` | 2 | `String` |
| `lib/string/string_extensions.dart` | 8 | `String` |
| `lib/string/string_nullable_extensions.dart` | 3 | `String?` |
| `lib/string/string_number_extensions.dart` | 3 | `String` |
| `lib/string/string_search_extensions.dart` | 4 | `String` |
| `lib/url/url_extensions.dart` | 3 | `String` |

## Root Cause

The rule visits `MethodDeclaration` and `PropertyAccessorDeclaration` AST nodes. For each, it checks whether the method body references any instance members (fields, getters, methods) of the enclosing class or extension. If no explicit `this` reference or explicit instance member access is found, it flags the method as "could be static."

The critical flaw is that **the rule does not account for `ExtensionDeclaration` nodes**. Inside an extension body:

1. **All unqualified method calls are implicit `this` calls.** When `BoolIterableExtensions` calls `any()`, it is calling `this.any()` where `this` is the `Iterable<bool>` receiver. The rule's `this`-reference detector does not recognize this.

2. **All unqualified property accesses are implicit `this` accesses.** `isEmpty`, `length`, `year`, `month` inside extension methods are `this.isEmpty`, `this.length`, etc.

3. **Extension methods cannot be `static` in Dart.** The Dart language specification does not allow `static` methods inside `extension` declarations (except for static members that are accessed via the extension name, which serve a completely different purpose and would not be callable on instances).

The rule likely works correctly for `class` declarations where instance members are explicitly declared, but it fails for `extension` declarations where the "instance members" come from the extended type.

## Why This Is a False Positive

1. **Extension methods cannot be made static.** The Dart language does not support `static` instance-like methods on extensions. Adding `static` to `bool get anyTrue => any((bool e) => e);` would produce a compile error. The rule's suggestion is impossible to implement.

2. **Extension methods always operate on `this`.** The entire purpose of an extension method is to be called on an instance: `[true, false].anyTrue`. Making it static would require changing the call syntax to `BoolIterableExtensions.anyTrue([true, false])`, which is not how Dart extensions work and would not compile.

3. **Implicit `this` is not detected by the rule.** When an extension method calls `any()`, `where()`, `isEmpty`, `length`, `toLowerCase()`, `year`, etc., these are all dispatched on the receiver (`this`). The rule's AST analysis only checks for explicit `this` keyword or explicit instance field/method references defined in the enclosing declaration. Since extension types "inherit" their members from the extended type, the rule misses them.

4. **100% false positive rate on extension methods.** Every single one of the 126 violations is on an extension method or getter. This is not a precision issue — the rule fundamentally misunderstands Dart extensions.

5. **126 violations constitute extreme noise.** This volume of false positives in a single library makes the rule effectively useless, as developers will either suppress it globally or ignore all info-level diagnostics.

## Scope of Impact

**Every Dart project that uses extension methods is affected.** Extension methods are a core Dart language feature introduced in Dart 2.7 (2019). They are used extensively in:

- The Flutter SDK itself (`BuildContextExtensions`, `ColorExtensions`, etc.)
- All major Dart packages (`collection`, `path`, `http`, etc.)
- Every project following modern Dart idioms

The false positive rate for this rule on extension methods is 100%. There is no way to write an extension method that the rule would correctly skip, because the rule does not understand the `extension` declaration.

## Recommended Fix

### Approach A: Skip all methods inside `ExtensionDeclaration` (recommended, simplest)

Add a parent-node check at the beginning of the visitor:

```dart
// In the MethodDeclaration / PropertyAccessorDeclaration visitor:
if (node.parent is ExtensionDeclaration) {
  return; // Extension methods cannot be static — skip unconditionally
}
```

This is a one-line fix that eliminates 100% of the false positives for extension methods.

### Approach B: Recognize implicit `this` in extensions (more thorough)

Enhance the `this`-reference detection to understand that unqualified method and property calls inside `extension` bodies are implicit `this` calls:

```dart
// When inside an ExtensionDeclaration, check if any unqualified identifier
// resolves to a member of the extended type
if (node.parent is ExtensionDeclaration) {
  final ExtensionDeclaration ext = node.parent as ExtensionDeclaration;
  final DartType? extendedType = ext.extendedType.type;
  if (extendedType != null) {
    // Check if any unqualified identifier in the method body is a member
    // of the extended type
    final bool usesExtendedMembers = _referencesExtendedTypeMembers(
      node.body, extendedType,
    );
    if (usesExtendedMembers) return;
  }
}
```

This is more complex but would also correctly handle the rare case of extension methods that truly do not access the receiver (though such methods are extremely unusual and arguably a code smell for a different reason).

### Approach C: Allow `static` only for extension methods that do not access receiver

If a method inside an `extension` block truly does not access the receiver at all (no implicit or explicit `this`), it could theoretically be a `static` member. However, this is so rare that Approach A (skip all) is more practical:

```dart
// Only flag extension methods if they truly have zero receiver access
// AND static extension members are syntactically valid for this use case
// (they serve a different purpose in Dart, so this is almost never correct)
```

**Recommendation:** Approach A is strongly recommended. It is a single-line fix with zero false negatives, because the suggestion to "make it static" is never valid for extension methods. This should be the **highest priority fix** for `prefer_static_method` as it affects 126 violations in this project alone and will affect every Dart project using extensions.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Extension getter using implicit this — cannot be static.
extension _good_IterableExt<T> on Iterable<T> {
  bool get isNotNullOrEmpty => isNotEmpty;  // isNotEmpty is this.isNotEmpty
}

// GOOD: Extension method using implicit this via inherited method.
extension _good_StringExt on String {
  String reversed() => split('').reversed.join('');  // split() is this.split()
}

// GOOD: Extension method calling this.method() explicitly.
extension _good_ListExt<T> on List<T> {
  T? safeFirst() => isEmpty ? null : this[0];
}

// GOOD: Extension method with no explicit `this` but implicit receiver access.
extension _good_BoolListExt on Iterable<bool> {
  bool get allTrue => every((bool b) => b);  // every() is this.every()
  int get trueCount => where((bool b) => b).length;  // where() is this.where()
}

// GOOD: Extension method on nullable type.
extension _good_NullableStringExt on String? {
  bool get isNullOrEmpty => this == null || this!.isEmpty;
}
```

### Existing BAD cases (should still trigger — class methods, not extensions)

```dart
// BAD: Class method that does not use any instance state — could be static.
// expect_lint: prefer_static_method
class _bad_Helper {
  int add(int a, int b) => a + b;  // No instance state referenced
}

// BAD: Class method that only uses parameters — could be static.
// expect_lint: prefer_static_method
class _bad_Formatter {
  String format(String value) => value.trim().toUpperCase();
}
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v4)
- **Dart SDK:** >=3.9.0 <4.0.0
- **Trigger project:** `D:\src\saropa_dart_utils` (Dart utility library — 32 extension files)
- **Total violations:** 126 across 30 extension files
- **False positive rate on extensions:** 100% (every violation is on an extension method/getter)
- **Affected AST node types:** `MethodDeclaration` and `PropertyAccessorDeclaration` inside `ExtensionDeclaration`
- **Dart language constraint:** `static` methods inside `extension` blocks serve a different purpose and cannot replace instance extension methods

## Severity

**High** — info-level diagnostic, but with 126 violations this is by far the noisiest false positive in the project. The rule fundamentally misunderstands Dart extension methods, which are a core language feature used in every modern Dart project. The fix is trivial (one-line parent-node check) and would immediately eliminate a massive source of false positives across all projects analyzed by saropa_lints. This should be prioritized as a **critical fix** because:

1. It affects every Dart project using extensions (which is nearly all of them)
2. The suggestion to "make it static" is impossible to follow
3. The volume of violations (126 in a single library) degrades trust in the linter
4. The fix is simple and has zero risk of false negatives
