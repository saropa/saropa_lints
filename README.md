![Saropa Lints - Advanced Static Analysis for Flutter & Dart](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/banner_v2.png)

**The most comprehensive static analysis suite for Flutter and Dart.** 2,300+ lint rules that catch memory leaks, security vulnerabilities, accessibility violations, and runtime crashes — the bugs that compile fine but crash in production.

Developed by [Saropa](https://saropa.com) to make the world of Dart & Flutter better.

<div align="center">

[![pub package](https://img.shields.io/pub/v/saropa_lints.svg?style=flat-square&logo=dart&color=blue)](https://pub.dev/packages/saropa_lints) [![pub points](https://img.shields.io/pub/points/saropa_lints?style=flat-square&logo=dart)](https://pub.dev/packages/saropa_lints/score) [![likes](https://img.shields.io/pub/likes/saropa_lints?style=flat-square&logo=dart&color=red)](https://pub.dev/packages/saropa_lints/score) [![ci](https://img.shields.io/github/actions/workflow/status/saropa/saropa_lints/ci.yml?branch=main&style=flat-square&logo=github&label=build)](https://github.com/saropa/saropa_lints/actions) [![GitHub stars](https://img.shields.io/github/stars/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints) [![GitHub forks](https://img.shields.io/github/forks/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints) [![GitHub issues](https://img.shields.io/github/issues/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints/issues) [![GitHub last commit](https://img.shields.io/github/last-commit/saropa/saropa_lints?style=flat-square&logo=github)](https://github.com/saropa/saropa_lints/commits)

[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-2332-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints) [![Flutter Platform](https://img.shields.io/badge/platform-flutter-02569B.svg?style=flat-square&logo=flutter)](https://flutter.dev/) [![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg?style=flat-square)](https://opensource.org/licenses/MIT)

</div>

> Have feedback? [Open an issue](https://github.com/saropa/saropa_lints/issues/new) on GitHub.

---

## Quick Start

**Requirements:** Dart SDK `>=3.9.0 <4.0.0`.

### Option A — VS Code extension (recommended)

1. Install [Saropa Lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints) from the Marketplace (also on [Open VSX](https://open-vsx.org/extension/saropa/saropa-lints))
2. Open the **Saropa Lints** sidebar (checklist icon)
3. Run **Saropa Lints: Set Up Project** to add the package and analysis config

Run **"Saropa Lints: Getting Started"** from the Command Palette for a guided tour.

### Option B — Tier preset (zero-config)

```bash
dart pub add --dev saropa_lints
```

```yaml
# analysis_options.yaml
include: package:saropa_lints/tiers/recommended.yaml
```

### Option C — CLI init (full control, CI/scripting)

```bash
dart pub add --dev saropa_lints
dart run saropa_lints:init --tier recommended
```

Run `dart analyze` — issues appear in your IDE and terminal. See the [CLI Reference](doc/guides/cli.md) for all commands and CI examples.

> **Presets:** `essential` · `recommended` · `professional` · `comprehensive` · `pedantic` — see [The 5 Tiers](#the-5-tiers)

---

## What Standard Linters Miss

`dart analyze` checks syntax and style. It doesn't check _behavior_. Code that compiles but fails at runtime:

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

Saropa Lints detects these patterns and 2,300+ more across four domains:

- **Security** — Hardcoded credentials, sensitive data in logs, unsafe deserialization, OWASP-mapped
- **Accessibility** — Missing semantics, inadequate touch targets, screen reader issues, EAA compliance
- **Performance** — Unnecessary rebuilds, memory leaks, expensive operations in build methods
- **Lifecycle** — setState after dispose, missing mounted checks, undisposed controllers and streams

Rules use AST type checking — not string matching — so you won't get false positives on variable names like "password" or "upstream".

![Flutter memory leak detection in VS Code showing undisposed TextEditingController](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260401_problems_tab.png)

---

## How Saropa Lints Compares

| Feature | `flutter_lints` | `very_good_analysis` | **Saropa Lints** |
|:---|:---:|:---:|:---|
| Syntax & style checks | Yes | Yes | Yes |
| Zero-config setup | Yes | Yes | Yes (tier presets) |
| Controller leak detection | — | — | Yes (deep analysis) |
| Runtime crash prevention | — | — | Yes (behavioral) |
| Security (OWASP mapped) | — | — | Yes (ISO/OWASP) |
| Library-specific rules | — | — | Yes (50+ rules) |
| AI-ready diagnostics | — | — | Yes |
| Health score & trends | — | — | Yes (VS Code extension) |

---

## Alternative Package Coverage

Saropa Lints has been audited rule-by-rule against **46 alternative Dart and Flutter lint packages** — the entire published landscape. Across 1,670 custom rules from those packages, saropa_lints has a HAVE or PARTIAL equivalent for **~75%**.

| Alternative | Their rules | Saropa coverage | Migration guide |
|---|---|---|---|
| **DCM** (dart_code_metrics) | 487 | 87% HAVE | [Guide](doc/guides/migration_guides/migration_from_dcm.md) |
| **flutter_skill_lints** | 279 | 84% HAVE | [Guide](doc/guides/migration_guides/migration_from_flutter_skill_lints.md) |
| **many_lints** | 261 | 74% HAVE | [Guide](doc/guides/migration_guides/migration_from_many_lints.md) |
| **awesome_lints** | 128 | 85% HAVE | [Guide](doc/guides/migration_guides/migration_from_awesome_lints.md) |
| **dart_code_linter** | 87 | 88% HAVE | [Guide](doc/guides/migration_guides/migration_from_dart_code_linter.md) |
| **solid_lints** | 31 | 48% HAVE | [Guide](doc/guides/migration_guides/migration_from_solid_lints.md) |
| **pyramid_lint** | 36 | 67% HAVE | [Guide](doc/guides/migration_guides/migration_from_pyramid_lint.md) |
| **riverpod_lint** | 13 | 30% HAVE | [Guide](doc/guides/migration_guides/migration_from_riverpod_lint.md) |
| **bloc_lint** | 9 | 37% HAVE | [Guide](doc/guides/migration_guides/migration_from_bloc_lint.md) |

Every alternative has a dedicated [migration guide](doc/guides/migration_guides/) with a per-rule mapping table and one-click migration packs in the VS Code extension.

---

## The 5 Tiers

Each tier builds on the previous one. Start where your team is comfortable and upgrade over time.

| Tier | Focus | When to use |
|------|-------|-------------|
| **Essential** | Crashes, data loss, security breaches, memory leaks | Every project. Non-negotiable baseline. |
| **Recommended** | + Common bugs, performance, accessibility fundamentals | Most production apps. The sensible default. |
| **Professional** | + Architecture, testability, documentation standards | Enterprise teams, long-lived codebases. |
| **Comprehensive** | + Stricter patterns, optimization, edge cases | Quality-obsessed teams, published packages. |
| **Pedantic** | + Everything, including highly opinionated rules | Greenfield projects, maximum strictness. |

Full tier details and configuration: [Configuration Guide](doc/guides/configuration.md)

---

## VS Code Extension

The package and extension are **one product** — published together and versioned in sync. The Dart package provides the rules; the extension is the setup, configuration, and triage surface.

**Key features:**

- **Health Score** — 0–100 in the status bar; green/yellow/red bands
- **Violations view** — Grouped by severity/impact/file/rule/OWASP, with inline annotations
- **Security Posture** — OWASP Top 10 coverage matrix and compliance export
- **Triage** — Disable noisy rules from the UI; see estimated score impact before acting
- **Rule Packs** — Enable stack bundles (Riverpod, Drift, Bloc, ...) from the UI
- **Package Vibrancy** — Dependency health with activity grades (A–F) and dormancy alerts
- **Code Health Dashboard** — Function-level scoring for your own Dart source
- **File Risk** — Files ranked by violation density; focus on the riskiest first
- **TODOs & Hacks** — Sidebar scan for TODO/FIXME/HACK markers (opt-in workspace scan)
- **Trends** — Score progression over time with milestone celebrations

![Package Vibrancy Report showing dependency health and version status](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260401_package_vibrancy_report.png)

Full extension reference: [Extension Guide](doc/guides/extension.md) — settings, commands, API, view details.

---

## Library-Specific Rules

Standard linters see valid Dart code. Saropa Lints understands library APIs and catches patterns that fail silently at runtime — 50+ rules for popular packages:

| Library | Common issues caught | Guide |
|---------|---------------------|-------|
| **GetX** | Undisposed controllers, memory leaks from workers, missing super calls | [Using with GetX](doc/guides/packages/using_with_getx.md) |
| **Riverpod** | Circular provider deps, ref.read() in build, missing ProviderScope | [Using with Riverpod](doc/guides/packages/using_with_riverpod.md) |
| **Provider** | Provider.of in build causing rebuilds, recreated providers losing state | [Using with Provider](doc/guides/packages/using_with_provider.md) |
| **Bloc** | Events in constructor, mutable state, unclosed Blocs, BlocListener in build | [Using with Bloc](doc/guides/packages/using_with_bloc.md) |
| **Isar** | Enum fields causing data corruption on schema changes | [Using with Isar](doc/guides/packages/using_with_isar.md) |
| **Hive** | Missing init, unclosed boxes, hardcoded encryption keys | [Using with Hive](doc/guides/packages/using_with_hive.md) |
| **Firebase** | Unbounded queries, missing batch writes, FCM token leaks | [Using with Firebase](doc/guides/packages/using_with_firebase.md) |

Also: Drift, Equatable, Freezed, dio, GraphQL, Supabase, get_it, flutter_hooks, Flame, and more. Configure which libraries are active in [analysis_options_custom.yaml](doc/guides/configuration.md#package-configuration).

---

## OWASP Security Mapping

Security rules map to **OWASP Mobile Top 10 (2024)** and **OWASP Top 10 (2021)** for compliance reporting and risk categorization.

| OWASP Mobile | Coverage | OWASP Web | Coverage |
|---|---|---|---|
| M1 Credential Usage | 5+ rules | A01 Broken Access Control | 4+ rules |
| M2 Supply Chain | 2+ rules | A02 Cryptographic Failures | 10+ rules |
| M3 Authentication | 5+ rules | A03 Injection | 6+ rules |
| M4 Input Validation | 6+ rules | A05 Misconfiguration | 4+ rules |
| M5 Communication | 2+ rules | A07 Authentication | 8+ rules |
| M6 Privacy Controls | 5+ rules | A09 Logging Failures | 2+ rules |
| M8 Misconfiguration | 4+ rules | | |
| M9 Data Storage | 7+ rules | | |
| M10 Cryptography | 4+ rules | | |

The [European Accessibility Act](https://accessible-eu-centre.ec.europa.eu/content-corner/news/eaa-comes-effect-june-2025-are-you-ready-2025-01-31_en) took effect June 2025. GitHub detected [39 million leaked secrets](https://github.blog/security/application-security/next-evolution-github-advanced-security/) in 2024. These aren't edge cases — Saropa Lints catches both categories.

---

## Built for AI

AI coding assistants move fast but hallucinate code that compiles yet crashes. Saropa Lints acts as guardrails — semantic feedback on _behavior_, not just syntax, forces the AI to correct mistakes in real-time.

Diagnostics are engineered as paste-ready prompts: deep context and specific failure points that give the AI exactly what it needs to fix the issue without further explanation.

![AI fixing Flutter security vulnerability automatically in Android Studio](https://raw.githubusercontent.com/saropa/saropa_lints/main/assets/20260401_AI_solver_tab.png)

---

## CLI Tools

Every command supports `--help`. Full reference: [CLI Guide](doc/guides/cli.md)

```bash
dart run saropa_lints:init             # Configure analysis_options.yaml
dart run saropa_lints scan             # Run rules against any Dart project
dart run saropa_lints:cross_file       # Unused files, circular deps, import stats
dart run saropa_lints:baseline         # Baseline existing violations for brownfield adoption
dart run saropa_lints:quality_gate     # CI pass/fail from violations.json
dart run saropa_lints:project_vibrancy # Function-level code-health scoring
dart run saropa_lints audit            # Full audit with SARIF output for GitHub
```

The scanner works on **any Dart project** — even without saropa_lints as a dependency. Ideal for evaluating before adopting.

---

## Scope: Static Code vs. Runtime Data

`saropa_lints` and **[Saropa Drift Advisor](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-drift-advisor)** are complementary. They analyze different things and should both be installed when you use Drift.

| | `saropa_lints` | `saropa_drift_advisor` |
|---|---|---|
| **Analyzes** | Dart source code (AST) | Live database file, schema, data |
| **Runs as** | Analyzer plugin (compile-time) | VS Code extension + debug server (runtime) |
| **Sees source** | Yes | No |
| **Sees data** | No | Yes |

---

## How It Works

```
Dart package                    VS Code extension
   |                                  |
   v                                  v
analysis_options.yaml  <---  Set Up Project / Set Tier / Triage
   |                                  |
   v                                  v
dart analyze           <---  Run Analysis (from UI)
   |                                  |
   v                                  v
violations.json        --->  Health Score, Violations, Security,
                             File Risk, Trends, Inline Annotations
```

The Dart package provides **2,332** lint rules via the native analyzer plugin. The VS Code extension reads `violations.json` and provides the UI. Both are published together.

---

## Adoption Strategy

Static analysis reveals problems that already exist. The tiered system lets you start at any level.

**New projects:** Start with `professional` or `comprehensive`.

**Existing projects:**
1. Enable `essential` — fix critical issues first
2. Move to `recommended` — fix warnings as you touch files
3. Enable higher tiers when the noise is manageable
4. Use [`dart run saropa_lints:baseline`](doc/guides/configuration.md#baseline) to suppress existing violations and only catch new ones

---

## Migrating from Other Tools

One-click migration packs in the VS Code extension, plus detailed per-package guides:

- [Migrating from DCM (Dart Code Metrics)](doc/guides/migration_guides/migration_from_dcm.md) — 87% HAVE coverage
- [Migrating from very_good_analysis](doc/guides/migration_guides/migration_from_vga.md)
- [Migrating from solid_lints](doc/guides/migration_guides/migration_from_solid_lints.md)
- [Migrating from awesome_lints](doc/guides/migration_guides/migration_from_awesome_lints.md) — 85% HAVE coverage
- [All 46 migration guides](doc/guides/migration_guides/)

---

## Rule Categories

| Category | Description |
|----------|-------------|
| **Flutter Widgets** | Lifecycle, setState, keys, performance |
| **Modern Dart 3.0+** | Class modifiers, patterns, records, when guards |
| **State Management** | Provider, Riverpod, Bloc patterns |
| **Performance** | Build optimization, memory, caching |
| **Security** | Credentials, encryption, input validation — [OWASP mapped](#owasp-security-mapping) |
| **Accessibility** | Screen readers, touch targets, semantics |
| **Testing** | Assertions, mocking, flaky test prevention |
| **Architecture** | Clean architecture, DI, SOLID principles |
| **Async** | Futures, Streams, cancellation |

[175+ stylistic rules](plans/guides/README_STYLISTIC.md) available separately for team preferences (formatting, ordering, naming). Enable individually or use `--stylistic-all`.

---

## Open Source & Transparent

Unlike proprietary tools, Saropa Lints is 100% open source (MIT). Every rule's logic is inspectable and forkable.

- [**ROADMAP.md**](ROADMAP.md) — Active backlog and planned rules
- **Deferred rules** — The hard problems we can't solve yet. Community help welcome.

| Marker | Meaning |
|--------|---------|
| :octopus: | [Tracked as GitHub issue](https://github.com/saropa/saropa_lints/issues) |
| :thought_balloon: | [Discussions — Q&A, ideas, announcements](https://github.com/saropa/saropa_lints/discussions) |

---

## Contributing

We don't have all the answers. If you've shipped production Flutter apps, we want your opinions.

- **Wrong rule?** Tell us why — we'll fix or remove it
- **Too strict?** Maybe it belongs in a higher tier
- **Missing rule?** Propose it, or implement it
- **New to AST analysis?** We mentor contributors. Pick a "Good First Issue"

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## Professional Services

Optional paid services for teams that want hands-on help.

| Service | Description |
|---------|-------------|
| **New Projects** | Development scoped to your stage — MVP, Production, or Enterprise |
| **Upgrade** | Move existing projects to higher tiers |
| **Audit** | Assess codebases you inherited |
| **Custom Rules** | Rules specific to your architecture and compliance requirements |

Contact: [saropa.com](https://saropa.com) | [services@saropa.com](mailto:services@saropa.com) | [Details](PROFESSIONAL_SERVICES.md)

---

## Documentation

| Document | Description |
|----------|-------------|
| [Extension Guide](doc/guides/extension.md) | VS Code extension — settings, commands, views, API |
| [Configuration Guide](doc/guides/configuration.md) | Tiers, platforms, packages, baseline, file skipping |
| [CLI Reference](doc/guides/cli.md) | All CLI commands with flags and CI examples |
| [Troubleshooting](doc/troubleshooting.md) | IDE issues, OOM errors, configuration problems |
| [FAQ](doc/faq.md) | Common questions about adoption, compatibility, custom rules |
| [Stylistic Rules](plans/guides/README_STYLISTIC.md) | 175+ optional formatting/naming/ordering rules |
| [Rule Packs](doc/guides/rule_packs.md) | Stack bundles and migration packs |
| [Performance](plans/guides/PERFORMANCE.md) | Profiling and optimization guide |
| [Composite Plugin](doc/guides/composite_analyzer_plugin.md) | Running saropa_lints alongside custom rules |
| [Violation Export API](VIOLATION_EXPORT_API.md) | violations.json schema for CI/tooling |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute rules and report issues |
| [CHANGELOG.md](CHANGELOG.md) | Version history and release notes |
| [SECURITY.md](SECURITY.md) | Security policy and vulnerability reporting |

### Library Guides

| Category | Package | Guide |
|----------|---------|-------|
| **State Management** | Riverpod | [Using with Riverpod](doc/guides/packages/using_with_riverpod.md) |
| | Bloc | [Using with Bloc](doc/guides/packages/using_with_bloc.md) |
| | Provider | [Using with Provider](doc/guides/packages/using_with_provider.md) |
| | GetX | [Using with GetX](doc/guides/packages/using_with_getx.md) |
| **Databases** | Isar | [Using with Isar](doc/guides/packages/using_with_isar.md) |
| | Hive | [Using with Hive](doc/guides/packages/using_with_hive.md) |
| | Drift | [Using with Drift](doc/guides/packages/using_with_drift.md) |
| **Backend** | Firebase | [Using with Firebase](doc/guides/packages/using_with_firebase.md) |
| **Platform** | iOS/macOS | [Apple Platform Rules](doc/guides/apple_platform_rules.md) |

---

## Badge

Show your code quality standards:

[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-recommended%2B-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints)

```md
[![Saropa Lints Badge](https://img.shields.io/badge/saropa_lints-recommended%2B-blue?style=flat&logo=flutter&logoColor=white&color=435489)](https://pub.dev/packages/saropa_lints)
```

## Supported Versions

The current major (`12.x`) is the actively maintained line. Earlier majors are updated only for security-impacting issues. [Open an issue](https://github.com/saropa/saropa_lints/issues/new) tagged `backport-request` if needed.

## License

MIT — see [LICENSE](LICENSE). Use it however you like.

---

[pub.dev](https://pub.dev/packages/saropa_lints) | [GitHub](https://github.com/saropa/saropa_lints) | [Issues](https://github.com/saropa/saropa_lints/issues) | [Saropa](https://saropa.com)

<div align="center">

[![Share on X](https://img.shields.io/badge/share%20on-X-000000?style=flat-square&logo=x&logoColor=white)](https://twitter.com/intent/tweet?text=Check%20out%20Saropa%20Lints%3A%20Catch%20memory%20leaks%2C%20security%20vulnerabilities%2C%20and%20runtime%20crashes%20in%20Flutter%21&url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Facebook](https://img.shields.io/badge/share%20on-facebook-1877F2?style=flat-square&logo=facebook&logoColor=white)](https://www.facebook.com/sharer/sharer.php?u=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Bluesky](https://img.shields.io/badge/share%20on-bluesky-0285FF?style=flat-square&logo=bluesky&logoColor=white)](https://bsky.app/intent/compose?text=Check%20out%20Saropa%20Lints%3A%20Catch%20memory%20leaks%2C%20security%20vulnerabilities%2C%20and%20runtime%20crashes%20in%20Flutter%21%20https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on LinkedIn](https://img.shields.io/badge/share%20on-linkedin-0077B5?style=flat-square&logo=linkedin&logoColor=white)](https://www.linkedin.com/sharing/share-offsite/?url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints) [![Share on Reddit](https://img.shields.io/badge/share%20on-reddit-FF4500?style=flat-square&logo=reddit&logoColor=white)](https://www.reddit.com/submit?url=https%3A%2F%2Fpub.dev%2Fpackages%2Fsaropa_lints&title=Saropa%20Lints%20-%20Advanced%20Static%20Analysis)

</div>
