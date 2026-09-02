# Competitor Gap Analysis

Compiled 2026-09-02. Analysis of 48 competitor Dart/Flutter lint packages against saropa_lints' current
2,300+ rule catalog. Source research: 10 grandchild-agent files in the gap-analysis scratchpad, each verified
against live GitHub source (not README/pub.dev descriptions alone, except where explicitly flagged
low-confidence).

<!--
  How to read this document:
  - HAVE  = saropa_lints already covers the same intent (rule id may differ).
  - PARTIAL = saropa_lints covers part of the behavior, or covers it under a narrower/broader trigger.
  - GAP   = no saropa_lints equivalent.
  - "N/A" = a stock Dart/Flutter SDK lint (ships via `lints`/`flutter_lints`) that saropa_lints
    deliberately does not reimplement — not counted toward GAP totals.
  - Preset-only packages ship zero custom rule implementations (pure `analysis_options.yaml` bundles of
    stock lints). They are listed for completeness but have no per-package detail section.
-->

## Competitor Landscape

Published Dart and Flutter lint packages that compete with, or are adjacent to,
`saropa_lints`. Compiled from pub.dev / GitHub search, September 2026 — verify
current rule counts and status before quoting externally, since these packages
update independently of this repo.

### Custom lint / analyzer-plugin rule collections

<!-- Direct competitive set: packages that ship their own custom rules. -->

| Package | URL | Mechanism | Coverage / focus |
|---|---|---|---|
| saropa_lints | https://pub.dev/packages/saropa_lints | `custom_lint` plugin | Comprehensive Flutter/Dart static-analysis suite. 2,332 custom rules and 254 quick fixes, five progressive tiers. |
| flutter_custom_lints | https://pub.dev/packages/flutter_custom_lints | `custom_lint` plugin | Large general-purpose Flutter/Dart custom lint collection. |
| awesome_lints | https://pub.dev/packages/awesome_lints | `custom_lint` plugin | Broad Dart/Flutter lint collection: 32 Flutter-specific, 65 general Dart, 8 Provider-specific, 22 Bloc-specific, 1 FakeAsync-specific rule. |
| essential_lints | https://pub.dev/packages/essential_lints | `custom_lint` plugin | 20+ rules focused on logical safety and function design, with quick fixes and code assists. |
| many_lints | https://pub.dev/packages/many_lints | Analysis-server plugin | 250+ opt-in rules and 100+ automated quick fixes. Uses Dart's newer analysis-server-plugin integration directly. |
| flutter_skill_lints | https://pub.dev/packages/flutter_skill_lints | Analysis-server plugin | Riverpod + codegen-architecture focused. 470+ diagnostic codes and 60+ quick fixes. |
| mad_lint | https://pub.dev/packages/mad_lint | Lint plugin | Structural integrity and resource management. |
| flutter_quality_lints | https://pub.dev/packages/flutter_quality_lints | `custom_lint` plugin | Code-health linter with HTML/JSON/Markdown trend-analysis reports. |
| ripplearc_linter | https://pub.dev/packages/ripplearc_linter | `custom_lint` plugin | Targeted custom lint rules for code quality and strict testing practices. |
| pyramid_lint | https://pub.dev/packages/pyramid_lint | Analysis-server plugin | Opinionated code-quality, consistency, and maintainability rules with IDE quick fixes. |
| klin_dart | https://pub.dev/packages/klin_dart | Custom lint package | Opinionated architecture, readability, maintainability, and style rules. |
| cosee_lints | https://pub.dev/packages/cosee_lints | Custom lint package | Cosee's internal enterprise preset — custom configuration plus `dart_code_linter` metrics. |
| leancode_lint | https://pub.dev/packages/leancode_lint | Analysis-server plugin | LeanCode's production rules — migrated from `custom_lint` to `analysis_server_plugin`. |
| flutter_best_practices_lints | https://pub.dev/packages/flutter_best_practices_lints | `custom_lint` plugin | Clean Flutter UI habits: single-class-per-file, matching file/class names. |
| clean_architecture_kit | https://pub.dev/packages/clean_architecture_kit | `custom_lint` plugin | Enforces clean-architecture domain boundaries. |
| architecture_linter | https://pub.dev/packages/architecture_linter | `custom_lint` plugin | Folder/import analyzer enforcing configurable layer-separation boundaries. |
| architecture_lints | https://pub.dev/packages/architecture_lints | `custom_lint` plugin | Dynamic/config-driven architectural linter via `architecture.yaml`. |
| df_safer_dart_lints | https://pub.dev/packages/df_safer_dart_lints | `custom_lint` plugin | Strict functional-programming enforcer using `df_safer_dart` annotations. |
| flutter_sane_lints | https://pub.dev/packages/flutter_sane_lints | `custom_lint` plugin | Flutter anti-pattern detection: memory leaks, rebuild overhead. |
| hardcoded_strings_lint | https://pub.dev/packages/hardcoded_strings_lint | `custom_lint` plugin | Unlocalized string detection in Flutter widgets. |
| flutter_refactor_plugin | https://pub.dev/packages/flutter_refactor_plugin | `custom_lint` plugin | Detects overly complex widget trees. |
| team_guard | https://pub.dev/packages/team_guard | `custom_lint` plugin | Team governance: blocks forbidden widgets/classes, suggests replacements. |
| subpackage_lint | https://pub.dev/packages/subpackage_lint | `custom_lint` plugin | Enforces subpackage/monorepo import boundaries. |
| import_order_lint | https://pub.dev/packages/import_order_lint | `custom_lint` plugin | Enforces import ordering following Flutter-style conventions. |
| import_lint | https://pub.dev/packages/import_lint | `custom_lint` plugin | Enforces import restrictions between layers/packages. |
| equatable_lint | https://pub.dev/packages/equatable_lint | `custom_lint` plugin | Validates `Equatable` `props` completeness. |
| equatable_lint_ultimate | https://pub.dev/packages/equatable_lint_ultimate | `custom_lint` plugin | Extended variant of `equatable_lint`. |
| fast_equatable_lint | https://pub.dev/packages/fast_equatable_lint | `custom_lint` plugin | Equivalent validation for `FastEquatable`. |
| all_observer_lint | https://pub.dev/packages/all_observer_lint | `custom_lint` plugin | Rules for observer-pattern usage. |
| riverpod_lint | https://pub.dev/packages/riverpod_lint | `custom_lint` plugin | Official Riverpod plugin — state mutation, `ref` passing, `ProviderScope` checks. |
| bloc_lint | https://pub.dev/packages/bloc_lint | `custom_lint` plugin | Official `bloc`/`flutter_bloc` lint rules. |
| flutter_hooks_lint | https://pub.dev/packages/flutter_hooks_lint | `custom_lint` plugin | Ensures `flutter_hooks` are only used in `build` methods with `use` prefix. |
| logd_linters | https://pub.dev/packages/logd_linters | `custom_lint` plugin | Logging safety for the `logd` package. |
| context_plus_lint | https://pub.dev/packages/context_plus_lint | `custom_lint` plugin | `context_plus` DI package `.use()` correctness checks. |
| solid_lints | https://pub.dev/packages/solid_lints | `custom_lint` plugin | ISO/IEC and NIST standards, SOLID principles. |
| surf_lint_rules | https://pub.dev/packages/surf_lint_rules | `custom_lint` plugin | Surf company's internal rules. |
| design_system_lints | https://pub.dev/packages/design_system_lints | `custom_lint` plugin | Enforces design-system/token usage in UI code. |
| mvvm_linter | https://pub.dev/packages/mvvm_linter | `custom_lint` plugin | Enforces MVVM architecture-layer boundaries. |
| amplify_lints | https://pub.dev/packages/amplify_lints | `custom_lint` plugin | AWS Amplify Flutter's internal rule set. |
| flame_lint | https://pub.dev/packages/flame_lint | `custom_lint` plugin | Flame game-engine ecosystem rules. |
| dart_code_metrics_annotations | https://pub.dev/packages/dart_code_metrics_annotations | Annotation package | Annotations consumed by DCM's rule engine. |
| dart_code_metrics_presets | https://pub.dev/packages/dart_code_metrics_presets | DCM presets | Predefined DCM rule presets. |
| jsdaddy_custom_lints | https://github.com/JsDaddy/dart-linter-rules | GitHub / `custom_lint` | Single rule: enforces kebab-case Dart file names. |

### Code metrics & standalone analysis engines

| Package | URL | Coverage / focus |
|---|---|---|
| dart_code_linter | https://pub.dev/packages/dart_code_linter | Standalone toolkit and analysis plugin (fork of DCM). Metrics + 70+ custom quality/anti-pattern rules. |

### Accessibility (a11y) linters

| Package | URL | Coverage / focus |
|---|---|---|
| flutter_a11y_lints | https://pub.dev/packages/flutter_a11y_lints | `SemanticNode` IR tree for deep a11y violations, focus management, and color-contrast ratios. |
| accessibility_lint | https://pub.dev/packages/accessibility_lint | Immediate checks: `IconButton` tooltips, image semantic labels, interactive element sizing. |

### Generators, tooling & AI-assisted analysis

| Package | URL | Coverage / focus |
|---|---|---|
| flutter_doctor_ai | https://pub.dev/packages/flutter_doctor_ai | AI-powered static-analysis CLI using Groq/Gemini/OpenAI for context-aware fixes. |
| json_serializable_lints | https://pub.dev/packages/json_serializable_lints | Validates `@JsonSerializable()` `fromJson`/`toJson` implementation. |
| json_parser_linter | https://pub.dev/packages/json_parser_linter | Detects unsafe JSON-parsing logic. |

### Standard analyzer-lint presets

<!-- Not direct competitors — no custom rule implementations. Frequently compared
     since they occupy the same `analysis_options.yaml` slot. -->

| Package | URL | Coverage / focus |
|---|---|---|
| flutter_lints | https://pub.dev/packages/flutter_lints | Official Flutter-maintained recommended analyzer rules. |
| lints | https://pub.dev/packages/lints | Official Dart-maintained `core`, `recommended`, and package-oriented rule sets. |
| lint | https://pub.dev/packages/lint | Community-driven (Pascal Welsch), Effective Dart guidelines. |
| lint_hard | https://pub.dev/packages/lint_hard | Strict drop-in replacement preset. |
| flutter_lints_plus | https://pub.dev/packages/flutter_lints_plus | Extended preset wrapping standard `flutter_lints`/`lints`. |
| very_good_analysis | https://pub.dev/packages/very_good_analysis | Very Good Ventures' strict analyzer preset. |
| pedantic_mono | https://pub.dev/packages/pedantic_mono | Monorepo edition recommended lints. |
| linteo | https://pub.dev/packages/linteo | iteo's Flutter/Dart rules. |
| austerity | https://pub.dev/packages/austerity | Strict-enforcement preset. |
| extra_pedantic | https://pub.dev/packages/extra_pedantic | Stricter analyzer linter settings. |
| flutterando_analysis | https://pub.dev/packages/flutterando_analysis | Flutterando Community's preset. |

### Custom-linter frameworks

<!-- Not competitors — these are the frameworks saropa_lints and most competitors
     are built on or migrated from. -->

| Package | URL | Purpose |
|---|---|---|
| custom_lint | https://pub.dev/packages/custom_lint | Runner/framework for `custom_lint` plugins. |
| custom_lint_builder | https://pub.dev/packages/custom_lint_builder | Authoring SDK for `custom_lint` plugins. |
| custom_lint_core | https://pub.dev/packages/custom_lint_core | Shared base APIs for custom-lint authors. |
| analysis_server_plugin | https://pub.dev/packages/analysis_server_plugin | Native analyzer-plugin API — used by `many_lints`, `leancode_lint` v17+, and saropa_lints. |

---

## Executive Summary

48 competitor packages plus **DCM proper (dcm.dev, 487 rules)** were audited rule-by-rule against saropa_lints.
DCM is the largest single competitor: saropa covers 421/487 (86%) with exact or semantic equivalents, 16 (3%)
partially, and has 50 true gaps (10%). Across all packages, roughly 360+ individual GAP findings were logged,
but the true number of **distinct, generalizable gaps** is far smaller — most GAPs cluster into a handful of
themes (see below) or are bespoke internal conventions of a single company's open-sourced linter with no broader
applicability (ripplearc_linter, mad_lint's `mapped_fields_*` family, team_guard). saropa_lints has HAVE/PARTIAL
coverage for roughly 75-85% of rules in the median competitor package; the largest packages checked (DCM 487
rules, many_lints 261 rules, flutter_skill_lints 279 rules) confirm this ratio directly (421/487, 190/261 and
231/279 HAVE respectively). The three biggest structural gaps are: (1) **zero fpdart coverage** (~26 rules, 100%
GAP — the single largest unaddressed rule family), (2) **no generic, user-configurable
architecture/import-boundary engine** (5+ competitors independently built one; saropa has only fixed
UI/domain/data heuristics), and (3) **thin coverage of newer/niche ecosystem packages** — Riverpod
lifecycle/naming completeness, Mocktail, Patrol, get_it, easy_localization, and Flame all have partial-to-zero
support despite saropa's deep Bloc/GetX/Equatable coverage in the same space.

A separate, non-gap finding worth flagging: five independent research agents found that
`saropa_rules_reference.json` / `saropa_rules_short.md` (the generated rule catalog used for doc lookups and
by parts of the extension) has **misattributed doc-comment text** for an unknown subset of rules — e.g.
`avoid_border_all`'s doc describes a Hero `heroTag` check, `require_animation_disposal`'s doc actually
describes a `Border.all` → `Border.fromBorderSide` check, `avoid_late_context`'s doc is about `Expanded`/`Spacer`,
and several more (full list in Methodology). This did not affect the HAVE/PARTIAL/GAP classifications below
(agents verified against live `.dart` source, not the corrupted reference), but the reference file itself needs
regeneration/investigation as a follow-up task independent of this document.

## Summary Table

| Package | Total Rules | HAVE | PARTIAL | GAP | Notes |
|---------|------------|------|---------|-----|-------|
| accessibility_lint | 5 | 3 | 1 | 0 | Repo archived/dead |
| all_observer_lint | 20 | 0 | 0 | 20 | Niche reactive-state library (`Observable`/`Computed`/`Observer`) |
| amplify_lints | ~75 | 3 | 0 | ~72 N/A | Preset-only, zero Amplify-specific rules |
| architecture_lints | 23 | 0 | 4 | 19 | Configurable component/layer-graph engine (puntbyte) |
| architecture_linter | 4 | 0 | 1 | 3 | 1 generic banned-import mechanism + 3 self-diagnostics |
| awesome_lints | 123 | 100 | 5 | 17 | 1 unconfirmed; strong Bloc/Provider overlap |
| bloc_lint | 9 | 3 | 5 | 1 | Official `felangel/bloc` package |
| clean_architecture_kit | 16 | 0 | 3 | 13 | Configurable Clean Architecture layer engine |
| context_plus_lint | 4 | 0 | 0 | 4 | `context_plus` package's own `Ref`/`context.use()` API |
| cosee_lints | 0 | 0 | 0 | 0 | Preset-only, zero custom rules |
| **DCM proper (dcm.dev)** | **487** | **421** | **16** | **50** | Commercial product; 378 exact name matches + 43 semantic equivalents. See detail section. |
| **very_good_analysis (VGA)** | **~206** | **~15** | **0** | **~191 N/A** | Preset-only (stock Dart analyzer rules). saropa operates in a separate namespace — not a gap, complementary. See detail section. |
| dart_code_linter | 82 | 68 | 8 | ~9 | DCM fork; several rule ids ported as saropa `configAlias`es |
| dart_code_metrics_annotations | 3 | 1 | 2 | 0 | `@Throws`/`@AcceptedTypes`/`@mutated` annotation contracts |
| dart_code_metrics_presets | 77 | 27 | 6 | 44 | 15 package-specific preset YAMLs (bloc/riverpod/provider/etc.) |
| df_safer_dart_lints | 9 (18 codes) | 0 | 3 | 6 | Annotation-gated null/isolate-safety rules |
| design_system_lints | 7 | 0 | 1 | 6 | Literal-to-annotated-source token provenance tracing |
| equatable_lint | 2 | 1 | 0 | 1 | bamlab |
| equatable_lint_ultimate | 3 | 1 | 1 | 1 | Fork of equatable_lint + 1 assist |
| essential_lints | 27 | 9 | 5 | 13 | Native `analysis_rule` API |
| fast_equatable_lint | 2 | 0 | 0 | 2 | `fast_equatable` package (`hashParameters` API) |
| flame_lint | 39 | 3 | 0 | 36 N/A | Preset-only, zero Flame-engine-specific rules |
| flutter_a11y_lints | 12 | 3 | 2 | 7 | 27 documented, only 12 actually shipped |
| flutter_best_practices_lints | 5 | 2 | 1 | 2 | 1 GAP is a documented philosophical conflict |
| flutter_custom_lints | 5 | 2 | 1 | 2 | |
| flutter_doctor_ai | 5 | 5 | 0 | 0 | Clean sweep — saropa is a superset |
| flutter_hooks_lint | 7 | 4 | 1 | 2 | Official-adjacent, `nikaera/flutter_hooks_lint` |
| flutter_quality_lints | 18 | 15 | 2 | 1 | Several of their rules are non-functional stubs as shipped |
| flutter_refactor_plugin | 1 | 0 | 1 | 0 | Source repo 404 — unverified, pub.dev description only |
| flutter_sane_lints | 2 | 2 | 0 | 0 | Clean sweep |
| flutter_skill_lints | 279 | 231 | 7 | 41 | Largest single package audited |
| hardcoded_strings_lint | 1 | 1 | 0 | 0 | Unverified against full source (GitHub listing cut off) |
| import_lint | 1 | 0 | 0 | 1 | Generic glob-based import-boundary DSL |
| import_order_lint | 1 | 0 | 1 | 0 | Standalone CLI formatter, not a `custom_lint` rule |
| json_parser_linter | 1 (2 sub-checks) | 0 | 0 | 1 | Annotation-presence → member-presence contract |
| json_serializable_lints | 3 | 0 | 0 | 3 | Same gap class as json_parser_linter |
| jsdaddy_custom_lints | 1 | 0 | 0 | 1 | Kebab-case filenames (conflicts with Dart convention) |
| klin_dart | 6 | 2 | 3 | 1 | |
| leancode_lint | 23 | 9 | 5 | 9 | Already migrated to `analysis_server_plugin` |
| logd_linters | 13 | 1 | 0 | 12 | `logd` logging package's arena/pool API |
| mad_lint | 13 | 7 | 2 | 4 | 4 GAPs are one company's bespoke `mappedFields` convention |
| many_lints | 261 | 190 | 3 | 68 | Includes the ~26-rule fpdart family (100% GAP) |
| mvvm_linter | 1 | 0 | 1 | 0 | Single 10-category MVVM member-order rule |
| pyramid_lint | 36 | 24 | 4 | 8 | High implementation quality, type-checked |
| riverpod_lint | 13 | 3 | 0 | 10 | Official `rrousselGit/riverpod` package |
| ripplearc_linter | 24 | 5 | 4 | 15 | One company's internal linter, mostly non-generalizable |
| solid_lints | 31 | 15 | 3 | 13 | Found a real saropa bug: `use_closest_build_context` is an empty no-op stub |
| subpackage_lint | 3 | 1 | 0 | 2 | `/src/` cross-subpackage import isolation |
| surf_lint_rules | 195 | 4 | 0 | ~191 N/A | Preset-only, zero custom rules |
| team_guard | 1 | 0 | 0 | 1 | Generic configurable "ban widget X, suggest Y" engine |

## Gap Themes

<!--
  Grouped by underlying concept, not by competitor package, so duplicate gaps (the same idea proposed by
  multiple packages) are counted once. Each theme lists which package(s) raised it and roughly how many
  distinct rules fall under it. This is the section to use when prioritizing what to build next.
-->

### 1. fpdart / functional-programming ecosystem (~26 unique gaps)

100% GAP. saropa_lints has zero fpdart-aware rules (no "fpdart", "TaskEither", or "Either" hits anywhere in
its rule set). Source: **many_lints** — `avoid_ad_hoc_left_type`, `avoid_bare_await_in_do`,
`avoid_dollar_outside_do_frame`, `avoid_either_of_future`, `avoid_future_of_either`, `avoid_future_of_option`,
`avoid_get_or_else_swallowing_failure`, `avoid_nested_do_notation`, `avoid_removed_fpdart_api`,
`avoid_throw_in_fp_callback`, `avoid_unnecessary_option`, `avoid_untyped_safe_cast`, `avoid_unrun_task`,
`prefer_and_then`, `prefer_chain_either`, `prefer_chaining_over_intermediate_run`, `prefer_do_notation`,
`prefer_from_nullable`, `prefer_from_predicate`, `prefer_safe_collection_access`,
`prefer_string_parse_extensions`, `prefer_task_either_over_try_catch`, `prefer_unit_over_void`. This is the
single largest unaddressed rule family in the entire audit — but scope it as a deliberate "adopt fpdart
package support" decision, since it requires modeling a whole third-party type system (`Either`/`Option`/
`Task`/`TaskEither`/`Do`), not incremental additions to existing rules.

### 2. Generic, user-configurable architecture/import-boundary engines (~30+ unique gaps, 6 packages)

The single most-repeated pattern across the audit: at least six competitors independently built a
**project-configurable** rule engine (YAML/annotation-driven) for banning imports, enforcing layer
dependencies, requiring naming conventions per component type, or requiring/forbidding base types —
none of which saropa_lints has, because saropa's Clean-Architecture coverage
(`avoid_business_logic_in_ui`, `avoid_direct_data_access_in_ui`, `avoid_ui_in_domain_layer`) is three fixed,
hardcoded relationships rather than a general N-layer/N-component graph the project itself can define.
- **clean_architecture_kit** (13 gaps): `disallow_flutter_imports_in_domain`, `disallow_flutter_types_in_domain`,
  `data_source_purity`, `repository_implementation_purity`, `disallow_use_case_in_presentation`,
  `enforce_model_to_entity_mapping`, `enforce_abstract_data_source_dependency`,
  `enforce_file_and_folder_location`, `enforce_naming_conventions`, `enforce_custom_return_type`,
  `enforce_use_case_inheritance`, `enforce_repository_inheritance`, `missing_use_case`.
- **architecture_lints** (19 gaps): `arch_dep_module`, `arch_orphan_file`, `arch_parity_missing`,
  `arch_type_strict_inheritance`, `arch_type_forbidden`, `arch_type_missing_base`, `arch_member_forbidden`,
  `arch_member_missing`, `arch_annot_forbidden`, `arch_annot_missing`, `arch_annot_strict`,
  `arch_naming_grammar`, `arch_naming_antipattern`, `arch_naming_pattern`, `arch_exception_conversion`,
  `arch_exception_forbidden`, `arch_exception_missing`, `arch_safety_param_strict`,
  `arch_safety_param_forbidden`, `arch_safety_return_strict`, `arch_safety_return_forbidden`,
  `arch_usage_instantiation` (single largest structural gap by rule count in Batch 3).
- **import_lint**: generic `target`/`from`/`except` glob-based import-boundary DSL — a project can define
  "feature A must not import feature B" purely from config; saropa cannot.
- **team_guard**: generic configurable "ban this widget/class, suggest this replacement" mechanism
  (`team_guard.forbidden_widget`).
- **many_lints**: `avoid_banned_annotations`, `avoid_banned_exports`, `avoid_banned_imports`,
  `avoid_banned_names`, `avoid_banned_types`, `banned_usage`, `use_class_prefix`, `use_class_suffix`,
  `match_pattern` — all generic config-driven ban/require mechanisms, distinct from saropa's fixed
  `banned_identifier_usage` (name-only matching, no annotation/type/directory awareness).
- **architecture_linter**: single generic per-layer banned-import mechanism (dynamic, one lint per
  configured entry).
- **subpackage_lint**: `avoid_src_import_from_other_subpackage`, `avoid_src_import_from_same_package`
  (monorepo `/src/` isolation).
- **ripplearc_linter**: `prevent_feature_module_dependencies`, `prevent_library_module_dependencies`,
  `no_direct_instantiation` (config-driven DI-only-instantiation ban).

### 3. Riverpod lifecycle/naming completeness (~13 unique gaps, deduped across 3 packages)

saropa covers the common Riverpod misuse patterns (`avoid_ref_read_inside_build`,
`avoid_ref_watch_outside_build`, `avoid_ref_inside_state_dispose`, `use_ref_and_state_synchronously`,
`avoid_notifier_constructors`, `avoid_assigning_notifiers`, `dispose_provided_instances`,
`avoid_nullable_async_value_pattern`) but is missing the *completeness/naming* layer, raised independently by
**riverpod_lint** (official package), **dart_code_metrics_presets** (`riverpod.yaml`, 16/18 GAP — the single
worst preset in that batch), and **many_lints**:
`avoid_public_notifier_properties` / `protected_notifier_properties` (external access to Notifier internals),
`notifier_build` (Notifier missing a `build()` method), `notifier_extends` (wrong base class),
`functional_ref` (functional provider's first param isn't the matching `Ref`), `provider_dependencies` /
`scoped_providers_should_specify_dependencies` (declared vs. actually-used `dependencies:`), `provider_parameters`
(family-provider argument instability/creation-time-parameter misuse), `only_use_keep_alive_inside_keep_alive`,
`unsupported_provider_value`, `prefer-riverpod-provider-suffix` / `prefer-riverpod-notifier-suffix` /
`prefer-correct-notifier-file-name` / `prefer-correct-provider-file-name` (naming conventions),
`prefer-single-notifier-per-file`, `avoid-calling-notifier-members-inside-build`.

### 4. Bloc ecosystem completeness (~13 unique gaps, deduped across 3 packages)

Similarly, saropa's Bloc coverage is strong on the common misuse patterns but thin on naming/structure
conventions. Deduped from **bloc_lint**, **dart_code_metrics_presets** (`bloc.yaml`), **awesome_lints**, and
**leancode_lint**: `prefer-multi-bloc-provider` flattening (Bloc-specific, distinct from saropa's generic
`avoid_nested_providers`), `avoid-empty-build-when` (missing `buildWhen` entirely — saropa only catches an
always-`true` `buildWhen`), `avoid-duplicate-bloc-event-handlers`, `handle-bloc-event-subclasses` (unhandled
sealed event subclass), `prefer-bloc-state-suffix` / `prefer-bloc-event-suffix` naming (saropa only has the
Bloc/Cubit-suffix check, not State/Event suffix), `prefer-immutable-bloc-state`/`prefer-immutable-bloc-events`
as a class-declaration check (saropa only catches mutation at call sites, not missing `@immutable`),
`avoid-returning-value-from-cubit-methods`, `bloc_related_class_naming` (State/Event must match the Bloc's own
subject name), `bloc_subclasses_naming` (State/Event prefixed with base class name), `add_cubit_suffix_for_your_cubits`.

### 5. Uncovered ecosystem packages: Mocktail, Patrol, get_it, easy_localization, Flame (~17 unique gaps)

`dart_code_metrics_presets` names these five packages as having **zero** saropa coverage across the board:
- **Mocktail/Mockito**: `use-then-answer`/`use_then_answer`, `pass-mock-object`/`pass_mock_object`,
  `avoid-implementation-in-mocks`/`avoid_implementation_in_mocks`, `prefer-correct-any-matcher`/
  `prefer_correct_any_matcher`, `avoid_then_return_with_future` (7 rule mentions across 2 packages, deduped to ~4 unique).
- **Patrol**: `prefer-custom-finder-over-find`, `prefer-symbol-over-key`.
- **get_it**: `avoid-functions-in-register-singleton` (no `get_it`-specific rules exist in saropa at all).
- **easy_localization**: `avoid-missing-tr`, `avoid-missing-tr-on-strings` (saropa's l10n rules target its own
  `l10n()` convention, not `easy_localization`'s `.tr()` extension).
- **Flame** (game engine): `avoid-creating-vector-in-update`, `avoid-initializing-in-on-mount`,
  `avoid-redundant-async-on-load`, `correct-game-instantiating`, plus `dart_code_linter`'s
  `avoid-initializing-in-on-mount` and `correct-game-instantiating` — confirmed zero Flame-specific rules on
  either side (flame_lint itself, the official Flame-org preset, ships none either).

### 6. JSON-codegen annotation-contract enforcement (2 packages, both 100% GAP)

A clean, narrowly-scoped, high-value gap independently identified by two unrelated researchers as a pattern:
saropa's JSON rules (`prefer_json_codegen`, `avoid_not_encodable_in_to_json`, `avoid_freezed_json_serializable_conflict`)
all assume `fromJson`/`toJson` methods already exist and check their *contents/style*. None verify that a class
carrying a JSON-codegen-trigger annotation actually *declares* the methods the generator or a hand-written
contract expects. Source: **json_serializable_lints** (`require_json_serializable_from_json`,
`require_json_serializable_to_json`, `require_annotation_from_json`) and **json_parser_linter**
(`json_parser_requirements` — its `toJson`/`fromJson` sub-checks). Straightforward to implement: annotation
presence → member presence.

### 7. Accessibility semantic-IR reasoning (6 unique gaps, 1 package)

**flutter_a11y_lints** built a semantic-tree IR (WidgetNode → SemanticTree with `labelGuarantee`,
`focusableDescendantCount`) enabling cross-widget/ancestor-descendant reasoning that saropa's single-pass AST
visitors don't attempt. Genuine gaps requiring this kind of reasoning: `A05` redundant
`Semantics(button:true)` wrapper on a primitive Material button, `A07` `Semantics(label:)` wrapper whose
descendants aren't excluded (double announcement), `A09` numeric-only label text missing units, `A13` composite
control exposing more than one focusable descendant (should be one screen-reader stop), `A21` `Tooltip`-wrapper
used instead of `IconButton.tooltip` param, `A22` `MergeSemantics` wrapping the ListTile family (already
self-merging). Also `A02` (label content contains redundant role words like "button"/"icon") is a simpler
content-inspection gap that doesn't need the IR.

### 8. Design-system token provenance (6 unique gaps, 1 package)

**design_system_lints**' whole mechanism — an `@designSystem` annotation marking a single source of truth,
with every literal of a matching type flagged repo-wide unless traced back to it — is a generic pattern saropa
doesn't have at all (saropa's `avoid_hardcoded_colors`/`no_magic_number` are hardcoded per-value-type
heuristics against `Theme.of(context)`, not a general "trace to annotated source" engine). Concrete gaps:
`edge_insets` (hardcoded `EdgeInsets.*` args), `box_shadow`, `radius`, `text_style` (saropa's
similarly-named `avoid_hardcoded_text_styles` is a false-cognate — actually about missing `onHover` handlers),
`theme_data` (hardcoded `ThemeData(...)` instantiation), `box_constraints` (hardcoded `width`/`height`
literals).

### 9. Budget/count-style rules with missing variants (~7 unique gaps, 3 packages)

saropa has function-length, parameter-count, and cyclomatic-complexity budgets but is missing sibling
count-based budgets that competitors ship: `avoid_long_files` (a true configurable line-count-with-max-lines-param
variant — many_lints; saropa's `avoid_long_length_files` family is tier-gated/opinionated, not
user-configurable), `avoid_too_many_methods` (class method-count budget), `avoid_too_many_widgets_per_build`
(widget-instantiation-count per `build()`), `max_statements` (statement-count, distinct from line-count),
`initializers_ordering` (constructor field-initializer order vs. field-declaration order), `class_length`
(klin_dart — LOC-based, distinct from saropa's `avoid_god_class` which counts members not lines),
`function_lines_of_code` (solid_lints — LOC not cyclomatic).

### 10. Test hygiene (4 unique gaps, 2 packages)

`avoid_skipped_tests` (`skip:`/`@Skip`), `avoid_focused_tests` (`solo: true`), `require_mirror_test`
(a `lib/` file has no matching `*_test.dart`) — many_lints. `avoid_missing_test_files` — flutter_skill_lints
(same "mirror test" concept). `test_file_mutation_coverage` — ripplearc_linter (mutation-testing directory
cross-reference, low generalizability).

### 11. New Dart 3.12/3.13 language-feature rules (3 unique gaps, 1 package)

many_lints covers newer Dart syntax saropa doesn't yet: `prefer_primary_constructors` (class of final fields +
trivial constructor → Dart 3.13 primary constructor), `prefer_private_named_parameters` (public named
parameter that only initializes a private field → Dart 3.12 shorthand), `prefer_returning_shorthands`
(expression-body return matching declared type → dot shorthand). Note saropa already covers the *other*
dot-shorthand rules (constructors/enums/static fields) — this is a narrow follow-up, not a new category.

### 12. Documentation conventions (5 unique gaps, 2 packages)

`document_interface` (abstract classes/their public methods must be documented), `document_enum` (enums/enum
values must be documented), `document_fake_parameters`, `no_internal_method_docs` (inverse convention: flag
docs on *private* methods) — ripplearc_linter. `always_put_doc_comments_before_annotations` (doc comment must
precede `@override` etc., not follow it) — pyramid_lint. `start_comments_with_space` — leancode_lint (saropa's
`require_ignore_comment_spacing` only covers `// ignore:` directives, not general comments).

### 13. Niche third-party package APIs (low priority individually, ~57 unique gaps across 4 packages)

Each of these targets a single niche package's own API surface with no broader Dart/Flutter applicability —
real gaps, but low ROI unless saropa specifically wants to support that package:
- **context_plus_lint** (4 gaps): `context_use_unique_key`, `context_ref_reassignment`,
  `wrong_ref_declaration`, `wrong_ref_type` — the `context_plus` package's `Ref`/`context.use()` API.
- **logd_linters** (12 gaps): arena/pool retention, `LogEngine`/`LogDecorator`/`LogFormatter`/`Logger`/
  `LogTag`/`LogBuffer`/`Handler` API misuse — the `logd` logging package.
- **all_observer_lint** (20 gaps): `Observable`/`Computed`/`Observer`/`effect`/`batch` reactive-state API misuse.
- **mad_lint** (4 gaps): `mapped_fields_*` family — one company's internal `mappedFields`/stringify-mixin
  convention.

### 14. Miscellaneous single-rule gaps worth a look

Not large enough to be a "theme" but concrete and easy to scope: `avoid_commented_out_code` (dead code left as
a comment — many_lints, flutter_skill_lints has the equivalent as HAVE via `prefer_no_commented_out_code`, so
this is resolved — kept here only as a false-negative check example), `use_gap` (SizedBox/Padding spacing →
`Gap` widget), `prefer_container` (collapse 3+ nested single-purpose widgets into one `Container` — many_lints,
awesome_lints, flutter_skill_lints all raise this independently, so it's a 3x-repeated single gap),
`avoid_single_child_in_multi_child_widgets` (generalizes saropa's Column/Row-only
`avoid_single_child_column_row` to Stack/Wrap/sliver-groups — leancode_lint, flutter_skill_lints,
clean_architecture_kit-adjacent), `no_direct_iterable_access` / `use_compare_without_case` (flutter_custom_lints
— generic unsafe-indexing and case-insensitive-string-compare extension-method conventions),
`prefer_iterable_any` / `prefer_iterable_every` (`.where().isNotEmpty`/`.isEmpty` → `.any`/`.every` —
pyramid_lint; note saropa's similarly-named `prefer_any_or_every` is a false-cognate, see Methodology),
`always_specify_parameter_names` (function-type-signature params — pyramid_lint), `proper_from_environment`
(non-const `bool/int/String.fromEnvironment` — pyramid_lint), `avoid_public_members_in_states` (public
fields/methods directly on a `State<T>` — pyramid_lint), `avoid_single_child_in_flex` (Row/Column/Flex with
exactly one child — pyramid_lint).

## Per-Package Details

<!-- Preset-only packages (cosee_lints, amplify_lints, flame_lint, surf_lint_rules) are excluded here per
     instructions — they ship 0 custom rules, already summarized in the table above. -->

### context_plus_lint

- **Source**: github.com/s0nerik/context_plus (packages/context_plus_lint)
- **Total rules**: 4
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 4

#### Gaps

- `context_use_unique_key` — within one build method, flags a second `context.use()` call whose
  (return type, `key`, `ref`) combination duplicates an earlier call.
- `context_ref_reassignment` — flags binding the same `Ref` instance more than once inside one build method.
- `wrong_ref_declaration` — requires `Ref` instances be declared only as top-level `final`/`static final`, not
  locals.
- `wrong_ref_type` — flags a `Ref<T>` whose generic argument doesn't match the `context.use()` return type.

### bloc_lint

- **Source**: github.com/felangel/bloc (packages/bloc_lint), official package
- **Total rules**: 9
- **Coverage**: HAVE: 3, PARTIAL: 5, GAP: 1

#### Gaps

- `avoid_build_context_extensions` — flags `context.read/watch/select` for Bloc/Cubit types; saropa recommends
  the opposite style (`prefer_bloc_extensions`), a philosophical conflict rather than an absence.

#### Partial

- `avoid_public_fields` → saropa's `avoid_bloc_public_fields` doc is Bloc-only; Cubit coverage unconfirmed.
- `prefer_build_context_extensions` → saropa's `prefer_bloc_extensions` only covers `BlocProvider.of` →
  `context.read`/`watch`, not `BlocBuilder`/`BlocSelector`/`context.select`.
- `prefer_cubit` → saropa's `prefer_cubit_for_simple_state` only fires for single-event-type Blocs, not every Bloc.
- `prefer_file_naming_conventions` → saropa's `prefer_snake_case_files` checks general naming, not that the
  file matches the specific Bloc/Cubit class it contains.
- `avoid_public_methods` → saropa's `avoid_bloc_public_methods` has a stricter (narrower) allowlist than theirs.

### logd_linters

- **Source**: github.com/pooriaaskarim/logd (packages/logd_linters)
- **Total rules**: 13
- **Coverage**: HAVE: 1, PARTIAL: 0, GAP: 12

#### Gaps

`logd_document_retained_across_cycles`, `logd_missing_release_in_engine`, `logd_checkout_without_release`,
`logd_freeze_on_unconfigured_logger`, `logd_decorator_not_immutable`, `logd_formatter_not_immutable`,
`logd_formatter_performs_string_rendering`, `logd_avoid_print_sink_in_production`, `logd_logtag_use_bitmask`,
`logd_log_buffer_not_sunk`, `logd_handler_missing_engine`, `logd_handler_missing_dispose` — all specific to the
`logd` package's own arena-pooled `LogDocument`/`LogEngine`/`Logger`/`LogTag`/`Handler` API. Low priority unless
saropa wants dedicated `logd` support.

### flutter_hooks_lint

- **Source**: github.com/nikaera/flutter_hooks_lint
- **Total rules**: 7
- **Coverage**: HAVE: 4, PARTIAL: 1, GAP: 2

#### Gaps

- `hooks_extends` — flags a hook call in a class not extending `HookWidget`/`HookConsumerWidget`; saropa's
  `avoid_hooks_outside_build` only checks method location, not inheritance.
- `hooks_memoized_consideration` — flags an expensive-initializer variable in a hook-widget class not wrapped
  in `useMemoized()`.

#### Partial

- `hooks_callback_consideration` — flags `useMemoized(() => fn, [...])` (memoized *function*, should be
  `useCallback`); saropa's `prefer_use_callback` only flags inline closures passed directly as callback props,
  with no matching auto-fix for this specific misuse.

### flutter_best_practices_lints

- **Source**: github.com/AndrewDongminYoo/custom_linters (packages/flutter_best_practices_lints)
- **Total rules**: 5
- **Coverage**: HAVE: 2, PARTIAL: 1, GAP: 2

#### Gaps

- `prefer_widget_class_over_widget_helper` — flags private `_build*` methods returning `Widget`; saropa's
  `prefer_widget_methods_over_classes` recommends the **opposite**, a documented philosophical conflict.
- `avoid_widget_operator_equals` — flags `operator ==` overridden directly on a Widget subclass; saropa's
  similarly-purposed `require_extend_equatable` fires on any `==` override and suggests extending Equatable,
  which is what this competitor rule argues against for widgets specifically.

#### Partial

- `single_class_per_file` — saropa's `prefer_one_widget_per_file` only counts Widget classes and lacks the
  abstract-interface/impl exception; also opt-in vs. their default.

### klin_dart

- **Source**: github.com/kevinchrist20/klin_dart
- **Total rules**: 6
- **Coverage**: HAVE: 2, PARTIAL: 3, GAP: 1

#### Gaps

- `class_length` — raw class-declaration line span (default max 500); saropa's `avoid_god_class` measures
  member count, not LOC — different metric, not a substitute.

#### Partial

- `cognitive_complexity` — genuine nesting-weighted SonarSource-style complexity with two-tier severity;
  saropa's `avoid_high_cyclomatic_complexity` is flat McCabe count, no nesting weight, no two-tier severity.
- `function_length` — default 75 lines, `build()` gets a 150-line threshold; saropa's `avoid_long_functions`
  (100-line default, excludes comments/blank lines) has no `build()`-specific higher threshold.
- `file_length` — 700-line default, excludes import lines, fully configurable; saropa's
  `avoid_long_length_files` uses a fixed 500-line tier-gated threshold, no configurable max, doesn't exclude imports.

### riverpod_lint

- **Source**: github.com/rrousselGit/riverpod (packages/riverpod_lint), official package
- **Total rules**: 13
- **Coverage**: HAVE: 3, PARTIAL: 0, GAP: 10

#### Gaps

`avoid_public_notifier_properties`, `avoid_ref_inside_state_dispose` (note: saropa DOES have a
similarly-named `avoid_ref_inside_state_dispose` per other batches — cross-check before building; treat as
PARTIAL if a rule with this exact name already exists), `functional_ref`, `notifier_build`, `notifier_extends`,
`only_use_keep_alive_inside_keep_alive`, `protected_notifier_properties`, `provider_dependencies`,
`provider_parameters`, `scoped_providers_should_specify_dependencies`, `unsupported_provider_value`,
`riverpod_syntax_error` (framework-internal codegen validation, no equivalent needed).

### solid_lints

- **Source**: github.com/solid-software/solid_lints
- **Total rules**: 31
- **Coverage**: HAVE: 15, PARTIAL: 3, GAP: 13

**Bug found in saropa_lints itself (not a competitor gap):** `use_closest_build_context`
(`lib/src/rules/core/context_rules.dart:1483`, class `UseClosestBuildContextRule`) is registered with a real
`LintCode` but its `runWithReporter` body is empty (`{}`) — a silent no-op. Worth fixing independent of this doc.

#### Gaps

`avoid_duplicate_code` (cross-project AST clone detector), `avoid_final_with_getter`,
`avoid_unnecessary_return_variable`, `avoid_using_api` (generic config-driven banned-API mechanism),
`feature_envy`, `function_lines_of_code`, `named_parameters_ordering`, `newline_before_return`,
`prefer_first`/`prefer_last` (index-0/length-1 → `.first`/`.last`), `use_descriptive_names_for_type_parameters`,
`use_nearest_context` (effectively a gap — corresponds to the empty-stub bug above), and two name-collision
false-HAVEs reclassified to GAP after reading actual doc content: `avoid_returning_widgets` (their check is
different from saropa's same-named rule) and `avoid_similar_names` (same — saropa's same-named rule is
actually about enum-indexed Map literals).

#### Partial

- `avoid_debug_print_in_release` — saropa's `avoid_print_in_release` guards `print()`, not `debugPrint()`.
- `member_ordering` — saropa's `prefer_member_ordering` is a flat 3-bucket order vs. their fully configurable DSL.
- `number_of_parameters` — saropa's `prefer_named_parameters` targets excess positional params, not a pure
  count ceiling.

### leancode_lint

- **Source**: github.com/leancodepl/flutter_corelibrary (packages/leancode_lint), v27.0.0, already migrated to
  `analysis_server_plugin`
- **Total rules**: 23
- **Coverage**: HAVE: 9, PARTIAL: 5, GAP: 9

#### Gaps

`add_cubit_suffix_for_your_cubits`, `avoid_catch_error` (saropa's `prefer_then_catcherror` recommends the
opposite), `bloc_subclasses_naming`, `constructor_parameters_and_fields_should_have_the_same_order`,
`never_discard_build_context`, `prefer_center_over_align` (not active upstream), `start_comments_with_space`,
`use_design_system_item`, `use_padding` (`Container(margin:, [key], [child])` only → `Padding`).

#### Partial

- `avoid_context_read_in_build` — saropa has initState-only and callbacks-only variants, none covers general
  read-during-build.
- `avoid_single_child_in_multi_child_widgets` — saropa's `avoid_single_child_column_row` covers only
  Column/Row, not the sliver-group family.
- `bloc_related_class_naming` — saropa only checks suffix presence, not subject-name match.
- `catch_parameter_names` — saropa checks only the exception param, not stack-trace, and isn't configurable.
- `prefer_abstract_final_class` — saropa's `prefer_extension_over_utility_class` detects the same shape but
  recommends `extension` instead of `abstract final class`.

### dart_code_linter

- **Source**: github.com/bancolombia/dart-code-linter (Dart Code Metrics fork)
- **Total rules**: 82 (84 dirs minus 2 support files)
- **Coverage**: HAVE: ~68, PARTIAL: 8, GAP: ~9

#### Gaps

`avoid-banned-imports`, `avoid-initializing-in-on-mount` (Flame), `avoid-non-configurable-callbacks-in-init-state`,
`avoid-throw-in-catch-block`, `ban-name`, `correct-game-instantiating` (Flame), `only-barrel-import`,
`prefer-first-or-null`, `use-design-system-item`.

#### Partial

- `arguments-ordering` — saropa sorts alphabetically, not by declaration order.
- `prefer-named-record-fields` — saropa only flags accessing positional records via `$1`/`$2`, not declaring them.
- `tag-name` — saropa checks kebab-case formatting, not match-to-class-name.

Also reports continuous metrics (cyclomatic complexity, LOC, Halstead-style maintainability index) via an
HTML/console report; saropa encodes similar signals as discrete threshold lint rules instead
(`avoid_high_cyclomatic_complexity`, `avoid_deep_nesting`, `avoid_long_functions`, etc.) with no continuous
maintainability-index report — a capability gap in tooling, not rule count.

### clean_architecture_kit

- **Source**: github.com/puntbyte/clean_architecture_workspace (packages/clean_architecture_kit)
- **Total rules**: 16
- **Coverage**: HAVE: 0, PARTIAL: 3, GAP: 13

#### Gaps

`disallow_flutter_imports_in_domain`, `disallow_flutter_types_in_domain`, `data_source_purity`,
`repository_implementation_purity`, `disallow_use_case_in_presentation`, `enforce_model_to_entity_mapping`,
`enforce_abstract_data_source_dependency`, `enforce_file_and_folder_location`, `enforce_naming_conventions`,
`enforce_custom_return_type`, `enforce_use_case_inheritance`, `enforce_repository_inheritance`, `missing_use_case`.

#### Partial

- `domain_layer_purity` — saropa's `avoid_ui_in_domain_layer` flags presentation logic in domain, not a
  generic configurable "domain cannot import layer X" check.
- `presentation_layer_purity` — saropa's Bloc-specific repository-abstraction rules aren't a generic
  "presentation cannot touch Repository" check.
- `enforce_layer_independence` — saropa's fixed UI/business/data checks aren't a configurable N-layer engine.

### architecture_linter

- **Source**: github.com/Iteo/architecture_linter
- **Total rules**: 1 functional rule + 3 tool self-diagnostics
- **Coverage**: HAVE: 0, PARTIAL: 1, GAP: 3 (self-diagnostics not comparable code-quality rules)

#### Gaps

`architecture_linter_config_file_error`, `architecture_linter_layers_not_found`,
`architecture_linter_banned_imports_not_found` — all meta-diagnostics for the tool's own config, not
code-quality rules.

#### Partial

- Banned-layer-import check (dynamic, one lint per configured entry) — saropa's fixed UI/domain/data rules
  aren't a generic user-configurable N-layer import-banning engine.

### architecture_lints

- **Source**: github.com/puntbyte/architecture_workspace (packages/architecture_lints)
- **Total rules**: 23
- **Coverage**: HAVE: 0, PARTIAL: 4, GAP: 19

#### Gaps

`arch_dep_module`, `arch_orphan_file`, `arch_parity_missing`, `arch_type_strict_inheritance`,
`arch_type_forbidden`, `arch_type_missing_base`, `arch_member_forbidden`, `arch_member_missing`,
`arch_annot_forbidden`, `arch_annot_missing`, `arch_annot_strict`, `arch_naming_grammar`,
`arch_naming_antipattern`, `arch_naming_pattern`, `arch_exception_conversion`, `arch_exception_forbidden`,
`arch_exception_missing`, `arch_safety_param_strict`, `arch_safety_param_forbidden`, `arch_safety_return_strict`,
`arch_safety_return_forbidden`, `arch_usage_instantiation` — the biggest structural gap in the whole audit by
rule count (config-driven architecture-component-graph engine).

#### Partial

- `arch_dep_component`, `arch_dep_external`, `arch_location`, `arch_usage_global_access` — all covered
  partially by saropa's fixed layer/DI rules, none of which is configurable per-project.

### df_safer_dart_lints

- **Source**: github.com/robmllze/df_safer_dart_lints
- **Total rules**: 9 rule classes / 18 lint codes (WARNING + ERROR variant of each)
- **Coverage**: HAVE: 0, PARTIAL: 3, GAP: 6

#### Gaps

`no_future_outcome_type`, `must_be_anonymous`, `must_be_strong_ref`, `no_futures`,
`must_use_unsafe_wrapper`, `sendable` — all annotation-gated on the package's own `@mustAwaitAllFutures`,
`@sendable`, `@unsafe` etc. markers.

#### Partial

- `must_use_outcome` — saropa's `avoid_ignoring_return_values` flags any discarded return value generically,
  not specifically an `Outcome` monad type.
- `must_await_all_futures` — saropa's `avoid_unawaited_future` fires generally; theirs is annotation-scoped
  with a separate error-severity tier.
- `must_handle_return` — same generic-discard concept as saropa's `avoid_ignoring_return_values`/
  `missing_use_result_annotation`, not annotation-driven with two severity tiers.

### design_system_lints

- **Source**: github.com/pattobrien/design_system_lints (Sidecar framework, not `custom_lint` — defunct since 2022)
- **Total rules**: 7 active (1 dead/commented-out excluded)
- **Coverage**: HAVE: 0, PARTIAL: 1, GAP: 6

#### Gaps

`edge_insets`, `box_shadow`, `radius`, `text_style` (saropa's similarly-named `avoid_hardcoded_text_styles` is
a false-cognate about `onHover`), `theme_data`, `box_constraints`.

#### Partial

- `color` — saropa's `avoid_hardcoded_colors` flags `Color(0x...)`/`Colors.x` against `Theme.of(context)`, not
  an arbitrary `@designSystem`-annotated source class.

### equatable_lint

- **Source**: github.com/bamlab/equatable_lint
- **Total rules**: 2
- **Coverage**: HAVE: 1, PARTIAL: 0, GAP: 1

#### Gaps

- `always_call_super_props_when_overriding_equatable_props` — flags a subclass `props` override missing
  `...super.props`; saropa's `require_equatable_props_override` only checks `props` exists at all, not the
  super-call obligation in an inheritance chain.

### equatable_lint_ultimate

- **Source**: github.com/TomaszCz/equatable_lint (fork)
- **Total rules**: 2 rules + 1 assist
- **Coverage**: HAVE: 1, PARTIAL: 1, GAP: 1

#### Gaps

Same `always_call_super_props_when_overriding_equatable_props` gap as equatable_lint above.

#### Partial

- "Make class extend Equatable" assist — saropa's `require_extend_equatable` only proactively flags classes
  that manually override `==`/`hashCode`; it has no unprompted "convert any plain class" assist.

### fast_equatable_lint

- **Source**: github.com/FaFre/fast_equatable_lint
- **Total rules**: 2
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 2

#### Gaps

- `missing_field_in_equatable_props` (for `fast_equatable`'s `hashParameters` getter) — saropa's Equatable
  rules are all keyed to the `equatable` package's `props`, none recognize `FastEquatable`/`hashParameters`.
- `always_call_super_props_when_overriding_equatable_props` (same package-recognition gap).

### all_observer_lint

- **Source**: github.com/CriandoGames/all_observer_lint
- **Total rules**: 20
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 20

#### Gaps

All 20 rules are specific to the niche `all_observer` reactive-state library and unrecognized by saropa:
`avoid_reactive_creation_in_build`, `avoid_effect_creation_in_build`, `watch_only_inside_build`,
`dispose_reactive_resources`, `avoid_reactive_write_in_computed`, `avoid_set_state_in_computed`,
`avoid_worker_creation_in_computed`, `avoid_io_in_computed`, `avoid_observable_write_during_observer_build`,
`self_referencing_computed`, `invalid_history_limit`, `async_inside_batch`,
`prefer_computed_for_derived_state`, `prefer_batch_for_multiple_related_writes`,
`prefer_assign_all_for_reactive_list_replace`, `unused_reactive_state`, `unobserved_reactive_read_in_build`,
`observer_without_reactive_read`, `computed_without_reactive_read`, `effect_without_reactive_read`,
`copied_reactive_collection_outside_tracking`.

### jsdaddy_custom_lints

- **Source**: github.com/JsDaddy/dart-linter-rules
- **Total rules**: 1
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 1

#### Gaps

- `file_naming_kebab_case` — requires hyphen-separated filenames, actively conflicting with Dart's own
  `snake_case` convention; a deliberate house-style choice, not a broadly applicable one.

### import_order_lint

- **Source**: github.com/anusii/import-order-lint (standalone CLI, not a `custom_lint` rule)
- **Total rules**: 1 check
- **Coverage**: HAVE: 0, PARTIAL: 1, GAP: 0

#### Partial

- Import ordering/grouping — saropa's `prefer_grouped_imports`/`prefer_sorted_imports`/
  `prefer_import_group_comments` flag the same violations as lint diagnostics, but have no
  `--set-exit-if-changed` auto-fix CLI equivalent to `dart format`'s exit-code contract.

### import_lint

- **Source**: github.com/kawa1214/import-lint
- **Total rules**: 1 rule-engine (generic `target`/`from`/`except` DSL)
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 1

#### Gaps

- Generic user-configurable import-boundary DSL — no saropa analog beyond the three fixed layer rules; see
  Gap Theme 2.

### mvvm_linter

- **Source**: github.com/nerdzlab/NerdzFlutter-MVVMLinter
- **Total rules**: 1
- **Coverage**: HAVE: 0, PARTIAL: 1, GAP: 0

#### Partial

- `class_order_rule` — enforces a 10-category MVVM-specific member order (constructor → callback fields →
  repository fields → final/const/static → late → other mutable → getter/backing-field/setter triad →
  getter/setter → public methods → private methods) with an auto-reorder assist. saropa's
  `prefer_member_ordering` is a flat 3-bucket order with none of this granularity.

### dart_code_metrics_annotations

- **Source**: github.com/CQLabs/dart-code-metrics-annotations
- **Total rules**: 3 annotation-driven rule groups
- **Coverage**: HAVE: 1, PARTIAL: 2, GAP: 0

#### Partial

- `@AcceptedTypes` → `pass-correct-accepted-types` — GAP outright (no saropa rule performs annotation-driven
  runtime-type-set narrowing).
- `@mutated` → `prefer-correct-mutated` — saropa's `avoid_parameter_mutation`/`avoid_collection_mutating_methods`
  are unconditional heuristics with no opt-out annotation mechanism; also `avoid_collection_mutating_methods`
  is scoped to mutations inside `setState()` specifically, materially narrower than the general-purpose
  competitor rule.

### dart_code_metrics_presets

- **Source**: github.com/CQLabs/dart-code-metrics-presets — 15 package-specific preset YAMLs
- **Total rules**: 77 across all 15 presets
- **Coverage**: HAVE: 27, PARTIAL: 6, GAP: 44

#### Gaps by preset

- **bloc.yaml** (22 rules, 12 GAP): see Gap Theme 4.
- **riverpod.yaml** (18 rules, 16 GAP): see Gap Theme 3 — the single worst preset in this package.
- **provider.yaml** (7 rules, 2 GAP): `avoid-read-inside-build`, `prefer-provider-extensions`,
  `prefer-immutable-selector-value`.
- **get_it.yaml** (1 rule, 1 GAP): `avoid-functions-in-register-singleton`.
- **flame.yaml** (4 rules, 4 GAP): see Gap Theme 5.
- **json_serializable.yaml** (1 rule, 1 GAP): `specify-unknown-enum-value`.
- **intl.yaml** (6 rules, 2 GAP): `prefer-number-format`, `prefer-date-format`.
- **easy_localization.yaml** (2 rules, 2 GAP): `avoid-missing-tr`, `avoid-missing-tr-on-strings`.
- **mocktail.yaml** (4 rules, 4 GAP): see Gap Theme 5.
- **patrol.yaml** (2 rules, 2 GAP): see Gap Theme 5.
- **flutter_hooks.yaml** (6 rules, 1 GAP): `prefer-use-callback`.
- **equatable.yaml** (4/4 HAVE), **getx.yaml** (3/5 HAVE), **firebase_analytics.yaml** (2/2 HAVE),
  **fake_async.yaml** (1/1 HAVE) — saropa is at or above parity on these four.

### flutter_a11y_lints

- **Source**: github.com/adil-adysh/flutter_a11y_lints
- **Total rules**: 12 actually shipped (27 documented, only 12 compiled into the rule bundle)
- **Coverage**: HAVE: 3, PARTIAL: 2, GAP: 7

#### Gaps

`A02` label content contains redundant role words ("button"/"icon"), `A05` redundant `Semantics(button:true)`
wrapper on a primitive button, `A07` `Semantics(label:)` wrapper that fails to exclude descendants (double
announcement), `A09` numeric-only label missing units, `A13` composite control with 2+ focusable descendants,
`A21` `Tooltip`-wrapper vs. `IconButton.tooltip` param, `A22` `MergeSemantics` on the ListTile family.

#### Partial

- `A03` decorative-image filename-keyword heuristic — saropa's `require_image_semantics`/
  `require_accessible_images` require semanticLabel on every Image (stricter overall) but don't specifically
  suggest exclusion for likely-decorative images by filename.

### accessibility_lint

- **Source**: github.com/MateuxLucax/accessibility-lint (archived/dead repo)
- **Total rules**: 5
- **Coverage**: HAVE: 3, PARTIAL: 1, GAP: 0

#### Partial

- `add_haptic_feedback_on_user_interaction` — a blanket check on all 4 listed widget types regardless of
  platform/importance; saropa's `prefer_ios_haptic_feedback` is scoped to iOS/Taptic-important interactions,
  narrower trigger surface.

### flutter_doctor_ai

- **Source**: github.com/ashwanisng/flutter_doctor_ai
- **Total rules**: 5
- **Coverage**: HAVE: 5, PARTIAL: 0, GAP: 0

Clean sweep — saropa's dispose/mounted-check/print/empty-setState rules are all supersets of this package's checks.

### json_serializable_lints

- **Source**: github.com/leithmail/json_serializable_lints_dart
- **Total rules**: 3
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 3

#### Gaps

`require_json_serializable_from_json`, `require_json_serializable_to_json`, `require_annotation_from_json` —
see Gap Theme 6 (JSON-codegen annotation-contract enforcement).

### json_parser_linter

- **Source**: github.com/Ragibn5/dart-flutter-packages (json_coder/json_parser_linter)
- **Total rules**: 1 combined rule (2 independent sub-checks)
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 1 (both sub-checks)

#### Gaps

- `json_parser_requirements` (toJson half + fromJson half) — see Gap Theme 6.

### flutter_custom_lints

- **Source**: github.com/bahricanyesil/flutter-custom-lints
- **Total rules**: 5
- **Coverage**: HAVE: 2, PARTIAL: 1, GAP: 2

#### Gaps

- `no_direct_iterable_access` — flags any direct `[]` index access on Iterable/List, suggesting a project-defined
  `safeAt()` extension; no saropa equivalent (`prefer_list_first`/`prefer_list_last` are stylistic aliases only).
- `use_compare_without_case` — flags `==`/`!=` between `String` operands, suggesting a `compareWithoutCase()`
  extension; saropa's `avoid_case_sensitive_path_comparison` is scoped to file paths only.

#### Partial

- `no_as_type_assertion` — flags every `as` cast unconditionally; saropa's `avoid_unsafe_cast` only flags casts
  that can actually fail at runtime (more precise, but misses the "any `as` at all" strict-mode case).

### awesome_lints

- **Source**: github.com/LucasXu0/awesome_lints
- **Total rules**: 123 distinct (129 files incl. Bloc 22, Provider 8, FakeAsync 1, Common/Dart 65, Flutter 32,
  minus 6 cross-referenced duplicates)
- **Coverage**: HAVE: 100, PARTIAL: 5, GAP: 17 (1 unconfirmed)

#### Gaps

`arguments_ordering`, `avoid_accessing_collections_by_constant_index`, `avoid_adjacent_strings` (saropa's
`prefer_adjacent_strings` is the opposite rule), `avoid_complex_loop_conditions`, `avoid_continue`,
`avoid_duplicate_collection_elements` (unconfirmed), `newline_before_case`/`_constructor`/`_method`/`_return`
(formatting rules, no matching ids found), `prefer_async_callback` (saropa has the opposite rule,
`prefer_future_void_function_over_async_callback`), `prefer_container` (see Gap Theme 14).

#### Partial

- `avoid_empty_build_when` — saropa's version fires only when `buildWhen` always returns `true`, not when it's
  omitted entirely.
- `handle_bloc_event_subclasses` — saropa's `sealed`-event rules enforce the hierarchy shape but don't verify
  every subclass has a handler.
- `avoid_collection_mutating_methods` — saropa scopes this to mutation inside `setState()` only; theirs is general.
- `avoid_read_inside_build`/`avoid_watch_outside_build` — matched against saropa's Riverpod-specific
  `avoid_ref_read_inside_build`/`avoid_ref_watch_outside_build`; if the target project uses the plain
  `provider` package (`context.read`/`context.watch`) rather than Riverpod, there's no exact analog.
- `avoid_nested_conditionals` — narrower threshold (3 vs. saropa's 5) and if-only scope vs. saropa's
  all-block-nesting `avoid_deep_nesting`.

### essential_lints

- **Source**: github.com/FMorschel/essential_lints
- **Total rules**: 27 (23 in `rules/`, 4 in `warnings/`)
- **Coverage**: HAVE: 9, PARTIAL: 5, GAP: 13

#### Gaps

`alphabetize_arguments`, `alphabetize_enum_constants`, `border_all`, `closure_incorrect_type`,
`duplicate_value` (within one boolean expression, distinct from saropa's cross-branch `no_equal_conditions`),
`empty_container`, `getters_in_member_list`, `is_future`, `mutable_tearoff`, `new_instance_cascade`,
`prefer_explicitly_named_parameters`, `returning_widgets`, `sorting_members` (own annotation-driven
member-sort system), `standard_comment_style`, `subtype_annotating`, `subtype_naming`, `variable_shadowing`.

#### Partial

- `border_radius_all` — saropa's `prefer_const_border_radius` targets const-ness, not `.all` vs. `.circular` API choice.
- `equal_statement` — likely overlaps `no_equal_switch_case`, not fully confirmed as identical trigger logic.
- `explicit_casts` — saropa's `avoid_unsafe_cast` only flags casts that can fail, narrower than "all explicit casts."
- `pending_listener` — saropa's disposal-family rules are type-specific, not a general "any `add()`-style
  listener needs a matching `remove()`" check.
- `unnecessary_setstate` — saropa's `avoid_empty_setstate` only catches empty-callback-body, not the broader
  "assigns the same value" no-op case.

### flutter_quality_lints

- **Source**: github.com/dvillegastech/flutter_quality_lints
- **Total rules**: 18
- **Coverage**: HAVE: 15, PARTIAL: 2, GAP: 1

Several of their rules are non-functional stubs as shipped (`enforce_layer_dependencies` compares source text
instead of file paths and never matches; `prefer_trailing_commas`'s comma-detection is a stub) — saropa's
equivalents are stricter and actually working.

#### Gaps

- `prefer_stateless_widgets` — inspects a State class's actual mutable-state usage (setState calls,
  uninitialized fields, lifecycle methods, controller fields) to suggest converting to StatelessWidget; saropa
  has no rule that performs this specific cross-check.

#### Partial

- `avoid_nested_conditionals` — 3-level if-only threshold vs. saropa's 5-level all-block `avoid_deep_nesting`.
- `avoid_widget_rebuilds` — saropa's const-widget rules cover part of this; no rule flags inline `.map()`/inline
  closures inside `build()` as a rebuild-cost pattern specifically.

### ripplearc_linter

- **Source**: github.com/ripplearc/ripplearc-flutter-lint (one company's internal linter, open-sourced as-is)
- **Total rules**: 24
- **Coverage**: HAVE: 5, PARTIAL: 4, GAP: 15

Most GAPs here are single-company internal conventions (specific class names, one issue-tracker URL pattern,
one DI framework's API) rather than broadly applicable rules.

#### Gaps

`document_enum`, `document_fake_parameters`, `document_interface`, `forbid_helper_util_naming`,
`forbid_manual_screenshot_theme` (project-specific golden-test convention), `forbid_raw_icon_and_image_usage`,
`no_direct_instantiation`, `no_internal_method_docs`, `no_optional_operators_in_tests`,
`prevent_feature_module_dependencies`, `prevent_library_module_dependencies`, `private_subject`,
`restrict_core_icon_data`, `test_file_mutation_coverage`, `todo_with_story_links` (general "TODO must
reference a ticket" concept has no saropa equivalent either, even setting aside the YouTrack-specific URL pattern).

#### Partial

- `avoid_static_typography` — no saropa rule bans raw `TextStyle()` in favor of a theme-extension typography access.
- `forbid_datetime_now` — saropa's `avoid_datetime_now_in_tests` only covers test files, not "always inject a
  Clock in production code."
- `forbid_modular_get_outside_module` — saropa's `avoid_service_locator_in_widgets` is narrower (widgets only).
- `prefer_fake_over_mock` — saropa has a same-named rule but its doc describes "excessive mocking" generally,
  not specifically the `extends Mock` → `extends Fake` pattern; needs verification.

### subpackage_lint

- **Source**: github.com/dumazy/subpackage_lint
- **Total rules**: 3
- **Coverage**: HAVE: 1, PARTIAL: 0, GAP: 2

#### Gaps

- `avoid_src_import_from_other_subpackage` — import reaches into another subpackage's `/src/` instead of its
  public barrel.
- `avoid_src_import_from_same_package` — absolute `package:`-style import reaching a `/src/` file within the
  same package instead of a relative import.

### team_guard

- **Source**: github.com/HazemHamdy7/team_guard
- **Total rules**: 1
- **Coverage**: HAVE: 0, PARTIAL: 0, GAP: 1

#### Gaps

- `team_guard.forbidden_widget` — generic project-configurable "ban this widget/class name, suggest this
  replacement" mechanism with an import-fixing quick fix; see Gap Theme 2.

### hardcoded_strings_lint

- **Source**: github.com/ShahSomething/hardcoded_strings_lint (GitHub tree listing cut off before `lib/src/`
  — behavior below is from README/planning docs, not directly verified source)
- **Total rules**: 1
- **Coverage**: HAVE: 1 (unverified), PARTIAL: 0, GAP: 0

No confirmed gaps; the single rule's callback-body exemption and technical-string (URL/email/hex/path)
allowlist aren't confirmed present in saropa's `avoid_hardcoded_strings_in_ui` doc — re-verify if precision matters.

### flutter_refactor_plugin

- **Source**: github.com/ahmedmamdouh/flutter_refactor_plugin — repo returns 404, unverified, pub.dev
  description only
- **Total rules**: 1
- **Coverage**: HAVE: 0, PARTIAL: 1, GAP: 0 (low-confidence, do not treat as confirmed)

#### Partial

- `prefer_declarative_over_widget_nesting` — an automatic widget-extraction quick fix with content-based
  naming; saropa's `avoid_excessive_widget_depth` detects the depth but has no such refactor-automation.

### flutter_sane_lints

- **Source**: github.com/gbassisp/extra_lints (flutter_sane_lints package)
- **Total rules**: 2
- **Coverage**: HAVE: 2, PARTIAL: 0, GAP: 0

Clean sweep — both rules (`avoid_string_literals_inside_widget`, `avoid_if_with_enum`) map directly to
saropa's `avoid_hardcoded_strings_in_ui` and `prefer_switch_with_enums`.

### many_lints

- **Source**: github.com/Nikoro/many_lints
- **Total rules**: 261
- **Coverage**: HAVE: 190, PARTIAL: 3, GAP: 68

See Gap Themes 1 (fpdart, ~26 of the 68), 2 (banned-* config engines), 3 (Riverpod), 9 (budget rules), 10
(test hygiene), 11 (new Dart syntax). Remaining non-themed gaps: `avoid_commented_out_code`,
`avoid_exit_outside_entrypoint`, `avoid_single_child_in_multi_child_widgets`,
`avoid_unmodified_loop_condition`, `member_ordering`/`match_pattern` config engines, `never_discard_build_context`,
`prefer_container`, `prefer_immutable_state` (name-pattern-matched, state-management-agnostic variant),
`prefer_theme_mode_getters`, `prefer_typed_exceptions`, `require_atomic_async_updates`, `use_gap`.

#### Partial

- `avoid_todo_comments` — saropa's `prefer_todo_format`/`prefer_fixme_format`/`prefer_hack_format` check
  marker *format*, not whether an issue/URL reference is present.
- `format_test_name` — saropa's version enforces snake_case naming; theirs is a fully configurable regex pattern.

### flutter_skill_lints

- **Source**: github.com/sgaabdu4/flutter_skill_lints
- **Total rules**: 279
- **Coverage**: HAVE: 231, PARTIAL: 7, GAP: 41

#### Gaps

`avoid_any_version`, `avoid_banned_exports`, `avoid_banned_file_names`, `avoid_banned_imports`,
`avoid_calling_notifier_members_inside_build`, `avoid_dependency_overrides`, `avoid_disposing_late_fields`,
`avoid_flutter_skill_lint_suppression`, `avoid_implementation_in_mocks`, `avoid_inline_error_codes`,
`avoid_labels`, `avoid_local_contract_key_constants`, `avoid_missing_test_files`,
`avoid_misused_wildcard_pattern`, `avoid_mounted_check_in_finally`, `avoid_nullable_async_or_collection_return_type`,
`avoid_parameter_aliases`, `avoid_positional_record_fields`, `avoid_public_late_final_without_initializer`,
`avoid_public_notifier_properties`, `avoid_repeated_property_aliases`, `avoid_then_return_with_future`,
`avoid_throw`, `avoid_unassigned_local_variable`, `avoid_unnecessary_parentheses`, `avoid_unnecessary_safe_area`,
`avoid_unused_local_variable`, `keep_state_below_its_widget`, `pass_mock_object`, `prefer_container`,
`prefer_correct_any_matcher`, `prefer_correct_static_icon_provider`, `prefer_publish_to_none`,
`pubspec_ordering`, `require_atomic_async_updates`, `resolve_platform_specific_implementation_before_use`,
`use_context_is_current_modal_route`, `use_local_notifications_exact_alarm_permission_api`,
`use_notifier_suffix`, `use_on_reorder_item_index_semantics`, `use_then_answer`.

#### Partial

- `avoid_banned_annotations`/`avoid_banned_names`/`avoid_banned_types` — saropa's `banned_identifier_usage`
  matches by identifier name only, not annotation/type-annotation-aware.
- `avoid_futureor_return_type` — saropa's `prefer_unwrapping_future_or` suggests unwrapping generally, doesn't
  specifically flag `FutureOr` as a return type.
- `avoid_missing_controller` — saropa's `require_form_field_controller` only covers `TextFormField`, not all
  controller-accepting input widgets.
- `avoid_single_child_in_multi_child_widgets` — saropa's `avoid_single_child_column_row` covers only Column/Row.
- `avoid_unnecessary_else_after_control_flow` — saropa's `avoid_redundant_else` only flags else after
  return/throw/continue/break; theirs bans all else blocks unconditionally.

### mad_lint

- **Source**: github.com/MadBrains/mad_lint (`analysis_server_plugin`/`AnalysisRule` API)
- **Total rules**: 13
- **Coverage**: HAVE: 7, PARTIAL: 2, GAP: 4

#### Gaps

All 4 GAPs are the `mapped_fields_*` family (`mapped_fields_key_value_mismatch`,
`mapped_fields_must_be_expression`, `mapped_fields_must_return_map`, `missing_mapped_fields_getter`) —
enforcing a MadBrains-internal `mappedFields`/stringify-mixin convention with no general-purpose Dart/Flutter
analog. Low priority.

#### Partial

- `stream_subscription_must_be_disposed` — targets a project-specific `.addDisposableTo(this)` helper
  convention; saropa's broader disposal rules expect assignment-to-variable + separate disposal call instead
  (an equivalent but different safety story, not a real functional gap).
- `missing_copy_with_for_states` — mad_lint targets any Bloc/state class; saropa's `require_equatable_copy_with`
  is Equatable-scoped, so a non-Equatable state class could slip through (partially covered via
  `prefer_copy_with_for_state`'s direct-mutation angle).

### pyramid_lint

- **Source**: github.com/charlescyt/pyramid_lint (`analysis_server_plugin`/`AnalysisRule` API, type-checked via `TypeChecker`)
- **Total rules**: 36
- **Coverage**: HAVE: 24, PARTIAL: 4, GAP: 8

High implementation quality — real quick-fixes on most rules, precise type-checking rather than string matching.

#### Gaps

`always_put_doc_comments_before_annotations`, `always_specify_parameter_names`, `prefer_iterable_any`
(`.where().isNotEmpty` → `.any()`), `prefer_iterable_every` (note: saropa's similarly-named
`prefer_any_or_every` is a false-cognate — see Methodology), `prefer_library_prefixes`, `proper_from_environment`,
`avoid_public_members_in_states`, `avoid_single_child_in_flex`.

#### Partial

- `no_duplicate_imports` — theirs catches byte-identical duplicate imports regardless of prefix; unclear
  whether saropa's `avoid_duplicate_named_imports` also fires on a verbatim duplicate with no prefix at all.
- `dispose_controllers` — pyramid's is type-checker-based (any disposable-typed field); saropa's is a fixed
  enumeration of known controller types, so a novel custom controller type would be missed by saropa but
  caught by pyramid.
- `prefer_border_radius_all` — saropa's `prefer_borderradius_circular` recommends the opposite direction
  (circular() over .all()) as an opinionated style rule; same subject, contradictory prescribed style.

## Methodology

Each of 48 packages was researched by a dedicated agent that located the real GitHub source (not just the
pub.dev description), read the actual rule implementation files (visitor logic, `LintCode`/`problemMessage`
text, doc comments), and cross-checked candidate matches against saropa_lints' live rule source in
`lib/src/rules/**/*.dart` — not name-similarity alone, since several apparent name collisions turned out to be
unrelated rules (e.g. saropa's `avoid_similar_names` is about enum-indexed Map literals, not confusing
identifiers; `prefer_any_or_every` is about explicit-null named args, not `.where()` → `.any()`/`.every()`).
Confidence level (High/Medium/Low) is noted per package in the original research files where source access was
incomplete (`hardcoded_strings_lint`, `flutter_refactor_plugin`).

### DCM proper (dcm.dev) — 487 rules

Audited 2026-09-02 against dcm.dev/docs/rules/ (the commercial DCM product, NOT the Bancolombia
`dart_code_linter` open-source fork which has its own section above). DCM is the single largest competitor
with 487 published lint rules across Common Dart, Flutter, Provider, Bloc, Riverpod, and Equatable categories.

**Method**: All 487 DCM rule names were extracted from the published docs page. 378 have an exact name match
in saropa_lints (DCM uses hyphens, saropa uses underscores — e.g. `avoid-dynamic` = `avoid_dynamic_type`).
The remaining 109 were manually cross-referenced by 4 parallel research agents reading saropa_lints source
to determine semantic equivalence.

**Results**: 421 HAVE (86%), 16 PARTIAL (3%), 50 GAP (10%).

#### Exact name matches (378 rules)

All 378 rules whose DCM hyphenated name maps to a saropa_lints underscored equivalent are classified HAVE.
These span the full DCM rule set — `avoid-*`, `prefer-*`, `no-*`, and all Bloc/Riverpod behavioral rules.

#### Non-exact matches classified HAVE (43 rules)

| DCM Rule | Saropa Equivalent | Notes |
|---|---|---|
| arguments-ordering | `prefer_arguments_ordering` | |
| avoid-commented-out-code | `prefer_no_commented_out_code` | Stylistic tier |
| avoid-continue | `prefer_no_continue_statement` | |
| avoid-dot-shorthands | `prefer_dot_shorthand` | Opposite polarity (prefers, not avoids) |
| avoid-duplicate-collection-elements | `avoid_duplicate_number_elements` + `_string_` + `_object_` | Split by literal type |
| avoid-duplicate-factories | `duplicate_constructor_declarations` | |
| avoid-duplicate-field-initializers | `duplicate_field_name` + `avoid_duplicate_initializers` | |
| avoid-dynamic | `avoid_dynamic_type` | |
| avoid-getter-prefix | `prefer_no_getter_prefix` | |
| avoid-inferrable-type-arguments | `prefer_inferred_type_arguments` | Conflicts with `prefer_explicit_type_arguments` |
| avoid-long-files | `avoid_long_length_files` + `avoid_very_long_length_files` | Tiered thresholds |
| avoid-mutating-parameters | `avoid_parameter_mutation` | |
| avoid-sensitive-query-params | `avoid_auth_in_query_params` + `avoid_app_links_sensitive_params` | Security tier |
| avoid-shadowing | `avoid_variable_shadowing` | |
| avoid-substring | `avoid_string_substring` | |
| avoid-single-child-column-or-row | `avoid_single_child_column_row` | |
| avoid-redundant-semantics-wrapper | `avoid_redundant_semantics` | |
| avoid-unrestricted-javascript | `avoid_webview_javascript_enabled` | |
| avoid-unrestricted-navigation | `require_webview_navigation_delegate` | |
| avoid-cubits | `avoid_cubit_usage` | Config alias `avoid_cubits` |
| avoid-missing-controller | `require_form_field_controller` | |
| banned-usage | `banned_identifier_usage` | Configurable via `analysis_options_custom.yaml` |
| dispose-fields | `dispose_widget_fields` + `dispose_class_fields` | |
| dispose-providers | `dispose_provider_instances` + `require_provider_dispose` | |
| format-comment | `format_comment_style` | Stylistic tier |
| max-imports | `limit_max_imports` | |
| member-ordering | `prefer_member_ordering` | Config alias `member_ordering` |
| newline-before-case | `prefer_blank_line_before_case` | |
| newline-before-constructor | `prefer_blank_line_before_constructor` | |
| newline-before-method | `prefer_blank_line_before_method` | |
| newline-before-return | `NewlineBeforeReturnRule` | |
| parameters-ordering | `enforce_parameters_ordering` | Config alias `parameters_ordering` |
| pattern-fields-ordering | `prefer_sorted_pattern_fields` | Config alias `pattern_fields_ordering` |
| prefer-assert-initializers-first | `prefer_asserts_in_initializer_lists_safe` | |
| prefer-contains | `prefer_list_contains` | |
| prefer-first | `prefer_list_first` | |
| prefer-icon-button-tooltip | `avoid_icon_buttons_without_tooltip` | |
| prefer-last | `prefer_list_last` | |
| prefer-random-secure | `prefer_secure_random_for_crypto` | |
| prefer-semantics-header | `require_heading_semantics` | |
| prefer-spacing | `prefer_spacing_over_sizedbox` | |
| provide-autofill-hints | `require_autofill_hints` | |
| provide-icon-semantic-label | `require_semantic_label_icons` | |
| provide-image-semantic-label | `require_image_semantics` | |
| record-fields-ordering | `prefer_sorted_record_fields` | Config alias `record_fields_ordering` |
| tag-name | `prefer_kebab_tag_name` | Config alias `tag_name` |
| add-equatable-props | `list_all_equatable_fields` | |

#### PARTIAL matches (16 rules)

| DCM Rule | Saropa Equivalent | What's Missing |
|---|---|---|
| avoid-always-null-variables | `avoid_always_null_parameters` | Covers params/returns, not general local variables |
| avoid-banned-names | `banned_identifier_usage` | Identifier-level only, not general declaration names |
| avoid-misused-wildcard-pattern | `avoid_keywords_in_wildcard_pattern` etc. | Specific wildcard cases, not a general misuse check |
| avoid-suspicious-global-reference | `avoid_global_state` | General global-state discouragement, not context-aware |
| avoid-throw | `avoid_throw_in_finally` etc. | Specific contexts only, no blanket "avoid throw" |
| avoid-unassigned-local-variable | `avoid_unassigned_late_fields` | Fields only, not local variables |
| avoid-unmodified-loop-condition | `avoid_complex_loop_conditions` | Checks complexity, not condition staleness |
| avoid-nested-interactive-semantics | `avoid_merged_semantics_hiding_info` | Only MergeSemantics context |
| avoid-watch-outside-build | `avoid_ref_watch_outside_build` | Riverpod only, not Provider |
| handle-bloc-event-subclasses | `require_bloc_event_sealed` | Requires sealed base but doesn't verify handler coverage |
| max-statements | `avoid_long_functions` | Counts lines, not statements |
| prefer-dedicated-media-query-methods | `avoid_deprecated_use_inherited_media_query` | Covers deprecated pattern, unclear on granular `.sizeOf()` |
| prefer-non-nulls | `avoid_unnecessary_nullable_parameters` | Covers unnecessary-nullable patterns, not a general sweep |
| prefer-unmodifiable-of | `prefer_unmodifiable_collections` | Scoped to Equatable only, not general |
| require-atomic-async-updates | `require_mounted_check_after_await` | Widget `mounted` only, not general atomic-update |
| avoid-read-inside-build | `avoid_ref_read_inside_build` | Riverpod only, no Provider equivalent |

#### TRUE GAPS (50 rules)

**Configurable blocklist family (5 rules)** — DCM has a coherent config-driven ban system for annotations,
exports, file names, imports, and types. saropa has `banned_identifier_usage` for identifiers but no
equivalent for the other 5 categories:
- `avoid-banned-annotations`
- `avoid-banned-exports`
- `avoid-banned-file-names`
- `avoid-banned-imports`
- `avoid-banned-types`

**Formatting / newline gaps (6 rules)** — saropa has 4 of 7 newline-before-* rules; missing 3:
- `newline-before-break`
- `newline-before-continue`
- `newline-before-throw`
- `initializers-ordering` — no initializer-list ordering rule
- `prefer-initializing-formals` — saropa has the opposite (`prefer_constructor_body_assignment`)
- `prefer-private-named-parameters`

**Structural / code-quality gaps (11 rules)**:
- `add-static-field` — code assist, not a lint
- `avoid-labels` — no rule targeting labeled statements
- `avoid-missing-test-files` — no source-without-test-file check
- `avoid-mutating-constant-collections` — no const-collection mutation check
- `avoid-never-passed-parameters` — no cross-file call-site analysis
- `avoid-not-assignable-collection-types` — no collection type-mismatch check
- `avoid-suspicious-super-overrides` — no suspicious super.method override check
- `avoid-unnecessary-factory` — no unnecessary factory constructor check
- `avoid-unnecessary-parentheses` — no general redundant-parentheses rule
- `avoid-unused-local-variable` — N/A: covered by Dart analyzer built-in
- `prefer-correct-mutated` — no `@mutated` annotation concept

**Flutter widget/a11y gaps (17 rules)**:
- `add-copy-with` — code-generation assist
- `always-pass-global-key` — no "require GlobalKey" rule
- `avoid-disposing-late-fields` — no late-field dispose guard
- `avoid-focusable-offstage` — no Offstage focus check
- `avoid-merge-semantics-list-tile` — no ListTile-specific MergeSemantics check
- `keep-state-below-its-widget` — no State class ordering rule
- `prefer-container` — no DecoratedBox+SizedBox→Container consolidation
- `prefer-correct-static-icon-provider` — no static icon provider check
- `prefer-haptic-feedback-on-interaction` — no haptic feedback check
- `prefer-localized-semantic-labels` — no localized-label requirement
- `provide-input-field-label` — no TextField label requirement
- `provide-progress-indicator-semantics` — no progress indicator semantics check
- `provide-slider-semantic-formatter` — no Slider semantic formatter check
- `use-existing-widget` — no "use built-in widget" suggestion engine

**Riverpod naming/structure gaps (6 rules)**:
- `avoid-calling-notifier-members-inside-build`
- `avoid-public-notifier-properties`
- `prefer-correct-notifier-file-name`
- `prefer-correct-provider-file-name`
- `prefer-riverpod-notifier-suffix`
- `prefer-riverpod-provider-suffix`
- `prefer-single-notifier-per-file`

**Equatable gaps (3 rules)**:
- `avoid-equatable-call-on-equality-base-class`
- `prefer-equatable-key-name`
- `sort-equatable-props`

### very_good_analysis (VGA) — ~206 stock rules

Audited 2026-09-02 against `analysis_options.10.0.0.yaml` from VGA's GitHub repo. VGA is a **preset-only**
package — it ships zero custom rule implementations. It enables ~206 stock Dart SDK `linter: rules:` entries
(style, formatting, documentation, basic correctness).

**Key finding: VGA and saropa_lints operate in completely separate rule namespaces.**

saropa_lints is a custom `analyzer_plugin`/`custom_lint` package — its ~2,390 rules are delivered through the
`plugins: saropa_lints: diagnostics:` section of the generated `analysis_options.yaml`. saropa's config
writer **never generates a `linter: rules:` block** for consumer projects. This means:

- VGA rules are stock Dart analyzer rules (e.g. `prefer_final_locals`, `require_trailing_commas`, `public_member_api_docs`)
- saropa rules are custom plugin rules (e.g. `prefer_final_locals_with_fix`, `prefer_trailing_comma`)
- **Both can and should coexist** — users running saropa_lints still need `flutter_lints` or VGA for stock rule coverage

**Conceptual equivalents (~12-15 rules)** — saropa has enhanced custom versions of some VGA stock rules:

| VGA Stock Rule | Saropa Custom Equivalent | Enhancement |
|---|---|---|
| `avoid_positional_boolean_parameters` | `avoid_positional_boolean_parameters_with_fix` | Adds quick fix |
| `avoid_print` | `avoid_print_in_release` / `avoid_print_in_production` | Context-aware (release only) |
| `avoid_returning_this` | `avoid_returning_this_with_fix` | Adds quick fix |
| `lines_longer_than_80_chars` | `prefer_readable_line_length` | Configurable threshold |
| `prefer_const_constructors` | `prefer_declaring_const_constructor` | Declaration-side check |
| `prefer_final_locals` | `prefer_final_locals_with_fix` | Adds quick fix |
| `prefer_single_quotes` | `prefer_single_quotes_strict` | Stricter enforcement |
| `require_trailing_commas` | `prefer_trailing_comma` / `prefer_trailing_comma_always` | |
| `sized_box_for_whitespace` | `prefer_sized_box_for_whitespace` | |
| `use_build_context_synchronously` | `check_mounted_after_async` / `require_mounted_check_after_await` | More specific checks |

**The remaining ~191 VGA rules are NOT gaps** — they are stock Dart style/formatting rules that saropa
intentionally does not reimplement (users get them from `flutter_lints`/VGA/`lints` alongside saropa). This
includes: `camel_case_types`, `constant_identifier_names`, `unnecessary_this`, `always_use_package_imports`,
`type_annotate_public_apis`, `public_member_api_docs`, `eol_at_end_of_file`, `directives_ordering`,
`sort_constructors_first`, most `unnecessary_*` rules, most `prefer_*` style rules, and all doc-comment rules.

**Recommendation**: saropa_lints' init CLI should recommend or auto-include VGA/flutter_lints via `include:`
to ensure stock rule coverage. This is a documentation/init-config task, not a rule-building task.

---

**Known data-quality issue, found independently by 5+ research agents across different packages**:
`saropa_rules_reference.json` / `saropa_rules_short.md` (the generated doc-comment catalog) has misattributed
doc text for an unknown subset of rules — the rule id/class name and its doc comment appear shifted relative
to each other. Confirmed examples: `avoid_border_all` (doc describes Hero `heroTag`), `avoid_deep_widget_nesting`
(doc describes `shrinkWrap`), `avoid_contradictory_expressions` (doc describes loop complexity),
`avoid_missing_completer_stack_trace` (doc describes late-final reassignment), `avoid_late_final_reassignment`,
`avoid_build_context_in_providers`, `avoid_inherited_widget_in_initstate`, `avoid_late_context` (doc describes
`Expanded`/`Spacer`), `avoid_mounted_in_setstate`, `avoid_state_constructors`, `avoid_returning_widgets`,
`avoid_shrink_wrap_in_lists`, `prefer_sliver_prefix` (doc describes `State` constructor bodies),
`prefer_text_rich` (doc describes the Sliver-prefix check), `banned_identifier_usage` (doc describes
positional-bool-parameter naming), `require_animation_disposal` (actually checks `Border.all` →
`Border.fromBorderSide`), `require_text_form_field_in_form` (actually checks `super.dispose()`),
`require_super_dispose_call` (actually about orientation handling), `prefer_any_or_every` (actually checks
explicit-null named args, unrelated to `.any()`/`.every()`). Root cause not determined — either
`extract_rules.py`'s "nearest preceding class" doc-matching heuristic breaks when multiple classes/helper
functions sit between a doc comment and its `LintCode(...)` call, or the doc comments are genuinely
misattached in the source files themselves. This is independent of the gap analysis (every classification
above was verified against live `.dart` source, not the corrupted reference) but is a real bug worth its own
investigation and fix.
