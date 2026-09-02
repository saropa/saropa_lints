# Migrate `rule_packs` from plugin block to custom file

The Dart SDK's `analysis_options.yaml` validator emits a false `unsupported_option` warning for `rule_packs` under `plugins > saropa_lints:` because the SDK hardcodes `{diagnostics, git, path, version, hosted}` as the allowed key set. This is the same root cause as the prior `log_level`/`lane`/`memory_mode` migration (2026-08-30), which explicitly deferred `rule_packs` due to its nested map structure.

## Finish Report (2026-09-02)

### Root cause

The Dart SDK validates plugin-block keys against a hardcoded allowlist before the plugin reads them. No plugin API exists to declare additional config keys. Every consumer project with `rule_packs` configured sees the warning on every analysis run.

### Fix

Moved `rule_packs` config from `plugins > saropa_lints:` in `analysis_options.yaml` to a top-level key in `analysis_options_custom.yaml`, following the established pattern for scalar keys.

### Changes

**Dart side (6 files):**

- `config_loader.dart` (`_reloadRulePacksFromRoot`): reads `analysis_options_custom.yaml` first via `parseRulePacksEnabledList`, falls back to the plugin block with a `PluginLogger.warning()` deprecation message directing users to run `migrate-config`.
- `config_writer.dart` (`generatePluginsYaml`): removed `rule_packs` output and the `rulePacksEnabled` parameter — rule packs are no longer written to the plugin block.
- `custom_overrides_core.dart`: added commented `# RULE PACKS` template to `buildMinimalConfig` and a `writeRulePacksToCustomFile` helper (regex-based block replace/insert with section-ordering awareness).
- `init_runner.dart` and `write_config_runner.dart`: read existing packs from custom file first (fallback to main file), write via `writeRulePacksToCustomFile` instead of passing to `generatePluginsYaml`.
- `bin/migrate_config.dart`: added structured `rule_packs` migration (parse nested block from plugin YAML, write to custom file via helper, remove indented block from main file).

**TypeScript side (2 files):**

- `rulePackYaml.ts`: `readRulePacksEnabled` reads custom file first with fallback; `writeRulePacksEnabled` writes to custom file as top-level key and calls `removeLegacyRulePacksFromMainFile` for cleanup.
- `migrateConfig.ts`: added `rule_packs` to migration set, using `parseRulePacksEnabled`/`writeRulePacksEnabled` from `rulePackYaml.ts`.

**Tests:** Updated `write_config_test.dart` — 2 assertions redirected to check `analysis_options_custom.yaml` instead of the main file. All 12 tests pass.

### Code-review hardening (same session)

Three bugs caught by code review and fixed before commit:

1. **Regex over-match** — `_rulePacksBlockPattern` and `_removeRulePacksTemplate` used `\s*#` / `\s*\n` alternations that matched zero-indent comment lines, causing them to eat into the next section's `# PLATFORM SETTINGS` header. Fixed by requiring indented children only (`\s+\S`) and stopping at blank-line boundaries.
2. **`--reset` doesn't clear rule_packs** — `writeRulePacksToCustomFile` was guarded by `isNotEmpty`, so `--reset` (which resolves to an empty pack list) never removed an existing `rule_packs:` block. Fixed by calling unconditionally; the function handles empty lists correctly.
3. **Empty `enabled: []` resurrects stale packs** — `readRulePacksEnabled` conflated "key absent" with "key present but empty", falling back to the legacy plugin block and resurrecting pack ids the user deliberately removed. Fixed by checking for the `rule_packs:` key's presence, not just a non-empty result.

All three fixes applied to both the Dart and TypeScript implementations.

### Known duplication

The custom-file-first fallback logic (5 lines: read custom file, check empty, fall back to main file) is duplicated between `init_runner.dart` and `write_config_runner.dart`. Both copies are small and stable; extracting a shared helper would touch the init system's API surface for marginal gain. The Dart/TS regex duplication for `rule_packs:` block parsing/writing is inherent to the dual-runtime architecture and cannot be shared.

### Backward compatibility

Projects with `rule_packs` in the old plugin-block location continue to work — the config loader falls back to the old location with a deprecation warning. The `migrate-config` CLI and extension command handle automatic migration. New projects created by `dart run saropa_lints:init` write `rule_packs` to the custom file from the start.

### Additional hardening

- `writeRulePacksToCustomFile` skips disk write when content is unchanged (avoids unnecessary I/O on every init run with no packs).
- `migrate-config` (Dart and TS) now removes skipped keys from the legacy plugin block even when they already exist in the custom file — previously, a key present in both files would be "SKIP"ped but never removed from the main file, leaving the `unsupported_option` warning intact.
- New test file: `test/init/write_rule_packs_custom_file_test.dart` (8 tests) — covers write, replace, clear, section-boundary safety, empty file, and file creation.

### Verification

- Dart analysis: 0 issues across all touched files.
- TypeScript: `tsc --noEmit` passes clean.
- `test/init/write_config_test.dart`: 12/12 pass.
- `test/init/write_rule_packs_custom_file_test.dart`: 8/8 pass (new).
- `test/config/analysis_options_rule_packs_test.dart`: all pass (parser unchanged).
- `test/scan/rule_tier_index_test.dart`: 8/8 pass (rule registration integrity).

### Related

- Prior fix: `plans/history/2026.08/2026.08.30/infra_unsupported_option_warning_for_custom_plugin_keys.md`
- Bug report: `plans/history/2026.09/2026.09.02/infra_rule_packs_unsupported_option_warning.md`
