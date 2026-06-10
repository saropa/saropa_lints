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
        - dart_sdk_3_2
        - flutter_sdk_3_7
```

Unknown pack ids are ignored. Rule-pack ownership is authoritative: pack-owned
rules are removed from tier-derived enables, then re-enabled only by
`rule_packs.enabled`. Any rule set to `false` in `diagnostics` (or disabled via
severities) **stays off** — explicit opt-out wins over pack opt-in.

### Legacy key compatibility (`migration_packs`)

`rule_packs` is the canonical key. For backward compatibility, parsers still
read legacy `migration_packs.enabled`.

- If both keys are present, `rule_packs.enabled` takes precedence.
- Writers (`dart run saropa_lints:init` and the VS Code Rule Packs view) normalize
  output to `rule_packs` and remove legacy `migration_packs` blocks.

## Semver-gated packs (pubspec.lock)

Some packs only merge when a dependency’s **resolved** version in
`pubspec.lock` satisfies a constraint (see `kRulePackDependencyGates` in
`lib/src/config/rule_packs.dart`). If the lockfile is missing or the package
is absent, those packs do **not** add rules (conservative). Ungated packs
behave as before.

Current semver-gated packs:

- **`collection_compat`** — gated on `collection >= 1.19.0`.
- **`riverpod_2`** — gated on `riverpod >= 2.0.0`. Holds `prefer_notifier_over_state`,
  which recommends migrating `StateProvider` to `NotifierProvider`. That target
  API only exists in Riverpod 2.x, so the rule is **moved out** of the base
  `riverpod` pack into `riverpod_2` — a Riverpod 1.x project never sees a
  recommendation it cannot follow. (`flutter_riverpod` / `hooks_riverpod` 2.x both
  resolve `riverpod` 2.x in the lockfile, so the core-package gate covers them.)

When a version-gated rule would otherwise live in an ungated package pack, it is
relocated via `kRelocatedRulePackCodes` (in `tool/rule_pack_audit.dart`) so the
gate is authoritative — both the registry generator and the audit apply the same
relocation.

## SDK-gated packs (pubspec `environment`)

Some packs are gated by SDK constraints in `pubspec.yaml` `environment:`:

- `dart_sdk_3_2` (requires `environment.sdk >= 3.2.0`)
- `flutter_sdk_3_0` (requires `environment.flutter >= 3.0.0`)
- `flutter_sdk_3_7` (requires `environment.flutter >= 3.7.0`)
- `flutter_sdk_3_10` (requires `environment.flutter >= 3.10.0`)
- `flutter_sdk_3_16` (requires `environment.flutter >= 3.16.0`)
- `flutter_sdk_3_18` (requires `environment.flutter >= 3.18.0`)
- `flutter_sdk_3_19` (requires `environment.flutter >= 3.19.0`)
- `flutter_sdk_3_22` (requires `environment.flutter >= 3.22.0`)
- `flutter_sdk_3_24` (requires `environment.flutter >= 3.24.0`)
- `flutter_sdk_3_28` (requires `environment.flutter >= 3.28.0`)
- `flutter_sdk_3_29` (requires `environment.flutter >= 3.29.0`)
- `flutter_sdk_3_32` (requires `environment.flutter >= 3.32.0`)
- `flutter_sdk_3_35` (requires `environment.flutter >= 3.35.0`)
- `flutter_sdk_3_38` (requires `environment.flutter >= 3.38.0`)

These packs are considered applicable from SDK constraints (not dependency markers).

## CLI (`dart run saropa_lints:init`)

- **`--list-packs`** — prints each pack, whether `pubspec.yaml` suggests it,
  semver gate status from `pubspec.lock`, and overall applicability; then exits.
- **`--enable-pack <id>`** — repeat to add packs; merged into
  `rule_packs.enabled` when init writes `analysis_options.yaml` (preserved across
  regenerations unless `--reset`, which clears packs unless you pass
  `--enable-pack` again).

## VS Code

**Saropa Lints: Open Lints Config** opens an **editor tab** (not a narrow sidebar) that lists packs, whether dependencies appear in
`pubspec.yaml`, toggles, rule counts, and target platforms (Flutter embedder
folders). SDK packs are detected from `environment.sdk` / `environment.flutter`
constraints. Toggles write the same `rule_packs` YAML. The **Issues** view title also exposes this command in Dart workspaces.

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

Optional future work (`saropa_lints_api` / Phase 7 in the architecture plan) is **not shipped**; see [plans/plan_migration_plugin_system.md](../../plans/plan_migration_plugin_system.md) §10 Phase 7.

## See also

- [composite_analyzer_plugin.md](composite_analyzer_plugin.md) — Saropa + custom rules in one plugin
- [plans/plan_migration_plugin_system.md](../../plans/plan_migration_plugin_system.md) — full product plan
