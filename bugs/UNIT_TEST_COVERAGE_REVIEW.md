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
| Rule instantiation tests (one per rule, metadata assertions) | **Done for 55 categories** | 55 test files have a Rule Instantiation group. See §3. |
| Real behavioral tests (linter on code, assert lint present/absent) | **Not done** | 0 such tests. See §4. |

---

## 1. Test quality (current state)

- **Fixture verification:** Done. Test files that list fixtures have “fixture exists” tests (real assertions).
- **Behavioral tests:** Almost all are placeholders (`expect('...', isNotNull)`). They do **not** run the linter on code or assert lint output.
- **Rule instantiation tests:** Done for 55 categories. Each of those test files has a group that instantiates every rule and asserts `code.name`, `problemMessage`, `correctionMessage` (see bugs/history summary).

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

## 3. Rule instantiation tests — DONE for 55 categories

55 test files have a “Rule Instantiation” group (one test per rule: instantiate, assert `code.name`, `problemMessage` contains `[code_name]`, length > 50, `correctionMessage` non-null). Any other category test file can reuse the same pattern if needed.

**Publish script:** Rule-instantiation status is derived from the codebase in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`): it scans each `test/{category}_rules_test.dart` for the string `Rule Instantiation`. The “Test Coverage” report shows a “Rule inst.” line (categories with that group / categories with a test file). This document is for human reference only; the script does not read it.

---

## 4. Real behavioral tests — NOT DONE

**Status:** No tests currently run the linter on a code snippet and assert that violating code produces a lint and compliant code does not.

**Recommendation:** Add a test pattern (e.g. custom_lint test helpers or a small runner) and then add, for at least high-impact rules:

- One test: violating code → expect lint with expected `code.name`.
- One test: compliant code → expect no lint for that rule.

Priority candidates: security, accessibility, error_handling, async rules.

---

## 5. Summary

| Need | Status |
|------|--------|
| Fixtures (per-rule in reviewed categories) | **Done** |
| Rule instantiation tests (per-rule metadata) | **Done for 55 categories** |
| Real behavioral tests (linter on code) | **Not done** |

Completed work is summarized in [bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md](history/unit_test_coverage_fixtures_and_instantiation_completed.md).
