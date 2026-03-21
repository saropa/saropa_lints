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

## VS Code

The **Rule Packs** sidebar view lists packs, whether dependencies appear in
`pubspec.yaml`, toggles, rule counts, and target platforms (Flutter embedder
folders). Toggles write the same `rule_packs` YAML.

## Registry

Pack contents live in `lib/src/config/rule_packs.dart` and are mirrored in
`extension/src/rulePacks/rulePackDefinitions.ts` for the extension UI.

## See also

- [plan/plan_migration_plugin_system.md](../../plan/plan_migration_plugin_system.md) — full product plan
