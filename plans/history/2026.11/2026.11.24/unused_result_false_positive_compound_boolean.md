# BUG: `unused_result` — False positive in compound boolean expressions

**Status: Open**

Created: 2026-11-23
Rule: `unused_result` (Dart SDK analyzer, NOT saropa_lints)
Severity: False positive
Source: `dartAnalysisLSP` / `dart`

---

## Summary

The Dart analyzer's `unused_result` lint fires on `@useResult`-annotated getters and methods when their return value is consumed inside a compound boolean expression (`&&`, `||`, `!`). The value IS used as an operand — the analyzer fails to track usage through boolean operators.

---

## Attribution

This is a **Dart SDK analyzer** diagnostic, not a saropa_lints rule. Owner: `dartAnalysisLSP`, source: `dart`.

```
grep -rn "'unused_result'" lib/src/rules/
# Expected: zero matches — rule is not defined in saropa_lints
```

Filed here for tracking since it affects saropa_dart_utils and the `// ignore:` suppressions reference this report.

---

## Affected Patterns (10 instances in saropa_dart_utils)

### Pattern 1: `@useResult` getter in `&&` / `||` return

```dart
// num_extensions.dart — isNotNullZeroOrNegative
@useResult
bool get isNotNullZeroOrNegative {
  final value = this;
  return value != null && value.isNotZeroOrNegative; // FALSE POSITIVE
}

// num_extensions.dart — isNullZeroOrNegative
@useResult
bool get isNullZeroOrNegative {
  final value = this;
  return value == null || value.isZeroOrNegative; // FALSE POSITIVE
}
```

### Pattern 2: `@useResult` method in `if` condition

```dart
// date_time_utils.dart — monthDayCount / monthDayCountSafe
if (month == 2 && isLeapYear(year: year)) { ... } // FALSE POSITIVE
if (year != null && isLeapYear(year: year)) { ... } // FALSE POSITIVE

// json_utils.dart — tryJsonDecodeListMap / tryJsonDecodeList
if (value == null || !isJson(value)) return null; // FALSE POSITIVE
```

### Pattern 3: `@useResult` getter in `.where()` callback

```dart
// string_case_extensions.dart — capitalizedWords / unCapitalizedWords
?.where((String word) => word.isNotEmpty && word[0].isAllLetterUpperCase) // FALSE POSITIVE
?.where((String word) => word.isNotEmpty && word[0].isAllLetterLowerCase) // FALSE POSITIVE
```

### Pattern 4: `@useResult` method in control flow

```dart
// string_text_extensions.dart — pluralize
if (length > 2 && this[length - 2].isVowel()) { ... } // FALSE POSITIVE

// string_text_extensions.dart — cropToWord
while (cropped.isNotEmpty && !cropped.endsWithAny(...)) { ... } // FALSE POSITIVE
```

---

## Workaround

Each site uses `// ignore: unused_result` on the line above.

---

## Root Cause

The Dart analyzer's `@useResult` checker does not follow value flow through short-circuit boolean operators. The annotated call's return value is consumed as an operand of `&&`, `||`, or prefix `!`, but the checker sees only the immediate statement context and flags the call as "unused".

---

## Closed (2026-11-24)

Not a saropa_lints rule. `unused_result` is the Dart SDK `@useResult` diagnostic from package:meta (source `dart`); no rule in lib/ emits it. Report upstream to dart-lang/sdk.
