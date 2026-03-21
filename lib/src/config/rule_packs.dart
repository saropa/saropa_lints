// ignore_for_file: always_specify_types

/// Rule pack ids → rule codes enabled when the pack is listed under
/// `plugins.saropa_lints.rule_packs.enabled` in analysis_options.yaml.
///
/// **Config merge order:** The native plugin loads severity overrides and
/// `diagnostics:` first; then [mergeRulePacksIntoEnabled] merges pack rule codes
/// into [SaropaLintRule.enabledRules]. Codes in [SaropaLintRule.disabledRules]
/// (explicit `false`) are skipped so user opt-out wins over pack opt-in.
///
/// **VS Code:** Keep [kRulePackRuleCodes] in sync with
/// `extension/src/rulePacks/rulePackDefinitions.ts` (same pack ids and rule
/// lists) so the Rule Packs webview shows correct counts.
library;

/// Returns rule codes for [packId], or empty if unknown.
Set<String> ruleCodesForPack(String packId) {
  final codes = kRulePackRuleCodes[packId];
  return codes == null ? <String>{} : Set<String>.from(codes);
}

/// All known pack ids.
Set<String> get knownRulePackIds => kRulePackRuleCodes.keys.toSet();

/// Adds rule codes from [packIds] into [enabled], skipping any code whose
/// lowercase name appears in [disabled] (diagnostics/severity disables).
///
/// Does not remove existing entries from [enabled]. Idempotent per code.
void mergeRulePacksIntoEnabled(
  Set<String> enabled,
  Set<String>? disabled,
  Iterable<String> packIds,
) {
  final disabledLc = <String>{
    for (final d in disabled ?? const <String>{}) d.toLowerCase(),
  };
  for (final packId in packIds) {
    for (final code in ruleCodesForPack(packId)) {
      if (disabledLc.contains(code.toLowerCase())) continue;
      enabled.add(code);
    }
  }
}

/// Canonical registry: pack id → rule codes (subset per family; expand over time).
const Map<String, Set<String>> kRulePackRuleCodes = {
  'riverpod': {
    'require_provider_scope',
    'avoid_riverpod_state_mutation',
    'require_riverpod_error_handling',
    'avoid_ref_read_inside_build',
    'avoid_ref_watch_outside_build',
    'avoid_riverpod_notifier_in_build',
    'require_riverpod_async_value_guard',
    'avoid_circular_provider_deps',
    'avoid_riverpod_string_provider_name',
    'prefer_riverpod_family_for_params',
    'require_async_value_order',
    'avoid_listen_in_async',
    'avoid_notifier_constructors',
    'use_ref_read_synchronously',
    'prefer_consumer_widget',
    'require_auto_dispose',
    'avoid_global_riverpod_providers',
    'prefer_riverpod_select',
    'require_flutter_riverpod_package',
    'prefer_riverpod_auto_dispose',
  },
  'drift': {
    'avoid_drift_raw_sql_interpolation',
    'avoid_drift_enum_index_reorder',
    'require_drift_database_close',
    'avoid_drift_update_without_where',
    'require_await_in_drift_transaction',
    'require_drift_foreign_key_pragma',
    'prefer_drift_batch_operations',
    'require_drift_stream_cancel',
    'avoid_drift_value_null_vs_absent',
    'require_drift_equals_value',
    'require_drift_read_table_or_null',
    'require_drift_create_all_in_oncreate',
    'require_drift_onupgrade_handler',
  },
  'bloc': {
    'require_bloc_close',
    'avoid_bloc_event_mutation',
    'avoid_duplicate_bloc_event_handlers',
    'emit_new_bloc_state_instances',
    'avoid_yield_in_on_event',
    'require_bloc_manual_dispose',
    'avoid_bloc_listen_in_build',
    'avoid_instantiating_in_bloc_value_provider',
    'avoid_existing_instances_in_bloc_provider',
  },
  'provider': {
    'require_provider_dispose',
    'avoid_provider_value_rebuild',
    'avoid_provider_recreate',
    'avoid_provider_in_widget',
    'prefer_multi_provider',
    'avoid_nested_providers',
  },
  'hive': {
    'require_hive_initialization',
    'require_hive_type_adapter',
    'require_hive_encryption_key_secure',
    'avoid_hive_field_index_reuse',
    'require_hive_adapter_registration_order',
    'require_hive_nested_object_adapter',
  },
  'firebase': {
    'require_firebase_init_before_use',
    'require_firebase_reauthentication',
    'require_firebase_token_refresh',
    'incorrect_firebase_event_name',
    'incorrect_firebase_parameter_name',
  },
  'getx': {
    'avoid_getx_context_outside_widget',
    'require_getx_worker_dispose',
    'require_getx_permanent_cleanup',
    'avoid_getx_build_context_bypass',
  },
  'isar': {
    'avoid_isar_enum_field',
    'require_isar_nullable_field',
    'avoid_isar_import_with_drift',
  },
};
