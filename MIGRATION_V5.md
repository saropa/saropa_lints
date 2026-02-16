# Migration Guide: v4 to v5

saropa_lints v5 migrates from `custom_lint` to the native Dart analyzer plugin system introduced in Dart 3.10.

## Why Migrate?

- **Quick fixes work in IDE** - the old system never delivered fix requests to custom_lint plugins
- **`dart analyze` integration** - no more `dart run custom_lint`
- **`dart fix --apply` support** - automated fixes work natively
- **Better IDE performance** - no separate isolate overhead

## Step 1: Update Dependencies

In your `pubspec.yaml`:

```yaml
# BEFORE (v4):
dev_dependencies:
  saropa_lints: ^4.15.0
  custom_lint: ^0.7.0

# AFTER (v5):
dev_dependencies:
  saropa_lints: ^5.0.0
```

Remove `custom_lint` from your dependencies. The native plugin system is built into the Dart SDK.

## Step 2: Update analysis_options.yaml

### Option A: Use a Tier Preset (Recommended)

Replace the old `custom_lint:` section with a tier include:

```yaml
# BEFORE (v4):
include: package:saropa_lints/tiers/recommended.yaml
custom_lint:
  rules:
    avoid_debug_print: true

# AFTER (v5):
include: package:saropa_lints/tiers/recommended.yaml
```

Available presets:
- `package:saropa_lints/tiers/essential.yaml` - Critical rules (~50)
- `package:saropa_lints/tiers/recommended.yaml` - Default tier (~150)
- `package:saropa_lints/tiers/professional.yaml` - Enterprise (~250)
- `package:saropa_lints/tiers/comprehensive.yaml` - Thorough (~400)
- `package:saropa_lints/tiers/pedantic.yaml` - All rules

### Option B: Use the Init Command

Regenerate your configuration:

```bash
dart run saropa_lints:init --tier comprehensive
```

This generates explicit `plugins: saropa_lints: diagnostics:` entries for all rules.

### Option C: Manual Configuration

Replace the `custom_lint:` section with `plugins:`:

```yaml
# BEFORE (v4):
custom_lint:
  enable_all_lint_rules: false
  rules:
    - avoid_debug_print: true
    - require_dispose: true
    - no_magic_number: false

# AFTER (v5):
plugins:
  saropa_lints:
    diagnostics:
      avoid_debug_print: true
      require_dispose: true
      no_magic_number: false
```

Key format changes:
- `custom_lint:` -> `plugins: saropa_lints:`
- `rules:` -> `diagnostics:`
- `- rule_name: true` -> `rule_name: true` (no list prefix)
- Remove `enable_all_lint_rules` (lint rules are disabled by default in v5)
- Severity overrides: `rule_name: warning` / `rule_name: error` / `rule_name: info`

## Step 3: Update Ignore Comments

```dart
// BEFORE (v4):
// ignore: avoid_debug_print

// AFTER (v5):
// ignore: saropa_lints/avoid_debug_print
```

The native system namespaces diagnostics with the plugin name.

## Step 4: Run Analysis

```bash
# BEFORE (v4):
dart run custom_lint

# AFTER (v5):
dart analyze
```

## Step 5: Custom Settings (Optional)

Per-project settings in `analysis_options_custom.yaml` continue to work:

```yaml
# Severity overrides
severities:
  avoid_debug_print: ERROR
  no_magic_number: false

# Baseline suppression
baseline:
  paths:
    - "lib/legacy/"

# Output control
max_issues: 500
output: both
```

## Breaking Changes

| Change | v4 | v5 |
|--------|-----|-----|
| Plugin system | `custom_lint` | Native analyzer plugin |
| Configuration | `custom_lint: rules:` | `plugins: saropa_lints: diagnostics:` |
| Run command | `dart run custom_lint` | `dart analyze` |
| Fix command | Not supported | `dart fix --apply` |
| Ignore format | `// ignore: rule_name` | `// ignore: saropa_lints/rule_name` |
| Rule defaults | All enabled | All disabled (must opt-in) |
| Dependencies | `custom_lint: ^0.7.0` | None (built-in) |

## Troubleshooting

### Rules not appearing?

1. Ensure `saropa_lints: ^5.0.0` is in `dev_dependencies`
2. Ensure rules are enabled in `diagnostics:` section (they're disabled by default)
3. Restart the IDE after changing `analysis_options.yaml`

### Quick fixes not appearing?

1. Ensure you're using Dart SDK 3.10+
2. Restart the analysis server: Cmd/Ctrl+Shift+P -> "Dart: Restart Analysis Server"

### Old `custom_lint` errors?

Remove `custom_lint` from your `pubspec.yaml` and delete `lib/custom_lint_client.dart` if it exists.
