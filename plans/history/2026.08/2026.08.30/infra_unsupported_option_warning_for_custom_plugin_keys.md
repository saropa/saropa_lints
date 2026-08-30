# BUG: `unsupported_option` — Dart SDK rejects valid plugin config keys

**Status: Fixed**

Created: 2026-08-30
Rule: N/A (infrastructure — Dart SDK analyzer validation, not a saropa_lints rule)
File: Dart SDK `analyzer` package, `analysis_options_file.dart`
Severity: Low (cosmetic warning, no functional impact)

---

## Summary

The Dart SDK's `analysis_options.yaml` validator emits `unsupported_option`
warnings for `log_level`, `lane`, and `memory_mode` keys under
`plugins > saropa_lints:` because the SDK hardcodes the allowed set to
`{diagnostics, git, path, version, hosted}`. The plugin parses these keys
correctly via its own YAML reader — the warning is a false positive from the
SDK's validator, not a real config error.

---

## Reproducer

```yaml
# analysis_options.yaml
plugins:
  saropa_lints:
    version: "15.2.4"
    log_level: info        # ← unsupported_option warning
    lane: light            # ← unsupported_option warning (if uncommented)
    diagnostics:
      # ...
```

Warning text:
```
The option 'log_level' isn't supported by 'plugins/saropa_lints'.
Try using one of the supported options: 'diagnostics', 'git', 'path',
'version', and 'hosted'.
```

**Frequency:** Always, for every consumer project that sets `log_level`,
`lane`, or `memory_mode`.

---

## Root Cause

The Dart SDK `analyzer` package hardcodes valid plugin option keys in
`lib/src/analysis_options/analysis_options_file.dart`:

```dart
// Plugins options.
static const String diagnostics = 'diagnostics';
static const String path = 'path';
static const String version = 'version';
static const String hosted = 'hosted';

/// Supported 'plugins' options.
static const Set<String> pluginsOptions = {
  diagnostics,
  path,
  version,
  hosted,
};
```

Confirmed in `analyzer-12.1.0` (line ~68). The `Plugin` base class
(`analysis_server_plugin` 0.3.14) exposes no override or callback to declare
additional config keys — the validator runs against the hardcoded set before
the plugin ever sees the YAML.

The plugin's `_loadLogLevel()` (`config_loader.dart:549`), `_loadRuleLane()`
(`:239`), and `_loadMemoryMode()` (`:585`) all parse these keys correctly from
the raw file content. The warning is purely cosmetic.

---

## Impact

- INFO-severity warning in the IDE Problems panel for every consumer.
- No functional impact — config is loaded and applied correctly.
- Users may be confused by a warning on a key the plugin documents and uses.

---

## Options

1. **Upstream SDK issue.** Request the `analyzer` package support a
   plugin-declared `configurationKeys` override (or wildcard pass-through).
   This is the correct long-term fix. Filed against `dart-lang/sdk` or
   `dart-lang/linter`.

2. **Move config to `analysis_options_custom.yaml`.** Relocate `log_level`,
   `lane`, and `memory_mode` parsing to the custom file (which the SDK
   validator does not touch). Trade-off: splits plugin config across two files,
   and consumers expect plugin knobs to live under the `plugins:` block.

3. **Suppress in consumer.** Add `// ignore: unsupported_option` above each
   key. Trade-off: per-consumer noise, and the `// ignore:` itself may draw
   its own warning depending on analyzer version.

4. **Do nothing.** The warning is INFO severity and the plugin works. Document
   that it is expected.

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK analyzer package: 12.1.0
- analysis_server_plugin: 0.3.14
- Triggering project: `d:\src\contacts\analysis_options.yaml` line 1147

---

## Finish Report (2026-08-30)

**Resolution:** Option 2 — moved `log_level`, `lane`, and `memory_mode` from the `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level keys in `analysis_options_custom.yaml`. The SDK's plugin-block validator does not inspect the custom file, eliminating the false `unsupported_option` warnings.

### Changes

**Dart side (`lib/src/native/config_loader.dart`):**
- Extracted `_parseTopLevelScalar(content, key)` — shared helper for all three config keys, with quote-stripping and lower-casing to match the TS `parseLaneFromCustomConfig` behavior.
- `_loadLogLevel`, `_loadRuleLane`, `_loadMemoryMode` all refactored to read top-level keys from `analysis_options_custom.yaml` via the shared helper.
- Deprecation fallback: all three loaders check the old `plugins > saropa_lints:` block via `parseScalarFromPluginBlock` when the key is absent from the custom file, using the value with a logged migration warning.

**Dart init (`lib/src/init/`):**
- `config_writer.dart`: Removed `log_level` and `lane` from the main file output.
- `custom_overrides_core.dart`: Added `log_level` and `lane` to the custom file template.

**TypeScript (`extension/src/config/laneConfig.ts`):**
- Renamed all lane functions to `*CustomConfig` variants; reads/writes `analysis_options_custom.yaml` with top-level key.
- `writeLaneToCustomConfig` insertion-point regex hardened (`\s?` instead of `\s`) so bare `output:` / `log_level:` at EOL still anchors.
- Callers in `setup.ts` and `configTree.ts` updated.

**Tests:** All updated and passing (Dart 23/23, TS 37/37, write_config 12/12).

### Hardening (follow-up pass)

- `_leadingSpaces` renamed to `_leadingWhitespace` in `runtime_tier_cap.dart` — now counts tabs too, fixing the deprecation fallback for tab-indented plugin blocks.
- TS `leadingSpaces` → `leadingWhitespace` in `tierConfig.ts` (same fix).
- TS deprecation fallback added: `parseLaneFromPluginBlock` in `laneConfig.ts` + `readRawLaneFromCustomConfig` now falls back to the old plugin-block location, closing the TS/Dart display disagreement for unmigrated projects.
- `_readWithDeprecationFallback` extracted in `config_loader.dart` to de-duplicate the fallback pattern across all three loaders.
- Dead alias `final content = mainContent;` removed from `_loadDiagnosticsConfig`.
- `kLaneConfigKey` constant restored in `_loadRuleLane` (was using raw `'lane'` string).
- Garbled doc comment in `runtime_tier_cap.dart` reformatted.
- Stale doc comment in `configTree.ts` updated to reflect the new custom file location.

### Migrate Config feature

- **CLI:** `dart run saropa_lints migrate-config` — reads `log_level`/`lane`/`memory_mode` from the old plugin block, moves them to `analysis_options_custom.yaml`, removes them from `analysis_options.yaml`. Safe to run multiple times.
- **Extension:** `saropaLints.migrateConfig` command — sidebar button "Migrate config keys" + command palette entry. Shows informational toast with result.
- Registered in `package.json`, `package.nls.json`, `extension.ts`, and `configTree.ts`.

### Not addressed
- `rule_packs` also lives under `plugins > saropa_lints:` (same SDK warning risk, out of scope).
- `noPluginBlock` l10n key name stale; 24 non-English locale catalogs require regeneration.
