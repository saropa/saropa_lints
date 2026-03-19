# Plan files (⭐ next in line)

Plans in this folder corresponded to the **10 easiest / next-in-line** items marked with ⭐ in [ROADMAP.md](../../ROADMAP.md).

**All 10 plans implemented and moved to history:** [bugs/history/20260317/](../history/20260317/IMPLEMENTED_cross_file_cli_and_central_stats.md).

| Implemented plan | Section |
|------------------|---------|
| plan_cross_file_cli_entry_point | Part 3 Phase 1 |
| plan_cross_file_analyzer | Part 3 Phase 1 |
| plan_cross_file_reporter | Part 3 Phase 1 |
| plan_cross_file_unit_tests | Part 3 Phase 1 |
| plan_cross_file_readme | Part 3 Phase 1 |
| plan_central_stats_aggregator | Part 2 Future Optimizations |
| plan_cross_file_html_report | Part 3 Phase 3 |
| plan_cross_file_baseline | Part 3 Phase 3 |
| plan_cross_file_ci_exit_codes | Part 3 Phase 3 |
| plan_cross_file_github_actions | Part 3 Phase 3 |
| plan_scan_public_api_file_list_tier | Scan public API, file-list, tier override, JSON ([history/20260319](../history/20260319/IMPLEMENTED_plan_scan_public_api_file_list_tier.md)) |

### Current plans

- **[plan_extension_todos_and_hacks.md](plan_extension_todos_and_hacks.md)** — Extension-only "TODOs & Hacks" sidebar view (regex-based scan, no Dart analyzer).
- **[plan_additional_rules_1_through_10.md](plan_additional_rules_1_through_10.md)** — First 10 rules from [ROADMAP.md § Additional rules](../../ROADMAP.md#additional-rules): no_runtimeType_toString, use_truncating_division, external_with_initializer, illegal_enum_values, wrong_number_of_parameters_for_setter, duplicate_ignore, type_check_with_null, unnecessary_library_name, invalid_runtime_check_with_js_interop_types, argument_must_be_native.
- **[plan_additional_rules_11_through_20.md](plan_additional_rules_11_through_20.md)** — Next 10 (most useful for developers): uri_does_not_exist, depend_on_referenced_packages, secure_pubspec_urls, invalid_visible_outside_template_annotation, prefer_for_elements_to_map_fromIterable, missing_code_block_language_in_doc_comment, unintended_html_in_doc_comment, uri_does_not_exist_in_doc_import, package_names, sort_pub_dependencies.
- **[plan_additional_rules_21_through_30.md](plan_additional_rules_21_through_30.md)** — Constructor/class/record bugs: conflicting_constructor_and_static_member through invalid_super_formal_parameter_location.
- **[plan_additional_rules_31_through_40.md](plan_additional_rules_31_through_40.md)** — Generators, enums, docs: non_constant_map_element through abi_specific_integer_invalid.
- **[plan_additional_rules_41_through_50.md](plan_additional_rules_41_through_50.md)** — Flow/type bugs: argument_type_not_assignable_to_error_handler through invalid_pattern_variable_in_shared_case_scope.
- **[plan_additional_rules_51_through_60.md](plan_additional_rules_51_through_60.md)** — Initialization/redirect/params: invalid_return_type_for_catch_error through super_formal_parameter_without_associated_positional.
- **[plan_additional_rules_61_through_70.md](plan_additional_rules_61_through_70.md)** — Undefined/type-arg/style: undefined_constructor_in_initializer through unnecessary_null_comparison (8 rules).
- **[plan_additional_rules_71_through_80.md](plan_additional_rules_71_through_80.md)** — Reserved for future ROADMAP expansion.
- **[plan_additional_rules_81_through_90.md](plan_additional_rules_81_through_90.md)** — Reserved for future ROADMAP expansion.
- **[plan_log_capture_integration.md](plan_log_capture_integration.md)** — Saropa Lints implementation for optional Log Capture integration: extension public API (getViolationsData, getHealthScoreParams, runAnalysis, runAnalysisForFiles, getVersion), runAnalysisForFiles for stack-trace files, consumer manifest (consumer_contract.json), VIOLATION_EXPORT_API update.

All additional-rule plans are ordered by **developer usefulness** (BLOCKER → MAJOR → MINOR; then Wow; then Effort). The ROADMAP Additional rules table has 69 rows (1–69); row 69 = avoid_unstable_final_fields (removed). Plans 1–10 and 11–70 cover rows 1–10 and 11–68 (58 remaining).

See [ROADMAP.md](../../ROADMAP.md) for other planned work.
