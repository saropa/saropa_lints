"""Diagnose specific errors in broken fixture files."""
import subprocess
import os
import re

os.chdir(r'd:\src\saropa_lints')

files = [
    "example/lib/accessibility/avoid_text_scale_factor_ignore_fixture.dart",
    "example/lib/animation/require_hero_tag_uniqueness_fixture.dart",
    "example/lib/api_network/require_notification_handler_top_level_fixture.dart",
    "example/lib/architecture/avoid_singleton_pattern_fixture.dart",
    "example/lib/async/prefer_async_init_state_fixture.dart",
    "example/lib/class_constructor/prefer_interface_class_fixture.dart",
    "example/lib/code_quality/avoid_duplicate_initializers_fixture.dart",
    "example/lib/code_quality/avoid_nested_extension_types_fixture.dart",
    "example/lib/code_quality/avoid_unnecessary_nullable_fields_fixture.dart",
    "example/lib/code_quality/prefer_dot_shorthand_fixture.dart",
    "example/lib/code_quality/prefer_redirecting_superclass_constructor_fixture.dart",
    "example/lib/code_quality/prefer_typedefs_for_callbacks_fixture.dart",
    "example/lib/collection/prefer_null_aware_elements_fixture.dart",
    "example/lib/dependency_injection/avoid_circular_di_dependencies_fixture.dart",
    "example/lib/dependency_injection/avoid_service_locator_in_widgets_fixture.dart",
    "example/lib/dependency_injection/prefer_null_object_pattern_fixture.dart",
    "example/lib/documentation/require_exception_documentation_fixture.dart",
    "example/lib/exception/avoid_throw_objects_without_tostring_fixture.dart",
    "example/lib/file_handling/prefer_sqflite_column_constants_fixture.dart",
    "example/lib/forms/prefer_regex_validation_fixture.dart",
    "example/lib/freezed/require_freezed_private_constructor_fixture.dart",
    "example/lib/json_datetime/prefer_json_serializable_fixture.dart",
    "example/lib/naming_style/prefer_typedef_for_callbacks_fixture.dart",
    "example/lib/navigation/avoid_circular_redirects_fixture.dart",
    "example/lib/navigation/prefer_go_router_extra_typed_fixture.dart",
    "example/lib/navigation/prefer_shell_route_shared_layout_fixture.dart",
    "example/lib/navigation/require_go_router_fallback_route_fixture.dart",
    "example/lib/packages/avoid_bloc_context_dependency_fixture.dart",
    "example/lib/packages/avoid_bloc_event_in_constructor_fixture.dart",
    "example/lib/packages/avoid_bloc_event_mutation_fixture.dart",
    "example/lib/packages/avoid_database_in_build_fixture.dart",
    "example/lib/packages/avoid_firestore_in_widget_build_fixture.dart",
    "example/lib/packages/avoid_getit_in_build_fixture.dart",
    "example/lib/packages/avoid_isar_string_contains_without_index_fixture.dart",
    "example/lib/packages/avoid_map_markers_in_build_fixture.dart",
    "example/lib/packages/avoid_nested_providers_fixture.dart",
    "example/lib/packages/prefer_cubit_for_simple_fixture.dart",
    "example/lib/packages/prefer_cubit_for_simple_state_fixture.dart",
    "example/lib/packages/prefer_isar_composite_index_fixture.dart",
    "example/lib/packages/prefer_isar_index_for_queries_fixture.dart",
    "example/lib/packages/prefer_typed_prefs_wrapper_fixture.dart",
    "example/lib/packages/prefer_unmodifiable_collections_fixture.dart",
    "example/lib/packages/require_background_message_handler_fixture.dart",
    "example/lib/packages/require_bloc_initial_state_fixture.dart",
    "example/lib/packages/require_bloc_manual_dispose_fixture.dart",
    "example/lib/packages/require_bloc_transformer_fixture.dart",
    "example/lib/packages/require_database_index_fixture.dart",
    "example/lib/packages/require_database_migration_fixture.dart",
    "example/lib/packages/require_hive_field_default_value_fixture.dart",
    "example/lib/packages/require_hive_migration_strategy_fixture.dart",
    "example/lib/packages/require_hive_nested_object_adapter_fixture.dart",
    "example/lib/packages/require_hive_type_adapter_fixture.dart",
    "example/lib/packages/require_initial_state_fixture.dart",
    "example/lib/type/avoid_null_assertion_fixture.dart",
    "example/lib/widget_lifecycle/require_should_rebuild_fixture.dart",
    "example/lib/widget_patterns/require_orientation_handling_fixture.dart",
    "example/lib/widget_patterns/require_text_overflow_handling_fixture.dart",
]

for f in files:
    r = subprocess.run(
        f'D:/tools/flutter/bin/dart.bat format --output=none {f}',
        capture_output=True, text=True, shell=True
    )
    out = r.stdout + r.stderr
    # Get just the first error line
    for line in out.split('\n'):
        if 'line ' in line and 'column' in line:
            print(f'{f}: {line.strip()}')
            break
    else:
        for line in out.split('\n'):
            if 'Expected' in line or 'error' in line.lower():
                print(f'{f}: {line.strip()}')
                break
