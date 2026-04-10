# Roadmap detail 9 rules — completed 2026-02-28

All 9 task specs were implemented and registered.

| Task | Rule(s) | Tier | Summary |
|------|---------|------|---------|
| task_⚠️_banned_usage.md | `banned_usage` | Professional | Configurable identifier ban list via analysis_options_custom.yaml; no-op without config. |
| task_⚠️_prefer_csrf_protection.md | `prefer_csrf_protection` | Professional | State-changing HTTP + Cookie without CSRF/Bearer (web/http). OWASP M3/A07. |
| task_⚠️_prefer_no_commented_code.md | `prefer_no_commented_code` (alias) | — | Alias for existing `prefer_no_commented_out_code`. |
| task_⚠️_prefer_semver_version.md | `prefer_semver_version` | Essential | pubspec.yaml version must be major.minor.patch. |
| task_⚠️_prefer_sqflite_encryption.md | `prefer_sqflite_encryption` | Professional | Sensitive DB paths + sqflite without sqlcipher. OWASP M9. |
| task_⚠️_require_conflict_resolution_strategy.md | `require_conflict_resolution_strategy` | Professional | Sync/upload/push overwriting without timestamp/conflict check. |
| task_⚠️_require_connectivity_timeout.md | `require_connectivity_timeout` | Essential | HTTP/dio requests without timeout. |
| task_⚠️_require_init_state_idempotent.md | `require_init_state_idempotent` | Essential | addListener/addObserver in initState without remove in dispose. |
| task_⚠️_require_input_validation.md | `require_input_validation` | Essential | Raw .text in post/put/patch body without trim/validate. OWASP M1/M4. |

Implementation: code_quality_rules, web_rules, config_rules, sqflite_rules, lifecycle_rules, connectivity_rules, widget_lifecycle_rules, security_rules; banned_usage_config + config_loader. Tests: test/roadmap_detail_9_rules_test.dart. Fixture: example/lib/roadmap_detail_9_rules_fixture.dart.
