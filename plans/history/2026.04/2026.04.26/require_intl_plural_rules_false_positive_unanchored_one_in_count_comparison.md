**Archived from `bugs/` on 2026-04-26** (implementation landed same day).

# `require_intl_plural_rules` — false positive: regex `[=!]=\s*1` matches inside `12`, `100`, `1000` (unanchored), firing on time/clock formatters

**Status:** Fixed (anchored `1` literal in `RequireIntlPluralRulesRule.countComparisonPatternFor`, 2026-04-26)

Filed: 2026-04-26
Rule: `require_intl_plural_rules`
File: `lib/src/rules/ui/internationalization_rules.dart` (line 1884, code at 1900–1989)
Severity: False positive (regex too permissive)
Rule version: v2 | Severity in code: WARNING | Impact: high

---

## Summary

The rule's gating regex (lines 1966–1969) checks whether a method's body compares an `int` parameter to the literal `1`:

```dart
final RegExp countComparisonPattern = RegExp(
  '${RegExp.escape(countParamName)}\\s*[=!]=\\s*1|'
  '1\\s*[=!]=\\s*${RegExp.escape(countParamName)}',
);
```

The `1` is **not anchored** — no end-of-number boundary. The regex therefore matches inside any literal that *starts* with `1`: `12`, `100`, `1024`, `1000000`. So a 12-hour clock formatter that compares `hour == 12` looks like a pluralization comparison `hour == 1` to this rule.

Combined with the rule's "method returns String + has int param + ≥ 2 string returns" preconditions, this causes the rule to flag time formatters, hour-cycle helpers, day-of-month formatters, version-comparison helpers, and any other code that happens to compare an int to a constant ≥ 10 starting with `1`.

---

## Attribution Evidence

```bash
$ grep -rn "'require_intl_plural_rules'" lib/src/rules/
lib/src/rules/ui/internationalization_rules.dart:1901:    'require_intl_plural_rules',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/ui/internationalization_rules.dart:1884` (`RequireIntlPluralRulesRule`)
**Rule class:** `RequireIntlPluralRulesRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/country/timezone/availability_hour_wheel.dart:66–72`.

```dart
/// Formats hour (0-23) as 12-hour string (e.g. "2 PM", "12 AM")
static String _formatHour(int hour) { // LINT — but should NOT lint
  if (hour == 0) return '12\nAM';
  if (hour == 12) return '12\nPM';   // ← `hour == 12` matches `hour\s*==\s*1` (unanchored)
  final bool isPM = hour >= 12;
  final int display = isPM ? hour - 12 : hour;
  return '$display\n${isPM ? 'PM' : 'AM'}';
}
```

This is a 12-hour clock label generator. Not pluralization. The strings `'12\nAM'`, `'12\nPM'`, and `'$display\nAM'`/`'$display\nPM'` are time labels. There is no plural noun anywhere.

**Frequency:** Always — any String-returning method with an `int` parameter, ≥ 2 `return '…'` statements, and at least one comparison to a number that *starts with* `1` (12, 100, 1000, 1024…) gets flagged.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic. The method compares `hour == 12`, not `hour == 1`. There is no pluralization happening — `'12\nAM'` and `'12\nPM'` are full time labels, not "one X / N Xs" forms. |
| **Actual** | `[require_intl_plural_rules] Manual pluralization logic using if/else or ternary expressions on count values.` fires on the `_formatHour` method declaration. |

---

## AST Context

```
MethodDeclaration (_formatHour)        ← reported here
  ├─ ReturnType: String
  ├─ Parameters: (int hour)
  └─ Body
      ├─ IfStatement (hour == 0) → return '12\nAM'
      ├─ IfStatement (hour == 12) → return '12\nPM'   ← regex match here
      └─ … return '$display\n…'
```

Detection sequence (lines 1923–1986):

1. Method must have `String` return type ✓
2. Method must have `int` parameter ✓ (`hour`)
3. Body must not already contain `Intl.plural` ✓
4. Body source must match `countComparisonPattern` — the broken check:
   - The literal `hour == 12` matches `hour\s*[=!]=\s*1` because the `1` in `12` is unanchored. ✓ (incorrectly)
5. Body must have `_returnStringPattern` matches ≥ 2 ✓ (4 returns of string literals)
6. `stringLiteralsSuggestManualPlural(body)` must return true — depends on `_PluralWordLiteralScanner`. The strings `'12\nAM'`, `'12\nPM'`, `'$display\nAM'`, `'$display\nPM'` would need to contain a plural-suggesting word. Without seeing that scanner I can't trace exactly which token triggers, but the diagnostic IS firing, which means it returns true. Plausible candidates: the scanner sees the `\n` escape interpolating into something it treats as a plural word, or it has an over-broad list that includes `AM`/`PM` (unlikely but possible), or it scans interpolation expressions like `$display` for plural intent.

The chain of preconditions filters most non-plural code, but step 4 alone is broken — and that is the lowest-hanging fix.

---

## Root Cause

### Flaw A: regex `1` is unanchored

```dart
RegExp(
  '${RegExp.escape(countParamName)}\\s*[=!]=\\s*1|'
  '1\\s*[=!]=\\s*${RegExp.escape(countParamName)}',
);
```

The `1` after `[=!]=\\s*` has no `\\b`, no negative-lookahead, no end-of-line anchor. It happily matches the leading `1` of `12`, `100`, `1024`, `19`, `1.5`, etc. The intent — "compares parameter to the literal integer 1" — is not what the regex actually asserts.

### Flaw B: multiple diagnostics could conflate clock/date code with pluralization more often than necessary

The set of methods that:

- Return `String`
- Take an `int`
- Have multiple string returns
- Compare to a number starting with `1`

…is large: hour formatters, month formatters, day-of-week → name mappers (where `if (day == 1) return 'Monday'` would be a true plural-shape comparison but the *output* is not pluralization), version-string formatters, ordinal formatters (`1st, 2nd, 3rd…`). Anchoring the regex closes the time-formatter case immediately and reduces the surface for the others.

---

## Suggested Fix

### Fix 1 — Anchor the `1` in the regex (one-character change)

Use a negated character class or word boundary to ensure the integer is exactly `1`:

```dart
final RegExp countComparisonPattern = RegExp(
  '${RegExp.escape(countParamName)}\\s*[=!]=\\s*1(?![0-9])|'
  '(?<![0-9])1\\s*[=!]=\\s*${RegExp.escape(countParamName)}',
);
```

`(?![0-9])` (negative lookahead) ensures no digit follows the `1`. `(?<![0-9])` (negative lookbehind) ensures no digit precedes a leading `1`. Together they assert "the literal `1`, not a digit inside a longer numeral".

This single change closes the `hour == 12` false positive without affecting any true-positive case.

### Fix 2 — Tighten the plural-word literal scanner (optional, lower priority)

Audit the `_PluralWordLiteralScanner` (referenced at line 1912 but defined elsewhere — check `internationalization_rules.dart` for its definition). The scanner's set of plural-suggesting tokens should not include time/clock terms (`AM`, `PM`, `hour`, `min`, `sec`, `day`, `month`, `year`) when those appear in label contexts. If the scanner already excludes those, no change needed; if it doesn't, this is the secondary defense in depth.

### Fix 3 — Document the rule's scope

The rule's docstring (lines 1840–1882) should explicitly say: *"This rule targets methods whose return string is a pluralization (e.g., '1 item' / '5 items'). It does NOT apply to label generators (clocks, dates, month names) or formatters that return arbitrary string forms based on an int parameter."* That carve-out makes intent explicit and helps users understand whether `// ignore:` is the right call or whether the rule has a real bug.

---

## Fixture Gap

The fixture at `example*/lib/ui/require_intl_plural_rules_fixture.dart` should include:

1. **`String describe(int count) { if (count == 1) return '1 item'; return '$count items'; }`** — expect LINT (true plural pattern)
2. **`String formatHour(int hour) { if (hour == 0) return '12 AM'; if (hour == 12) return '12 PM'; return '$display ${isPM ? "PM" : "AM"}'; }`** — expect NO lint *(currently false positive)*
3. **`String version(int build) { if (build == 100) return 'beta'; return 'stable'; }`** — expect NO lint *(currently false positive)*
4. **`String ordinal(int n) { if (n == 1) return '1st'; if (n == 2) return '2nd'; if (n == 3) return '3rd'; return '${n}th'; }`** — expect NO lint (formatting, not pluralization, even though it compares to 1)
5. **`String monthName(int month) { if (month == 1) return 'January'; if (month == 12) return 'December'; ... }`** — expect NO lint (mapping, not plural)
6. **Method comparing `count == 10` (no `1`-starting number)** — expect NO lint (already correct)

Cases 4 and 5 are arguably covered by the literal-scanner step. Case 2 is closed by Fix 1.

---

## Downstream

Tracked in `contacts/`. Once this report exists, `// ignore: require_intl_plural_rules` is added at `lib/components/country/timezone/availability_hour_wheel.dart:66` with a comment pointing here.

---

## Environment

- saropa_lints version: 12.4.0
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
