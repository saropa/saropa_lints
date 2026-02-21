# Deferred Rules & Technical Limitations
<!-- cspell:disable -->

This document contains rules and features that are **deferred** due to technical complexity, framework limitations, or requiring cross-file analysis that is not yet supported.

> **Looking for implementable rules?** See [ROADMAP.md](ROADMAP.md) for rules that can be implemented now.

---

## Table of Contents

- [Deferred: Pubspec Rules](#deferred-pubspec-rules-11-rules)
- [Deferred: Cross-File Analysis Rules](#deferred-cross-file-analysis-rules-2-rules)
- [Performance Architecture & Limitations](#performance-architecture)
- [Deferred & Complex Rules (Consolidated)](#deferred--complex-rules-consolidated)
- [Package-Specific Rules from saropa](#package-specific-rules-from-saropa-38-remaining)

---

## Legend

### Severity Emojis

| Emoji | Severity | Meaning |
|-------|----------|---------|
| 🚨 | ERROR | Critical issue that must be fixed |
| ⚠️ | WARNING | Important issue that should be addressed |
| ℹ️ | INFO | Informational suggestion or best practice |

### Complexity/Risk Markers

| Marker | Emoji | Meaning |
|--------|-------|---------|
| `[CONTEXT]` | 🎯 | Needs build/test context detection |
| `[HEURISTIC]` | 🧠 | Variable name or string pattern matching (high false-positive risk) |
| `[CROSS-FILE]` | 🚫 | Requires analysis across multiple files |
| `[TOO-COMPLEX]` | 🔮 | Pattern too abstract for reliable AST detection |
| `[PUBSPEC]` | 📦 | Requires pubspec.yaml analysis (not Dart AST) |

### Tracking Markers

| Emoji | Meaning |
|-------|---------|
| 🐙 | Tracked as GitHub issue (click to view) |
| 💡 | Planned enhancement tracked as GitHub Discussion |

---

## Deferred: Pubspec Rules (11 rules)

> **Note**: saropa_lints currently only analyzes `.dart` files using the Dart AST. These pubspec rules require YAML parsing which is not yet supported.

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
| 📦 `prefer_semver_version` | Essential | WARNING | Version not matching `x.y.z` format |
| 📦 `prefer_caret_version_syntax` | Stylistic | INFO | Version constraint without `^` prefix |
| 📦 `avoid_dependency_overrides` | Recommended | WARNING | `dependency_overrides` without explanatory comment |
| 📦 `prefer_correct_package_name` | Essential | ERROR | Package name not matching Dart conventions |
| 🚨📦 `require_compatible_versions` | Essential | ERROR | Check for incompatible package versions. Detect known version conflicts. |
| ℹ️📦 `prefer_latest_stable` | Recommended | INFO | Use latest stable versions. Detect outdated packages. |
| ⚠️📦 `avoid_deprecated_packages` | Essential | WARNING | Don't use deprecated packages. Detect known deprecated packages. |
| 🚨📦 `require_null_safe_packages` | Essential | ERROR | All packages should be null-safe. Detect pre-null-safety dependencies. |
| ℹ️📦 `prefer_first_party_packages` | Recommended | INFO | Prefer official Flutter/Dart packages. Detect unofficial alternatives. |

---

## Deferred: Cross-File Analysis Rules

> **Note**: These rules require **cross-file dependency graph analysis** or access to **non-Dart configuration files** (manifest, plist, gitignore, etc.). The `avoid_circular_imports` rule has been implemented using the `ImportGraphCache` infrastructure.

### Provider/State Management

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| 🚨🐙 [`avoid_provider_circular_dependency`](https://github.com/saropa/saropa_lints/issues/2) | Essential | ERROR | Requires tracking Provider dependencies across files to detect cycles. |
| 🚨🐙 [`avoid_riverpod_circular_provider`](https://github.com/saropa/saropa_lints/issues/1) | Essential | ERROR | Requires tracking `ref.watch()` and `ref.read()` calls across multiple provider files. |
| ℹ️🚫 `require_riverpod_test_override` | Professional | INFO | Test overrides may be in setup files separate from test files. |
| ℹ️🚫 `require_go_router_deep_link_test` | Professional | INFO | Routes are defined in one file, tests in another. |

### Platform Configuration Rules

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

## Performance Architecture

The `custom_lint` plugin architecture runs inside the Dart analysis server process. This provides excellent IDE integration (real-time squiggles, quick fixes, hover info).

### Blocked Optimizations (Requires custom_lint Framework Changes)

- ❌ `ThrottledAnalysis.recordEdit()` - needs IDE keystroke events
- ❌ `SpeculativeAnalysis.recordFileOpened()` - needs IDE file open events
- ❌ `RuleGroupExecutor` batch execution - custom_lint runs rules independently

### IDE/Extension Limitations (Not Controllable)

The following VSCode UI elements are **not configurable** from this package:

| Element | Current | Desired | Why Not Possible |
|---------|---------|---------|------------------|
| Status bar "Lints" label | "Lints" | "Analyze" | Hardcoded in Dart-Code extension |
| Status bar icon | 🔍 (magnifying glass) | 🐛 (bug) | Hardcoded in Dart-Code extension |

The "Lints" status bar item is controlled entirely by the [Dart-Code VSCode extension](https://github.com/Dart-Code/Dart-Code). There are no user-facing settings to customize its icon or label. To request changes, file an issue at [Dart-Code/Dart-Code](https://github.com/Dart-Code/Dart-Code/issues).

### Future Optimizations (Deferred)

| Optimization | Effort | Impact | Description |
|--------------|--------|--------|-------------|
| **Speculative Analysis** | Hard | Medium | `SpeculativeAnalysis` class exists but requires IDE hooks to know when files are opened. custom_lint doesn't expose these events. Would pre-analyze files the user is likely to open next. |
| **Full Throttled Analysis** | Hard | Medium | `ThrottledAnalysis` class exists but debounce requires `recordEdit()` calls when user types. custom_lint doesn't expose keystroke events. Current workaround: simple content-hash-based throttle in `run()` prevents duplicate analysis of identical content within 300ms. |
| Cache Warming on Startup | Medium | Low | Pre-analyze visible/open files when IDE starts. Requires knowing which files are open (IDE-specific) or using heuristics (recent files, pubspec.yaml siblings). Could delay startup. |
| Result Memoization by AST Hash | Hard | Medium | Cache rule results keyed by AST subtree hash. Skip re-running rules on unchanged AST nodes. Requires efficient AST hashing, careful invalidation logic, and significant memory management. |
| Central Stats Aggregator | Low | Low | Unified API to get all cache statistics in one call. Useful for debugging and monitoring. |
| Auto-Disable Inactive Rules | Medium | Low | Track rule hit rates over many analysis runs. Rules with 0% violation rate over 100+ files are candidates for automatic disabling (opt-in). Requires persistence of hit rate statistics and user configuration. |
| Memory Pooling | Medium | Low | Reuse visitor and reporter objects instead of allocating new ones for each file. Reduces GC pressure for high-frequency analysis. Would require resettable object design and pool management. |
| Lazy Rule Instantiation | Medium | Low | Create rule instances on-demand based on enabled tier rather than `const` list. Current approach uses compile-time constants (low overhead), but lazy instantiation could reduce initial memory for projects using minimal tiers. |
| **Rule Hit Rate Decay** | Medium | High | Track violation rate per rule. Rules with 0% hits over 50+ files get deprioritized (run last). Self-tuning optimization that adapts to codebase patterns. |
| ~~**Negative Pattern Index**~~ | Low | Medium | **SKIPPED - Safety Risk**: At startup, scan codebase for patterns that NEVER appear. Skip rules requiring absent patterns globally. **Problem**: If a developer adds a pattern (e.g., `Timer.periodic`) to a file after IDE startup, rules would be incorrectly skipped until IDE restart, causing real violations to be missed. This optimization trades correctness for speed, which violates our principle that optimizations must never miss actual violations. |
| **Semantic Similarity Skip** | Hard | High | Files with identical import+class structure likely have same violations. Hash structure → cache rule results. Skip analysis on structurally identical files. |
| **Violation Locality Heuristic** | Medium | Medium | Track where violations cluster (imports, class bodies, etc). Focus analysis on high-violation regions first for faster initial feedback. |
| **Co-Edit Prediction** | Hard | Medium | From git history, learn which files are edited together. When A changes, pre-warm B's cache. Requires git log parsing and pattern learning. |
| **Type Resolution Batching** | Medium | High | Rules needing type resolution share the expensive resolver setup. Batch them instead of per-rule setup cost. Requires grouping rules by type resolution needs. |

**Alternative under consideration**: A standalone precompiled CLI binary could bypass framework limitations for CI pipelines (parallel execution, lower memory), but would sacrifice real-time IDE feedback. May revisit when rule count exceeds 2000.

---

## Deferred & Complex Rules (Consolidated)

This section consolidates all rules that are deferred or marked as too complex for reliable AST detection. These rules are listed here for tracking purposes and should NOT be implemented until the underlying complexity is resolved.

### Why Rules Are Deferred

| Marker | Emoji | Reason | Implementation Barrier |
|--------|-------|--------|------------------------|
| `[HEURISTIC]` | 🧠 | Variable name or string pattern matching | High false-positive risk from matching non-target patterns |
| `[CONTEXT]` | 🎯 | Needs build/test context detection | Requires tracking widget lifecycle state |
| `[CROSS-FILE]` | 🚫 | Requires analysis across multiple files | Single-file AST analysis cannot detect these |
| `[TOO-COMPLEX]` | 🔮 | Pattern too abstract for reliable detection | No clear AST pattern exists |
| `[PUBSPEC]` | 📦 | Requires pubspec.yaml analysis (not Dart AST) | YAML parsing not supported |
| `DEFERRED` | — | Explicitly deferred for various reasons | See individual rule descriptions |

---

### Deferred: Bloc/State Management Rules (with markers)

| Rule | Reason | Description |
|------|--------|-------------|
| `require_riverpod_override_in_tests` | CROSS-FILE | Test overrides may be in setup |
| `require_bloc_test_coverage` | CROSS-FILE | Test coverage requires test file analysis |

### Deferred: Code Quality Rules (with markers)

| Rule | Reason | Description |
|------|--------|-------------|
| `require_e2e_coverage` | CROSS-FILE | Test coverage is cross-file |

### Deferred: Loading State Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `require_loading_timeout` | TOO-COMPLEX | "Loading state" is too abstract |
| `require_loading_state_distinction` | TOO-COMPLEX | Initial vs refresh is runtime |
| `require_refresh_completion_feedback` | TOO-COMPLEX | "Visible change" detection is runtime |
| `require_infinite_scroll_end_indicator` | TOO-COMPLEX | Scroll + hasMore + indicator is complex |

### Deferred: Context Detection Rules

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_cache_in_build` | CONTEXT | Cache lookups in build() may be expensive. Requires detecting build method context. |

### Deferred: Heuristic Detection Rules

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

### Deferred: Cross-File Analysis Required

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_never_passed_parameters` | CROSS-FILE | Requires analyzing all call sites |
| `avoid_getit_unregistered_access` | CROSS-FILE | Registration may be in separate file |
| `require_temp_file_cleanup` | CROSS-FILE | Delete may be in separate function |
| `require_crash_reporting` | CROSS-FILE | Crash reporting setup is centralized |
| `prefer_layer_separation` | CROSS-FILE | Architecture analysis is cross-file |
| `require_missing_test_files` | CROSS-FILE | Test file existence check |

### Deferred: Package-Specific Rules (saropa)

These rules from the saropa project analysis require heuristic detection, cross-file analysis, or have vague detection criteria.

#### Heuristic/"Logout" Detection

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
| `require_cache_manager_clear_on_logout` | LOGOUT DETECTION | What constitutes "logout" is context-dependent |

#### "Check Before Use" Patterns

| Rule | Reason | Description |
|------|--------|-------------|
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

#### Cross-File Analysis Required

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_envied_secrets_in_repo` | CROSS-FILE | Requires reading .gitignore file |
| `require_timezone_initialization` | CROSS-FILE | initializeTimeZones() may be in main.dart |

---

**Total Deferred Rules: ~136** (was ~100, added 36 from saropa package analysis)

These rules should be revisited when:
1. Cross-file analysis becomes available
2. Better heuristics are developed
3. Runtime analysis tools are integrated
4. Package-specific detection is implemented

---

## Package-Specific Rules from saropa (38 remaining)

> Generated on 2026-01-10 by `analyze_pubspec.py`

### Authentication

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

### Background Processing

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_workmanager_unique_name` | Recommended | workmanager | Use unique names to prevent duplicates |
| `require_workmanager_error_handling` | Recommended | workmanager | Handle task failures with retry |

### Contacts & Calendar

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_calendar_permission_check` | Essential | device_calendar | Request permission before accessing |
| `require_contacts_permission_check` | Essential | flutter_contacts | Request permission before accessing |
| `require_contacts_error_handling` | Recommended | flutter_contacts | Handle permission denied gracefully |
| `avoid_contacts_full_fetch` | Stylistic | flutter_contacts | Use withProperties for needed fields only |

### Device & Platform

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_device_info_permission_check` | Recommended | device_info_plus | Check permissions |
| `require_device_info_error_handling` | Recommended | device_info_plus | Handle errors |
| `require_package_info_permission_check` | Recommended | package_info_plus | Check permissions |
| `require_package_info_error_handling` | Recommended | package_info_plus | Handle errors |
| `avoid_url_launcher_untrusted_urls` | Recommended | url_launcher | Validate URLs before launching |

### Forms & Input

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_speech_permission_check` | Essential | speech_to_text | Check microphone permission |
| `require_speech_availability_check` | Recommended | speech_to_text | Check isAvailable first |

### In-App Features

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `avoid_in_app_review_on_first_launch` | Recommended | in_app_review | Don't request on first launch |
| `require_in_app_review_availability_check` | Recommended | in_app_review | Check isAvailable first |
| `require_webview_clear_on_logout` | Recommended | webview_flutter | Clear WebView cache/cookies on logout |

### Location & Maps

| Rule | Tier | Package | Description |
|------|------|---------|-------------|
| `require_geomag_permission_check` | Essential | geomag | Check location permission |

### Other

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

_Moved from ROADMAP.md on 2026-01-28 to reduce clutter in the main roadmap._
