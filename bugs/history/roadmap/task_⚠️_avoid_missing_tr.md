> **========================================================**
> **DUPLICATE -- DO NOT IMPLEMENT**
> **========================================================**
>
> Already implemented as `AvoidHardcodedStringsInUiRule` in
> `lib/src/rules/internationalization_rules.dart` (line 32).
> Detects hardcoded strings in Text, RichText, SelectableText,
> DefaultTextStyle, and Button widgets. Extended in v5.1.0 to
> also cover InputDecoration and AlertDialog.
>
> **========================================================**

# Task: `avoid_missing_tr`

## Summary
- **Rule Name**: `avoid_missing_tr`
- **Tier**: Essential
- **Severity**: WARNING
- **Status**: Planned
- **Source**: ROADMAP.md §1.62 Intl/Localization Rules

## Problem Statement

String literals in Flutter code that are displayed to the user must be wrapped in a translation call (`.tr()`, `tr()`, `AppLocalizations.of(context).key`, `S.of(context).key`, etc.). Hardcoded user-visible strings bypass the localization pipeline, causing:
1. Strings that appear in English even when the app is set to French/German/Japanese
2. Missing translation keys that reviewers/QA can't easily audit
3. App Store rejections in some markets that require localization

## Description (from ROADMAP)

> Detect strings that should be translated but aren't.

## Relationship to `avoid_missing_tr_on_strings`

These two rules are essentially the same rule with slightly different framing. `avoid_missing_tr` focuses on detecting the absence of `.tr()` calls, while `avoid_missing_tr_on_strings` focuses on user-visible strings. **Consolidate into one rule** and note the duplication.

## Trigger Conditions

1. String literal assigned to `Text(...)`, `TextSpan(text: ...)`, `Tooltip(message: ...)`, `AppBar(title: Text(...))`, `SnackBar(content: Text(...))`, etc.
2. The string is NOT wrapped in a translation call
3. The string is a "user-visible" string (not a key, URL, identifier, format string, debug string)

### Package Detection
Fire only if the project uses one of:
- `easy_localization` (`.tr()` syntax)
- `flutter_localizations` / `intl` (`AppLocalizations.of(context).key`)
- `get` / `getx` (`'key'.tr`)
- `localization` package

If no localization package is present, suppress the rule.

## Implementation Approach

### AST Visitor Pattern

```dart
context.registry.addInstanceCreationExpression((node) {
  if (!_isTextWidget(node)) return;
  final firstArg = _getFirstStringArg(node);
  if (firstArg == null) return;
  if (_isTranslated(firstArg)) return;
  if (_isNonTranslatableString(firstArg)) return;
  reporter.atNode(firstArg, code);
});
```

`_isTextWidget`: check if the constructor is `Text(...)`, `TextSpan(text: ...)`, etc.
`_isTranslated`: check if the string literal is the target of a method call `.tr()` or wrapped in `tr(...)`.
`_isNonTranslatableString`: check if the string:
- Looks like a URL (`http://`, `https://`)
- Is all numbers or a date format
- Is an empty string
- Is a single character
- Contains only symbols/punctuation
- Starts with `_` (likely a key not a value)
- Has a debug/dev marker

## Code Examples

### Bad (Should trigger)
```dart
// User-visible string without translation
Text('Welcome to the app')  // ← trigger

AppBar(
  title: Text('Settings'),  // ← trigger
)

SnackBar(
  content: Text('Error: Please try again'),  // ← trigger
)
```

### Good (Should NOT trigger)
```dart
// easy_localization
Text('welcome_message'.tr())  // ✓

// flutter_localizations
Text(AppLocalizations.of(context)!.welcome)  // ✓

// Non-user-visible string
Text('https://example.com')  // ✓ URL
Text('')  // ✓ empty string
Text('A')  // ✓ single character (probably icon/symbol)

// Debug/dev string
if (kDebugMode)
  Text('Debug: $message')  // ✓ debug-only
```

## Edge Cases & False Positives

| Scenario | Expected Behavior | Notes |
|---|---|---|
| `Text('')` empty string | **Suppress** | |
| `Text(' ')` whitespace only | **Suppress** | |
| `Text('1')`, `Text('42')` numbers | **Suppress** | |
| `Text('\n')`, `Text('•')` symbols | **Suppress** | |
| `Text(variable)` (not a literal) | **Suppress** — variable may be translated elsewhere | Only check literal strings |
| `Text('error_key')` — looks like a key | **Suppress** — follows `snake_case` key naming | Heuristic: all lowercase with underscores = key |
| `Text('Error: $message')` | **Trigger** — interpolation doesn't make it translated | |
| `Text(kDebugMode ? 'Debug' : value)` | **Suppress on 'Debug' part** — debug only | |
| `Text('https://example.com/help')` | **Suppress** — URL | |
| Accessibility labels (not visible text): `Semantics(label: '...')` | **Trigger** — semantics labels need translation too | |
| Project has no localization package | **Suppress** | `ProjectContext` check |
| Test files | **Suppress** | |

## Unit Tests

### Violations
1. `Text('Hello')` in project with `easy_localization` → 1 lint
2. `AppBar(title: Text('Settings'))` → 1 lint

### Non-Violations
1. `Text('hello'.tr())` → no lint
2. `Text('')` → no lint
3. `Text('https://...')` → no lint
4. Project without localization package → no lint
5. Test file → no lint

## Quick Fix

Offer "Add `.tr()` call" (for easy_localization):
```dart
// Before:
Text('Hello')
// After:
Text('Hello'.tr())
```

Or "Wrap with `tr()`" (for other packages).

Only offer the fix when the package type is detectable.

## Notes & Issues

1. **`avoid_missing_tr` vs `avoid_missing_tr_on_strings`**: These are essentially the same rule. **Recommend merging** into one implementation and keeping only the cleaner rule name. Note this duplication in the task.
2. **Localization package detection is critical** — the rule is useless (and actively harmful as a false positive generator) without knowing what localization syntax to expect.
3. **"Looks like a key" heuristic**: `snake_case_string` is likely a translation key used correctly, `Title Case String` is likely hardcoded text. This heuristic will have false positives/negatives.
4. **`label:` parameters** in many Flutter widgets (e.g., `InputDecoration(label: Text('Email'))`) should also be checked.
