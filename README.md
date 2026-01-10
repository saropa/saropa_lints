![saropa_lints banner](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/banner_v2.png)

# Saropa Lints

[![ci](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/saropa_lints.svg)](https://pub.dev/packages/saropa_lints)
[![pub points](https://img.shields.io/pub/points/saropa_lints)](https://pub.dev/packages/saropa_lints/score)
[![rules](https://img.shields.io/badge/rules-860%2B-4B0082)](https://github.com/saropa/saropa_lints/blob/main/doc/rules/README.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

Developed by [Saropa][saropa_link]. Making the world of Dart & Flutter better, one lint at a time.

[saropa_link]: https://saropa.com

---

## Why Saropa Lints?

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

Saropa Lints detects these patterns and hundreds more:

- **Security** — Hardcoded credentials, sensitive data in logs, unsafe deserialization
- **Accessibility** — Missing semantics, inadequate touch targets, screen reader issues
- **Performance** — Unnecessary rebuilds, memory leaks, expensive operations in build
- **Lifecycle** — setState after dispose, missing mounted checks, undisposed resources

**Accuracy focused**: Rules use proper AST type checking instead of string matching, reducing false positives on variable names like "upstream" or "spinning".

### Essential for reactive libraries

If you use **GetX**, **Riverpod**, **Provider**, **Bloc**, or **Isar**, these audits are critical. These libraries are powerful but have patterns that fail silently at runtime:

| Library | Common issues caught | Guide |
|---------|---------------------|-------|
| **GetX** | Undisposed controllers, memory leaks from listeners | [Using with GetX](doc/guides/using_with_getx.md) |
| **Riverpod** | Circular provider deps, ref.read() in build, missing ProviderScope | [Using with Riverpod](doc/guides/using_with_riverpod.md) |
| **Provider** | Provider.of in build causing rebuilds, recreated providers losing state | [Using with Provider](doc/guides/using_with_provider.md) |
| **Bloc** | Events in constructor, mutable state, unclosed Blocs, BlocListener in build | [Using with Bloc](doc/guides/using_with_bloc.md) |
| **Isar** | Enum fields causing data corruption on schema changes | [Using with Isar](doc/guides/using_with_isar.md) |

Standard linters don't understand these libraries. They see valid Dart code. Saropa Lints has 20+ rules specifically for state management anti-patterns that cause crashes, memory leaks, and data corruption in production.

### Why it matters

The [European Accessibility Act](https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en) takes effect June 2025, requiring accessible apps in retail, banking, and travel. GitHub detected [39 million leaked secrets](https://github.blog/security/application-security/next-evolution-github-advanced-security/) in repositories during 2024.

These aren't edge cases. They're compliance requirements and security basics that standard linters miss.

### Free and open

Good options exist, but many are paid or closed-source. We believe these fundamentals should be free and open. A rising tide lifts all boats.

The tier system lets you adopt gradually — start with ~100 critical rules, work up to 860+ when you're ready.

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

- [Migrating from very_good_analysis](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_vga.md) (also covers `lints`, `lint`, `pedantic`)
- [Migrating from DCM (Dart Code Metrics)](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_dcm.md)
- [Migrating from solid_lints](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_solid_lints.md)
- [Using with flutter_lints](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_flutter_lints.md) (complementary setup)

## The 5 Tiers

Pick the tier that matches your team:

| Tier | Best For |
|------|----------|
| **Essential** | Every project. Prevents crashes, memory leaks, security holes. |
| **Recommended** | Most teams. Adds performance, accessibility, null safety, collection bounds. |
| **Professional** | Enterprise. Adds architecture, documentation, comprehensive testing. |
| **Comprehensive** | Quality obsessed. Best practices everywhere. |
| **Insanity** | Greenfield projects. Every single rule. |

**Plus 21 optional [stylistic rules](https://github.com/saropa/saropa_lints/blob/main/STYLISTIC.md)** — team preferences, not in any tier.

### Configuration template

See [example/analysis_options_template.yaml](https://github.com/saropa/saropa_lints/blob/main/example/analysis_options_template.yaml) for a complete reference with all 860+ rules organized by category, tier membership, and examples.

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

**See [STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/STYLISTIC.md)** for the full list with examples, pros/cons, and quick fixes.

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

## Limitations

- Scope: custom_lint (and therefore saropa_lints) only runs rules inside the package where you invoke it. `dependency_overrides` pointing to local packages are not linted automatically—add saropa_lints to the overridden package and run `dart run custom_lint` in that package (or wire a workspace task) if you want coverage there.
- File types: Only Dart source files (`.dart`) are analyzed. Non-Dart assets (JSON, XML, YAML, scripts, etc.) are out of scope for custom_lint.

## Running the Linter

**Command line (recommended - always works):**
```bash
dart run custom_lint
```

### Impact Report

Run lints with results grouped by business impact:

```bash
dart run saropa_lints:impact_report
```

Output shows critical issues first, with actionable guidance:

```
--- CRITICAL (2) ---
  lib/main.dart:45 - avoid_hardcoded_credentials
  lib/auth.dart:23 - require_dispose

--- HIGH (5) ---
  lib/widget.dart:89 - avoid_icon_buttons_without_tooltip
  ...

Impact Summary
==============
CRITICAL: 2 (fix immediately!)
HIGH:     5 (address soon)
MEDIUM:   12 (tech debt)
LOW:      34 (style)

Total: 53 issues
```

**Impact levels:**
- `critical`: Each occurrence is serious — even 1-2 is unacceptable (memory leaks, security)
- `high`: 10+ requires action (accessibility, performance anti-patterns)
- `medium`: 100+ indicates tech debt (error handling, complexity)
- `low`: Large counts acceptable (style, naming conventions)

Exit code equals the number of critical issues (capped at 125), making it CI-friendly.

**IDE Integration (unreliable):**

custom_lint uses the Dart analyzer plugin system, which has known reliability issues. IDE integration may or may not work depending on your setup. If you don't see warnings in your IDE:

1. Run `flutter pub get`
2. Restart VS Code completely (not just the analysis server)
3. Check **View → Output → Dart Analysis Server** for errors
4. If still not working, use the CLI - it's reliable

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

### VS Code Status Bar Button (Optional)

Want a clickable button instead of remembering the keyboard shortcut? Install the included extension:

```bash
python scripts/install_vscode_extension.py
```

Then restart VS Code.

**What you get:**

- A **"Lints"** button in the status bar (bottom of VS Code)
- A search icon in the editor title bar when viewing Dart files
- Both trigger `dart run custom_lint` and open the Problems panel

## Troubleshooting

### IDE doesn't show lint warnings

If your IDE isn't automatically detecting lint issues:

1. **Use the keyboard shortcut**: Press **Ctrl+Shift+B** (or **Cmd+Shift+B** on Mac) to run custom_lint manually via the VS Code task
2. **Use the bug button**: If you installed the status bar extension, click the **"Lints"** button in the status bar or the search icon in the editor title bar
3. Restart VS Code completely (not just the analysis server)
4. Check **View → Output → Dart Analysis Server** for errors
5. If IDE integration remains unreliable, use the CLI directly: `dart run custom_lint`

### Out of Memory errors

If you see errors like:
```
../../runtime/vm/zone.cc: 96: error: Out of memory.
Crash occurred when compiling package:analyzer/... in optimizing JIT mode
```

**Solution 1: Clear the pub cache** (most effective)
```bash
dart pub cache clean
dart pub get
dart run custom_lint
```

**Solution 2: Increase Dart heap size** (PowerShell)
```powershell
$env:DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart run custom_lint
```

**Solution 3: Delete local build artifacts**
```bash
# Windows
rmdir /s /q .dart_tool && dart pub get

# macOS/Linux
rm -rf .dart_tool && dart pub get
```

### Native crashes (Windows)

If you see native crashes with error codes like `ExceptionCode=-1073741819`:

```bash
# Windows
rmdir /s /q .dart_tool && flutter pub get

# macOS/Linux
rm -rf .dart_tool && flutter pub get
```

Then run `dart run custom_lint` again.

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
| [STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/STYLISTIC.md) | 20 optional stylistic rules with examples and quick fixes |
| [ROADMAP.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md) | Planned rules and project direction |
| [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) | How to contribute rules and report issues |
| [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) | Version history and release notes |
| [SECURITY.md](https://github.com/saropa/saropa_lints/blob/main/SECURITY.md) | Security policy and reporting vulnerabilities |
| [ENTERPRISE.md](https://github.com/saropa/saropa_lints/blob/main/ENTERPRISE.md) | Professional services and custom rules |

### State Management Guides

| Library | Guide |
|---------|-------|
| Riverpod | [Using with Riverpod](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_riverpod.md) |
| Bloc | [Using with Bloc](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_bloc.md) |
| Provider | [Using with Provider](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_provider.md) |
| GetX | [Using with GetX](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_getx.md) |
| Isar | [Using with Isar](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_isar.md) |

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

---

## About This Project

> "The bitterness of poor quality remains long after the sweetness of meeting the schedule has been forgotten." — Karl Wiegers

> "Quality is not an act, it is a habit." — Aristotle

**saropa_lints** is a comprehensive static analysis package for Flutter and Dart applications. With 860+ lint rules organized into 5 progressive tiers (and more planned), it catches memory leaks, security vulnerabilities, accessibility violations, and runtime crashes that standard linters miss. Whether you're building a startup MVP or enterprise software, saropa_lints helps you ship more stable, secure, and accessible apps.

**Keywords:** Flutter linter, Dart static analysis, custom_lint rules, Flutter code quality, memory leak detection, security scanning, accessibility testing, WCAG compliance, European Accessibility Act, Flutter best practices, Dart analyzer plugin, code review automation, CI/CD linting, Flutter enterprise tools

**Hashtags:** #Flutter #Dart #StaticAnalysis #CodeQuality #FlutterDev #DartLang #Linting #DevTools #OpenSource #Accessibility #Security #BestPractices

---

## Sources

- **custom_lint** — Plugin framework for custom Dart analysis rules
  https://pub.dev/packages/custom_lint

- **Dart Analyzer** — Dart's static analysis engine
  https://dart.dev/tools/analysis

- **Flutter Accessibility** — Flutter accessibility documentation
  https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility

- **WCAG 2.1 Guidelines** — Web Content Accessibility Guidelines
  https://www.w3.org/WAI/standards-guidelines/wcag/

- **European Accessibility Act** — EU accessibility legislation effective June 2025
  https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en

- **GitHub Secret Scanning** — Leaked credentials detection report
  https://github.blog/security/application-security/next-evolution-github-advanced-security/

- **OWASP Top 10** — Application security vulnerabilities
  https://owasp.org/www-project-top-ten/

- **SonarQube** — Static analysis platform
  https://www.sonarsource.com/products/sonarqube/

- **Effective Dart** — Official Dart style guide
  https://dart.dev/effective-dart

- **Flutter Performance** — Performance best practices
  https://docs.flutter.dev/perf
