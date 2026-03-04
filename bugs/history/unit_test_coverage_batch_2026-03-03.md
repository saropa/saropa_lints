# Unit Test Coverage: Batch 2026-03-03

**Completed:** 2026-03-03  
**Related:** bugs/UNIT_TEST_COVERAGE.md

## Summary

- **Rule instantiation tests added:** 10 (firebase 3, geolocator 1, record_pattern 1, performance 1, theming 2, widget_layout 2). All follow existing pattern: instantiate rule, assert `code.name`, `problemMessage` contains `[code_name]`, length > 50, `correctionMessage` non-null.
- **Behavioral coverage (fixture_lint_integration_test):** 57 rules in `expectedFromFixtures` (was 15; added 42). Asserts that when `custom_lint` runs on `example_async`, those rule codes appear in parsed violations. No stubs; all entries reference rules with real fixtures under `example_async/lib`.
- **Doc fix:** test/theming_rules_test.dart header updated from "4" to "6" Theming lint rules.

## Files changed

- test/firebase_rules_test.dart
- test/geolocator_rules_test.dart
- test/record_pattern_rules_test.dart
- test/performance_rules_test.dart
- test/theming_rules_test.dart
- test/widget_layout_rules_test.dart
- test/fixture_lint_integration_test.dart

## Verification

- Rule-instantiation tests for the above categories pass when run.
- Integration test requires `dart test test/fixture_lint_integration_test.dart`; may be skipped if project has analyzer API breakages (e.g. formatting fixes) in the same tree.
