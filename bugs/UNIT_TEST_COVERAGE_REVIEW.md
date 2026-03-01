# Unit Test Coverage: Current Status

**Last updated:** 2025-03-01  
**Scope:** All lint rules in `lib/src/rules/` and all rule-related tests in `test/`.

**Completed work (archived in bugs/history):**  
Fixture work (66 rules) and Rule Instantiation (55 categories) are **done**. Summary: [bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md](history/unit_test_coverage_fixtures_and_instantiation_completed.md).

**This document:** Current status only. What is done vs not done is stated explicitly in each section below.

---

## Current status at a glance

| Item | Status | Notes |
|------|--------|--------|
| Fixtures (one per rule in reviewed categories) | **Done** | 27 categories, 0 missing. See §2. |
| Rule instantiation tests (one per rule, metadata assertions) | **Done for 99 categories** | All category test files have a Rule Instantiation group. See §3. |
| Real behavioral tests (linter on code, assert lint present/absent) | **Started** | One test in fixture_lint_integration_test.dart. See §4. |

---

## 1. Test quality (current state)

- **Fixture verification:** Done. Test files that list fixtures have “fixture exists” tests (real assertions).
- **Behavioral tests:** One integration test runs custom_lint on example_async and asserts specific rule codes appear in parsed output when violations exist. Most category tests still use placeholders (`expect('...', isNotNull)`).
- **Rule instantiation tests:** Done for 99 categories. Each category test file has a group that instantiates every rule and asserts `code.name`, `problemMessage`, `correctionMessage` (see bugs/history summary).

---

## 2. Fixtures — DONE

All 27 categories that were in scope have **0 rules without a dedicated fixture**. Counts below are for reference; no action left.

| Category              | Rule count | Fixture count | Missing |
|-----------------------|-----------:|--------------:|--------:|
| structure             | 45         | 45            | 0       |
| class_constructor     | 20         | 20            | 0       |
| naming_style          | 28         | 28            | 0       |
| type                  | 18         | 18            | 0       |
| control_flow           | 31         | 31            | 0       |
| hive                  | 23         | 23            | 0       |
| performance           | 49         | 49            | 0       |
| widget_patterns       | 104        | 104           | 0       |
| api_network           | 38         | 38            | 0       |
| code_quality          | 105        | 104+          | 0       |
| collection            | 25         | 25            | 0       |
| complexity            | 14         | 14            | 0       |
| firebase              | 29         | 29            | 0       |
| memory_management     | 13         | 13            | 0       |
| return                | 7          | 7             | 0       |
| stylistic_additional | 24         | 24            | 0       |
| web                   | 8          | 8             | 0       |
| animation             | 19         | 19            | 0       |
| config                | 7          | 7             | 0       |
| connectivity          | 3          | 3             | 0       |
| freezed               | 10         | 10            | 0       |
| isar                  | 21         | 21            | 0       |
| notification          | 8          | 8             | 0       |
| sqflite               | 2          | 2             | 0       |
| type_safety           | 17         | 17            | 0       |
| ui_ux                 | 20         | 20            | 0       |
| widget_lifecycle      | 36         | 36            | 0       |

---

## 3. Rule instantiation tests — DONE for 99 categories

All 99 category test files have a “Rule Instantiation” group (one test per rule: instantiate, assert `code.name`, `problemMessage` contains `[code_name]`, length > 50, `correctionMessage` non-null). Any other category test file can reuse the same pattern if needed.

**Publish script:** Rule-instantiation status is derived from the codebase in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`): it scans each `test/{category}_rules_test.dart` for the string `Rule Instantiation`. The “Test Coverage” report shows a “Rule inst.” line (categories with that group / categories with a test file). This document is for human reference only; the script does not read it.

---

## 4. Real behavioral tests — STARTED

**Status:** One integration test runs the linter on the example_async package and asserts that when custom_lint reports violations, specific rules (e.g. `avoid_catch_all`, `avoid_dialog_context_after_async`, `require_stream_controller_close`, `require_feature_flag_default`, `prefer_specifying_future_value_type`) appear in the parsed output. See `test/fixture_lint_integration_test.dart` — "custom_lint on example_async reports expected rules from fixtures". When custom_lint cannot run (e.g. resolver conflict) or reports no violations, the test skips per-rule assertions. Full per-rule behavioral coverage (violating snippet → lint, compliant snippet → no lint) is not yet done.

**Recommendation:** Add more rules to the expected list and/or a test pattern (e.g. custom_lint test helpers or a small runner) for at least high-impact rules:

- One test: violating code → expect lint with expected `code.name`.
- One test: compliant code → expect no lint for that rule.

Priority candidates: security, accessibility, error_handling, async rules.

---

## 5. Summary

| Need | Status |
|------|--------|
| Fixtures (per-rule in reviewed categories) | **Done** |
| Rule instantiation tests (per-rule metadata) | **Done for 99 categories** |
| Real behavioral tests (linter on code) | **Started** (one integration test) |

Completed work is summarized in [bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md](history/unit_test_coverage_fixtures_and_instantiation_completed.md).
