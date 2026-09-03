# Migrating from klin_dart

This guide helps you migrate from `klin_dart` to `saropa_lints`.

## Why Migrate?

| Feature | klin_dart | saropa_lints |
|---------|-----------|--------------|
| **Rule count** | 6 rules | 2300+ custom rules |
| **Focus** | Complexity metrics & hardcoded strings | Flutter-specific analysis across security, accessibility, performance, and state management |
| **Configuration** | Per-rule thresholds (class/function/file length) | 5 progressive tiers |
| **Maintenance** | Small community package | Actively maintained |
| **Cost** | Free & open source | Free & open source |

**Note**: klin_dart is a small, focused package (6 rules) built around code-length and complexity metrics plus two string-literal checks. saropa_lints covers the same ground with configurable-threshold equivalents, plus 2300+ rules beyond klin_dart's scope.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  klin_dart: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - custom_lint

# klin_dart rules configured under custom_lint.rules

# After
analyzer:
  plugins:
    - custom_lint
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart run custom_lint
```

## Choosing a Tier

klin_dart ships one flat rule set. saropa_lints offers progressive tiers:

| klin_dart Usage | saropa_lints Tier | Description |
|-----------------|-------------------|--------------|
| Default rules | **Essential** (~300 rules) | Critical bugs, memory leaks, security |
| + length/complexity thresholds | **Recommended** (~900 rules) | Balanced coverage |
| Strict thresholds | **Professional** (~1600 rules) | Enterprise-grade |

**Start with `recommended`** — it covers klin_dart's complexity/length checks plus Flutter-specific rules klin_dart doesn't have.

## Rule Mapping

Coverage: 6 rules — 2 HAVE (33%), 3 PARTIAL, 1 TODO (16%)

| klin_dart Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_hardcoded_strings_in_widgets` | HAVE | `avoid_hardcoded_strings_in_ui` |
| `avoid_string_literals_in_logic` | HAVE | `no_magic_string` |
| `class_length` | TODO | TODO — see [proposal](../../../plans/tier_2_high_value/proposal_function_lines_of_code.md). `avoid_god_class` exists but measures member count, not LOC — a different metric, not a substitute |
| `cognitive_complexity` | PARTIAL | `avoid_high_cyclomatic_complexity` — flat McCabe count, no nesting weight or two-tier severity like klin_dart's SonarSource-style metric |
| `file_length` | PARTIAL | `avoid_long_length_files` — fixed 500-line tier-gated threshold, not configurable, doesn't exclude import lines like klin_dart's 700-line default |
| `function_length` | PARTIAL | `avoid_long_functions` — 100-line default (excludes comments/blank lines), no `build()`-specific higher threshold like klin_dart's 150-line allowance |

## What You Gain

klin_dart covers 6 rules around length/complexity metrics and two string-literal checks. saropa_lints covers the same intent plus rules entirely outside klin_dart's scope:

**Security**
- `avoid_hardcoded_credentials` — Catches secrets in code
- `avoid_logging_sensitive_data` — PII protection
- `require_secure_storage` — SharedPreferences warnings

**Accessibility**
- `require_semantics_label` — Screen reader support
- `avoid_small_touch_targets` — Touch target sizing

**Memory & Lifecycle**
- `require_dispose` — Full resource disposal tracking
- `avoid_context_in_initstate_dispose` — Prevents common Flutter bug

**State Management**
- Riverpod, Bloc, and Provider-specific rules covering hundreds of package-specific anti-patterns

## What You Lose

| klin_dart Feature | Alternative |
|--------------------|--------------|
| Configurable per-rule thresholds (e.g. custom max class length) | saropa_lints thresholds are fixed per tier; use `// ignore:` for isolated exceptions |
| `build()`-specific higher function-length threshold | Not currently modeled; `avoid_long_functions` applies one threshold to all functions |
| Cognitive-complexity nesting weight | `avoid_high_cyclomatic_complexity` uses flat McCabe count |

## Suppressing Rules

Both packages use custom_lint, so the syntax is identical:

```dart
// klin_dart / saropa_lints style (same)
// ignore: avoid_long_functions
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
