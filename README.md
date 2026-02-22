
![Saropa Lints - Advanced Static Analysis](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/banner_v2.png)

<!-- # Saropa Lints -->

**Catch memory leaks, security vulnerabilities, and runtime crashes that standard linters miss.**
<br>
Developed by [Saropa](https://saropa.com) to make the world of Dart & Flutter better.

<!-- ref: https://shields.io/badges and https://simpleicons.org/?q=flutter -->
<br>
<div align="center">

<!-- Note that the badges are all grouped together so they flow horizontally. -->

[![pub package](https://img.shields.io/pub/v/saropa_lints.svg?style=flat-square&logo=dart&color=blue)](https://pub.dev/packages/saropa_lints) [![pub points](https://img.shields.io/pub/points/saropa_lints?style=flat-square&logo=dart)](https://pub.dev/packages/saropa_lints/score) [![likes](https://img.shields.io/pub/likes/saropa_lints?style=flat-square&logo=dart&color=red)](https://pub.dev/packages/saropa_lints/score) [![ci](https://img.shields.io/github/actions/workflow/status/saropa/saropa_lints/ci.yml?branch=main&style=flat-square&logo=github&label=build)](https://github.com/saropa/saropa_lints/actions) [![GitHub stars](https://img.shields.io/github/stars/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints) [![GitHub forks](https://img.shields.io/github/forks/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints) [![GitHub issues](https://img.shields.io/github/issues/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints/issues) [![GitHub last commit](https://img.shields.io/github/last-commit/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints/commits) 

[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-1700%2B-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints) [![Flutter Platform](https://img.shields.io/badge/platform-flutter-02569B.svg?style=flat-square&logo=flutter)](https://flutter.dev/) [![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg?style=flat-square)](https://opensource.org/licenses/MIT)


[![Share on X](https://img.shields.io/badge/share%20on-X-000000?style=flat-square&logo=x&logoColor=white)](https://twitter.com/intent/tweet?text=Check%20out%20Saropa%20Lints%3A%20Catch%20memory%20leaks%2C%20security%20vulnerabilities%2C%20and%20runtime%20crashes%20in%20Flutter%21&url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Facebook](https://img.shields.io/badge/share%20on-facebook-1877F2?style=flat-square&logo=facebook&logoColor=white)](https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Bluesky](https://img.shields.io/badge/share%20on-bluesky-0285FF?style=flat-square&logo=bluesky&logoColor=white)](https://bsky.app/intent/compose?text=Check%20out%20Saropa%20Lints%3A%20Catch%20memory%20leaks%2C%20security%20vulnerabilities%2C%20and%20runtime%20crashes%20in%20Flutter%21%20https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on LinkedIn](https://img.shields.io/badge/share%20on-linkedin-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Reddit](https://img.shields.io/badge/share%20on-reddit-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/submit?url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints&title=Saropa%20Lints%20-%20Advanced%20Static%20Analysis)

</div>
<br>

> 💬 **Have feedback on Saropa Lints?** Please share it by [opening an issue](https://github.com/saropa/saropa_lints/issues/new) on GitHub!

---

## Quick Start

### Option A — Zero-config (tier preset)

```bash
dart pub add --dev saropa_lints
```

Add one line to your `analysis_options.yaml`:

```yaml
include: package:saropa_lints/tiers/recommended.yaml
```

That's it. Run `dart analyze` and issues appear in your IDE and terminal.

Available presets: `essential.yaml` · `recommended.yaml` · `professional.yaml` · `comprehensive.yaml` · `pedantic.yaml`

### Option B — Full control (init tool)

```bash
dart pub add --dev saropa_lints

# Generate explicit rule configuration (pick your tier)
dart run saropa_lints:init --tier recommended
```

This updates (or creates) two files:
- **`analysis_options.yaml`** — the `plugins: saropa_lints: diagnostics:` section is regenerated with every rule set to `true`/`false` for your tier. All other sections (`analyzer:`, `linter:`, etc.) are preserved. Your manual rule overrides are kept.
- **`analysis_options_custom.yaml`** — your project settings. Created on first run; never overwritten. Missing sections are added automatically on subsequent runs.

### Review your settings

Open `analysis_options_custom.yaml` and adjust for your project:

```yaml
# Enable only the platforms you target
platforms:
  ios: true
  android: true
  web: false         # set true if you target web
  macos: false
  windows: false
  linux: false

# Disable packages you don't use (all enabled by default)
packages:
  riverpod: true
  bloc: true
  firebase: true
  # ... see file for full list

# Analysis settings
max_issues: 500      # Max issues shown in Problems tab (0 = show all)
output: both         # "both" = Problems tab + report file
                     # "file" = report file only (nothing in Problems tab)
```

After changing settings, re-run init to apply: `dart run saropa_lints:init`

### Run analysis

```bash
dart analyze
```

Issues appear in your IDE's Problems panel and in the terminal. No extra commands needed — Saropa Lints runs as a native Dart analyzer plugin.

> **Available tiers:** `essential` · `recommended` · `professional` · `comprehensive` · `pedantic` — see [The 5 Tiers](#the-5-tiers) for details
>
> **Stuck?** See [Troubleshooting](#troubleshooting) · **Upgrading?** See [Migration guides](#migrating-from-other-tools)

---

## Why Saropa Lints?

### Linting vs static analysis

`dart analyze` checks syntax and style. Static analysis checks _behavior_.

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

### Radical Transparency

We build in public. We don't just show you what works; we explicitly document what *doesn't* work yet.

* [**ROADMAP.md**](ROADMAP.md): Our active backlog. See exactly what rules are coming next and vote on priorities.
* [**ROADMAP_DEFERRED.md**](ROADMAP_DEFERRED.md): The "Hard Problems." We document rules we *can't* implement yet due to technical limitations (like cross-file analysis). We invite the community to help us crack these barriers.

| Marker | Meaning | Example |
|--------|---------|---------|
| 🐙 | Tracked as GitHub issue | [Open Issues](https://github.com/saropa/saropa_lints/issues) |
| 💭 | Announcements, Q&A, and Ideas | [Discussion: Diagnostic Statistics](https://github.com/saropa/saropa_lints/discussions) |

![AI fixing Flutter security vulnerability automatically in Android Studio](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260502_build_report_terminal_tab.png)

### Compliance: EAA & OWASP Security

The [European Accessibility Act](https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en) takes effect June 2025, requiring accessible apps in retail, banking, and travel. GitHub detected [39 million leaked secrets](https://github.blog/security/application-security/next-evolution-github-advanced-security/) in repositories during 2024.

These aren't edge cases. They're compliance requirements and security basics that standard linters miss.

### Comparison vs Standard Tools

Why switch? Saropa Lints covers everything in standard tools plus strict behavioral analysis.

| Feature | `flutter_lints` | `very_good_analysis` | **Saropa Lints** |
| :--- | :---: | :---: | :--- |
| **Syntax Checks** | ✅ | ✅ | ✅ |
| **Strict/Opinionated Style** | ❌ | ✅ | ✅ |
| **Zero-Config Setup** | ✅ | ✅ | ✅ **(Tier Presets)** |
| **Controller Leak Detection** | ❌ | ❌ | ✅ **(Deep Analysis)** |
| **Runtime Crash Prevention** | ❌ | ❌ | ✅ **(Behavioral)** |
| **Security (OWASP Mapped)** | ❌ | ❌ | ✅ **(ISO/OWASP)** |
| **Library Specific (Riverpod/Bloc)**| ❌ | ❌ | ✅ **(50+ rules)** |
| **AI-Ready Diagnostics** | ❌ | ❌ | ✅ |
| **Dependency Scanning** | ❌ | ❌ | 🚧 **(Coming Soon)** |

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

### Open Source & Community Driven

Unlike "black box" paid tools, Saropa Lints is 100% open source (MIT). You can inspect the logic behind every rule, verify the security checks yourself, and fork it if you disagree.

* **No hidden logic:** See exactly how we detect vulnerabilities.
* **No vendor lock-in:** It's standard Dart code.
* **Community powered:** Rules are often suggested, debated, and refined by the Flutter community, not just a single vendor.

---

### Built for AI
AI coding assistants like Cursor, Windsurf, and Copilot move fast, but they often hallucinate code that compiles yet fails in production. They might forget to dispose a controller, use a deprecated API, or ignore security best practices.

Saropa Lints acts as the guardrails for your AI. By providing immediate, semantic feedback on **behavior**—not just syntax—it forces the AI to correct its own mistakes in real-time.

**Optimized for AI Repair**
The tool is also built to **fix**. Saropa Lints diagnostics are engineered to be "paste-ready," providing deep context and specific failure points. When you copy a problem report directly into your AI tool window, it acts as a perfect prompt—giving the AI exactly the info it needs to refactor the code and resolve the issue immediately, without you needing to explain the context.

![AI fixing Flutter security vulnerability automatically in Android Studio](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260502_AI_solver_tab.png)

---
### Migrating from other tools?

- [Migrating from very_good_analysis](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_vga.md) (also covers `lints`, `lint`, `pedantic`)
- [Migrating from DCM (Dart Code Metrics)](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_dcm.md)
- [Migrating from solid_lints](https://github.com/saropa/saropa_lints/blob/main/doc/guides/migration_from_solid_lints.md)
- [Using with flutter_lints](https://github.com/saropa/saropa_lints/blob/main/doc/guides/using_with_flutter_lints.md) (complementary setup)

> **Why two options?** The tier presets (Option A) are great for getting started fast. The init tool (Option B) gives you explicit `true`/`false` for every rule, making it easy to customize individual rules and see exactly what's enabled.

## The 5 Tiers

Pick the tier that matches your team's needs. Each tier builds on the previous one.

| Tier              | Purpose                                                                                                                                                                                                                                                 | Target User                                                                   | Example Rules                                                                                                                                                                                                          |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Essential**     | **Prevents crashes, data loss, security breaches, and memory leaks.** These are rules where a single violation can cause real harm - app crashes, user data exposed, resources never released. If your app violates these, something bad _will_ happen. | Every project, every team. Non-negotiable baseline.                           | `require_field_dispose` (memory leak), `avoid_hardcoded_credentials` (security breach), `check_mounted_after_async` (crash), `avoid_null_assertion` (runtime exception), `require_firebase_init_before_use` (crash)    |
| **Recommended**   | **Catches common bugs, basic performance issues, and accessibility fundamentals.** These are mistakes that cause real problems but may not immediately crash your app - poor UX, sluggish performance, inaccessible interfaces, silent failures.        | Most teams. The sensible default for production apps.                         | `require_semantics_label` (accessibility), `avoid_expensive_build` (performance), `require_json_decode_try_catch` (error handling), `avoid_shrinkwrap_in_scrollview` (performance), `require_image_error_builder` (UX) |
| **Professional**  | **Enforces architecture, testability, maintainability, and documentation standards.** Code that works but is hard to test, hard to change, or hard to understand. Technical debt that slows teams down over time.                                       | Enterprise teams, long-lived codebases, teams with multiple developers.       | `avoid_god_class` (architecture), `require_public_api_documentation` (docs), `prefer_result_pattern` (error handling), `require_test_cleanup` (testing), `avoid_hardcoded_strings_in_ui` (i18n)                        |
| **Comprehensive** | **Stricter patterns, optimization hints, and thorough edge case coverage.** Rules that catch subtle issues, enforce consistency, and push toward optimal patterns. Helpful but not critical.                                                            | Quality-obsessed teams, libraries/packages, teams that want maximum coverage. | `prefer_element_rebuild` (subtle perf), `prefer_immutable_bloc_state` (strict pattern), `require_test_documentation` (maintainability), `prefer_fake_platform` (test quality)                                          |
| **Pedantic**      | **Everything, including pedantic and highly opinionated rules.** Rules that most teams would find excessive but are valuable for greenfield projects or teams that want zero compromise.                                                                | New projects starting fresh, teams that want maximum strictness from day one. | `prefer_custom_single_child_layout` (micro-optimization), `prefer_feature_folder_structure` (opinionated architecture), `avoid_returning_widgets` (pedantic)                                                           |

### Stylistic Rules (Separate Track)

**[175+ stylistic rules](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for formatting, ordering, and naming conventions.

The init tool includes an **interactive walkthrough** that shows code examples and lets you enable/disable each rule:

```bash
# Interactive walkthrough (default — runs automatically)
dart run saropa_lints:init

# Bulk-enable all stylistic rules (CI / non-interactive)
dart run saropa_lints:init --stylistic-all

# Skip the walkthrough entirely
dart run saropa_lints:init --no-stylistic

# Re-review previously decided rules
dart run saropa_lints:init --reset-stylistic
```

Or enable specific stylistic rules in your generated config by changing `false` to `true`.

Conflicting pairs (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) must be enabled individually - you choose which style your team prefers.

Stylistic rules are orthogonal to correctness. Your code can be perfectly correct while violating every stylistic rule, or perfectly formatted while crashing on every screen. That's why they're separate.

### Configuration template

See [example/analysis_options_template.yaml](https://github.com/saropa/saropa_lints/blob/main/example/analysis_options_template.yaml) for a complete reference with all 1700+ rules organized by category, tier membership, and examples.

### Using a tier

**Option A — Tier preset (zero-config):**

```yaml
# In analysis_options.yaml — just pick your tier:
include: package:saropa_lints/tiers/recommended.yaml
```

**Option B — Init tool (full control):**

```bash
# Most teams start here
dart run saropa_lints:init --tier recommended

# See all options
dart run saropa_lints:init --help

# Preview without writing
dart run saropa_lints:init --tier professional --dry-run
```

Available tiers: `essential` (1), `recommended` (2), `professional` (3), `comprehensive` (4), `pedantic` (5)

The init tool includes an interactive stylistic rules walkthrough by default. Use `--stylistic-all` to bulk-enable, or `--no-stylistic` to skip.

### Customizing rules

After generating configuration, customize rules by editing `analysis_options.yaml`:

```yaml
plugins:
  saropa_lints:
    diagnostics:
      # The init tool generates explicit true/false for every rule
      avoid_hardcoded_strings_in_ui: true  # change to false to disable
      require_public_api_documentation: false  # change to true to enable

      # Stylistic rules (enable the ones your team prefers)
      prefer_single_quotes: true
      prefer_trailing_comma_always: true
```

Rules use standard YAML map format (no `-` prefix needed).

To change tiers, either switch the `include:` preset or re-run the init tool:

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

To disable this rule: `prefer_arguments_ordering: false`

**Aliases**: Some rules support shorter aliases for convenience. For example, `prefer_arguments_ordering` also accepts `arguments_ordering`:

```yaml
plugins:
  saropa_lints:
    diagnostics:
      # Both of these work:
      prefer_arguments_ordering: false  # canonical name
      arguments_ordering: false          # alias
```

Aliases are provided for rules where the prefix (`enforce_`, `require_`) might be commonly omitted.

### Enabling all rules

Use the `pedantic` tier preset or the init tool to enable all rules:

```yaml
# Option A: Tier preset
include: package:saropa_lints/tiers/pedantic.yaml

# Option B: Init tool
# dart run saropa_lints:init --tier pedantic --stylistic-all
```

**This is intentional.** It forces teams to explicitly review and disable rules they disagree with, ensuring:

- No rule is accidentally overlooked
- Your config becomes a complete record of team style decisions
- Mutually exclusive rules (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) require explicit choice

If you enable all rules, you will need to disable one rule from each conflicting pair.

### Severity levels

Each rule has a fixed severity (ERROR, WARNING, or INFO) defined in the rule itself. Severity cannot be overridden per-project. If a rule's severity doesn't match your needs:

- Use `// ignore: rule_name` to suppress individual occurrences
- Disable the rule entirely with `rule_name: false`
- [Open an issue](https://github.com/saropa/saropa_lints/issues) if you think the default severity should change

### Baseline for Brownfield Projects

#### The Problem

You want to adopt saropa_lints on an existing project. You run `dart analyze` and see:

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

175+ rules for team preferences — not included in any correctness tier. Enable individually, via the interactive walkthrough during `init`, or use `--stylistic-all` to bulk-enable.

Examples: `prefer_relative_imports`, `prefer_single_quotes`, `prefer_arrow_functions`, `prefer_trailing_comma_always`, `prefer_for_in`, `prefer_boolean_prefixes_for_params`

**See [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for the full list with examples, pros/cons, and quick fixes.

## Performance

Saropa Lints runs as a native Dart analyzer plugin — no separate process needed. The tier system helps manage analysis scope:

- Rules set to `false` are not loaded
- Start with `essential` or `recommended`
- Upgrade tiers as you fix warnings

```bash
# GOOD: Start with recommended tier
dart run saropa_lints:init --tier recommended

# CAUTION: Enabling everything on a legacy codebase may show thousands of warnings
dart run saropa_lints:init --tier pedantic
```

### Performance Tip: Use Lower Tiers During Development

For faster iteration during development:

1. **Use `essential` tier locally** — catches critical bugs with fewer rules
2. **Use `professional` or higher in CI** — thorough checking where speed matters less
3. **Upgrade tiers gradually** — fix warnings before enabling more rules

The tier you choose has a direct impact on analysis speed:

- `essential`: ~300 rules → **fastest** (memory leaks, security, crashes)
- `recommended`: ~850 rules → moderate (+ accessibility, performance)
- `professional`: ~1500 rules → slower (+ architecture, documentation)
- `comprehensive`/`pedantic`: 1572+ rules → **slowest** (everything)

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

- **Scope**: Saropa Lints runs as a native analyzer plugin on the package where it's configured. For multi-package workspaces, add `saropa_lints` to each package's `analysis_options.yaml`.
- **File types**: Only Dart source files (`.dart`) are analyzed. Non-Dart assets (JSON, XML, YAML, scripts, etc.) are out of scope.

## Running the Linter

**Command line:**

```bash
dart analyze
```

Saropa Lints runs as a native Dart analyzer plugin. Issues appear automatically in your IDE's Problems panel and in `dart analyze` output.

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

### IDE Integration

Saropa Lints v5 uses the native Dart analyzer plugin system. Issues appear directly in your IDE's Problems panel — no extra setup required.

**If you don't see warnings:**

1. Run `dart pub get` (or `flutter pub get`)
2. Restart your IDE (VS Code: `Ctrl+Shift+P` → "Developer: Reload Window")
3. Check **View → Output → Dart Analysis Server** for errors

## Troubleshooting

### I'm new and completely lost

**Start here:**

1. **Install**: Add to your `pubspec.yaml` dev_dependencies:
   ```yaml
   dev_dependencies:
     saropa_lints: ^5.0.0
   ```

2. **Configure**: Add to your `analysis_options.yaml`:
   ```yaml
   include: package:saropa_lints/tiers/recommended.yaml
   ```

3. **Get dependencies**:
   ```bash
   dart pub get
   ```

4. **Reload VS Code**:
   - Press `Ctrl+Shift+P`
   - Type "reload"
   - Click "Developer: Reload Window"

5. **Check**: Look at the PROBLEMS panel (View → Problems), or run `dart analyze`

**Still not working?** See the sections below.

### IDE doesn't show lint warnings

**Quick Fix (works 90% of the time):**

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "reload"
3. Click "Developer: Reload Window"
4. Wait for analysis to complete

**If that doesn't work:**

1. Clear the cache: Delete the `.dart_tool` folder and run `dart pub get`
2. Reload VS Code again (steps above)
3. Check **View → Output → Dart Analysis Server** for errors
4. Verify configuration is correct (see "Configuration not working" below)

**Alternative (command line):**

Run `dart analyze` in your terminal to see all issues immediately.

### Configuration not working (not enough rules loading)

**Problem:** You only get a few rules instead of the full set for your chosen tier.

**Solution:** Use the CLI tool to generate explicit configuration:

```bash
# Generate config for comprehensive tier
dart run saropa_lints:init --tier comprehensive

# Or for all rules (pedantic tier)
dart run saropa_lints:init --tier pedantic
```

This generates `analysis_options.yaml` with explicit `rule_name: true` for every enabled rule.

**Verify it worked:** Run `dart analyze` and check the output.

### Too many warnings! What do I do?

**This is normal** when first installing. You'll see hundreds or thousands of warnings.

**Option 1: Start smaller** (recommended for existing projects)

```bash
# Start with essential tier (~300 critical rules)
dart run saropa_lints:init --tier essential
```

**Option 2: Use baseline** (for brownfield projects)

Generate a baseline to suppress existing issues and only catch new violations:

```bash
dart run saropa_lints:baseline
```

**Option 3: Disable noisy rules**

Edit your `analysis_options.yaml` and set specific rules to `false`:

```yaml
plugins:
  saropa_lints:
    diagnostics:
      prefer_double_quotes: false  # disabled
      prefer_trailing_comma_always: false
      no_magic_number: false
```

**Option 4: Use quick fixes**

Many rules have automatic fixes:
- Hover over the warning
- Click "Quick Fix" or press `Ctrl+.`
- Select "Fix all in file" to fix all instances at once
- Or run `dart fix --apply` from the command line

**Don't stress about fixing everything immediately.** Pick one category (like accessibility or memory leaks) and fix those first.

### Out of Memory errors

If you see errors like:

```
../../runtime/vm/zone.cc: 96: error: Out of memory.
```

**Solution 1: Clear the pub cache** (most effective)

```bash
dart pub cache clean
dart pub get
```

**Solution 2: Increase Dart heap size** (PowerShell)

```powershell
$env:DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart analyze
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

Then run `dart analyze` again.

## Frequently Asked Questions

**Q: Does this replace `flutter_lints`?**
A: You can run them side-by-side, but Saropa Lints covers everything in `flutter_lints` plus 1600+ additional behavioral and security checks. Most teams replace `flutter_lints` entirely. With v5, you no longer need `custom_lint` either — just `saropa_lints` in your dev_dependencies.

**Q: Will this slow down my CI/CD pipeline?**
A: Saropa Lints v5 runs as a native analyzer plugin, integrated directly into `dart analyze`. The **Tier System** allows you to balance speed and strictness. The `essential` tier is designed to be fast for CI environments.

**Q: Can I use this with existing legacy projects?**
A: Yes! Use the **Baseline** feature (`dart run saropa_lints:baseline`) to suppress existing issues instantly. This lets you enforce quality on *new* code without having to fix 500+ legacy errors first.

**Q: I'm upgrading from v4 — what changed?**
A: v5 uses the native Dart analyzer plugin system instead of `custom_lint`. Remove `custom_lint` from your dependencies, replace `custom_lint: rules:` with `plugins: saropa_lints: diagnostics:` in your config (or just use a tier preset), and run `dart analyze` instead of `dart run custom_lint`. The init tool handles the config migration automatically.

## Contributing

**We are building the industry standard together.**

We don't have all the answers. We believe great tools are forged by many hands, and if you've shipped production Flutter apps, we want your opinions.

If you think a rule is:

- **Wrong** - tell us why, we'll fix it or remove it
- **Too strict** - maybe it belongs in a higher tier
- **Too lenient** - maybe it should be stricter or have options
- **Missing** - propose it, or better yet, implement it

**Want to learn AST analysis?** We mentor contributors. Pick a "Good First Issue" and we'll guide you through writing your first linter.

### How to contribute

See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for detailed guidelines.

**Adding a new rule:**

1. Create rule in appropriate `lib/src/rules/*.dart` file
2. Register in `lib/src/rules/all_rules.dart`
3. Add to the appropriate tier in `lib/src/tiers.dart`
4. Add tests in `test/`
5. Update CHANGELOG.md

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

[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-recommended%2B-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints)

```md
[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-recommended%2B-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints)
```

## License

MIT - see [LICENSE](https://github.com/saropa/saropa_lints/blob/main/LICENSE). Use it however you like.

---

Built with care by the Flutter community. Questions? Ideas? We'd love to hear from you.

[pub.dev][pub_link] | [GitHub][github_link] | [Issues][issues_link] | [Saropa][saropa_link]

[pub_link]: https://pub.dev/packages/saropa_lints
[github_link]: https://github.com/saropa/saropa_lints
[issues_link]: https://github.com/saropa/saropa_lints/issues
[saropa_link]: https://saropa.com

---

## About This Project

> "The bitterness of poor quality remains long after the sweetness of meeting the schedule has been forgotten." — Karl Wiegers

> "Quality is not an act, it is a habit." — Aristotle

**saropa_lints** is a comprehensive static analysis package for Flutter and Dart applications. With 1700+ lint rules organized into 5 progressive tiers (and more planned), it catches memory leaks, security vulnerabilities, accessibility violations, and runtime crashes that standard linters miss. Whether you're building a startup MVP or enterprise software, saropa_lints helps you ship more stable, secure, and accessible apps.

**Keywords:** Flutter linter, Dart static analysis, Flutter code quality, memory leak detection, security scanning, accessibility testing, WCAG compliance, European Accessibility Act, Flutter best practices, Dart analyzer plugin, code review automation, CI/CD linting, Flutter enterprise tools

**Hashtags:** #Flutter #Dart #StaticAnalysis #CodeQuality #FlutterDev #DartLang #Linting #DevTools #OpenSource #Accessibility #Security #BestPractices

---

## Sources

- **Dart Analyzer** — Dart's static analysis engine
  https://dart.dev/tools/analysis

- **analysis_server_plugin** — Native Dart analyzer plugin framework
  https://pub.dev/packages/analysis_server_plugin

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
