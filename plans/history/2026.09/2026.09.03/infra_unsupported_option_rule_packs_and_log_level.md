# BUG: `unsupported_option` — `rule_packs` and `log_level` still trigger SDK warnings

**Status: Fixed**

Created: 2026-09-03
Rule: N/A (infrastructure — Dart SDK analyzer validation, not a saropa_lints rule)
File: `lib/src/native/config_loader.dart`
Severity: Low (cosmetic warning, no functional impact — plugin parses both keys correctly)

---

## Summary

Consumer projects using `rule_packs` and `log_level` under `plugins > saropa_lints:` in `analysis_options.yaml` still see `unsupported_option` warnings from the Dart SDK analyzer. The prior fix (`plans/history/2026.08/2026.08.30/infra_unsupported_option_warning_for_custom_plugin_keys.md`) moved `log_level`, `lane`, and `memory_mode` to `analysis_options_custom.yaml` but explicitly left `rule_packs` out of scope. The plan at `plans/history/2026.09/2026.09.02/infra_rule_packs_unsupported_option_warning.md` is marked "Fixed" but contains no commits section and the warnings persist, so the fix was never implemented.

Additionally, `log_level` is still present under `plugins:` in at least one consumer (`saropa_drift_advisor`), suggesting the migration for that key wasn't applied to all consumers or the `init` command still writes it there.

---

## Reproducer

```yaml
# analysis_options.yaml (consumer project, e.g. saropa_drift_advisor)
plugins:
  saropa_lints:
    version: "14.3.8"
    log_level: info            # ← unsupported_option warning
    rule_packs:                # ← unsupported_option warning
      enabled:
        - collection_compat
        - dart_sdk_3_2
```

Warning text (both keys):
```
The option 'log_level' isn't supported by 'plugins/saropa_lints'.
Try using one of the supported options: 'diagnostics', 'git', 'path', 'version', and 'hosted'.

The option 'rule_packs' isn't supported by 'plugins/saropa_lints'.
Try using one of the supported options: 'diagnostics', 'git', 'path', 'version', and 'hosted'.
```

**Frequency:** Always, for every consumer project that has these keys under `plugins:`.

---

## Root Cause

The Dart SDK `analyzer` package hardcodes valid plugin option keys:
```dart
static const Set<String> pluginsOptions = {
  diagnostics, path, version, hosted,
};
```

No plugin API exists to register additional config keys. The SDK validates against this set before the plugin sees the YAML.

---

## Suggested Fix

1. **`rule_packs`:** Move parsing from the `plugins > saropa_lints:` block to `analysis_options_custom.yaml` (top-level key), following the pattern used for `log_level`/`lane`/`memory_mode`. Unlike those scalars, `rule_packs` is a nested map (`rule_packs.enabled: [list]`), so the custom-file reader/writer needs to handle YAML map + list structure.

2. **`log_level`:** Verify the `init` command and `migrate_config` CLI no longer write `log_level` under `plugins:`. If they already write it to the custom file, the fix is just migrating existing consumers.

3. **`migrate_config` CLI:** Ensure both keys are in the set of keys migrated from the plugin block to the custom file, so consumers can run a single command to fix the warnings.

---

## Related

- Prior fix (log_level/lane/memory_mode): `plans/history/2026.08/2026.08.30/infra_unsupported_option_warning_for_custom_plugin_keys.md`
- Incomplete plan for rule_packs: `plans/history/2026.09/2026.09.02/infra_rule_packs_unsupported_option_warning.md`
- Rule packs config: `lib/src/config/rule_packs.dart`
- Rule packs YAML parsing: `lib/src/config/analysis_options_rule_packs.dart`

---

## Environment

- saropa_lints version: 14.3.8 (consumer), latest (source)
- Dart SDK version: (current)
- Triggering project: `d:\src\saropa_drift_advisor\analysis_options.yaml` lines 59-60

---

## Finish Report (2026-09-03)

Investigation confirmed the fix was already fully implemented across the codebase:

- `config_loader.dart` reads `rule_packs` and `log_level` from `analysis_options_custom.yaml` as canonical, falling back to the plugin block only with a deprecation warning directing users to run `migrate-config`.
- The `init` command writes both keys to the custom file only — never under `plugins:`.
- The `migrate-config` CLI handles all four migrated keys (`log_level`, `lane`, `memory_mode`, `rule_packs`) including the nested map structure for `rule_packs.enabled`.

The bug report was filed based on warnings still visible in `saropa_drift_advisor`, which had not yet run the migration. No code changes were required in saropa_lints — the consumer project needs `dart run saropa_lints migrate-config`.

The CHANGELOG heading for `[15.2.12]` was missing the required `— Unreleased` suffix; corrected as part of this task.

### Hardening (2026-09-03)

Three robustness gaps were fixed in the config migration infrastructure:

1. **Tab indentation support** (`analysis_options_rule_packs.dart`): `_leadingSpaces()` now counts both spaces and tabs, matching the `_leadingWhitespace()` helper in `runtime_tier_cap.dart`. Previously, tab-indented YAML files caused all lines to compute indent=0, breaking block detection silently.

2. **Orphan `rule_packs:` removal** (`migrate_config.dart`): `hasLegacyRulePacks` is now set based on whether the key exists in the plugin block (regex check), not just whether `parseRulePacksEnabledList()` returned items. A bare `rule_packs:` without `enabled:` or list items was previously left in the main file after migration.

3. **Trailing comment handling** (`migrate_config.dart`): The `_pluginRulePacksBlock` removal regex now accepts optional trailing comments on `rule_packs:` and `enabled:` key lines (e.g. `rule_packs: # my packs`).

### Doctor command (2026-09-03)

New `dart run saropa_lints doctor [directory]` CLI command scans a consumer project's configuration for:
- Keys misplaced under `plugins:` that belong in `analysis_options_custom.yaml`
- Missing `analysis_options_custom.yaml`
- Missing `saropa_lints` plugin entry
- Missing version constraint

Prints a numbered issue list with fix suggestions. Registered in the unified CLI router (`bin/saropa_lints.dart`).
