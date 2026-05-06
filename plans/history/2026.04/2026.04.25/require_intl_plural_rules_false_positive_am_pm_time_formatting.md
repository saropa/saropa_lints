# BUG: `require_intl_plural_rules` false positive on AM/PM hour formatting

**Status: Fixed** (2026-04-25)

Created: 2026-04-25  
Rule: `require_intl_plural_rules`  
Severity: False positive

---

## Attribution Evidence

- Rule defined in `lib/src/rules/ui/internationalization_rules.dart`:
  - `'require_intl_plural_rules'`
- Rule set exported in `lib/src/rules/all_rules.dart`:
  - `export 'ui/internationalization_rules.dart';`

---

## Reproducer (downstream)

`contacts/lib/components/country/timezone/availability_hour_wheel.dart`:

- function `_formatHour(int hour)` with AM/PM branch:
  - `if (hour == 0) return '12\nAM';`
  - `if (hour == 12) return '12\nPM';`
  - `return '$display\n${isPM ? 'PM' : 'AM'}';`

This is clock-format branching, not noun pluralization.

---

## Expected vs Actual

- **Expected:** No lint for fixed AM/PM formatting logic.
- **Actual:** Lint flags method as manual pluralization.

---

## Root cause (confirmed)

The plural-word check used a regex on **full method `body.toSource()`** with a `['"]…['"]`-style span. The `[^'"]*` segment does not stop at semicolons, so a match could start at the **closing** quote of a short literal (e.g. after `'12\nAM'`), consume non-quote code including `(hour == 12)`, and satisfy `\bhour\b` via the `hours?` alternation before the next opening quote.

---

## Resolution

- **Detection:** Plural-indicator words are matched only inside `SimpleStringLiteral` values and `InterpolationString` fragments (`_PluralWordLiteralScanner`), not across raw source.
- **Tests:** `test/require_intl_plural_rules_behavior_test.dart` (wheel vs manual plural).
- **Fixture:** `_good449_formatHourWheel` in `example/lib/internationalization/require_intl_plural_rules_fixture.dart`.
- **Changelog:** `CHANGELOG.md` §12.5.0 Fixed.

---

## Suggested Fix (original)

1. Tighten rule to detect pluralization intent, not any numeric branching.
2. Exclude common time-format markers (`AM`, `PM`) and non-count labels.
3. Add a fixture explicitly validating `_formatHour`-style methods as **OK**.

Items 1 and 3 addressed by literal-only scan + fixture; item 2 not required once literals no longer false-match code between quotes.
