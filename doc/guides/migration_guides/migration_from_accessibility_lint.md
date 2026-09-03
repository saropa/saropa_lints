# Migrating from accessibility_lint

This guide helps you migrate from [`accessibility_lint`](https://pub.dev/packages/accessibility_lint)
(github.com/MateuxLucax/accessibility-lint) to `saropa_lints`.

> **This package is abandoned.** The `accessibility_lint` repository has been archived
> by its author and receives no bug fixes, security patches, or Dart SDK compatibility
> updates. It will break on a future Dart or Flutter release with no upstream fix
> available. Remove it from your `pubspec.yaml` and migrate to an actively maintained
> alternative.

## Why Migrate?

| Feature | accessibility_lint | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 5 rules | 2300+ custom rules |
| **Focus** | Immediate accessibility checks: tooltips, semantic labels, touch targets | Full accessibility suite plus security, performance, and Flutter-specific patterns |
| **Maintenance** | **Archived — no longer maintained** | Actively maintained |
| **Configuration** | Flat rule set | 5 progressive tiers + rule packs |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  accessibility_lint: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - accessibility_lint

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

Coverage: 5 rules — 4 HAVE (80%), 1 PARTIAL

| accessibility_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_icon_button_without_tooltip` | HAVE | `avoid_icon_buttons_without_tooltip` |
| `add_haptic_feedback_on_user_interaction` | PARTIAL | `prefer_ios_haptic_feedback` — scoped to iOS/Taptic-important interactions, narrower trigger surface than accessibility_lint's blanket check on all 4 listed widget types |
| `avoid_icon_without_semantic_label` | HAVE | `require_semantic_label_icons` |
| `avoid_image_without_semantic_label` | HAVE | `require_image_semantics` |
| `avoid_small_interactive_elements` | HAVE | `avoid_small_touch_targets` |

## What You Gain

`accessibility_lint`'s repo is archived — no bug fixes, no new rules. Beyond the 1:1
mapping above, saropa_lints ships deep additional accessibility coverage
(`avoid_color_only_indicators`, `require_heading_semantics`, `avoid_merged_semantics_hiding_info`,
and more) plus security, performance, and 5 major state-management library integrations
that accessibility_lint never attempted.

## Suppressing Rules

The syntax is identical — both use underscores:

```dart
// accessibility_lint style
// ignore: avoid_small_interactive_elements

// saropa_lints style
// ignore: avoid_small_touch_targets
```

Note the rule names differ even where the check is equivalent — update `// ignore:`
comments to the new saropa rule names when migrating.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
