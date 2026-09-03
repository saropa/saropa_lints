# PROPOSAL: Flag Manual Number Formatting in Favor of `intl`'s `NumberFormat`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_date_format`

---

## Summary

Add `prefer_number_format` to flag manual construction of a formatted numeric display string — hand-rolled thousands-separator insertion, manual `toStringAsFixed` chains for currency, or string interpolation of a raw `double`/`int` for user-facing display — suggesting `package:intl`'s `NumberFormat` (`NumberFormat.currency`, `NumberFormat.decimalPattern`, etc.) instead.

**Closes gap:** `dart_code_metrics_presets` `prefer-number-format` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Displaying a raw `1234567.5` or a hand-built `'$1,234.50'` string bakes in one locale's grouping separator, decimal point, and currency symbol placement — all of which vary by region and none of which a hand-rolled implementation typically handles correctly. `NumberFormat` centralizes locale-aware grouping, rounding, and currency symbol formatting the same way `DateFormat` does for dates, closing the equivalent numeric-formatting gap.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String formatPrice(double amount) {
  return '\$${amount.toStringAsFixed(2)}'; // LINT — manual currency formatting, hardcoded symbol/locale
}
```

### Should pass (good code)

```dart
String formatPrice(double amount) {
  return NumberFormat.currency(symbol: '\$').format(amount); // OK — uses intl's NumberFormat
}
```

---

## Proposed Tier

Tier: Professional
Justification: catches a real i18n/formatting correctness gap (locale-specific grouping/decimal/currency conventions) but requires the `intl` dependency, so placed below Essential/Recommended which are dependency-free.

---

## Edge Cases

1. **`toStringAsFixed` used for a non-display purpose (rounding a value for a calculation, not for showing to the user)** — should pass; the rule targets user-facing numeric *display*, not internal rounding logic.
2. **Interpolation of an `int` with no decimal/grouping formatting at all (e.g. `'Count: $count'`)** — needs discussion; small integers with no thousands separator need are lower-risk than currency/decimal formatting.
3. **`NumberFormat` already used but combined with extra hand-appended literal text (e.g. a trailing unit suffix)** — should pass; the rule targets absence of `NumberFormat`, not how it's composed with surrounding text.
4. **Percentage formatting via manual `* 100` and string concatenation** — should flag under the same rationale; `NumberFormat.percentPattern` is the equivalent library-provided alternative.

---

## Alternatives Considered

- **Limit scope to currency formatting only, skip general decimal/percentage formatting** — rejected as narrower than the upstream rule's likely scope; hand-rolled decimal and percentage formatting carry the same locale-correctness risk as currency.

---

## Decision

---

## Implementation Notes

---

## Commits
