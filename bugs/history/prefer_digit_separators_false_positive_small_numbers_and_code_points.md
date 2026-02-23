# Bug: `prefer_digit_separators` flags 5-digit numbers where separators reduce clarity

## Resolution

**Fixed.** Threshold raised from 10,000 (5+ digits) to 100,000 (6+ digits) to match common style guide recommendations.


## Summary

The `prefer_digit_separators` rule flags the numeric literal `56327` (a Unicode
code point constant) and recommends adding digit separators (`56_327`). However:

1. Five-digit numbers are at the boundary of readability — most style guides
   only mandate separators for 6+ digit numbers.
2. Unicode code points are conventionally written as unseparated integers or
   in hexadecimal (`0xDC07`). Adding decimal digit separators to a code point
   creates a false sense of "thousands grouping" that has no semantic meaning
   in the Unicode context.

## Severity

**False positive (borderline)** -- the separator `56_327` implies a
thousands-grouping (`56 thousand, 327`) which is irrelevant for a Unicode code
point. The conventional representation would be hex (`0xDC07`) or an
unseparated decimal. The rule's threshold is too aggressive for 5-digit numbers.

## Reproduction

### Minimal example

```dart
extension StringExtensions on String {
  /// The Unicode replacement character code point for invalid sequences.
  // FLAGGED: prefer_digit_separators
  //          "Large number should use digit separators"
  static const int _invalidUnicodeReplacementRuneCode = 56327;
}
```

### Why separators don't help here

```dart
// Current (clear — it's a code point):
static const int _invalidUnicodeReplacementRuneCode = 56327;

// With separators (misleading — implies thousands grouping):
static const int _invalidUnicodeReplacementRuneCode = 56_327;

// Conventional alternative (hex — standard for code points):
static const int _invalidUnicodeReplacementRuneCode = 0xDC07;
```

The value `56327` is a Unicode code point (U+DC07). In the Unicode domain,
numbers are identified by their full decimal or hex value, not by their
thousands-place grouping. Writing `56_327` would be unusual and potentially
confusing to anyone familiar with Unicode conventions.

### Lint output

```
line 654 col 57 • [prefer_digit_separators] Large number should use digit
separators. Digit separators improve readability of large numbers. This
numeric literal usage can cause precision errors or make the intended value
unclear. {v4}
```

### All affected locations (1 instance)

| File | Line | Value | Context |
|------|------|-------|---------|
| `lib/string/string_extensions.dart` | 654 | `56327` | Unicode code point constant |

## Root cause

The rule flags any numeric literal above a certain digit count (apparently 5+
digits) without considering:

1. **The number's domain**: Code points, port numbers, HTTP status codes, and
   other domain-specific identifiers are conventionally written without
   separators regardless of digit count.

2. **The threshold**: Five digits is at the readability boundary. Most
   industry style guides (Google Java, Kotlin, Swift) recommend separators
   for 6+ or 7+ digit numbers, not 5-digit numbers.

3. **Whether the number represents a quantity**: Digit separators are helpful
   for quantities (`1_000_000` = one million) because the thousands grouping
   maps to how we read quantities. For identifiers (code points, addresses,
   IDs), the grouping has no semantic meaning.

## Suggested fix

### Option A: Raise threshold to 6+ digits

Only flag numeric literals with 6 or more digits. Five-digit numbers
(10,000–99,999) are at the readability boundary and commonly written without
separators:

```dart
void checkIntegerLiteral(IntegerLiteral node) {
  final String text = node.literal.lexeme;
  // Only flag 6+ digit numbers (100,000+)
  if (text.length < 6) return;  // Currently triggers at 5
  // ... existing logic
}
```

### Option B: Exempt named constants with domain-specific context

If the number is assigned to a `const` variable whose name contains domain
keywords (`rune`, `code`, `point`, `port`, `status`, `id`, `address`, `offset`),
skip the rule:

```dart
final domainKeywords = {'rune', 'code', 'point', 'port', 'status',
                        'id', 'address', 'offset', 'index'};

void checkIntegerLiteral(IntegerLiteral node) {
  // Check if assigned to a domain-specific constant
  final parent = node.parent;
  if (parent is VariableDeclaration) {
    final name = parent.name.lexeme.toLowerCase();
    if (domainKeywords.any((kw) => name.contains(kw))) {
      return; // Domain identifier — separators don't add clarity
    }
  }
  // ... existing logic
}
```

### Option C: Suggest hex for code points

For code-point-like contexts, suggest hex notation (`0xDC07`) rather than
decimal with separators. This is the standard representation in Unicode
documentation and tools.

## Test cases to add

```dart
// Should NOT flag (false positives to fix):

// Unicode code point (5 digits, domain-specific)
const int replacementChar = 56327;

// Port number
const int httpsPort = 44300;

// 5-digit ID
const int maxUserId = 99999;

// HTTP status (3 digits, but extended example)
const int errorCode = 10404;

// Should STILL flag (true positives, no change):

// Large quantity without separators
const int population = 1000000;  // FLAGGED: should be 1_000_000

// Financial amount
const int maxCents = 999999;  // FLAGGED: should be 999_999

// Duration in milliseconds
const int timeoutMs = 300000;  // FLAGGED: should be 300_000

// 7+ digit number
const int bigNumber = 1234567;  // FLAGGED: should be 1_234_567
```

## Impact

Any codebase with Unicode processing, network programming, or ID-based
constants will see false positives on 5-digit numeric literals. The current
threshold casts too wide a net and flags numbers that are readable without
separators.
