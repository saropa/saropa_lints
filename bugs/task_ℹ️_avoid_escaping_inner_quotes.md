# Task: `avoid_escaping_inner_quotes`

## Summary
- **Rule Name**: `avoid_escaping_inner_quotes`
- **Tier**: Stylistic
- **Severity**: INFO
- **Status**: Planned
- **Source**: ROADMAP.md §Style

## Problem Statement
When a string literal contains quote characters that match the string's delimiter, those characters must be escaped with a backslash. This escaping is unnecessary when the alternative quote character (single vs. double) could be used as the delimiter — the inner quotes would then require no escaping at all.

Unnecessary escape sequences:
1. **Reduce readability** — backslashes interrupt the visual flow of the string
2. **Are error-prone** — it is easy to miss or misplace a backslash, especially in multiline strings
3. **Confuse readers** who must mentally parse escape sequences to understand the string's content

Dart supports both single (`'`) and double (`"`) quote delimiters, making it straightforward to avoid inner-quote escaping in most cases. The Dart style guide recommends single quotes by default, but allows double quotes specifically to avoid inner-quote escaping.

## Description (from ROADMAP)
Detects string literals that use backslash-escaped quote characters (`\'` or `\"`) when switching the string delimiter would eliminate the need for escaping.

## Trigger Conditions
- A `SimpleStringLiteral` node (not raw, not multiline)
- The literal uses single quote delimiters and contains one or more `\'` escape sequences, AND contains no `\"` characters (so switching to double quotes would eliminate all quote escaping)
- OR: The literal uses double quote delimiters and contains one or more `\"` escape sequences, AND contains no `'` characters (so switching to single quotes would eliminate all quote escaping)

## Implementation Approach

### AST Visitor
```dart
context.registry.addSimpleStringLiteral((node) {
  // ...
});
```

### Detection Logic
1. Skip raw strings (`r'...'`) — escape sequences have no meaning in raw strings.
2. Skip multiline strings (`'''...'''`, `"""..."""`) — these have different conventions.
3. Retrieve the literal's token source: `node.literal.lexeme`.
4. Determine the quote character from the first character of the lexeme.
5. If quote is `'`:
   - Count occurrences of `\'` (escaped single quote) in the lexeme.
   - Count occurrences of `"` (unescaped double quote) in the string value.
   - If `\'` count > 0 AND `"` count == 0: report. Switching to `"` would eliminate all escaping.
6. If quote is `"`:
   - Count occurrences of `\"` (escaped double quote) in the lexeme.
   - Count occurrences of `'` (unescaped single quote) in the string value.
   - If `\"` count > 0 AND `'` count == 0: report. Switching to `'` would eliminate all escaping.
7. Do NOT report if switching would introduce new escaping (both types of quotes present).

## Code Examples

### Bad (triggers rule)
```dart
// Single-quoted string with escaped apostrophe — switch to double quotes.
final message = 'It\'s a beautiful day'; // LINT

// Single-quoted string with multiple escaped quotes.
final text = 'Don\'t panic, it\'s fine'; // LINT

// Double-quoted string with escaped double quotes.
final json = "The key is \"name\""; // LINT

// Single-quoted with escaped quote in interpolation context — still lintable.
final label = 'User\'s name'; // LINT

// String with escaped quote in a const.
const String kTitle = 'Alice\'s Restaurant'; // LINT
```

### Good (compliant)
```dart
// Use double quotes to avoid escaping the apostrophe.
final message = "It's a beautiful day";

// Use double quotes for the whole set.
final text = "Don't panic, it's fine";

// Use single quotes to avoid escaping double quotes.
final json = 'The key is "name"';
final label = "User's name";
const String kTitle = "Alice's Restaurant";

// String contains BOTH quote types — escaping is unavoidable.
final mixed = 'It\'s called "Dart"'; // OK — no way to avoid escaping one
final mixed2 = "It's called \"Dart\""; // OK — same string, different choice

// Raw string — no escape sequences apply.
final raw = r'It\'s not escaped'; // OK — raw string

// Multiline string — different conventions apply.
final multi = '''
  It's fine here, no escaping needed.
'''; // OK — triple quotes
```

## Edge Cases & False Positives
- **Both quote types present**: `'It\'s called "Dart"'` — both `'` and `"` appear. Switching quote style replaces one escape with another. Do NOT flag — there is no improvement available.
- **Raw strings**: `r'can\'t'` — in a raw string, `\'` is not an escape sequence; it is a literal backslash followed by an apostrophe. Do not flag raw strings at all.
- **Multiline strings**: `'''it's fine'''` — triple-quoted strings have their own escaping rules and readability conventions. Skip multiline strings.
- **Interpolated strings**: `'$name\'s item'` — this is a `StringInterpolation` node, not a `SimpleStringLiteral`. The rule targets `SimpleStringLiteral` nodes. If extending to interpolated strings, treat the literal parts with the same logic.
- **Adjacent strings**: `'It\'s ' 'a test'` — each adjacent part is a separate `SimpleStringLiteral`. Apply the rule per-part: if one part can switch quotes to avoid escaping without conflicting with the adjacent parts, flag it.
- **Unicode escapes**: `'\u0027'` is a valid way to write an apostrophe without using a quote character. Do not flag this — it is a legitimate alternative.
- **`\n`, `\t`, other escape sequences**: Strings containing backslash-n, backslash-t, etc. (non-quote escapes) are not affected by switching quote style. The rule focuses only on quote-character escaping.
- **Generated code**: Skip `*.g.dart`, `*.freezed.dart`.

## Unit Tests

### Should Trigger (violations)
```dart
// Test 1: apostrophe in single-quoted string
const t1 = 'It\'s time'; // LINT

// Test 2: multiple apostrophes
const t2 = 'Don\'t, can\'t, won\'t'; // LINT

// Test 3: escaped double-quote in double-quoted string
const t3 = "Say \"hello\""; // LINT

// Test 4: escaped quote in non-const
String t4() => 'User\'s data'; // LINT
```

### Should NOT Trigger (compliant)
```dart
// Test 5: no escaped quotes
const t5 = 'Hello world';
const t6 = "Hello world";

// Test 6: both quote types — unavoidable
const t7 = 'It\'s "complicated"'; // No lint

// Test 7: raw string
const t8 = r'It\'s raw'; // No lint

// Test 8: multiline string
const t9 = '''It's a multiline string'''; // No lint

// Test 9: already uses the better quote
const t10 = "It's fine"; // No lint
```

## Quick Fix
**Message**: "Switch to {double/single} quotes to avoid escaping"

The fix should:
1. Change the opening and closing delimiter from `'` to `"` (or vice versa).
2. Remove all `\'` (or `\"`) escape sequences, replacing them with the unescaped character.
3. Ensure no new escape sequences are introduced (the pre-check in the detection logic guarantees this).

Example:
```dart
// Before:
'It\'s a beautiful day'
// After:
"It's a beautiful day"
```

```dart
// Before:
"The key is \"name\""
// After:
'The key is "name"'
```

The fix must handle:
- Multiple escape sequences in one string
- Other escape sequences (`\n`, `\t`, `\\`) that must be preserved
- The quote character appearing at the very start or end of the string content

## Notes & Issues
- This is a Stylistic-tier rule — it is purely about readability, not correctness or performance. It should be opt-in.
- The Dart style guide recommends single quotes as the default, but explicitly notes that double quotes are acceptable to avoid inner apostrophe escaping. The fix should prefer switching to double quotes when the string contains apostrophes (matching real-world natural language patterns) and switching to single quotes when the string contains double quotes (matching JSON-like strings).
- A project may have an existing convention (e.g., always use double quotes). The rule should respect the `analysis_options.yaml` `prefer_double_quotes` / `prefer_single_quotes` lint if enabled — suppress this rule if one of those is already enforced, to avoid conflicting guidance.
- The rule name `avoid_escaping_inner_quotes` clearly communicates the intent. An alternative name `prefer_quote_style_for_literals` is less precise.
