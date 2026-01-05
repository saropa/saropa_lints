# Saropa Lints Example Configuration

This file shows a complete `custom_lint.yaml` configuration with all 475+ rules.

## Setup

1. Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^0.1.1
```

2. Add to `analysis_options.yaml`:
```yaml
analyzer:
  plugins:
    - custom_lint
```

3. Copy `custom_lint.yaml` to your project root and enable the rules you want.

## Configuration Reference

See [custom_lint.yaml](custom_lint.yaml) for the complete configuration with all rules organized by category:

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
dart run custom_lint
```
