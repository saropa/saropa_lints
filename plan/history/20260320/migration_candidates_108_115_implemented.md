# Migration candidates #108–#115 (Dart SDK 3.0) — summary

## Implemented in code

| Candidate | Outcome |
|-----------|---------|
| #108 HasNextIterator deprecated | `avoid_deprecated_has_next_iterator` |
| #109 MAX_USER_TAGS removed | `avoid_removed_max_user_tags_constant` + quick fix → `maxUserTags` |
| #110 Metrics / Metric / Counter / Gauge removed | `avoid_removed_dart_developer_metrics` |
| #111 NetworkInterface.listSupported deprecated | `avoid_deprecated_network_interface_list_supported` |
| #112 Use Deprecated.message | Existing `avoid_deprecated_expires_getter` (`.expires` → `.message`) |
| #113 Use TypeError | Existing `avoid_removed_cast_error`; FallThroughError → existing `avoid_removed_fall_through_error` |
| #114 Use maxUserTags | Same as #109 |
| #115 Object vs String | **No rule** — `dart:js_util` `callMethod` parameter widened; `String` callers need no change |

## LintImpact (post-review)

- **High:** `avoid_removed_max_user_tags_constant`, `avoid_removed_dart_developer_metrics` (compile breaks on Dart 3 for removed APIs).
- **Medium:** `avoid_deprecated_has_next_iterator` (deprecation / migration).
- **Low:** `avoid_deprecated_network_interface_list_supported` (deprecated no-op check).

## Plans

Source specs remain under `plan/implementable_only_in_plugin_extension/migration-candidate-10[8-9]*` and `11[0-5]*` with updated checklists and status.
