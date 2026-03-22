# Composite analyzer plugin (org-specific rules + Saropa)

Dart allows **one analyzer plugin per analysis context**. To ship **your own** lint rules (for example “prefer `CommonText` over `Text`”) **and** keep Saropa Lints, use a **single** plugin package that:

1. Depends on `package:saropa_lints` and on a package (or `lib/`) that defines your rules.
2. Exposes `lib/main.dart` with the top-level `plugin` variable required by the analysis server.
3. In `Plugin.start`, calls `loadNativePluginConfig` (re-exported from `package:saropa_lints/saropa_lints.dart`).
4. In `Plugin.register`, calls `registerSaropaLintRules` on the `PluginRegistry`, then registers your rules and fixes the same way. That registrar skips rules when `SaropaLintRule.isDisabled` is true (including disables keyed by `configAliases`).

## `analysis_options.yaml`

Enable **your** plugin name (not `saropa_lints` alongside another plugin). Put Saropa’s settings **under that block** — `version`, `diagnostics`, `rule_packs`, etc. The native config loader finds the first `diagnostics:` / `rule_packs:` blocks in the merged file; keep a single plugin section to avoid ambiguity.

Example shape:

```yaml
plugins:
  acme_saropa:
    path: packages/acme_saropa_plugin
    version: "0.0.1" # or pub version for your meta-plugin
    diagnostics:
      avoid_debug_print: true
      # … other Saropa rule ids …
    rule_packs:
      enabled:
        - riverpod
```

Your meta-plugin’s `Plugin.name` should return `acme_saropa` so it matches the YAML key.

## API surface (from `package:saropa_lints/saropa_lints.dart`)

| Symbol | Use |
|--------|-----|
| `loadNativePluginConfig` | Load tier/diagnostics/packs/baseline/output from YAML and env (call from `start`). |
| `loadOutputConfigFromProjectRoot` | Refresh output settings when project root is known (if you mirror Saropa behavior). |
| `loadRulePacksConfigFromProjectRoot` | Re-merge rule packs from lockfile when project root is known. |
| `registerSaropaLintRules` | Register Saropa rules and fixes on the registry (call from `register`). |
| `SaropaLintRule`, Saropa rule patterns in this repo | Extend for rules in Saropa’s pipeline; or use analyzer `AbstractAnalysisRule` per [Dart analyzer plugins](https://dart.dev/tools/analyzer-plugins). |

## `dart run saropa_lints:init`

Init currently generates `plugins.saropa_lints`. For a composite setup you will **hand-edit** or script YAML until init grows a template flag.

## See also

- [Rule packs](rule_packs.md) — optional Saropa bundles (same YAML block as above).
- [plan/plan_migration_plugin_system.md](../../plan/plan_migration_plugin_system.md) — Phase 7 product context.
