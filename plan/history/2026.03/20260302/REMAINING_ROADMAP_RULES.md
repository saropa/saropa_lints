# Remaining Roadmap Rules (Implement All)

**Purpose:** Checklist for implementing all rules from the [task index](README.md).  
**Rule name:** From filename `task_XXX.md` → rule name `XXX`.  
**Implemented:** Rule name (or documented alias) exists in `lib/src/tiers.dart`.

## Status key

| Status          | Meaning                                                    |
| --------------- | ---------------------------------------------------------- |
| **Done**        | Rule is in tiers (implemented).                            |
| **Skip (Hard)** | Cross-file, heuristics, or YAML; defer per PLAN_100_RULES. |
| **To do**       | Not in tiers; single-file AST feasible (Easy or Medium).   |

## Implemented / covered

<!-- cspell:ignore asmap rxdart -->
These task rule names are already implemented (or covered by an existing rule):

- **require_riverpod_lint_package** → covered by **require_riverpod_lint**
- **fold** → covered by **prefer_fold_over_reduce**
- **prefer_const_constructor_declarations** → covered by **prefer_declaring_const_constructor**
- **avoid_freezed_invalid_annotation_target** — implemented (freezed_rules.dart)
- **avoid_referencing_subclasses** — implemented (class_constructor_rules.dart)
- **avoid_test_on_real_device** — implemented (test_rules.dart)
- **avoid_unnecessary_null_aware_elements** — implemented (unnecessary_code_rules.dart)
- **prefer_asmap_over_indexed_iteration** — implemented (collection_rules.dart)
- **prefer_import_over_part** — implemented (structure_rules.dart)
- **prefer_result_type** — implemented (type_rules.dart)
- **prefer_correct_throws** — implemented (documentation_rules.dart)
- **prefer_layout_builder_for_constraints** — implemented (widget_layout_rules.dart)
- **require_const_list_items** — implemented (collection_rules.dart)
- **prefer_context_read_not_watch** → covered by **prefer_context_read_in_callbacks** (provider_rules.dart)
- **prefer_cache_extent** — implemented (scroll_rules.dart)
- **prefer_biometric_protection** — implemented (security_rules.dart)
- **avoid_renaming_representation_getters** — implemented (class_constructor_rules.dart)
- **tag_name** → covered by **prefer_kebab_tag_name** (naming_style_rules.dart)
- **pattern_fields_ordering** → covered by **prefer_sorted_pattern_fields** (record_pattern_rules.dart)
- **record_fields_ordering** → covered by **prefer_sorted_record_fields** (record_pattern_rules.dart)
- **require_error_handling_graceful**, **require_exception_documentation**, **require_example_in_documentation**, **require_parameter_documentation**, **require_return_documentation**, **suggest_yield_after_db_read** — implemented (error_handling_rules.dart, documentation_rules.dart, db_yield_rules.dart).
- All Easy rules from Batch 1 in PLAN_100_RULES are implemented (see CHANGELOG and tiers).

## Hard (skip for “implement all” single-file batch)

Implement only when cross-file/heuristics/YAML support exists.

| Task                                        | Importance |
| ------------------------------------------- | ---------- |
| task_avoid_importing_entrypoint_exports.md  | High       |
| task_handle_bloc_event_subclasses.md        | High       |
| task_prefer_automatic_dispose.md            | High       |
| task_prefer_composition_over_inheritance.md | High       |
| task_prefer_correct_screenshots.md          | High       |
| task_prefer_inline_comments_sparingly.md    | Medium     |
| task_prefer_intent_filter_export.md         | High       |
| task_require_di_module_separation.md        | High       |
| task_require_resource_tracker.md            | Medium     |

## To do (Easy then Medium; prefer High importance)

Implement in this order: **Easy** first, then **Medium**, and within each group prefer **High** importance.

### Easy – to do

| Rule name                                                    | Importance | Note |
| ------------------------------------------------------------ | ---------- | ---- |
| (All Easy from index are implemented or covered; none left.) |            |      |

### Medium – to do (High importance first)

**Implemented (106+ rules):** prefer_auto_route_path_params_simple, … (see list in previous version), plus require_error_handling_graceful, require_exception_documentation, require_example_in_documentation, require_parameter_documentation, require_return_documentation, suggest_yield_after_db_read (all in tiers). tag_name → prefer_kebab_tag_name; pattern_fields_ordering → prefer_sorted_pattern_fields; record_fields_ordering → prefer_sorted_record_fields.

| Rule name | Importance | Status |
| --------- | ---------- | ------ |
| *(All High/Medium to-do rules above are implemented or covered.)* | | Done |

### Medium – to do (Medium / Low importance)

| Rule name | Importance | Status |
| --------- | ---------- | ------ |
| pattern_fields_ordering | Low | Covered by **prefer_sorted_pattern_fields** |
| record_fields_ordering | Low | Covered by **prefer_sorted_record_fields** |

---

## How to implement each rule

1. Open `bugs/roadmap/task_<rule_name>.md` for examples and detection notes.
2. Add rule class in the right `lib/src/rules/*_rules.dart`.
3. Register in `lib/saropa_lints.dart` and add to the correct set in `lib/src/tiers.dart`.
4. Add `testRule(...)` and fixture list entry in `test/*_rules_test.dart`.
5. Add `example_*/lib/.../<rule_name>_fixture.dart` with LINT/OK comments.
6. Add one line under [Unreleased] in `CHANGELOG.md`.
7. Run `dart analyze lib` and the relevant tests.

**Total to do (Medium, excluding Hard):** ~120+ rules. Implement in batches of 10–20; prefer High importance first.
