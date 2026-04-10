# False positive: `avoid_hardcoded_locale` — flags locale strings used as lookup data, not formatting arguments

## Resolution

**Fixed.** Added `_isInsideCollectionLiteral()` helper that walks up parent AST nodes and skips locale-pattern strings inside `SetOrMapLiteral` or `ListLiteral`. Stops at method/constructor invocation boundaries so `DateFormat('en_US')` is still flagged. Option B from the report was implemented.

## Summary

The `avoid_hardcoded_locale` rule flags **any** `SimpleStringLiteral` whose value matches the pattern `xx_XX` (two lowercase letters, underscore, two uppercase letters). It does not consider the context in which the string appears. This causes false positives when locale-pattern strings are used as **data elements** (e.g., in a `Set<String>` lookup table) rather than as arguments to locale-sensitive formatting APIs like `DateFormat` or `NumberFormat`.

Ironically, the flagged code in `saropa_dart_utils` is **doing exactly what the rule's correction message recommends** — reading the device locale via `Platform.localeName` and comparing it against known values. The rule fires on the comparison targets.

## Reproduction

### Triggering code

```dart
// lib/datetime/date_time_utils.dart (saropa_dart_utils)

/// Locale codes that commonly use month-first (MM/DD/YYYY) date format.
static const Set<String> _monthFirstLocales = <String>{
  'en_US', // <-- FLAGGED: avoid_hardcoded_locale
  'en_PH', // <-- FLAGGED: avoid_hardcoded_locale
  'en_CA', // <-- FLAGGED: avoid_hardcoded_locale
  'fil',   // (not flagged — no underscore pattern)
  'fsm',   // (not flagged)
  'gu_GU', // <-- FLAGGED: avoid_hardcoded_locale
  'mh',    // (not flagged)
  'pw',    // (not flagged)
  'en_BZ', // <-- FLAGGED: avoid_hardcoded_locale
};

/// Returns true if the device uses a month-first date format.
static bool isDeviceDateMonthFirst() =>
    _monthFirstLocales.contains(Platform.localeName);
```

Every string in `_monthFirstLocales` matching `xx_XX` pattern triggers the diagnostic. This produces **5 false positives** from a single `Set<String>` constant.

### Diagnostic output

```
[avoid_hardcoded_locale] Hardcoded locale ignores user's device settings.
Apps should respect the user's device locale settings. {v6}
Use Localizations.localeOf(context).toString() to get device locale.
```

### Why this is a false positive

1. **These strings are not passed to any formatting API.** They are not arguments to `DateFormat`, `NumberFormat`, `Intl.message`, or any locale-sensitive constructor. They are elements in a `const Set<String>`.

2. **The code respects the device locale.** The method `isDeviceDateMonthFirst()` reads `Platform.localeName` (the device's actual locale) and checks whether it appears in the known set. This is the **correct pattern** — it is reading the device locale, not overriding it.

3. **The correction message is inapplicable.** The suggestion to "Use `Localizations.localeOf(context).toString()` to get device locale" makes no sense here — there is no `BuildContext` available (this is a utility library, not a widget), and the code is already using the device locale.

4. **There is no alternative.** Locale lookup tables must contain locale code strings. You cannot express `'en_US'` without writing `'en_US'`. The rule offers no way to distinguish data from formatting arguments.

## Root cause

The rule implementation in `internationalization_rules.dart` (lines 426-437):

```dart
static final RegExp _localePattern = RegExp(r"'[a-z]{2}_[A-Z]{2}'");

@override
void runWithReporter(
  SaropaDiagnosticReporter reporter,
  SaropaContext context,
) {
  context.addSimpleStringLiteral((SimpleStringLiteral node) {
    final String value = node.value;

    // Check for locale patterns like 'en_US', 'de_DE', etc.
    if (_localePattern.hasMatch("'$value'")) {
      reporter.atNode(node);
    }
  });
}
```

The rule matches on the string value alone. It does not inspect the parent AST node to determine whether the string is:
- An argument to a locale-sensitive API (should flag)
- An element in a collection literal (should not flag)
- A constant value in a comparison/lookup (should not flag)
- An assignment to a locale variable (context-dependent)

## Other patterns likely to false-positive

The same issue would affect any code that stores locale strings as data:

```dart
// Locale-to-language mapping — all values would be flagged
const Map<String, String> localeToLanguage = {
  'en_US': 'English (US)',     // FLAGGED
  'fr_FR': 'French',           // FLAGGED
  'de_DE': 'German',           // FLAGGED
};

// Supported locales list
const supportedLocales = ['en_US', 'es_MX', 'pt_BR'];  // All FLAGGED

// Locale validation
bool isSupported(String locale) => supportedLocales.contains(locale);

// Test assertions
expect(getLocale(), equals('en_US'));  // FLAGGED in test
```

## Existing fixture gap

The test fixture (`avoid_hardcoded_locale_fixture.dart`) only tests the happy path — locale strings passed directly to `DateFormat` and `NumberFormat`. It does not include negative test cases for locale strings used in non-formatting contexts (collections, constants, comparisons, tests).

## Suggested improvements

### Option A: Only flag when the string is a direct argument to a locale-sensitive API (recommended)

Check the parent AST nodes. Only report when the string literal is:
- A positional argument to `DateFormat`, `NumberFormat`, or `Intl` constructors/methods
- A named argument with name `locale` in any constructor/method call
- Assigned to a variable named `locale`, `defaultLocale`, etc.

```dart
context.addSimpleStringLiteral((SimpleStringLiteral node) {
  final String value = node.value;
  if (!_localePattern.hasMatch("'$value'")) return;

  // Only flag if used as a locale argument to a formatting API
  final AstNode? parent = node.parent;

  // Check: named argument with name 'locale'
  if (parent is NamedExpression && parent.name.label.name == 'locale') {
    reporter.atNode(node);
    return;
  }

  // Check: second positional argument to DateFormat/NumberFormat
  if (parent is ArgumentList) {
    final grandparent = parent.parent;
    if (grandparent is InstanceCreationExpression) {
      final typeName = grandparent.constructorName.type.name.lexeme;
      if (typeName == 'DateFormat' || typeName == 'NumberFormat') {
        reporter.atNode(node);
        return;
      }
    }
  }

  // Check: assignment to Intl.defaultLocale
  if (parent is AssignmentExpression) {
    final leftSource = parent.leftHandSide.toSource();
    if (leftSource.contains('defaultLocale') || leftSource.contains('locale')) {
      reporter.atNode(node);
      return;
    }
  }
});
```

### Option B: Exclude collection literal elements

At minimum, do not flag strings inside `SetOrMapLiteral` or `ListLiteral` nodes, since these are data definitions, not API calls:

```dart
// Skip strings that are elements of a collection literal
AstNode? parent = node.parent;
while (parent != null) {
  if (parent is SetOrMapLiteral || parent is ListLiteral) return;
  if (parent is InstanceCreationExpression || parent is MethodInvocation) break;
  parent = parent.parent;
}
```

### Option C: Add a heuristic tag

If exact context detection is too costly, add a `[HEURISTIC]` tag to the message (like `avoid_hardcoded_locale_strings` does) so developers understand the rule may produce false positives, and consider downgrading to INFO severity with a note about expected false positives.

## Fixture additions needed

The fixture file should include negative cases:

```dart
// GOOD: Should NOT trigger avoid_hardcoded_locale

// Locale strings in a lookup set (data, not formatting)
const Set<String> monthFirstLocales = {'en_US', 'en_CA', 'en_PH'};

// Locale strings in a map (data, not formatting)
const Map<String, String> names = {'en_US': 'English', 'fr_FR': 'French'};

// Locale strings in a list (data, not formatting)
const List<String> supported = ['en_US', 'es_MX'];

// Locale strings in comparisons (checking device locale)
bool isUs() => Platform.localeName == 'en_US';

// Locale strings in test assertions
// expect(result, equals('en_US'));
```

## Environment

- **Rule:** `avoid_hardcoded_locale` v6
- **Severity:** INFO (professional tier)
- **saropa_lints version:** 5.0.0-beta.15
- **Source:** `lib/src/rules/internationalization_rules.dart` lines 405-442
- **Triggered in:** `saropa_dart_utils` — `lib/datetime/date_time_utils.dart` lines 18-28
- **OS:** Windows 11 Pro 10.0.22631
- **False positives in affected file:** 5 (one per `xx_XX` locale string in the set)
