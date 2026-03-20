<!-- AUTO-SYNC: The heading and Goal line below are updated by the publish
     script via sync_roadmap_header() in scripts/modules/_rule_metrics.py.
     Heading regex: "# Roadmap: Aiming for N,NNN"
     Goal regex:    "Goal: NNN rules (NNN implemented, NNN remaining)"
     Goal is rounded up to the nearest 100. -->
# Roadmap: Aiming for 2,100 Lint Rules
<!-- cspell:disable -->

See [CHANGELOG.md](CHANGELOG.md) for implemented rules. Goal: 2100 rules (2071 implemented, 29 remaining).

> **When implementing**: Remove from ROADMAP, add to CHANGELOG, register in `all_rules.dart` + `tiers.dart`. See [CONTRIBUTING.md](CONTRIBUTING.md).

> **Planned rules**: Detailed task specs (examples, detection, false positives) are in [bugs/roadmap/](bugs/roadmap/) (one file per rule: `task_<rule_name>.md`). See [bugs/roadmap/README.md](bugs/roadmap/README.md) for the index.

> **Deferred rules**: Rules we do not implement yet because they need cross-file analysis, YAML/config parsing, or heuristic detection with high false-positive risk → see **Part 2: Deferred Rules & Technical Limitations** below for why each group is deferred.

### Legend

| Emoji | Meaning |
|-------|---------|
| 🚨 / ⚠️ / ℹ️ | ERROR / WARNING / INFO severity |
| ⭐ | Next in line for implementation |
| 🐙 | [GitHub issue](https://github.com/saropa/saropa_lints/issues) |
| 💡 | [Discussion](https://github.com/saropa/saropa_lints/discussions) |

**Tiers**: Essential (1) → Recommended (2) → Professional (3) → Comprehensive (4) → Pedantic (5)

**Deferred complexity/risk markers** (used in Part 2):

| Marker | Meaning |
|--------|---------|
| `[CONTEXT]` | Needs build/test context detection |
| `[HEURISTIC]` | Variable/string pattern matching (high false-positive risk) |
| `[CROSS-FILE]` | Requires analysis across multiple files |
| `[TOO-COMPLEX]` | Pattern too abstract for reliable AST detection |
| `[PUBSPEC]` | Requires pubspec.yaml analysis (not Dart AST) |

### Stylistic rule pairs and overlaps

Some rules intentionally conflict or overlap; the **init wizard** (`dart run saropa_lints:init --stylistic`) lets users choose which stylistic rules to enable. This is by design, not a bug.

| Relationship | Rules | Notes |
|--------------|--------|--------|
| **Intentional pair** | `avoid_cubit_usage` vs `prefer_cubit_for_simple_state` | Opposite preferences: prefer Bloc (event traceability) vs prefer Cubit for simple state. Enable one via the wizard. |
| **Narrow variant** | `prefer_expression_body_getters` vs `prefer_arrow_functions` | Getter-only vs all single-expression bodies. Can enable both (getters get the narrow rule; methods the broad one) or just one. |
| **Other pairs** | e.g. `prefer_type_over_var` / `prefer_var_over_explicit_type` | Documented in rule DartDoc and in CHANGELOG; wizard shows both so users pick one. |

When adding or reviewing rules, check CODE_INDEX and tiers for existing stylistic opposites; document pairs in the rule’s DartDoc and, if needed, in this table.

---

## Part 1: Technical Debt & Improvements

### 1.0 SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

⭐ Details and design notes for each enhancement are in [bugs/discussion/](bugs/discussion/) (one file per discussion: `discussion_055_diagnostic_statistics.md` through `discussion_061_tier_based_filtering.md`).

---

## Part 2: Deferred Rules & Technical Limitations

Rules and features in this section are **deferred**: we do not implement them yet because the current analyzer only supports single-file Dart AST analysis, and implementing these would either require unsupported infrastructure (YAML, cross-file graphs, IDE events), produce unreliable results (heuristic/pattern matching with high false-positive risk), or depend on runtime or build-time context we cannot detect. Each subsection below states **why** those items are deferred so contributors know what would need to change before implementing them.

### Table of Contents (Part 2)

- [Deferred: Pubspec Rules](#deferred-pubspec-rules-11-rules)
- [Deferred: Cross-File Analysis Rules](#deferred-cross-file-analysis-rules)
- [Deferred: Performance Architecture](#deferred-performance-architecture)
- [Deferred & Complex Rules (Consolidated)](#deferred--complex-rules-consolidated)
- [Deferred: Remaining Hard (cross-file/heuristics/YAML)](#deferred-remaining-hard-cross-fileheuristicsyaml)
- [Deferred: Package-Specific Rules from saropa](#deferred-package-specific-rules-from-saropa-38-remaining)
- [Rules reviewed and not viable (do not re-propose)](#rules-reviewed-and-not-viable-do-not-re-propose)

---

### Deferred: Pubspec Rules (16 rules)

> **Why deferred:** saropa_lints only analyzes `.dart` files via the Dart AST. Pubspec rules require reading and parsing `pubspec.yaml` (and sometimes other YAML or external data). Until we have a YAML-capable analyzer or a separate CLI that runs on non-Dart files, these rules cannot be implemented without extending the plugin beyond its current scope.

**Implementation Options**:
1. A separate analyzer plugin that processes YAML files
2. A standalone CLI tool that checks pubspec.yaml
3. Integration with `dart pub` or custom pubspec parsing

**External Dependencies**:
- `prefer_latest_stable` requires pub.dev API calls to check latest versions
- `require_compatible_versions` needs a maintained database of known conflicts
- `require_null_safe_packages` needs SDK constraint parsing

| Rule | Tier | Severity | Description |
|------|------|----------|-------------|
| 📦 `avoid_any_version` | Essential | WARNING | `any` version constraint in dependencies |
| 📦 `prefer_publish_to_none` | Recommended | INFO | Private package without `publish_to: none` |
| 📦 `prefer_caret_version_syntax` | Stylistic | INFO | Version constraint without `^` prefix |
| 📦 `avoid_dependency_overrides` | Recommended | WARNING | `dependency_overrides` without explanatory comment |
| 🚨📦 `require_compatible_versions` | Essential | ERROR | Check for incompatible package versions. Detect known version conflicts. |
| ℹ️📦 `prefer_latest_stable` | Recommended | INFO | Use latest stable versions. Detect outdated packages. |
| ⚠️📦 `avoid_deprecated_packages` | Essential | WARNING | Don't use deprecated packages. Detect known deprecated packages. |
| 🚨📦 `require_null_safe_packages` | Essential | ERROR | All packages should be null-safe. Detect pre-null-safety dependencies. |
| ℹ️📦 `prefer_first_party_packages` | Recommended | INFO | Prefer official Flutter/Dart packages. Detect unofficial alternatives. |
| 📦 `add_resolution_workspace` | Professional | INFO | Monorepo: add resolution workspace for dependency management (requires workspace YAML). |
| 📦 `pubspec_ordering` | Stylistic | INFO | Pubspec fields should follow recommended ordering. |
| 📦 `newline_before_pubspec_entry` | Stylistic | INFO | Add blank lines between major pubspec sections. |
| 📦 `dependencies_ordering` | Stylistic | INFO | Dependencies in pubspec should be sorted alphabetically. |
| 📦 `prefer_pinned_version_syntax` | Stylistic | INFO | Pinned version syntax (e.g. `1.2.3`) may be preferred over caret in some workflows. |
| 📦 `prefer_commenting_pubspec_ignores` | Professional | INFO | Comment pubspec ignore/dependency_override entries. |
| 📦 `prefer_l10n_yaml_config` | Professional | INFO | Prefer l10n configuration via YAML (e.g. l10n.yaml). |

---

### Deferred: Cross-File Analysis Rules

> **Why deferred:** The custom_lint pipeline runs per file; it does not have a guaranteed view of the whole project or of non-Dart assets. These rules require **cross-file dependency analysis** (e.g. provider/riverpod usage across files) or **reading non-Dart config** (AndroidManifest.xml, Info.plist, .gitignore, etc.). We defer them until cross-file and config-file support exists; `avoid_circular_imports` already uses `ImportGraphCache` for import-only cross-file analysis.

#### Provider/State Management

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| 🚨🐙 [`avoid_provider_circular_dependency`](https://github.com/saropa/saropa_lints/issues/2) | Essential | ERROR | Requires tracking Provider dependencies across files to detect cycles. |
| 🚨🐙 [`avoid_riverpod_circular_provider`](https://github.com/saropa/saropa_lints/issues/1) | Essential | ERROR | Requires tracking `ref.watch()` and `ref.read()` calls across multiple provider files. |
| ℹ️🚫 `require_riverpod_test_override` | Professional | INFO | Test overrides may be in setup files separate from test files. |
| ℹ️🚫 `require_go_router_deep_link_test` | Professional | INFO | Routes are defined in one file, tests in another. |

#### Project-wide / coverage / barrel

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| ℹ️🚫 `require_test_coverage_threshold` | Professional | INFO | Coverage is computed project-wide; single-file AST cannot enforce threshold. |
| ℹ️🚫 `require_test_golden_threshold` | Professional | INFO | Golden file count and usage span multiple files. |
| ℹ️🚫 `require_barrel_files` | Professional | INFO | Requires detecting multiple individual imports across files to suggest barrel exports. |

#### Platform Configuration Rules

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| 🚨🐙 [`require_android_manifest_entries`](https://github.com/saropa/saropa_lints/issues/36) | Essential | ERROR | Requires reading AndroidManifest.xml to verify features have proper declarations. |
| 🚨🐙 [`require_ios_info_plist_entries`](https://github.com/saropa/saropa_lints/issues/35) | Essential | ERROR | Requires reading Info.plist to verify iOS features have proper entries. |
| ℹ️🐙 [`require_desktop_window_setup`](https://github.com/saropa/saropa_lints/issues/37) | Professional | INFO | Desktop apps need window configuration in platform-specific files. |
| 🚨🚫 `avoid_audio_in_background_without_config` | Essential | ERROR | Background audio requires iOS/Android configuration files. |
| 🚨🚫 `avoid_geolocator_background_without_config` | Essential | ERROR | Background location needs manifest/plist entries. |
| 🚨🚫 `require_notification_icon_kept` | Essential | ERROR | ProGuard rules are in separate configuration files. |
| 🚨🚫 `require_firestore_security_rules` | Essential | ERROR | Firestore rules are in firestore.rules file. |
| 🚨🐙 [`require_env_file_gitignore`](https://github.com/saropa/saropa_lints/issues/41) | Essential | ERROR | Requires reading .gitignore to verify .env is excluded. |

**Implementation Requirements**:
1. Build on existing `ImportGraphCache` infrastructure for Dart file analysis
2. Add platform config file readers (XML, plist, gitignore parsing)
3. Extend cycle detection for provider dependencies

---

### Deferred: Performance Architecture

> **Why deferred:** Optimizations below depend on **IDE or framework capabilities we do not have**: keystroke/edit events, file-open events, or control over how/when rules are run. The plugin runs inside the Dart analysis server with no access to these hooks, so we defer these ideas until the custom_lint (or IDE) API supports them or we introduce a separate CLI path.

The `custom_lint` plugin architecture runs inside the Dart analysis server process. This provides excellent IDE integration (real-time squiggles, quick fixes, hover info).

#### Blocked Optimizations (Requires custom_lint Framework Changes)

- ❌ `ThrottledAnalysis.recordEdit()` - needs IDE keystroke events
- ❌ `SpeculativeAnalysis.recordFileOpened()` - needs IDE file open events
- ❌ `RuleGroupExecutor` batch execution - custom_lint runs rules independently

#### IDE/Extension Limitations (Not Controllable)

The following VSCode UI elements are **not configurable** from this package:

| Element | Current | Desired | Why Not Possible |
|---------|---------|---------|------------------|
| Status bar "Lints" label | "Lints" | "Analyze" | Hardcoded in Dart-Code extension |
| Status bar icon | 🔍 (magnifying glass) | 🐛 (bug) | Hardcoded in Dart-Code extension |

The "Lints" status bar item is controlled entirely by the [Dart-Code VSCode extension](https://github.com/Dart-Code/Dart-Code). There are no user-facing settings to customize its icon or label. To request changes, file an issue at [Dart-Code/Dart-Code](https://github.com/Dart-Code/Dart-Code/issues).

#### Future Optimizations (Deferred)

| Optimization | Effort | Impact | Description |
|--------------|--------|--------|-------------|
| **Speculative Analysis** | Hard | Medium | `SpeculativeAnalysis` class exists but requires IDE hooks to know when files are opened. custom_lint doesn't expose these events. Would pre-analyze files the user is likely to open next. |
| **Full Throttled Analysis** | Hard | Medium | `ThrottledAnalysis` class exists but debounce requires `recordEdit()` calls when user types. custom_lint doesn't expose keystroke events. Current workaround: simple content-hash-based throttle in `run()` prevents duplicate analysis of identical content within 300ms. |
| ⭐ Cache Warming on Startup | Medium | Low | Pre-analyze visible/open files when IDE starts. Requires knowing which files are open (IDE-specific) or using heuristics (recent files, pubspec.yaml siblings). Could delay startup. |
| ⭐ Result Memoization by AST Hash | Hard | Medium | Cache rule results keyed by AST subtree hash. Skip re-running rules on unchanged AST nodes. Requires efficient AST hashing, careful invalidation logic, and significant memory management. |
| ⭐ Auto-Disable Inactive Rules | Medium | Low | Track rule hit rates over many analysis runs. Rules with 0% violation rate over 100+ files are candidates for automatic disabling (opt-in). Requires persistence of hit rate statistics and user configuration. |
| ⭐ Memory Pooling | Medium | Low | Reuse visitor and reporter objects instead of allocating new ones for each file. Reduces GC pressure for high-frequency analysis. Would require resettable object design and pool management. |
| ⭐ Lazy Rule Instantiation | Medium | Low | Create rule instances on-demand based on enabled tier rather than `const` list. Current approach uses compile-time constants (low overhead), but lazy instantiation could reduce initial memory for projects using minimal tiers. |
| ⭐ **Rule Hit Rate Decay** | Medium | High | Track violation rate per rule. Rules with 0% hits over 50+ files get deprioritized (run last). Self-tuning optimization that adapts to codebase patterns. |
| ~~**Negative Pattern Index**~~ | Low | Medium | **SKIPPED - Safety Risk**: At startup, scan codebase for patterns that NEVER appear. Skip rules requiring absent patterns globally. **Problem**: If a developer adds a pattern (e.g., `Timer.periodic`) to a file after IDE startup, rules would be incorrectly skipped until IDE restart, causing real violations to be missed. This optimization trades correctness for speed, which violates our principle that optimizations must never miss actual violations. |
| **Semantic Similarity Skip** | Hard | High | Files with identical import+class structure likely have same violations. Hash structure → cache rule results. Skip analysis on structurally identical files. |
| ⭐ **Violation Locality Heuristic** | Medium | Medium | Track where violations cluster (imports, class bodies, etc). Focus analysis on high-violation regions first for faster initial feedback. |
| **Co-Edit Prediction** | Hard | Medium | From git history, learn which files are edited together. When A changes, pre-warm B's cache. Requires git log parsing and pattern learning. |
| ⭐ **Type Resolution Batching** | Medium | High | Rules needing type resolution share the expensive resolver setup. Batch them instead of per-rule setup cost. Requires grouping rules by type resolution needs. |

**Alternative under consideration**: A standalone precompiled CLI binary could bypass framework limitations for CI pipelines (parallel execution, lower memory), but would sacrifice real-time IDE feedback. May revisit when rule count exceeds 2000.

---

### Deferred & Complex Rules (Consolidated)

> **Why deferred:** The rules below would require analysis we cannot do reliably today (cross-file, config, or runtime context), or would rely on heuristics that cause too many false positives. We list them for tracking only; do **not** implement until the barrier in the table is addressed (e.g. cross-file support, config parsing, or a clear AST pattern that avoids heuristic matching).

#### Why Rules Are Deferred

| Marker | Reason | Implementation Barrier |
|--------|--------|------------------------|
| `[HEURISTIC]` | Variable name or string pattern matching | High false-positive risk |
| `[CONTEXT]` | Needs build/test context detection | Requires tracking widget lifecycle state |
| `[CROSS-FILE]` | Requires analysis across multiple files | Single-file AST analysis cannot detect these |
| `[TOO-COMPLEX]` | Pattern too abstract for reliable detection | No clear AST pattern exists |
| `[PUBSPEC]` | Requires pubspec.yaml analysis (not Dart AST) | YAML parsing not supported |

#### Deferred: Bloc/State Management Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `require_riverpod_override_in_tests` | CROSS-FILE | Test overrides may be in setup |
| `require_bloc_test_coverage` | CROSS-FILE | Test coverage requires test file analysis |

#### Deferred: Code Quality Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `require_e2e_coverage` | CROSS-FILE | Test coverage is cross-file |

#### Deferred: Loading State Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `require_loading_timeout` | TOO-COMPLEX | "Loading state" is too abstract |
| `require_loading_state_distinction` | TOO-COMPLEX | Initial vs refresh is runtime |
| `require_refresh_completion_feedback` | TOO-COMPLEX | "Visible change" detection is runtime |
| `require_infinite_scroll_end_indicator` | TOO-COMPLEX | Scroll + hasMore + indicator is complex |

#### Deferred: Context Detection Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_cache_in_build` | CONTEXT | Cache lookups in build() may be expensive. Requires detecting build method context. |

#### Deferred: Configuration-Dependent Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_banned_api` | TOO-COMPLEX | Configurable rule to restrict usage of specific APIs by package, class, or identifier with include/exclude file patterns. Requires per-project configuration parsing from analysis_options.yaml which is not yet supported by the rule infrastructure. |

#### Deferred: Heuristic Detection Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `require_snackbar_duration_consideration` | HEURISTIC | "Important content" is subjective |
| `require_bloc_one_per_feature` | HEURISTIC | Each feature should have its own Bloc. Detecting "unrelated events" is subjective. |
| `avoid_getx_for_everything` | HEURISTIC | GetX shouldn't be used for all patterns. "Over-reliance" is subjective. |
| `avoid_notification_overload` | HEURISTIC | Too many notifications annoy users. "High-frequency" is subjective. |
| `prefer_feature_folders` | HEURISTIC | Organize by feature, not type. "Flat structure with many files" is heuristic. |
| `avoid_util_class` | HEURISTIC | Util classes are code smells. Name matching "Util/Helper" is heuristic. |
| `require_single_responsibility` | HEURISTIC | Classes should have one responsibility. "Mixed concerns" is subjective. |
| `require_cache_invalidation` | HEURISTIC | Caches need invalidation strategy. [GitHub #38](https://github.com/saropa/saropa_lints/issues/38) |
| `require_cache_ttl` | HEURISTIC | Caches need TTL. [GitHub #39](https://github.com/saropa/saropa_lints/issues/39) |
| `avoid_over_caching` | HEURISTIC | Not everything needs caching. "Excessive cache usage" is subjective. |
| `avoid_excessive_logging` | HEURISTIC | Too much logging impacts performance. "High-frequency log calls" is heuristic. |
| `avoid_service_locator_abuse` | HEURISTIC | Don't use GetIt everywhere. "Business logic" detection is heuristic. |
| `avoid_insufficient_contrast` | HEURISTIC | Text needs sufficient contrast. [GitHub #43](https://github.com/saropa/saropa_lints/issues/43) |
| `prefer_extract_widget` | HEURISTIC | Large build methods should be split. "Build >100 lines" is arbitrary. |

#### Deferred: Cross-File Analysis Required

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_never_passed_parameters` | CROSS-FILE | Requires analyzing all call sites |
| `avoid_getit_unregistered_access` | CROSS-FILE | Registration may be in separate file |
| `require_temp_file_cleanup` | CROSS-FILE | Delete may be in separate function |
| `require_crash_reporting` | CROSS-FILE | Crash reporting setup is centralized |
| `prefer_layer_separation` | CROSS-FILE | Architecture analysis is cross-file |
| `require_missing_test_files` | CROSS-FILE | Test file existence check |

#### Deferred: Remaining Hard (cross-file/heuristics/YAML)

Implement only when cross-file, heuristics, or YAML support exists. Single-file AST analysis cannot implement these reliably.

| Rule | Reason | Description |
|------|--------|-------------|
| `handle_bloc_event_subclasses` | CROSS-FILE | Bloc event class hierarchy spans multiple files. |
| `prefer_automatic_dispose` | CONTEXT / HEURISTIC | Automatic dispose detection needs lifecycle/context. |
| `prefer_composition_over_inheritance` | TOO-COMPLEX | Pattern too abstract for reliable AST detection. |
| `prefer_correct_screenshots` | CROSS-FILE | Screenshot references, tests, and assets span files. |
| `prefer_inline_comments_sparingly` | HEURISTIC | "Sparingly" is subjective; threshold would be arbitrary. |
| `prefer_intent_filter_export` | CROSS-FILE | Android intent-filter export requires manifest/usage analysis. |
| `require_di_module_separation` | CROSS-FILE | DI module boundaries require cross-file analysis. |
| `require_resource_tracker` | HEURISTIC / CROSS-FILE | Resource tracking is context-dependent across files. |

#### Deferred: Package-Specific Rules (saropa) — Heuristic/Logout/Check-Before-Use

These rules from the saropa project analysis require heuristic detection, cross-file analysis, or have vague detection criteria.

| Rule | Reason | Description |
|------|--------|-------------|
| `require_google_signin_disconnect_on_logout` | LOGOUT DETECTION | What constitutes "logout" is context-dependent |
| `avoid_google_signin_silent_without_fallback` | CONTROL FLOW | Requires understanding interactive fallback flow |
| `require_apple_credential_state_check` | CONTROL FLOW | Requires detecting prior state check |
| `avoid_storing_apple_identity_token` | DATA FLOW | Requires tracing token to storage calls |
| `require_google_sign_in_platform_interface_error_handling` | HEURISTIC | Platform auth error handling varies |
| `require_google_sign_in_platform_interface_logout_cleanup` | LOGOUT DETECTION | Logout cleanup is context-dependent |
| `require_googleapis_auth_error_handling` | HEURISTIC | Auth error handling varies |
| `require_googleapis_auth_logout_cleanup` | LOGOUT DETECTION | Logout cleanup is context-dependent |
| `require_webview_clear_on_logout` | LOGOUT DETECTION | What constitutes "logout" is context-dependent |
| `require_cache_manager_clear_on_logout` | LOGOUT DETECTION | Logout cleanup is context-dependent |
| `require_supabase_auth_state_listener` | CROSS-FILE | Listener may be set up elsewhere |
| `require_workmanager_unique_name` | CROSS-FILE | Requires comparing names across all files |
| `require_workmanager_error_handling` | HEURISTIC | What counts as "retry logic" is vague |
| `require_calendar_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_contacts_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_contacts_error_handling` | HEURISTIC | "Error handling" is too vague |
| `avoid_contacts_full_fetch` | HEURISTIC | Usage context determines if full fetch is needed |
| `require_device_info_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_device_info_error_handling` | HEURISTIC | "Error handling" is too vague |
| `require_package_info_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_package_info_error_handling` | HEURISTIC | "Error handling" is too vague |
| `avoid_url_launcher_untrusted_urls` | DATA FLOW | Requires tracing URL source |
| `require_speech_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_speech_availability_check` | CHECK BEFORE USE | Availability check may be in separate method |
| `avoid_in_app_review_on_first_launch` | APP STATE | First launch detection requires app state |
| `require_in_app_review_availability_check` | CHECK BEFORE USE | Availability check may be elsewhere |
| `require_iap_error_handling` | HEURISTIC | PurchaseStatus handling patterns vary |
| `require_iap_verification` | TOO COMPLEX | "Server-side verification" cannot be detected |
| `require_iap_restore_handling` | CROSS-FILE | Restore handling may be in separate class |
| `require_geomag_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_app_links_validation` | HEURISTIC | What counts as "validation" is vague |
| `require_file_picker_permission_check` | CHECK BEFORE USE | Permission check may be in separate method |
| `require_file_picker_type_validation` | HEURISTIC | What counts as "type validation" is vague |
| `require_file_picker_size_check` | HEURISTIC | What counts as "size check" is vague |
| `require_password_strength_threshold` | HEURISTIC | Score threshold usage patterns vary |
| `avoid_envied_secrets_in_repo` | CROSS-FILE | Requires reading .gitignore file |
| `require_timezone_initialization` | CROSS-FILE | initializeTimeZones() may be in main.dart |

**Total Deferred Rules: ~136.** Revisit when: (1) cross-file analysis becomes available, (2) better heuristics are developed, (3) runtime analysis tools are integrated, (4) package-specific detection is implemented.

#### Deferred: Package-Specific Rules from saropa (38 remaining)

> **Why deferred:** These rules are the same as those in the "Deferred: Package-Specific Rules (saropa) — Heuristic/Logout/Check-Before-Use" table above. They are deferred because they need cross-file analysis, logout/control-flow detection, "check before use" patterns across methods, or heuristic criteria that would produce too many false positives with single-file AST only.
>
> Generated on 2026-01-10 by `analyze_pubspec.py`

##### Authentication

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_google_signin_disconnect_on_logout` | Recommended | google_sign_in | Call GoogleSignIn.disconnect() on logout |
| `avoid_google_signin_silent_without_fallback` | Stylistic | google_sign_in | signInSilently() should have fallback |
| `require_google_sign_in_platform_interface_error_handling` | Recommended | google_sign_in_platform_interface | Handle auth errors |
| `require_google_sign_in_platform_interface_logout_cleanup` | Recommended | google_sign_in_platform_interface | Cleanup on logout |
| `require_googleapis_auth_error_handling` | Recommended | googleapis_auth | Handle auth errors |
| `require_googleapis_auth_logout_cleanup` | Recommended | googleapis_auth | Cleanup on logout |
| `require_apple_credential_state_check` | Recommended | sign_in_with_apple | Check getCredentialState() before assuming signed in |
| `avoid_storing_apple_identity_token` | Essential | sign_in_with_apple | Don't store identity tokens locally |
| `require_sign_in_with_apple_platform_interface_error_handling` | Recommended | sign_in_with_apple_platform_interface | Handle auth errors |
| `require_sign_in_with_apple_platform_interface_logout_cleanup` | Recommended | sign_in_with_apple_platform_interface | Cleanup on logout |
| `require_supabase_auth_state_listener` | Recommended | supabase_flutter | Listen to onAuthStateChange |

##### Background Processing

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_workmanager_unique_name` | Recommended | workmanager | Use unique names to prevent duplicates |
| `require_workmanager_error_handling` | Recommended | workmanager | Handle task failures with retry |

##### Contacts & Calendar

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_calendar_permission_check` | Essential | device_calendar | Request permission before accessing |
| `require_contacts_permission_check` | Essential | flutter_contacts | Request permission before accessing |
| `require_contacts_error_handling` | Recommended | flutter_contacts | Handle permission denied gracefully |
| `avoid_contacts_full_fetch` | Stylistic | flutter_contacts | Use withProperties for needed fields only |

##### Device & Platform

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_device_info_permission_check` | Recommended | device_info_plus | Check permissions |
| `require_device_info_error_handling` | Recommended | device_info_plus | Handle errors |
| `require_package_info_permission_check` | Recommended | package_info_plus | Check permissions |
| `require_package_info_error_handling` | Recommended | package_info_plus | Handle errors |
| `avoid_url_launcher_untrusted_urls` | Recommended | url_launcher | Validate URLs before launching |

##### Forms & Input

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_speech_permission_check` | Essential | speech_to_text | Check microphone permission |
| `require_speech_availability_check` | Recommended | speech_to_text | Check isAvailable first |

##### In-App Features

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `avoid_in_app_review_on_first_launch` | Recommended | in_app_review | Don't request on first launch |
| `require_in_app_review_availability_check` | Recommended | in_app_review | Check isAvailable first |
| `require_webview_clear_on_logout` | Recommended | webview_flutter | Clear WebView cache/cookies on logout |

##### Location & Maps

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_geomag_permission_check` | Essential | geomag | Check location permission |

##### Other

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_app_links_validation` | Recommended | app_links | Validate deep link parameters |
| `avoid_envied_secrets_in_repo` | Essential | envied | Ensure .env files are gitignored |
| `require_file_picker_permission_check` | Recommended | file_picker | Check storage permission first |
| `require_file_picker_type_validation` | Recommended | file_picker | Validate file type after picking |
| `require_file_picker_size_check` | Recommended | file_picker | Check file size to prevent OOM |
| `require_cache_manager_clear_on_logout` | Recommended | flutter_cache_manager | Clear cache on logout |
| `require_timezone_initialization` | Essential | timezone | Call initializeTimeZones() first |
| `require_password_strength_threshold` | Recommended | zxcvbn | Enforce minimum score 3+ |

---

### Rules reviewed and not viable (do not re-propose)

Reference list of proposed rules that were reviewed and **rejected**. Rationale is preserved so contributors do not re-propose them.

#### Drift

Proposed Drift-related lint rules that were reviewed and **not** implemented:

| Proposed rule | Reason not viable |
|---------------|-------------------|
| `avoid_drift_client_default_for_timestamps` | `clientDefault(() => DateTime.now())` vs `withDefault(currentDateAndTime)` are both valid (Dart runtime clock vs SQL canonical). Design choice, not a bug. |
| `avoid_drift_custom_constraint_without_not_null` | customConstraint() intentionally overrides NOT NULL; power users need exact SQL. Flagging would cause false positives. |
| `require_drift_build_runner` | Lint analyzes source at rest; cannot detect stale/missing generated files. Build either succeeds or fails. |

Other rejected ideas (redundant with compiler/library or trivial): schema downgrade, multiple autoIncrement, trailing column `()`, WAL mode, modular generation preference.

#### Roadmap (AST/infra/heuristic barriers)

Proposed rules from roadmap task review that were **not** implemented due to infrastructure, detection, or false-positive barriers:

| Proposed rule | Reason not viable |
|---------------|-------------------|
| `avoid_any_version` | Requires YAML parsing of `pubspec.yaml`; custom_lint only processes `.dart`. Same blocker as all pubspec rules. |
| `avoid_banned_api` | Configurable layer-boundary rule requires per-project config parsing from `analysis_options.yaml` not yet supported; high maintenance and overlap with `banned_usage`. |
| `avoid_connectivity_ui_decisions` | False positive rate too high; cannot distinguish full-screen block from small offline indicator (identical AST: StreamBuilder → if on ConnectivityResult → return widget). |
| `avoid_dependency_overrides` | Requires reading `pubspec.yaml`; custom_lint has no API for non-Dart files. Infrastructure blocker. |
| `avoid_firestore_admin_role_overuse` | Cannot distinguish security enforcement (bad) from UI personalization (fine); `claims['admin']` for UI gating looks identical in both cases. |
| `avoid_large_assets_on_web` | Lint cannot read file sizes from disk; asset paths are strings; analyzer does not resolve to filesystem. Build-time/CI concern. |
| `avoid_large_object_in_state` | Static analysis cannot measure runtime size; e.g. `Uint8List` could be 16 bytes or 5MB. DevTools memory profiler is the right tool. |
| `avoid_pagination_refetch_all` | Detection surface too narrow; real apps use BLoC/Riverpod/PagingController, not for-loops; near-zero real-world detections. |
| `avoid_repeated_widget_creation` | Determining “identical widgets with all-const args” requires deep expression analysis; trivial case rare, complex case unreliable. |
| `avoid_suspicious_global_reference` | Allowlist would not converge (Theme.of, Navigator.of, MediaQuery, GetIt, singletons, etc.); estimated 90%+ false positive rate. |
| `avoid_unbounded_collections` | List.add() used everywhere; linter cannot determine if a list "should" have a bound (domain-level decision). Phase 1 would flag virtually every stateful list. |

---

## Part 3: Cross-File Analysis CLI Tool Roadmap

Plan for building DCM-style cross-file analysis capabilities as a standalone CLI tool.

### Rationale

The `custom_lint` framework and native analyzer plugins both operate per-file, making certain analyses impossible:
- Unused code/file detection (requires project-wide usage graph)
- Circular dependency detection (requires import graph)
- Cross-feature dependency analysis (requires module boundaries)

DCM solves this with standalone CLI commands. We can do the same, leveraging existing infrastructure.

### Scope & Limitations

**What CLI provides:**
- Terminal output for CI/CD pipelines
- JSON/HTML reports for documentation
- Exit codes for build gates
- Cross-file analysis that per-file tools cannot do

**What CLI does NOT provide:**
- IDE "PROBLEMS" panel integration
- Real-time squiggles in editor
- Quick fixes
- On-save feedback

```
┌─────────────────────────────────────────────────────────────┐
│                    Reporting Comparison                     │
├─────────────────┬──────────────┬──────────────┬────────────┤
│ Output          │ Current      │ Native       │ CLI        │
├─────────────────┼──────────────┼──────────────┼────────────┤
│ IDE PROBLEMS    │ Yes          │ Yes (faster) │ No         │
│ Editor squiggles│ Yes          │ Yes (faster) │ No         │
│ Quick fixes     │ Yes          │ Yes          │ No         │
│ Terminal        │ Yes          │ Yes          │ Yes        │
│ JSON reports    │ No           │ No           │ Yes        │
│ HTML reports    │ No           │ No           │ Yes        │
│ CI exit codes   │ Yes          │ Yes          │ Yes        │
└─────────────────┴──────────────┴──────────────┴────────────┘
```

**Use CLI for:**
- CI/CD pipeline enforcement
- Batch analysis reports
- Cross-file checks (unused files, circular deps)
- Periodic audits

**Use Native/Current for:**
- Real-time IDE feedback
- Developer experience during coding

### Existing Infrastructure

| Component | Location | Ready |
|-----------|----------|-------|
| ImportGraphCache | `lib/src/project_context_import_location.dart` | Yes |
| SemanticTokenCache | `lib/src/project_context_semantic_compilation.dart` | Yes |
| CLI framework | `bin/saropa_lints.dart` | Yes |
| Argument parsing | `bin/init.dart` pattern | Yes |
| Baseline system | `bin/baseline.dart` | Yes |
| AnalysisReporter | `lib/src/report/analysis_reporter.dart` | Yes |

### Phase 1: Foundation (MVP)

**Goal**: Basic cross-file analysis with text/JSON output

#### 1.1 Create CLI Entry Point

Create `bin/cross_file.dart`:

```
dart run saropa_lints:cross_file [command] [options]

Commands:
  unused-files     Find files not imported by any other file
  circular-deps    Detect circular import chains
  import-stats     Show import graph statistics

Options:
  --path <dir>     Project directory (default: current)
  --output <fmt>   Output format: text, json (default: text)
  --exclude <glob> Exclude patterns (can repeat)
```

#### 1.2 Implement Commands

| Command | Implementation | Leverages |
|---------|---------------|-----------|
| `unused-files` | Build import graph, find files with no importers | `ImportGraphCache.getImporters()` |
| `circular-deps` | Scan all files for circular chains | `ImportGraphCache.detectCircularImports()` |
| `import-stats` | Aggregate graph statistics | `ImportGraphCache.getStats()` |

#### 1.3 Output Formats

**Text output** (default):
```
Unused Files (3 found):
  lib/src/deprecated/old_helper.dart
  lib/src/utils/unused_util.dart
  lib/src/features/dead_feature.dart

Circular Dependencies (1 found):
  lib/src/a.dart -> lib/src/b.dart -> lib/src/c.dart -> lib/src/a.dart
```

**JSON output** (`--output json`):
```json
{
  "unusedFiles": ["lib/src/deprecated/old_helper.dart"],
  "circularDependencies": [
    ["lib/src/a.dart", "lib/src/b.dart", "lib/src/c.dart", "lib/src/a.dart"]
  ]
}
```

#### 1.4 Register Executable

Add to `pubspec.yaml`:
```yaml
executables:
  cross_file: cross_file
```

#### Deliverables
- [x] `bin/cross_file.dart` - CLI entry point
- [x] `lib/src/cli/cross_file_analyzer.dart` - Analysis logic
- [x] `lib/src/cli/cross_file_reporter.dart` - Output formatting
- [x] Unit tests for each command
- [x] Update README with usage

---

### Phase 2: Enhanced Analysis

**Goal**: Deeper analysis with symbol-level tracking

#### 2.1 Unused Symbols Detection

Detect public symbols not used outside their defining file:
- Classes
- Top-level functions
- Top-level variables
- Extensions
- Typedefs
- Mixins
- Enums

**Implementation**:
1. Use `AnalysisContextCollection` for full resolution
2. Build symbol → usage location map
3. Report symbols with no external references
4. Respect `@visibleForTesting`, `@protected` annotations

```
dart run saropa_lints:cross_file unused-symbols [options]

Options:
  --include-private    Include private symbols (default: false)
  --exclude-public-api Exclude package public API (default: false)
  --exclude-overrides  Exclude overridden members (default: true)
```

#### 2.2 Cross-Feature Dependencies

For projects using feature-based architecture (`lib/features/*/`):

```
dart run saropa_lints:cross_file feature-deps [options]

Options:
  --features-path <glob>  Feature directory pattern (default: lib/features/*)
  --show-matrix           Show dependency matrix
  --fail-on-violation     Exit 1 if cross-feature imports found
```

Output:
```
Feature Dependencies:

  auth -> (none)
  home -> auth
  profile -> auth, home  [VIOLATION: home]
  settings -> auth

Violations (1):
  lib/features/profile/profile_page.dart imports lib/features/home/home_model.dart
```

#### 2.3 Dead Import Detection

Find imports that are declared but no symbols from them are used:

```
dart run saropa_lints:cross_file dead-imports [options]
```

#### Deliverables
- [ ] `unused-symbols` command
- [ ] `feature-deps` command
- [ ] `dead-imports` command
- [ ] Dependency matrix visualization (text)
- [ ] Performance optimization for large projects

---

### Phase 3: Reporting & Integration

**Goal**: Rich output formats and CI/CD integration

#### 3.1 HTML Reports

```
dart run saropa_lints:cross_file report --output html --output-dir reports/
```

Generates:
- `reports/index.html` - Summary dashboard
- `reports/unused-files.html` - Detailed unused files list
- `reports/circular-deps.html` - Dependency graph visualization
- `reports/feature-matrix.html` - Feature dependency matrix

#### 3.2 Baseline Support

Integrate with existing baseline system:

```
dart run saropa_lints:cross_file unused-files --baseline cross_file_baseline.json
dart run saropa_lints:cross_file unused-files --update-baseline
```

Suppresses known issues, fails only on new violations.

#### 3.3 CI/CD Integration

Exit codes:
- `0` - No issues found
- `1` - Issues found
- `2` - Configuration error

GitHub Actions example:
```yaml
- name: Cross-file analysis
  run: dart run saropa_lints:cross_file unused-files --fail-on-violation
```

#### 3.4 Watch Mode

```
dart run saropa_lints:cross_file watch
```

Re-runs analysis on file changes, useful during development.

#### Deliverables
- [x] HTML report generation
- [x] Baseline integration
- [x] CI-friendly exit codes
- [ ] ⭐ Watch mode
- [x] GitHub Actions example workflow

---

### Phase 4: Advanced Features

**Goal**: Parity with DCM advanced features

#### 4.1 Code Duplication Detection

```
dart run saropa_lints:cross_file duplicates [options]

Options:
  --min-lines <n>      Minimum lines to consider (default: 5)
  --min-tokens <n>     Minimum tokens to consider (default: 50)
  --ignore-comments    Ignore comment differences
```

**Implementation**: AST-based comparison using normalized token streams.

#### 4.2 Unused Localization Keys

For projects using ARB files:

```
dart run saropa_lints:cross_file unused-l10n [options]

Options:
  --arb-dir <path>     ARB directory (default: lib/l10n)
```

#### 4.3 Dependency Graph Export

```
dart run saropa_lints:cross_file graph --output dot > deps.dot
dot -Tpng deps.dot -o deps.png
```

Exports import graph in DOT format for visualization with Graphviz.

#### 4.4 Integration with Lint Rules

Expose cross-file data to lint rules via `ProjectContext`:

```dart
// In a lint rule
final crossFile = ProjectContext.of(context).crossFileAnalysis;
if (crossFile.isSymbolUnused(node.name)) {
  reporter.atNode(node, code);
}
```

#### Deliverables
- [ ] Duplicate code detection
- [ ] Unused localization detection
- [ ] DOT graph export
- [ ] ProjectContext integration for lint rules

---

### Technical Considerations (CLI)

#### Performance

| Concern | Mitigation |
|---------|------------|
| Large projects (1000+ files) | Use `ImportGraphCache` (regex-based, fast) |
| Symbol resolution | Lazy `AnalysisContextCollection`, only when needed |
| Repeated runs | Cache results with file modification timestamps |
| Memory | Stream results, don't hold full AST in memory |

#### Exclusions

Default exclusions (configurable):
- `build/`
- `.dart_tool/`
- Generated files (`*.g.dart`, `*.freezed.dart`)
- Test files (for `unused-symbols` in lib/)

#### Configuration

Support `analysis_options.yaml` integration:

```yaml
cross_file:
  exclude:
    - "**/*.g.dart"
    - "lib/generated/**"
  features_path: "lib/features/*"
  unused_symbols:
    exclude_public_api: true
    exclude_overrides: true
```

#### References

- [DCM check-unused-code](https://dcm.dev/docs/cli/code-quality-checks/unused-code/)
- [DCM check-unused-files](https://dcm.dev/docs/cli/code-quality-checks/unused-files/)
- [Dart analyzer package](https://pub.dev/packages/analyzer)
- [AnalysisContextCollection](https://pub.dev/documentation/analyzer/latest/)

---

## Additional rules

Use as a todo list for implementation candidates. Sorted by **Effort** (L → M → H) then **Wow** (H → M → L).

**Implementation plans** (by developer usefulness): [bugs/plan/](bugs/plan/) — see `plan_additional_rules_1_through_10.md` through `plan_additional_rules_81_through_90.md` for target files, approach, and acceptance criteria per rule.

**Legend:** 🐛 BUG · 💨 CODE_SMELL · ⚠️ MINOR · 🚨 MAJOR · 🔴 BLOCKER · 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

| Rule key | Kind | Name | Checks for (summary) | Severity | Effort | Wow |
|----------------|------|------|----------------------|----------|--------|-----|
| conflicting_constructor_and_static_member | 🐛 BUG | Conflicting constructor and static member | Named constructor and static method/field have same name. | ⚠️ MINOR | 🟡 M | ★ L |
| duplicate_constructor | 🐛 BUG | Duplicate constructor | More than one unnamed or same-named constructor. | ⚠️ MINOR | 🟡 M | ★ L |
| duplicate_field_name | 🐛 BUG | Duplicate field name | Record literal/type has duplicate field name. | ⚠️ MINOR | 🟡 M | ★ L |
| field_initializer_redirecting_constructor | 🐛 BUG | Field initializer redirecting constructor | Redirecting constructor initializes a field. | ⚠️ MINOR | 🟡 M | ★ L |
| illegal_concrete_enum_member | 🐛 BUG | Illegal concrete enum member | Enum/concrete Enum implementer has concrete instance member. | ⚠️ MINOR | 🟡 M | ★ L |
| invalid_extension_argument_count | 🐛 BUG | Invalid extension argument count | Extension override doesn't have exactly one argument. | ⚠️ MINOR | 🟡 M | ★ L |
| invalid_field_name | 🐛 BUG | Invalid field name | Record literal/type has invalid field name. | ⚠️ MINOR | 🟡 M | ★ L |
| invalid_literal_annotation | 🐛 BUG | Invalid literal annotation | literal annotation applied to non–const constructor. | ⚠️ MINOR | 🟡 M | ★ L |
| invalid_non_virtual_annotation | 🐛 BUG | Invalid non virtual annotation | nonVirtual on wrong declaration or non-concrete member. | ⚠️ MINOR | 🟡 M | ★ L |
| invalid_super_formal_parameter_location | 🐛 BUG | Invalid super formal parameter location | Super parameter used outside non-redirecting generative constructor. | ⚠️ MINOR | 🟡 M | ★ L |
| non_constant_map_element | 🐛 BUG | Non constant map element | if or spread element in const map isn't constant. | ⚠️ MINOR | 🟡 M | ★ L |
| return_in_generator | 🐛 BUG | Return in generator | Generator uses return with value or implicit return. | ⚠️ MINOR | 🟡 M | ★ L |
| subtype_of_disallowed_type | 🐛 BUG | Subtype of disallowed type | extends/implements/with/on restricted type (bool, int, etc.). | ⚠️ MINOR | 🟡 M | ★ L |
| undefined_enum_constructor | 🐛 BUG | Undefined enum constructor | Enum value constructor doesn't exist. | ⚠️ MINOR | 🟡 M | ★ L |
| yield_in_non_generator | 🐛 BUG | Yield in non generator | yield/yield* in non–async*/sync* function. | ⚠️ MINOR | 🟡 M | ★ L |
| abstract_field_initializer | 💨 CODE_SMELL | Abstract field initializer | Abstract field has initializer. | ⚠️ MINOR | 🟡 M | ★ L |
| annotate_redeclares | 💨 CODE_SMELL | Annotate redeclares | Redeclared members should be annotated. | ⚠️ MINOR | 🟡 M | ★ L |
| deprecated_new_in_comment_reference | 💨 CODE_SMELL | Deprecated new in comment reference | Doc comment uses new in comment reference. | ⚠️ MINOR | 🟡 M | ★ L |
| document_ignores | 💨 CODE_SMELL | Document ignores | Ignored diagnostics should be documented. | ⚠️ MINOR | 🟡 M | ★ L |
| abi_specific_integer_invalid | 🐛 BUG | Abi specific integer invalid | Class extending AbiSpecificInteger doesn't meet requirements. | ⚠️ MINOR | 🔴 H | ★ L |
| argument_type_not_assignable_to_error_handler | 🐛 BUG | Argument type not assignable to error handler | Future.catchError argument function parameters incompatible. | ⚠️ MINOR | 🔴 H | ★ L |
| body_might_complete_normally | 🐛 BUG | Body might complete normally | Method/function with non-nullable return type could implicitly return null. | ⚠️ MINOR | 🔴 H | ★ L |
| const_map_key_not_primitive_equality | 🐛 BUG | Const map key not primitive equality | Const map key class implements == or hashCode. | ⚠️ MINOR | 🔴 H | ★ L |
| dead_null_aware_expression | 🐛 BUG | Dead null aware expression | Left operand of ?? can't be null, or unnecessary null-aware usage. | ⚠️ MINOR | 🔴 H | ★ L |
| duplicate_pattern_field | 🐛 BUG | Duplicate pattern field | Record/object pattern matches same field or getter more than once. | ⚠️ MINOR | 🔴 H | ★ L |
| implicit_super_initializer_missing_arguments | 🐛 BUG | Implicit super initializer missing arguments | Super constructor has required parameter not passed. | ⚠️ MINOR | 🔴 H | ★ L |
| inconsistent_pattern_variable_logical_or | 🐛 BUG | Inconsistent pattern variable logical or | Pattern variable in logical-or has different type on branches. | ⚠️ MINOR | 🔴 H | ★ L |
| invalid_annotation | 🐛 BUG | Invalid annotation | Annotation not const variable or const constructor invocation. | ⚠️ MINOR | 🔴 H | ★ L |
| invalid_null_aware_operator | 🐛 BUG | Invalid null aware operator | Null-aware operator on known non-nullable receiver. | ⚠️ MINOR | 🔴 H | ★ L |
| invalid_pattern_variable_in_shared_case_scope | 🐛 BUG | Invalid pattern variable in shared case scope | Shared switch case body references variable from one case. | ⚠️ MINOR | 🔴 H | ★ L |
| invalid_return_type_for_catch_error | 🐛 BUG | Invalid return type for catch error | Future.catchError callback return type incompatible. | ⚠️ MINOR | 🔴 H | ★ L |
| invalid_type_argument_in_const_literal | 🐛 BUG | Invalid type argument in const literal | Type parameter as type argument in const literal. | ⚠️ MINOR | 🔴 H | ★ L |
| invocation_of_non_function_expression | 🐛 BUG | Invocation of non function expression | Invocation target isn't a function. | ⚠️ MINOR | 🔴 H | ★ L |
| missing_default_value_for_parameter | 🐛 BUG | Missing default value for parameter | Optional parameter has non-nullable type and no default. | ⚠️ MINOR | 🔴 H | ★ L |
| not_assigned_potentially_non_nullable_local_variable | 🐛 BUG | Not assigned potentially non nullable local variable | Local variable referenced but not definitely assigned. | ⚠️ MINOR | 🔴 H | ★ L |
| not_initialized_non_nullable_instance_field | 🐛 BUG | Not initialized non nullable instance field | Non-nullable instance field not initialized. | ⚠️ MINOR | 🔴 H | ★ L |
| not_initialized_non_nullable_variable | 🐛 BUG | Not initialized non nullable variable | Static/top-level non-nullable variable has no initializer. | ⚠️ MINOR | 🔴 H | ★ L |
| recursive_constructor_redirect | 🐛 BUG | Recursive constructor redirect | Constructor redirects to itself (directly or indirectly). | ⚠️ MINOR | 🔴 H | ★ L |
| redirect_to_invalid_function_type | 🐛 BUG | Redirect to invalid function type | Factory redirects to constructor with incompatible parameters. | ⚠️ MINOR | 🔴 H | ★ L |
| super_formal_parameter_without_associated_positional | 🐛 BUG | Super formal parameter without associated positional | Positional super parameter but super constructor has no matching positional. | ⚠️ MINOR | 🔴 H | ★ L |
| undefined_constructor_in_initializer | 🐛 BUG | Undefined constructor in initializer | Super constructor invoked doesn't exist. | ⚠️ MINOR | 🔴 H | ★ L |
| undefined_extension_getter | 🐛 BUG | Undefined extension getter | Extension override getter not defined. | ⚠️ MINOR | 🔴 H | ★ L |
| undefined_extension_setter | 🐛 BUG | Undefined extension setter | Extension override setter not defined. | ⚠️ MINOR | 🔴 H | ★ L |
| undefined_super_member | 🐛 BUG | Undefined super member | super member not in superclass chain. | ⚠️ MINOR | 🔴 H | ★ L |
| wrong_number_of_type_arguments | 🐛 BUG | Wrong number of type arguments | Type arguments count doesn't match type parameters. | ⚠️ MINOR | 🔴 H | ★ L |
| omit_obvious_local_variable_types | 💨 CODE_SMELL | Omit obvious local variable types | Don't type annotate when type is obvious. | ⚠️ MINOR | 🔴 H | ★ L |
| type_parameter_supertype_of_its_bound | 💨 CODE_SMELL | Type parameter supertype of its bound | Type parameter bound is (indirectly) itself. | ⚠️ MINOR | 🔴 H | ★ L |
| unnecessary_null_comparison | 💨 CODE_SMELL | Unnecessary null comparison | Equality with null where operand can't be null. | ⚠️ MINOR | 🔴 H | ★ L |
| avoid_unstable_final_fields | 💨 CODE_SMELL | Avoid unstable final fields | (Rule removed.) | MINOR | ⚪ — | ⚪ — |

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

Pick a rule from [bugs/roadmap/](bugs/roadmap/) (see [README](bugs/roadmap/README.md)) or the sections above and submit a PR!

---

> **Package-specific rule sources** have been moved to [LINKS.md](LINKS.md#package-specific-rule-sources).
