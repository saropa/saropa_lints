# BUG: `prefer_try_parse_for_dynamic_data` - fixture GOOD cases with regex-validated input still report

**Status: Fixed**

Created: 2026-11-26
Rule: `prefer_try_parse_for_dynamic_data`
File: `lib/src/rules/data/json_datetime_rules.dart`
Severity: False positive
Rule version: v5 (fixed in v6)

---

## Summary

Two cases that the example fixture documents as GOOD are reported.

---

## Attribution Evidence

```bash
grep -rn "'prefer_try_parse_for_dynamic_data'" lib/src/rules/
# lib/src/rules/data/json_datetime_rules.dart:235:    'prefer_try_parse_for_dynamic_data',
```

---

## Reproducer

`example/lib/json_datetime/prefer_try_parse_for_dynamic_data_fixture.dart`, run through the rule harnesses.

| Fixture function | Lines | Resolved | Unresolved |
|---|---|---|---|
| `goodRegexCaptureGroup` | 24-26 | silent | reports all three |
| `goodRegexGuardedSubstring` | 36-38 | reports all three | reports all three |

---

## Expected vs Actual

- Expected: no diagnostic on any of the six `int.parse` calls.
- Actual: reported as in the table.

---

## Root Cause

Not investigated. The relevant exemptions are `_isDigitOnlyRegexCapture` and `_isRegexValidatedSubstring`.

---

## Fixture Gap

The cases exist, but `test/scan/fixture_lint_integration_test.dart` does not fail on them.

---

## Environment

- saropa_lints version: 17.9.1 plus unreleased 17.10.0 changes

---

## Resolution (2026-11-26)

The report is correct for five of the six calls.

Root cause:

- The RegExp declaration was searched only in the block holding the parse, so a pattern declared outside a loop was never found (`goodRegexGuardedSubstring`, both scans).
- A named `RegExp(...)` variable was recognized only as a constructor node; the unresolved parse yields a method invocation (`goodRegexCaptureGroup`, unresolved).

The sixth call, `int.parse(token.substring(6))`, is a true positive: the guard `^\d{4,8}$` admits 6-character tokens, for which the argument is `''` and `int.parse` throws. The fixture now marks it `expect_lint`.

Fix: lookup walks outward through enclosing blocks (outer variables must be `final`/`const`; parameters and loop variables hide them) and accepts both node shapes. The exemption now also requires an anchored, non-multiLine pattern, a digit run that cannot be empty, and literal `substring` bounds that cannot produce `''`.

Tests: `test/rules/data/prefer_try_parse_regex_validated_test.dart` runs both scans, including the example fixture's exact reported lines.

Not covered: reassignment of the validated string between the guard and the parse is not detected.

## Finish Report (2026-11-26)

Status: Fixed.

A follow-up review found that a catch parameter, pattern variable or local function reusing the name of a checked `firstMatch` result was read as that result. The lookup now uses the shared binding list in `lib/src/local_binding_utils.dart`.

Verification: `prefer_try_parse_regex_validated_test.dart`, `json_datetime_rules_test.dart`, `prefer_try_parse_const_uri_test.dart` and `fixture_lint_integration_test.dart` passed. The new hiding cases cover pattern declarations, if-case and switch patterns and local functions; no dedicated catch-parameter case exists for this rule.

Not covered: reassignment of the validated string between the guard and the parse.
