# Dart SDK 3.0 migration rules — implemented (2026-03-20)

## Summary

Implemented **15** Saropa lint rules for APIs removed or deprecated in **Dart 3.0+** across `dart:core`, `dart:collection`, `dart:developer`, and `dart:io`, consolidated in `lib/src/rules/config/dart_sdk_3_removal_rules.dart`. Rules are **Recommended** tier, use **`requiredPatterns`** for early file skip, and prefer **element resolution** over name-only heuristics where possible.

## Rules (migration candidates #098–#107)

| Plan | Rule names |
|------|------------|
| #098 | `avoid_deprecated_list_constructor` |
| #099 | `avoid_removed_proxy_annotation`, `avoid_removed_provisional_annotation` |
| #100 | `avoid_deprecated_expires_getter` |
| #101 | `avoid_removed_cast_error` |
| #102 | `avoid_removed_fall_through_error` |
| #103 | `avoid_removed_abstract_class_instantiation_error` |
| #104 | `avoid_removed_cyclic_initialization_error` |
| #105 | `avoid_removed_nosuchmethoderror_default_constructor` |
| #106 | `avoid_removed_bidirectional_iterator` |
| #107 | `avoid_removed_deferred_library` |

## Extension (migration candidates #108–#115)

| Plan | Rule / notes |
|------|----------------|
| #108 | `avoid_deprecated_has_next_iterator` |
| #109, #114 | `avoid_removed_max_user_tags_constant` (quick fix) |
| #110 | `avoid_removed_dart_developer_metrics` |
| #111 | `avoid_deprecated_network_interface_list_supported` |
| #112 | Covered by existing `avoid_deprecated_expires_getter` |
| #113 | Covered by `avoid_removed_cast_error` + `avoid_removed_fall_through_error` |
| #115 | No rule: `dart:js_util` `callMethod` parameter widened (String still valid) |

Summary: `bugs/history/20260320/migration_candidates_108_115_implemented.md`.

## Source plans (archived from `plan/implementable_only_in_plugin_extension/`)

Moved into this folder:

- `migration-candidate-098-removed_the_deprecated_list_constructor_as_it_wasn_t_null_sa.md`
- `migration-candidate-099-removed_the_deprecated_proxy_and_provisional_annotations.md`
- `migration-candidate-100-removed_the_deprecated_deprecated_expires_getter.md`
- `migration-candidate-101-removed_the_deprecated_casterror_error.md`
- `migration-candidate-102-removed_the_deprecated_fallthrougherror_error_the_kind_of.md`
- `migration-candidate-103-removed_the_deprecated_abstractclassinstantiationerror_error.md`
- `migration-candidate-104-removed_the_deprecated_cyclicinitializationerror_cyclic_depe.md`
- `migration-candidate-105-removed_the_deprecated_nosuchmethoderror_default_constructor.md`
- `migration-candidate-106-removed_the_deprecated_bidirectionaliterator_class.md`
- `migration-candidate-107-removed_the_deprecated_deferredlibrary_class.md`

## Tests & fixtures

- `test/dart_sdk_3_removal_rules_test.dart` — registry, `LintImpact`, `requiredPatterns`, `rulesWithFixes`, fixture coverage
- `example/lib/dart_sdk_3_removal_fixture.dart` — BAD (`expect_lint`)
- `example/lib/dart_sdk_3_removal_good_fixture.dart` — GOOD (false-positive guard)

## Related fix

- `AvoidImplicitAnimationDisposeCastRule` now calls `disposeInvocationForCastAsDisposeTarget` from `lib/src/implicit_animation_dispose_cast_ast.dart` (was referencing a missing private helper).
