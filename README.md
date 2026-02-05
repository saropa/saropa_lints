![saropa_lints banner](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/banner_v2.png)

# Saropa Lints

Catch memory leaks, security vulnerabilities, and runtime crashes that standard linters miss. Developed by [Saropa][saropa_link] to make the world of Dart & Flutter better, one fix at a time.

[saropa_link]: https://saropa.com

<!-- CI/CD & Build Status -->
[![ci](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml/badge.svg)](https://github.com/saropa/saropa_lints/actions/workflows/ci.yml)

<!-- Pub.dev Metrics (Auto-updating) -->
[![pub package](https://img.shields.io/pub/v/saropa_lints.svg?logo=dart&label=pub)](https://pub.dev/packages/saropa_lints)
[![pub points](https://img.shields.io/pub/points/saropa_lints?logo=dart)](https://pub.dev/packages/saropa_lints/score)
<!-- NO LONGER AVAILABLE [![popularity](https://img.shields.io/pub/popularity/saropa_lints?logo=dart)](https://pub.dev/packages/saropa_lints/score) -->
[![likes](https://img.shields.io/pub/likes/saropa_lints?logo=dart&color=red)](https://pub.dev/packages/saropa_lints/score)

<!-- GitHub Activity -->
[![GitHub stars](https://img.shields.io/github/stars/saropa/saropa_lints?style=social)](https://github.com/saropa/saropa_lints)
[![GitHub forks](https://img.shields.io/github/forks/saropa/saropa_lints?style=social)](https://github.com/saropa/saropa_lints)
[![GitHub last commit](https://img.shields.io/github/last-commit/saropa/saropa_lints)](https://github.com/saropa/saropa_lints/commits)
[![GitHub issues](https://img.shields.io/github/issues/saropa/saropa_lints)](https://github.com/saropa/saropa_lints/issues)

<!-- Technical Info -->
[![Dart SDK Version](https://badgen.net/pub/sdk-version/saropa_lints)](https://pub.dev/packages/saropa_lints)
[![Flutter Platform](https://img.shields.io/badge/platform-flutter-ff69b4.svg?logo=flutter)](https://flutter.dev/)

<!-- Custom Badges -->
[![rules](https://img.shields.io/badge/rules-1700%2B-4B0082)](https://github.com/saropa/saropa_lints/blob/main/doc/rules/README.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![style: saropa lints](https://img.shields.io/badge/style-saropa__lints-4B0082.svg)](https://pub.dev/packages/saropa_lints)

> 💬 **Have feedback on Saropa Lints?** Share it by [opening an issue](https://github.com/saropa/saropa_lints/issues/new) on GitHub!

---

## Why Saropa Lints?

### Linting vs static analysis

`flutter analyze` checks syntax and style. Static analysis checks _behavior_.

Your linter catches unused variables and formatting issues. It doesn't catch undisposed controllers, hardcoded credentials, or `setState` after `dispose` — because these require understanding what the code _does_, not just how it's written.

In mature ecosystems, tools like [SonarQube](https://www.sonarsource.com/products/sonarqube/), [Coverity](https://www.synopsys.com/software-integrity/security-testing/static-analysis-sast.html), and [Checkmarx](https://checkmarx.com/) fill this gap. Flutter hasn't had an equivalent — until now.

![Flutter memory leak detection in VS Code showing undisposed TextEditingController](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260502_problems_tab.png)

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

### Stop Debugging Known Issues
Saropa Lints specifically targets the error messages developers search for when their app crashes. It statically analyzes and prevents:

* **Memory Leaks:** `TextEditingController`, `AnimationController`, and `StreamSubscription` created but never disposed.
* **Concurrency Bugs:** `BuildContext` usage across async gaps and unawaited futures in `initState`.
* **Security Flaws:** Hardcoded API keys, insecure HTTP (cleartext), and weak cryptography.
* **UI Crashes:** `setState() called after dispose()`, layout overflow risks, and null assertions on backend data.
* **State Errors:** `Riverpod` providers reading inside `build` or `Bloc` events added in constructors.

### Essential for popular packages

If you use **GetX**, **Riverpod**, **Provider**, **Bloc**, **Isar**, **Hive**, or **Firebase**, these audits are critical. These libraries are powerful but have patterns that fail silently at runtime:

| Library      | Common issues caught                                                                             | Guide                                                    |
| ------------ | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------- |
| **GetX**     | Undisposed controllers, memory leaks from workers, missing super calls                           | [Using with GetX](doc/guides/using_with_getx.md)         |
| **Riverpod** | Circular provider deps, ref.read() in build, missing ProviderScope                               | [Using with Riverpod](doc/guides/using_with_riverpod.md) |
| **Provider** | Provider.of in build causing rebuilds, recreated providers losing state                          | [Using with Provider](doc/guides/using_with_provider.md) |
| **Bloc**     | Events in constructor, mutable state, unclosed Blocs, BlocListener in build                      | [Using with Bloc](doc/guides/using_with_bloc.md)         |
| **Isar**     | Enum fields causing data corruption on schema changes; caching Isar streams (runtime crash risk) | [Using with Isar](doc/guides/using_with_isar.md)         |
| **Hive**     | Missing init, unclosed boxes, hardcoded encryption keys, type adapter issues                     | [Using with Hive](doc/guides/using_with_hive.md)         |
| **Firebase** | Unbounded queries, missing batch writes, invalid Analytics events, FCM token leaks               | [Using with Firebase](doc/guides/using_with_firebase.md) |


![Screenshot of analysis_options_custom.yaml](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260502_analysis_options_custom_yaml.png)


Standard linters don't understand these libraries. They see valid Dart code. Saropa Lints has 50+ rules specifically for library-specific anti-patterns that cause crashes, memory leaks, cost overruns, and data corruption in production. Recent update: `require_camera_permission_check` no longer triggers on non-camera controllers (e.g., IsarStreamController), eliminating a key false positive for Isar users. The new `avoid_cached_isar_stream` rule (with quick fix) prevents a common Isar runtime error.

### Legend: Roadmap Markers

| Marker | Meaning | Example |
|--------|---------|---------|
| 🐙 | Tracked as GitHub issue | [#0000](https://github.com/saropa/saropa_lints/issues/0000) |
| 💡 | Planned enhancement tracked as GitHub Discussion | [Discussion: Diagnostic Statistics](https://github.com/saropa/saropa_lints/discussions/000) |

### Compliance: EAA & OWASP Security

The [European Accessibility Act](https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en) takes effect June 2025, requiring accessible apps in retail, banking, and travel. GitHub detected [39 million leaked secrets](https://github.blog/security/application-security/next-evolution-github-advanced-security/) in repositories during 2024.

These aren't edge cases. They're compliance requirements and security basics that standard linters miss.

### Comparison vs Standard Tools

Why switch? Saropa Lints covers everything in standard tools plus strict behavioral analysis.

| Feature | `flutter_lints` | `very_good_analysis` | **Saropa Lints** |
| :--- | :---: | :---: | :---: |
| **Syntax Checks** | ✅ | ✅ | ✅ |
| **Style Enforcement** | ❌ | ✅ | ✅ |
| **Memory Leak Detection** | ❌ | ❌ | **✅ (Deep Analysis)** |
| **Runtime Crash Prevention** | ❌ | ❌ | **✅ (Behavioral)** |
| **Security (OWASP)** | ❌ | ❌ | **✅ (Mapped)** |
| **Library Specific (Riverpod/Bloc)**| ❌ | ❌ | **✅ (50+ rules)** |
| **AI-Ready Diagnostics** | ❌ | ❌ | **✅** |

### OWASP Compliance Mapping

Security rules are mapped to **OWASP Mobile Top 10 (2024)** and **OWASP Top 10 (2021)** standards. This enables:

- **Compliance reporting** for security audits
- **Risk categorization** aligned with industry standards
- **Coverage analysis** across OWASP categories

| OWASP Mobile          | Coverage | OWASP Web                  | Coverage  |
| --------------------- | -------- | -------------------------- | --------- |
| M1 Credential Usage   | 5+ rules | A01 Broken Access Control  | 4+ rules  |
| M2 Supply Chain       | 2+ rules | A02 Cryptographic Failures | 10+ rules |
| M3 Authentication     | 5+ rules | A03 Injection              | 6+ rules  |
| M4 Input Validation   | 6+ rules | A05 Misconfiguration       | 4+ rules  |
| M5 Communication      | 2+ rules | A07 Authentication         | 8+ rules  |
| M6 Privacy Controls   | 5+ rules | A09 Logging Failures       | 2+ rules  |
| M7 Binary Protections | 2+ rules |                            |           |
| M8 Misconfiguration   | 4+ rules |                            |           |
| M9 Data Storage       | 7+ rules |                            |           |
| M10 Cryptography      | 4+ rules |                            |           |

**Gaps**: A06 (Outdated Components) requires dependency scanning tooling.

Rules expose their OWASP mapping programmatically:

```dart
// Query a rule's OWASP categories
final rule = AvoidHardcodedCredentialsRule();
print(rule.owasp); // Mobile: M1 | Web: A07
```

### Free and open

Good options exist, but many are paid or closed-source. We believe these fundamentals should be free and open. A rising tide lifts all boats.

The tier system lets you adopt gradually — start with ~100 critical rules, work up to 1700+ when you're ready.

---

### Built for AI
AI coding assistants like Cursor, Windsurf, and Copilot move fast, but they often hallucinate code that compiles yet fails in production. They might forget to dispose a controller, use a deprecated API, or ignore security best practices.

Saropa Lints acts as the guardrails for your AI. By providing immediate, semantic feedback on **behavior**—not just syntax—it forces the AI to correct its own mistakes in real-time.

**Optimized for AI Repair**
The tool is also built to **fix**. Saropa Lints diagnostics are engineered to be "paste-ready," providing deep context and specific failure points. When you copy a problem report directly into your AI tool window, it acts as a perfect prompt—giving the AI exactly the info it needs to refactor the code and resolve the issue immediately, without you needing to explain the context.

![AI fixing Flutter security vulnerability automatically in Android Studio](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260502_AI_solver_tab.png)

---
## Quick Start

### 1. Add dependencies

```yaml
# pubspec.yaml
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^4.6.0
```

### 2. Enable custom_lint

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - custom_lint
```

### 3. Generate tier configuration

```bash
dart run saropa_lints:init --tier comprehensive
```

This generates `analysis_options.yaml` with explicit `true`/`false` for every rule.

Available tiers: `essential` (1), `recommended` (2), `professional` (3), `comprehensive` (4), `insanity` (5)

> **Why a CLI tool?** The `custom_lint` plugin doesn't reliably pass configuration like `tier: recommended` to plugins. The CLI tool bypasses this limitation by generating explicit rule lists that work 100% of the time.

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

Pick the tier that matches your team's needs. Each tier builds on the previous one.

| Tier              | Purpose                                                                                                                                                                                                                                                 | Target User                                                                   | Example Rules                                                                                                                                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Essential**     | **Prevents crashes, data loss, security breaches, and memory leaks.** These are rules where a single violation can cause real harm - app crashes, user data exposed, resources never released. If your app violates these, something bad _will_ happen. | Every project, every team. Non-negotiable baseline.                           | `require_field_dispose` (memory leak), `avoid_hardcoded_credentials` (security breach), `check_mounted_after_async` (crash), `avoid_null_assertion` (runtime exception), `require_firebase_init_before_use` (crash)    |
| **Recommended**   | **Catches common bugs, basic performance issues, and accessibility fundamentals.** These are mistakes that cause real problems but may not immediately crash your app - poor UX, sluggish performance, inaccessible interfaces, silent failures.        | Most teams. The sensible default for production apps.                         | `require_semantics_label` (accessibility), `avoid_expensive_build` (performance), `require_json_decode_try_catch` (error handling), `avoid_shrinkwrap_in_scrollview` (performance), `require_image_error_builder` (UX) |
| **Professional**  | **Enforces architecture, testability, maintainability, and documentation standards.** Code that works but is hard to test, hard to change, or hard to understand. Technical debt that slows teams down over time.                                       | Enterprise teams, long-lived codebases, teams with multiple developers.       | `avoid_god_class` (architecture), `require_public_api_documentation` (docs), `prefer_result_pattern` (error handling), `require_test_cleanup` (testing), `avoid_hardcoded_strings_in_ui` (i18n)                        |
| **Comprehensive** | **Stricter patterns, optimization hints, and thorough edge case coverage.** Rules that catch subtle issues, enforce consistency, and push toward optimal patterns. Helpful but not critical.                                                            | Quality-obsessed teams, libraries/packages, teams that want maximum coverage. | `prefer_element_rebuild` (subtle perf), `prefer_immutable_bloc_state` (strict pattern), `require_test_documentation` (maintainability), `prefer_fake_platform` (test quality)                                          |
| **Insanity**      | **Everything, including pedantic and highly opinionated rules.** Rules that most teams would find excessive but are valuable for greenfield projects or teams that want zero compromise.                                                                | New projects starting fresh, teams that want maximum strictness from day one. | `prefer_custom_single_child_layout` (micro-optimization), `prefer_feature_folder_structure` (opinionated architecture), `avoid_returning_widgets` (pedantic)                                                           |

### Stylistic Rules (Separate Track)

**[175+ stylistic rules](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for formatting, ordering, and naming conventions.

To include stylistic rules when generating configuration:

```bash
dart run saropa_lints:init --tier comprehensive --stylistic
```

Or enable specific stylistic rules in your generated config by changing `false` to `true`.

Conflicting pairs (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) must be enabled individually - you choose which style your team prefers.

Stylistic rules are orthogonal to correctness. Your code can be perfectly correct while violating every stylistic rule, or perfectly formatted while crashing on every screen. That's why they're separate.

### Configuration template

See [example/analysis_options_template.yaml](https://github.com/saropa/saropa_lints/blob/main/example/analysis_options_template.yaml) for a complete reference with all 1700+ rules organized by category, tier membership, and examples.

### Using a tier

Generate configuration for your chosen tier:

```bash
# Most teams start here
dart run saropa_lints:init --tier recommended

# See all options
dart run saropa_lints:init --help

# Preview without writing
dart run saropa_lints:init --tier professional --dry-run
```

Available tiers: `essential` (1), `recommended` (2), `professional` (3), `comprehensive` (4), `insanity` (5)

Add `--stylistic` to include opinionated formatting rules.

### Customizing rules

After generating configuration, customize rules by editing `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    # The init tool generates explicit true/false for every rule
    - avoid_hardcoded_strings_in_ui: true  # change to false to disable
    - require_public_api_documentation: false  # change to true to enable

    # Stylistic rules (enable the ones your team prefers)
    - prefer_single_quotes: true
    - prefer_trailing_comma_always: true
```

**IMPORTANT:** Rules must use YAML list format (with `-` prefix):

```yaml
# ✅ Correct (list format)
rules:
  - avoid_hardcoded_strings_in_ui: false

# ❌ Wrong (map format - rules will be silently ignored)
rules:
  avoid_hardcoded_strings_in_ui: false  # NO DASH = NOT PARSED!
```

To change tiers, re-run the init tool:

```bash
dart run saropa_lints:init --tier professional
```

### Platform configuration

The `analysis_options_custom.yaml` file includes a `platforms` section that controls which platform-specific rules are active. Only iOS and Android are enabled by default. Enable the platforms your project targets:

```yaml
# In analysis_options_custom.yaml
platforms:
  ios: true         # enabled by default
  android: true     # enabled by default
  macos: false      # enable if targeting macOS
  web: false        # enable if targeting web
  windows: false    # enable if targeting Windows
  linux: false      # enable if targeting Linux
```

Each platform has dedicated rules that catch platform-specific issues:

| Platform | Rules | Examples |
|----------|-------|---------|
| **iOS** | 90+ | Safe area, privacy manifest, App Tracking Transparency, Face ID, HealthKit, keychain |
| **Android** | 11+ | Runtime permissions, notification channels, PendingIntent flags, cleartext traffic |
| **macOS** | 15+ | Sandboxing, notarization, hardened runtime, window restoration, entitlements |
| **Web** | 10+ | CORS handling, platform channels, deferred loading, URL strategy, web renderer |
| **Windows** | Desktop shared | Menu bar, window close confirmation, native file dialogs, focus indicators |
| **Linux** | Desktop shared | Same desktop rules as Windows |

Some rules are shared across platform groups:

- **Apple rules** (iOS + macOS): Apple Sign In, nonce validation
- **Desktop rules** (macOS + Windows + Linux): Menu bar, window management, keyboard/mouse interaction patterns

When a platform is set to `false`, its rules move to the disabled section. Shared rules (e.g., Apple Sign In for iOS + macOS) are only disabled when **all** their platforms are disabled.

**User overrides always win** — if you force-enable a rule in the overrides section, it stays enabled even if its platform is disabled.

The `init` tool logs which platforms are disabled and how many rules are affected:

```
Platforms disabled: web, windows, linux (23 rules affected)
```

### Package configuration

The `analysis_options_custom.yaml` file includes a `packages` section that controls which library-specific rules are active. All packages are enabled by default. Disable packages you don't use to reduce noise:

```yaml
# In analysis_options_custom.yaml
packages:
  # State Management
  bloc: true
  provider: true
  riverpod: true
  getx: true

  # UI & Utilities
  flutter_hooks: true

  # Data Classes
  equatable: true
  freezed: true

  # Storage & Database
  firebase: true
  isar: true
  hive: true
  shared_preferences: true
  sqflite: true

  # Networking
  dio: true
  graphql: true
  supabase: true

  # DI & Services
  get_it: true
  workmanager: true

  # Device & UI
  url_launcher: true
  geolocator: true
  qr_scanner: true

  # Gaming
  flame: true
```

Setting a package to `false` moves all its rules to the disabled section. If you don't use Riverpod, for example, set `riverpod: false` to remove 24+ Riverpod-specific rules from your analysis.

Rules shared between packages (e.g., database rules shared by Firebase, Isar, Hive, and sqflite) are only disabled when **all** packages that use them are disabled.

After changing platform or package settings, re-run init to apply:

```bash
dart run saropa_lints:init
```

### Config key names and aliases

Rule config keys match the rule name shown in lint messages (the part in `[brackets]`):

```
lib/my_file.dart:42 - [prefer_arguments_ordering] Named arguments should be in alphabetical order.
                       ^^^^^^^^^^^^^^^^^^^^^^^^^ This is the config key
```

To disable this rule: `- prefer_arguments_ordering: false`

**Aliases**: Some rules support shorter aliases for convenience. For example, `prefer_arguments_ordering` also accepts `arguments_ordering`:

```yaml
rules:
  # Both of these work:
  - prefer_arguments_ordering: false  # canonical name
  - arguments_ordering: false          # alias
```

Aliases are provided for rules where the prefix (`enforce_`, `require_`) might be commonly omitted.

### enable_all_lint_rules

The `enable_all_lint_rules: true` setting enables ALL rules, including opinionated stylistic rules:

```yaml
custom_lint:
  enable_all_lint_rules: true
```

**This is intentional.** It forces teams to explicitly review and disable rules they disagree with, ensuring:

- No rule is accidentally overlooked
- Your `custom_lint.yaml` becomes a complete record of team style decisions
- Mutually exclusive rules (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) require explicit choice

If you enable all rules, you will need to disable one rule from each conflicting pair.

### Severity levels

Each rule has a fixed severity (ERROR, WARNING, or INFO) defined in the rule itself. Severity cannot be overridden per-project. If a rule's severity doesn't match your needs:

- Use `// ignore: rule_name` to suppress individual occurrences
- Disable the rule entirely with `- rule_name: false`
- [Open an issue](https://github.com/saropa/saropa_lints/issues) if you think the default severity should change

### Baseline for Brownfield Projects

#### The Problem

You want to adopt saropa_lints on an existing project. You run `dart run custom_lint` and see:

```
lib/old_widget.dart:42 - avoid_print
lib/old_widget.dart:87 - no_empty_block
lib/legacy/api.dart:15 - avoid_dynamic
... 500 more violations
```

**That's overwhelming.** You can't fix 500 issues before your next sprint. But you also can't ignore linting entirely - new code should be clean.

#### The Solution: Baseline

The **baseline feature** records all existing violations and hides them, while still catching violations in new code.

- **Old code**: Violations hidden (baselined)
- **New code**: Violations reported normally

This lets you adopt linting **today** without fixing legacy code first.

#### Quick Start (One Command)

```bash
dart run saropa_lints:baseline
```

This command:

1. Runs analysis to find all current violations
2. Creates `saropa_baseline.json` with those violations
3. Updates your `analysis_options.yaml` automatically

**Result**: Old violations are hidden, new code is still checked.

#### Three Combinable Baseline Types

| Type           | Config          | Description                      | Best For               |
| -------------- | --------------- | -------------------------------- | ---------------------- |
| **File-based** | `baseline.file` | JSON listing specific violations | "Fix nothing yet"      |
| **Date-based** | `baseline.date` | Git blame - ignore old code      | "Fix gradually by age" |

All three types are combinable - any match suppresses the violation.

#### Full Configuration

> **Note:** Baseline configuration via YAML is not yet supported. Use the
> `dart run saropa_lints:baseline` CLI command shown above, which generates
> the baseline file and updates your config automatically.

The baseline CLI supports these options:

| Option | Description |
| ------ | ----------- |
| `--file` | Output file (default: `saropa_baseline.json`) |
| `--date` | Ignore code unchanged since this date (uses git blame) |
| `--paths` | Ignore entire directories (glob patterns) |
| `--only-impacts` | Only baseline certain severities (e.g., `low,medium`) |

#### Path Pattern Examples

| Pattern             | Matches                              |
| ------------------- | ------------------------------------ |
| `lib/legacy/`       | All files under `lib/legacy/`        |
| `*.g.dart`          | All files ending in `.g.dart`        |
| `lib/**/old_*.dart` | Files like `lib/foo/old_widget.dart` |

#### Priority Filtering

Use `only_impacts` to baseline only certain severity levels while still seeing critical issues:

```yaml
baseline:
  file: "saropa_baseline.json"
  only_impacts: [low, medium, opinionated] # Still see critical and high
```

#### Cleaning Up Over Time

As you fix violations, update the baseline to remove fixed items:

```bash
dart run saropa_lints:baseline --update
```

Output shows what was fixed:

```
Baseline Update Summary:
  Previous: 150 violations
  Current:  120 violations
  Fixed:    30 violations removed!
```

#### CLI Reference

```bash
dart run saropa_lints:baseline              # Generate new baseline
dart run saropa_lints:baseline --update     # Refresh, remove fixed violations
dart run saropa_lints:baseline --dry-run    # Preview without changes
dart run saropa_lints:baseline --skip-config # Don't update analysis_options.yaml
dart run saropa_lints:baseline -o custom.json # Custom output path
dart run saropa_lints:baseline ./my_project  # Run on specific directory
dart run saropa_lints:baseline --help        # See all options
```

## Rule Categories

| Category                 | Description                                                                           |
| ------------------------ | ------------------------------------------------------------------------------------- |
| **Flutter Widgets**      | Lifecycle, setState, keys, performance                                                |
| **Modern Dart 3.0+**     | Class modifiers, patterns, records, when guards                                       |
| **Modern Flutter**       | TapRegion, OverlayPortal, SearchAnchor, CarouselView                                  |
| **State Management**     | Provider, Riverpod, Bloc patterns                                                     |
| **Performance**          | Build optimization, memory, caching                                                   |
| **Security**             | Credentials, encryption, input validation — [OWASP mapped](#owasp-compliance-mapping) |
| **Accessibility**        | Screen readers, touch targets, semantics                                              |
| **Testing**              | Assertions, mocking, flaky test prevention                                            |
| **Architecture**         | Clean architecture, DI, SOLID principles                                              |
| **Error Handling**       | Exceptions, logging, recovery                                                         |
| **Async**                | Futures, Streams, cancellation                                                        |
| **API & Network**        | Timeouts, retries, caching                                                            |
| **Internationalization** | Localization, RTL, plurals                                                            |
| **Documentation**        | Public API, examples, deprecation                                                     |

## Stylistic Rules

175+ rules for team preferences — not included in any correctness tier. Enable individually or via `--stylistic` flag based on your conventions.

Examples: `prefer_relative_imports`, `prefer_single_quotes`, `prefer_arrow_functions`, `prefer_trailing_comma_always`, `prefer_for_in`, `prefer_boolean_prefixes_for_params`

**See [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for the full list with examples, pros/cons, and quick fixes.

## Performance

Running all 1700+ rules uses significant memory. The tier system helps:

- Rules set to `false` are not loaded
- Start with `essential` or `recommended`
- Upgrade tiers as you fix warnings

```bash
# GOOD: Start with recommended tier
dart run saropa_lints:init --tier recommended

# CAUTION: Enabling everything on a legacy codebase may show thousands of warnings
dart run saropa_lints:init --tier insanity
```

### Performance Tip: Use Lower Tiers During Development

**custom_lint is notoriously slow** with large rule sets. For faster iteration during development:

1. **Use `essential` tier locally** (~400 rules) - catches critical bugs, runs 3-5x faster
2. **Use `professional` or higher in CI** - thorough checking where speed matters less
3. **Upgrade tiers gradually** - fix warnings before enabling more rules

```bash
# Fast local development (~400 rules)
dart run saropa_lints:init --tier essential

# Thorough CI checking (~1400 rules)
dart run saropa_lints:init --tier professional
```

The tier you choose has a direct impact on analysis speed:

- `essential`: ~250 rules → **fastest** (memory leaks, security, crashes)
- `recommended`: ~800 rules → moderate (+ accessibility, performance)
- `professional`: ~1400 rules → slower (+ architecture, documentation)
- `comprehensive`/`insanity`: 1520+ rules → **slowest** (everything)

## Adoption Strategy

Static analysis doesn't create problems — it reveals ones that already exist. The tiered system lets you start at any level and progress at your own pace. Findings are for your workflow. You control what you address and when.

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

| File Pattern                                  | Skipped By Default                    |
| --------------------------------------------- | ------------------------------------- |
| `*.g.dart`, `*.freezed.dart`, `*.gen.dart`    | Yes (generated code)                  |
| `*_fixture.dart`, `fixture/**`, `fixtures/**` | Yes (test fixtures)                   |
| `*_test.dart`, `test/**`                      | Yes (override with `testRelevance`)   |
| `example/**`                                  | No (override with `skipExampleFiles`) |

Test files are skipped by default because most production-focused rules generate noise in test code. Override `testRelevance` to change behavior per rule:

- `TestRelevance.never` — skip test files (default)
- `TestRelevance.always` — run on all files including tests
- `TestRelevance.testOnly` — run only on test files

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
python scripts/modules/_install_vscode_extension.py
```

Then restart VS Code.

**What you get:**

- A **"Lints"** button in the status bar (bottom of VS Code)
- A search icon in the editor title bar when viewing Dart files
- Both trigger `dart run custom_lint` and open the Problems panel

## Troubleshooting

### I'm new and completely lost

**Start here:**

1. **Install**: Add to your `pubspec.yaml` dev_dependencies:
   ```yaml
   dev_dependencies:
     custom_lint: ^0.8.0
     saropa_lints: ^4.2.3
   ```

2. **Configure**: Add to your `analysis_options.yaml`:
   ```yaml
   analyzer:
     plugins:
       - custom_lint

   custom_lint:
     enable_all_lint_rules: true  # Start with all rules
   ```

3. **Reload VS Code**:
   - Press `Ctrl+Shift+P`
   - Type "reload"
   - Click "Developer: Reload Window"

4. **Wait**: Give it 1-2 minutes to analyze your code

5. **Check**: Look at the PROBLEMS panel (View → Problems)

**Still not working?** See the sections below.

### IDE doesn't show lint warnings

**Quick Fix (works 90% of the time):**

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "reload"
3. Click "Developer: Reload Window"
4. Wait 1 minute for analysis to complete

**If that doesn't work:**

1. Clear the cache: Delete the `.dart_tool/custom_lint` folder in your project
2. Reload VS Code again (steps above)
3. Check **View → Output → Dart Analysis Server** for errors
4. Verify configuration is correct (see "Configuration not working" below)

**Alternative (command line):**

Run `dart run custom_lint` in your terminal to see all issues immediately.

### Configuration not working (not enough rules loading)

**Problem:** You only get ~200 rules instead of the full set for your chosen tier.

**Cause:** The `custom_lint` plugin does not support plugin-level configuration keys. YAML-based tier selection (e.g., `saropa_lints: tier: recommended`) does not work.

**Solution:** Use the CLI tool to generate explicit configuration:

```bash
# Generate config for comprehensive tier (1618 rules)
dart run saropa_lints:init --tier comprehensive

# Or for all rules (insanity tier)
dart run saropa_lints:init --tier insanity
```

This generates `analysis_options.yaml` with explicit `- rule_name: true` for every enabled rule, which works 100% of the time.

**Verify it worked:** Run `dart run custom_lint` and check the rule count in the output.

### Too many warnings! What do I do?

**This is normal** when first installing. You'll see hundreds or thousands of warnings.

**Option 1: Start smaller** (recommended for existing projects)

```bash
# Start with essential tier (~400 critical rules)
dart run saropa_lints:init --tier essential
```

**Option 2: Use baseline** (for brownfield projects)

Generate a baseline to suppress existing issues and only catch new violations:

```bash
dart run saropa_lints:baseline
```

**Option 3: Disable noisy rules**

Edit your generated `analysis_options.yaml` and change specific rules from `true` to `false`:

```yaml
rules:
    - prefer_double_quotes: false  # disabled
    - prefer_trailing_comma_always: false
    - no_magic_number: false
```

**Option 4: Use quick fixes**

Many rules have automatic fixes:
- Hover over the warning
- Click "Quick Fix" or press `Ctrl+.`
- Select "Fix all in file" to fix all instances at once

**Don't stress about fixing everything immediately.** Pick one category (like accessibility or memory leaks) and fix those first.

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

## Frequently Asked Questions

**Q: Does this replace `flutter_lints`?**
A: You can run them side-by-side, but Saropa Lints covers everything in `flutter_lints` plus 1600+ additional behavioral and security checks. Most teams replace `flutter_lints` entirely.

**Q: Will this slow down my CI/CD pipeline?**
A: Saropa Lints is optimized for performance. While it runs deeper checks than standard linters, the **Tier System** allows you to balance speed and strictness. The `essential` tier is designed to be lightning-fast for CI environments.

**Q: Can I use this with existing legacy projects?**
A: Yes! Use the **Baseline** feature (`dart run saropa_lints:baseline`) to suppress existing issues instantly. This lets you enforce quality on *new* code without having to fix 500+ legacy errors first.

## Contributing

We believe great tools are built by communities, not companies. Contributions and feedback are always welcome.

If you think a rule is:

- **Wrong** - tell us why, we'll fix it or remove it
- **Too strict** - maybe it belongs in a higher tier
- **Too lenient** - maybe it should be stricter or have options
- **Missing** - propose it, or better yet, implement it

We don't have all the answers. If you've shipped production Flutter apps and have opinions, we want to hear from you.

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

Optional paid services for teams that want hands-on help. See [PROFESSIONAL_SERVICES.md](https://github.com/saropa/saropa_lints/blob/main/PROFESSIONAL_SERVICES.md) for details.

| Service          | Description                                                       |
| ---------------- | ----------------------------------------------------------------- |
| **New Projects** | Development scoped to your stage — MVP, Production, or Enterprise |
| **Upgrade**      | Move existing projects to higher tiers as they grow               |
| **Audit**        | Assess codebases you inherited; remediation quoted separately     |
| **Custom Rules** | Rules specific to your architecture and compliance requirements   |

Contact: [saropa.com](https://saropa.com) | [services@saropa.com](mailto:services@saropa.com)

## Documentation

| Document                                                                                              | Description                                   |
| ----------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)           | 175+ optional stylistic rules with examples   |
| [PERFORMANCE.md](https://github.com/saropa/saropa_lints/blob/main/PERFORMANCE.md)                     | Performance optimization guide and profiling  |
| [ROADMAP.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP.md)                             | Planned rules and project direction           |
| [ROADMAP_DEFERRED.md](https://github.com/saropa/saropa_lints/blob/main/ROADMAP_DEFERRED.md)           | Deferred rules (cross-file, heuristic)        |
| [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md)                   | How to contribute rules and report issues     |
| [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)                         | Version history and release notes             |
| [SECURITY.md](https://github.com/saropa/saropa_lints/blob/main/SECURITY.md)                           | Security policy and reporting vulnerabilities |
| [PROFESSIONAL_SERVICES.md](https://github.com/saropa/saropa_lints/blob/main/PROFESSIONAL_SERVICES.md) | Professional services and custom rules        |

### Package Integration Guides

We provide specialized lint rules for popular Flutter packages. These catch library-specific anti-patterns that standard linters miss.

| Category             | Package   | Guide                                                                                                       |
| -------------------- | --------- | ----------------------------------------------------------------------------------------------------------- |
| **State Management** | Riverpod  | [Using with Riverpod](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_riverpod.md)   |
|                      | Bloc      | [Using with Bloc](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_bloc.md)           |
|                      | Provider  | [Using with Provider](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_provider.md)   |
|                      | GetX      | [Using with GetX](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_getx.md)           |
| **Databases**        | Isar      | [Using with Isar](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_isar.md)           |
|                      | Hive      | [Using with Hive](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_hive.md)           |
| **Backend Services** | Firebase  | [Using with Firebase](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_firebase.md)   |
| **Platform**         | iOS/macOS | [Apple Platform Rules](https://github.com/saropa/saropa_lints/blob/main/doc/guides/apple_platform_rules.md) |

#### For Package Authors

**Want lint rules for your package?** We'd love to collaborate with package maintainers to add rules that catch common gotchas and enforce best practices for your library.

Benefits:

- Help users avoid common mistakes with your package
- Reduce support burden from preventable issues
- Improve developer experience with your library

Contact us via [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) or open an issue to discuss adding rules for your package.

## Badge

**Show off your code quality**

Prove that your code is secure, memory-safe, and accessible. Add the Saropa Lints style badge to your README to indicate you follow strict behavioral standards.

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

**saropa_lints** is a comprehensive static analysis package for Flutter and Dart applications. With 1700+ lint rules organized into 5 progressive tiers (and more planned), it catches memory leaks, security vulnerabilities, accessibility violations, and runtime crashes that standard linters miss. Whether you're building a startup MVP or enterprise software, saropa_lints helps you ship more stable, secure, and accessible apps.

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
