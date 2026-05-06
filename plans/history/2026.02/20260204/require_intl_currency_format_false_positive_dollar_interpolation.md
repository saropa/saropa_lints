# Bug: `require_intl_currency_format` false positive on all `toStringAsFixed()` string interpolations

## Rule

`require_intl_currency_format` in `lib/src/rules/internationalization_rules.dart` (line 1602)

## Severity

**High** — This is a systematic false positive that affects every string interpolation containing `toStringAsFixed()`, regardless of whether currency formatting is involved.

## Summary

The rule incorrectly flags non-currency string interpolations (compass bearings, GPS coordinates, percentages, etc.) as manual currency formatting. The root cause is that `node.toSource()` includes the Dart interpolation `$` character, which matches `r'$'` in the `_currencySymbols` set. Since **every** Dart string interpolation contains `$`, the currency symbol check is always true, and the rule degrades to "any `toStringAsFixed()` inside a string interpolation."

## Triggering Code (false positive)

```dart
// Islamic prayer times widget — compass direction to Mecca
'Qibla direction: ${times.qiblaDirection!.toStringAsFixed(1)}° from North'

// GPS coordinates
'Latitude ${data.location.latitude.toStringAsFixed(2)}°, Longitude ${data.location.longitude.toStringAsFixed(2)}°'
```

Neither of these involves currency. They format geographic degrees.

## Other examples that would false-positive

```dart
// Temperature
'Current temperature: ${temp.toStringAsFixed(1)}°C'

// Battery percentage
'Battery: ${level.toStringAsFixed(0)}%'

// Distance
'Distance: ${km.toStringAsFixed(2)} km'

// Angle / rotation
'Rotation: ${angle.toStringAsFixed(1)}°'

// Score / rating
'Rating: ${score.toStringAsFixed(1)} / 5.0'
```

None of these are currency, yet all will trigger the rule.

## Root Cause

`internationalization_rules.dart` lines 1642–1654:

```dart
context.registry.addStringInterpolation((StringInterpolation node) {
  final source = node.toSource();  // ← includes Dart's '$' interpolation syntax

  bool hasCurrencySymbol = false;
  for (final symbol in _currencySymbols) {
    if (source.contains(symbol)) {  // ← r'$' matches the '$' from '${...}'
      hasCurrencySymbol = true;
      break;
    }
  }

  if (!hasCurrencySymbol) return;  // ← always true for any interpolation

  for (final element in node.elements) {
    if (element is InterpolationExpression) {
      final expr = element.expression;
      if (expr is MethodInvocation &&
          expr.methodName.name == 'toStringAsFixed') {
        reporter.atNode(node, code);  // ← fires on ALL toStringAsFixed
        return;
      }
    }
  }
});
```

**Step-by-step:**

1. `node.toSource()` on `'Qibla: ${dir.toStringAsFixed(1)}°'` returns the string **including** the `$` character that is part of Dart's interpolation syntax.
2. `_currencySymbols` contains `r'$'` (the dollar sign).
3. `source.contains(r'$')` is `true` because every interpolated string source contains `$`.
4. `hasCurrencySymbol` is therefore **always true** for any `StringInterpolation` node.
5. The rule then checks for `toStringAsFixed` and reports — even though no currency symbol exists in the actual string content.

## Suggested Fix

Check only the **literal string parts** (`InterpolationString` elements) for currency symbols, not the full source representation. The `StringInterpolation.elements` list alternates between `InterpolationString` (literal text) and `InterpolationExpression` (interpolated code). Only the literal text can contain actual currency symbols intended by the developer.

```dart
context.registry.addStringInterpolation((StringInterpolation node) {
  // Check only literal string segments for currency symbols,
  // NOT toSource() which includes Dart's '$' interpolation syntax.
  bool hasCurrencySymbol = false;
  for (final element in node.elements) {
    if (element is InterpolationString) {
      final literal = element.value;
      for (final symbol in _currencySymbols) {
        if (literal.contains(symbol)) {
          hasCurrencySymbol = true;
          break;
        }
      }
      if (hasCurrencySymbol) break;
    }
  }

  if (!hasCurrencySymbol) return;

  // ... rest of detection logic unchanged ...
});
```

This ensures `r'$'` only matches an actual `$` character written in the string literal (e.g., `'\$${price.toStringAsFixed(2)}'`), not the `$` used for Dart interpolation syntax.

## Additional Consideration

The `BinaryExpression` handler (lines 1682–1711) uses `SimpleStringLiteral.value` which correctly checks the **content** of string literals, not their source representation. This inconsistency between the two handlers confirms the `StringInterpolation` handler has a bug — it should also check content, not source.

## Discovered In

- **File:** `lib/components/event/special_events/today_islamic_prayer_times_information.dart`
- **Project:** contacts (Saropa)
- **Context:** Compass bearing display for Qibla direction and GPS coordinate display — zero currency formatting present in the file
