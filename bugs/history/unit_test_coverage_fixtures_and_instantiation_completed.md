# Unit Test Coverage: Fixtures and Rule Instantiation (Completed)

**Completed:** 2025-03-01  
**Source:** bugs/UNIT_TEST_COVERAGE_REVIEW.md (current status lives there)

## What was completed

1. **Missing fixtures (66 rules in 27 categories)**  
   All 66 missing fixtures were added: one `*_fixture.dart` per rule under the appropriate `example*/lib/<category>/`, plus fixture name in the category test file’s `fixtures` list and a “fixture exists” test. All 27 categories in the review table now have 0 missing.

2. **Rule instantiation tests (55 categories)**  
   A “Rule Instantiation” group was added to 55 category test files. Each group has one test per rule that instantiates the rule and asserts `code.name`, `problemMessage` contains `[code_name]`, `problemMessage.length` > 50, and `correctionMessage` is non-null. Catches registration and code-name mismatches.

## References

- **CHANGELOG.md** — Unreleased “Added” bullets for missing fixtures and rule instantiation tests.
- **bugs/UNIT_TEST_COVERAGE_REVIEW.md** — Current status: fixtures done, rule instantiation done for 55 categories; real behavioral tests not started.
