# Migrating from flutter_doctor_ai

This guide helps you migrate from [`flutter_doctor_ai`](https://pub.dev/packages/flutter_doctor_ai)
(github.com/ashwanisng/flutter_doctor_ai) to `saropa_lints`.

## Why Migrate?

| Feature | flutter_doctor_ai | saropa_lints |
|---------|--------------------|--------------|
| **Rule count** | 5 static rules (plus an AI-powered CLI mode using Groq/Gemini/OpenAI) | 2300+ custom rules |
| **Architecture** | Standalone CLI, LLM calls for context-aware fixes | `custom_lint`/`analysis_server_plugin`, real-time IDE feedback |
| **Focus** | A handful of common Flutter bug patterns | Comprehensive security, accessibility, performance, and Flutter-specific analysis |
| **Cost** | AI mode requires an LLM API key | Free & open source, no external calls |

**Note**: flutter_doctor_ai's AI-powered fix suggestions are outside saropa_lints' scope
— saropa_lints is a static rule engine with deterministic quick fixes, not an LLM-backed
tool. If you rely specifically on AI-generated fix explanations, that capability has no
saropa_lints equivalent. Its 5 static rules, however, are fully covered.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_doctor_ai: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - flutter_doctor_ai

# After
analyzer:
  plugins:
    - saropa_lints
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

### Step 3: Run the linter

```bash
dart analyze
```

## Rule Mapping

Coverage: 5 HAVE (100%), 0 PARTIAL (0%), 0 TODO (0%). Clean sweep — saropa's
dispose/mounted-check/print/empty-setState/long-function rules are all supersets of
flutter_doctor_ai's static checks.

| flutter_doctor_ai Rule | Status | Saropa Rule / Action |
|---|---|---|
| `large_build_method` | HAVE | `avoid_long_functions` |
| `empty_setstate` | HAVE | `avoid_empty_setstate` |
| `print_statement` | HAVE | `avoid_print_in_production` |
| `missing_mounted_check` | HAVE | `require_mounted_check_after_await` |
| `missing_dispose` | HAVE | `dispose_class_fields` / `dispose_widget_fields` |

## What You Gain

Beyond full coverage of flutter_doctor_ai's static rules, saropa_lints adds deterministic
IDE quick fixes for each of the mapped rules above, real-time squiggles, and 5 progressive
tiers — none of which flutter_doctor_ai's CLI-only architecture provides.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
