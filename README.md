# saropa_lints

[![pub package](https://img.shields.io/pub/v/saropa_lints.svg)](https://pub.dev/packages/saropa_lints)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

497 lint rules for Flutter and Dart. MIT licensed. Free forever - no catches.

This is an active project and we want your input. Found a bug? Think a rule is wrong? Have a better approach? Open an issue or PR. We'd rather fix a bad rule than defend it.

## Quick Start

### 1. Add dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^0.1.0
```

### 2. Enable custom_lint

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

### 3. Choose your tier

```yaml
# analysis_options.yaml
include: package:saropa_lints/tiers/recommended.yaml
```

### 4. Run the linter

```bash
dart run custom_lint
```

## The 5 Tiers

Pick the tier that matches your team:

| Tier | Rules | Best For |
|------|-------|----------|
| **Essential** | ~50 | Every project. Prevents crashes, memory leaks, security holes. |
| **Recommended** | ~150 | Most teams. Adds performance, accessibility, testing basics. |
| **Professional** | ~300 | Enterprise. Adds architecture, documentation, comprehensive testing. |
| **Comprehensive** | ~400 | Quality obsessed. Best practices everywhere. |
| **Insanity** | 497 | Greenfield projects. Every single rule. |

### Using a tier

```yaml
# analysis_options.yaml

# Pick ONE of these:
include: package:saropa_lints/tiers/essential.yaml
include: package:saropa_lints/tiers/recommended.yaml      # Most teams start here
include: package:saropa_lints/tiers/professional.yaml
include: package:saropa_lints/tiers/comprehensive.yaml
include: package:saropa_lints/tiers/insanity.yaml
```

### Customizing rules

After including a tier, you can enable or disable specific rules:

```yaml
include: package:saropa_lints/tiers/recommended.yaml

custom_lint:
  rules:
    # Disable a rule from the tier
    avoid_hardcoded_strings_in_ui: false

    # Enable a rule from a higher tier
    require_public_api_documentation: true
```

## Rule Categories

| Category | Description |
|----------|-------------|
| **Flutter Widgets** | Lifecycle, setState, keys, performance |
| **State Management** | Provider, Riverpod, Bloc patterns |
| **Performance** | Build optimization, memory, caching |
| **Security** | Credentials, encryption, input validation |
| **Accessibility** | Screen readers, touch targets, semantics |
| **Testing** | Assertions, mocking, flaky test prevention |
| **Architecture** | Clean architecture, DI, SOLID principles |
| **Error Handling** | Exceptions, logging, recovery |
| **Async** | Futures, Streams, cancellation |
| **API & Network** | Timeouts, retries, caching |
| **Internationalization** | Localization, RTL, plurals |
| **Documentation** | Public API, examples, deprecation |

## Performance

Running all 497 rules uses significant memory. The tier system helps:
- Rules set to `false` are not loaded
- Start with `essential` or `recommended`
- Upgrade tiers as you fix warnings

```yaml
# GOOD: Start with recommended tier
include: package:saropa_lints/tiers/recommended.yaml

# BAD: Enabling everything at once on a legacy codebase
include: package:saropa_lints/tiers/insanity.yaml  # May show thousands of warnings
```

## Adoption Strategy

### New Projects

Start with `professional` or `comprehensive`. Fix issues as you write code.

### Existing Projects

1. Enable `essential`. Fix critical issues first.
2. Move to `recommended`. Fix warnings as you touch files.
3. Enable higher tiers when the noise is manageable.

### Suppressing Warnings

When a rule doesn't apply to specific code:

```dart
// ignore: avoid_hardcoded_strings_in_ui
const debugText = 'DEBUG MODE';

// For entire files:
// ignore_for_file: avoid_print_in_production
```

Always add a comment explaining **why** you're suppressing.

## IDE Integration

Works automatically in:
- **VS Code** with Dart extension
- **Android Studio / IntelliJ** with Dart plugin
- **Command line** via `dart run custom_lint`

Issues appear as you type with quick-fix suggestions.

## Contributing

Contributions are welcome. So is criticism.

If you think a rule is:
- **Wrong** - tell us why, we'll fix it or remove it
- **Too strict** - maybe it belongs in a higher tier
- **Too lenient** - maybe it should be stricter or have options
- **Missing** - propose it, or better yet, implement it

We don't have all the answers. If you've shipped production Flutter apps and have opinions, we want to hear them.

### How to contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

**Adding a new rule:**
1. Create rule in appropriate `lib/src/rules/*.dart` file
2. Add to the appropriate tier(s) in `lib/tiers/*.yaml`
3. Add tests in `test/rules/*_test.dart`
4. Update CHANGELOG.md

**Reporting issues:**
- Include a minimal code sample that triggers (or should trigger) the rule
- Explain what you expected vs what happened
- If you disagree with a rule's premise, say so directly

### Discussing rules

Not sure if something is a bug or a design decision? Open a discussion issue. We're happy to explain our reasoning and change our minds when presented with good arguments.

## Professional Services

Optional paid services for teams that want hands-on help:

| Service | Description |
|---------|-------------|
| **Reports** | Codebase analysis with prioritized findings |
| **Remediation** | We fix the issues |
| **Custom Rules** | Rules specific to your codebase |
| **Training** | Team workshops |

Contact: [saropa.com](https://saropa.com)

## License

MIT - see [LICENSE](LICENSE).

## Links

- [pub.dev package](https://pub.dev/packages/saropa_lints)
- [GitHub repository](https://github.com/saropa/saropa_lints)
- [Issue tracker](https://github.com/saropa/saropa_lints/issues)
- [Saropa website](https://saropa.com)
