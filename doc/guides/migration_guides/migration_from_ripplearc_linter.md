# Migrating from ripplearc_linter

This guide helps you migrate from [`ripplearc_linter`](https://pub.dev/packages/ripplearc_linter) to `saropa_lints`.

## Why Migrate?

| Feature | ripplearc_linter | saropa_lints |
|---------|-------------------|--------------|
| **Rule count** | 24 rules | 2300+ custom rules |
| **Focus** | One company's internal code-quality and strict-testing conventions, open-sourced as-is | Security, accessibility, performance, and 2300+ Flutter-specific patterns |
| **Configuration** | Flat rule list | 5 progressive tiers |
| **Applicability** | Many rules encode one team's specific conventions (a DI framework's API, a doc-comment policy, an issue-tracker URL pattern) | Broadly applicable across projects |

**Note**: Most of `ripplearc_linter`'s gaps below are single-company internal conventions — specific class names, one DI framework's `Modular.get<T>()` API, one issue-tracker's URL pattern — rather than rules with broad applicability. If your team shares these exact conventions (Modular DI, a `coreui` icon package, YouTrack story links), keep `ripplearc_linter` installed alongside `saropa_lints`.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  ripplearc_linter: ^1.0.0

# After
dev_dependencies:
  custom_lint: ^0.8.0
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
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

Coverage: 5 HAVE (21%), 4 PARTIAL (17%), 15 TODO (62%).

| ripplearc_linter Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_static_colors` | HAVE | `avoid_hardcoded_colors` |
| `avoid_static_typography` | PARTIAL | No saropa rule bans raw `TextStyle()` in favor of a theme-extension typography access — TODO, no proposal filed yet |
| `avoid_test_timeouts` | HAVE | `require_integration_test_timeout` |
| `document_enum` | TODO | TODO — no proposal filed yet |
| `document_fake_parameters` | TODO | TODO — no proposal filed yet |
| `document_interface` | TODO | TODO — no proposal filed yet |
| `forbid_datetime_now` | PARTIAL | `avoid_datetime_now_in_tests` — only covers test files, not "always inject a Clock in production code" |
| `forbid_forced_unwrapping` | HAVE | `avoid_non_null_assertion` |
| `forbid_helper_util_naming` | TODO | TODO — no proposal filed yet |
| `forbid_manual_screenshot_theme` | TODO | TODO — no proposal filed yet (project-specific golden-test convention) |
| `forbid_modular_get_outside_module` | PARTIAL | `avoid_service_locator_in_widgets` — narrower, widgets only |
| `forbid_raw_icon_and_image_usage` | TODO | TODO — no proposal filed yet |
| `no_direct_instantiation` | TODO | TODO — no proposal filed yet |
| `no_internal_method_docs` | TODO | TODO — no proposal filed yet |
| `no_optional_operators_in_tests` | TODO | TODO — no proposal filed yet |
| `prefer_fake_over_mock` | PARTIAL | `prefer_fake_over_mock` exists but its doc describes "excessive mocking" generally, not specifically the `extends Mock` → `extends Fake` pattern — needs verification |
| `prevent_feature_module_dependencies` | TODO | TODO — no proposal filed yet |
| `prevent_library_module_dependencies` | TODO | TODO — no proposal filed yet |
| `private_subject` | TODO | TODO — no proposal filed yet |
| `restrict_core_icon_data` | TODO | TODO — no proposal filed yet |
| `sealed_over_dynamic` | HAVE | `prefer_switch_with_sealed_classes` |
| `specific_exception_types` | HAVE | `avoid_catch_all` / `avoid_catching_generic_exception` |
| `test_file_mutation_coverage` | TODO | TODO — no proposal filed yet |
| `todo_with_story_links` | TODO | TODO — no proposal filed yet. The general "TODO must reference a ticket" concept has no saropa equivalent either, even setting aside the YouTrack-specific URL pattern. |

## Suppressing Rules

```dart
// ripplearc_linter style
// ignore: avoid_static_colors

// saropa_lints style
// ignore: avoid_hardcoded_colors
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
