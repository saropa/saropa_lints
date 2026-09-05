# Configuration Guide

Saropa Lints has three independent configuration axes — **tier** (how strict), **platforms** (which OS-specific rules run), and **packages** (which library-specific rules run) — plus a **baseline** mechanism for adopting the linter on an existing codebase without fixing everything on day one. This guide collects the detailed reference material; see the [README](../../README.md) for the quick-start paths (VS Code extension, tier preset, CLI init).

## Tiers

<!-- Five cumulative tiers; each builds on the previous one. Pick the strictest tier your team can tolerate today, and move up as violations get fixed. -->

| Tier | Purpose | Example Rules |
| --- | --- | --- |
| **Essential** | Prevents crashes, data loss, security breaches, and memory leaks. | `require_field_dispose`, `avoid_hardcoded_credentials`, `check_mounted_after_async` |
| **Recommended** | Catches common bugs, basic performance issues, and accessibility fundamentals. | `require_semantics_label`, `avoid_expensive_build`, `require_json_decode_try_catch` |
| **Professional** | Enforces architecture, testability, maintainability, and documentation standards. | `avoid_god_class`, `require_public_api_documentation`, `prefer_result_pattern` |
| **Comprehensive** | Stricter patterns, optimization hints, and thorough edge case coverage. | `prefer_element_rebuild`, `prefer_immutable_bloc_state`, `require_test_documentation` |
| **Pedantic** | Everything, including pedantic and highly opinionated rules. | `prefer_custom_single_child_layout`, `prefer_feature_folder_structure`, `avoid_returning_widgets` |

### Setting a tier

```yaml
# In analysis_options.yaml — just pick your tier:
include: package:saropa_lints/tiers/recommended.yaml
```

```bash
dart run saropa_lints:init --tier recommended
dart run saropa_lints:init --target /path/to/project
dart run saropa_lints:init --help
```

Available tiers: `essential` (1), `recommended` (2), `professional` (3), `comprehensive` (4), `pedantic` (5).

VS Code extension: use **Set Tier** from the command palette or click the tier badge in the status bar.

## Rule Configuration

### Rule configuration cheatsheet

Mental model:

- **Tier** = broad baseline (`essential` → `pedantic`).
- **Packs** = domain/version bundles (library and SDK migration groups) — see [Rule Packs](#rule-packs) below.

Current behavior:

- Pack-owned package/SDK migration rules are **off unless their pack is enabled**.
- Tier selection still controls non-pack-owned rules.
- Explicit `diagnostics: rule_name: false` still disables a rule.

Minimal setup pattern:

```yaml
# Enable a tier plus specific rule packs (library/SDK migration bundles).
plugins:
  saropa_lints:
    version: "x.y.z"
    rule_packs:
      enabled:
        - riverpod
        - flutter_sdk_3_32
```

Quick commands:

```bash
dart run saropa_lints:init --tier recommended
dart run saropa_lints:init --list-packs
dart run saropa_lints:init --tier recommended --enable-pack riverpod --enable-pack flutter_sdk_3_32
```

If users are unsure, start with a tier only and enable packs later.

This updates (or creates) two files:

- **`analysis_options.yaml`** — the `plugins: saropa_lints: diagnostics:` section is regenerated with every rule set to `true`/`false` for your tier. All other sections are preserved.
- **`analysis_options_custom.yaml`** — your project settings (platforms, analysis output). Created on first run; never overwritten.

### Customizing rules

After generating configuration, customize rules by editing `analysis_options.yaml`:

```yaml
plugins:
  saropa_lints:
    diagnostics:
      # The init tool generates explicit true/false for every rule
      avoid_hardcoded_strings_in_ui: true # change to false to disable
      require_public_api_documentation: false # change to true to enable

      # Stylistic rules (enable the ones your team prefers)
      prefer_single_quotes: true
      prefer_trailing_comma_always: true
```

Rules use standard YAML map format (no `-` prefix needed).

To change tiers, either switch the `include:` preset or re-run the init tool:

```bash
dart run saropa_lints:init --tier professional
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
      prefer_arguments_ordering: false # canonical name
      arguments_ordering: false # alias
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

- No rule is accidentally overlooked.
- Your config becomes a complete record of team style decisions.
- Mutually exclusive rules (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) require explicit choice.

If you enable all rules, you will need to disable one rule from each conflicting pair.

## Platform Configuration

The `analysis_options_custom.yaml` file includes a `platforms` section that controls which platform-specific rules are active. Only iOS and Android are enabled by default. Enable the platforms your project targets:

```yaml
# In analysis_options_custom.yaml
platforms:
  ios: true # enabled by default
  android: true # enabled by default
  macos: false # enable if targeting macOS
  web: false # enable if targeting web
  windows: false # enable if targeting Windows
  linux: false # enable if targeting Linux
```

Each platform has dedicated rules that catch platform-specific issues:

| Platform | Rules | Examples |
| --- | --- | --- |
| **iOS** | 90+ | Safe area, privacy manifest, App Tracking Transparency, Face ID, HealthKit, keychain |
| **Android** | 11+ | Runtime permissions, notification channels, PendingIntent flags, cleartext traffic |
| **macOS** | 15+ | Sandboxing, notarization, hardened runtime, window restoration, entitlements |
| **Web** | 10+ | CORS handling, platform channels, deferred loading, URL strategy, web renderer |
| **Windows** | Desktop shared | Menu bar, window close confirmation, native file dialogs, focus indicators |
| **Linux** | Desktop shared | Same desktop rules as Windows |

Some rules are shared across platform groups:

- **Apple rules** (iOS + macOS): Apple Sign In, nonce validation.
- **Desktop rules** (macOS + Windows + Linux): Menu bar, window management, keyboard/mouse interaction patterns.

When a platform is set to `false`, its rules move to the disabled section. Shared rules (e.g., Apple Sign In for iOS + macOS) are only disabled when **all** their platforms are disabled.

**User overrides always win** — if you force-enable a rule in the overrides section, it stays enabled even if its platform is disabled.

The `init` tool logs which platforms are disabled and how many rules are affected:

```
Platforms disabled: web, windows, linux (23 rules affected)
```

## Package Configuration

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

## Rule Packs

Rule packs are domain/version bundles (library and SDK migration groups, e.g. `riverpod`, `flutter_sdk_3_32`) layered on top of a tier — pack-owned rules are off until their pack is enabled. List and enable them with `dart run saropa_lints:init --list-packs` / `--enable-pack <id>`.

See [rule_packs.md](rule_packs.md) for the full reference (pack IDs, applicability rules, semver gates).

## Stylistic Rules

**175+ stylistic rules** for formatting, ordering, and naming conventions are a **separate track** from correctness tiers — your code can be perfectly correct while violating every stylistic rule, or perfectly formatted while crashing on every screen. That's why they're not included in `essential` → `pedantic`.

Enable stylistic rules individually in your config, or use the VS Code extension's Setup & triage view to enable/disable them with estimated score impact.

For CI/scripting, use `--no-stylistic` (default) or `--stylistic-all` to bulk-enable:

```bash
dart run saropa_lints:init --tier recommended --stylistic-all
```

Conflicting pairs (e.g., `prefer_single_quotes` vs `prefer_double_quotes`) must be enabled individually — you choose which style your team prefers.

See [../../plans/guides/README_STYLISTIC.md](../../plans/guides/README_STYLISTIC.md) for the full list with examples, pros/cons, and quick fixes.

## Baseline

### The Problem

You want to adopt saropa_lints on an existing project. You run `dart analyze` and see:

```
lib/old_widget.dart:42 - avoid_print
lib/old_widget.dart:87 - no_empty_block
lib/legacy/api.dart:15 - avoid_dynamic
... 500 more violations
```

**That's overwhelming.** You can't fix 500 issues before your next sprint. But you also can't ignore linting entirely — new code should be clean.

### The Solution: Baseline

The **baseline feature** records all existing violations and hides them, while still catching violations in new code.

- **Old code**: Violations hidden (baselined).
- **New code**: Violations reported normally.

This lets you adopt linting **today** without fixing legacy code first.

### Quick Start (One Command)

```bash
dart run saropa_lints:baseline
```

This command:

1. Runs analysis to find all current violations.
2. Creates `saropa_baseline.json` with those violations.
3. Updates your `analysis_options.yaml` automatically.

**Result**: Old violations are hidden, new code is still checked.

### Combinable baseline types

| Type | Config | Description | Best For |
| --- | --- | --- | --- |
| **File-based** | `baseline.file` | JSON listing specific violations | "Fix nothing yet" |
| **Date-based** | `baseline.date` | Git blame - ignore old code | "Fix gradually by age" |

Both types are combinable: any match suppresses the violation.

### Full Configuration

> **Note:** Baseline configuration via YAML is not yet supported. Use the
> `dart run saropa_lints:baseline` CLI command shown above, which generates
> the baseline file and updates your config automatically.

The baseline CLI supports these options:

| Option | Description |
| --- | --- |
| `--file` | Output file (default: `saropa_baseline.json`) |
| `--date` | Ignore code unchanged since this date (uses git blame) |
| `--paths` | Ignore entire directories (glob patterns) |
| `--only-impacts` | Only baseline certain severities (e.g., `low,medium`) |

### Path Pattern Examples

| Pattern | Matches |
| --- | --- |
| `lib/legacy/` | All files under `lib/legacy/` |
| `*.g.dart` | All files ending in `.g.dart` |
| `lib/**/old_*.dart` | Files like `lib/foo/old_widget.dart` |

### Priority Filtering

Use `only_impacts` to baseline only certain severity levels while still seeing errors:

```yaml
baseline:
  file: "saropa_baseline.json"
  only_impacts: [info] # Still see errors and warnings
```

> **Severity model:** errors must be fixed; warnings could fail or look bad; info is FYI. The 5-bucket impact taxonomy (`critical / high / medium / low / opinionated`) collapsed into the analyzer's three native severities on 2026-05-03. Existing `only_impacts: [low, medium, opinionated]` configs keep working (the values map to the new buckets) but new code should use `[info]` / `[warning]` / `[error]`.

### Cleaning Up Over Time

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

### CLI Reference

```bash
dart run saropa_lints:baseline              # Generate new baseline
dart run saropa_lints:baseline --update     # Refresh, remove fixed violations
dart run saropa_lints:baseline --dry-run    # Preview without changes
dart run saropa_lints:baseline --skip-config # Don't update analysis_options.yaml
dart run saropa_lints:baseline -o custom.json # Custom output path
dart run saropa_lints:baseline ./my_project  # Run on specific directory
dart run saropa_lints:baseline --help        # See all options
```

## Severity Levels

Each rule has a fixed severity (ERROR, WARNING, or INFO) defined in the rule itself. Severity cannot be overridden per-project. If a rule's severity doesn't match your needs:

- Use `// ignore: rule_name` to suppress individual occurrences.
- Disable the rule entirely with `rule_name: false`.
- [Open an issue](https://github.com/saropa/saropa_lints/issues) if you think the default severity should change.

Severity levels, in full:

- `error`: MUST be fixed — broken, will crash, exploitable, or fails in production (memory leaks, hardcoded credentials, always-failing casts).
- `warning`: Could fail or is embarrassing — may break under the wrong conditions or fail audits (accessibility, performance anti-patterns, missing error handling).
- `info`: FYI — style, consistency, opinionated guidance (naming conventions, hardcoded strings, missing docs).

Exit code from `dart run saropa_lints:severity_report` equals the number of errors (capped at 125), making it CI-friendly.

## Automatic File Skipping

Rules automatically skip files that can't be manually fixed:

| File Pattern | Skipped By Default |
| --- | --- |
| `*.g.dart`, `*.freezed.dart`, `*.gen.dart` | Yes (generated code) |
| `*_fixture.dart`, `fixture/**`, `fixtures/**` | Yes (test fixtures) |
| `*_test.dart`, `test/**` | Yes (override with `testRelevance`) |
| `example/**` | No (override with `skipExampleFiles`) |

Test files are skipped by default because most production-focused rules generate noise in test code. Override `testRelevance` to change behavior per rule:

- `TestRelevance.never` — skip test files (default).
- `TestRelevance.always` — run on all files including tests.
- `TestRelevance.testOnly` — run only on test files.

## Runtime Tier Cap

To enforce a stricter cumulative band than the rules still listed as enabled in YAML (for example in CI), set the `SAROPA_TIER` environment variable to `essential`, `recommended`, `professional`, `comprehensive`, or `pedantic`, or set `saropa_tier` in `analysis_options_custom.yaml` or `runtime_tier` / `saropa_tier` under `plugins.saropa_lints` in `analysis_options.yaml`.

When both the environment variable and a config file value are set, **the environment variable wins**. This is useful for capping tier strictness in CI without touching the checked-in YAML — e.g. running `pedantic` locally but capping at `recommended` in CI via `SAROPA_TIER=recommended`.
