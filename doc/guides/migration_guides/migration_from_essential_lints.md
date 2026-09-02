# Migrating from essential_lints

This guide helps you migrate from [`essential_lints`](https://pub.dev/packages/essential_lints) to `saropa_lints`.

## Why Migrate?

| Feature | essential_lints | saropa_lints |
|---------|-------------------|--------------|
| **Rule count** | 31 rules (27 in `rules/`, 4 in `warnings/`) | 2300+ custom rules |
| **Focus** | Logical safety and function/member-ordering design, with quick fixes and code assists | Security, accessibility, performance, and 2300+ Flutter-specific patterns |
| **Architecture** | Native `analysis_rule` API | `custom_lint` plugin |
| **Configuration** | Flat rule list | 5 progressive tiers |

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  essential_lints: ^1.0.0

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

Coverage: 9 HAVE (29%), 5 PARTIAL (16%), 17 TODO (55%).

| essential_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `alphabetize_arguments` | TODO | TODO — no proposal filed yet |
| `alphabetize_enum_constants` | TODO | TODO — no proposal filed yet |
| `ambiguous_positional_boolean` | HAVE | `avoid_positional_boolean_parameters_with_fix` |
| `boolean_assignment` | HAVE | `avoid_assignments_as_conditions` |
| `border_all` | TODO | TODO — no proposal filed yet |
| `border_radius_all` | PARTIAL | `prefer_const_border_radius` — targets const-ness, not the `.all` vs. `.circular` API choice |
| `closure_incorrect_type` | TODO | TODO — no proposal filed yet |
| `completer_error_no_stack` | HAVE | `avoid_missing_completer_stack_trace` |
| `duplicate_value` | TODO | TODO — no proposal filed yet. Their rule flags duplicate values within one boolean expression, distinct from saropa's cross-branch `no_equal_conditions`. |
| `empty_container` | TODO | TODO — no proposal filed yet |
| `equal_statement` | PARTIAL | Likely overlaps `no_equal_switch_case`, not fully confirmed as identical trigger logic |
| `explicit_casts` | PARTIAL | `avoid_unsafe_cast` — only flags casts that can fail at runtime, narrower than "all explicit casts" |
| `first_getter` | HAVE | `prefer_list_first` |
| `getters_in_member_list` | TODO | TODO — no proposal filed yet |
| `is_future` | TODO | TODO — no proposal filed yet |
| `last_getter` | HAVE | `prefer_list_last` |
| `mutable_tearoff` | TODO | TODO — no proposal filed yet |
| `new_instance_cascade` | TODO | TODO — no proposal filed yet |
| `optional_positional_parameters` | HAVE | `prefer_optional_positional_params` |
| `padding_over_container` | HAVE | `prefer_padding_over_container` |
| `pending_listener` | PARTIAL | saropa's disposal-family rules (e.g. `always_remove_listener`) are type-specific, not a general "any `add()`-style listener needs a matching `remove()`" check |
| `prefer_explicitly_named_parameters` | TODO | TODO — no proposal filed yet |
| `returning_widgets` | TODO | TODO — no proposal filed yet |
| `same_package_direct_import` | HAVE | `prefer_relative_imports_enforced` |
| `sorting_members` | TODO | TODO — no proposal filed yet (own annotation-driven member-sort system) |
| `standard_comment_style` | TODO | TODO — no proposal filed yet |
| `subtype_annotating` | TODO | TODO — no proposal filed yet |
| `subtype_naming` | TODO | TODO — no proposal filed yet |
| `unnecessary_setstate` | PARTIAL | `avoid_empty_setstate` — only catches empty-callback-body, not the broader "assigns the same value" no-op case |
| `useless_else` | HAVE | `avoid_redundant_else` |
| `variable_shadowing` | TODO | TODO — no proposal filed yet |

## Suppressing Rules

```dart
// essential_lints style
// ignore: useless_else

// saropa_lints style
// ignore: avoid_redundant_else
```

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
