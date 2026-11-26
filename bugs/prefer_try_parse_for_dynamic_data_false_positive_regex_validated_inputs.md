# BUG: `prefer_try_parse_for_dynamic_data` - fixture GOOD cases with regex-validated input still report

**Status: Open**

Created: 2026-11-26
Rule: `prefer_try_parse_for_dynamic_data`
File: `lib/src/rules/data/json_datetime_rules.dart`
Severity: False positive
Rule version: v5

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
