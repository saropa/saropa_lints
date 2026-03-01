<!-- AUTO-SYNC: The heading and Goal line below are updated by the publish
     script via sync_roadmap_header() in scripts/modules/_rule_metrics.py.
     Heading regex: "# Roadmap: Aiming for N,NNN"
     Goal regex:    "Goal: NNN rules (NNN implemented, NNN remaining)"
     Goal is rounded up to the nearest 100. -->
# Roadmap: Aiming for 2,200 Lint Rules
<!-- cspell:disable -->

See [CHANGELOG.md](CHANGELOG.md) for implemented rules. Goal: 2200 rules (1726 implemented, 464 remaining).

> **When implementing**: Remove from ROADMAP, add to CHANGELOG, register in `all_rules.dart` + `tiers.dart`. See [CONTRIBUTING.md](CONTRIBUTING.md).

> **Planned rules**: Detailed task specs (examples, detection, false positives) are in [bugs/roadmap/](bugs/roadmap/) (one file per rule: `task_<rule_name>.md`). See [bugs/roadmap/README.md](bugs/roadmap/README.md) for the index.

> **Deferred rules**: Cross-file analysis, heuristics, YAML parsing → see **Part 2: Deferred Rules & Technical Limitations** below.

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

---

## Part 1: Technical Debt & Improvements

### 1.0 SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

Details and design notes for each enhancement are in [bugs/discussion/](bugs/discussion/) (one file per discussion: `discussion_055_diagnostic_statistics.md` through `discussion_061_tier_based_filtering.md`).

---

## Part 2: Deferred Rules & Technical Limitations

Rules and features in this section are **deferred** due to technical complexity, framework limitations, or cross-file analysis that is not yet supported.

### Table of Contents (Part 2)

- [Deferred: Pubspec Rules](#deferred-pubspec-rules-11-rules)
- [Deferred: Cross-File Analysis Rules](#deferred-cross-file-analysis-rules)
- [Deferred: Performance Architecture](#deferred-performance-architecture)
- [Deferred & Complex Rules (Consolidated)](#deferred--complex-rules-consolidated)
- [Deferred: Package-Specific Rules from saropa](#deferred-package-specific-rules-from-saropa-38-remaining)

---

### Deferred: Pubspec Rules (11 rules)

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

### Deferred: Cross-File Analysis Rules

> **Note**: These rules require **cross-file dependency graph analysis** or access to **non-Dart configuration files** (manifest, plist, gitignore, etc.). The `avoid_circular_imports` rule has been implemented using the `ImportGraphCache` infrastructure.

#### Provider/State Management

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| 🚨🐙 [`avoid_provider_circular_dependency`](https://github.com/saropa/saropa_lints/issues/2) | Essential | ERROR | Requires tracking Provider dependencies across files to detect cycles. |
| 🚨🐙 [`avoid_riverpod_circular_provider`](https://github.com/saropa/saropa_lints/issues/1) | Essential | ERROR | Requires tracking `ref.watch()` and `ref.read()` calls across multiple provider files. |
| ℹ️🚫 `require_riverpod_test_override` | Professional | INFO | Test overrides may be in setup files separate from test files. |
| ℹ️🚫 `require_go_router_deep_link_test` | Professional | INFO | Routes are defined in one file, tests in another. |

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

### Deferred & Complex Rules (Consolidated)

Rules below are deferred or marked as too complex for reliable AST detection. Listed for tracking only; do NOT implement until the underlying complexity is resolved.

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
| ImportGraphCache | `lib/src/project_context.dart:3145-3383` | Yes |
| SemanticTokenCache | `lib/src/project_context.dart:3585-3720` | Yes |
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
- [ ] `bin/cross_file.dart` - CLI entry point
- [ ] `lib/src/cli/cross_file_analyzer.dart` - Analysis logic
- [ ] `lib/src/cli/cross_file_reporter.dart` - Output formatting
- [ ] Unit tests for each command
- [ ] Update README with usage

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
- [ ] HTML report generation
- [ ] Baseline integration
- [ ] CI-friendly exit codes
- [ ] Watch mode
- [ ] GitHub Actions example workflow

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

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

Pick a rule from [bugs/roadmap/](bugs/roadmap/) (see [README](bugs/roadmap/README.md)) or the sections above and submit a PR!

---

> **Package-specific rule sources** have been moved to [LINKS.md](LINKS.md#package-specific-rule-sources).
