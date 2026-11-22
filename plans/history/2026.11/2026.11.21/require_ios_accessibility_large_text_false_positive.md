# BUG: `require_ios_accessibility_large_text` — fires on TextStyle fontSize whose consumer already applies a TextScaler

**Status: Fixed**

Rule: `require_ios_accessibility_large_text`
File: `lib/src/rules/platforms/ios_capabilities_permissions_rules.dart`
Severity: False positive
Sites in downstream app: 5 of 6 sites in 3 files (TextPainter with textScaler 2, Text consumers 2, share image with scale pinned on purpose 1)

---

## Summary

Every literal `fontSize` in a `TextStyle` is reported. The code is correct; each site carries an `// ignore:` workaround.

---

## Attribution Evidence

```bash
grep -rn "'require_ios_accessibility_large_text'" lib/src/rules/
# Expected: lib/src/rules/platforms/ios_capabilities_permissions_rules.dart:NN
```

---

## Reproducer

```dart
final TextPainter painter = TextPainter(
  text: TextSpan(
    text: label,
    style: TextStyle(fontSize: 11), // LINT, but should NOT lint
  ),
  textScaler: MediaQuery.textScalerOf(context), // scaling applied here
  textDirection: TextDirection.ltr,
)..layout();
```

**Frequency:** Only with the pattern above.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the `TextStyle` is passed to a `TextPainter` that has `textScaler:`, or to `Text`/`RichText` (which apply the ambient scaler). |
| **Actual** | Every literal `fontSize` in a `TextStyle` is reported. |

---

## Suggested Fix

Do not flag a bare `TextStyle`; flag only when the consumer in the same file disables scaling without a stated reason. Add a fixture for the pattern above to the rule's example fixtures.


Status: Fixed (2026-11-21)
