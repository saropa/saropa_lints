![saropa_lints banner](assets/banner.png)

# saropa_lints

[![ci](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/saropa_lints.svg)](https://pub.dev/packages/saropa_lints)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

Developed by [Saropa][saropa_link]. Making the world of Dart & Flutter better, one lint at a time.

[saropa_link]: https://saropa.com

---

## Why saropa_lints?

Flutter's ecosystem is young. The mature tooling that other platforms take for granted — security analysis, accessibility enforcement, architectural guardrails — is still catching up.

Good options exist, but many are paid or closed-source. We believe these fundamentals should be free and open. A rising tide lifts all boats.

Dart's analyzer catches syntax errors. saropa_lints catches the rest:

- **Security** — Hardcoded credentials, unsafe deserialization, input validation gaps
- **Accessibility** — Missing semantics, inadequate touch targets, screen reader issues
- **Performance** — Unnecessary rebuilds, memory leaks, expensive operations in build methods
- **Maintainability** — Inconsistent patterns, error handling gaps, architectural drift

The tier system lets you adopt gradually. Start with 50 critical rules, work up to 1000 when you're ready.

---

## Quick Start

### 1. Add dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^1.1.9
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

### Migrating from other tools?

- [Migrating from very_good_analysis](docs/migration_from_vga.md)
- [Migrating from DCM (Dart Code Metrics)](docs/migration_from_dcm.md)

## The 5 Tiers

Pick the tier that matches your team:

| Tier | Rules | Best For |
|------|-------|----------|
| **Essential** | ~100 | Every project. Prevents crashes, memory leaks, security holes. |
| **Recommended** | ~300 | Most teams. Adds performance, accessibility, testing basics. |
| **Professional** | ~600 | Enterprise. Adds architecture, documentation, comprehensive testing. |
| **Comprehensive** | ~800 | Quality obsessed. Best practices everywhere. |
| **Insanity** | 1000 | Greenfield projects. Every single rule. |

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

Running all 1000 rules uses significant memory. The tier system helps:
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

We believe great tools are built by communities, not companies. Contributions and feedback are always welcome.

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

Optional paid services for teams that want hands-on help. See [ENTERPRISE.md](ENTERPRISE.md) for details.

| Service | Description |
|---------|-------------|
| **Codebase Assessment** | We analyze your codebase, prioritize findings, create a remediation roadmap |
| **Remediation** | We fix the issues — you stay focused on features |
| **Custom Rules** | Rules specific to your architecture and compliance requirements |
| **Training** | Team workshops on Flutter best practices |

Contact: [saropa.com](https://saropa.com) | [lints@saropa.com](mailto:lints@saropa.com)

## Badge

To indicate your project is using `saropa_lints`:

[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

```md
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)
```

## License

MIT - see [LICENSE](LICENSE). Use it however you like.

---

Built with care by the Flutter community. Questions? Ideas? We'd love to hear from you.

[pub.dev][pub_link] | [GitHub][github_link] | [Issues][issues_link] | [Saropa][saropa_link]

[pub_link]: https://pub.dev/packages/saropa_lints
[github_link]: https://github.com/saropa/saropa_lints
[issues_link]: https://github.com/saropa/saropa_lints/issues
