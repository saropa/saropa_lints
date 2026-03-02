# Full test coverage — checklist plan

**Goal:** Make the publish “Test Coverage” report show **Fixtures = 100%**.

**Ground truth analysis:** `d:/src/saropa_lints/reports/missing_fixtures_analysis.md`

## What’s actually broken (from research)

- **A. code_quality categories don’t map to fixtures**
  - Rules live in 4 category files:
    - `lib/src/rules/code_quality_avoid_rules.dart` → category `code_quality_avoid`
    - `lib/src/rules/code_quality_control_flow_rules.dart` → category `code_quality_control_flow`
    - `lib/src/rules/code_quality_prefer_rules.dart` → category `code_quality_prefer`
    - `lib/src/rules/code_quality_variables_rules.dart` → category `code_quality_variables`
  - Fixtures live in **one dir**: `example_core/lib/code_quality/*.dart` (104 fixture files).
  - The metrics function `_count_fixtures_for_category(category)` in `scripts/modules/_rule_metrics.py` looks for `example_*/lib/{category}/` and therefore returns **0** for each `code_quality_*` category.
  - This single mapping issue accounts for **104** of the reported missing fixtures.

- **B. isar shows 21/22 due to a commented-out rule class**
  - `lib/src/rules/packages/isar_rules.dart` contains a **commented-out** class:
    - `// class RequireIsarNonNullableMigrationRule extends SaropaLintRule { ... }`
  - `_RULE_CLASS_RE` counts `class ... extends ...` **even inside `//` comments**, so category rule-count is inflated by 1.
  - The tests already treat Isar as **21 rules** (see `test/isar_rules_test.dart` header), and there are **21** Isar fixture files (`example_packages/lib/isar/*_fixture.dart`).

- **C. There are still real missing fixtures**
  - After fixing (A) and (B), you’ll still need to add missing fixture files for specific rules (listed below).

## Checklist

### 0) Reproduce baseline (optional but recommended)

- [ ] Run the publish coverage report (whatever command you used to produce terminal output) and record:
  - Fixtures: `X/1964` (currently reported ~98.3% in your terminal)
  - Lowest fixture coverage list

### 1) Fix metrics: make code_quality_* categories count fixtures

Pick one of these approaches (A is lower-risk; B is higher churn).

- [ ] **1A (recommended): update metrics mapping in** `scripts/modules/_rule_metrics.py`
  - [ ] Add a special case in `_count_fixtures_for_category(...)`:
    - If `category.startswith('code_quality_')`, look in `example_core/lib/code_quality/`.
  - [ ] **Important:** don’t just return `len(code_quality_dir/*_fixture.dart)` for every `code_quality_*` category (that would overcount 4x).
    - Instead, parse rule code names from the category’s rule file and count only fixtures whose basename matches one of those rule names.
    - (The rule names are the first string literal inside each `LintCode(...)` call; `test/code_quality_rules_test.dart` already enumerates many of them, and fixtures are named `{rule_name}_fixture.dart`.)

- [ ] **1B: merge code_quality back to one category**
  - [ ] Merge the 4 files into one `lib/src/rules/code_quality_rules.dart` (category becomes `code_quality`)
  - [ ] Update `lib/src/rules/all_rules.dart` exports
  - [ ] Keep fixtures in `example_core/lib/code_quality/`

### 2) Fix metrics: don’t count commented-out rule classes

- [ ] Update `_RULE_CLASS_RE` usage in `scripts/modules/_rule_metrics.py` so it doesn’t count `class ... extends ...` inside line comments.
  - Practical implementation options:
    - Strip `// ...` comments from file text before applying `_RULE_CLASS_RE`, or
    - Change the regex to `^(?!\\s*//)\\s*class ... extends ...` with `re.MULTILINE`, and separately handle block comments if needed.
- [ ] Re-run the coverage report and confirm Isar is no longer reported as missing 1 fixture.

### 3) Add real missing fixture files (rule-by-rule)

For each item below:
- Create `.../{rule_name}_fixture.dart` in the specified directory
- Include at least:
  - **BAD** example with `// expect_lint: {rule_name}`
  - **GOOD** example with no `expect_lint`
- Follow the existing fixture style in that directory (ignore headers, mock imports, etc.).

#### architecture (1)
- [ ] `prefer_builder_pattern` → `example_core/lib/architecture/`

#### async (1)
- [ ] `avoid_void_async` → `example_async/lib/async/`

#### class_constructor (1)
- [ ] `prefer_final_fields_always` → `example_core/lib/class_constructor/`

#### config (2)
- [ ] `prefer_compile_time_config` → `example_async/lib/config/`
- [ ] `prefer_flavor_configuration` → `example_async/lib/config/`

#### connectivity (1)
- [ ] `prefer_connectivity_debounce` → `example_async/lib/connectivity/`

#### freezed (1)
- [ ] `prefer_freezed_union_types` → `example_packages/lib/freezed/`

#### json_datetime (1)
- [ ] `prefer_correct_json_casts` → `example_async/lib/json_datetime/`

#### navigation (1)
- [ ] `prefer_go_router_builder` → `example_widgets/lib/navigation/`

#### auto_route (2)
- [ ] `prefer_auto_route_path_params_simple` → `example_packages/lib/auto_route/`
- [ ] `prefer_auto_route_typed_args` → `example_packages/lib/auto_route/`

#### bloc (1)
- [ ] `avoid_cubit_usage` → `example_packages/lib/bloc/`

#### firebase (3)
- [ ] `prefer_firebase_transaction_for_counters` → `example_packages/lib/firebase/`
- [ ] `prefer_correct_topics` → `example_packages/lib/firebase/`
- [ ] `prefer_deep_link_auth` → `example_packages/lib/firebase/`

#### geolocator (1)
- [ ] `prefer_geolocation_coarse_location` → `example_packages/lib/geolocator/`

#### getx (1)
- [ ] `avoid_getx_rx_nested_obs` → `example_packages/lib/getx/`

#### riverpod (1)
- [ ] `avoid_riverpod_string_provider_name` → `example_packages/lib/riverpod/`

#### performance (1)
- [ ] `prefer_disk_cache_for_persistence` → `example_async/lib/performance/`

#### record_pattern (1)
- [ ] `prefer_class_destructuring` → `example_core/lib/record_pattern/`

#### return (1)
- [ ] `avoid_returning_this` → `example_core/lib/return/`

#### stylistic (2)
- [ ] `prefer_expression_body_getters` → `example_style/lib/stylistic/`
- [ ] `prefer_block_body_setters` → `example_style/lib/stylistic/`

#### theming (2)
- [ ] `prefer_dark_mode_colors` → `example_widgets/lib/theming/`
- [ ] `prefer_high_contrast_mode` → `example_widgets/lib/theming/`

#### widget_layout (2)
- [ ] `prefer_flex_for_complex_layout` → `example_widgets/lib/widget_layout/`
- [ ] `prefer_find_child_index_callback` → `example_widgets/lib/widget_layout/`

#### widget_patterns (3)
- [ ] `avoid_bool_in_widget_constructors` → `example_widgets/lib/widget_patterns/`
- [ ] `avoid_unnecessary_containers` → `example_widgets/lib/widget_patterns/`
- [ ] `prefer_const_literals_to_create_immutables` → `example_widgets/lib/widget_patterns/`

### 4) Update test fixture lists + rule instantiation tests

Many category tests have a hardcoded `fixtures = [...]` list that asserts each fixture file exists.

Update these at minimum:

- [ ] `test/config_rules_test.dart`
  - [ ] Add 2 fixtures to the list: `prefer_compile_time_config`, `prefer_flavor_configuration`
  - [ ] Add Rule Instantiation tests for `PreferCompileTimeConfigRule` and `PreferFlavorConfigurationRule`

- [ ] `test/auto_route_rules_test.dart`
  - [ ] Add 2 fixtures to the list: `prefer_auto_route_path_params_simple`, `prefer_auto_route_typed_args`
  - [ ] Add Rule Instantiation tests for `PreferAutoRoutePathParamsSimpleRule` and `PreferAutoRouteTypedArgsRule`

Also update the relevant `test/{category}_rules_test.dart` files for each category in section 3 if they have fixture lists.

### 5) Verify

- [ ] Re-run the publish coverage report and confirm **Fixtures = 100%**
- [ ] Run `dart test`
- [ ] Run `dart analyze --fatal-infos`

