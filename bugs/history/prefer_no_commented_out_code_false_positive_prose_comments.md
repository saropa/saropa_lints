# Bug: `prefer_no_commented_out_code` false positives on prose comments and section headers

## Summary

The `prefer_no_commented_out_code` rule (v5) incorrectly flags several
categories of legitimate comments as "commented-out code":

1. **Inline prose comments** explaining code behavior (e.g., `// this is non-null, other is null`)
2. **Section header comments** organizing barrel file exports (e.g., `// Iterable extensions`)
3. **Dartdoc continuation lines** that happen to contain code-like words (e.g., `/// existing one.`)
4. **Explanatory comments** describing what the next line of code does (e.g., `// Iterate over each row in the matrix`)

The rule's message says "Prose comments and special markers like TODO, FIXME,
and test directives are automatically skipped" but the prose detection is not
working correctly for these common comment patterns.

## Severity

**False positive** -- 11 of 14 flagged instances across 7 files are legitimate
prose comments, not commented-out code. Only 2 are actual commented-out code.

## Reproduction

### Example 1: Inline prose comment flagged as code

**File:** `lib/list/list_extensions.dart`, line 34

```dart
if (other == null) return false; // this is non-null, other is null
```

The trailing comment `// this is non-null, other is null` is an explanatory
note about the guard clause. It is not commented-out code.

### Example 2: Section header comments in barrel file

**File:** `lib/saropa_dart_utils.dart`, lines 47, 54, 61, 73

```dart
// Iterable extensions
export 'iterable/comparable_iterable_extensions.dart';
export 'iterable/iterable_extensions.dart';

// JSON utilities
export 'json/json_utils.dart';

// List extensions
export 'list/list_extensions.dart';
...

// Map extensions and utilities
export 'map/map_extensions.dart';
...

// String extensions and utilities
export 'string/string_analysis_extensions.dart';
```

All four flagged lines are section header comments used to organize exports
by category. They contain no code syntax whatsoever.

### Example 3: Prose comment containing the word "this"

**File:** `lib/int/int_nullable_extensions.dart`, line 18

```dart
// this is smaller
if (self == null) {
  return -1;
}
```

The comment `// this is smaller` explains the semantics of the branch.
The word "this" refers to the concept of "this value", not the Dart `this`
keyword.

### Example 4: Algorithmic explanation comments

**File:** `lib/enum/enum_iterable_extensions.dart`, line 103

```dart
List<T> sortedEnumValues() =>
    // Map the list of enum values to a list of their names as strings
    toList()
      // Sort the list of names in alphabetical order
      ..sort((T a, T b) => a.name.compareTo(b.name));
```

Both inline comments are prose explanations of the chained method calls.

### Example 5: Dartdoc lines flagged as code

**File:** `lib/map/map_extensions.dart`, lines 193 and 210

```dart
/// Uses an immutable approach: creates a new list rather than mutating the
/// existing one.
```

These are `///` dartdoc lines that are being flagged. Dartdoc should never
trigger this rule.

### Example 6: Multi-line prose comment

**File:** `lib/list/list_of_list_extensions.dart`, line 40

```dart
// Use expand() method to flatten the 2D list and create a
// new set with the same elements as this iterable
final List<T>? result = expand((List<T> e) => e).toUnique(ignoreNulls: ignoreNulls);
```

This is a two-line prose explanation of the algorithm. It mentions method
names (`expand()`) in a prose context, which likely triggers the false
positive.

## Full list of false positives

| File | Line | Content | Why it's a false positive |
|------|------|---------|--------------------------|
| `list/list_extensions.dart` | 34 | `// this is non-null, other is null` | Inline prose explaining guard clause |
| `saropa_dart_utils.dart` | 47 | `// Iterable extensions` | Section header |
| `saropa_dart_utils.dart` | 54 | `// List extensions` | Section header |
| `saropa_dart_utils.dart` | 61 | `// Map extensions and utilities` | Section header |
| `saropa_dart_utils.dart` | 73 | `// String extensions and utilities` | Section header |
| `int/int_nullable_extensions.dart` | 18 | `// this is smaller` | Prose (not Dart `this` keyword) |
| `enum/enum_iterable_extensions.dart` | 103 | `// Map the list of enum values...` | Algorithmic prose explanation |
| `list/list_of_list_extensions.dart` | 40 | `// Use expand() method to flatten...` | Prose mentioning method name |
| `list/list_of_list_extensions.dart` | 115 | `// Iterate over each row in the matrix` | Prose description of loop |
| `map/map_extensions.dart` | 193 | `/// existing one.` | Dartdoc line |
| `map/map_extensions.dart` | 210 | `/// Uses an immutable approach...` | Dartdoc line |

## Root cause

The rule's heuristic for distinguishing prose from code appears too aggressive.
Possible causes:

1. **Comments containing method-like words** (e.g., "expand()", "Map") are
   being classified as code even when used in prose context
2. **Section header comments** that are short and contain type-like words
   (e.g., "Iterable", "List", "Map", "String") are misidentified as code
3. **Dartdoc lines (`///`)** are not being excluded properly -- the rule
   description says prose is skipped, but dartdoc lines are still flagged
4. **The word "this"** in a prose comment triggers code detection

## Suggested fix

1. **Exclude `///` dartdoc comments entirely** -- dartdoc is documentation by
   definition, not commented-out code
2. **Improve prose heuristics** to recognize:
   - Section headers (short comments without code syntax like `()`, `{}`, `;`)
   - Inline trailing comments after code statements
   - Comments that form complete English sentences
3. **Add a whitelist for common prose words** that overlap with Dart keywords:
   `this`, `return`, `null`, `true`, `false`, `is`, `in`, `for`, `if`, `else`
4. **Require stronger code indicators** before flagging: look for balanced
   parentheses, semicolons, assignment operators, or type annotations rather
   than just keyword presence

## Resolution

**Fixed in v5.0.3.** Three changes to `CommentPatterns` in `comment_utils.dart`:
1. **Tightened standalone keyword pattern**: `this`, `super`, `new`, `else`, `case`, `finally` now require code-like syntax after them (e.g. `this.x`, `new MyClass`), not bare keywords in prose
2. **Tightened type-name pattern**: type names now require code punctuation after the identifier (e.g. `String name;`), preventing "Map the list" or "Iterable extensions" from matching
3. **Added prose guard with strong-code-indicator bypass**: comments with 3+ words and 2+ common English function words are treated as prose, unless the comment contains balanced parentheses, semicolons, `=>`, or braces

## Environment

- saropa_lints version: latest (v5 of this rule)
- Dart SDK: 3.x
- Project: saropa_dart_utils
