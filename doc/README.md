# Saropa Lints API Reference

Custom lint rules for Dart & Flutter static analysis.

## Configuration

Generate your configuration with the CLI tool:

```bash
dart run saropa_lints:init --tier recommended
```

Available tiers: `essential` (1), `recommended` (2), `professional` (3),
`comprehensive` (4), `pedantic` (5).

## Tiers

| Tier | Rules | Description |
|------|-------|-------------|
| `essential` | ~45 | Critical rules - prevents crashes, security issues |
| `recommended` | ~150 | Default for most teams |
| `professional` | ~350 | Enterprise teams |
| `comprehensive` | ~700 | Quality-obsessed teams |
| `pedantic` | 475+ | Greenfield projects |

## Rule Categories

- **Security** - Hardcoded credentials, sensitive data exposure
- **Accessibility** - Missing semantics, touch targets
- **Performance** - Memory leaks, unnecessary rebuilds
- **Lifecycle** - Disposal, mounted checks
- **Architecture** - Layer violations, god classes
- **Testing** - Best practices, flaky test detection

## Guides

- [Migration from v4 to v5](guides/migration_v4_to_v5.md) — custom_lint to native analyzer plugin
- [Upgrading to v7](guides/upgrading_to_v7.md) — analyzer 10, lowerCaseName config, and breaking changes
- [Rule packs](guides/rule_packs.md) — optional stack bundles; not a third-party plugin API (see “Custom or project-specific rules” there)
- [Composite analyzer plugin](guides/composite_analyzer_plugin.md) — one meta-plugin: Saropa + org-specific rules (`registerSaropaLintRules`, `loadNativePluginConfig`)

## Links

- [GitHub Repository](https://github.com/saropa/saropa_lints)
- [pub.dev Package](https://pub.dev/packages/saropa_lints)
