# Migrating from pyramid_lint

This guide helps you migrate from `pyramid_lint` to `saropa_lints`.

## Why Migrate?

| Feature | pyramid_lint | saropa_lints |
|---------|--------------|--------------|
| **Rule count** | 36 rules | 2300+ custom rules |
| **Focus** | Curated Dart + Flutter correctness/style set | Full-spectrum security, accessibility, performance, and library-specific analysis |
| **Configuration** | Enable individually | 5 progressive tiers |
| **Implementation quality** | High — real quick-fixes, precise `TypeChecker`-based type checking | High — quick-fixes on 221+ rules, mix of type-checking and AST pattern matching |

**Note**: pyramid_lint is small but well-built — most rules ship real quick-fixes and use the analyzer's `TypeChecker` rather than string matching, so a handful of its checks (e.g. `dispose_controllers`) catch cases saropa's fixed-enumeration equivalents miss. See PARTIAL rows below.

## Architecture Differences

Like mad_lint, pyramid_lint is built on `analysis_server_plugin`/`AnalysisRule` — the official Dart analyzer plugin system. It installs as an `analyzer.plugins` entry, not through `custom_lint`.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  pyramid_lint: ^0.8.0

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - pyramid_lint

# After
analyzer:
  plugins:
    - saropa_lints
```

Then generate the configuration:

```bash
dart run saropa_lints:init --tier recommended
```

## Rule Mapping

Coverage: 25 HAVE (68%), 4 PARTIAL (11%), 8 TODO (22%) — audited against the pyramid_lint docs sidebar (`docs.json`), which lists 37 rules (22 Dart + 15 Flutter); the package's own published total is 36.

### Dart Lints

| pyramid_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `always_put_doc_comments_before_annotations` | TODO | TODO — no proposal filed yet |
| `always_specify_parameter_names` | TODO | TODO — no proposal filed yet |
| `avoid_dynamic` | HAVE | `avoid_dynamic_type` |
| `avoid_empty_blocks` | HAVE | `no_empty_block` |
| `avoid_mutable_global_variables` | HAVE | `avoid_global_state` |
| `avoid_positional_fields_in_records` | HAVE | `avoid_positional_record_field_access` |
| `avoid_unused_parameters` | HAVE | `avoid_unused_parameters` |
| `class_members_ordering` | HAVE | `prefer_member_ordering` |
| `max_lines_for_file` | HAVE | `avoid_long_length_files` / `avoid_very_long_length_files` |
| `max_lines_for_function` | HAVE | `avoid_long_functions` |
| `no_duplicate_imports` | PARTIAL | `avoid_duplicate_named_imports` — pyramid catches byte-identical duplicate imports regardless of prefix; unclear whether saropa's rule also fires on a verbatim duplicate with no prefix at all. TODO — no proposal filed yet |
| `no_self_comparisons` | HAVE | `avoid_self_compare` |
| `prefer_async_await` | HAVE | `prefer_async_await` |
| `prefer_iterable_any` | TODO | TODO — no proposal filed yet (`.where().isNotEmpty` → `.any()`; saropa's similarly-named `prefer_any_or_every` is a false cognate — it targets explicit-null named arguments, not iterable-chain rewrites) |
| `prefer_iterable_every` | TODO | TODO — no proposal filed yet (same false-cognate note as `prefer_iterable_any`) |
| `prefer_iterable_first` | HAVE | `prefer_list_first` |
| `prefer_iterable_last` | HAVE | `prefer_list_last` |
| `prefer_library_prefixes` | TODO | TODO — no proposal filed yet |
| `prefer_new_line_before_return` | HAVE | `NewlineBeforeReturnRule` |
| `prefer_underscore_for_unused_callback_parameters` | HAVE | `prefer_wildcard_for_unused_param` |
| `proper_from_environment` | TODO | TODO — no proposal filed yet |
| `unnecessary_nullable_return_type` | HAVE | `avoid_unnecessary_nullable_return_type` |

### Flutter Lints

| pyramid_lint Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_public_members_in_states` | TODO | TODO — no proposal filed yet |
| `avoid_single_child_in_flex` | TODO | TODO — no proposal filed yet |
| `dispose_controllers` | PARTIAL | `require_form_field_controller` — pyramid's is type-checker-based (any disposable-typed field); saropa's is a fixed enumeration of known controller types, so a novel custom controller type would be missed by saropa but caught by pyramid. TODO — no proposal filed yet |
| `prefer_async_callback` | HAVE | `prefer_async_callback` |
| `prefer_border_from_border_side` | HAVE | `avoid_border_all` |
| `prefer_border_radius_all` | PARTIAL | `prefer_borderradius_circular` — same subject, contradictory prescribed style (saropa recommends `.circular()` over `.all()`, pyramid recommends the opposite). TODO — no proposal filed yet |
| `prefer_dedicated_media_query_functions` | PARTIAL | `avoid_deprecated_use_inherited_media_query` — TODO extend, see [proposal](../../../bugs/proposal_extend_avoid_deprecated_use_inherited_media_query_dcm_parity.md) |
| `prefer_text_rich` | HAVE | `prefer_text_rich` |
| `prefer_void_callback` | HAVE | `prefer_void_callback` |
| `proper_edge_insets_constructors` | HAVE | `prefer_correct_edge_insets_constructor` |
| `proper_expanded_and_flexible` | HAVE | `avoid_flexible_outside_flex` |
| `proper_super_dispose` | HAVE | `proper_super_calls` |
| `proper_super_init_state` | HAVE | `proper_super_calls` |
| `specify_icon_button_tooltip` | HAVE | `avoid_icon_buttons_without_tooltip` |
| `use_spacer` | HAVE | `avoid_expanded_as_spacer` |

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
