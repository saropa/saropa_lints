# PROPOSAL: Flag Manual Date Formatting in Favor of `intl`'s `DateFormat`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_number_format`

---

## Summary

Add `prefer_date_format` to flag manual construction of a formatted date string via string interpolation/concatenation of `DateTime` fields (`'${date.day}/${date.month}/${date.year}'`) or manual zero-padding logic, suggesting `package:intl`'s `DateFormat` instead.

**Closes gap:** `dart_code_metrics_presets` `prefer-date-format` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Hand-built date strings hardcode a single locale's field order and separators, silently break for single-digit days/months (`'5/3/2026'` instead of `'05/03/2026'`), and give every call site its own slightly different formatting logic to maintain. `DateFormat` centralizes locale-aware formatting, zero-padding, and named-month/weekday rendering behind one well-tested API, which is exactly the kind of "don't hand-roll what a library already solved correctly" gap this rule closes.

---

## Detection / Behavior

### Should flag (bad code)

```dart
String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}'; // LINT — manual date formatting, no zero-padding, no locale awareness
}
```

### Should pass (good code)

```dart
String formatDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date); // OK — uses intl's DateFormat
}
```

---

## Proposed Tier

Tier: Professional
Justification: catches a real i18n/formatting correctness gap (missing zero-padding, hardcoded locale) but requires the `intl` dependency, so placed below Essential/Recommended which are dependency-free.

---

## Edge Cases

1. **String interpolation of a single `DateTime` field for a non-display purpose (e.g. building a cache key or file name)** — should pass; the rule targets user-facing date *display* formatting, not arbitrary string keys.
2. **`toIso8601String()` used for a machine-readable format (API payloads, logs)** — should pass; ISO 8601 is itself the correct choice for non-display date serialization, not a manual-formatting hazard.
3. **Interpolation of only one `DateTime` field in isolation (e.g. `'Year: ${date.year}'`)** — needs discussion; a single-field interpolation carries much less of the zero-padding/ordering risk than a full multi-field date string.
4. **`DateFormat` already used but with a hand-appended literal suffix/prefix around it** — should pass; the rule is about detecting the *absence* of `DateFormat`, not policing how it's combined with other strings.

---

## Alternatives Considered

- **Detect only missing zero-padding, not general manual concatenation** — rejected as narrower than the upstream rule's likely scope; hardcoded field order/locale is an equally real defect the rule should catch.

---

## Decision

---

## Implementation Notes

---

## Commits
