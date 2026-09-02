# BUG: `unsupported_option` — `rule_packs` key triggers false SDK warning

**Status: Fixed**

Created: 2026-09-02
Rule: N/A (infrastructure — Dart SDK analyzer validation, not a saropa_lints rule)
File: `lib/src/native/config_loader.dart` (line ~746, `_loadRulePacksConfig`)
Severity: Low (cosmetic warning, no functional impact)

---

## Summary

The Dart SDK's `analysis_options.yaml` validator emits an `unsupported_option` warning for the `rule_packs` key under `plugins > saropa_lints:`. The plugin parses `rule_packs` correctly via `_loadRulePacksConfig()` — the warning is a false positive from the SDK's hardcoded allowed-key set `{diagnostics, git, path, version, hosted}`.

This is the same root cause as the `log_level` / `lane` / `memory_mode` warnings fixed in `plans/history/2026.08/2026.08.30/infra_unsupported_option_warning_for_custom_plugin_keys.md`. That fix explicitly noted `rule_packs` as out of scope (line 158).

---

## Attribution Evidence

Not a rule — this is infrastructure. The config loader that parses `rule_packs` lives in `lib/src/native/config_loader.dart`:

```
config_loader.dart:746: /// Parses `rule_packs.enabled` under `plugins.saropa_lints` and merges rule
config_loader.dart:750: void _loadRulePacksConfig() {
```

The rule pack registry and merging logic: `lib/src/config/rule_packs.dart`, `lib/src/config/analysis_options_rule_packs.dart`.

---

## Reproducer

```yaml
# analysis_options.yaml (any consumer project)
plugins:
  saropa_lints:
    version: "15.2.8"
    rule_packs:          # ← unsupported_option warning
      enabled:
        - collection_compat
        - dart_sdk_3_2
```

Warning text:
```
The option 'rule_packs' isn't supported by 'plugins/saropa_lints'.
Try using one of the supported options: 'diagnostics', 'git', 'path',
'version', and 'hosted'.
```

**Frequency:** Always, for every consumer project that configures `rule_packs`.

---

## Root Cause

Same as the prior fix — the Dart SDK `analyzer` package hardcodes valid plugin option keys in `lib/src/analysis_options/analysis_options_file.dart`:

```dart
static const Set<String> pluginsOptions = {
  diagnostics, path, version, hosted,
};
```

The SDK validates against this set before the plugin sees the YAML. No plugin API exists to declare additional config keys.

---

## Suggested Fix

Move `rule_packs` parsing from the `plugins > saropa_lints:` block to `analysis_options_custom.yaml` (top-level key), following the same pattern used for `log_level`, `lane`, and `memory_mode`:

1. **`config_loader.dart`:** Read `rule_packs` from `analysis_options_custom.yaml` as a top-level key. Add deprecation fallback to the old plugin-block location via `_readWithDeprecationFallback` (or a structured equivalent, since `rule_packs` is a map, not a scalar).
2. **`config_writer.dart` / `custom_overrides_core.dart`:** Move `rule_packs` output from the main file template to the custom file template.
3. **`init_runner.dart`:** Update `dart run saropa_lints:init` to write `rule_packs` to the custom file.
4. **`migrate-config` CLI command:** Add `rule_packs` to the set of keys migrated from the plugin block to the custom file.
5. **Extension TS (`rulePackYaml.ts`):** Update read/write paths to target the custom file.

### Complexity note

Unlike `log_level` / `lane` / `memory_mode` (scalars), `rule_packs` is a nested map (`rule_packs.enabled: [list]`). The custom-file reader and writer need to handle YAML map + list structure, not just a scalar value. The deprecation fallback also needs to parse a nested structure from the plugin block.

---

## Environment

- saropa_lints version: 15.2.8
- Dart SDK analyzer package: 12.1.0
- analysis_server_plugin: 0.3.14
- Triggering project: `d:\src\saropa_drift_advisor\analysis_options.yaml` line 59

---

## Related

- Prior fix: `plans/history/2026.08/2026.08.30/infra_unsupported_option_warning_for_custom_plugin_keys.md`
- Rule packs config: `lib/src/config/rule_packs.dart`
- Rule packs YAML parsing: `lib/src/config/analysis_options_rule_packs.dart`
