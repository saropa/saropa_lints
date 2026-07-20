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
      avoid_unguarded_debug: true
      # … other Saropa rule ids …
    rule_packs:
      enabled:
        - riverpod
```

Your meta-plugin’s `Plugin.name` should return `acme_saropa` so it matches the YAML key.

**Runtime tier cap:** use `SAROPA_TIER` or `saropa_tier` in `analysis_options_custom.yaml` (project root). The plugin-block key that carries `runtime_tier` is read as `plugins.saropa_lints` only; for a custom `plugins.*` name, set the cap via environment or the custom file.

## API surface (from `package:saropa_lints/saropa_lints.dart`)

| Symbol | Use |
|--------|-----|
| `loadNativePluginConfig` | Load tier/diagnostics/packs/baseline/output from YAML and env (call from `start`). |
| `loadOutputConfigFromProjectRoot` | Refresh output settings when project root is known (if you mirror Saropa behavior). |
| `loadRulePacksConfigFromProjectRoot` | Re-merge rule packs from lockfile when project root is known. |
| `registerSaropaLintRules` | Register Saropa rules and fixes on the registry (call from `register`). |
| `SaropaLintRule`, Saropa rule patterns in this repo | Extend for rules in Saropa’s pipeline; or use analyzer `AbstractAnalysisRule` per [Dart analyzer plugins](https://dart.dev/tools/analyzer-plugins). |

### Optional facade: `package:saropa_lints_api`

The repository ships a tiny sibling package, **`saropa_lints_api`** (`packages/saropa_lints_api/`), that **re-exports** the same composite-plugin symbols (`registerSaropaLintRules`, the config loaders, `SaropaLintRule`). Meta-plugins may depend on `saropa_lints_api` instead of declaring `saropa_lints` directly if you want a narrow import surface and a single place to bump the Saropa constraint.

## `dart run saropa_lints:init` and VS Code

Init still generates `plugins.saropa_lints` for normal setups. For a composite plugin:

**VS Code (recommended):** Command palette → **“Saropa Lints: Create Composite Analyzer Plugin (scaffold)”**. The action is intentionally not in the sidebar — it targets a narrow audience (teams that ship their own custom analyzer rules) and the term is jargon for the typical Saropa user. The command is also listed under **Saropa Lints: Show All Commands**. The extension shows a short preflight notification (**Continue** / **Open guide**) so you can read what will happen or open this guide before choosing a workspace-relative folder (default `packages/composite_saropa_plugin`).

**CLI:**

```bash
dart run saropa_lints:init --emit-composite-plugin-scaffold [dir]
```

Both paths write a minimal `pubspec.yaml` + `lib/main.dart` + `README.md` under the chosen folder (CLI: default `composite_saropa_plugin` relative to `--target` when the path is omitted). Adjust the generated `Plugin.name` / package name to match your `analysis_options.yaml` key, then add your rules in `register`.

## See also

- [Rule packs](rule_packs.md) — optional Saropa bundles (same YAML block as above).
- [plans/plan_migration_plugin_system.md](../../plans/plan_migration_plugin_system.md) — Phase 7 product context.
