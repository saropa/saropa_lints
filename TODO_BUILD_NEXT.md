# TODO: Next 25 lint-related builds

**Sources:** [ROADMAP.md](ROADMAP.md) (Part 2 — Implementable Rules), [plan/deferred/cross_file_analysis.md](plan/deferred/cross_file_analysis.md), [plan/README.md](plan/README.md), [plan/cross_file_cli_design.md](plan/cross_file_cli_design.md).

**Scope note:** Items **1–8** are per-file Dart rules that **cross-check platform or repo config** (same product pattern as existing iOS checks). Items **9–25** are **deferred as single-plugin-file rules** today; the practical “build” is extending **`dart run saropa_lints:cross_file`**, `ImportGraphCache`, and/or the extension sidebar so these become enforceable without false confidence from AST-only heuristics.

**Workflow (any new rule):** [CONTRIBUTING.md](CONTRIBUTING.md), [CLAUDE.md](CLAUDE.md), [.claude/skills/lint-rules/SKILL.md](.claude/skills/lint-rules/SKILL.md) — register in [lib/src/rules/all_rules.dart](lib/src/rules/all_rules.dart) and [lib/src/tiers.dart](lib/src/tiers.dart), fixture in `example/` (only when BAD fires), test under `test/`, [CHANGELOG.md](CHANGELOG.md) under Unreleased.

---

## Part A — Platform & repo config cross-reference (8 rules)

These match the table in [ROADMAP.md — Part 2 — Platform Config Cross-Reference Rules](ROADMAP.md#platform-config-cross-reference-rules). GitHub tracking: [#35](https://github.com/saropa/saropa_lints/issues/35), [#36](https://github.com/saropa/saropa_lints/issues/36), [#37](https://github.com/saropa/saropa_lints/issues/37), [#41](https://github.com/saropa/saropa_lints/issues/41).

| # | Rule name | Tier (ROADMAP) | Severity (ROADMAP) | Config / artifact |
|---|-----------|----------------|--------------------|---------------------|
| 1 | `require_android_manifest_entries` | Essential | ERROR | `android/**/AndroidManifest.xml` |
| 2 | `require_ios_info_plist_entries` | Essential | ERROR | `ios/Runner/Info.plist` |
| 3 | `require_desktop_window_setup` | Professional | INFO | macOS/Windows/Linux window metadata |
| 4 | `avoid_audio_in_background_without_config` | Essential | ERROR | `Info.plist` + `AndroidManifest.xml` |
| 5 | `avoid_geolocator_background_without_config` | Essential | ERROR | `Info.plist` + `AndroidManifest.xml` |
| 6 | `require_notification_icon_kept` | Essential | ERROR | `proguard-rules.pro` (R8 / shrinker) |
| 7 | `require_firestore_security_rules` | Essential | ERROR | `firestore.rules` |
| 8 | `require_env_file_gitignore` | Essential | ERROR | `.gitignore` |

### Shared implementation pattern

- **Existing iOS pattern:** [lib/src/info_plist_utils.dart](lib/src/info_plist_utils.dart) — `InfoPlistChecker.forFile()`, project root via `pubspec.yaml`, cached read of `ios/Runner/Info.plist`, `hasKey()` style checks. New rules should add **small dedicated parsers** (or a shared `XmlConfigReader`) rather than ad-hoc string scans across the tree.
- **Existing Android narrative in rules:** [lib/src/rules/platforms/android_rules.dart](lib/src/rules/platforms/android_rules.dart), [lib/src/rules/widget/widget_patterns_require_rules.dart](lib/src/rules/widget/widget_patterns_require_rules.dart) (AndroidManifest snippets in DartDoc, permission / queries guidance).
- **Project gating:** [lib/src/project_context.dart](lib/src/project_context.dart) — `ProjectContext.of(context).isFlutterProject`, `usesPackage(...)`, skip non-Flutter or irrelevant packages (e.g. `geolocator`, `just_audio` / `audio_session` only when present).
- **False-positive discipline:** [CONTRIBUTING.md](CONTRIBUTING.md) “Avoiding False Positives”, [bugs/](bugs/) history under `false_positives/` if similar rules already triaged strings.

### Per-rule detail

1. **`require_android_manifest_entries`**  
   - **Intent:** When Dart/Flutter code uses APIs that require manifest declarations (`<uses-permission>`, `<service>`, `<receiver>`, `android:exported`, `tools:replace`, etc.), assert the corresponding XML entries exist.  
   - **Build:** XML parser (package or lightweight) for `AndroidManifest.xml`; map **API → required manifest fragments** (mirror how camera/microphone docs exist today in widget rules).  
   - **Refs:** ROADMAP table; [android_rules.dart](lib/src/rules/platforms/android_rules.dart) for style of platform messaging.

2. **`require_ios_info_plist_entries`**  
   - **Intent:** Generic “required keys present for used capability” beyond the many granular `require_ios_*` rules already in [lib/src/tiers.dart](lib/src/tiers.dart). Could mean a **data-driven** list (usage of API X ⇒ key Y) or a **project-configurable** allowlist file — product decision before coding.  
   - **Build:** Reuse `InfoPlistChecker`; extend with optional config path or in-rule tables.  
   - **Refs:** ROADMAP “Parser exists”; [info_plist_utils.dart](lib/src/info_plist_utils.dart).

3. **`require_desktop_window_setup`**  
   - **Intent:** Flutter desktop apps using window_manager / bitsdojo / multi-window packages should have platform-specific setup (title bar, min size, close handler).  
   - **Build:** Gate on `ProjectContext` + desktop; read `windows/runner/`, `linux/`, `macos/Runner/` files as needed; keep INFO severity to avoid noise on web-only projects.

4. **`avoid_audio_in_background_without_config`**  
   - **Intent:** Background audio requires UIBackgroundModes audio on iOS and foreground service / manifest entries on Android.  
   - **Build:** Detect imports/usages (`just_audio`, `audio_service`, etc.); join `InfoPlistChecker` + new manifest parser.

5. **`avoid_geolocator_background_without_config`**  
   - **Intent:** Background location updates need `UIBackgroundModes` location, Android background location permission and manifest.  
   - **Build:** Gate on `usesPackage('geolocator')` or type names; cross-check both platforms. Complements existing `prefer_geolocator_*` battery rules in tiers (not a duplicate).

6. **`require_notification_icon_kept`**  
   - **Intent:** ProGuard/R8 rules that strip notification small-icon resources break FCM/system notifications.  
   - **Build:** Parse `android/app/proguard-rules.pro` (and flavors) for `-keep` / `res/raw` patterns when `firebase_messaging` or `flutter_local_notifications` is used.

7. **`require_firestore_security_rules`**  
   - **Intent:** Projects with `cloud_firestore` dependency should have a `firestore.rules` file under repo root (or monorepo path discoverable from `firebase.json`).  
   - **Build:** Read `firebase.json` if present; else heuristic file existence at default path; ERROR only when Firestore usage is detected in Dart.

8. **`require_env_file_gitignore`**  
   - **Intent:** `.env` / `.env.*` containing secrets must be listed in `.gitignore`.  
   - **Build:** Text parse `.gitignore`; glob `.env*` at project root; report if tracked file would leak (optional: only flag when `dotenv` / `envied` detected). **Note:** [plan/deferred/cross_file_analysis.md](plan/deferred/cross_file_analysis.md) also mentions `avoid_envied_secrets_in_repo` needing `.gitignore` — align messaging, don’t double-report.

---

## Part B — Cross-file / project-graph rules (17 rules)

**Why here:** [plan/deferred/cross_file_analysis.md](plan/deferred/cross_file_analysis.md) documents that the **analyzer plugin is per-file**; these need **project-wide graphs** or **test layout** knowledge.

**Where to implement first:** [lib/src/project_context_import_location.dart](lib/src/project_context_import_location.dart) (`ImportGraphCache`, `getImporters()`, `detectCircularImports()`), [lib/src/cli/cross_file_analyzer.dart](lib/src/cli/cross_file_analyzer.dart), [bin/cross_file.dart](bin/cross_file.dart), design notes in [plan/cross_file_cli_design.md](plan/cross_file_cli_design.md) (planned: unused symbols, dead imports, watch mode). [ROADMAP.md](ROADMAP.md) “Cross-File CLI Improvements” lists **Unused symbols detection**, **Cross-feature dependency analysis**, **Dead import detection**, **Extension UI integration** — these rules align with that roadmap.

### Provider / navigation (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 9 | `avoid_provider_circular_dependency` | ERROR | Provider graph across files — [issue #2](https://github.com/saropa/saropa_lints/issues/2) |
| 10 | `avoid_riverpod_circular_provider` | ERROR | `ref.watch` / `ref.read` dependency cycle — [issue #1](https://github.com/saropa/saropa_lints/issues/1) |
| 11 | `require_riverpod_test_override` | INFO | Overrides may live in `test/` harness files separate from tests |
| 12 | `require_go_router_deep_link_test` | INFO | Route tables vs test files |

**Implementation sketch:** Build a **directed graph** of providers (node = library or top-level provider field); cycles → ERROR. Start with **static** `ref.watch(a)` edges only; document false negatives for dynamic providers.

### Project / coverage / barrels (3)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 13 | `require_test_coverage_threshold` | INFO | LCOV or `dart test --coverage` output aggregation |
| 14 | `require_test_golden_threshold` | INFO | Golden file counts vs `matchesGoldenFile` usages |
| 15 | `require_barrel_files` | INFO | Import graph: many sibling imports → suggest barrel |

**Refs:** CLI `import-stats` / graph today; coverage is **new CLI command** or CI wrapper, not a Dart lint visitor.

### Bloc (2)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 16 | `require_riverpod_override_in_tests` | INFO | Same multi-file override concern as #11 |
| 17 | `require_bloc_test_coverage` | INFO | Bloc/Cubit classes vs `bloc_test` usage across `test/` |

### Unused / dead code (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 18 | `require_e2e_coverage` | INFO | Integration test layout vs `lib/` features |
| 19 | `avoid_never_passed_parameters` | INFO | All call sites of a parameter (AnalysisContextCollection in future) |
| 20 | `require_missing_test_files` | INFO | For each `lib/foo.dart`, check `test/foo_test.dart` (naming convention) |
| 21 | `require_temp_file_cleanup` | INFO | `Directory.systemTemp` / `createTemp` usage vs `delete` in same file or project — conservative heuristic |

### Architecture / DI (4)

| # | Rule | Severity | Need |
|---|------|----------|------|
| 22 | `avoid_getit_unregistered_access` | INFO | Registration in `injection.dart` vs `GetIt.I<>` in widgets |
| 23 | `require_crash_reporting` | INFO | Single `FirebaseCrashlytics.instance` setup vs many `recordError` call sites |
| 24 | `prefer_layer_separation` | INFO | Import direction: `domain` must not import `ui` — layer graph from path conventions |
| 25 | `require_di_module_separation` | INFO | Same intent as [plan/history/2026.03/20260301/task_require_di_module_separation.md](plan/history/2026.03/20260301/task_require_di_module_separation.md); also listed under “Hard” in [plan/history/2026.03/20260302/REMAINING_ROADMAP_RULES.md](plan/history/2026.03/20260302/REMAINING_ROADMAP_RULES.md) |

**Note:** [plan/history/2026.03/20260302/REMAINING_ROADMAP_RULES.md](plan/history/2026.03/20260302/REMAINING_ROADMAP_RULES.md) lists related tasks as **cross-file / YAML** — treat Part B as **CLI + baseline + HTML report** first; IDE squiggles only if analyzer gains multi-file API ([cross_file_analysis.md](plan/deferred/cross_file_analysis.md) “What would unblock”).

---

## Package-specific cross-file (follow-up batch — not in the 25 above)

Documented in the same deferred file but omitted here to keep the count at **25**: `require_supabase_auth_state_listener`, `require_workmanager_unique_name`, `require_iap_restore_handling`, `handle_bloc_event_subclasses`, `require_timezone_initialization`, `avoid_envied_secrets_in_repo`, `prefer_correct_screenshots`, `prefer_intent_filter_export`, `require_resource_tracker`. Use [plan/deferred/cross_file_analysis.md](plan/deferred/cross_file_analysis.md) “Package-Specific Cross-File” and “Misc” tables when planning **batch 2**.

---

## Explicit non-candidates (do not duplicate)

- **Analyzer duplicates:** [plan/deferred/plan_additional_rules_41_through_50.md](plan/deferred/plan_additional_rules_41_through_50.md) — entire batch deferred as built-in `dart analyze` diagnostics.  
- **Many “additional rules” 51–70:** same rationale in plan history — prefer domain-specific value.  
- **Already implemented examples from plan/history:** `return_in_generator`, `yield_in_non_generator`, `non_constant_map_element`, `abstract_field_initializer`, `avoid_inert_animation_value_in_build` — see [lib/src/rules/flow/control_flow_rules.dart](lib/src/rules/flow/control_flow_rules.dart), [lib/src/rules/data/collection_rules.dart](lib/src/rules/data/collection_rules.dart), [lib/src/rules/architecture/compile_time_syntax_rules.dart](lib/src/rules/architecture/compile_time_syntax_rules.dart), [lib/src/rules/ui/animation_rules.dart](lib/src/rules/ui/animation_rules.dart).

---

## Suggested build order

1. **Infrastructure:** Android XML + `.gitignore` text parsers (unlocks #1, #4, #5, #8).  
2. **Firestore / ProGuard** text heuristics (#6, #7).  
3. **Desktop** file probes (#3).  
4. **CLI graph extensions** for #9–#12 (highest GitHub demand).  
5. **Coverage / test-file presence** commands (#13–#14, #20).  
6. **Layer / DI** conventions behind `--path` and config file (#24–#25).

---

_Last generated from repo state 2026-04-25._
