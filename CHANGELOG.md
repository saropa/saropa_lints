# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 2.7.0.

## [4.1.3] - 2026-01-14

- Migrated all single/double-word lint rules to three-word convention for clarity and discoverability. Notable migrations include:
  - `arguments_ordering` → `enforce_arguments_ordering`
  - `capitalize_comment` → `capitalize_comment_start`
  - `prefer_first_method_usage` → `prefer_list_first`
  - `prefer_last_method_usage` → `prefer_list_last`
  - `prefer_member_ordering` → `enforce_member_ordering`
  - `prefer_container_widget` → `prefer_single_container`
  - `prefer_pagination_pattern` → `prefer_api_pagination`
  - `prefer_contains_method_usage` → `prefer_list_contains`
  - `avoid_dynamic_typing` → `avoid_dynamic_type`
  - `avoid_substring_usage` → `avoid_string_substring`
  - `avoid_continue_statement` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `require_dispose_method` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `max_imports` → `limit_max_imports`
  - `avoid_shadowing` → `avoid_variable_shadowing`
  - `prefer_selector` → `prefer_context_selector`
  - `dispose_providers` → `dispose_provider_instances`
  - `prefer_first` → `prefer_list_first`
  - `prefer_last` → `prefer_list_last`
  - `prefer_contains` → `prefer_list_contains`
  - `prefer_container` → `prefer_single_container`
  - `prefer_pagination` → `prefer_api_pagination`
  - `avoid_dynamic` → `avoid_dynamic_type`
  - `avoid_substring` → `avoid_string_substring`
  - `member_ordering` → `enforce_member_ordering`
  - `parameters_ordering` → `enforce_parameters_ordering`
  - `format_comment` → `format_comment_style`
  - `require_dispose` → `require_field_dispose`
  - `dispose_fields` → `dispose_widget_fields`
  - `avoid_continue` → `avoid_continue_statement`
  - `extend_equatable` → `require_extend_equatable`
  - `avoid_shadowing` → `avoid_variable_shadowing`

## [4.1.2] - 2026-01-13

### Fixed

- Removed a stray change log entry from the readme

## [4.1.1] - 2026-01-13

### Added
- **New Rule:** `avoid_cached_isar_stream` ([lib/src/rules/isar_rules.dart])
  - Detects and prevents caching of Isar query streams (must be created inline).
  - **Tier:** Professional
  - **Quick Fix:** Inlines offending Isar stream expressions at usage sites and removes the cached variable.
  - **Example:** [example/lib/isar/avoid_cached_isar_stream_fixture.dart]

### Tier Assignment for Previously Unassigned Rules

The following 6 rules, previously implemented but not assigned to any tier, are now included in the most appropriate tier sets in `lib/src/tiers.dart`:

- **Recommended Tier:**
  - `avoid_duplicate_test_assertions` (test quality)
  - `avoid_real_network_calls_in_tests` (test reliability)
  - `require_error_case_tests` (test completeness)
  - `require_test_isolation` (test reliability)
  - `prefer_where_or_null` (idiomatic Dart collections)
- **Professional Tier:**
  - `prefer_copy_with_for_state` (state management, immutability)

This ensures all implemented rules are available through tiered configuration and improves coverage for test and state management best practices.

### Rule Tier Assignment Audit

- Ran `scripts/audit_rules.py` to identify all implemented rules not assigned to any tier.
- Assigned the following rules to the most appropriate tier sets in `lib/src/tiers.dart`:
  - **Recommended:** `avoid_duplicate_test_assertions`, `avoid_real_network_calls_in_tests`, `require_error_case_tests`, `require_test_isolation`, `prefer_where_or_null`
  - **Professional:** `prefer_copy_with_for_state`
- All implemented rules are now available through tiered configuration. This ensures no orphaned rules and improves test and state management coverage.
- Updated changelog to document these assignments and maintain full transparency of tier coverage.

### Tier Set Maintenance

- Commented out unimplemented rules in all tier sets in `lib/src/tiers.dart` to ensure only implemented rules are active per tier.
- Confirmed all unimplemented rules are tracked in `ROADMAP.md` for future implementation.
- This change improves roadmap alignment and prevents accidental activation of unimplemented rules.
- Materially improve the message quality for all Critial rules

## [4.1.0] - 2026-01-12

### Tier Assignment Audit

**181 rules** previously unassigned to any tier are now properly categorized. These rules existed but were not included in tier configurations, meaning users weren't getting them unless explicitly enabled.

#### Essential Tier (+50 rules)

Critical and high-impact rules now included in the essential tier:

| Category | Rules Added |
|----------|-------------|
| **Security** | `avoid_deep_link_sensitive_params`, `avoid_path_traversal`, `avoid_webview_insecure_content`, `require_data_encryption`, `require_secure_password_field`, `prefer_html_escape` |
| **JSON/Type Safety** | `avoid_dynamic_json_access`, `avoid_dynamic_json_chains`, `avoid_unrelated_type_casts`, `require_null_safe_json_access` |
| **Platform Permissions** | `avoid_platform_channel_on_web`, `require_image_picker_permission_android`, `require_image_picker_permission_ios`, `require_permission_manifest_android`, `require_permission_plist_ios`, `require_url_launcher_queries_android`, `require_url_launcher_schemes_ios` |
| **Memory/Resource Leaks** | `avoid_stream_subscription_in_field`, `avoid_websocket_memory_leak`, `prefer_dispose_before_new_instance`, `require_dispose_implementation`, `require_video_player_controller_dispose` |
| **Widget Lifecycle** | `check_mounted_after_async`, `avoid_ref_in_build_body`, `avoid_flashing_content` |
| **Animation** | `avoid_animation_rebuild_waste`, `avoid_overlapping_animations` |
| **Navigation** | `prefer_maybe_pop`, `require_deep_link_fallback`, `require_stepper_validation` |
| **Firebase/Backend** | `prefer_firebase_remote_config_defaults`, `require_background_message_handler`, `require_fcm_token_refresh_handler` |
| **Forms/WebView** | `require_validator_return_null`, `avoid_image_picker_large_files`, `prefer_webview_javascript_disabled`, `require_webview_error_handling`, `require_webview_navigation_delegate`, `require_websocket_message_validation` |
| **Data/Storage** | `prefer_utc_for_storage`, `require_database_migration`, `require_enum_unknown_value` |
| **State/UI** | `require_error_widget`, `require_feature_flag_default`, `require_immutable_bloc_state`, `require_map_idle_callback`, `require_media_loading_state`, `prefer_bloc_listener_for_side_effects`, `require_cors_handling` |

#### Recommended Tier (+83 rules)

Medium-impact rules for better code quality:

| Category | Rules Added |
|----------|-------------|
| **Widget Structure** | `avoid_deep_widget_nesting`, `avoid_find_child_in_build`, `avoid_layout_builder_in_scrollable`, `avoid_nested_providers`, `avoid_opacity_misuse`, `avoid_shrink_wrap_in_scroll`, `avoid_unbounded_constraints`, `avoid_unconstrained_box_misuse` |
| **Gesture/Input** | `avoid_double_tap_submit`, `avoid_gesture_conflict`, `avoid_gesture_without_behavior`, `prefer_actions_and_shortcuts`, `prefer_cursor_for_buttons`, `require_disabled_state`, `require_drag_feedback`, `require_focus_indicator`, `require_hover_states`, `require_long_press_callback` |
| **Forms/Testing** | `require_button_loading_state`, `require_form_validation`, `avoid_flaky_tests`, `avoid_real_timer_in_widget_test`, `avoid_stateful_test_setup`, `prefer_matcher_over_equals`, `prefer_mock_http`, `require_golden_test`, `require_mock_verification` |
| **Performance** | `avoid_hardcoded_layout_values`, `avoid_hardcoded_text_styles`, `avoid_large_images_in_memory`, `avoid_map_markers_in_build`, `avoid_stack_overflow`, `prefer_clip_behavior`, `prefer_deferred_loading_web`, `prefer_keep_alive`, `prefer_sliver_app_bar`, `prefer_sliver_list` |
| **State Management** | `avoid_late_context`, `prefer_cubit_for_simple_state`, `prefer_selector_over_consumer`, `require_bloc_consumer_when_both` |
| **Accessibility** | `avoid_screenshot_sensitive`, `avoid_semantics_exclusion`, `prefer_merge_semantics`, `avoid_small_text` |
| **Database/Navigation** | `require_database_index`, `prefer_transaction_for_batch`, `prefer_typed_route_params`, `require_refresh_indicator`, `require_scroll_controller`, `require_scroll_physics` |
| **Desktop/i18n** | `require_menu_bar_for_desktop`, `require_window_close_confirmation`, `require_intl_locale_initialization`, `require_notification_timezone_awareness` |

#### Comprehensive Tier (+48 rules)

Low-impact style and pattern rules:

- Code style: `avoid_digit_separators`, `avoid_nested_try_statements`, `avoid_type_casts`
- Documentation: `prefer_doc_comments_over_regular`, `prefer_error_suffix`, `prefer_exception_suffix`
- Patterns: `prefer_class_over_record_return`, `prefer_record_over_equatable`, `prefer_guard_clauses`
- Async: `prefer_async_only_when_awaiting`, `prefer_await_over_then`, `prefer_sync_over_async_where_possible`
- Testing: `prefer_expect_over_assert_in_tests`, `prefer_single_expectation_per_test`
- And 33 more...

#### Intentionally Untiered (81 rules)

Stylistic/opinionated rules remain untiered for team-specific configuration:

- Quote style: `prefer_single_quotes` vs `prefer_double_quotes`
- Import style: `prefer_relative_imports` vs `prefer_absolute_imports`
- Member ordering: `prefer_fields_before_methods` vs `prefer_methods_before_fields`
- Control flow: `prefer_ternary_over_if_null` vs `prefer_if_null_over_ternary`
- Debug rules: `always_fail`, `greeting`, `firebase_custom`

---

## [4.0.1] - 2026-01-12

### Testing Best Practices Rules

Activated 5 previously unregistered testing best practices rules:

| Rule | Tier | Description |
|------|------|-------------|
| `prefer_test_find_by_key` | Recommended | Suggests `find.byKey()` over `find.byType()` for reliable widget testing |
| `prefer_setup_teardown` | Recommended | Detects duplicated test setup code (3+ occurrences) |
| `require_test_description_convention` | Recommended | Ensures test names include descriptive words |
| `prefer_bloc_test_package` | Professional | Suggests `blocTest()` when detecting Bloc testing patterns |
| `prefer_mock_verify` | Professional | Warns when `when()` is used without `verify()` |

**Note:** `avoid_test_sleep` was already registered.

**Code cleanup:** Removed redundant test file path checks from these rules (file type filtering is handled by `applicableFileTypes`).

### DX Message Quality Improvements

Improved problem messages for 7 critical-impact rules to provide specific consequences instead of generic descriptions:

| Rule | Improvement |
|------|-------------|
| `require_secure_storage` | Now explains XML storage exposure enables credential extraction |
| `avoid_storing_sensitive_unencrypted` | Added backup extraction and identity theft consequence |
| `check_mounted_after_async` | Specifies State disposal during async gap |
| `avoid_stream_subscription_in_field` | Clarifies callbacks fire after State disposal |
| `require_stream_subscription_cancel` | Specifies State disposal context |
| `require_interval_timer_cancel` | Specifies State disposal context |
| `avoid_dialog_context_after_async` | Clarifies BuildContext deactivation during async gap |

**Result**: Critical impact rules now at 100% DX compliance (40/40 passing).

### Documentation

- **PROFESSIONAL_SERVICES.md**: Rewrote professional services documentation with clearer service offerings and contact information

---

## [4.0.0] - 2026-01-12

### OWASP Compliance Mapping

Security rules are now mapped to **OWASP Mobile Top 10 (2024)** and **OWASP Top 10 (2021)** standards, transforming saropa_lints from a developer tool into a **security audit tool**.

#### Coverage

| OWASP Mobile | Rules | OWASP Web | Rules |
|--------------|-------|-----------|-------|
| M1 Credential Usage | 5+ | A01 Broken Access Control | 4+ |
| M3 Authentication | 5+ | A02 Cryptographic Failures | 10+ |
| M4 Input Validation | 6+ | A03 Injection | 6+ |
| M5 Communication | 2+ | A05 Misconfiguration | 4+ |
| M6 Privacy Controls | 5+ | A07 Authentication Failures | 8+ |
| M8 Misconfiguration | 4+ | A09 Logging Failures | 2+ |
| M9 Data Storage | 7+ | | |
| M10 Cryptography | 4+ | | |

**Gaps**: M2 (Supply Chain), M7 (Binary Protection), and A06 (Outdated Components) require separate tooling — dependency scanners and build-time protections.

#### New Files

- `lib/src/owasp/owasp_category.dart` - `OwaspMobile` and `OwaspWeb` enums with category metadata
- `lib/src/owasp/owasp_mapping.dart` - Compliance reporting utilities
- `lib/src/owasp/owasp.dart` - Barrel export

#### API

Rules expose OWASP mappings via the `owasp` property:

```dart
final rule = AvoidHardcodedCredentialsRule();
print(rule.owasp); // Mobile: M1 | Web: A07

// Generate compliance report
final mappings = getAllSecurityRuleMappings();
final report = generateComplianceReport(mappings);
```

#### Modified Files

- `lib/src/saropa_lint_rule.dart` - Added `OwaspMapping? get owasp` to `SaropaLintRule` base class
- `lib/src/rules/security_rules.dart` - Added OWASP mappings to 41 security rules
- `lib/src/rules/crypto_rules.dart` - Added OWASP mappings to 4 cryptography rules
- `lib/saropa_lints.dart` - Export `OwaspMapping`, `OwaspMobile`, `OwaspWeb`

### Baseline Feature for Brownfield Projects

**The problem**: You want to adopt saropa_lints on an existing project, but running analysis shows 500+ violations in legacy code. You can't fix them all before your next sprint, but you want new code to be clean.

**The solution**: The baseline feature records existing violations and hides them. Old code is "baselined" (hidden), new code is still checked. You can adopt linting today without fixing legacy code first.

#### Quick Start

```bash
# Generate baseline - hides all current violations
dart run saropa_lints:baseline
```

This command creates `saropa_baseline.json` and updates your `analysis_options.yaml`. Old violations are hidden, new code is still checked.

#### Three Combinable Baseline Types

| Type | Config | Description |
|------|--------|-------------|
| **File-based** | `baseline.file` | JSON file listing specific violations to ignore |
| **Path-based** | `baseline.paths` | Glob patterns for directories (e.g., `lib/legacy/`) |
| **Date-based** | `baseline.date` | Git blame - ignore code unchanged since a date |

All three types are combinable - any match suppresses the violation.

#### Full Configuration

```yaml
custom_lint:
  saropa_lints:
    tier: recommended
    baseline:
      file: "saropa_baseline.json"    # Specific violations
      date: "2025-01-15"              # Code unchanged since this date
      paths:                           # Directories/patterns
        - "lib/legacy/"
        - "lib/deprecated/"
        - "**/generated/"
      only_impacts: [low, medium]     # Only baseline these severities
```

#### CLI Commands

```bash
dart run saropa_lints:baseline              # Generate new baseline
dart run saropa_lints:baseline --update     # Refresh, remove fixed violations
dart run saropa_lints:baseline --dry-run    # Preview without changes
dart run saropa_lints:baseline --help       # See all options
```

#### New Files

- `lib/src/baseline/baseline_config.dart` - Configuration parsing
- `lib/src/baseline/baseline_file.dart` - JSON file handling
- `lib/src/baseline/baseline_paths.dart` - Glob pattern matching
- `lib/src/baseline/baseline_date.dart` - Git blame integration
- `lib/src/baseline/baseline_manager.dart` - Central orchestrator
- `bin/baseline.dart` - CLI tool

See [README.md](README.md#baseline-for-brownfield-projects) for full documentation.

### New Rules

#### OWASP Coverage Gap Rules

Five new rules to fill gaps in OWASP coverage:

| Rule | OWASP | Severity | Description |
|------|-------|----------|-------------|
| `avoid_ignoring_ssl_errors` | M5, A05 | ERROR | Detects `badCertificateCallback = (...) => true` that bypasses SSL validation |
| `require_https_only` | M5, A05 | WARNING | Flags `http://` URLs (except localhost). Has quick fix to replace with HTTPS |
| `avoid_unsafe_deserialization` | M4, A08 | WARNING | Detects `jsonDecode` results used in dangerous operations without type validation |
| `avoid_user_controlled_urls` | M4, A10 | WARNING | Flags user input (text controllers) passed directly to HTTP methods without URL validation |
| `require_catch_logging` | M8, A09 | WARNING | Catch blocks that silently swallow exceptions without logging or rethrowing |

---

## [3.4.0] - 2026-01-12

### Performance Optimizations

Added comprehensive performance infrastructure to support 1400+ lint rules efficiently.

#### Caching Infrastructure

- **`SourceLocationCache`**: O(log n) offset-to-line lookups via binary search with cached line start offsets
- **`SemanticTokenCache`**: Caches resolved type information and symbol metadata across rules
- **`CompilationUnitCache`**: Caches expensive AST traversal results (class names, method names, imports)
- **`ImportGraphCache`**: Caches project import graph for dependency queries and circular import detection

#### IDE Integration (Infrastructure Only)

- **`ThrottledAnalysis`**: Debounces analysis during rapid typing (requires IDE hooks not available in custom_lint)
- **`SpeculativeAnalysis`**: Pre-analyzes files likely to be opened next (requires IDE hooks not available in custom_lint)
- **Note**: These classes exist for future IDE integration but cannot be fully wired up without custom_lint framework changes

#### Rule Execution Optimization

- **`RuleGroupExecutor`**: Groups related rules to share setup/teardown costs and intermediate results
- **`ConsolidatedVisitorDispatch`**: Single AST traversal for multiple rules (reduces O(rules × nodes) to O(nodes))
- **`BaselineAwareEarlyExit`**: Skips rules when all violations are baselined
- **`DiffBasedAnalysis`**: Only re-analyzes changed regions of files

#### Memory Optimization

- **`StringInterner`**: Interns common strings (StatelessWidget, BuildContext) to reduce memory allocation
- Pre-interns 35+ common Dart/Flutter strings at startup
- **`LruCache`**: Generic LRU cache with configurable size limits to prevent unbounded memory growth
- **`MemoryPressureHandler`**: Monitors memory usage and auto-clears caches when threshold exceeded

#### Profiling

- **`HotPathProfiler`**: Instruments hot paths to identify slow rules and operations
- Tracks execution times, slow operations (>50ms threshold), and provides statistical analysis
- Enable via `HotPathProfiler.enable()` for development debugging

#### Parallel Execution

- **`ParallelAnalyzer`**: Now uses real `Isolate.run()` for true parallel file analysis
- Distributes work across multiple CPU cores for 2-4x speedup on large projects
- Automatic fallback to sequential processing when isolates unavailable

#### Integration Wiring

- **Startup initialization**: `initializeCacheManagement()` and `StringInterner.preInternCommon()` called at plugin startup
- **Memory tracking**: `MemoryPressureHandler.recordFileProcessed()` called per-file to trigger auto-clearing
- **Rule groups registered**: 6 groups defined (async, widget, context, dispose, test, security) for batch execution
- **Rapid analysis throttle**: Content-hash-based throttle prevents duplicate analysis of identical content within 300ms
- **Bloom filter pre-screening**: O(1) probabilistic membership testing in `PatternIndex` before expensive string searches
- **Content region skipping**: Rules can declare `requiresClassDeclaration`, `requiresMainFunction`, `requiresImports` to skip irrelevant files
- **Git-aware file priority**: `GitAwarePriority` tracks modified/staged files for prioritized analysis
- **Import-based rule filtering**: `requiresFlutterImport` getter skips widget rules instantly for pure Dart files
- **Adaptive tier switching**: Auto-switches to essential-tier rules during rapid editing (3+ analyses in 2 seconds)

### New Rules

- **`avoid_circular_imports`**: Detects circular import dependencies using `ImportGraphCache`
  - Reports when files are part of an import cycle
  - Suggests extracting shared types to break cycles

---

## [3.3.1] - 2026-01-12

### Quick Fix Policy Update

Updated contribution guidelines and roadmap with a plan to achieve 90% quick fix coverage.

#### HACK Comment Fixes Discouraged

`// HACK: fix this manually` fixes are now discouraged. They provide no real value. See [CONTRIBUTING.md](CONTRIBUTING.md#hack-comment-fixes-are-discouraged) for details.

- Real fixes that transform code are required
- If a fix can't be implemented safely, don't add one
- Document "no fix possible" in the rule's doc comment

#### Quick Fix Implementation Plan

Added comprehensive plan to [ROADMAP.md](ROADMAP.md#quick-fix-implementation-plan) with:

- **Category A**: Safe transformations (100% target) - ~200 rules
- **Category B**: Contextual transformations (80% target) - ~400 rules
- **Category C**: Multi-choice fixes (50% target) - ~300 rules
- **Category D**: Human judgment required (0% fixes) - ~600 rules

Safety checklist: no deleting code, no behavior changes, works in edge cases.

### Tooling

- **`scripts/audit_rules.py`**: Now displays per-file statistics table with line counts, rule counts, and fix counts for each rule file

---

## [3.3.0] - 2026-01-12

### Audit Script v2.0

The `scripts/audit_rules.py` has been completely redesigned with improved readability and comprehensive analysis.

#### New Features

- **OWASP Coverage Stats** - Visual progress bars showing Mobile (8/10) and Web (10/10) coverage with uncovered categories listed
- **Tier Distribution** - Rule counts per tier (essential, recommended, professional, comprehensive, insanity) with cumulative totals and visual bars
- **Severity Distribution** - Critical/high/medium/low breakdown with percentages
- **Quality Metrics** - Quick fix coverage (13%), correction message coverage (99.6%), lines of code stats
- **Orphan Rules Detection** - Identifies rules implemented but not assigned to any tier (262 found)
- **File Health Analysis** - Largest files by rule count, files needing quick fixes
- **DX Message Audit** - Now shows all impact levels with pass rates and percentages

#### Improved Output

- Organized into logical sections: Rule Inventory, Distribution Analysis, Security & Compliance, Quality Metrics, ROADMAP Sync, DX Message Audit
- Visual progress bars for coverage metrics
- Cleaner section headers with Unicode box-drawing characters
- Compact mode (`--compact`) to skip the file table for faster runs
- Top 3 worst offenders shown in terminal, full details in exported report

#### Command Options

```bash
python scripts/audit_rules.py              # Full audit
python scripts/audit_rules.py --compact    # Skip file table
python scripts/audit_rules.py --dx-all     # Show all DX issues
python scripts/audit_rules.py --no-dx      # Skip DX audit
```

---

## [3.1.2] - 2026-01-12

### New Rules

#### Tiered File Length Rules (OPINIONATED)

Opinionated style preferences for teams that prefer smaller files. **Not quality indicators** - large files are often necessary and valid for data, enums, constants, generated code, configs, and lookup tables.

| Rule | Threshold | Tier | Severity |
|------|-----------|------|----------|
| `prefer_small_files` | 200 lines | insanity | INFO |
| `avoid_medium_files` | 300 lines | professional | INFO |
| `avoid_long_files` | 500 lines | comprehensive | INFO |
| `avoid_very_long_files` | 1000 lines | recommended | INFO |

All rules can be disabled per-file with `// ignore_for_file: rule_name`.

### Performance Optimizations

#### Combined Pattern Index

- **Global pattern index**: Instead of each rule scanning for its patterns individually, we now build a combined index at startup and scan file content ONCE.
- **O(patterns) instead of O(rules x patterns)**: For 1400+ rules with multiple patterns, this is a massive speedup in the pre-filtering phase.
- **New `PatternIndex` class**: Automatically built when rules are loaded, transparent to rule authors.

#### Incremental Analysis Tracking

- **Skip unchanged files**: New `IncrementalAnalysisTracker` remembers which rules passed on which files.
- **Content hash comparison**: Only re-runs rules when file content actually changes.
- **Config-aware cache invalidation**: Cache automatically clears when tier or rule configuration changes.
- **Per-rule tracking**: Individual rules that pass are recorded, so even partial re-analysis benefits.
- **Disk persistence**: Cache survives IDE restarts! Saved to `.dart_tool/saropa_lints_cache.json`.
- **Auto-save throttling**: Saves after every 50 changes to balance performance vs data safety.
- **Atomic writes**: Uses temp file + rename to prevent corruption on crash.

#### File Metrics Cache

- **Cached file metrics**: New `FileMetricsCache` computes line count, class count, function count, etc. once per file.
- **Shared across rules**: All rules accessing file metrics use the same cached values.
- **Includes content indicators**: `hasAsyncCode`, `hasWidgets` for fast filtering.

#### New Rule Optimization Hooks

- **`requiresAsync` getter**: Skip rules on files without async/Future patterns.
- **`requiresWidgets` getter**: Skip rules on files without Widget/State patterns.
- **`maximumLineCount` getter**: (DANGEROUS - use sparingly) Skip rules on very large files. Only for O(n²) rules where analysis time is prohibitive. Off by default.

#### Smart Content Filter

- **New `SmartContentFilter` class**: Combines multiple heuristics in a single filter check.
- **Supports patterns, line counts, keywords, async, widgets**: One call to check all constraints.

#### Rule Priority Queue

- **Cost-based rule ordering**: Rules sorted by cost so cheap rules run first.
- **Fail-fast optimization**: Cheaper rules provide faster initial feedback.
- **New `RulePriorityQueue` class**: Sorts rules by cost + pattern count for optimal execution order.

#### Content Region Index

- **Pre-indexed file regions**: Imports, class declarations, and top-level code indexed separately.
- **Targeted scanning**: Rules checking imports don't need to scan function bodies.
- **New `ContentRegionIndex` class**: Computes and caches structural regions per file.

#### AST Node Type Registry

- **Batch rules by node type**: Group rules that care about the same AST nodes.
- **Reduced visitor overhead**: Instead of each rule registering callbacks, batch invocations.
- **New `AstNodeTypeRegistry` class**: Tracks which rules care about which node categories.

#### Content Fingerprinting

- **Structural fingerprints**: Quick hash of file characteristics (imports, classes, async, widgets).
- **Similarity detection**: Files with same fingerprint likely have same violations.
- **New `ContentFingerprint` class**: Enables caching across similar files.

#### Rule Dependency Graph

- **Fail-fast chains**: If rule A finds violations, skip dependent rule B.
- **Prerequisite tracking**: Declare rule dependencies for smarter execution.
- **New `RuleDependencyGraph` class**: Track and query rule dependencies.

#### Rule Execution Statistics

- **Historical performance tracking**: Track execution time and violation rates per rule.
- **Dynamic optimization**: Identify slow rules and rules that rarely find violations.
- **New `RuleExecutionStats` class**: Records and queries rule performance data.

#### Lazy Pattern Compilation

- **Deferred regex compilation**: Patterns compiled only when actually needed.
- **Skip compilation for filtered rules**: If early filtering skips a rule, its patterns are never compiled.
- **New `LazyPattern` and `LazyPatternCache` classes**: Lazy regex infrastructure.

#### Parallel Pre-Analysis

- **Parallel file scanning**: Pre-analyze files in parallel to populate caches before rules execute.
- **Async batch processing**: Files processed in batches with async gaps to avoid blocking.
- **Unified cache warming**: Computes metrics, fingerprints, file types, and pattern matches in one pass.
- **Batch execution planning**: Determines which rules should run on which files upfront.
- **New `ParallelAnalyzer` class**: Manages parallel pre-analysis of files.
- **New `ParallelAnalysisResult` class**: Contains all pre-computed analysis data for a file.
- **New `RuleBatchExecutor` class**: Plans and tracks which rules apply to which files.
- **New `BatchableRuleInfo` class**: Rule metadata for batch execution planning.

#### Consolidated Visitor Dispatch

- **Single-pass AST traversal**: Instead of each rule registering separate visitors, dispatch to all rules from one traversal.
- **Reduced traversal overhead**: O(nodes) instead of O(rules × nodes) for visitor callbacks.
- **Category-based registration**: Rules register for specific AST node categories (imports, classes, invocations, etc.).
- **New `ConsolidatedVisitorDispatch` class**: Manages rule callbacks by node category.
- **New `NodeVisitCallback` typedef**: Standard callback signature for consolidated visitors.

#### Baseline-Aware Early Exit

- **Skip fully-baselined rules**: If all violations of a rule in a file are baselined, skip the rule entirely.
- **Path-based baseline detection**: Files covered by path-based baseline can skip matching rules.
- **Violation counting**: Track baselined violation counts for optimization decisions.
- **New `BaselineAwareEarlyExit` class**: Tracks and queries baseline coverage per file/rule.

#### Diff-Based Analysis

- **Changed region tracking**: Only re-analyze lines that changed since last analysis.
- **Line range overlap detection**: Skip rules whose scope doesn't overlap with changes.
- **Simple line-by-line diff**: Fast diff computation without external dependencies.
- **Range merging**: Consolidate overlapping change regions for efficient queries.
- **New `DiffBasedAnalysis` class**: Computes and caches changed regions per file.
- **New `LineRange` class**: Represents line ranges with overlap/merge operations.

#### Import Graph Cache

- **Project-wide import graph**: Parse imports once and cache the dependency graph.
- **Transitive dependency queries**: Check if file A transitively imports file B.
- **Reverse graph**: Track which files import a given file.
- **Circular import detection**: Find import cycles involving a specific file.
- **New `ImportGraphCache` class**: Builds and queries the import graph.
- **New `ImportNode` class**: Represents a file's import relationships.

---

## [3.1.1] - 2026-01-12

### New Rules

- **prefer_descriptive_bool_names_strict**: Strict version of bool naming rule for insanity tier. Requires traditional prefixes (`is`, `has`, `can`, `should`). Does not allow action verbs.

### Enhancements

- **prefer_descriptive_bool_names**: Now lenient (professional tier). Allows action verb prefixes (`process`, `sort`, `remove`, etc.) and `value` suffix.

### Bug Fixes

- **no_boolean_literal_compare**: Fixed rule not being registered in plugin. Was implemented but missing from `saropa_lints.dart`.
- **avoid_conditions_with_boolean_literals**: Now only checks logical operators (`&&`, `||`). Equality comparisons (`==`, `!=`) are handled by `no_boolean_literal_compare` which has proper nullable type checking. This eliminates double-linting and false positives on `nullableBool == true`.
- **require_ios_permission_description**: Fixed false positive on `ImagePicker()` constructor. The rule now only triggers on method calls (`pickImage`, `pickVideo`, etc.) where it can detect the actual source (gallery vs camera).
- **require_ios_face_id_usage_description**: Now checks Info.plist before reporting. Previously always triggered on `LocalAuthentication` usage regardless of whether `NSFaceIDUsageDescription` was already present.
- **AvoidContextAcrossAsyncRule**: Now recognizes mounted-guarded ternary pattern `context.mounted ? context : null` as safe.
- **PreferDocCurlyApostropheRule**: Fixed quick fix not appearing - was searching `precedingComments` instead of `documentationComment`. Renamed from `PreferCurlyApostropheRule` to clarify it only applies to documentation.
- **Missing rule name prefixes**: Fixed 17 rules that were missing the `[rule_name]` prefix in their `problemMessage`. Affected rules: `avoid_future_tostring`, `prefer_async_await`, `avoid_late_keyword`, `prefer_simpler_boolean_expressions`, `avoid_context_in_initstate_dispose`, `avoid_shrink_wrap_in_lists`, `prefer_widget_private_members`, `avoid_hardcoded_locale`, `require_ios_permission_description`, `avoid_getter_prefix`, `prefer_correct_callback_field_name`, `prefer_straight_apostrophe`, `prefer_curly_apostrophe`, `avoid_dynamic`, `no_empty_block`.

---

## [3.1.0] - 2026-01-12

### Enhancements

- **Rule name prefix in messages**: All 1536 rules now prefix `problemMessage` with `[rule_name]` for visibility in VS Code's Problems panel.

### Bug Fixes

- **AvoidContextAfterAwaitInStaticRule**: Now recognizes `context.mounted` guards to prevent false positives.
- **AvoidStoringContextRule**: No longer flags function types that accept `BuildContext` as a parameter (callback signatures).
- **RequireIntlPluralRulesRule**: Only flags `== 1` or `!= 1` patterns, not general int comparisons.
- **AvoidLongRunningIsolatesRule**: Less aggressive on `compute()` - skips when comments indicate foreground use or in StreamTransformer patterns.

---

## [3.0.2] - 2026-01-12

### Bug Fixes

#### Async Context Utils

- **Compound `&&` mounted checks**: Fixed detection of mounted checks in compound conditions. `if (mounted && otherCondition)` now correctly protects the then-branch since short-circuit evaluation guarantees `mounted` is true when the body executes.
- **Nested mounted guards**: Fixed `ContextUsageFinder` to recognize context usage inside nested `if (mounted)` blocks. Previously, patterns like `if (someCondition) { if (context.mounted) context.doThing(); }` would incorrectly flag the inner usage.

#### AvoidUnawaitedFutureRule

- **Lifecycle method support**: Extended safe fire-and-forget detection to include `didUpdateWidget()` and `deactivate()` in addition to `dispose()`. These lifecycle methods are synchronous and subscription cleanup doesn't need to be awaited.
- **onDone callback support**: Added support for `StreamController.close()` in `onDone` and `onError` callbacks. The `onDone` parameter of `Stream.listen()` is `void Function()`, so you cannot await inside it - closing the controller here is standard cleanup for transformed streams.

#### PreferExplicitTypesRule

- **No longer flags `dynamic`**: The rule now only flags `var` and `final` without explicit types. `dynamic` is an explicit type choice (commonly used for JSON handling), not implicit inference like `var`.

#### PreferSnakeCaseFilesRule

- **Multi-part extension support**: Added recognition of common multi-part file extensions used in Dart/Flutter projects: `.io.dart`, `.dto.dart`, `.model.dart`, `.entity.dart`, `.service.dart`, `.repository.dart`, `.controller.dart`, `.provider.dart`, `.bloc.dart`, `.cubit.dart`, `.state.dart`, `.event.dart`, `.notifier.dart`, `.view.dart`, `.widget.dart`, `.screen.dart`, `.page.dart`, `.dialog.dart`, `.utils.dart`, `.helper.dart`, `.extension.dart`, `.mixin.dart`, `.test.dart`, `.mock.dart`, `.stub.dart`, `.fake.dart`.

#### SaropaDiagnosticReporter

- **Fixed zero-width highlight in `atToken`**: The built-in `atToken` method had a bug where `endColumn` equaled `startColumn`, resulting in zero-width diagnostic highlights. Now uses `atOffset` with explicit length to ensure proper span highlighting.

---

## [3.0.1] - 2026-01-12

### Performance Optimizations

#### Content Pre-filtering

- **New `requiredPatterns` getter**: Rules can specify string patterns that must be present for the rule to run.
- **Fast string search**: Checks for patterns BEFORE AST parsing, skipping irrelevant files instantly.
- **Example usage**: A rule checking `Timer.periodic` can return `{'Timer.periodic'}` to skip files without timers.

#### Skip Small Files

- **New `minimumLineCount` getter**: High-cost rules can skip files under a threshold line count.
- **Efficient counting**: Uses fast character scan instead of splitting into lines.
- **Example usage**: Complex nested callback rules can set `minimumLineCount => 50` to skip small files.

#### File Content Caching

- **New `FileContentCache` class**: Tracks file content hashes to detect unchanged files.
- **Rule pass tracking**: Records which rules passed on unchanged files to skip redundant analysis.
- **Impact**: Files that haven't changed between saves can skip re-running passing rules.

### Documentation

- **Updated ROADMAP.md**: Added "Future Optimizations" section with Batch AST Visitors and Lazy Rule Instantiation as planned major refactors.

---

## [3.0.0] - 2026-01-12

### Performance Optimizations

This release focuses on **significant performance improvements** for large codebases. custom_lint is notoriously slow with 1400+ rules, and these optimizations address the main bottlenecks.

#### Tier Set Caching

- **Cached tier rule sets**: Previously, `getRulesForTier()` was rebuilding Set unions on EVERY file analysis. Now tier sets are computed once on first access and cached for all subsequent calls.
- **Impact**: ~5-10x faster tier filtering after first access.

#### Rule Filtering Cache

- **Cached filtered rule list**: Previously, the 1400+ rule list was filtering on every file. Now the filtered list is computed once per analysis session and reused.
- **Impact**: Eliminates O(n) filtering on each of thousands of files.

#### Analyzer Excludes

- **Added comprehensive analyzer excludes** in `analysis_options.yaml`:
  - Generated code (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.gen.dart`, `*.mocks.dart`, `*.config.dart`)
  - Build artifacts (`build/**`, `.dart_tool/**`)
  - Example files (`example/**`)
- **Impact**: Skips files that can't be manually fixed, reducing analysis time significantly.

#### Rule Timing Instrumentation

- **New `RuleTimingTracker`**: Tracks execution time of each rule to identify slow rules.
- **Enable profiling**: Set `SAROPA_LINTS_PROFILE=true` environment variable.
- **Slow rule logging**: Rules taking >10ms are logged immediately for investigation.
- **Timing report**: Access `RuleTimingTracker.summary` for a report of the 20 slowest rules.

#### Rule Cost Classification

- **New `RuleCost` enum**: `trivial`, `low`, `medium`, `high`, `extreme`
- **1483 rules tagged**: Every rule now has a `cost` getter indicating execution cost.
- **Rule priority ordering**: Rules are sorted by cost so fast rules run first.
- **Impact**: Expensive rules (type resolution, full AST traversal) run last, after quick wins.

#### File Type Filtering

- **New `FileType` enum**: `widget`, `test`, `bloc`, `provider`, `model`, `service`, `general`
- **Early exit optimization**: Rules can declare `applicableFileTypes` to skip non-matching files entirely.
- **377 rules with file type filtering**: Widget rules skip non-widget files, test rules skip non-test files, etc.
- **`FileTypeDetector`**: Caches file type detection per file path for fast repeated access.
- **Impact**: Widget-specific rules skip ~80% of files in typical projects.

#### Project Context Caching

- **New `ProjectContext` class**: Caches project root detection and pubspec parsing.
- **One-time parsing**: Pubspec.yaml is parsed once per project, not per file.
- **Impact**: Eliminates redundant file I/O across 1400+ rules.

### Documentation

- **Added performance tips to README**: Guidance on using lower tiers during development for faster iteration.
- **Tier speed comparison**: Documented the performance impact of each tier level.
- **Updated CONTRIBUTING.md**: Added rule author guidance for `cost` and `applicableFileTypes` getters.

### New Rules

- **`prefer_expanded_at_call_site`**: Warns when a widget's `build()` method returns `Expanded`/`Flexible` directly. Returning these widgets couples the widget to Flex parents; if later wrapped with Padding etc., it will crash. Better to let the caller add `Expanded` where needed. **Quick fix available:** Adds HACK comment to mark for manual refactoring. (WARNING, recommended tier)

### Improved Rules

- **`avoid_expanded_outside_flex`**: Enhanced documentation explaining false positive cases (widgets returning Expanded that are used directly in Flex) and design guidance for preferring Expanded at call sites.

### Breaking Changes

None. All changes are backwards-compatible performance improvements.

---

## [2.7.0] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).

## [Unassigned Rules Notice] - 2026-01-13

The following 6 implemented rules are not currently assigned to any tier. They remain available for manual configuration and will be reviewed for tier assignment in a future release:

- `avoid_duplicate_test_assertions`
- `avoid_real_network_calls_in_tests`
- `prefer_copy_with_for_state`
- `prefer_where_or_null`
- `require_error_case_tests`
- `require_test_isolation`
