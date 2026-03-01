# Full Review: Lint Rules Unit Test Coverage

**Date:** 2025-03-01  
**Scope:** All lint rules in `lib/src/rules/` and all rule-related tests in `test/`.

---

## Executive Summary

- **Total rules:** 1,886  
- **Total categories:** 99 (all have at least one test file)  
- **Total `test()` calls** in rule test files: 3,421  

**Findings:**

1. **Almost all behavioral tests are placeholders** — they do not run the linter on code or assert on lint results. They use `expect('description', isNotNull)` and only document intent.
2. **Rule instantiation tests:** 55 test files now include a "Rule Instantiation" group (asserting `rule.code.name`, `problemMessage` contains `[code_name]`, `problemMessage.length` > 50, `correctionMessage` non-null). See §3 for list. Originally only 3 files had metadata tests (auto_route, migration, rxdart).
3. **No tests** use a “run linter on code string” API (e.g. `analyzeCode` / custom_lint test helpers) to assert that bad code produces a lint and good code does not.
4. ~~**66 rules** have no dedicated fixture file (27 categories have more rules than fixtures).~~ **Resolved:** All 66 missing fixtures have been added; see §2.

Only rules that **can use extra tests** are listed below (missing fixtures, missing metadata tests, or placeholder-only behavioral tests).

---

## 1. Test Quality: Placeholder vs Real Assertions

Across the rule test files:

- **Fixture verification:** Every rule test file that lists fixtures includes “fixture exists” tests (file path exists). These are **real** assertions.
- **Behavioral tests:** The vast majority of “SHOULD trigger” / “should NOT trigger” tests are **placeholders**:  
  `expect('some description', isNotNull)`.  
  They do **not** run the analyzer on Dart code or check lint output. So they do not guard against regressions in rule logic.
- **Rule metadata tests:** 55 test files now include a "Rule Instantiation" group (one test per rule). Originally: `auto_route_rules_test.dart`, `migration_rules_test.dart`, `rxdart_rules_test.dart`. Added for: animation, api_network, architecture, accessibility, async, bloc, class_constructor, collection, complexity, config, connectivity, context, control_flow, crypto, debug, db_yield, dio, disposal, documentation, equatable, equality, error_handling, exception, firebase, forms, freezed, get_it, getx, hive, image, isar, lifecycle, memory_management, migration, naming_style, navigation, notification, performance, platform, provider, return, riverpod, scroll, security, sqflite, structure, theming, type, type_safety, ui_ux, web, widget_lifecycle (and others).  

**Conclusion:** All other rules can use extra tests in two ways:

- **Rule instantiation tests** (like auto_route / migration / rxdart): instantiate the rule and assert `rule.code.name`, `problemMessage` (and optionally length), and `correctionMessage`.
- **Behavioral tests** (ideal): run the linter on a snippet of Dart code (e.g. via custom_lint test utilities if available) and assert that violating code produces the expected lint and compliant code produces none.

---

## 2. Rules Without a Dedicated Fixture (66 rules in 27 categories)

These categories have **more rules than fixtures**. Adding a `*_fixture.dart` per missing rule (and a corresponding “fixture exists” test) would close the gap. The exact rule names for each gap would need to be derived from the rule file (e.g. by comparing `LintCode` names to existing fixture filenames).

| Category              | Rule count | Fixture count | Missing |
|-----------------------|-----------:|--------------:|--------:|
| structure             | 45         | 45            | 0       |
| class_constructor     | 20         | 20            | 0       |
| naming_style          | 28         | 28            | 0       |
| type                  | 18         | 18            | 0       |
| control_flow          | 31         | 31            | 0       |
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
| stylistic_additional  | 24         | 24            | 0       |
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

**Total:** 27 categories; **0 rules** now without a dedicated fixture (all 66 gaps filled).

**Update (completed):** All 66 missing fixtures have been added; test fixture lists and CHANGELOG updated. Isar has 21 active rules (one commented out); all 21 have fixtures.

**Recommendation (done):** For each rule that had no fixture, the following was added:

1. A fixture file under the appropriate `example*/lib/<category>/` (e.g. `example_core/lib/structure/<rule_name>_fixture.dart`) with at least one LINT and one OK case.
2. The corresponding fixture name in the category’s test file `fixtures` list and a “fixture exists” test (if not already covered by a loop).

---

## 3. Rules That Can Use Rule Instantiation Tests

Every rule **except** the 8 covered in the 3 files below can use **rule instantiation** tests (same pattern as in `auto_route_rules_test.dart`, `migration_rules_test.dart`, `rxdart_rules_test.dart`):

- **Already covered (8 rules):**
  - `avoid_auto_route_context_navigation`, `avoid_auto_route_keep_history_misuse`, `require_auto_route_guard_resume`, `require_auto_route_full_hierarchy`
  - `avoid_asset_manifest_json`, `prefer_dropdown_initial_value`, `prefer_on_pop_with_result`
  - `avoid_behavior_subject_last_value`

So **all other rules** (1,886 − 8 = 1,878) are candidates for at least one test that:

- Instantiates the rule class.
- Asserts `rule.code.name` equals the expected string.
- Asserts `rule.code.problemMessage` contains the rule name (or similar) and has a minimum length.
- Asserts `rule.code.correctionMessage` is non-null (and optionally non-empty).

This would catch registration mistakes and doc/code name mismatches.

---

## 4. Rules That Can Use Real Behavioral Tests

**Current state:** There are no tests that:

- Run the linter on a string of Dart code (or a small in-memory file), and  
- Assert that violating code yields exactly the expected lint(s), and  
- Assert that compliant code yields no lint for that rule.

The only “real” run of the linter in tests is the integration test in `test/fixture_lint_integration_test.dart`, which runs `dart run custom_lint` on the `example_async` package and checks that output is parseable — it does not assert per-rule or per-line behavior.

**Recommendation:** Introduce a test pattern (e.g. using custom_lint’s test utilities or a small helper that runs the plugin on a snippet) and add, at least for high-impact or error-prone rules:

- One test with **violating** code → expect one (or more) lint with the expected `code.name`.
- One test with **compliant** code → expect no lint for that rule.

Priority candidates include security, accessibility, and correctness rules (e.g. in `security_rules`, `accessibility_rules`, `error_handling_rules`, `async_rules`).

---

## 5. Summary: What “Extra Tests” Means Per Rule

| Need | Count / scope | Action |
|------|----------------|--------|
| **Missing fixture** | ~~66 rules in 27 categories~~ **Done** | Added `*_fixture.dart` and fixture-exists test for all. |
| **Rule instantiation test** | ~~1,878 rules~~ **Done for 55 categories** | One test per rule in 55 test files; remaining categories can use the same pattern. |
| **Real behavioral test** | All rules (0 currently) | Where feasible, add tests that run the linter on code and assert lint presence/absence. |

This review only reports on **rules that can use extra tests**; it does not list rules that are already fully covered by real assertions (there are none beyond the 8 with metadata tests and the project-wide fixture-exists coverage).
