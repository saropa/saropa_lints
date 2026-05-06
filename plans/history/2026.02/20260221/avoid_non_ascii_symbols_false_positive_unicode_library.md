# `avoid_non_ascii_symbols` false positive: Unicode processing library requires non-ASCII characters

**Integrated 2026-03-02:** Rule DartDoc exempt (invisible/confusable only), CHANGELOG_ARCHIVE intent, false_positive_fixes_test group.

## Status: RESOLVED

## Resolution

Narrowed detection from all non-ASCII characters to a curated set of invisible/confusable code points (zero-width, invisible formatters, non-standard whitespace, directional overrides).

## Summary

The `avoid_non_ascii_symbols` rule (v4) flags all non-ASCII characters in Dart source files, recommending replacement with ASCII equivalents or Unicode escape sequences. In `saropa_dart_utils` -- a **text processing and Unicode utility library** -- this produces hundreds of false positives across files whose entire purpose is to define, map, and process non-ASCII characters: emoji constants, HTML entity tables, diacritics mappings, and typographic symbols.

The rule cannot distinguish between accidental non-ASCII (invisible spaces, homoglyphs) and intentional non-ASCII that constitutes the library's core functionality.

## Diagnostic Output

```
resource: /D:/src/saropa_dart_utils/lib/datetime/time_emoji_utils.dart
owner:    _generated_diagnostic_collection_name_#2
code:     avoid_non_ascii_symbols
severity: 2 (info)
message:  [avoid_non_ascii_symbols] String contains non-ASCII characters.
          Non-ASCII characters can cause encoding issues and may be hard to
          distinguish visually (e.g., different types of spaces). {v4}
          Replace non-ASCII characters with ASCII equivalents or Unicode escape
          sequences (e.g., \u00E9 for e-acute).
line:     6, column 34
```

Estimated violations across the project: 400+ (extrapolated from affected files below).

## Affected Source

### Emoji constants (2 violations)

File: `lib/datetime/time_emoji_utils.dart` lines 6, 9

```dart
class TimeEmojiUtils {
  /// Emoji representing the sun (sun emoji).
  static const String sunEmoji = '☀️';   // ← line 6: triggers
  /// Emoji representing the moon (moon emoji).
  static const String moonEmoji = '🌙';  // ← line 9: triggers
}
```

These are the library's public API constants for day/night emoji representation. Replacing `'☀️'` with `'\u2600\uFE0F'` would make the code unreadable and harder to maintain with zero functional benefit.

### Infinity symbols in formatDouble (2 violations)

File: `lib/double/double_extensions.dart` line 81

```dart
String formatDouble(int decimalPlaces, {bool showTrailingZeros = true}) {
  if (isNaN) return 'NaN';
  if (isInfinite) return isNegative ? '-∞' : '∞';  // ← line 81: triggers (2x)
  // ...
}
```

The infinity symbol `∞` (`\u221E`) is the mathematically correct representation. Replacing it with `'\u221E'` obscures intent.

### HTML entity mapping (27+ violations)

File: `lib/html/html_utils.dart` lines 12-46

```dart
const Map<String, String> _htmlEntities = <String, String>{
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&nbsp;': '\u00A0',       // non-breaking space -- already escaped
  '&copy;': '\u00A9',       // ← triggers (copyright symbol in escape form)
  '&reg;': '\u00AE',        // ← triggers (registered symbol)
  '&trade;': '\u2122',      // ← triggers (trademark symbol)
  '&euro;': '\u20AC',       // ← triggers (euro sign)
  '&pound;': '\u00A3',      // ← triggers (pound sign)
  '&yen;': '\u00A5',        // ← triggers (yen sign)
  '&cent;': '\u00A2',       // ← triggers (cent sign)
  '&bull;': '\u2022',       // ← triggers (bullet)
  '&hellip;': '\u2026',     // ← triggers (horizontal ellipsis)
  '&ndash;': '\u2013',      // ← triggers (en dash)
  '&mdash;': '\u2014',      // ← triggers (em dash)
  '&lsquo;': '\u2018',      // ← triggers (left single quote)
  '&rsquo;': '\u2019',      // ← triggers (right single quote)
  '&ldquo;': '\u201C',      // ← triggers (left double quote)
  '&rdquo;': '\u201D',      // ← triggers (right double quote)
  '&laquo;': '\u00AB',      // ← triggers (left guillemet)
  '&raquo;': '\u00BB',      // ← triggers (right guillemet)
  '&times;': '\u00D7',      // ← triggers (multiplication sign)
  '&divide;': '\u00F7',     // ← triggers (division sign)
  '&frac12;': '\u00BD',     // ← triggers (fraction one-half)
  '&frac14;': '\u00BC',     // ← triggers (fraction one-quarter)
  '&frac34;': '\u00BE',     // ← triggers (fraction three-quarters)
};
```

Note: These are ALREADY using Unicode escape sequences (`\u00A9` etc.) which are pure ASCII in source text, yet the rule still triggers. This suggests the rule checks the Dart AST's resolved `stringValue` property (which converts escapes to actual Unicode code points) rather than the raw source text. This is a secondary bug: the rule should inspect source characters, not resolved string values, to avoid flagging properly escaped Unicode.

### Typographic constants (15+ violations)

File: `lib/string/string_extensions.dart` lines 39-82

```dart
extension StringExtensions on String {
  static const String accentedQuoteOpening = '\u2018';     // ' — triggers
  static const String accentedQuoteClosing = '\u2019';     // ' — triggers
  static const String accentedDoubleQuoteOpening = '\u201C'; // " — triggers
  static const String accentedDoubleQuoteClosing = '\u201D'; // " — triggers
  static const String ellipsis = '…';                      // ← triggers
  static const String doubleChevron = '»';                 // ← triggers
  static const String apostrophe = '\u2019';               // ' — triggers
  static const String hyphen = '‐';                        // ← triggers (Unicode hyphen)
  static const String softHyphen = '\u00ad';               // ← triggers
  static const String blank = 'ㅤ';                        // ← triggers (Hangul filler)
  static const String zeroWidth = '\u200B';                // ← triggers
  static const String nonBreakingSpace = '\u00A0';         // ← triggers
  static const String nonBreakingHyphen = '\u2011';        // ← triggers
  static const String bullet = '\u2022';                   // ← triggers
}
```

These constants ARE the library's product. `StringExtensions` provides typographic utilities for text formatting -- the non-ASCII characters are the entire point.

### Diacritics mapping (300+ violations)

File: `lib/string/string_diacritics_extensions.dart`

```dart
static const Map<String, List<String>> _accentsMap = <String, List<String>>{
  'A': ['À', 'Á', 'Â', 'Ã', 'Ä', 'Å'],   // ← 6 triggers per line
  'a': ['à', 'á', 'â', 'ã', 'ä', 'å'],     // ← 6 triggers per line
  'C': ['Ç'],
  'c': ['ç'],
  'E': ['È', 'É', 'Ê', 'Ë'],
  // ... hundreds more diacritical character mappings ...
};
```

This map is the core data structure for the `removeDiacritics()` method. Replacing every accented character with a `\uXXXX` escape would transform a readable, maintainable mapping into an impenetrable wall of hex codes. For example:

- **Current:** `'A': ['À', 'Á', 'Â', 'Ã', 'Ä', 'Å']`
- **"Fixed":** `'A': ['\u00C0', '\u00C1', '\u00C2', '\u00C3', '\u00C4', '\u00C5']`

The escaped version is strictly worse for maintainability and code review.

## Root Cause

The rule flags ALL non-ASCII characters in string literals without considering:

1. **Whether the non-ASCII character is intentional** -- assigned to a named `const` field, clearly part of a data mapping, or used in a library whose purpose is Unicode processing.

2. **Whether the character is visible and identifiable** -- the rule's own message acknowledges "different types of spaces" as the primary concern, but it flags ALL non-ASCII including clearly visible emoji, mathematical symbols, and accented letters.

3. **Whether Unicode escape sequences are already used** -- some flagged constants already use `\uXXXX` form (e.g., `'\u00A9'` for copyright), yet the rule still fires. This indicates the rule inspects the AST's resolved `stringValue` rather than the raw source text, flagging escape sequences that are pure ASCII in source code.

4. **The project type** -- a utility library that processes Unicode text fundamentally requires non-ASCII characters in its source code.

## Why This Is a False Positive

1. **The library's core purpose is Unicode text processing** -- non-ASCII characters are the product, not an accident. Flagging them is like flagging `import 'dart:math'` in a math library.

2. **Readability is strictly worse with escape sequences** -- `'☀️'` is instantly recognizable; `'\u2600\uFE0F'` requires a Unicode table lookup. The diacritics map with 500+ characters would become unmaintainable.

3. **The rule's stated concern does not apply** -- "encoding issues" and "hard to distinguish visually" apply to invisible characters (zero-width spaces, homoglyphs), not to visible emoji, mathematical symbols, and accented letters.

4. **Test files require non-ASCII for correctness** -- tests for Unicode handling must contain non-ASCII strings to verify behavior. Escaping them provides no safety benefit.

5. **Scale of impact makes the rule unusable** -- with 400+ violations, the rule cannot be enabled for this project type without producing overwhelming noise that buries legitimate warnings.

## Scope of Impact

Any Dart library or project dealing with:

- **Unicode text processing** -- diacritics removal, normalization, transliteration
- **Internationalization (i18n)** -- locale-specific characters, translated strings
- **Emoji support** -- emoji constants, emoji parsing, emoji rendering
- **HTML processing** -- entity decoding, HTML-to-text conversion
- **Typography** -- smart quotes, dashes, special punctuation
- **Character encoding** -- UTF-8/UTF-16 handling, code point manipulation

This includes a large proportion of non-trivial Dart packages on pub.dev.

## Recommended Fix

### Approach A: Only flag invisible or confusable characters (recommended)

Narrow the rule to its stated purpose -- catching characters that "may be hard to distinguish visually":

```dart
// Only flag characters that are genuinely dangerous:
// - Zero-width characters: \u200B, \u200C, \u200D, \uFEFF
// - Invisible formatters: \u00AD (soft hyphen), \u2060 (word joiner)
// - Homoglyphs: Cyrillic а (U+0430) vs Latin a (U+0061)
// - Non-standard whitespace: \u00A0, \u2000-\u200A, \u202F, \u205F, \u3000
//
// Do NOT flag:
// - Visible emoji (Unicode emoji category)
// - Accented Latin characters (Unicode block Latin Extended)
// - Mathematical symbols
// - Currency symbols
// - Punctuation (en dash, em dash, curly quotes, ellipsis)
static const Set<int> _invisibleOrConfusable = { ... };
```

### Approach B: Skip string literals assigned to named constants

If a non-ASCII character appears in a `const` field initializer with a descriptive name, it is clearly intentional:

```dart
// Skip: explicitly named constant
static const String sunEmoji = '☀️';  // intentional

// Flag: anonymous string in code
print('Hello\u200BWorld');  // suspicious zero-width space
```

### Approach C: Add file/directory-level suppression

Allow projects to exclude specific files or directories from this rule:

```yaml
# analysis_options.yaml
saropa_lints:
  rules:
    avoid_non_ascii_symbols:
      exclude:
        - "lib/string/string_diacritics_extensions.dart"
        - "lib/html/html_utils.dart"
        - "lib/datetime/time_emoji_utils.dart"
```

**Recommendation:** Approach A is the most principled fix -- the rule should only flag characters that are genuinely dangerous (invisible or visually confusable), not all non-ASCII. Approach C is a pragmatic interim solution.

## Test Fixture Updates

### New GOOD cases (should NOT trigger)

```dart
// GOOD: Emoji constant with descriptive name -- clearly intentional.
class Emojis {
  static const String sun = '☀️';
  static const String moon = '🌙';
}

// GOOD: Diacritics mapping -- core data for text processing.
const Map<String, String> accents = {'à': 'a', 'é': 'e', 'ñ': 'n'};

// GOOD: HTML entity character value.
const Map<String, String> entities = {'&copy;': '©', '&reg;': '®'};

// GOOD: Mathematical symbol in formatting output.
String formatInfinity(double value) => value.isInfinite ? '∞' : '$value';

// GOOD: Typographic constant.
static const String ellipsis = '…';
static const String bullet = '•';
```

### Existing BAD cases (should still trigger)

```dart
// BAD: Invisible zero-width space in identifier-like context.
// expect_lint: avoid_non_ascii_symbols
final String name = 'Hello\u200BWorld';  // Zero-width space between words

// BAD: Cyrillic 'а' (U+0430) masquerading as Latin 'a' (U+0061).
// expect_lint: avoid_non_ascii_symbols
final String variable = 'dаta';  // Cyrillic 'а' -- homoglyph attack

// BAD: Non-standard whitespace that looks like a regular space.
// expect_lint: avoid_non_ascii_symbols
final String text = 'Hello\u00A0World';  // Non-breaking space in inline code
```

## Environment

- **saropa_lints version:** 5.0.0-beta.9 (rule version v4)
- **Dart SDK:** 3.x
- **Trigger project:** `D:\src\saropa_dart_utils` (pure Dart utility library, not a Flutter app)
- **Trigger files (estimated 400+ violations):**
  - `lib/datetime/time_emoji_utils.dart` -- 2 (emoji constants)
  - `lib/double/double_extensions.dart` -- 2 (infinity symbol)
  - `lib/html/html_utils.dart` -- 27+ (HTML entity mapping)
  - `lib/string/string_extensions.dart` -- 15+ (typographic constants)
  - `lib/string/string_diacritics_extensions.dart` -- 300+ (diacritics mapping)
  - `test/*` -- 50+ (Unicode test data)
- **Rule severity:** info

## Severity

High -- while each individual violation is info-level, the sheer volume (400+ estimated) makes this the single largest source of lint noise in the project. The rule is fundamentally incompatible with any library that processes Unicode text, which is a core use case for Dart packages. The false positive rate for this project type approaches 100%, since virtually every flagged character is intentional and necessary for the library's functionality.
