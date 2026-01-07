# saropa_lints API Reference

Custom lint rules for Dart & Flutter static analysis.

## Configuration

Add to your `analysis_options.yaml`:

```yaml
custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

## Tiers

| Tier | Rules | Description |
|------|-------|-------------|
| `essential` | ~45 | Critical rules - prevents crashes, security issues |
| `recommended` | ~150 | Default for most teams |
| `professional` | ~350 | Enterprise teams |
| `comprehensive` | ~700 | Quality-obsessed teams |
| `insanity` | 475+ | Greenfield projects |

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
