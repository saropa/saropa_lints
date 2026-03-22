# Rule packs (optional)

When you use the **native analyzer plugin** configuration produced by
`dart run saropa_lints:init`, you can enable **named bundles** of rules for
specific stacks (Riverpod, Drift, etc.) without listing every rule id.

## Configuration

Under `plugins.saropa_lints` in `analysis_options.yaml`:

```yaml
plugins:
  saropa_lints:
    version: "9.x.x"
    rule_packs:
      enabled:
        - riverpod
        - drift
```

Unknown pack ids are ignored. Rule codes from packs are merged into the
effective enabled set **after** `diagnostics:`; any rule set to `false` in
`diagnostics` (or disabled via severities) **stays off** — explicit opt-out
wins over pack opt-in.

## Semver-gated packs (pubspec.lock)

Some packs only merge when a dependency’s **resolved** version in
`pubspec.lock` satisfies a constraint (see `kRulePackDependencyGates` in
`lib/src/config/rule_packs.dart`). If the lockfile is missing or the package
is absent, those packs do **not** add rules (conservative). Ungated packs
behave as before.

## CLI (`dart run saropa_lints:init`)

- **`--list-packs`** — prints each pack, whether `pubspec.yaml` suggests it,
  semver gate status from `pubspec.lock`, and overall applicability; then exits.
- **`--enable-pack <id>`** — repeat to add packs; merged into
  `rule_packs.enabled` when init writes `analysis_options.yaml` (preserved across
  regenerations unless `--reset`, which clears packs unless you pass
  `--enable-pack` again).

## VS Code

The **Rule Packs** sidebar view lists packs, whether dependencies appear in
`pubspec.yaml`, toggles, rule counts, and target platforms (Flutter embedder
folders). Toggles write the same `rule_packs` YAML.

## Registry

Effective pack → rule code maps are built from generated data plus a small merge in
`lib/src/config/rule_packs.dart` (e.g. semver-only `collection_compat`). Pubspec marker
keys are generated the same way.

### Maintainers: regenerate and audit

After adding, removing, or renaming rules under `lib/src/rules/packages/*_rules.dart`:

1. Run **`dart run tool/generate_rule_pack_registry.dart`** — refreshes
   `lib/src/config/rule_pack_codes_generated.dart` and
   `extension/src/rulePacks/rulePackDefinitions.ts` (labels, `matchPubNames`, rule lists).
2. If a rule must belong to **more than one** pack but is implemented in one file only,
   add it to **`kCompositeRulePackIds`** in `tool/rule_pack_audit.dart` (see
   `avoid_isar_import_with_drift` → drift + isar).
3. Run **`dart run tool/rule_pack_audit.dart`** — must exit 0 (compares extracted
   `LintCode` names to `kRulePackRuleCodes`).

The generator also warns when `kPubspecMarkersByPack` in
`tool/generate_rule_pack_registry.dart` is missing a pack or lists an unused pack id.

## Custom or project-specific rules (e.g. `Text` → `CommonText`)

**Rule packs are not a plugin SDK.** They only turn on **bundles of rules that already ship inside** `package:saropa_lints`. You cannot point a pack at arbitrary code in another package.

For **team-specific** analyzer diagnostics (naming wrappers, banned APIs, migration nags):

- **Composite analyzer plugin** — A single dev_dependency package depends on `saropa_lints` plus your rules and exposes the one `plugin` entry; call `loadNativePluginConfig` in `start`, `registerSaropaLintRules` in `register`, then register your rules. See [composite_analyzer_plugin.md](composite_analyzer_plugin.md).
- **Private fork or path dependency** — Add rule classes to your fork of `saropa_lints`, register them in `all_rules.dart` / tiers like any maintainer change, and depend on that package from your app. Works today without a facade package.
- **Not a second native plugin** — The Dart analyzer enforces **one analyzer plugin per analysis context** for merged options, so you generally **cannot** run `saropa_lints` and a separate custom analyzer plugin together in the same project. See [dart-lang/sdk#50981](https://github.com/dart-lang/sdk/issues/50981).
- **Outside the analyzer** — Codemods (`dart fix` custom transforms, bespoke CLI), CI grep/checks, or code review bots for policies that do not need IDE squiggles.

Optional future work (`saropa_lints_api` / Phase 7 in the architecture plan) is **not shipped**; see [plan/plan_migration_plugin_system.md](../../plan/plan_migration_plugin_system.md) §10 Phase 7.

## See also

- [composite_analyzer_plugin.md](composite_analyzer_plugin.md) — Saropa + custom rules in one plugin
- [plan/plan_migration_plugin_system.md](../../plan/plan_migration_plugin_system.md) — full product plan
