# Legacy Task File Reconciliation

Reconciles `plans/history/**/task_*.md` (350 files) against the current rule catalog
(`lib/src/tiers.dart` + `lib/src/rules/`). 335 of the 350 carry `**Status**: Planned` in their header —
a boilerplate field most were never updated after implementation. Cross-referenced each file's rule-name
(derived from filename) against tiers.dart and the rule source.

## Method

1. Extracted a candidate rule id from each filename (strip `task_` prefix, leading emoji, `.md` suffix).
2. Matched against `tiers.dart` string literals (exact rule id).
3. Fallback: searched all `lib/src/rules/**/*.dart` source for the rule id as a string literal (covers
   rules implemented but not yet tier-assigned).
4. Fallback: guessed a PascalCase rule-class name (`avoid_foo_bar` → `AvoidFooBarRule`) and searched for
   it — this catches rules saropa implemented under a *different* id than the task file proposed (e.g.
   the task named `prefer_final_locals`; saropa shipped it as `prefer_final_locals_with_fix`, since
   saropa deliberately doesn't reimplement stock Dart-SDK lints verbatim — it extends them with fixes/
   stricter triggers, hence the suffix).

## Results

| Category | Count |
|---|---|
| Total task files | 350 |
| No `Status` field (implicitly not tracked) | 1 |
| Already implemented (exact tiers.dart or source match) | 260 |
| Already implemented (confirmed via class-name lookup, different final rule id) | 27 |
| **Genuinely still open** | **37** |
| Duplicate filename across two history dates (same rule proposed twice) | 1 (`avoid_any_version`) |

**287 of 335 "Planned" task files (85.7%) describe work that is already done.** Their `Status: Planned`
header is stale — a historical-record accuracy issue, not a missing-work issue. Left as-is since these
are archived records in `plans/history/`, not active tracking; re-auditing/rewriting 287 archive files'
status fields was judged lower value than surfacing the actual open list below.

## Genuinely open (37 unique rules, no implementation and no filed proposal)

Cross-checked against the 298 proposals filed this session (`bugs/proposal_*.md`) — none of these 37
overlap with a competitor-package migration-guide gap, meaning they are saropa's own internal roadmap
ideas rather than DCM/alternative-package parity items.

### Correctness / code-quality
- `avoid_equals_and_hash_code_on_mutable_classes`
- `avoid_implementing_value_types`
- `avoid_null_checks_in_equality_operators`
- `avoid_private_typedef_functions`
- `avoid_redundant_argument_values`
- `prefer_expression_function_bodies`
- `avoid_dynamic_calls`
- `avoid_repeated_widget_creation`
- `avoid_suspicious_global_reference`
- `avoid_unbounded_collections`
- `prefer_composition_over_inheritance`
- `prefer_automatic_dispose`
- `handle_bloc_event_subclasses` (also raised independently by `bloc_lint` — see
  `plans/GAP_ANALYSIS.md` Gap Theme 4; worth folding into that Bloc-completeness batch instead of
  building standalone)

### Security
- `avoid_banned_api`
- `avoid_firestore_admin_role_overuse`
- `avoid_remember_me_insecure`
- `avoid_secure_storage_in_background`
- `avoid_url_launcher_sandbox_issues`
- `avoid_webview_local_storage_access`

### Platform / performance
- `avoid_connectivity_ui_decisions`
- `avoid_large_assets_on_web`
- `avoid_large_object_in_state`
- `avoid_pagination_refetch_all`
- `prefer_intent_filter_export`

### pubspec.yaml hygiene
- `add_resolution_workspace`
- `dependencies_ordering`
- `newline_before_pubspec_entry`
- `prefer_caret_version_syntax`
- `prefer_commenting_pubspec_ignores`
- `prefer_pinned_version_syntax`
- `pubspec_ordering`

### Style / docs
- `prefer_inline_comments_sparingly`
- `prefer_l10n_yaml_config`
- `prefer_correct_screenshots`

### Architecture / testing infra
- `require_barrel_files`
- `require_di_module_separation`
- `require_resource_tracker`
- `require_test_coverage_threshold`
- `require_test_golden_threshold`

## Recovered: TODO_BUILD_NEXT.md (deleted 2026-05-20, commit `8d15d688^`)

Recovered via `git show 8d15d688^:TODO_BUILD_NEXT.md` and cross-checked against `tiers.dart`. It listed
25 items in two parts:

**Part A — platform/repo-config cross-reference (8 rules): all DONE.**
`require_android_manifest_entries`, `require_ios_info_plist_entries`, `require_desktop_window_setup`,
`avoid_audio_in_background_without_config`, `avoid_geolocator_background_without_config`,
`require_notification_icon_kept`, `require_firestore_security_rules`, `require_env_file_gitignore`.

**Part B — cross-file/project-graph rules (17 rules): all still OPEN.** These need project-wide graph
infrastructure (`ImportGraphCache`, the `cross_file` CLI — see `plans/cross_file_cli_design.md`,
`plans/deferred/cross_file_analysis.md`) rather than per-file AST visitors, which is why they were
deferred in the original doc and remain unbuilt:
`avoid_provider_circular_dependency`, `avoid_riverpod_circular_provider`,
`require_riverpod_test_override`, `require_go_router_deep_link_test`, `require_test_coverage_threshold`,
`require_test_golden_threshold`, `require_barrel_files`, `require_riverpod_override_in_tests`,
`require_bloc_test_coverage`, `require_e2e_coverage`, `avoid_never_passed_parameters`,
`require_missing_test_files`, `require_temp_file_cleanup`, `avoid_getit_unregistered_access`,
`require_crash_reporting`, `prefer_layer_separation`, `require_di_module_separation`.

Five of these (`require_test_coverage_threshold`, `require_test_golden_threshold`,
`require_barrel_files`, `require_di_module_separation`, and — from the doc's own "package-specific
follow-up batch" list — `handle_bloc_event_subclasses`, `prefer_correct_screenshots`,
`prefer_intent_filter_export`, `require_resource_tracker`) already appear in the 37-item open list
above, confirming both reconciliation passes agree. The doc is not being restored to the repo root —
its content is fully captured here and its cross-file-CLI framing is now stale (superseded by whatever
state `bin/cross_file.dart` is in today); treat this section as the historical record instead.

## Next step

The 37 open items above have no proposal file. Before implementing any of them, file proposals
(`bugs/proposal_*.md`, same format as the 298 filed this session) so they're tracked the same way as
every other pending rule.
