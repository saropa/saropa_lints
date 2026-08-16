# BUG: Infra — 38 saropa_lints Rule Names Collide With Core Dart/Flutter Lint Names

**Status: Open**

Created: 2026-08-16
Rule: N/A (infra — affects `require_ignore_comment_plugin_prefix` and 38 individual rules, see list below)
File: `lib/src/rules/stylistic/formatting_rules.dart:1143` (`RequireIgnoreCommentPluginPrefixRule`)
Severity: High — namespace integrity violation; ZERO conflicts permitted (decision 2026-08-16)
Rule version: N/A | Since: unknown | Updated: 2026-08-16

---

## Summary

38 saropa_lints rules are registered under the exact same string ID as a well-known
core Dart/Flutter analyzer lint (`prefer_single_quotes`, `avoid_unused_constructor_parameters`,
`prefer_final_locals`, `avoid_void_async`, etc. — full list below). When a downstream
project enables both the core lint and the saropa_lints custom rule of the same name
(as `d:\src\contacts\analysis_options.yaml` does), a developer who writes a bare
`// ignore: prefer_single_quotes` — reasonably assuming they're suppressing the
well-known core Dart lint they've seen in every Dart project for years — is, per
`RequireIgnoreCommentPluginPrefixRule`'s own logic and warning message, NOT suppressing
the saropa_lints copy of that rule. The diagnostic keeps firing, and the developer gets
a confusing secondary warning telling them to prefix a name they had no reason to think
was plugin-owned.

This was discovered while auditing a downstream bulk-fix
(`d:\src\contacts` commit `4769670c25`, follow-up `510f3626bb`) that hand-classified
~230 "core, leave bare" rule names into a `CORE_RULES` set. 38 of those names turned out
to also be independently registered saropa_lints rules, discovered only by intersecting
the hand-compiled set against `tiers.getAllDefinedRules()`. The fix script had no way to
know this without extracting the live registry — the collision itself is the root
problem, not the downstream script.

---

## Attribution Evidence

**Positive — the meta-rule that produces the misleading guidance:**

```bash
grep -rn "'require_ignore_comment_plugin_prefix'" lib/src/rules/
# lib/src/rules/stylistic/formatting_rules.dart:1172:    'require_ignore_comment_plugin_prefix',
```

**Positive — all 38 colliding rule names, each independently registered in saropa_lints:**

```
avoid_classes_with_only_static_members       lib/src/rules/architecture/structure_rules.dart:2912
avoid_double_and_int_checks                  lib/src/rules/flow/control_flow_rules.dart:2421
avoid_escaping_inner_quotes                  lib/src/rules/stylistic/stylistic_rules.dart:4783
avoid_field_initializers_in_const_classes    lib/src/rules/core/class_constructor_rules.dart:1995
avoid_function_literals_in_foreach_calls     lib/src/rules/data/collection_rules.dart:3596
avoid_js_rounded_ints                        lib/src/rules/platforms/web_rules.dart:727
avoid_positional_boolean_parameters          lib/src/rules/code_quality/code_quality_avoid_rules.dart:4368
avoid_private_typedef_functions              lib/src/rules/data/type_rules.dart:2856
avoid_returning_null_for_future              lib/src/rules/flow/return_rules.dart:570
avoid_returning_null_for_void                lib/src/rules/flow/return_rules.dart:486
avoid_returning_this                         lib/src/rules/flow/return_rules.dart:141
avoid_setters_without_getters                lib/src/rules/architecture/structure_rules.dart:2995
avoid_shadowing_type_parameters              lib/src/rules/data/type_rules.dart:2779
avoid_single_cascade_in_expression_statements lib/src/rules/stylistic/stylistic_rules.dart:4862
avoid_types_on_closure_parameters            lib/src/rules/stylistic/stylistic_rules.dart:501
avoid_unnecessary_containers                 lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:5373
avoid_unused_constructor_parameters          lib/src/rules/core/class_constructor_rules.dart:1894
avoid_void_async                             lib/src/rules/core/async_rules.dart:5134
missing_code_block_language_in_doc_comment    lib/src/rules/core/documentation_rules.dart:1239
prefer_asserts_in_initializer_lists          lib/src/rules/core/class_constructor_rules.dart:2248
prefer_const_constructors_in_immutables      lib/src/rules/core/class_constructor_rules.dart:2382
prefer_const_declarations                    lib/src/rules/data/type_rules.dart:3054
prefer_const_literals_to_create_immutables   lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart:5442
prefer_constructors_over_static_methods      lib/src/rules/architecture/structure_rules.dart:3767
prefer_double_quotes                         lib/src/rules/stylistic/stylistic_additional_rules.dart:247
prefer_final_fields                          lib/src/rules/core/class_constructor_rules.dart:2658
prefer_final_locals                          lib/src/rules/data/type_rules.dart:2907
prefer_if_elements_to_conditional_expressions lib/src/rules/flow/control_flow_rules.dart:2502
prefer_initializing_formals                  lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart:843
prefer_inlined_adds                          lib/src/rules/data/collection_rules.dart:3655
prefer_null_aware_method_calls               lib/src/rules/flow/control_flow_rules.dart:2546
prefer_relative_imports                      lib/src/rules/stylistic/stylistic_rules.dart:95
prefer_single_quotes                         lib/src/rules/stylistic/stylistic_rules.dart:1985
secure_pubspec_urls                          lib/src/rules/config/config_rules.dart:1242
sort_pub_dependencies                        lib/src/rules/config/config_rules.dart:1093
unintended_html_in_doc_comment               lib/src/rules/core/documentation_rules.dart:1329
unnecessary_library_name                     lib/src/rules/architecture/structure_rules.dart:4667
use_truncating_division                      lib/src/rules/stylistic/stylistic_rules.dart:5199
```

Generated by intersecting a hand-scraped `set()` of ~230 known-core Dart/Flutter/analyzer
lint names against `grep -rhA1 "= LintCode($" lib/src/rules/` (2335 registered saropa_lints
rule names, extracted 2026-08-16). All 38 have real `LintCode('<name>', ...)` registrations
above, not string literals from unrelated contexts (`conflictingRules` list-of-strings
mentions were explicitly excluded from the grep).

**Live-config confirmation (downstream, `d:\src\contacts\analysis_options.yaml`):**
Both the core rule and the saropa_lints rule are simultaneously enabled for at least
`prefer_single_quotes`, `avoid_unused_constructor_parameters`, and `prefer_final_locals`
— one under the plain `linter: rules:` section, the other under the `custom_lint:`
plugin config section with an inline `[SEVERITY] ...` comment characteristic of
saropa_lints' generated rule descriptions.

---

## Reproducer

```dart
// analysis_options.yaml has BOTH enabled (as contacts does):
//   linter: rules: { prefer_single_quotes: true }
//   custom_lint: ... saropa_lints: { prefer_single_quotes: true }

class Example {
  void method() {
    final String s = "double quoted"; // VIOLATES both the core rule AND the saropa_lints rule
  }
}
```

Developer, unaware saropa_lints reimplements this exact rule name, writes the ignore
comment they've written in every other Dart project for years:

```dart
// ignore: prefer_single_quotes
final String s = "double quoted";
```

Per `RequireIgnoreCommentPluginPrefixRule`'s own stated behavior (see Root Cause), the
saropa_lints copy of `prefer_single_quotes` is NOT suppressed by this bare comment — only
the core analyzer's copy is. The developer now sees a `require_ignore_comment_plugin_prefix`
warning telling them their perfectly standard, decade-old idiom is wrong, with no
indication that the "real" reason is a same-name collision they have no way to discover
without reading saropa_lints source.

**Frequency:** Always, for any of the 38 listed names, in any project where both the
core lint and the saropa_lints rule are enabled together.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | saropa_lints NEVER reuses a core Dart/Flutter lint's exact string ID — zero conflicts permitted |
| **Actual** | 38 names silently collide, producing duplicate diagnostics and confusing `require_ignore_comment_plugin_prefix` warnings on standard ignore comments |

---

## Root Cause

38 rule authors independently chose string IDs that already belong to core
Dart/Flutter/`package:lints`, without a uniqueness check against the standard lint namespace
at rule-registration time. Whether intentional (extending a core rule) or accidental is moot —
zero conflicts is the policy regardless of intent.

---

## Decided Fix

**Rename 35 colliding rules** with semantic suffixes that describe what differentiates
the saropa_lints version from the core Dart lint. **Drop 3 rules** that add nothing
beyond the core lint. Decision made 2026-08-16.

### Naming convention

Use a **semantic suffix** — NOT a blanket `saropa_` prefix. The new name should reflect
what the saropa version adds or enforces beyond the core rule.

Example: `prefer_single_quotes` → `prefer_single_quotes_strict`

Common suffix patterns:
- `_strict` — saropa version is stricter / catches more cases
- `_with_fix` — saropa version adds a quick fix the core rule lacks
- `_extended` — saropa version covers additional AST patterns
- `_enforced` — saropa version elevates severity or scope
- `_relaxed` — saropa version is more lenient / fewer false positives
- `_safe` — saropa version adds safety analysis before flagging

### Rename map (38 rules)

| # | Current name | New name | Suffix rationale |
|---|---|---|---|
| 1 | `avoid_classes_with_only_static_members` | `avoid_classes_with_only_static_members_with_fix` | adds `AddAbstractFinalFix` |
| 2 | `avoid_double_and_int_checks` | `avoid_double_and_int_checks_extended` | two diagnostic codes (always-false vs prefer-num) + fix |
| 3 | `avoid_escaping_inner_quotes` | `avoid_escaping_inner_quotes_with_fix` | adds `SwapStringDelimiterFix` |
| 4 | `avoid_field_initializers_in_const_classes` | `avoid_field_initializers_in_const_classes_relaxed` | skips simple literal initializers |
| 5 | `avoid_function_literals_in_foreach_calls` | `avoid_function_literals_in_foreach_calls_no_maps` | skips Map types (for-in requires `.entries`) |
| 6 | `avoid_js_rounded_ints` | `avoid_js_rounded_ints_extended` | handles negative integer literals |
| 7 | `avoid_positional_boolean_parameters` | `avoid_positional_boolean_parameters_with_fix` | adds `ConvertToNamedBoolParamFix` |
| 8 | `avoid_private_typedef_functions` | **DROP** | no behavioral difference from core lint |
| 9 | `avoid_returning_null_for_future` | `avoid_returning_null_for_future_strict` | guards nullable `Future<T>?` + revived deprecated rule + fix |
| 10 | `avoid_returning_null_for_void` | `avoid_returning_null_for_void_with_fix` | adds `ReplaceReturnNullWithReturnFix` |
| 11 | `avoid_returning_this` | `avoid_returning_this_with_fix` | adds `ReplaceReturnThisWithReturnFix` |
| 12 | `avoid_setters_without_getters` | `avoid_setters_without_getters_local` | checks same class body only, not inherited |
| 13 | `avoid_shadowing_type_parameters` | `avoid_shadowing_type_parameters_class_methods` | class→method shadowing only |
| 14 | `avoid_single_cascade_in_expression_statements` | `avoid_single_cascade_in_expression_statements_with_fix` | adds `ReplaceSingleCascadeWithDotFix` |
| 15 | `avoid_types_on_closure_parameters` | `avoid_types_on_closure_parameters_with_fix` | adds `RemoveClosureParameterTypeFix` |
| 16 | `avoid_unnecessary_containers` | `avoid_unnecessary_containers_resolved` | uses resolved type info, not name matching |
| 17 | `avoid_unused_constructor_parameters` | `avoid_unused_constructor_parameters_skip_private` | skips private params, regex-based usage detection |
| 18 | `avoid_void_async` | `avoid_void_async_extended` | lifecycle/test method exemptions + @override skip + fix |
| 19 | `missing_code_block_language_in_doc_comment` | **DROP** | no behavioral difference from core lint |
| 20 | `prefer_asserts_in_initializer_lists` | `prefer_asserts_in_initializer_lists_safe` | safety analysis prevents invalid moves |
| 21 | `prefer_const_constructors_in_immutables` | `prefer_const_constructors_in_immutables_extended` | treats Widget subclasses as implicitly @immutable |
| 22 | `prefer_const_declarations` | `prefer_const_declarations_with_fix` | adds quick fix, conservative const-expression check |
| 23 | `prefer_const_literals_to_create_immutables` | `prefer_const_literals_to_create_immutables_widget_scoped` | widget files only, Widget hierarchy only |
| 24 | `prefer_constructors_over_static_methods` | `prefer_constructors_over_static_methods_strict` | expression-body only, same-class return only |
| 25 | `prefer_double_quotes` | `prefer_double_quotes_with_fix` | adds quick fix |
| 26 | `prefer_final_fields` | `prefer_final_fields_with_fix` | adds quick fix, conservative with part files |
| 27 | `prefer_final_locals` | `prefer_final_locals_with_fix` | adds quick fix, element-identity reassignment detection |
| 28 | `prefer_if_elements_to_conditional_expressions` | `prefer_if_elements_to_conditional_expressions_null_branch` | only flags ternaries where one branch is null |
| 29 | `prefer_initializing_formals` | **DROP** | no behavioral difference from core lint |
| 30 | `prefer_inlined_adds` | `prefer_inlined_adds_strict` | consecutive statements only, no cross-block |
| 31 | `prefer_null_aware_method_calls` | `prefer_null_aware_method_calls_extended` | also catches if-statement form, not just ternaries |
| 32 | `prefer_relative_imports` | `prefer_relative_imports_enforced` | equivalent detection, opinionated/optional |
| 33 | `prefer_single_quotes` | `prefer_single_quotes_strict` | also checks interpolated strings + fix |
| 34 | `secure_pubspec_urls` | `secure_pubspec_urls_strict` | security-scoped check with CWE-494 mapping |
| 35 | `sort_pub_dependencies` | `sort_pub_dependencies_extended` | also checks dependency_overrides section |
| 36 | `unintended_html_in_doc_comment` | `unintended_html_in_doc_comment_strict` | skips code blocks/spans, safe-HTML-tag whitelist |
| 37 | `unnecessary_library_name` | `unnecessary_library_name_with_fix` | adds `RemoveLibraryNameFix` |
| 38 | `use_truncating_division` | `use_truncating_division_strict` | WARNING severity (core uses INFO) |

### Deprecation path

Old names kept as deprecated aliases for one release cycle. The `--fix-ignores` migration
tool updated to handle the rename in downstream `analysis_options.yaml` and ignore comments.

### Downstream impact

Breaking change across every downstream project's `analysis_options.yaml` and existing
ignore comments. The deprecation alias + `--fix-ignores` migration tool are the mitigation.

### Guard rail

Add a test that intersects `tiers.getAllDefinedRules()` against a maintained set of known
core Dart/Flutter lint names. Fails CI if any new collision is introduced.

---

## Fixture Gap

Add a test that validates zero intersection between saropa_lints rule names and the known
core Dart/Flutter lint namespace.

---

## Changes Made

None — filed for triage, no fix applied.

---

## Tests Added

None.

---

## Commits

None yet.

---

## Environment

- saropa_lints version: local checkout at `d:\src\saropa_lints` (working tree currently has
  an unrelated pre-existing compile error in `lib/src/rules/widget/build_method_rules.dart`
  around line 288 — not caused by this investigation, not touched)
- Dart SDK: project default (`d:\src\contacts` / `d:\src\saropa_lints`)
- custom_lint version: per `d:\src\contacts\pubspec.yaml`
- Triggering project: `d:\src\contacts`, `analysis_options.yaml`, multiple files under `lib/`
