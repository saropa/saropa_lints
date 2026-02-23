# Bug: `avoid_duplicate_string_literals` false positive on domain-inherent string values

## Resolution

**Fixed.** Added `_domainLiterals` exempt set (`true`, `false`, `null`, `none`) to both `AvoidDuplicateStringLiteralsRule` and `AvoidDuplicateStringLiteralsPairRule`. Self-documenting domain vocabulary is no longer flagged.


## Summary

The `avoid_duplicate_string_literals` rule flags the string literals `'true'`
and `'false'` appearing multiple times in a file whose sole purpose is
converting between `String` and `bool` types. These string values are the
**domain vocabulary** of bool-string conversion — they cannot be avoided, and
extracting them to named constants adds indirection without improving clarity.

## Severity

**False positive** -- the rule's advice ("Extract this string to a named
constant for maintainability") is counterproductive here. The literals `'true'`
and `'false'` are:

1. **Self-documenting** — no named constant is clearer than the literal itself
2. **Domain-inherent** — a bool-to-string converter must reference these values
3. **Impossible to get wrong** — `'true'` and `'false'` are universally
   understood; a named constant like `kTrueString` adds noise

## Reproduction

### Minimal example

```dart
/// Saropa extensions for converting [String] to [bool]
extension BoolStringExtensions on String {
  /// Converts a case-insensitive 'true' or 'false' to a boolean.
  /// Returns null if not 'true' or 'false'.
  bool? toBoolNullable() {
    if (toLowerCase() == 'true') {     // occurrence 1
      return true;
    } else if (toLowerCase() == 'false') {
      return false;
    }
    return null;
  }

  /// Converts 'true' to boolean true, everything else to false.
  // FLAGGED: avoid_duplicate_string_literals_pair (line 17)
  bool toBool() => toLowerCase() == 'true';  // occurrence 2
}

extension BoolStringNullableExtensions on String? {
  /// Converts 'true' to boolean true, everything else to false.
  // FLAGGED: avoid_duplicate_string_literals (line 25)
  // FLAGGED: avoid_duplicate_string_literals_pair (line 25)
  bool toBool() => this?.toLowerCase() == 'true';  // occurrence 3
}
```

### What the rule suggests vs. reality

```dart
// What the rule wants:
class _BoolStrings {
  static const String trueValue = 'true';
  static const String falseValue = 'false';
}

bool toBool() => toLowerCase() == _BoolStrings.trueValue;

// What this actually achieves:
// ❌ More indirection (reader must look up _BoolStrings.trueValue)
// ❌ More lines of code
// ❌ The constant name `trueValue` is LESS clear than the literal `'true'`
// ❌ No maintainability benefit — the string 'true' will never change
```

### Lint output

```
line 17 col 37 • [avoid_duplicate_string_literals_pair] String literal
appears 2+ times in this file. Consider extracting to a constant. {v1}

line 25 col 43 • [avoid_duplicate_string_literals] String literal appears
3+ times in this file. Consider extracting to a constant. {v1}
```

### All affected locations (3 instances across 2 rules)

| File | Line | Literal | Rule variant | Occurrences |
|------|------|---------|-------------|-------------|
| `lib/bool/bool_string_extensions.dart` | 17 | `'true'` | `_pair` (2+) | 3 total |
| `lib/bool/bool_string_extensions.dart` | 25 | `'true'` | base (3+) | 3 total |
| `lib/bool/bool_string_extensions.dart` | 25 | `'true'` | `_pair` (2+) | 3 total |

## Root cause

The rule counts string literal occurrences per file without considering:

1. **Whether the literal is self-documenting**: Short, universally understood
   strings like `'true'`, `'false'`, `''`, `' '`, `','`, `'.'`, `'\n'` gain
   nothing from extraction to a named constant.

2. **Whether the file's domain inherently requires the literal**: A
   bool-string converter MUST compare against `'true'` and `'false'`. These
   are not "magic strings" — they are the canonical string representations
   defined by Dart's `bool.toString()`.

3. **Whether extraction improves maintainability**: The rule assumes
   duplication means "if one changes, all must change." But `'true'` will
   never change its meaning. The string `'true'` is to bool parsing what
   `0` is to number validation — a fundamental constant of the domain.

## Suggested fix

### Option A: Exempt well-known language/framework literals

Maintain a set of string literals that are universally understood and should
not be flagged regardless of repetition:

```dart
static const _exemptLiterals = <String>{
  'true', 'false',       // Boolean literals
  '', ' ', '\n', '\t',   // Whitespace/empty
  ',', '.', ':', ';',    // Punctuation
  '(', ')', '[', ']',    // Brackets
  '{', '}', '<', '>',
  'null',                // Null literal
  '0', '1', '-1',        // Common numbers as strings
};

void checkStringLiteral(StringLiteral node) {
  final value = node.stringValue;
  if (value != null && _exemptLiterals.contains(value)) {
    return; // Self-documenting literal — do not flag
  }
  // ... existing counting logic
}
```

### Option B: Exempt short strings (≤5 characters)

Very short strings are inherently self-documenting. A named constant for a
1-5 character string rarely improves readability:

```dart
void checkStringLiteral(StringLiteral node) {
  final value = node.stringValue;
  if (value != null && value.length <= 5) {
    return; // Too short to benefit from extraction
  }
  // ... existing counting logic
}
```

### Option C: Higher threshold for short strings

Instead of flagging at 2-3 occurrences for all strings, use a higher threshold
for short strings:

```dart
int getThreshold(String value) {
  if (value.length <= 3) return 6;   // Very short: flag at 6+
  if (value.length <= 5) return 4;   // Short: flag at 4+
  return 2;                          // Normal: flag at 2+
}
```

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Boolean parsing — 'true'/'false' are domain constants
bool parse1(String s) => s == 'true';
bool parse2(String s) => s.toLowerCase() == 'true';
bool? parse3(String s) => s == 'true' ? true : s == 'false' ? false : null;

// Separator characters used multiple times
String clean(String s) => s.replaceAll(',', '').replaceAll('.', '');

// Empty string checks
bool isEmpty1(String? s) => s == null || s == '';
bool isEmpty2(String? s) => s?.trim() == '';

// Should STILL flag (true positives, no change):

// Long duplicate strings — likely should be constants
String getEndpoint() => 'https://api.example.com/v2';
String getBackup() => 'https://api.example.com/v2';

// Domain-specific strings that could change
String getLabel() => 'Submit Order';
String getTitle() => 'Submit Order';

// Error messages
void validate() {
  throw Exception('Invalid configuration');
}
void check() {
  throw Exception('Invalid configuration');
}
```

## Impact

Any file that performs string-based parsing, formatting, or comparison will
use domain-specific string literals repeatedly. Common examples:

- Bool parsing: `'true'`, `'false'`
- CSV/JSON processing: `','`, `'"'`, `'null'`
- Date parsing: `'-'`, `'/'`, `'T'`
- Path processing: `'/'`, `'.'`, `'..'`
- URL parsing: `'://'`, `'?'`, `'&'`, `'='`

These are all self-documenting literals where extraction to named constants
reduces readability rather than improving it.
