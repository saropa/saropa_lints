# Unit Test Coverage: Status and Plan to 100%

**Last updated:** 2026-03-02  
**Scope:** All lint rules in `lib/src/rules/` and all rule-related tests in `test/`.  
**Goal:** Publish “Test Coverage” report shows **Fixtures = 100%**.

This document merges the former **UNIT_TEST_COVERAGE_REVIEW.md** (current status) and **FULL_TEST_COVERAGE_PLAN.md** (checklist). Ground truth analysis (if present): `reports/missing_fixtures_analysis.md`.

---

## Policy: No stub fixtures

**Stub fixtures are prohibited.** A fixture file must not be added for a rule until that rule is implemented and the fixture is validated.

- **Do not** add a fixture that only contains `// expect_lint: rule_name` and placeholder BAD/GOOD code when the rule’s `runWithReporter()` is empty or does not report on that code. That is a stub and inflates coverage without testing anything.
- **Do** add a fixture only when the rule actually runs and reports on the BAD example (so that `expect_lint` would fail if the rule regressed). The fixture must be validated (e.g. by running the linter on the example package or by an integration test that asserts the expected lint appears).
- **If a rule is not yet implemented:** do not create a fixture for it. Fix the metrics (§6.1–6.2) and/or implement the rule first; then add the fixture and validate it.

Counting stub files as “fixtures” is not allowed.

---

## 1. Current status at a glance

| Item | Status | Notes |
|------|--------|--------|
| Fixtures (one per rule in reviewed categories) | **Done for 27 categories** | Those 27 have 0 missing. Other rules still need fixtures — see §6.3. |
| Rule instantiation tests (one per rule, metadata assertions) | **Done for 99 categories** | All category test files have a Rule Instantiation group. See §3. |
| Real behavioral tests (linter on code, assert lint present/absent) | **In progress** | Violating→lint and compliant→no lint in `fixture_lint_integration_test.dart`. See §5. |
| Publish report “Fixtures” metric | **&lt;100%** | ~98.3% due to metrics bugs and a few real gaps. See §4 and §6. |

---

## 2. Fixtures — 27 categories complete (others have gaps)

All 27 categories below have **0 rules without a dedicated fixture**. Other categories/rules still have missing fixtures; see §6.3 for the list to add.

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
| notification         | 8          | 8             | 0       |
| sqflite               | 2          | 2             | 0       |
| type_safety           | 17         | 17            | 0       |
| ui_ux                 | 20         | 20            | 0       |
| widget_lifecycle      | 36         | 36            | 0       |

---

## 3. Rule instantiation tests — Done for 99 categories

All 99 category test files have a “Rule Instantiation” group (one test per rule: instantiate, assert `code.name`, `problemMessage` contains `[code_name]`, length &gt; 50, `correctionMessage` non-null).

**Publish script:** Rule-instantiation status is derived in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`): it scans each `test/{category}_rules_test.dart` for the string `Rule Instantiation`. The “Test Coverage” report shows a “Rule inst.” line. This document is for human reference only; the script does not read it.

---

## 4. Why the publish report shows Fixtures &lt; 100%

- **A. code_quality categories don’t map to fixtures**
  - Rules live in 4 category files: `code_quality_avoid`, `code_quality_control_flow`, `code_quality_prefer`, `code_quality_variables`.
  - Fixtures live in **one dir**: `example_core/lib/code_quality/*.dart` (104 fixture files).
  - `_count_fixtures_for_category(category)` in `scripts/modules/_rule_metrics.py` looks for `example_*/lib/{category}/` and returns **0** for each `code_quality_*` category. This accounts for **104** of the reported missing fixtures.

- **B. isar shows 21/22 due to a commented-out rule class**
  - `lib/src/rules/packages/isar_rules.dart` contains a **commented-out** class. `_RULE_CLASS_RE` counts `class ... extends ...` even inside `//` comments, so category rule-count is inflated by 1. Tests and fixtures already treat Isar as 21 rules.

- **C. Real missing fixtures**
  - After fixing (A) and (B), some rules still need fixture files. They are listed in the checklist (§6).

---

## 5. Real behavioral tests — Started

Integration tests in `test/fixture_lint_integration_test.dart`: run custom_lint on example_async and assert expected rule codes when violations exist; assert compliant-only fixture has zero violations. Full per-rule behavioral coverage (violating → lint, compliant → no lint) is not yet done.

**Recommendation:** Add more rules to the expected list and/or a test pattern for at least high-impact rules (security, accessibility, error_handling, async). Priority: one test “violating code → expect lint”; one test “compliant code → expect no lint.”

---

## 6. Checklist: reach Fixtures = 100% in publish report

### 6.0) Reproduce baseline (optional)

- [ ] Run the publish coverage report and record: Fixtures `X/1964`, lowest fixture coverage list.

### 6.1) Fix metrics: code_quality_* categories

Pick one approach (1A lower-risk; 1B higher churn).

- [ ] **1A (recommended): update** `scripts/modules/_rule_metrics.py`
  - [ ] In `_count_fixtures_for_category(...)`: if `category.startswith('code_quality_')`, look in `example_core/lib/code_quality/`.
  - [ ] **Important:** Do not return `len(code_quality_dir/*_fixture.dart)` for every `code_quality_*` (would overcount 4×). Parse rule code names from the category’s rule file and count only fixtures whose basename matches those rule names (e.g. first string literal in each `LintCode(...)`; fixtures named `{rule_name}_fixture.dart`).

- [ ] **1B: merge code_quality to one category**
  - [ ] Merge the 4 files into one `lib/src/rules/code_quality_rules.dart` (category `code_quality`), update `all_rules.dart`, keep fixtures in `example_core/lib/code_quality/`.

### 6.2) Fix metrics: don’t count commented-out rule classes

- [ ] Update `_RULE_CLASS_RE` usage in `scripts/modules/_rule_metrics.py` so it doesn’t count `class ... extends ...` inside line comments (e.g. strip `//` lines before regex, or use `^(?!\s*//)\s*class ... extends ...` with `re.MULTILINE`; handle block comments if needed).
- [ ] Re-run coverage and confirm Isar no longer shows 1 missing fixture.

### 6.3) Add real missing fixture files

**No stubs.** Add a fixture only when the rule is implemented and the BAD example actually triggers the linter. Validate the fixture (run the linter on the example package or an integration test that asserts the expected lint). Do not add a file that only has `expect_lint` and placeholder code if the rule does not run on that code.

For each item: create `.../{rule_name}_fixture.dart` with at least a **BAD** example (`// expect_lint: {rule_name}`) that the rule reports on, and a **GOOD** example (no expect_lint). Follow existing fixture style in that directory. If the rule is not yet implemented, implement it first or leave the fixture out; do not add a stub.

| Category        | Rule(s) | Directory |
|-----------------|--------|-----------|
| architecture    | `prefer_builder_pattern` | `example_core/lib/architecture/` |
| async           | `avoid_void_async` | `example_async/lib/async/` |
| class_constructor | `prefer_final_fields_always` | `example_core/lib/class_constructor/` |
| config          | `prefer_compile_time_config`, `prefer_flavor_configuration` | `example_async/lib/config/` |
| connectivity    | `prefer_connectivity_debounce` | `example_async/lib/connectivity/` |
| freezed         | `prefer_freezed_union_types` | `example_packages/lib/freezed/` |
| json_datetime   | `prefer_correct_json_casts` | `example_async/lib/json_datetime/` |
| navigation      | `prefer_go_router_builder` | `example_widgets/lib/navigation/` |
| auto_route      | `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args` | `example_packages/lib/auto_route/` |
| bloc            | `avoid_cubit_usage` | `example_packages/lib/bloc/` |
| firebase        | `prefer_firebase_transaction_for_counters`, `prefer_correct_topics`, `prefer_deep_link_auth` | `example_packages/lib/firebase/` |
| geolocator      | `prefer_geolocation_coarse_location` | `example_packages/lib/geolocator/` |
| getx            | `avoid_getx_rx_nested_obs` | `example_packages/lib/getx/` |
| riverpod        | `avoid_riverpod_string_provider_name` | `example_packages/lib/riverpod/` |
| performance     | `prefer_disk_cache_for_persistence` | `example_async/lib/performance/` |
| record_pattern  | `prefer_class_destructuring` | `example_core/lib/record_pattern/` |
| return          | `avoid_returning_this` | `example_core/lib/return/` |
| stylistic       | `prefer_expression_body_getters`, `prefer_block_body_setters` | `example_style/lib/stylistic/` |
| theming         | `prefer_dark_mode_colors`, `prefer_high_contrast_mode` | `example_widgets/lib/theming/` |
| widget_layout   | `prefer_flex_for_complex_layout`, `prefer_find_child_index_callback` | `example_widgets/lib/widget_layout/` |
| widget_patterns | `avoid_bool_in_widget_constructors`, `avoid_unnecessary_containers`, `prefer_const_literals_to_create_immutables` | `example_widgets/lib/widget_patterns/` |

### 6.4) Update test fixture lists and rule instantiation tests

- [ ] `test/config_rules_test.dart`: add fixtures `prefer_compile_time_config`, `prefer_flavor_configuration`; add Rule Instantiation for `PreferCompileTimeConfigRule`, `PreferFlavorConfigurationRule`.
- [ ] `test/auto_route_rules_test.dart`: add fixtures `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args`; add Rule Instantiation for the two rules.
- [ ] Update other `test/{category}_rules_test.dart` fixture lists for categories in §6.3 where applicable.

### 6.5) Verify

- [ ] Re-run publish coverage and confirm **Fixtures = 100%**.
- [ ] Run `dart test`.
- [ ] Run `dart analyze --fatal-infos`.

---

## 7. Summary

| Need | Status |
|------|--------|
| Fixtures (per-rule in 27 reviewed categories) | **Done** |
| Rule instantiation tests (99 categories) | **Done** |
| Real behavioral tests (linter on code) | **In progress** |
| Publish report Fixtures = 100% | **Checklist above** |

Completed fixture and rule-instantiation work is summarized in `bugs/history/unit_test_coverage_fixtures_and_instantiation_completed.md` (if present).
