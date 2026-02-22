# `no_empty_string` false positive: standard Dart idiom for empty string literals

## Status: RESOLVED

## Summary

The `no_empty_string` rule (v6) flags all occurrences of empty string literals (`''` or `""`) in source code, recommending `.isEmpty` or `.isNotEmpty` for comparisons. However, the rule fires on ALL uses of empty strings, not just comparisons. It flags default parameter values, return values, fallback values in null-coalescing expressions, and string identity elements in concatenation -- contexts where `.isEmpty` is either syntactically impossible or semantically incorrect.

In `saropa_dart_utils` -- a string utility library where empty strings are fundamental building blocks -- this rule produces pervasive false positives across the codebase. The empty string `''` is the most basic Dart string idiom and is not discouraged by the Dart style guide or Effective Dart.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/double/double_extensions.dart
owner:    _generated_diagnostic_collection_name_#2
code:     no_empty_string
severity: 2 (info)
message:  [no_empty_string] Using empty string literals ("") in your code can
          be ambiguous and may indicate a missing value or a placeholder.
          Relying on empty strings for logic can lead to subtle bugs and makes
          intent unclear to readers. {v6}
          Instead of using empty string literals directly, use .isEmpty or
          .isNotEmpty for string comparisons. This makes your intent explicit
          and your code more robust.
line:     91
```

Estimated violations across the project: 78+ (based on the affected files listed below).

## Affected Source

### Return value: empty string as fallback (line 91)

File: `lib/double/double_extensions.dart` line 91

```dart
// Remove trailing zeros, then remove trailing decimal point if present
return result.replaceAll(_trailingZerosRegex, '').replaceAll(_trailingDecimalPointRegex, '');
//                                             ^^                                        ^^
// Both empty strings are the replacement argument to replaceAll().
// They mean "replace the match with nothing" -- this is standard Dart.
// You CANNOT use .isEmpty here -- it is a replacement value, not a comparison.
```

### Return value: guard return for empty input (lines 126, 141, 156)

File: `lib/string/string_case_extensions.dart` lines 126, 141, 156

```dart
/// Converts the first character to lowercase.
String lowerCaseFirstChar() => isEmpty ? '' : this[0].toLowerCase() + substringSafe(1);
//                                       ^^
// Returns empty string for empty input. Cannot use .isEmpty as a return value.

/// Converts the first character to uppercase.
String upperCaseFirstChar() => isEmpty ? '' : this[0].toUpperCase() + substringSafe(1);
//                                       ^^
// Same pattern -- guard against empty input, return empty string.

/// Converts to title case.
String titleCase() => isEmpty ? '' : this[0].toUpperCase() + substringSafe(1).toLowerCase();
//                              ^^
// Same pattern.
```

### Guard condition: comparing parameter to empty string (line 160)

File: `lib/string/string_between_extensions.dart` line 160

```dart
String between(String start, String end, {bool endOptional = true, bool trim = true}) {
  if (isEmpty || start.isEmpty) return '';   // ← triggers (return value)
  //                                   ^^
  final int startIndex = indexOf(start);
  if (startIndex == -1) return '';            // ← triggers (return value)
  //                           ^^
  // ...
  return '';                                  // ← triggers (fallback return)
}
```

### Null-coalescing fallback (line 109)

File: `lib/list/list_of_list_extensions.dart` line 109

```dart
result.write(this[i].map((dynamic e) => e?.toString() ?? '').join(','));
//                                                        ^^
// Null-coalescing to empty string: if element is null, use '' as placeholder.
// Cannot use .isEmpty -- this is a fallback VALUE, not a comparison.
```

### String formatting: empty replacement in replaceAll (line 34)

File: `lib/map/map_extensions.dart` line 34

```dart
String formatMap() {
  if (isEmpty) return '';  // ← triggers (return value)
  //                  ^^
  // ...
}
```

### Default parameter value

Common pattern across many files:

```dart
// Standard Dart pattern: default separator is empty string
String join([String separator = '']) => ...;
//                              ^^
// Cannot use .isEmpty as a default parameter value.
// This is how Dart's own Iterable.join() works.
```

## Root Cause

The rule flags all occurrences of empty string literals (`''` or `""`) regardless of context. Its diagnostic message says "use `.isEmpty` or `.isNotEmpty` for string comparisons," but the rule does not limit itself to comparison contexts. It fires on:

| Context | Example | Can use .isEmpty? | Is a comparison? |
|---|---|---|---|
| Equality comparison | `if (value == '')` | Yes (equivalent) | Yes |
| Return value | `return ''` | No | No |
| Default parameter | `String sep = ''` | No | No |
| Null-coalescing | `x ?? ''` | No | No |
| Replacement argument | `replaceAll(regex, '')` | No | No |
| String concatenation | `condition ? 'text' : ''` | No | No |
| Guard return | `if (isEmpty) return ''` | No (already uses isEmpty) | No |

Out of these seven contexts, `.isEmpty` is applicable to only ONE (equality comparison). The rule fires on all seven, producing false positives in six of them.

### The rule's premise is also debatable for comparisons

Even for `if (value == '')`, the Dart style guide does not prefer `.isEmpty` over `== ''`. Both are idiomatic:

- `value == ''` -- explicit, readable, familiar from most programming languages
- `value.isEmpty` -- slightly more Dart-idiomatic, but functionally identical

The official Dart linter has `prefer_is_empty` for Iterable/Map contexts, but even that rule does not flag `String == ''` comparisons as errors.

## Why This Is a False Positive

1. **Empty string `''` is standard Dart idiom** -- the Dart language specification, style guide, and standard library all use empty string literals extensively. `Iterable.join()` defaults to `''`. `String.replaceAll()` uses `''` as "replace with nothing."

2. **The rule fires in contexts where `.isEmpty` is syntactically impossible** -- you cannot write `String separator = .isEmpty` as a default parameter, or `return .isEmpty` as a return value. The correction message is inapplicable to the majority of flagged sites.

3. **For a string utility library, empty strings are fundamental** -- `saropa_dart_utils` provides string manipulation methods. Empty strings appear as guard returns, identity elements, default values, and separator defaults. Flagging them all is like flagging `0` in a math library.

4. **No bug risk** -- the diagnostic claims empty strings "can lead to subtle bugs," but there is no evidence that `return ''` or `?? ''` causes bugs. The empty string is a well-defined value with clear semantics.

5. **The alternative adds verbosity with no clarity gain** -- replacing `return ''` with `return String.empty` (if such a constant existed) or extracting `const String _empty = ''` would add boilerplate without improving readability or safety.

6. **78+ violations produce significant noise** -- in a string utility library, this volume of false positives drowns out genuinely useful diagnostics.

## Scope of Impact

Virtually every Dart project uses empty string literals. Common patterns that will trigger false positives:

- **String processing:** Any method that returns `''` as a default/fallback
- **Formatting:** `replaceAll(pattern, '')` to remove matches
- **Joining:** `join('')` to concatenate without separator
- **Default parameters:** `String separator = ''`, `String prefix = ''`
- **Null safety:** `value ?? ''` to provide non-null fallback
- **Guard returns:** `if (isEmpty) return ''`
- **Builder patterns:** `StringBuffer` with conditional appends using empty alternatives

This affects all Dart codebases, but especially string processing libraries, formatters, parsers, and text manipulation utilities.

## Recommended Fix

### Approach A: Only flag equality comparisons (minimal)

Restrict the rule to contexts where `.isEmpty` is actually an alternative:

```dart
// Only fire on:
if (expression is BinaryExpression) {
  if (expression.operator.type == TokenType.EQ_EQ ||
      expression.operator.type == TokenType.BANG_EQ) {
    // Check if one side is an empty string literal
    // Suggest: value.isEmpty instead of value == ''
    // Suggest: value.isNotEmpty instead of value != ''
  }
}
// Do NOT fire on: return '', ?? '', default params, replaceAll args, etc.
```

### Approach B: Whitelist non-comparison contexts

Explicitly skip contexts where empty strings are unavoidable:

```dart
// Skip if the empty string appears in:
// 1. Default parameter value
// 2. Return statement
// 3. Right side of ?? (null-coalescing)
// 4. Argument to a method call (e.g., replaceAll, join)
// 5. Conditional expression alternative (ternary)
final AstNode parent = node.parent;
if (parent is DefaultFormalParameter) return;
if (parent is ReturnStatement) return;
if (parent is BinaryExpression && parent.operator.type == TokenType.QUESTION_QUESTION) return;
if (parent is ArgumentList) return;
if (parent is ConditionalExpression) return;
```

### Approach C: Retire the rule

The empty string `''` is not a code smell in Dart. Unlike magic numbers or magic strings, the empty string has a universal, unambiguous meaning. No mainstream Dart linter flags it. Consider removing this rule from the recommended tier entirely, or making it opt-in only.

**Recommendation:** Approach A is the minimum viable fix. Approach B provides more comprehensive coverage. Approach C is worth considering given the very low signal-to-noise ratio of this rule.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Default parameter value.
void join([String separator = '']) {}

// GOOD: Return value for empty input guard.
String process(String input) {
  if (input.isEmpty) return '';
  return input.toUpperCase();
}

// GOOD: Null-coalescing fallback.
String safe(String? value) => value ?? '';

// GOOD: Replacement argument in replaceAll.
String clean(String text) => text.replaceAll(RegExp(r'\s+'), '');

// GOOD: Ternary alternative (identity element).
String sign(double value) => value >= 0 ? '' : '-';

// GOOD: Guard return in extension method.
extension on String {
  String firstChar() => isEmpty ? '' : this[0];
}
```

### Existing BAD cases (could trigger -- debatable)

```dart
// DEBATABLE: Equality comparison where .isEmpty is clearer.
// expect_lint: no_empty_string
bool check(String value) => value == '';

// DEBATABLE: Inequality comparison where .isNotEmpty is clearer.
// expect_lint: no_empty_string
bool hasValue(String value) => value != '';
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v6)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\saropa_dart_utils` (pure Dart utility library, not a Flutter app)
- **Trigger files (estimated 78+ violations):**
  - `lib/double/double_extensions.dart` -- line 91 (replaceAll argument)
  - `lib/html/html_utils.dart` -- line 125 (return fallback)
  - `lib/list/list_of_list_extensions.dart` -- line 109 (null-coalescing)
  - `lib/map/map_extensions.dart` -- line 34 (guard return)
  - `lib/string/string_between_extensions.dart` -- 11+ (guard returns, comparisons)
  - `lib/string/string_case_extensions.dart` -- lines 126, 141, 156 (guard returns)
  - Plus many more across the codebase
- **Rule severity:** info

## Severity

Medium -- info-level diagnostic, but with 78+ violations it represents significant noise. The rule fires in contexts where its own correction advice (use `.isEmpty`) is syntactically impossible, which makes the diagnostic confusing and unhelpful. For a string utility library, the false positive rate approaches 90%+ since the vast majority of empty string usages are return values, fallbacks, and replacement arguments -- not comparisons. The rule should be scoped to comparison contexts only, or retired from the recommended tier.
