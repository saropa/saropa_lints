# Task: `prefer_raw_strings`

## Summary
- **Rule Name**: `prefer_raw_strings`
- **Tier**: Professional
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Code Quality

## Problem Statement
Dart string literals support escape sequences such as `\n` (newline), `\t` (tab), and
`\\` (literal backslash). When a string contains many backslash characters — common in
regular expressions, file paths (on Windows), and certain data formats — each literal
backslash must be written as `\\`. This leads to visually noisy and error-prone strings:

```dart
final regex = RegExp('\\d{3}-\\d{2}-\\d{4}');  // hard to read
```

Dart provides raw string literals (`r'...'` or `r"..."`) that treat backslash as a
literal character with no escape processing:

```dart
final regex = RegExp(r'\d{3}-\d{2}-\d{4}');    // clear and readable
```

When a non-raw string contains `\\` sequences and none of those sequences need to be
interpreted escape sequences (i.e., the intent is always a literal backslash), the raw
string form is cleaner, more readable, and eliminates a class of subtle bugs where a
developer writes `\d` instead of `\\d` in a regex.

## Description (from ROADMAP)
Flag non-raw string literals that contain `\\` (escaped backslash) sequences that would
be more clearly expressed as raw strings.

## Trigger Conditions
1. A `SimpleStringLiteral` node where `isRaw == false`.
2. The string value (not the lexeme) contains a literal backslash — i.e., the source
   text contains at least one `\\`.
3. The string does NOT contain any escape sequences that cannot be represented in a raw
   string: `\n`, `\r`, `\t`, `\b`, `\f`, `\v`, `\0`, `\xHH`, `\uHHHH`, `\u{HHHH}`,
   or `\'`/`\"` (when needed for the string delimiter). A raw string cannot represent
   these — converting would change meaning.
4. The string does NOT contain `$` with a variable reference (though `\$` in a raw string
   is fine — raw strings still allow `$` literally; it is interpolation that changes).
   Wait: raw strings DO suppress `$` interpolation. If the string contains `${expr}` or
   `$name` interpolation, it must remain non-raw.
5. Optionally: threshold on number of `\\` occurrences. Fire only when there are ≥2
   double-backslash sequences to avoid flagging trivial cases. (Configurable threshold.)

## Implementation Approach

### AST Visitor
```dart
context.registry.addSimpleStringLiteral((node) { ... });
```

### Detection Logic
1. Check `node.isRaw == false` (skip already-raw strings).
2. Check `node.isSynthetic == false` (skip synthetic strings from codegen).
3. Retrieve `node.lexeme` (the source text including quotes).
4. Check that `\\` (two consecutive backslash characters in source) appears in the
   lexeme. Note: in the lexeme, a literal double-backslash `\\` represents a single
   backslash in the string value.
5. Check for disqualifying escape sequences in the lexeme: `\n`, `\r`, `\t`, `\b`,
   `\f`, `\v`, `\0`, `\x`, `\u`. If any are present, the string cannot be converted
   to raw — skip.
6. Check that the lexeme does NOT contain string interpolation (`${` or `$[a-zA-Z_]`).
   Raw strings suppress interpolation — conversion would change meaning.
7. Count the number of `\\` occurrences. If below threshold (default: 1), skip.
8. Report the `SimpleStringLiteral` node.

For multiline strings (`'''` and `"""`), apply the same logic — raw multiline strings
(`r'''` and `r"""`) are valid Dart.

## Code Examples

### Bad (triggers rule)
```dart
// Regex: hard to read with double escapes
final ssn = RegExp('\\d{3}-\\d{2}-\\d{4}');

// Windows path (hardcoded for illustration)
final path = 'C:\\Users\\Admin\\Documents';

// LaTeX fragment
final latex = '\\frac{1}{2} + \\sqrt{x}';

// Simple single-escape case (threshold = 1)
final newline = '\\n is a newline character';  // describing \n, not using it
```

### Good (compliant)
```dart
// Raw string — clear and readable
final ssn = RegExp(r'\d{3}-\d{2}-\d{4}');

final path = r'C:\Users\Admin\Documents';

final latex = r'\frac{1}{2} + \sqrt{x}';

// ok: string uses actual escape sequence — cannot be raw
final tab = 'column1\tcolumn2';

// ok: string uses interpolation — cannot be raw
final greeting = 'Hello, $name!';

// ok: already raw
final pattern = r'\d+';

// ok: single \\ with threshold = 2 (does not meet threshold)
final esc = '\\';
```

## Edge Cases & False Positives
- **Strings with real escape sequences**: Any string using `\n`, `\t`, `\r`, `\0`,
  `\xHH`, `\uHHHH`, `\u{HHHH}` cannot be converted to a raw string — skip these entirely.
- **Strings with interpolation**: `'Hello $name'` — interpolation is suppressed in raw
  strings. Do not flag any string with `$varname` or `${expr}` interpolation.
- **Mixed escape and backslash**: `'C:\\path\nline2'` — contains both `\\` and `\n`.
  Cannot be raw — skip.
- **`\$` literal**: A non-raw string can suppress interpolation with `\$`. If the string
  contains `\$`, it likely needs to remain non-raw for that suppression. Skip.
- **Adjacent string literals**: Dart allows adjacent string literals that are
  concatenated: `'foo' 'bar'`. Each literal is a separate AST node; analyze each
  independently.
- **String in const context**: Raw strings are valid in const contexts. No special
  handling needed.
- **`StringInterpolation` nodes**: These are not `SimpleStringLiteral` — they are
  `InterpolationString` within `StringInterpolation`. Do not flag these (they cannot
  be raw because they contain interpolation).
- **Multiline raw strings**: `r'''` and `r"""` are valid. When flagging a `'''` string,
  suggest `r'''` as the fix.
- **The `\` at end of line (line continuation)**: Not valid in Dart strings (Dart does
  not have line-continuation backslash). Not an issue.
- **Threshold tuning**: The default threshold of 1 (flag any string with a `\\`) may
  produce noise. Consider defaulting to 2 and making it configurable.
- **Generated files**: String literals in generated files (`.g.dart`, `.freezed.dart`)
  often contain regex patterns. Consider suppressing for generated files or flagging
  at a lower severity.

## Unit Tests

### Should Trigger (violations)
```dart
void test1() {
  final r1 = RegExp('\\d+\\.\\d+');  // LINT: use r'\d+\.\d+'
  final r2 = '\\w+@\\w+\\.\\w+';    // LINT: email-like regex
}
```

### Should NOT Trigger (compliant)
```dart
void test2() {
  final ok1 = r'\d+\.\d+';            // ok: already raw
  final ok2 = 'Hello\nWorld';         // ok: \n is a real escape
  final ok3 = 'Name: $name';          // ok: interpolation — can't be raw
  final ok4 = 'single backslash: \\'; // ok: single occurrence below threshold (if threshold=2)
  final ok5 = '\u0041';               // ok: unicode escape — can't be raw
}
```

## Quick Fix
**Convert the non-raw string to a raw string by adding the `r` prefix and removing double backslashes.**

```dart
// Before
final regex = RegExp('\\d{3}-\\d{2}-\\d{4}');

// After
final regex = RegExp(r'\d{3}-\d{2}-\d{4}');
```

The fix:
1. Identifies the opening quote (single or double, or triple).
2. Inserts `r` before the opening quote.
3. Replaces all `\\` occurrences in the string body with `\`.

The source range for the replacement covers the entire string literal lexeme.
When using `addSimpleReplacement`, compute the raw string value by replacing all `\\`
in the source lexeme body with `\`.

Take care: the replacement must not alter the surrounding code. The fix only touches
the string literal node's source range.

## Notes & Issues
- Dart's `SimpleStringLiteral.value` gives the interpreted string (backslashes already
  processed); `SimpleStringLiteral.lexeme` gives the source text (including quotes and
  escape characters). Use `lexeme` for detection and fix generation.
- The check for disqualifying escape sequences should search the raw lexeme (source text),
  not the processed value, to detect `\n`, `\t`, etc. Specifically, look for the
  two-character sequences `\n`, `\t`, etc. in the source (not in the runtime value, which
  would be a newline character).
- The rule name `prefer_raw_strings` is short and idiomatic. Alternatives considered:
  `prefer_raw_string_literals`, `use_raw_strings_for_regex`.
- This rule pairs well with `avoid_string_concatenation` since complex string building
  often involves regex patterns that would benefit from raw strings.
- Consider a variant for `StringInterpolation` nodes where each non-interpolated fragment
  (`InterpolationString`) contains `\\` — though converting interpolated strings to raw
  is not possible, a companion message could suggest refactoring to concatenation.
