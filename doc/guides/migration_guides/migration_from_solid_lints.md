# Migrating from solid_lints

This guide helps you migrate from [`solid_lints`](https://pub.dev/packages/solid_lints)
(github.com/solid-software/solid_lints) to `saropa_lints`.

## Why Migrate?

| Feature | solid_lints | saropa_lints |
|---------|-------------|--------------|
| **Rule count** | 33 rules | 2300+ custom rules |
| **Focus** | SOLID principles, ISO/IEC & NIST-inspired code quality | Security, accessibility, performance, Flutter-specific patterns, plus general code quality |
| **Configuration** | Per-rule YAML options | 5 progressive tiers + rule packs |
| **Architecture** | Native `analysis_server_plugin` | Native `analysis_server_plugin` |
| **Flutter coverage** | A handful of widget-shape rules | Deep Flutter/GetX/Riverpod/Bloc/Provider/Firebase coverage |

Both packages have moved to the native `analysis_server_plugin` API (no `custom_lint`
runner required), so the migration is mostly a config swap, not an architecture change.

## Quick Migration

### Step 1: Update pubspec.yaml

```yaml
# Before
dev_dependencies:
  solid_lints: ^0.x.x

# After
dev_dependencies:
  saropa_lints: ^2.6.0
```

### Step 2: Update analysis_options.yaml

```yaml
# Before
analyzer:
  plugins:
    - solid_lints

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

## Choosing a Tier

solid_lints ships a flat rule set with per-rule opt-in/opt-out. saropa_lints uses
progressive tiers so you can start narrow and grow coverage over time:

| solid_lints Usage | saropa_lints Tier | Description |
|--------------------|--------------------|--------------|
| Default rule set | **Recommended** (~900 rules) | Balanced coverage, closest match to solid_lints' scope |
| Strict SOLID enforcement | **Professional** (~1600 rules) | Enterprise-grade, adds architecture rules |
| Everything enabled | **Comprehensive** (~2100 rules) | Quality obsessed |

**Start with `recommended`** — it covers solid_lints' code-quality and naming concerns
plus Flutter-specific rules solid_lints doesn't attempt.

## Rule Mapping

Coverage: 33 rules — 16 HAVE (48%), 3 PARTIAL, 14 TODO (42%)
current published rule set (33 rules as of this audit; verified directly against
`github.com/solid-software/solid_lints` `lib/main.dart`, not just documentation).

> **Note on rule count**: `plans/GAP_ANALYSIS.md` records an earlier audit of solid_lints
> at 31 rules (15 HAVE / 3 PARTIAL / 13 GAP). Re-verifying against the live upstream
> source for this guide found solid_lints now ships 33 rules — two more than the prior
> audit counted, both of which saropa_lints already covers by name-equivalent rule. The
> table below reflects the current 33-rule set.

| solid_lints Rule | Status | Saropa Rule / Action |
|---|---|---|
| `avoid_debug_print_in_release` | PARTIAL | `avoid_print_in_release` guards `print()`, not `debugPrint()` |
| `avoid_duplicate_code` | TODO | Cross-project AST clone detector — no saropa equivalent. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_duplicate_code.md) |
| `avoid_final_with_getter` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_final_with_getter.md) |
| `avoid_global_state` | HAVE | `avoid_global_state` |
| `avoid_late_keyword` | HAVE | `avoid_late_keyword` |
| `avoid_non_null_assertion` | HAVE | `avoid_non_null_assertion` |
| `avoid_returning_widgets` | TODO | Name collision only — saropa's same-named rule checks a different shape. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_returning_widgets_solid_lints_parity.md) |
| `avoid_similar_names` | TODO | Name collision only — saropa's same-named rule targets enum-indexed Map literals, not similar identifiers. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_avoid_similar_names_solid_lints_parity.md) |
| `avoid_unnecessary_return_variable` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_unnecessary_return_variable.md) |
| `avoid_unnecessary_setstate` | HAVE | `avoid_unnecessary_setstate` |
| `avoid_unnecessary_type_assertions` | HAVE | `avoid_unnecessary_type_assertions` |
| `avoid_unrelated_type_assertions` | HAVE | `avoid_unrelated_type_assertions` |
| `avoid_unused_parameters` | HAVE | `avoid_unused_parameters` |
| `avoid_using_api` | TODO | Generic config-driven banned-API mechanism — no equivalent. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_avoid_using_api.md) |
| `cyclomatic_complexity` | HAVE | `avoid_high_cyclomatic_complexity` |
| `double_literal_format` | HAVE | `double_literal_format` |
| `feature_envy` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_feature_envy.md) |
| `function_lines_of_code` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_function_lines_of_code.md) |
| `member_ordering` | PARTIAL | `prefer_member_ordering` is a flat 3-bucket order vs. solid_lints' fully configurable DSL |
| `named_parameters_ordering` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_named_parameters_ordering.md) |
| `newline_before_return` | TODO | TODO — see [proposal](../../../bugs/tier_1_quick_wins/proposal_newline_before_return.md) |
| `no_empty_block` | HAVE | `no_empty_block` |
| `no_equal_then_else` | HAVE | `no_equal_then_else` |
| `no_magic_number` | HAVE | `no_magic_number` |
| `number_of_parameters` | PARTIAL | `prefer_named_parameters` targets excess positional params, not a pure count ceiling |
| `prefer_conditional_expressions` | HAVE | `prefer_conditional_expressions` |
| `prefer_early_return` | HAVE | `prefer_early_return` |
| `prefer_first` | TODO | index-0 → `.first` — TODO, see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_first.md) |
| `prefer_last` | TODO | length-1 index → `.last` — TODO, see [proposal](../../../bugs/tier_1_quick_wins/proposal_prefer_last.md) |
| `prefer_match_file_name` | HAVE | `prefer_match_file_name` |
| `proper_super_calls` | HAVE | `proper_super_calls` |
| `use_descriptive_names_for_type_parameters` | TODO | TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_use_descriptive_names_for_type_parameters.md) |
| `use_nearest_context` | TODO | Effectively a gap — corresponds to a known saropa bug, see Known Issues below. TODO — see [proposal](../../../bugs/tier_2_high_value/proposal_extend_use_nearest_context_solid_lints_parity.md) |

## Known Issues

**`use_closest_build_context` is a silent no-op.** While auditing solid_lints'
`use_nearest_context` rule against saropa's nearest-`BuildContext` coverage, this audit
found that `UseClosestBuildContextRule`
(`lib/src/rules/core/context_rules.dart:1483`) is registered with a real `LintCode` but
its `runWithReporter` body is empty (`{}`) — the rule never reports anything. This is a
saropa-side bug independent of this migration guide and is tracked for a fix; it is
called out here so anyone relying on `use_closest_build_context` today knows it is
currently dormant.

## What You Gain

Rules solid_lints doesn't attempt, beyond raw rule count:

**Security**
- `avoid_hardcoded_credentials` — catches secrets in code
- `avoid_logging_sensitive_data` — PII protection
- `require_secure_storage` — SharedPreferences warnings
- `avoid_http_urls` — HTTPS enforcement

**Accessibility**
- `require_semantics_label` — screen reader support
- `avoid_small_touch_targets` — touch target sizing
- `avoid_color_only_indicators` — color blindness support

**State Management**
- `avoid_bloc_event_in_constructor` — Bloc anti-patterns
- `avoid_watch_in_callbacks` — Riverpod best practices
- `require_notify_listeners` — ChangeNotifier checks

**Lifecycle**
- `avoid_context_in_initstate_dispose` — prevents a common Flutter bug
- `require_dispose` — full resource disposal tracking

## What You Lose

solid_lints covers a few code-quality checks saropa_lints doesn't have a direct
equivalent for yet — see the TODO rows in the Rule Mapping table above, notably
`avoid_duplicate_code` (cross-file clone detection) and `avoid_using_api` (a generic
configurable banned-API engine). If these are load-bearing for your team, consider
keeping solid_lints installed alongside saropa_lints for just those rules until saropa
closes the gap.

## Suppressing Rules

The syntax is identical — both use underscores:

```dart
// solid_lints style
// ignore: avoid_returning_widgets

// saropa_lints style
// ignore: avoid_returning_widgets
```

Rule names may collide (see `avoid_returning_widgets` and `avoid_similar_names` in the
table above) — check the Rule Mapping table before assuming a suppressed solid_lints
rule and a saropa_lints rule of the same name check the same thing.

## Getting Help

- [GitHub Issues](https://github.com/saropa/saropa_lints/issues)
- [Full Documentation](https://pub.dev/packages/saropa_lints)

---

Questions about migrating? Open an issue - we're happy to help.
