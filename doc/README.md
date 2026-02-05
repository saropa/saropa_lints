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

## Links

- [GitHub Repository](https://github.com/saropa/saropa_lints)
- [pub.dev Package](https://pub.dev/packages/saropa_lints)
