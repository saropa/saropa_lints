/**
 * Rule pack metadata for the Rule Packs UI. Keep pack ids and rule code lists
 * aligned with lib/src/config/rule_packs.dart.
 */

export interface RulePackDefinition {
  readonly id: string;
  readonly label: string;
  /** Dependency names in pubspec that imply this pack (any match = detected). */
  readonly matchPubNames: readonly string[];
  readonly ruleCodes: readonly string[];
}

export const RULE_PACK_DEFINITIONS: readonly RulePackDefinition[] = [
  {
    id: 'riverpod',
    label: 'Riverpod',
    matchPubNames: ['riverpod', 'flutter_riverpod', 'hooks_riverpod'],
    ruleCodes: [
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
    ],
  },
  {
    id: 'drift',
    label: 'Drift',
    matchPubNames: ['drift', 'drift_dev'],
    ruleCodes: [
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
    ],
  },
  {
    id: 'bloc',
    label: 'Bloc',
    matchPubNames: ['bloc', 'flutter_bloc', 'hydrated_bloc'],
    ruleCodes: [
      'require_bloc_close',
      'avoid_bloc_event_mutation',
      'avoid_duplicate_bloc_event_handlers',
      'emit_new_bloc_state_instances',
      'avoid_yield_in_on_event',
      'require_bloc_manual_dispose',
      'avoid_bloc_listen_in_build',
      'avoid_instantiating_in_bloc_value_provider',
      'avoid_existing_instances_in_bloc_provider',
    ],
  },
  {
    id: 'provider',
    label: 'Provider',
    matchPubNames: ['provider'],
    ruleCodes: [
      'require_provider_dispose',
      'avoid_provider_value_rebuild',
      'avoid_provider_recreate',
      'avoid_provider_in_widget',
      'prefer_multi_provider',
      'avoid_nested_providers',
    ],
  },
  {
    id: 'hive',
    label: 'Hive',
    matchPubNames: ['hive', 'hive_flutter'],
    ruleCodes: [
      'require_hive_initialization',
      'require_hive_type_adapter',
      'require_hive_encryption_key_secure',
      'avoid_hive_field_index_reuse',
      'require_hive_adapter_registration_order',
      'require_hive_nested_object_adapter',
    ],
  },
  {
    id: 'firebase',
    label: 'Firebase',
    matchPubNames: [
      'firebase_core',
      'firebase_auth',
      'cloud_firestore',
      'firebase_messaging',
      'firebase_storage',
      'firebase_analytics',
    ],
    ruleCodes: [
      'require_firebase_init_before_use',
      'require_firebase_reauthentication',
      'require_firebase_token_refresh',
      'incorrect_firebase_event_name',
      'incorrect_firebase_parameter_name',
    ],
  },
  {
    id: 'getx',
    label: 'GetX',
    matchPubNames: ['get', 'getx'],
    ruleCodes: [
      'avoid_getx_context_outside_widget',
      'require_getx_worker_dispose',
      'require_getx_permanent_cleanup',
      'avoid_getx_build_context_bypass',
    ],
  },
  {
    id: 'isar',
    label: 'Isar',
    matchPubNames: ['isar', 'isar_flutter_libs'],
    ruleCodes: ['avoid_isar_enum_field', 'require_isar_nullable_field', 'avoid_isar_import_with_drift'],
  },
];

/** True if pubspec.yaml declares any of [matchPubNames] as a dependency entry. */
export function isPackDetected(def: RulePackDefinition, pubspecContent: string): boolean {
  return def.matchPubNames.some((n) => new RegExp(`^\\s+${n}\\s*:`, 'm').test(pubspecContent));
}
