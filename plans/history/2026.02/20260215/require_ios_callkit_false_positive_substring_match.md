# `require_ios_callkit_integration` false positives from substring matching

## Status: RESOLVED

## Resolution

Fixed in v4.14.5 (rule version v4). Replaced `String.contains()` matching
with word-boundary `RegExp` (`\b` anchors) in `_voipRegexes`. Patterns like
"Agora" now only match as whole words, so "Zagora" and "Stara Zagora" no
longer trigger false positives. Anti-pattern baseline updated.

## Problem

The `require_ios_callkit_integration` rule uses case-insensitive `String.contains()` to match VoIP-related patterns inside string literals. This causes false positives when a pattern appears as a **substring** of an unrelated word.

### Example: "Agora" inside city names

The pattern set includes `'Agora'` (the VoIP SDK). A case-insensitive `contains()` match means any string containing the substring "agora" triggers the rule — including the geographic names **"Zagora"** and **"Stara Zagora"**.

```
'Zagora'       → contains "agora" (case-insensitive) → FALSE POSITIVE
'Stara Zagora' → contains "agora" (case-insensitive) → FALSE POSITIVE
```

These are city/province names in Bulgaria and Morocco, stored as static data in `CountryStateModel` objects. There is zero VoIP intent.

## Affected Rule

**File:** `lib/src/rules/platforms/ios_rules.dart` line 4844–4904

**Root cause** (lines 4894–4896):
```dart
final String value = node.value.toLowerCase();
for (final String pattern in _voipPatterns) {
  if (value.contains(pattern.toLowerCase())) {  // ← no word boundary check
```

## Other potential false positives from the same mechanism

| Pattern | Could false-positive on |
|---------|------------------------|
| `agora` | Zagora, Agorah, Pitagora, any word containing "agora" |
| `voip` | Less likely but possible in compound strings |
| `call_state` | Unlikely in natural strings |
| `twilio` | Unlikely |
| `vonage` | Unlikely |

The `agora` pattern is the most problematic because it's a common Greek/Latin root meaning "marketplace" — it appears in place names worldwide.

## Suggested fix

Use **word-boundary matching** instead of raw `contains()`:

```dart
/// Match whole words only, accounting for common delimiters
static final Map<String, RegExp> _voipRegexes = {
  for (final String pattern in _voipPatterns)
    pattern: RegExp(r'\b' + RegExp.escape(pattern) + r'\b', caseSensitive: false),
};

// In the visitor:
final String value = node.value;
for (final MapEntry<String, RegExp> entry in _voipRegexes.entries) {
  if (entry.value.hasMatch(value)) {
    reporter.atNode(node, code);
    hasReported = true;
    return;
  }
}
```

Alternatively, restrict matching to identifier-style strings (containing underscores/dots) rather than natural-language strings that contain spaces.

## Reproduction

Any Dart file containing a string literal with "Zagora" (or any string where "agora" appears as a substring):

```dart
// This triggers the warning — it should not
const String city = 'Stara Zagora';
```

## Environment

- **saropa_lints version:** 4.14.5
- **Trigger project:** `D:\src\contacts` — country/state static data files
- **Files affected:**
  - `lib/data/country_state/country_state_data.dart:448` — `'Stara Zagora'`
  - `lib/data/country_state/by_country/country_state_data_ma.dart:173` — `'Zagora'`
