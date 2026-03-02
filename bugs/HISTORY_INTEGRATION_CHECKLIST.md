# bugs/history integration checklist

Review 100% of `bugs/history` files and integrate into the codebase.

**First 10 reviewed (false_positives):** All 10 had fixes already in rule implementations and CHANGELOG_ARCHIVE. Integrated: rule DartDoc exemptions, CHANGELOG [Unreleased] bullet, and FP test groups for avoid_barrel_files and avoid_duplicate_number_elements. History files kept (not deleted) for detail.

- **Rule doc header:** Add/update DartDoc on the rule class (known FPs, edge cases).
- **CHANGELOG:** Ensure `### Fixed` (or `### Added`) has an entry per affected rule.
- **Tests:** Add or extend false-positive tests in `test/false_positive_fixes_test.dart` or rule test; add regression tests for rule bugs.
- **Fixtures:** Ensure “good” examples match FP cases where relevant.

After integration, remove history references from CHANGELOG and delete or archive the file.

---

## Phase 1: false_positives (82 files)

- [x] bugs/history/false_positives/avoid_barrel_files_false_positive_package_entry_point.md
- [x] bugs/history/false_positives/avoid_duplicate_number_elements_false_positive_days_in_month.md
- [x] bugs/history/false_positives/avoid_duplicate_string_literals_false_positive_domain_semantic_constants.md
- [x] bugs/history/false_positives/avoid_dynamic_sql_false_positive_pragma_statements.md
- [x] bugs/history/false_positives/avoid_dynamic_type_false_positive_json_context.md
- [x] bugs/history/false_positives/avoid_dynamic_type_false_positive_json_utilities.md
- [x] bugs/history/false_positives/avoid_excessive_expressions_false_positive_guard_clauses_and_symmetric_patterns.md
- [x] bugs/history/false_positives/avoid_god_class_false_positive_static_const_namespace.md
- [x] bugs/history/false_positives/avoid_hardcoded_locale_false_positive_on_lookup_data.md
- [x] bugs/history/false_positives/avoid_ignoring_return_values_false_positive_map_mutation_methods.md
- [x] bugs/history/false_positives/avoid_ignoring_return_values_false_positive_property_setter_assignment.md
- [x] bugs/history/false_positives/avoid_ios_hardcoded_device_model_false_positive_substring_match.md
- [x] bugs/history/false_positives/avoid_manual_date_formatting_map_key_false_positive.md
- [x] bugs/history/false_positives/avoid_medium_length_files_false_positive_counts_dartdoc.md
- [x] bugs/history/false_positives/avoid_medium_length_files_false_positive_counts_documentation.md
- [x] bugs/history/false_positives/avoid_missing_enum_constant_in_map_false_positive_complete_maps.md
- [x] bugs/history/false_positives/avoid_money_arithmetic_on_double_false_positive_non_financial_variable_names.md
- [x] bugs/history/false_positives/avoid_nested_assignments_false_positive_arrow_function_body.md
- [x] bugs/history/false_positives/avoid_nested_assignments_for_loop_false_positive.md
- [x] bugs/history/false_positives/avoid_non_ascii_symbols_false_positive_unicode_library.md
- [ ] bugs/history/false_positives/avoid_path_traversal_false_positive_private_helper_method.md
- [ ] bugs/history/false_positives/avoid_positioned_outside_stack_false_positive.md
- [ ] bugs/history/false_positives/avoid_positioned_outside_stack_false_positives.md
- [ ] bugs/history/false_positives/avoid_ref_in_build_body_false_positive_callbacks_inside_build.md
- [ ] bugs/history/false_positives/avoid_ref_watch_outside_build_false_positive_riverpod_provider_bodies.md
- [ ] bugs/history/false_positives/avoid_similar_names_false_positives_short_names_and_time_units.md
- [ ] bugs/history/false_positives/avoid_single_child_column_row_if_element_false_positive.md
- [ ] bugs/history/false_positives/avoid_static_state_false_positive_cached_regex_constants.md
- [ ] bugs/history/false_positives/avoid_stream_subscription_in_field_false_positive_listen_as_argument_to_collection_add.md
- [ ] bugs/history/false_positives/avoid_string_concatenation_l10n_false_positive_numeric_only_interpolation.md
- [ ] bugs/history/false_positives/avoid_unbounded_listview_false_positive_in_overlay_callbacks.md
- [ ] bugs/history/false_positives/avoid_unmarked_public_class_false_positive_static_utility_classes.md
- [ ] bugs/history/false_positives/avoid_unnecessary_nullable_return_type_false_positive_conditional_null_branches.md
- [ ] bugs/history/false_positives/avoid_unnecessary_nullable_return_type_false_positive_expression_bodies.md
- [ ] bugs/history/false_positives/avoid_unnecessary_nullable_return_type_false_positive_map_operator.md
- [ ] bugs/history/false_positives/avoid_unnecessary_nullable_return_type_false_positive_nullable_delegation.md
- [ ] bugs/history/false_positives/avoid_unnecessary_setstate_false_positive_closure_callbacks.md
- [ ] bugs/history/false_positives/avoid_unnecessary_to_list_false_positive_required_by_return_type.md
- [ ] bugs/history/false_positives/avoid_unused_assignment_false_positive_conditional_reassignment.md
- [ ] bugs/history/false_positives/avoid_unused_assignment_false_positive_definite_assignment_if_else.md
- [ ] bugs/history/false_positives/avoid_unused_assignment_false_positive_loop_reassignment.md
- [ ] bugs/history/false_positives/avoid_url_launcher_simulator_tests_false_positive_no_launcher_usage.md
- [ ] bugs/history/false_positives/avoid_variable_shadowing_false_positive_non_overlapping_loop_scopes.md
- [ ] bugs/history/false_positives/check_mounted_after_async_false_positive_guard_clause.md
- [ ] bugs/history/false_positives/check_mounted_after_async_false_positives.md
- [ ] bugs/history/false_positives/comment_and_type_arg_false_positives.md
- [ ] bugs/history/false_positives/discussion_062_false_positive_reduction_review.md
- [ ] bugs/history/false_positives/false_positives_kykto.md
- [ ] bugs/history/false_positives/function_always_returns_null_false_positive_async_generator_method.md
- [ ] bugs/history/false_positives/function_always_returns_null_false_positive_async_generator.md
- [ ] bugs/history/false_positives/multiple_false_positives_in_utility_library_context.md
- [ ] bugs/history/false_positives/no_empty_string_false_positive_standard_dart_idiom.md
- [ ] bugs/history/false_positives/no_equal_conditions_false_positive_if_case_pattern_matching.md
- [ ] bugs/history/false_positives/no_magic_number_false_positive_named_default_parameters.md
- [ ] bugs/history/false_positives/prefer_cached_getter_false_positive_extension_getters.md
- [ ] bugs/history/false_positives/prefer_compute_for_heavy_work_false_positive_pure_dart_library.md
- [ ] bugs/history/false_positives/prefer_const_widgets_in_lists_false_positive.md
- [ ] bugs/history/false_positives/prefer_digit_separators_false_positive_small_numbers_and_code_points.md
- [ ] bugs/history/false_positives/prefer_edgeinsets_symmetric_false_positive.md
- [ ] bugs/history/false_positives/prefer_implicit_boolean_comparison_false_positive.md
- [ ] bugs/history/false_positives/prefer_keep_alive_false_positive_naive_tab_string_match.md
- [ ] bugs/history/false_positives/prefer_list_first_false_positive_sibling_index_access.md
- [ ] bugs/history/false_positives/prefer_match_file_name_false_positive_matching_class_name.md
- [ ] bugs/history/false_positives/prefer_named_boolean_parameters_false_positive_lambda_parameters.md
- [ ] bugs/history/false_positives/prefer_no_commented_out_code_false_positive_prose_comments.md
- [ ] bugs/history/false_positives/prefer_prefixed_global_constants_false_positive_dart_convention.md
- [ ] bugs/history/false_positives/prefer_secure_random_false_positive_non_security_shuffling.md
- [ ] bugs/history/false_positives/prefer_setup_teardown_false_positive_expect_as_setup.md
- [ ] bugs/history/false_positives/prefer_static_method_false_positive_extension_methods.md
- [ ] bugs/history/false_positives/prefer_stream_distinct_false_positives.md
- [ ] bugs/history/false_positives/prefer_switch_expression_false_positive_complex_case_logic.md
- [ ] bugs/history/false_positives/prefer_trailing_comma_always_false_positive_callback_arguments.md
- [ ] bugs/history/false_positives/prefer_unique_test_names_false_positive_ignores_group_scoping.md
- [ ] bugs/history/false_positives/prefer_wheretype_over_where_is_false_positive_negated_type_check.md
- [ ] bugs/history/false_positives/require_currency_code_with_amount_false_positive_non_monetary_totals.md
- [ ] bugs/history/false_positives/require_dispose_pattern_false_positive_borrowed_references.md
- [ ] bugs/history/false_positives/require_envied_obfuscation_false_positive_class_level_annotation.md
- [ ] bugs/history/false_positives/require_error_case_tests_false_positive_defensive_source.md
- [ ] bugs/history/false_positives/require_file_path_sanitization_false_positive_private_helper_method.md
- [ ] bugs/history/false_positives/require_hero_tag_uniqueness_false_positive_cross_route_pairs.md
- [ ] bugs/history/false_positives/require_https_only_test_false_positive_url_utility_tests.md
- [ ] bugs/history/false_positives/require_intl_currency_format_false_positive_dollar_interpolation.md
- [ ] bugs/history/false_positives/require_ios_callkit_false_positive_substring_match.md
- [ ] bugs/history/false_positives/require_ios_callkit_false_positive_whole_word_agora.md
- [ ] bugs/history/false_positives/require_list_preallocate_false_positive_unknowable_size.md
- [ ] bugs/history/false_positives/require_location_timeout_false_positive_permission_checks.md
- [ ] bugs/history/false_positives/require_number_format_locale_false_positive_device_locale.md
- [ ] bugs/history/false_positives/string_contains_false_positive_audit.md

---

## Phase 1: rule_bugs (22 files)

- [ ] bugs/history/rule_bugs/avoid_empty_setstate severity.md
- [ ] bugs/history/rule_bugs/avoid_empty_setstate_wrong_tier.md
- [ ] bugs/history/rule_bugs/avoid_expanded_outside_flex_documentation.md
- [ ] bugs/history/rule_bugs/avoid_large_list_copy_overly_generic_detection.md
- [ ] bugs/history/rule_bugs/avoid_long_parameter_list_ignore_not_respected.md
- [ ] bugs/history/rule_bugs/conflicting_rules_prefer_static_class_vs_prefer_abstract_final_static_class.md
- [ ] bugs/history/rule_bugs/dartdoc_references_nonexistent_parameter.md
- [ ] bugs/history/rule_bugs/detect_unsorted_imports.md
- [ ] bugs/history/rule_bugs/duplicate_rules_async_without_await.md
- [ ] bugs/history/rule_bugs/function_always_returns_null_generator_guard_ineffective.md
- [ ] bugs/history/rule_bugs/no_magic_number_string_in_tests_severity_miscalibration.md
- [ ] bugs/history/rule_bugs/prefer_catch_over_on_reverse_rule.md
- [ ] bugs/history/rule_bugs/prefer_expanded_at_call_site.md
- [ ] bugs/history/rule_bugs/prefer_static_class_regression_on_abstract_final_class.md
- [ ] bugs/history/rule_bugs/quick_fixes_not_appearing_in_vscode.md
- [ ] bugs/history/rule_bugs/report_avoid_deprecated_usage_analyzer_api_crash.md
- [ ] bugs/history/rule_bugs/report_avoid_deprecated_usage_metadataimpl_not_iterable_crash.md
- [ ] bugs/history/rule_bugs/report_duplicate_paths_deduplication.md
- [ ] bugs/history/rule_bugs/report_session_management.md
- [ ] bugs/history/rule_bugs/require_minimum_contrast_ignore_suppression.md
- [ ] bugs/history/rule_bugs/require_yield_between_db_awaits_read_vs_write.md
- [ ] bugs/history/rule_bugs/violation_deduplication.md
- [ ] bugs/history/rule_bugs/yield description and quickfix.md

---

## Phase 2: issues (9 files)

- [ ] bugs/history/issues/issue_020_require_pagination_for_large_lists.md
- [ ] bugs/history/issues/issue_024_prefer_sliverfillremaining_for_empty_state.md
- [ ] bugs/history/issues/issue_025_require_rtl_layout_support.md
- [ ] bugs/history/issues/issue_026_require_stepper_state_management.md
- [ ] bugs/history/issues/issue_029_require_pagination_for_large_lists.md
- [ ] bugs/history/issues/issue_033_prefer_sliverfillremaining_for_empty_state.md
- [ ] bugs/history/issues/issue_034_require_rtl_layout_support.md
- [ ] bugs/history/issues/issue_035_require_stepper_state_management.md
- [ ] bugs/history/issues/issue_038_avoid_infinite_scroll_duplicate_requests.md

---

## Phase 2: migration (5 files)

- [ ] bugs/history/migration/migration to native dart analyzer plugin.md
- [ ] bugs/history/migration/migration-candidate-003-remove_deprecated_assetmanifest_json_file_in.md
- [ ] bugs/history/migration/migration-candidate-007-deprecate_dropdownbuttonformfield_value_parameter_in_favor_o.md
- [ ] bugs/history/migration/migration-candidate-008-clean_up_references_to_deprecated_onpop_method_in_docs_in.md

---

## Phase 3: not_viable/drift (8 files)

- [ ] bugs/history/not_viable/drift/not-viable-avoid_drift_client_default_for_timestamps.md
- [ ] bugs/history/not_viable/drift/not-viable-avoid_drift_custom_constraint_without_not_null.md
- [ ] bugs/history/not_viable/drift/not-viable-avoid_drift_downgrade.md
- [ ] bugs/history/not_viable/drift/not-viable-avoid_drift_multiple_auto_increment.md
- [ ] bugs/history/not_viable/drift/not-viable-prefer_drift_modular_generation.md
- [ ] bugs/history/not_viable/drift/not-viable-require_drift_build_runner.md
- [ ] bugs/history/not_viable/drift/not-viable-require_drift_table_column_trailing_parens.md
- [ ] bugs/history/not_viable/drift/not-viable-require_drift_wal_mode.md

---

## Phase 3: not_viable/framework_upgrade (134 files)

- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-001-material_change_default_mouse_cursor_of_buttons_to_basic_arr.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-002-fix_drawer_child_docstring_to_say_listview_instead_of_sliver.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-004-introduce_a_getter_for_project_to_get_gradle_wrapper_propert.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-005-update_gradleutils_dart_to_use_constant_instead_of_final_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-006-lastenginecommit_ps1_use_flutterroot_instead_of_gittoplevel_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-009-android_gradle_use_lowercase_instead_of_tolowercase_in_prepa.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-010-add_use_addmachineoutputflag_outputsmachineformat_instead_of.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-011-switch_to_linux_orchestrators_for_windows_releasers_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-012-deprecate_themedata_indicatorcolor_in_favor_of_tabbarthemeda.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-013-cp_betaskwasm_use_queuemicrotask_instead_of_postmessage_when.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-014-make_developing_fluttertools_nicer_use_fail_instead_of_throw.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-015-fuchsia_remove_explicit_logsink_and_inspectsink_routing_and_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-016-prefer_using_non_nullable_opacityanimation_property_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-017-deprecate_unused_buttonstylebutton_iconalignment_property_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-018-add_surfaceproducer_onsurfacecleanup_deprecate_onsurfacedest.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-019-native_assets_create_nativeassetsmanifest_json_instead_of_ke.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-020-update_fakecodec_dart_to_use_future_value_instead_of_synchro.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-021-flutter_gpu_use_vm_vector4_for_clear_color_instead_of_ui_col.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-022-deprecate_buttonbar_buttonbarthemedata_and_themedata_buttonb.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-023-use_fml_scopedcleanupclosure_instead_of_deathrattle_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-024-switch_to_iterable_cast_instance_method_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-025-copy_any_previous_iconthemedata_instead_of_overwriting_it_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-026-switch_to_relevant_remote_constructors_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-027-use_super_key_instead_of_manually_passing_the_key_parameter_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-028-use_no_strip_wams_instead_of_no_name_section_in_dart_compile.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-029-issue_anerror_instead_of_an_info_for_a_non_working_api_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-030-switch_to_filterquality_medium_for_images_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-031-switch_to_more_reliable_flutter_dev_link_destinations_in_the.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-032-switch_to_triage_labels_for_platform_package_triage_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-033-remove_deprecated_texttheme_members_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-034-remove_deprecated_keepalivehandle_release_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-035-remove_deprecated_interactiveviewer_alignpanaxis_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-036-remove_deprecated_cupertinocontextmenu_previewbuilder_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-037-fix_chips_use_square_delete_button_inkwell_shape_instead_of_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-038-remove_deprecated_platformmenubar_body_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-039-deprecate_rawkeyevent_rawkeyboard_et_al_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-040-changes_to_use_valuenotifier_instead_of_a_force_rebuild_for_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-041-use_timelinerecorder_systrace_instead_of_systracetimeline_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-042-overlayportal_overlaychild_contributes_semantics_to_overlayp.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-043-fix_typo_of_not_instead_of_now_for_useinheritedmediaquery_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-044-switch_to_chrome_for_testing_instead_of_vanilla_chromium_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-045-windows_move_to_fluttercompositor_for_rendering_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-046-switch_to_chrome_for_testing_instead_of_chromium_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-047-switch_to_android_14_for_physical_device_firebase_tests_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-048-deprecate_usematerial3_parameter_in_themedata_copywith_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-049-new_feature_allowing_the_listview_slivers_to_have_different_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-050-use_utf8_encode_instead_of_longer_const_utf8encoder_convert_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-051-use_start_instead_of_extent_for_windows_ime_cursor_position_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-052-advise_developers_to_use_overflowbar_instead_of_buttonbar_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-053-give_channel_descriptions_in_flutter_channel_use_branch_inst.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-054-fluttertools_modify_skeleton_template_to_use_listenablebuild.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-055-remove_deprecated_appbar_color_appbar_backwardscompatibility.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-056-deprecates_testwindow_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-057-alwaysthrows_is_deprecated_return_never_instead_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-058-use_string_codeunitat_instead_of_string_codeunits_in_paragra.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-059-use_variable_instead_of_multiple_accesses_through_a_map_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-060-use_skiaenableganesh_instead_of_legacy_gn_arg_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-061-initialize_themedata_visualdensity_using_themedata_platform_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-062-windows_use_ninja_instead_of_ninja_exe_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-063-switch_from_noto_emoji_to_noto_color_emoji_and_update_font_d.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-064-deprecate_animatedlistitembuilder_and_animatedlistremovedite.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-065-change_type_in_implicitlyanimatedwidget_to_remove_type_cast_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-066-change_type_in_implicitlyanimatedwidget_to_remove_type_cast_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-067-use_scrollbartheme_instead_theme_for_scrollbar_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-068-fix_references_to_symbols_to_use_brackets_instead_of_backtic.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-069-framework_use_visibility_instead_of_opacity_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-070-use_double_isnan_instead_of_double_nan_which_is_always_false.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-071-error_in_docs_custompaint_instead_of_custompainter_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-072-change_default_value_of_effectiveinactivepressedoverlaycolor.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-073-ignore_uses_of_soon_to_be_deprecated_nullthrownerror_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-074-tool_migrate_off_deprecated_coverage_parameters_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-075-mention_that_navigationbar_is_a_new_widget_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-076-inputdecorator_switch_hint_to_opacity_instead_of_animatedopa.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-077-update_key_examples_to_use_focus_widgets_instead_of_rawkeybo.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-078-remove_deprecated_renderobjectelement_methods_in.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-079-but_false_on_windows_use_filesystementity_typesync_instead_t.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-080-breaking_change_native_classes_in_dart_html_like_htmlelement.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-081-breaking_change_55786_securitycontext_is_now_final_this_mean.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-082-deprecates_filesystemdeleteevent_isdirectory_which_always_re.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-083-added_option_for_parallelwaiterror_to_get_some_meta_informat.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-084-breaking_change_53863_stdout_has_a_new_field_lineterminator.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-085-added_option_for_parallelwaiterror_to_get_some_meta_informat.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-086-breaking_change_53863_stdout_has_a_new_field_lineterminator.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-087-core_pointer_types_are_now_deprecated.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-088-jsanyoperatorextension_for_the_new_extensions_this_shouldn_t.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-089-deprecated_the_service_getisolateid_method.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-090-jsnumber_todart_is_removed_in_favor_of_todartdouble_and_toda.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-091-both_apis_now_return_a_bool_instead_of_a_jsboolean_typeofequ.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-092-now_takes_in_a_string_instead_of_a_jsstring.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-093-this_api_now_takes_in_an_int_instead_of_jsnumber.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-094-added_a_deprecation_warning_when_platform_is_instantiated.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-095-added_class_samesite.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-096-calls_these_members_and_use_that_instead.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-097-use_deprecated_message_instead.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-098-removed_the_deprecated_list_constructor_as_it_wasn_t_null_sa.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-099-removed_the_deprecated_proxy_and_provisional_annotations.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-100-removed_the_deprecated_deprecated_expires_getter.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-101-removed_the_deprecated_casterror_error.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-102-removed_the_deprecated_fallthrougherror_error_the_kind_of.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-103-removed_the_deprecated_abstractclassinstantiationerror_error.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-104-removed_the_deprecated_cyclicinitializationerror_cyclic_depe.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-105-removed_the_deprecated_nosuchmethoderror_default_constructor.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-106-removed_the_deprecated_bidirectionaliterator_class.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-107-removed_the_deprecated_deferredlibrary_class.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-108-deprecated_the_hasnextiterator_class_50883.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-109-removed_the_deprecated_maxusertags_constant.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-110-removed_the_deprecated_metrics_metric_counter.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-111-deprecate_networkinterface_listsupported_has_always_returned.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-112-use_deprecated_message_instead.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-113-use_typeerror_instead.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-114-use_maxusertags_instead.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-115-now_takes_object_instead_of_string.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-116-on_windows_the_pubcache_has_moved_to_localappdata_since_dart.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-117-observatory_is_no_longer_served_by_default_and_users_should_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-118-there_is_no_immediate_problem_but_is_related_to_a_deprecatio.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-119-5728_use_flutterroot_instead_of_looking_for_the_flutter_pack.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-120-5830_switch_to_lsp_client_v10_0_0_next_18_and_enable_delayop.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-121-5801_use_package_foo_instead_of_foldernames_in_command_execu.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-122-the_flutter_widget_preview_now_works_for_all_projects_within.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-123-5730_wish_to_inform_the_user_to_prefer_usb_over_wifi_when_de.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-124-the_flutter_widget_preview_sidebar_icon_now_appears_after_ex.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-125-davidmartos_contributed_new_settings_dart_getfluttersdkcomma.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-126-5311_switch_customdevtools_to_assume_dt_instead_of_devtoolst.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-127-5231_switch_to_parsing_the_new_flutter_version_file_bin_cach.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-128-5225_switch_to_the_dtd_sidebar_when_using_a_new_enough_sdk_i.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-129-the_hover_for_enum_values_no_longer_incorrectly_reports_the_.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-130-the_dart_previewsdkdaps_setting_has_been_replaced_by_a_new_d.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-131-flutter_users_should_run_flutter_pub_get_instead_of_dart_pub.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-132-4377_switch_to_vs_code_s_telemetry_classes_is_enhancement.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-133-a_new_setting_dart_addsdktoterminalpath_enables_automaticall.md
- [ ] bugs/history/not_viable/framework_upgrade/migration-candidate-134-flutter_recently_added_an_option_to_flutter_create_to_create.md

---

## Phase 3: not_viable/roadmap (11 files)

- [ ] bugs/history/not_viable/roadmap/task_??_avoid_any_version.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_banned_api.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_connectivity_ui_decisions.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_dependency_overrides.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_firestore_admin_role_overuse.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_large_assets_on_web.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_large_object_in_state.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_pagination_refetch_all.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_repeated_widget_creation.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_suspicious_global_reference.md
- [ ] bugs/history/not_viable/roadmap/task_??_avoid_unbounded_collections.md

---

## Phase 2: plans (7 files)

- [ ] bugs/history/plans/drift_support_plan.md
- [ ] bugs/history/plans/file_structure.md
- [ ] bugs/history/plans/framework_feature_upgrade_suggestions.md
- [ ] bugs/history/plans/ROADMAP_NATIVE_PLUGIN.md
- [ ] bugs/history/plans/rule_versioning_plan.md
- [ ] bugs/history/plans/task_test_coverage_improvement_plan.md
- [ ] bugs/history/plans/TIER_AND_SEVERITY_ANALYSIS.md

---

## Phase 2: releases (2 files)

- [ ] bugs/history/releases/2026-02-07_v4.12.2_abort_rerun_config.md
- [ ] bugs/history/releases/ci_analyzer_fixes_2026.md

---

## Phase 2: roadmap/summary (5 files)

- [ ] bugs/history/roadmap/README.md
- [ ] bugs/history/roadmap/summary/nine_rules_implemented_2026.md
- [ ] bugs/history/roadmap/summary/roadmap_detail_12_rules_implemented.md
- [ ] bugs/history/roadmap/summary/SUMMARY_18_roadmap_detail_rules_implemented.md
- [ ] bugs/history/roadmap/summary/SUMMARY.md

---

## Phase 2: roadmap/task (plain) (75 files)

- [ ] bugs/history/roadmap/task/task_avoid_cascades.md
- [ ] bugs/history/roadmap/task/task_avoid_cubits.md
- [ ] bugs/history/roadmap/task/task_avoid_expensive_log_string_construction.md
- [ ] bugs/history/roadmap/task/task_avoid_explicit_type_declaration.md
- [ ] bugs/history/roadmap/task/task_avoid_freezed_invalid_annotation_target.md
- [ ] bugs/history/roadmap/task/task_avoid_referencing_subclasses.md
- [ ] bugs/history/roadmap/task/task_avoid_renaming_representation_getters.md
- [ ] bugs/history/roadmap/task/task_avoid_returning_this.md
- [ ] bugs/history/roadmap/task/task_avoid_riverpod_string_provider_name.md
- [ ] bugs/history/roadmap/task/task_avoid_test_on_real_device.md
- [ ] bugs/history/roadmap/task/task_avoid_unnecessary_null_aware_elements.md
- [ ] bugs/history/roadmap/task/task_format_test_name.md
- [ ] bugs/history/roadmap/task/task_prefer_asmap_over_indexed_iteration.md
- [ ] bugs/history/roadmap/task/task_prefer_auto_route_path_params_simple.md
- [ ] bugs/history/roadmap/task/task_prefer_auto_route_typed_args.md
- [ ] bugs/history/roadmap/task/task_prefer_base_prefix.md
- [ ] bugs/history/roadmap/task/task_prefer_biometric_protection.md
- [ ] bugs/history/roadmap/task/task_prefer_bloc_extensions.md
- [ ] bugs/history/roadmap/task/task_prefer_block_body_setters.md
- [ ] bugs/history/roadmap/task/task_prefer_branch_io_or_firebase_links.md
- [ ] bugs/history/roadmap/task/task_prefer_builder_pattern.md
- [ ] bugs/history/roadmap/task/task_prefer_cache_extent.md
- [ ] bugs/history/roadmap/task/task_prefer_cancellation_token_pattern.md
- [ ] bugs/history/roadmap/task/task_prefer_cascade_assignments.md
- [ ] bugs/history/roadmap/task/task_prefer_class_destructuring.md
- [ ] bugs/history/roadmap/task/task_prefer_closest_context.md
- [ ] bugs/history/roadmap/task/task_prefer_compile_time_config.md
- [ ] bugs/history/roadmap/task/task_prefer_conditional_logging.md
- [ ] bugs/history/roadmap/task/task_prefer_connectivity_debounce.md
- [ ] bugs/history/roadmap/task/task_prefer_const_constructor_declarations.md
- [ ] bugs/history/roadmap/task/task_prefer_constructor_over_literals.md
- [ ] bugs/history/roadmap/task/task_prefer_constructors_over_static_methods.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_json_casts.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_throws.md
- [ ] bugs/history/roadmap/task/task_prefer_correct_topics.md
- [ ] bugs/history/roadmap/task/task_prefer_dark_mode_colors.md
- [ ] bugs/history/roadmap/task/task_prefer_deactivate_for_cleanup.md
- [ ] bugs/history/roadmap/task/task_prefer_deep_link_auth.md
- [ ] bugs/history/roadmap/task/task_prefer_disk_cache_for_persistence.md
- [ ] bugs/history/roadmap/task/task_prefer_explicit_null_checks.md
- [ ] bugs/history/roadmap/task/task_prefer_expression_body_getters.md
- [ ] bugs/history/roadmap/task/task_prefer_extension_suffix.md
- [ ] bugs/history/roadmap/task/task_prefer_factory_constructor.md
- [ ] bugs/history/roadmap/task/task_prefer_final_fields_always.md
- [ ] bugs/history/roadmap/task/task_prefer_find_child_index_callback.md
- [ ] bugs/history/roadmap/task/task_prefer_fire_and_forget.md
- [ ] bugs/history/roadmap/task/task_prefer_firebase_transaction_for_counters.md
- [ ] bugs/history/roadmap/task/task_prefer_flavor_configuration.md
- [ ] bugs/history/roadmap/task/task_prefer_flex_for_complex_layout.md
- [ ] bugs/history/roadmap/task/task_prefer_fold_over_reduce.md
- [ ] bugs/history/roadmap/task/task_prefer_foreach_over_map_entries.md
- [ ] bugs/history/roadmap/task/task_prefer_foreach.md
- [ ] bugs/history/roadmap/task/task_prefer_freezed_union_types.md
- [ ] bugs/history/roadmap/task/task_prefer_function_over_static_method.md
- [ ] bugs/history/roadmap/task/task_prefer_geolocator_coarse_location.md
- [ ] bugs/history/roadmap/task/task_prefer_getx_builder_over_obx.md
- [ ] bugs/history/roadmap/task/task_prefer_go_router_builder.md
- [ ] bugs/history/roadmap/task/task_prefer_high_contrast_mode.md
- [ ] bugs/history/roadmap/task/task_prefer_i_prefix_interfaces.md
- [ ] bugs/history/roadmap/task/task_prefer_if_else_over_guards.md
- [ ] bugs/history/roadmap/task/task_prefer_impl_suffix.md
- [ ] bugs/history/roadmap/task/task_prefer_import_over_part.md
- [ ] bugs/history/roadmap/task/task_prefer_layout_builder_for_constraints.md
- [ ] bugs/history/roadmap/task/task_prefer_mixin_prefix.md
- [ ] bugs/history/roadmap/task/task_prefer_no_i_prefix_interfaces.md
- [ ] bugs/history/roadmap/task/task_prefer_non_const_constructors.md
- [ ] bugs/history/roadmap/task/task_prefer_optional_named_params.md
- [ ] bugs/history/roadmap/task/task_prefer_optional_positional_params.md
- [ ] bugs/history/roadmap/task/task_prefer_overrides_last.md
- [ ] bugs/history/roadmap/task/task_prefer_result_type.md
- [ ] bugs/history/roadmap/task/task_prefer_separate_assignments.md
- [ ] bugs/history/roadmap/task/task_prefer_static_method_over_function.md
- [ ] bugs/history/roadmap/task/task_require_auto_route_page_suffix.md
- [ ] bugs/history/roadmap/task/task_require_const_list_items.md
- [ ] bugs/history/roadmap/task/task_require_firebase_reauthentication.md
- [ ] bugs/history/roadmap/task/task_require_firebase_token_refresh.md

---

## Phase 2: roadmap/task_info (50 files)

- [ ] bugs/history/roadmap/task_info/task_??_avoid_bool_in_widget_constructors.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_classes_with_only_static_members.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_double_and_int_checks.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_equals_and_hash_code_on_mutable_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_escaping_inner_quotes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_field_initializers_in_const_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_function_literals_in_foreach_calls.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_implementing_value_types.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_js_rounded_ints.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_null_checks_in_equality_operators.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_positional_boolean_parameters.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_private_typedef_functions.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_argument_values.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_await.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_redundant_null_check.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_returning_null_for_future.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_returning_null_for_void.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_setters_without_getters.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_single_cascade_in_expression_statements.md
- [ ] bugs/history/roadmap/task_info/task_??_avoid_unnecessary_containers.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_adjacent_strings.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_adjective_bool_getters.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_asserts_in_initializer_lists.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_constructors_in_immutables.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_declarations.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_const_literals_to_create_immutables.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_constructors_first.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_expression_function_bodies.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_methods.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_over_utility_class.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_extension_type_for_wrapper.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_final_fields.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_final_locals.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_getters_before_setters.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_if_elements_to_conditional_expressions.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_inlined_adds.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_interpolation_to_compose.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_lowercase_constants.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_mixin_over_abstract.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_named_bool_params.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_noun_class_names.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_null_aware_method_calls.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_raw_strings.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_record_over_tuple_class.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_sealed_classes.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_sealed_for_state.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_static_before_instance.md
- [ ] bugs/history/roadmap/task_info/task_??_prefer_verb_method_names.md
- [ ] bugs/history/roadmap/task_info/task_??_require_deprecation_message.md
- [ ] bugs/history/roadmap/task_info/task_??_require_public_api_documentation.md

---

## Phase 2: roadmap/task_octopus (6 files)

- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_batch_requests.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_binary_format.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_infinite_scroll_preload.md
- [ ] bugs/history/roadmap/task_octopus/task_??_prefer_pool_pattern.md
- [ ] bugs/history/roadmap/task_octopus/task_??_require_compression.md
- [ ] bugs/history/roadmap/task_octopus/task_??_require_expando_cleanup.md

---

## Phase 2: roadmap/task_star (7 files)

- [ ] bugs/history/roadmap/task_star/task_?_avoid_deprecated_usage.md
- [ ] bugs/history/roadmap/task_star/task_?_handle_throwing_invocations.md
- [ ] bugs/history/roadmap/task_star/task_?_no_empty_block.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_form_bloc_for_complex.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_local_notification_for_immediate.md
- [ ] bugs/history/roadmap/task_star/task_?_prefer_master_detail_for_large.md
- [ ] bugs/history/roadmap/task_star/task_?_require_auto_route_guard_resume.md

---

## Phase 2: roadmap/task_warning (62 files)

- [ ] bugs/history/roadmap/task_warning/task_??_avoid_accessing_other_classes_private_members.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_auto_route_context_navigation.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_auto_route_keep_history_misuse.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_behavior_subject_last_value.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_cache_stampede.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_cached_image_web.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_clip_during_animation.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_closure_capture_leaks.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_collection_mutating_methods.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_connectivity_equals_internet.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_deep_nesting.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_dynamic_calls.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_entitlement_without_server.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_equatable_nested_equality.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_expensive_did_change_dependencies.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_firebase_user_data_in_auth.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_form_validation_on_change.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_freezed_any_map_issue.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_getx_rx_nested_obs.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_high_cyclomatic_complexity.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_datetime_local.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_large_single_entry.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_hive_type_modification.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_controller.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_tr_on_strings.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_missing_tr.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_multiple_animation_controllers.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_permission_request_loop.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_platform_specific_imports.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_remember_me_insecure.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_return_await_db.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_secure_storage_in_background.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_shadowing_type_parameters.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_shared_prefs_sync_race.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_stack_trace_in_production.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_string_env_parsing.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_suspicious_super_overrides.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_unused_constructor_parameters.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_unused_local_variable.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_url_launcher_sandbox_issues.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_void_async.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_webview_cors_issues.md
- [ ] bugs/history/roadmap/task_warning/task_??_avoid_webview_local_storage_access.md
- [ ] bugs/history/roadmap/task_warning/task_??_banned_usage.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_csrf_protection.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_no_commented_code.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_semver_version.md
- [ ] bugs/history/roadmap/task_warning/task_??_prefer_sqflite_encryption.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_auto_route_full_hierarchy.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_conflict_resolution_strategy.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_connectivity_timeout.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_error_handling_graceful.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_exhaustive_sealed_switch.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_firebase_app_check_production.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_init_state_idempotent.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_input_validation.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_late_access_check.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_pagination_for_large_lists.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_ssl_pinning_sensitive.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_text_scale_factor_awareness.md
- [ ] bugs/history/roadmap/task_warning/task_??_require_yield_after_db_write.md
- [ ] bugs/history/roadmap/task_warning/task_??_verify_documented_parameters_exist.md

---

## Phase 2: todos (4 files)

- [ ] bugs/history/todos/todo_001_missing_require_ios_platform_check_rule.md
- [ ] bugs/history/todos/todo_002_missing_avoid_ios_background_fetch_abuse_rule.md
- [ ] bugs/history/todos/todo_003_missing_require_method_channel_error_handling_rule.md
- [ ] bugs/history/todos/todo_004_missing_require_universal_link_validation_rule.md

---

## Phase 2: tooling, user_reports, completed, README (5 files)

- [ ] bugs/history/tooling/publish_audit_failure_flow_fixed.md
- [ ] bugs/history/user_reports/[icealive] fix_regex_parsing_review.md
- [ ] bugs/history/completed/remaining_roadmap_26_rules_implemented.md
- [ ] bugs/history/completed/unit_test_coverage_fixtures_and_instantiation_completed.md
- [ ] bugs/history/README.md

---

**Total: 498 files.** Mark each `[ ]` as `[x]` when reviewed and integrated (or archived/deleted as per plan).
