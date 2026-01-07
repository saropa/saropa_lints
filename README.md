![saropa_lints banner](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/banner.png)

# saropa_lints

[![ci](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/saropa_lints.svg)](https://pub.dev/packages/saropa_lints)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

Developed by [Saropa][saropa_link]. Making the world of Dart & Flutter better, one lint at a time.

[saropa_link]: https://saropa.com

---

## Why saropa_lints?

### Linting vs static analysis

`flutter analyze` checks syntax and style. Static analysis checks *behavior*.

Your linter catches unused variables and formatting issues. It doesn't catch undisposed controllers, hardcoded credentials, or `setState` after `dispose` — because these require understanding what the code *does*, not just how it's written.

In mature ecosystems, tools like [SonarQube](https://www.sonarsource.com/products/sonarqube/), [Coverity](https://www.synopsys.com/software-integrity/security-testing/static-analysis-sast.html), and [Checkmarx](https://checkmarx.com/) fill this gap. Flutter hasn't had an equivalent — until now.

### What it catches

Code that compiles but fails at runtime:

```dart
// Memory leak — controller never disposed
final _controller = TextEditingController();

// Crash — setState after widget disposed
await api.fetchData();
setState(() => _data = data);  // boom

// State loss — new GlobalKey every build
Widget build(context) {
  final key = GlobalKey<FormState>();  // wrong
  return Form(key: key, ...);
}
```

saropa_lints detects these patterns and hundreds more:

- **Security** — Hardcoded credentials, sensitive data in logs, unsafe deserialization
- **Accessibility** — Missing semantics, inadequate touch targets, screen reader issues
- **Performance** — Unnecessary rebuilds, memory leaks, expensive operations in build
- **Lifecycle** — setState after dispose, missing mounted checks, undisposed resources

**Accuracy focused**: Rules use proper AST type checking instead of string matching, reducing false positives on variable names like "upstream" or "spinning".

### Why it matters

The [European Accessibility Act](https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en) takes effect June 2025, requiring accessible apps in retail, banking, and travel. GitHub detected [39 million leaked secrets](https://github.blog/security/application-security/next-evolution-github-advanced-security/) in repositories during 2024.

These aren't edge cases. They're compliance requirements and security basics that standard linters miss.

### Free and open

Good options exist, but many are paid or closed-source. We believe these fundamentals should be free and open. A rising tide lifts all boats.

The tier system lets you adopt gradually — start with 55 critical rules, work up to 547 when you're ready.

---

## Quick Start

### 1. Add dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^1.3.0
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
custom_lint:
  saropa_lints:
    tier: recommended  # essential | recommended | professional | comprehensive | insanity
```

### 4. Run the linter

```bash
dart run custom_lint
```

### Migrating from other tools?

- [Migrating from very_good_analysis](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_vga.md)
- [Migrating from DCM (Dart Code Metrics)](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_dcm.md)

## The 5 Tiers

Pick the tier that matches your team:

| Tier | Best For |
|------|----------|
| **Essential** | Every project. Prevents crashes, memory leaks, security holes. |
| **Recommended** | Most teams. Adds performance, accessibility, null safety, collection bounds. |
| **Professional** | Enterprise. Adds architecture, documentation, comprehensive testing. |
| **Comprehensive** | Quality obsessed. Best practices everywhere. |
| **Insanity** | Greenfield projects. Every single rule. |

**Plus 20 optional [stylistic rules](STYLISTIC.md)** — team preferences, not in any tier.

### Using a tier

```yaml
# analysis_options.yaml
custom_lint:
  saropa_lints:
    tier: recommended  # Most teams start here
```

Available tiers: `essential`, `recommended`, `professional`, `comprehensive`, `insanity`

### Customizing rules

After choosing a tier, you can enable or disable specific rules.

**IMPORTANT:** Rules must use YAML list format (with `-` prefix), not map format:

```yaml
custom_lint:
  saropa_lints:
    tier: recommended
  rules:
    # Disable a rule from the tier
    - avoid_hardcoded_strings_in_ui: false

    # Enable a rule from a higher tier
    - require_public_api_documentation: true

    # Enable stylistic rules (not in any tier by default)
    - prefer_single_quotes: true
    - prefer_trailing_comma_always: true
```

**Wrong (map format - rules will be silently ignored):**
```yaml
rules:
  avoid_hardcoded_strings_in_ui: false  # NO DASH = NOT PARSED!
```

**Correct (list format):**
```yaml
rules:
  - avoid_hardcoded_strings_in_ui: false  # DASH = PARSED!
```

### Severity levels

Each rule has a fixed severity (ERROR, WARNING, or INFO) defined in the rule itself. Severity cannot be overridden per-project. If a rule's severity doesn't match your needs:

- Use `// ignore: rule_name` to suppress individual occurrences
- Disable the rule entirely with `- rule_name: false`
- [Open an issue](https://github.com/saropa/saropa_lints/issues) if you think the default severity should change

## Rule Categories

| Category | Description |
|----------|-------------|
| **Flutter Widgets** | Lifecycle, setState, keys, performance |
| **Modern Dart 3.0+** | Class modifiers, patterns, records, when guards |
| **Modern Flutter** | TapRegion, OverlayPortal, SearchAnchor, CarouselView |
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

## Stylistic Rules

20 rules for team preferences — not included in any tier. Enable individually based on your conventions.

Examples: `prefer_relative_imports`, `prefer_single_quotes`, `prefer_arrow_functions`, `prefer_trailing_comma_always`

**See [STYLISTIC.md](STYLISTIC.md)** for the full list with examples, pros/cons, and quick fixes.

## Performance

Running all 1000 rules uses significant memory. The tier system helps:
- Rules set to `false` are not loaded
- Start with `essential` or `recommended`
- Upgrade tiers as you fix warnings

```yaml
# GOOD: Start with recommended tier
custom_lint:
  saropa_lints:
    tier: recommended

# BAD: Enabling everything at once on a legacy codebase
custom_lint:
  saropa_lints:
    tier: insanity  # May show thousands of warnings
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

// Hyphenated format also works:
// ignore: avoid-hardcoded-strings-in-ui
const debugText = 'DEBUG MODE';

// For entire files:
// ignore_for_file: avoid_print_in_production
```

Always add a comment explaining **why** you're suppressing.

### Automatic File Skipping

Rules automatically skip files that can't be manually fixed:

| File Pattern | Skipped By Default |
|--------------|-------------------|
| `*.g.dart`, `*.freezed.dart`, `*.gen.dart` | Yes (generated code) |
| `*_fixture.dart`, `fixture/**`, `fixtures/**` | Yes (test fixtures) |
| `*_test.dart`, `test/**` | No (override with `skipTestFiles`) |
| `example/**` | No (override with `skipExampleFiles`) |

This reduces noise from generated code and intentionally "bad" fixture files.

## Running the Linter

**Command line (recommended - always works):**
```bash
dart run custom_lint
```

**IDE Integration (unreliable):**

custom_lint uses the Dart analyzer plugin system, which has known reliability issues. IDE integration may or may not work depending on your setup. If you don't see warnings in your IDE:

1. Run `flutter pub get`
2. Restart VS Code completely (not just the analysis server)
3. Check **View → Output → Dart Analysis Server** for errors
4. If still not working, use the CLI - it's reliable

**If custom_lint crashes:**

If you see native crashes (e.g., `ExceptionCode=-1073741819` on Windows), clear the analysis cache:

```bash
# Windows
rmdir /s /q .dart_tool && flutter pub get

# macOS/Linux
rm -rf .dart_tool && flutter pub get
```

Then run `dart run custom_lint` again.

**For reliable workflows, use:**
- Pre-commit hooks
- CI/CD checks
- VS Code tasks (see below)

### VS Code Task Setup (Recommended)

Create `.vscode/tasks.json` in your project root:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "custom_lint",
      "type": "shell",
      "command": "dart run custom_lint",
      "group": {
        "kind": "build",
        "isDefault": true
      },
      "presentation": {
        "reveal": "always",
        "panel": "dedicated"
      },
      "problemMatcher": {
        "owner": "custom_lint",
        "fileLocation": ["relative", "${workspaceFolder}"],
        "pattern": {
          "regexp": "^\\s*(.+):(\\d+):(\\d+)\\s+•\\s+(.+)\\s+•\\s+(\\w+)\\s+•\\s+(ERROR|WARNING|INFO)$",
          "file": 1,
          "line": 2,
          "column": 3,
          "message": 4,
          "code": 5,
          "severity": 6
        }
      }
    }
  ]
}
```

**Usage:**
- Press **Ctrl+Shift+B** (or **Cmd+Shift+B** on Mac) to run custom_lint
- Warnings appear in the **Problems** panel (Ctrl+Shift+M)
- Click any warning to jump to that line in your code

This is more reliable than IDE integration because it runs the actual CLI tool rather than depending on the analyzer plugin system.

## Contributing

We believe great tools are built by communities, not companies. Contributions and feedback are always welcome.

If you think a rule is:
- **Wrong** - tell us why, we'll fix it or remove it
- **Too strict** - maybe it belongs in a higher tier
- **Too lenient** - maybe it should be stricter or have options
- **Missing** - propose it, or better yet, implement it

We don't have all the answers. If you've shipped production Flutter apps and have opinions, we want to hear them.

### How to contribute

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for detailed guidelines.

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

Optional paid services for teams that want hands-on help. See [ENTERPRISE.md](https://github.com/saropa/saropa_lints/blob/main/ENTERPRISE.md) for details.

| Service | Description |
|---------|-------------|
| **Codebase Assessment** | We analyze your codebase, prioritize findings, create a remediation roadmap |
| **Remediation** | We fix the issues — you stay focused on features |
| **Custom Rules** | Rules specific to your architecture and compliance requirements |
| **Training** | Team workshops on Flutter best practices |

Contact: [saropa.com](https://saropa.com) | [lints@saropa.com](mailto:lints@saropa.com)

## Documentation

| Document | Description |
|----------|-------------|
| [STYLISTIC.md](STYLISTIC.md) | 20 optional stylistic rules with examples and quick fixes |
| [ROADMAP.md](ROADMAP.md) | Planned rules and project direction |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute rules and report issues |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [SECURITY.md](SECURITY.md) | Security policy and reporting vulnerabilities |
| [ENTERPRISE.md](ENTERPRISE.md) | Professional services and custom rules |

## Badge

To indicate your project is using `saropa_lints`:

[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

```md
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)
```

## License

MIT - see [LICENSE](https://github.com/saropa/saropa_lints/blob/main/LICENSE). Use it however you like.

---

Built with care by the Flutter community. Questions? Ideas? We'd love to hear from you.

[pub.dev][pub_link] | [GitHub][github_link] | [Issues][issues_link] | [Saropa][saropa_link]

[pub_link]: https://pub.dev/packages/saropa_lints
[github_link]: https://github.com/saropa/saropa_lints
[issues_link]: https://github.com/saropa/saropa_lints/issues
