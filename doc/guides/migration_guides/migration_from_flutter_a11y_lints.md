# Migrating from flutter_a11y_lints

This guide helps you migrate from [`flutter_a11y_lints`](https://pub.dev/packages/flutter_a11y_lints) to `saropa_lints`.

## Why Migrate?

| Feature | flutter_a11y_lints | saropa_lints |
|---------|---------------------|--------------|
| **Rule count** | 12 shipped rules (27 documented, 15 unimplemented) | 2300+ custom rules, dozens accessibility-focused |
| **Focus** | Accessibility only, via a `SemanticNode` IR tree | Broad Dart/Flutter analysis incl. deep accessibility coverage |
| **Configuration** | `custom_lint` plugin | 5 progressive tiers |
| **Maintenance** | Small, single-purpose package | Actively maintained, broad scope |
| **Cost** | Free & open source | Free & open source |

`flutter_a11y_lints` documents 27 accessibility rules (`A01`–`A22`+) but only 12 are actually compiled into the shipped rule bundle. saropa_lints has substantial, independently-developed accessibility coverage (semantics labels, touch targets, focus, contrast) that overlaps heavily with the shipped rules, plus a stronger baseline on several (e.g. images require a semantic label unconditionally, not only when detected as "informative").

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  flutter_a11y_lints: ^1.0.0

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
    - flutter_a11y_lints

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

## Rule Mapping

Coverage: 3 HAVE (25%), 2 PARTIAL (17%), 7 TODO (58%) — 12 rules actually shipped by flutter_a11y_lints (27 are documented but only 12 are compiled into the bundle).

| flutter_a11y_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `A01` — interactive control must have an accessible label | HAVE | `require_button_semantics` |
| `A02` — label contains redundant role words ("button"/"icon") | TODO | TODO — see [proposal](../../../bugs/proposal_a02_redundant_role_words.md). |
| `A03` — decorative images should be excluded from semantics | PARTIAL | `require_image_semantics` / `require_accessible_images` require a `semanticLabel` on every `Image` (stricter overall) but don't specifically suggest `excludeFromSemantics: true` for likely-decorative images by filename heuristic. |
| `A04` — informative images must provide semantic labels | HAVE | `require_image_semantics` / `require_accessible_images` |
| `A05` — remove redundant `Semantics(button: true)` wrapper on a primitive button | TODO | TODO — see [proposal](../../../bugs/proposal_a05_redundant_semantics_button_wrapper.md). |
| `A06` — interactive control with multiple semantic parts should use `MergeSemantics` | HAVE | `prefer_merge_semantics` |
| `A07` — `Semantics()` label replacement must exclude children (prevents double announcement) | TODO | TODO — see [proposal](../../../bugs/proposal_a07_semantics_label_excludes_children.md). |
| `A09` — numeric-only label missing units | TODO | TODO — see [proposal](../../../bugs/proposal_a09_numeric_label_missing_units.md). |
| `A13` — composite control should present a single semantic role (2+ focusable descendants) | TODO | TODO — see [proposal](../../../bugs/proposal_a13_composite_control_single_role.md). |
| `A15` — custom gesture recognizer should surface a semantic action | PARTIAL | `require_button_semantics` flags `GestureDetector`/`InkWell` missing a `Semantics(button: true)` wrapper generally, but doesn't map non-tap gestures (long-press, double-tap) to distinct semantic actions the way `A15` does. |
| `A21` — use `IconButton.tooltip` instead of wrapping with `Tooltip` | TODO | TODO — see [proposal](../../../bugs/proposal_a21_prefer_iconbutton_tooltip.md). |
| `A22` — avoid `MergeSemantics` on the `ListTile` family (double-announcement) | TODO | TODO — see [proposal](../../../bugs/proposal_avoid_merge_semantics_list_tile.md) |

## What You Gain

saropa_lints' accessibility coverage extends well beyond the 12 shipped `flutter_a11y_lints` rules:

- `require_semantics_label`, `require_heading_semantics`, `require_semantic_label_icons` — broader semantics coverage across widget types, not limited to images and buttons
- `avoid_small_touch_targets` — touch target sizing (not covered by `flutter_a11y_lints` at all)
- `avoid_gesture_only_interactions` — keyboard/switch-control accessibility for `GestureDetector`
- `require_focus_indicator` — visible focus indicators for keyboard navigation
- `require_autofill_hints` — form field autofill accessibility

## What You Lose

`flutter_a11y_lints`'s `SemanticNode` IR tree drives a handful of nuanced checks saropa_lints doesn't replicate yet: redundant role words in labels (`A02`), numeric-value unit requirements (`A09`), composite-control single-role enforcement (`A13`), and the `Tooltip`-vs-`IconButton.tooltip` distinction (`A21`). If these matter to your project, keep `flutter_a11y_lints` running alongside saropa_lints — the two plugins don't conflict.

```yaml
# analysis_options.yaml — running both
analyzer:
  plugins:
    - flutter_a11y_lints
    - custom_lint
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
