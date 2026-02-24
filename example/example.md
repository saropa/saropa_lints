# Saropa Lints Example Configuration

This file shows how to configure saropa_lints with all 1677+ rules.

## Setup

1. Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  saropa_lints: ^5.0.0
```

2. Add to `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - saropa_lints

saropa_lints:
  tier: recommended # essential | recommended | professional | comprehensive | pedantic
```

## Configuration Reference

See [analysis_options_template.yaml](analysis_options_template.yaml) for the complete configuration with all rules organized by category:

- **Security** - Credentials, encryption, input validation
- **Accessibility** - Screen readers, touch targets, semantics
- **Null Safety** - Proper null handling
- **Error Handling** - Exception management
- **Architecture** - Clean architecture patterns
- **Flutter Lifecycle** - Widget state management
- **Performance** - Build optimization, memory
- **Async** - Futures, Streams
- **Collections** - Safe collection usage
- **Control Flow** - Conditionals, loops
- **And 20+ more categories...**

## Importance Levels

Each rule is tagged with an importance level:

| Level | Meaning |
|-------|---------|
| `[CRITICAL]` | Bugs, crashes, data loss, security issues |
| `[HIGH]` | Likely bugs, performance problems |
| `[MEDIUM]` | Code quality, maintainability |
| `[LOW]` | Style preferences |
| `[NOISY]` | Valid but generates many warnings |

## Running the Linter

```bash
dart analyze
```
