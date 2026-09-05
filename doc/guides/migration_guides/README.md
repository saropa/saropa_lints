# Migration Guides Index

One guide per alternative lint package, each mapping that package's rules to a saropa_lints equivalent (HAVE / PARTIAL / TODO).

**Aggregate coverage:** across the ~46 audited alternatives that ship custom rules (1,670 rules total,
excluding preset-only packages that just bundle stock analyzer lints), saropa_lints has a HAVE or PARTIAL
equivalent for **~75%** (1,258/1,670).

| Package | Guide | Coverage |
|---|---|---|
| accessibility_lint | [migration_from_accessibility_lint.md](migration_from_accessibility_lint.md) | 5 rules — 4 HAVE (80%), 1 PARTIAL |
| all_observer_lint | [migration_from_all_observer_lint.md](migration_from_all_observer_lint.md) | 21 rules — 21 TODO (100%) |
| architecture_linter | [migration_from_architecture_linter.md](migration_from_architecture_linter.md) | 3 rules — 3 TODO (100%) |
| architecture_lints | [migration_from_architecture_lints.md](migration_from_architecture_lints.md) | 26 rules — 4 PARTIAL, 22 TODO (84%) |
| awesome_lints | [migration_from_awesome_lints.md](migration_from_awesome_lints.md) | 128 rules — 115 HAVE (89%), 7 PARTIAL, 6 TODO (4%) |
| bloc_lint | [migration_from_bloc_lint.md](migration_from_bloc_lint.md) | 8 rules — 3 HAVE (37%), 5 PARTIAL |
| clean_architecture_kit | [migration_from_clean_architecture_kit.md](migration_from_clean_architecture_kit.md) | 16 rules — 3 PARTIAL, 13 TODO (81%) |
| context_plus_lint | [migration_from_context_plus_lint.md](migration_from_context_plus_lint.md) | 4 rules — 4 TODO (100%) |
| dart_code_linter | [migration_from_dart_code_linter.md](migration_from_dart_code_linter.md) | 87 rules — 77 HAVE (88%), 2 PARTIAL, 8 TODO (9%) |
| dart_code_metrics_annotations | [migration_from_dart_code_metrics_annotations.md](migration_from_dart_code_metrics_annotations.md) | 1 HAVE (33%), 2 PARTIAL (67%), 0 TODO (0%). |
| dart_code_metrics_presets | [migration_from_dart_code_metrics_presets.md](migration_from_dart_code_metrics_presets.md) | 63 rules — 43 HAVE (68%), 2 PARTIAL, 18 TODO (29%) |
| DCM (dart_code_metrics) | [migration_from_dcm.md](migration_from_dcm.md) | 487 rules — 431 HAVE (89%), 16 PARTIAL, 40 TODO (8%) |
| design_system_lints | [migration_from_design_system_lints.md](migration_from_design_system_lints.md) | 7 rules — 1 PARTIAL, 6 TODO (85%) |
| df_safer_dart_lints | [migration_from_df_safer_dart_lints.md](migration_from_df_safer_dart_lints.md) | 9 rules — 3 PARTIAL, 6 TODO (66%) |
| equatable_lint | [migration_from_equatable_lint.md](migration_from_equatable_lint.md) | 2 rules — 1 HAVE (50%), 1 TODO (50%) |
| equatable_lint_ultimate | [migration_from_equatable_lint_ultimate.md](migration_from_equatable_lint_ultimate.md) | 2 rules — 1 HAVE (50%), 1 TODO (50%) |
| essential_lints | [migration_from_essential_lints.md](migration_from_essential_lints.md) | 31 rules — 13 HAVE (42%), 5 PARTIAL, 13 TODO (42%) |
| fast_equatable_lint | [migration_from_fast_equatable_lint.md](migration_from_fast_equatable_lint.md) | 0 HAVE (0%), 0 PARTIAL (0%), 2 TODO (100%). |
| flutter_a11y_lints | [migration_from_flutter_a11y_lints.md](migration_from_flutter_a11y_lints.md) | 3 HAVE (25%), 2 PARTIAL (17%), 7 TODO (58%) — 12 rules actually shipped by flutter_a11y_lints (27 are documented but only 12 are compiled into the bundle). |
| flutter_best_practices_lints | [migration_from_flutter_best_practices_lints.md](migration_from_flutter_best_practices_lints.md) | 5 rules — 2 HAVE (40%), 1 PARTIAL, 2 TODO (40%) |
| flutter_custom_lints | [migration_from_flutter_custom_lints.md](migration_from_flutter_custom_lints.md) | 5 rules — 2 HAVE (40%), 1 PARTIAL, 2 TODO (40%) |
| flutter_doctor_ai | [migration_from_flutter_doctor_ai.md](migration_from_flutter_doctor_ai.md) | 5 rules — 5 HAVE (100%) |
| flutter_hooks_lint | [migration_from_flutter_hooks_lint.md](migration_from_flutter_hooks_lint.md) | 7 rules — 4 HAVE (57%), 1 PARTIAL, 2 TODO (28%) |
| flutter_quality_lints | [migration_from_flutter_quality_lints.md](migration_from_flutter_quality_lints.md) | 18 rules — 16 HAVE (89%), 2 PARTIAL, 0 TODO (0%) |
| flutter_refactor_plugin | [migration_from_flutter_refactor_plugin.md](migration_from_flutter_refactor_plugin.md) | 1 rules — 1 PARTIAL |
| flutter_sane_lints | [migration_from_flutter_sane_lints.md](migration_from_flutter_sane_lints.md) | 2 rules — 2 HAVE (100%) |
| flutter_skill_lints | [migration_from_flutter_skill_lints.md](migration_from_flutter_skill_lints.md) | 48 rules — 5 HAVE (10%), 6 PARTIAL, 37 TODO (77%) |
| hardcoded_strings_lint | [migration_from_hardcoded_strings_lint.md](migration_from_hardcoded_strings_lint.md) | 1 rules — 1 HAVE (100%) |
| import_lint | [migration_from_import_lint.md](migration_from_import_lint.md) | 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%). |
| import_order_lint | [migration_from_import_order_lint.md](migration_from_import_order_lint.md) | 0 HAVE (0%), 1 PARTIAL (100%), 0 TODO (0%). |
| jsdaddy_custom_lints | [migration_from_jsdaddy_custom_lints.md](migration_from_jsdaddy_custom_lints.md) | 1 rules — 1 TODO (100%) |
| json_parser_linter | [migration_from_json_parser_linter.md](migration_from_json_parser_linter.md) | 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%). |
| json_serializable_lints | [migration_from_json_serializable_lints.md](migration_from_json_serializable_lints.md) | 3 rules — 3 TODO (100%) |
| klin_dart | [migration_from_klin_dart.md](migration_from_klin_dart.md) | 6 rules — 2 HAVE (33%), 3 PARTIAL, 1 TODO (16%) |
| leancode_lint | [migration_from_leancode_lint.md](migration_from_leancode_lint.md) | 23 rules — 12 HAVE (52%), 5 PARTIAL, 6 TODO (26%) |
| logd_linters | [migration_from_logd_linters.md](migration_from_logd_linters.md) | 13 rules — 1 HAVE (7%), 12 TODO (92%) |
| mad_lint | [migration_from_mad_lint.md](migration_from_mad_lint.md) | 13 rules — 7 HAVE (53%), 2 PARTIAL, 4 TODO (30%) |
| many_lints | [migration_from_many_lints.md](migration_from_many_lints.md) | 266 rules — 204 HAVE (77%), 7 PARTIAL, 51 TODO (19%) |
| mvvm_linter | [migration_from_mvvm_linter.md](migration_from_mvvm_linter.md) | 1 rules — 1 PARTIAL |
| pyramid_lint | [migration_from_pyramid_lint.md](migration_from_pyramid_lint.md) | 37 rules — 29 HAVE (78%), 3 PARTIAL, 5 TODO (14%) |
| ripplearc_linter | [migration_from_ripplearc_linter.md](migration_from_ripplearc_linter.md) | 24 rules — 7 HAVE (29%), 4 PARTIAL, 13 TODO (54%) |
| riverpod_lint | [migration_from_riverpod_lint.md](migration_from_riverpod_lint.md) | 13 rules — 4 HAVE (30%), 9 TODO (69%) |
| solid_lints | [migration_from_solid_lints.md](migration_from_solid_lints.md) | 33 rules — 21 HAVE (63%), 3 PARTIAL, 9 TODO (27%) |
| subpackage_lint | [migration_from_subpackage_lint.md](migration_from_subpackage_lint.md) | 3 rules — 1 HAVE (33%), 2 TODO (66%) |
| team_guard | [migration_from_team_guard.md](migration_from_team_guard.md) | 0 HAVE (0%), 0 PARTIAL (0%), 1 TODO (100%). |
| VGA (very_good_analysis) | [migration_from_vga.md](migration_from_vga.md) | 191 stock rules audited. ~10 have an enhanced saropa custom equivalent (optional |

## One-click migration packs

Packages with meaningful HAVE coverage now have a corresponding **migration pack** in the VS Code extension. When a project still depends on one of these packages, the extension surfaces a "Migrate from …" pack in the Rule Packs dashboard under the **Migrations** domain. Toggling it on enables all equivalent saropa rules in one click — no manual rule-by-rule configuration needed.
