<!-- AUTO-SYNC: The heading and Goal line below are updated by the publish
     script via sync_roadmap_header() in scripts/modules/_rule_metrics.py.
     Heading regex: "# Roadmap: Aiming for N,NNN"
     Goal regex:    "Goal: NNN rules (NNN implemented, NNN remaining)"
     Goal is rounded up to the nearest 100. -->
# Roadmap: Aiming for 2,200 Lint Rules
<!-- cspell:disable -->

See [CHANGELOG.md](CHANGELOG.md) for implemented rules. Goal: 2200 rules (1721 implemented, 469 remaining).

> **When implementing**: Remove from ROADMAP, add to CHANGELOG, register in `all_rules.dart` + `tiers.dart`. See [CONTRIBUTING.md](CONTRIBUTING.md).

> **Deferred rules**: Cross-file analysis, heuristics, YAML parsing → [ROADMAP_DEFERRED.md](ROADMAP_DEFERRED.md)

### Legend

| Emoji | Meaning |
|-------|---------|
| 🚨 / ⚠️ / ℹ️ | ERROR / WARNING / INFO severity |
| ⭐ | Next in line for implementation |
| 🐙 | [GitHub issue](https://github.com/saropa/saropa_lints/issues) |
| 💡 | [Discussion](https://github.com/saropa/saropa_lints/discussions) |

**Tiers**: Essential (1) → Recommended (2) → Professional (3) → Comprehensive (4) → Pedantic (5)

---

## Part 1: Detailed Rule Specifications

### 1.3 Performance Rules

#### Memory Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_pool_pattern` | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| ℹ️🐙 [`prefer_pool_pattern`](https://github.com/saropa/saropa_lints/issues/13) | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| ℹ️ `require_expando_cleanup` | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |
| ℹ️🐙 [`require_expando_cleanup`](https://github.com/saropa/saropa_lints/issues/14) | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |

#### Network Performance

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_compression` | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| ℹ️🐙 [`require_compression`](https://github.com/saropa/saropa_lints/issues/15) | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| ℹ️ `prefer_batch_requests` | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| ℹ️🐙 [`prefer_batch_requests`](https://github.com/saropa/saropa_lints/issues/16) | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| ℹ️ `prefer_binary_format` | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |
| ℹ️🐙 [`prefer_binary_format`](https://github.com/saropa/saropa_lints/issues/18) | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |

### 1.4 Testing Rules

#### Unit Testing

#### Integration Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_test_ordering` | Professional | INFO | Integration tests may depend on database state from previous tests. Document dependencies or use `setUp` to ensure required state. |
| ℹ️ `prefer_retry_flaky` | Comprehensive | INFO | Integration tests on real devices are inherently flaky. Configure retry count in CI (e.g., `--retry=2`) rather than deleting useful tests. |
| ℹ️ `prefer_test_data_reset` | Professional | INFO | Each test should start with known state. Reset database, clear shared preferences, and log out users in setUp to prevent test pollution. |
| ℹ️ `avoid_screenshot_in_ci` | Comprehensive | INFO | Screenshots in CI consume storage and slow tests. Take screenshots only on failure for debugging, not on every test. |
| ℹ️ `prefer_test_report` | Comprehensive | INFO | Generate JUnit XML or JSON reports for CI dashboards. Raw console output is hard to track over time. |
| ℹ️ `require_performance_test` | Professional | INFO | Measure frame rendering time and startup latency in integration tests. Catch performance regressions before they reach production. |
| ℹ️ `avoid_test_on_real_device` | Recommended | INFO | Real devices vary in performance and state. Use emulators/simulators in CI for consistent, reproducible results. |
| ℹ️ `prefer_parallel_tests` | Comprehensive | INFO | Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites. |

### 1.5 Security Rules

#### Authentication & Authorization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_oauth_pkce` | Professional | INFO | Mobile OAuth without PKCE is vulnerable to authorization code interception. Use PKCE (Proof Key for Code Exchange) for secure OAuth flows. |
| ℹ️⭐ `require_session_timeout` | Professional | INFO | Sessions without timeout remain valid forever if tokens are stolen. Implement idle timeout and absolute session limits. |
| ℹ️ `prefer_deep_link_auth` | Professional | INFO | Deep links with auth tokens (password reset, magic links) must validate tokens server-side and expire quickly. |
| ⚠️ `avoid_remember_me_insecure` | Recommended | WARNING | "Remember me" storing unencrypted credentials is a security risk. Use refresh tokens with proper rotation and revocation. |
| ℹ️ `require_multi_factor` | Comprehensive | INFO | Sensitive operations (payments, account changes) should offer or require multi-factor authentication for additional security. |

#### Data Protection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_keychain_access` | Professional | INFO | iOS Keychain requires proper access groups and entitlements. Incorrect configuration causes data loss on app reinstall. |
| ℹ️ `require_backup_exclusion` | Professional | INFO | Sensitive data should be excluded from iCloud/Google backups. Backups are often less protected than the device. |
| ℹ️ `prefer_root_detection` | Professional | INFO | Rooted/jailbroken devices bypass security controls. Detect and warn users, or disable sensitive features on compromised devices. |

#### Security & Configuration (Test Files)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_https_only_test` | Professional | INFO | HTTP URLs in test files are typically test fixtures, not real endpoints. Reports at INFO severity so teams can disable independently from production `require_https_only`. |
| ℹ️ `avoid_hardcoded_config_test` | Professional | INFO | Hardcoded URLs and keys in test files are typically test fixture data, not deployment configuration. Reports at INFO severity so teams can disable independently from production `avoid_hardcoded_config`. |

#### Input Validation & Injection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_whitelist_validation` | Professional | INFO | Validate input against known-good values (allowlist) rather than blocking known-bad values (blocklist). Blocklists miss novel attacks. |
| ⚠️ `prefer_csrf_protection` | Professional | WARNING | State-changing requests need CSRF tokens. Without protection, malicious sites can trigger actions on behalf of logged-in users. |
| ℹ️ `prefer_intent_filter_export` | Professional | INFO | Android intent filters should be exported only when necessary. Unexported components can't be invoked by malicious apps. |

### 1.6 Accessibility Rules

#### Screen Reader Support

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `avoid_redundant_semantics` | Comprehensive | INFO | An Image with semanticLabel inside a Semantics wrapper announces twice. Remove duplicate semantic information. |
| ℹ️⭐ `prefer_semantics_container` | Professional | INFO | Groups of related widgets should use Semantics `container: true` to indicate they form a logical unit for navigation. |
| ℹ️ `prefer_semantics_sort` | Professional | INFO | Complex layouts may need `sortKey` to control screen reader navigation order. Default order may not match visual layout. |
| ℹ️ `avoid_semantics_in_animation` | Comprehensive | INFO | Semantics should not change during animations. Screen readers get confused by rapidly changing semantic trees. |
| ℹ️ `prefer_announce_for_changes` | Comprehensive | INFO | Important state changes should use `SemanticsService.announce()` to inform screen reader users of non-visual feedback. |

#### Visual Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_color_only_meaning` | Essential | WARNING | Never use color alone to convey information (red=error). Add icons, text, or patterns for colorblind users. |
| ℹ️ `prefer_high_contrast_mode` | Professional | INFO | Support MediaQuery.highContrast for users who need stark color differences. Provide high-contrast theme variant. |
| ℹ️ `prefer_dark_mode_colors` | Professional | INFO | Dark mode isn't just inverted colors. Ensure proper contrast, reduce pure white text, and test readability. |
| ℹ️ `require_link_distinction` | Comprehensive | INFO | Links must be distinguishable from regular text without relying on color alone. Use underline or other visual treatment. |
| ℹ️ `prefer_outlined_icons` | Comprehensive | INFO | Outlined icons have better visibility than filled icons for users with low vision. Consider icon style for accessibility. |

#### Motor Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_external_keyboard` | Comprehensive | INFO | Support full keyboard navigation for users who can't use touch. Ensure all actions are reachable via Tab and Enter. |
| ℹ️ `require_switch_control` | Comprehensive | INFO | Switch control users navigate sequentially. Ensure logical focus order and that all interactive elements are focusable. |

### 1.8 Navigation & Routing Rules

#### Navigator & GoRouter

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_go_router_redirect` | Professional | INFO | Auth checks in redirect() run before build, preventing flash of protected content. Checking in build shows then redirects. |

#### Deep Linking

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_branch_io_or_firebase_links` | Professional | INFO | Raw deep links break when app not installed. Branch.io or Firebase Dynamic Links provide install-then-open flow. |

### 1.9 Forms & Validation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_form_bloc_for_complex` | Professional | INFO | Forms with >5 fields, conditional logic, or multi-step flows benefit from form state management (FormBloc, Reactive Forms). |
| ℹ️⭐ `prefer_input_formatters` | Professional | INFO | Phone numbers, credit cards, dates should auto-format as user types using TextInputFormatter for better UX. |

### 1.10 Database & Storage Rules

#### Local Database (Hive/Isar/Drift)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_isar_for_complex_queries` | Comprehensive | INFO | Hive's query capabilities are limited. Isar supports complex queries, full-text search, and links between objects. |

#### DB/IO Yield (All DB Packages + File I/O)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `require_yield_after_db_write` | Recommended | WARNING | Database or I/O write without a following `yieldToUI()` call. Write operations acquire exclusive locks that block the UI thread. |
| ℹ️ `suggest_yield_after_db_read` | Recommended | INFO | Bulk database or I/O read without a following `yieldToUI()` call. Deserializing large payloads can cause frame drops. `findFirst` is excluded. |
| ⚠️ `avoid_return_await_db` | Recommended | WARNING | Returning directly from a database/IO write skips `yieldToUI()`. Save to variable, yield, then return. Read operations are excluded. |

### 1.11 Platform-Specific Rules

> **iOS/macOS**: Implemented in v2.4.0 - See [Apple Platform Rules Guide](doc/guides/apple_platform_rules.md) for 104 rules.

#### Web-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_large_assets_on_web` | Recommended | WARNING | Web has no app install; assets download on demand. Lazy-load images and use appropriate formats (WebP) for faster loads. |

> **Linux**: Implemented in v4.9.20 — 5 rules covering XDG paths, X11/Wayland, font fallbacks, and privilege escalation.
>
> **Windows**: Implemented in v4.9.20 — 5 rules covering drive letters, path separators, case-insensitive FS, single-instance, and MAX_PATH.

### 1.13 Offline-First & Sync Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_optimistic_updates` | Professional | INFO | Update local state immediately, sync to server in background. Waiting for server makes UI feel slow. |
| ⚠️ `require_conflict_resolution_strategy` | Professional | WARNING | Offline edits that conflict with server need resolution: last-write-wins, merge, or user prompt. Define strategy upfront. |
| ⚠️⭐ `avoid_full_sync_on_every_launch` | Professional | WARNING | Downloading entire dataset on launch is slow and expensive. Use delta sync with timestamps or change feeds. |

### 1.14 Background Processing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_foreground_service_android` | Professional | INFO | Android kills background services aggressively. Use foreground service with notification for ongoing work. |

### 1.15 Push Notification Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_local_notification_for_immediate` | Recommended | INFO | flutter_local_notifications is better for app-generated notifications. FCM is for server-triggered messages. |

### 1.16 Payment & In-App Purchase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_grace_period_handling` | Professional | INFO | Users with expired cards get billing grace period. Handle "grace period" status to avoid locking out paying customers. |
| ⚠️ `avoid_entitlement_without_server` | Professional | WARNING | Client-side entitlement checks can be bypassed. Verify subscription status server-side for valuable content. |

### 1.17 Maps & Location Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_continuous_location_updates` | Professional | WARNING | GPS polling drains battery fast. Use significant location changes or geofencing when you don't need real-time updates. |
| ℹ️⭐ `prefer_geocoding_cache` | Professional | INFO | Reverse geocoding (coords to address) costs API calls. Cache results; coordinates rarely change for same address. |

### 1.19 Theming & Dark Mode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.20 Responsive & Adaptive Design Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_master_detail_for_large` | Professional | INFO | On tablets, list-detail flows should show both panes (master-detail) rather than stacked navigation. |
| ℹ️⭐ `prefer_adaptive_icons` | Recommended | INFO | Icons at 24px default are too small on tablets, too large on watches. Use IconTheme or scale based on screen size. |
| ℹ️ `require_foldable_awareness` | Comprehensive | INFO | Foldable devices have hinges and multiple displays. Use DisplayFeature API to avoid placing content on fold. |

### 1.28 Analytics & Tracking Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `require_analytics_error_handling` | Recommended | INFO | Analytics failures shouldn't crash the app. Detect analytics calls without try-catch wrapper. |

### 1.34 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_json_codegen` | Professional | INFO | Manual fromJson/toJson is error-prone. Detect hand-written fromJson methods; suggest json_serializable/freezed. |
| ℹ️ `require_json_date_format_consistency` | Professional | INFO | Dates in JSON need consistent format. Detect DateTime serialization without explicit format. |

### 1.35 GetIt & Dependency Injection Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_getit_dispose_registration` | Professional | INFO | Disposable singletons need dispose callbacks. Detect registerSingleton of Disposable types without dispose parameter. |

### 1.36 Logging Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `avoid_expensive_log_string_construction` | Professional | INFO | Don't build expensive strings for logs that won't print. Detect string interpolation in log calls without level guard. |

### 1.37 Pagination Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `require_pagination_for_large_lists` | Essential | WARNING | Loading all items at once causes OOM and slow UI. Detect ListView/GridView with large itemCount without pagination. |
| ⚠️ `avoid_pagination_refetch_all` | Professional | WARNING | Refetching all pages on refresh wastes bandwidth. Detect refresh logic that resets all paginated data. |
| ℹ️ `require_pagination_error_recovery` | Recommended | INFO | Failed page loads need retry option. Detect pagination without error state handling. |

### 1.39 Search & Filter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_search_cancel_previous` | Professional | INFO | Cancel previous search request when new search starts. Detect search without CancelToken or similar mechanism. |

### 1.42 ListView & ScrollView Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_sliverfillremaining_for_empty` | Professional | INFO | Empty state in CustomScrollView needs SliverFillRemaining. Detect empty state widget as regular sliver. |

### 1.44 Internationalization (L10n) Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `require_rtl_layout_support` | Recommended | WARNING | RTL languages need directional awareness. Detect hardcoded left/right in layouts without Directionality check. |

### 1.47 Stepper & Multi-step Flow Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `require_stepper_state_management` | Professional | INFO | Stepper state should handle back navigation. Detect Stepper without preserving form state across steps. |

### 1.51 Avatar & Profile Image Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

> **Note:** Loading State, Pull-to-Refresh, and Infinite Scroll end-indicator rules have been moved to [ROADMAP_DEFERRED.md](ROADMAP_DEFERRED.md#deferred-loading-state-rules) due to `[TOO-COMPLEX]` detection requirements.

### 1.52 Infinite Scroll Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_infinite_scroll_preload` | Professional | INFO | Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll. |
| ℹ️🐙 [`prefer_infinite_scroll_preload`](https://github.com/saropa/saropa_lints/issues/28) | Professional | INFO | Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll. |
| ℹ️ `require_infinite_scroll_error_recovery` | Recommended | INFO | Failed page loads need retry. Detect infinite scroll without error state and retry button. |
| ⚠️⭐ `avoid_infinite_scroll_duplicate_requests` | Professional | WARNING | Prevent multiple simultaneous page requests. Detect scroll listener without loading guard. |

### 1.55 Architecture Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_banned_api` | Professional | WARNING | Configurable rule to restrict usage of specific APIs based on source package, class name, identifier, or named parameter, with include/exclude file patterns. Useful for enforcing layer boundaries (e.g., UI cannot call database directly). Inspired by solid_lints' `avoid_using_api`. |

### 1.56 Type Safety & Casting Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `avoid_explicit_type_declaration` | Stylistic | INFO | Prefer type inference over explicit type declarations where the type is obvious. |

### 1.57 Error Handling Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `handle_throwing_invocations` | Professional | INFO | Invocations that can throw should be handled appropriately. |
| ℹ️ `prefer_correct_throws` | Professional | INFO | Document thrown exceptions with `@Throws` annotation. |

### 1.58 Class & Inheritance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_accessing_other_classes_private_members` | Professional | WARNING | Detect access to private members of other classes through workarounds. |
| ℹ️ `avoid_referencing_subclasses` | Professional | INFO | Base classes should not reference their subclasses directly. |
| ℹ️ `avoid_renaming_representation_getters` | Professional | INFO | Extension type representation getters should not be renamed. |
| ⚠️ `avoid_suspicious_super_overrides` | Professional | WARNING | Detect suspicious super.method() calls in overrides. |
| ℹ️ `prefer_class_destructuring` | Professional | INFO | Use record destructuring for class field access when beneficial. |

### 1.59 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_correct_json_casts` | Professional | INFO | Use proper type casts when working with JSON data. |

### 1.60 Ordering & Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `pattern_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in pattern matching. |
| ℹ️ `record_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in record declarations. |

### 1.61 Code Quality Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_deprecated_usage` | Recommended | WARNING | Warn when using deprecated APIs, classes, or methods. |
| ⚠️ `avoid_high_cyclomatic_complexity` | Professional | WARNING | Warn when functions exceed a configurable cyclomatic complexity threshold. |
| ℹ️⭐ `avoid_ignoring_return_values` | Recommended | INFO | Warn when function return values are ignored (unless explicitly marked). |
| ℹ️ `avoid_importing_entrypoint_exports` | Professional | INFO | Avoid importing from files that re-export entry points. |
| ⚠️ `avoid_suspicious_global_reference` | Professional | WARNING | Detect suspicious references to global state in methods. |
| ⚠️ `avoid_unused_local_variable` | Recommended | WARNING | Local variables that are declared but never used. |
| ⚠️⭐ `no_empty_block` | Recommended | WARNING | Empty blocks indicate missing implementation or dead code. |
| ℹ️ `tag_name` | Professional | INFO | Validate custom element tag names follow conventions. |
| ⚠️ `banned_usage` | Professional | WARNING | Configurable rule to ban specific APIs, classes, or patterns. |

### 1.63 Documentation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_public_api_documentation` | Professional | INFO | Public classes and methods must have doc comments |
| ℹ️ `avoid_misleading_documentation` | Professional | INFO | Doc comments must match method name and behavior |
| ℹ️ `require_deprecation_message` | Recommended | INFO | `@Deprecated` must include migration guidance |
| ℹ️ `require_complex_logic_comments` | Professional | INFO | Complex methods must have explanatory comments |
| ℹ️ `require_parameter_documentation` | Professional | INFO | Parameters must be documented with `[paramName]` |
| ℹ️ `require_return_documentation` | Professional | INFO | Non-void methods must document return value |
| ℹ️ `require_exception_documentation` | Professional | INFO | Methods that throw must document exceptions |
| ℹ️ `require_example_in_documentation` | Professional | INFO | Complex public classes should include usage examples |
| ⚠️ `verify_documented_parameters_exist` | Professional | WARNING | Doc `[paramName]` references must match actual parameters |

### 1.62 Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `avoid_cubits` | Stylistic | INFO | Prefer Bloc over Cubit for better event traceability. |
| ℹ️ `handle_bloc_event_subclasses` | Professional | INFO | Ensure all event subclasses are handled in event handlers. |
| ℹ️ `prefer_bloc_extensions` | Professional | INFO | Use Bloc extension methods for cleaner code. |

#### Flutter Hooks Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_misused_hooks` | Essential | WARNING | Detect common hook misuse patterns. |
| ℹ️⭐ `prefer_use_callback` | Professional | INFO | Use useCallback for memoizing callback functions. |

#### Intl/Localization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_missing_tr` | Essential | WARNING | Detect strings that should be translated but aren't. |
| ⚠️ `avoid_missing_tr_on_strings` | Essential | WARNING | User-visible strings should use translation methods. |

#### Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_missing_controller` | Essential | WARNING | Widgets with controllers should have controllers provided. |
| ⚠️⭐ `avoid_misused_test_matchers` | Recommended | WARNING | Detect incorrect usage of test matchers. |
| ℹ️ `format_test_name` | Stylistic | INFO | Test names should follow a consistent format. |
| ℹ️ `prefer_custom_finder_over_find` | Professional | INFO | Use custom finders for better test readability and maintenance. |

#### Patrol Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_custom_finder_over_find` | Professional | INFO | Use Patrol's custom finders for clearer integration tests. |

#### Pubspec Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `add_resolution_workspace` | Professional | INFO | Add resolution workspace for monorepo dependency management. |
| ⚠️ `avoid_any_version` | Essential | WARNING | Avoid `any` version constraint - specify version ranges. |
| ⚠️ `avoid_dependency_overrides` | Recommended | WARNING | dependency_overrides should only be used temporarily. |
| ℹ️ `dependencies_ordering` | Stylistic | INFO | Dependencies should be sorted alphabetically. |
| ℹ️ `newline_before_pubspec_entry` | Stylistic | INFO | Add blank lines between major pubspec sections. |
| ℹ️ `prefer_caret_version_syntax` | Stylistic | INFO | Use `^1.0.0` caret syntax for version constraints. |
| ℹ️ `prefer_commenting_pubspec_ignores` | Professional | INFO | Document why pubspec rules are ignored. |
| ℹ️ `prefer_correct_screenshots` | Professional | INFO | Screenshots in pubspec should have valid paths and descriptions. |
| ℹ️ `prefer_correct_topics` | Professional | INFO | Topics should be valid pub.dev topics. |
| ℹ️ `prefer_pinned_version_syntax` | Professional | INFO | Pin exact versions for production stability. |
| ℹ️ `prefer_publish_to_none` | Recommended | INFO | Private packages should have `publish_to: none`. |
| ⚠️ `prefer_semver_version` | Essential | WARNING | Version should follow semantic versioning (major.minor.patch). |
| ℹ️ `pubspec_ordering` | Stylistic | INFO | Pubspec fields should follow recommended ordering. |

#### Widget/Flutter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_collection_mutating_methods` | Professional | WARNING | Avoid methods that mutate collections in place. |
| ⚠️ `avoid_missing_controller` | Essential | WARNING | Widgets requiring controllers should have them provided. |
| ℹ️ `avoid_unnecessary_null_aware_elements` | Recommended | INFO | Null-aware elements in collections that can't be null. |
| ℹ️ `use_closest_build_context` | Professional | INFO | Use the closest available BuildContext for better performance. |

---

## Part 2: Stylistic & Preference Rules

> **Note**: These rules are **not included in any tier** by default. They represent team preferences where there is no objectively "correct" answer. Teams explicitly enable them based on their coding conventions. See [Legend > Tier Definitions](#tier-definitions) for tier explanations.

### Stylistic / Opinionated Rules

These rules are **not included in any tier** by default. They represent team preferences where there is no objectively "correct" answer. Teams explicitly enable them based on their coding conventions.

> **See [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for full documentation on implemented stylistic rules.

#### Planned Stylistic Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_grouped_related_statements` | Stylistic | INFO | Prefer grouping related statements for readability. |
| ℹ️ `prefer_ungrouped_statements` | Stylistic | INFO | Prefer ungrouped statements for certain logic flows. |
| ℹ️ `prefer_blank_line_between_members` | Stylistic | INFO | Blank line between class members. |
| ℹ️ `prefer_compact_members` | Stylistic | INFO | Compact class member declarations. |
| ℹ️ `prefer_named_constructor_parameters` | Stylistic | INFO | Prefer named parameters in constructors for clarity. |
| ℹ️ `prefer_positional_constructor_parameters` | Stylistic | INFO | Prefer positional parameters in constructors for brevity. |
| ℹ️ `prefer_explicit_parameter_assignment` | Stylistic | INFO | Prefer explicit parameter assignment in constructors. |
| ℹ️ `prefer_const_constructor_declarations` | Stylistic | INFO | Prefer declaring constructors as const when possible. |
| ℹ️ `prefer_non_const_constructors` | Stylistic | INFO | Prefer non-const constructors when mutation is required. |
| ℹ️ `prefer_factory_constructor` | Stylistic | INFO | Prefer factory constructors for object creation patterns. |

### Miscellaneous Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `avoid_bool_in_widget_constructors` | Professional | INFO | Avoid using bools in widget constructors; prefer enums for clarity. |
| ℹ️ `avoid_cascades` | Stylistic | INFO | Discourage use of cascade (..) for clarity and maintainability. |
| ℹ️ `avoid_classes_with_only_static_members` | Recommended | INFO | Avoid classes with only static members; use top-level functions or variables. |
| ℹ️ `avoid_double_and_int_checks` | Professional | INFO | Avoid type checks for double/int; use num or generic constraints. |
| ⚠️ `avoid_dynamic_calls` | Recommended | WARNING | Avoid dynamic calls; prefer static typing for safety. |
| ℹ️ `avoid_equals_and_hash_code_on_mutable_classes` | Professional | INFO | Avoid overriding equals/hashCode on mutable classes. |
| ℹ️ `avoid_escaping_inner_quotes` | Stylistic | INFO | Prefer consistent quote usage to avoid escaping. |
| ℹ️ `avoid_field_initializers_in_const_classes` | Professional | INFO | Avoid field initializers in const classes; use constructor initializers. |
| ℹ️ `avoid_function_literals_in_foreach_calls` | Stylistic | INFO | Prefer method references over function literals in forEach. |
| ℹ️ `avoid_implementing_value_types` | Professional | INFO | Avoid implementing value types; use composition instead. |
| ℹ️ `avoid_js_rounded_ints` | Comprehensive | INFO | Avoid relying on JS number rounding for ints. |
| ℹ️ `avoid_null_checks_in_equality_operators` | Professional | INFO | Avoid null checks in == operator; use identical or null-aware logic. |
| ℹ️ `avoid_positional_boolean_parameters` | Professional | INFO | Avoid positional boolean parameters; use named or enums. |
| ℹ️ `avoid_private_typedef_functions` | Comprehensive | INFO | Avoid private typedef functions; prefer public for clarity. |
| ℹ️ `avoid_redundant_argument_values` | Recommended | INFO | Avoid redundant argument values; use defaults. |
| ℹ️ `avoid_redundant_await` | Recommended | INFO | Avoid redundant await; return the future directly. |
| ℹ️ `avoid_returning_null_for_future` | Recommended | INFO | Avoid returning null for Future; return Future.value(). |
| ℹ️ `avoid_returning_null_for_void` | Recommended | INFO | Avoid returning null for void; just return. |
| ℹ️ `avoid_returning_this` | Stylistic | INFO | Avoid returning this from methods; prefer fluent interfaces. |
| ℹ️ `avoid_setters_without_getters` | Professional | INFO | Avoid setters without corresponding getters. |
| ⚠️ `avoid_shadowing_type_parameters` | Recommended | WARNING | Avoid shadowing type parameters in generics. |
| ℹ️ `avoid_single_cascade_in_expression_statements` | Stylistic | INFO | Avoid single cascade in expression statements; use direct call. |
| ℹ️ `avoid_types_on_closure_parameters` | Stylistic | INFO | Avoid explicit types on closure parameters when unnecessary. |
| ℹ️ `avoid_unnecessary_containers` | Recommended | INFO | Avoid unnecessary Container widgets in Flutter. |
| ⚠️ `avoid_unused_constructor_parameters` | Recommended | WARNING | Avoid unused constructor parameters; remove or use them. |
| ⚠️ `avoid_void_async` | Recommended | WARNING | Avoid async functions that return void. |
| ℹ️ `prefer_asserts_in_initializer_lists` | Professional | INFO | Prefer asserts in initializer lists for constructors. |
| ℹ️ `prefer_const_constructors_in_immutables` | Professional | INFO | Prefer const constructors in immutable classes. |
| ℹ️ `prefer_const_declarations` | Recommended | INFO | Prefer const declarations where possible. |
| ℹ️ `prefer_const_literals_to_create_immutables` | Recommended | INFO | Prefer const literals to create immutable collections. |
| ℹ️ `prefer_constructors_over_static_methods` | Stylistic | INFO | Prefer constructors over static factory methods. |
| ℹ️ `prefer_expression_function_bodies` | Recommended | INFO | Prefer expression function bodies for simple functions. |
| ℹ️ `prefer_final_fields` | Professional | INFO | Prefer final fields for immutability. |
| ℹ️ `prefer_final_locals` | Recommended | INFO | Prefer final for local variables. |
| ℹ️ `prefer_foreach` | Stylistic | INFO | Prefer forEach over for-in for readability. |
| ℹ️ `prefer_if_elements_to_conditional_expressions` | Recommended | INFO | Prefer if elements in collections to conditional expressions. |
| ℹ️ `prefer_inlined_adds` | Recommended | INFO | Prefer inlined adds in collection literals. |
| ℹ️ `fold` | Stylistic | INFO | Use fold for collection reduction where appropriate. |
| ℹ️ `prefer_asmap_over_indexed_iteration` | Professional | INFO | Prefer asMap().entries for indexed iteration over manual index. |
| ℹ️ `prefer_cascade_assignments` | Stylistic | INFO | Prefer using cascade (..) for assignments to the same object. |
| ℹ️ `prefer_constructor_over_literals` | Stylistic | INFO | Prefer List()/Map() constructors over literals in certain contexts. |
| ℹ️ `prefer_explicit_null_checks` | Stylistic | INFO | Prefer explicit null checks for clarity. |
| ℹ️ `prefer_fire_and_forget` | Stylistic | INFO | Prefer fire-and-forget async calls where result is not needed. |
| ℹ️ `prefer_fold_over_reduce` | Stylistic | INFO | Prefer fold over reduce for collections when initial value is needed. |
| ℹ️ `prefer_foreach_over_map_entries` | Stylistic | INFO | Prefer forEach for map iteration over map.entries. |
| ℹ️ `prefer_if_else_over_guards` | Stylistic | INFO | Prefer if-else over guard clauses for certain logic. |
| ℹ️ `prefer_null_aware_method_calls` | Recommended | INFO | Prefer null-aware method calls (?.) for nullable objects. |
| ℹ️ `prefer_separate_assignments` | Stylistic | INFO | Prefer separate assignments over chained or compound assignments. |
| ℹ️ `prefer_then_catcherror` | Stylistic | INFO | Prefer then().catchError() over try/catch for async error handling. |

#### Import & File Organization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_sorted_imports` | Professional | INFO | Alphabetically sort imports within groups |
| ℹ️ `prefer_import_groups` | Professional | INFO | Group imports: dart, package, relative (with blank lines) |
| ℹ️ `prefer_deferred_imports` | Comprehensive | INFO | Use deferred imports for large libraries |
| ℹ️ `prefer_show_hide` | Comprehensive | INFO | Explicit `show`/`hide` on imports |
| ℹ️ `prefer_part_over_import` | Pedantic | INFO | Use `part`/`part of` for tightly coupled files |
| ℹ️ `prefer_import_over_part` | Professional | INFO | Use imports instead of `part`/`part of` |

#### Naming Conventions

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_lowercase_constants` | Recommended | INFO | Constants in `lowerCamelCase` (Dart style guide) |
| ℹ️ `prefer_verb_method_names` | Professional | INFO | Methods start with verbs (`get`, `set`, `fetch`, `compute`) |
| ℹ️ `prefer_noun_class_names` | Professional | INFO | Class names are nouns or noun phrases |
| ℹ️ `prefer_adjective_bool_getters` | Professional | INFO | Boolean getters as adjectives (`isEmpty` vs `getIsEmpty`) |
| ℹ️ `prefer_i_prefix_interfaces` | Comprehensive | INFO | Interface classes use `I` prefix (`IRepository`) |
| ℹ️ `prefer_no_i_prefix_interfaces` | Comprehensive | INFO | Interface classes without `I` prefix |
| ℹ️ `prefer_impl_suffix` | Comprehensive | INFO | Implementation classes use `Impl` suffix |
| ℹ️ `prefer_base_prefix` | Comprehensive | INFO | Base classes use `Base` prefix |
| ℹ️ `prefer_mixin_prefix` | Comprehensive | INFO | Mixins use `Mixin` suffix or no suffix |
| ℹ️ `prefer_extension_suffix` | Comprehensive | INFO | Extensions use `Extension` or `X` suffix |

#### Member Ordering

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_constructors_first` | Professional | INFO | Constructors before other members |
| ℹ️ `prefer_getters_before_setters` | Professional | INFO | Getters immediately before their setters |
| ℹ️ `prefer_static_before_instance` | Professional | INFO | Static members before instance members |
| ℹ️ `prefer_factory_before_named` | Comprehensive | INFO | Factory constructors before named constructors |
| ℹ️ `prefer_overrides_last` | Comprehensive | INFO | `@override` methods at bottom of class |

#### Comments & Documentation

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `prefer_no_commented_code` | Recommended | WARNING | Disallow commented-out code blocks |
| ℹ️ `prefer_inline_comments_sparingly` | Comprehensive | INFO | Limit inline comments; prefer self-documenting code |

#### String Preferences

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_raw_strings` | Professional | INFO | Raw strings `r'...'` when escapes are heavy |
| ℹ️ `prefer_adjacent_strings` | Recommended | INFO | Adjacent strings over `+` concatenation |
| ℹ️ `prefer_interpolation_to_compose` | Recommended | INFO | String interpolation `${}` over concatenation |

#### Function & Method Style

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_function_over_static_method` | Comprehensive | INFO | Top-level functions over static methods |
| ℹ️ `prefer_static_method_over_function` | Comprehensive | INFO | Static methods over top-level functions |
| ℹ️ `prefer_expression_body_getters` | Recommended | INFO | Arrow `=>` for simple getters |
| ℹ️ `prefer_block_body_setters` | Comprehensive | INFO | Block body `{}` for setters |
| ℹ️ `prefer_positional_bool_params` | Comprehensive | INFO | Boolean parameters as positional |
| ℹ️ `prefer_named_bool_params` | Professional | INFO | Boolean parameters as named |
| ℹ️ `prefer_optional_positional_params` | Comprehensive | INFO | `[optional]` over `{named}` |
| ℹ️ `prefer_optional_named_params` | Recommended | INFO | `{named}` over `[positional]` |

#### Type & Class Style

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_final_fields_always` | Professional | INFO | All instance fields should be `final` |
| ℹ️ `prefer_mixin_over_abstract` | Professional | INFO | Mixins over abstract classes when appropriate |
| ℹ️ `prefer_extension_over_utility_class` | Professional | INFO | Extension methods over static utility classes |
| ℹ️ `prefer_inline_function_types` | Comprehensive | INFO | Inline function types over `typedef` |
| ℹ️ `prefer_sealed_classes` | Professional | INFO | Sealed classes for closed type hierarchies |

---

## Part 3: Technical Debt & Improvements

### 3.0 SaropaLintRule Base Class Enhancements

The `SaropaLintRule` base class provides enhanced features for all lint rules.

#### Planned Enhancements

| Feature | Priority | Description |
|---------|----------|-------------|
| 💡 [Discussion: Diagnostic Statistics](https://github.com/saropa/saropa_lints/discussions/55) | Medium | Track hit counts per rule for metrics/reporting |
| 💡 [Discussion: Related Rules](https://github.com/saropa/saropa_lints/discussions/57) | Low | Link related rules together, suggest complementary rules |
| 💡 [Discussion: Suppression Tracking](https://github.com/saropa/saropa_lints/discussions/56) | High | Audit trail of suppressed lints for tech debt tracking |
| 💡 [Discussion: Batch Deduplication](https://github.com/saropa/saropa_lints/discussions/58) | Low | Prevent duplicate reports at same offset |
| 💡 [Discussion: Custom Ignore Prefixes](https://github.com/saropa/saropa_lints/discussions/59) | Low | Support `// saropa-ignore:`, `// tech-debt:` prefixes |
| 💡 [Discussion: Performance Tracking](https://github.com/saropa/saropa_lints/discussions/60) | Medium | Measure rule execution time for optimization |
| 💡 [Discussion: Tier-Based Filtering](https://github.com/saropa/saropa_lints/discussions/61) | Medium | Enable/disable rules by tier at runtime |

---

## Part 4: Modern Language Feature Rules

Rules to help adopt modern Dart and Flutter language features.

### 4.1 Dart 3.x Feature Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `use_specific_deprecation` | Professional | INFO | Use Dart 3.10 specific deprecation annotations for finer-grained control. |
| ℹ️ `avoid_redundant_null_check` | Recommended | INFO | Dart 3.9 improved type promotion makes some null checks redundant. |
| ℹ️ `prefer_js_interop_over_dart_js` | Professional | INFO | Use stable `dart:js_interop` (Dart 3.5) instead of deprecated `dart:js`. |
| ℹ️ `prefer_extension_type_for_wrapper` | Professional | INFO | Use extension types (Dart 3.3) for zero-cost type wrappers. |
| ℹ️ `prefer_record_over_tuple_class` | Professional | INFO | Use records (Dart 3.0) instead of tuple classes. |
| ℹ️ `prefer_sealed_for_state` | Professional | INFO | Use sealed classes (Dart 3.0) for exhaustive state hierarchies. |
| ⚠️ `require_exhaustive_sealed_switch` | Essential | WARNING | Switch on sealed types must handle all cases. |

### 4.2 Flutter Widget Feature Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_overlay_portal_layout_builder` | Professional | INFO | Use OverlayPortal.overlayChildLayoutBuilder (Flutter 3.38) for unconstrained overlays. |

---

## Part 5: Package-Specific Rules

Rules for popular Flutter packages based on common gotchas, anti-patterns, and best practices.

### 5.2 go_router Navigation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_go_router_builder` | Professional | INFO | Use go_router_builder for compile-time route safety. Detect hand-written route paths. |

### 5.3 Provider State Management Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_provider_update_should_notify` | Professional | INFO | ChangeNotifiers should implement efficient notifyListeners. Detect notifying on every setter. |

### 5.4 Riverpod Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_riverpod_lint_package` | Recommended | INFO | Install riverpod_lint for official linting. Detect Riverpod usage without riverpod_lint dependency. |
| ℹ️ `avoid_riverpod_string_provider_name` | Professional | INFO | Provider.name should be auto-generated. Detect manual name strings in providers. |
| ℹ️ `prefer_riverpod_code_gen` | Professional | INFO | Use @riverpod annotation for type-safe providers. Detect hand-written provider declarations. |
| ℹ️ `prefer_riverpod_keep_alive` | Professional | INFO | Long-lived state should use ref.keepAlive(). Detect state loss from auto-dispose. |

### 5.5 Bloc/Cubit Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_behavior_subject_last_value` | Professional | WARNING | BehaviorSubject retains value after close. Use PublishSubject when appropriate. |

### 5.6 GetX Anti-Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_getx_builder_over_obx` | Recommended | INFO | GetBuilder is more explicit than Obx for state. Detect mixed patterns. |
| ⚠️ `avoid_getx_rx_nested_obs` | Professional | WARNING | Nested .obs creates complex reactive trees. Detect Rx<List<Rx<Type>>>. |

### 5.7 Hive Database Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_hive_type_modification` | Professional | WARNING | Modifying Hive type fields breaks existing data. Detect field type changes. |
| ℹ️ `prefer_hive_compact` | Professional | INFO | Large boxes should be compacted periodically. Detect long-running box without compact. |
| ℹ️ `prefer_hive_web_aware` | Recommended | INFO | Hive web has different behavior. Detect Hive usage without web considerations. |

### 5.8 SharedPreferences Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_shared_prefs_large_data` | Professional | WARNING | SharedPreferences isn't for large data. Detect storing >1KB values. |
| ⚠️ `avoid_shared_prefs_sync_race` | Professional | WARNING | Multiple writers can race. Detect concurrent SharedPreferences writes. |

### 5.9 sqflite Database Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_sqflite_index_for_queries` | Professional | INFO | Frequently queried columns need indexes. Detect slow queries without index. |
| ⚠️ `prefer_sqflite_encryption` | Professional | WARNING | Sensitive databases need encryption. Use sqlcipher_flutter_libs. |

### 5.10 cached_network_image Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `require_cached_image_device_pixel_ratio` | Professional | INFO | Consider devicePixelRatio for sizing. Detect fixed sizes without DPR. |
| ⚠️ `avoid_cached_image_web` | Recommended | WARNING | CachedNetworkImage lacks web caching. Detect web usage; suggest alternatives. |
| ⚠️⭐ `avoid_cached_image_unbounded_list` | Essential | WARNING | Image lists need bounded cache. Detect ListView with many CachedNetworkImages. |

### 5.11 image_picker Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `avoid_image_picker_quick_succession` | Professional | WARNING | Multiple rapid picks cause ALREADY_ACTIVE error. Detect pickImage without debounce. |

### 5.12 permission_handler Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️⭐ `prefer_permission_request_in_context` | Professional | INFO | Request permissions when needed, not at startup. Detect all permissions in main(). |
| ℹ️ `require_permission_lifecycle_observer` | Professional | INFO | Re-check permissions on app resume. Detect missing WidgetsBindingObserver. |
| ℹ️ `prefer_permission_minimal_request` | Recommended | INFO | Request only needed permissions. Detect requesting unused permissions. |
| ⚠️ `avoid_permission_request_loop` | Professional | WARNING | Don't repeatedly request denied permission. Detect request in loop or retry. |

### 5.13 geolocator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_geolocator_coarse_location` | Recommended | INFO | ACCESS_COARSE_LOCATION for city-level. Detect fine permission for coarse needs. |

### 5.14 flutter_local_notifications Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_notification_custom_sound | Professional | INFO | Important notifications may need custom sound. Document sound configuration. |

### 5.15 connectivity_plus Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_connectivity_equals_internet` | Essential | WARNING | Connectivity type doesn't mean internet access. Detect using status to skip network call. |
| ⚠️ `require_connectivity_timeout` | Essential | WARNING | Always set timeout on network requests. Connectivity status can be misleading. |
| ℹ️ `prefer_internet_connection_checker` | Professional | INFO | Use internet_connection_checker for actual internet verification. |
| ℹ️ `require_connectivity_resume_check` | Professional | INFO | Re-check connectivity when app resumes. Android 8+ stops background updates. |
| ⚠️ `avoid_connectivity_ui_decisions` | Professional | WARNING | Don't block UI based on connectivity alone. Detect conditional UI from connectivity. |
| ℹ️ `prefer_connectivity_debounce` | Professional | INFO | Debounce rapid connectivity changes. Detect status handler without debounce. |

### 5.16 url_launcher Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_url_launcher_sandbox_issues` | Professional | WARNING | Launched apps run in Flutter sandbox. Document back navigation issues. |

### 5.17 freezed/json_serializable Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `avoid_freezed_invalid_annotation_target` | Recommended | INFO | Disable invalid_annotation_target warning in analysis_options. |
| ℹ️ `prefer_freezed_union_types` | Professional | INFO | Use Freezed unions for sealed state. Detect manual sealed class hierarchies. |
| ⚠️ `avoid_freezed_any_map_issue` | Professional | WARNING | any_map in build.yaml not respected in .freezed.dart. Document workaround. |

### 5.18 equatable Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_equatable_nested_equality | Professional | WARNING | Nested Equatables should also be immutable. Detect mutable nested objects. |

### 5.19 http Package Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `require_ssl_pinning_sensitive` | Professional | WARNING | Sensitive APIs need certificate pinning. Detect auth endpoints without pinning. |
| ⚠️ `avoid_stack_trace_in_production` | Essential | WARNING | Don't show stack traces to users. Detect printStackTrace in error handlers. |
| ⚠️ `require_input_validation` | Essential | WARNING | Validate user input before sending. Detect raw input in API calls. |
| ℹ️ `require_content_type_validation` | Professional | INFO | Verify response Content-Type. Detect JSON parsing without content-type check. |
| ⚠️ `require_error_handling_graceful` | Essential | WARNING | Show friendly errors, not technical ones. Detect raw exception messages in UI. |

### 5.20 Animation Performance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_clip_during_animation` | Professional | WARNING | Pre-clip content before animating. Detect ClipRect in animated widget. |
| ⚠️⭐ `avoid_excessive_rebuilds_animation` | Essential | WARNING | Don't wrap entire screen in AnimatedBuilder. Detect large subtree in builder. |
| ⚠️ `avoid_multiple_animation_controllers` | Professional | WARNING | Multiple controllers on same widget conflict. Detect multiple controllers without coordination. |

### 5.21 Stream/StreamBuilder Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_stream_transformer` | Professional | INFO | Use transformers for complex operations. Detect manual stream manipulation. |
| ℹ️ `require_stream_cancel_on_error` | Professional | INFO | Consider cancelOnError for critical streams. Detect error-sensitive streams. |
| ℹ️ `prefer_rxdart_for_complex_streams` | Professional | INFO | RxDart provides better operators. Detect complex stream transformations. |

### 5.22 Future/Async Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_cancellable_operations` | Professional | INFO | Long operations should be cancellable. Detect Completer without cancel mechanism. |

### 5.23 Widget Lifecycle Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_expensive_did_change_dependencies` | Professional | WARNING | didChangeDependencies runs often. Detect heavy work in didChangeDependencies. |
| ℹ️ `prefer_deactivate_for_cleanup` | Professional | INFO | Use deactivate for removable cleanup. Detect dispose-only cleanup that could be in deactivate. |

### 5.24 Form/TextFormField Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_input_formatters` | Professional | INFO | Use inputFormatters for controlled input. Detect manual onChange filtering. |
| ⚠️ `avoid_form_validation_on_change` | Professional | WARNING | Validating every keystroke is expensive. Detect onChanged triggering validation. |
| ℹ️ `prefer_form_bloc_for_complex` | Professional | INFO | Complex forms benefit from FormBloc. Detect forms with >5 fields and conditionals. |
| ℹ️ `require_error_message_clarity` | Recommended | INFO | Error messages should explain fix. Detect generic "Invalid" messages. |

### 5.25 ListView/GridView Performance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_const_list_items` | Professional | INFO | List items should be const when possible. Detect non-const static items. |
| ℹ️ `prefer_cache_extent` | Professional | INFO | Tune cacheExtent for performance. Detect default cacheExtent with issues. |
| ℹ️ `require_addAutomaticKeepAlives_off` | Professional | INFO | Disable for memory savings in long lists. Detect long list with default true. |
| ℹ️ `prefer_find_child_index_callback` | Professional | INFO | Use for custom child positioning. Detect custom index needs. |

### 5.26 Navigator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_will_pop_scope | Professional | INFO | Handle back button appropriately. Detect navigation without back handling. |
| ℹ️ `prefer_named_routes_for_deep_links` | Professional | INFO | Named routes enable deep linking. Detect anonymous route construction. |

### 5.27 auto_route Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️⭐ `require_auto_route_guard_resume` | Essential | WARNING | Call resolver.next(true) after guard condition met. Detect guard without resume. |
| ⚠️ `avoid_auto_route_context_navigation` | Professional | WARNING | Use router instead of context for nested navigation. Detect context.push in nested route. |
| ℹ️ `require_auto_route_page_suffix` | Stylistic | INFO | Page classes should have Page suffix. Detect @RoutePage without suffix. |
| ℹ️ `prefer_auto_route_path_params_simple` | Recommended | INFO | Path params should be simple types. Detect complex objects in path. |
| ⚠️ `require_auto_route_full_hierarchy` | Essential | WARNING | Navigate with full parent hierarchy. Detect child route without parent. |
| ℹ️ `prefer_auto_route_typed_args` | Professional | INFO | Use strongly typed route arguments. Detect dynamic args passing. |
| ⚠️ `avoid_auto_route_keep_history_misuse` | Professional | WARNING | Understand keepHistory: false behavior. Detect unintended stack modification. |
| ℹ️ `require_auto_route_deep_link_config` | Professional | INFO | Configure deep links properly. Detect routes without path configuration. |

### 5.28 Internationalization (intl) Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_l10n_yaml_config` | Recommended | INFO | Use l10n.yaml for configuration. Detect missing configuration file. |
| ℹ️ `require_rtl_support` | Professional | INFO | Support RTL layouts. Detect hardcoded left/right in layouts. |

### 5.29 Firebase Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_firestore_admin_role_overuse` | Professional | WARNING | Limit admin roles. Detect excessive admin claims assignment. |
| ⚠️ `require_firebase_reauthentication` | Essential | WARNING | Sensitive operations need recent auth. Detect sensitive ops without reauthenticateWithCredential. |
| ℹ️ `require_firebase_email_enumeration_protection` | Professional | INFO | fetchSignInMethodsForEmail was removed. Detect usage in code. |
| ⚠️ `require_firebase_token_refresh` | Essential | WARNING | Handle token refresh on idTokenChanges. Detect missing refresh handler. |
| ⚠️ `avoid_firebase_user_data_in_auth` | Professional | WARNING | Auth claims limited to 1000 bytes. Detect large data in custom claims. |
| ℹ️ `require_firebase_offline_persistence` | Recommended | INFO | Configure Firestore offline persistence. Detect Firestore without persistence settings. |
| ✅ `require_firebase_composite_index` | Essential | ERROR | RTDB compound queries need `.indexOn`. Detect `orderByChild` + filter without index. |
| ℹ️ `prefer_firebase_transaction_for_counters` | Professional | INFO | Use transactions for counters. Detect read-then-write pattern. |
| ⚠️ `require_firebase_app_check_production` | Professional | WARNING | Enable App Check for production. Detect production without App Check. |

### 5.30 WebView Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_webview_local_storage_access` | Professional | WARNING | Limit WebView local storage access. Detect unrestricted storage settings. |
| ℹ️ `require_webview_user_agent` | Professional | INFO | Set custom user agent for analytics. Detect default user agent. |
| ℹ️ `prefer_webview_sandbox` | Professional | INFO | Use sandbox attribute for iframes. Detect iframe without sandbox. |
| ⚠️ `avoid_webview_cors_issues` | Professional | WARNING | WebView has CORS limitations. Document CORS handling. |

### 5.31 Testing Best Practices Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_test_golden_threshold` | Professional | INFO | Set golden test threshold for CI differences. Detect default threshold. |
| ℹ️ `require_test_coverage_threshold` | Professional | INFO | Set minimum coverage threshold. Detect coverage below threshold. |

### 5.33 Memory Optimization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_large_object_in_state` | Professional | WARNING | Large objects in widget state cause memory issues. Detect >1MB objects in state. |
| ℹ️ `require_image_memory_cache_limit` | Professional | INFO | Set PaintingBinding.imageCache limits. Detect default unlimited cache. |
| ℹ️ `prefer_weak_references` | Comprehensive | INFO | Use Expando for optional associations. Detect strong refs where weak would work. |
| ⚠️ `avoid_closure_capture_leaks` | Professional | WARNING | Closures can capture and retain objects. Detect closures capturing large objects. |
| ⚠️ `avoid_unbounded_collections` | Essential | WARNING | Collections without size limits cause OOM. Detect growing collections without limits. |
| ℹ️ `prefer_streams_over_polling` | Professional | INFO | Streams are more memory-efficient than polling. Detect Timer-based polling. |

### 5.34 Error Handling Best Practices Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_error_recovery` | Professional | INFO | Error handlers should enable recovery. Detect catch without user-recoverable action. |
| ℹ️ `prefer_result_type` | Professional | INFO | Use Result/Either types for expected failures. Detect try-catch for business logic. |
| ℹ️ `prefer_zone_error_handler` | Comprehensive | INFO | Use Zone for unhandled async errors. Detect async without zone handling. |

### 5.35 Platform-Specific Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_platform_specific_imports` | Recommended | WARNING | Use conditional imports for platform code. Detect dart:io in web code. |
| ℹ️ `prefer_platform_widget_adaptive` | Recommended | INFO | Use platform-adaptive widgets. Detect Material widgets in iOS-only context. |

### 5.36 API Response Handling Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `require_api_response_validation` | Professional | INFO | Validate API response structure. Detect direct field access without validation. |
| ℹ️ `require_api_version_handling` | Professional | INFO | Handle API version changes. Detect hardcoded response expectations. |

### 5.37 Build Context Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_context_read_not_watch | Professional | INFO | Use context.read in one-time operations. Detect context.watch in single-use callback. |
| ℹ️ `prefer_closest_context` | Professional | INFO | Use closest BuildContext for better performance. Detect distant context usage. |
| ℹ️ `require_context_in_build_descendants` | Professional | INFO | Use Builder for updated context. Detect context issue after widget creation. |

### 5.38 Code Organization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_composition_over_inheritance` | Professional | INFO | Use composition for flexibility. Detect deep inheritance hierarchies. |
| ℹ️ `require_barrel_files` | Professional | INFO | Use barrel files for exports. Detect multiple individual imports. |
| ℹ️ `require_interface_for_dependency` | Professional | INFO | Use interfaces for testability. Detect concrete class dependencies. |
| ℹ️ `prefer_extension_methods` | Professional | INFO | Use extensions for type-specific utilities. Detect static methods that could be extensions. |

### 5.39 Caching Strategy Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_lru_cache` | Professional | INFO | Use LRU for memory-bounded cache. Detect Map used as cache without eviction. |
| ℹ️ `prefer_stale_while_revalidate` | Professional | INFO | Show stale data while refreshing. Detect blocking refresh pattern. |
| ⚠️ `avoid_cache_stampede` | Professional | WARNING | Prevent thundering herd on cache miss. Detect cache without locking. |
| ℹ️ `prefer_disk_cache_for_persistence` | Professional | INFO | Use disk cache for persistence across sessions. Detect memory-only cache for persistent data. |

### 5.40 Debugging & Logging Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_log_levels` | Professional | INFO | Use log levels appropriately. Detect single log level usage. |
| ℹ️ `prefer_conditional_logging` | Professional | INFO | Expensive log message construction should be conditional. Detect expensive string in log. |
| ℹ️ `require_error_context_in_logs` | Professional | INFO | Errors need context for debugging. Detect error log without context. |
| ℹ️ `prefer_log_timestamp` | Professional | INFO | Include timestamps in logs. Detect logs without time information. |

### 5.41 Configuration & Environment Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_flavor_configuration` | Professional | INFO | Use Flutter flavors for environments. Detect manual environment switching. |
| ⚠️ `avoid_string_env_parsing` | Recommended | WARNING | Parse environment strings properly. Detect raw String.fromEnvironment usage. |
| ℹ️ `prefer_compile_time_config` | Professional | INFO | Use const for compile-time config. Detect runtime config lookup for static values. |
| ℹ️ `require_config_validation` | Professional | INFO | Validate configuration on startup. Detect config usage without validation. |

### 5.42 Dependency Injection Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_injectable_package` | Professional | INFO | Use code generation for DI. Detect manual registration boilerplate. |
| ℹ️ `require_di_module_separation` | Professional | INFO | Separate DI configuration into modules. Detect monolithic registration. |

### 5.43 Accessibility Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `require_text_scale_factor_awareness` | Essential | WARNING | UI should handle text scaling. Detect fixed-size text containers. |
| ℹ️ `require_focus_order` | Professional | INFO | Ensure logical focus order. Detect FocusTraversalGroup misconfiguration. |
| ℹ️ `require_reduced_motion_support` | Recommended | INFO | Check MediaQuery.disableAnimations. Detect animations without reduced motion check. |
| ℹ️ `prefer_readable_line_length` | Professional | INFO | Lines shouldn't exceed ~80 characters. Detect wide text without constraints. |
| ℹ️ `require_heading_hierarchy` | Professional | INFO | Use proper heading structure. Detect inconsistent heading levels. |

### 5.44 Auto-Dispose Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_automatic_dispose` | Professional | INFO | Use packages with auto-dispose. Detect manual disposal patterns. |
| ℹ️ `require_subscription_composite` | Professional | INFO | Group subscriptions for batch disposal. Detect multiple individual subscriptions. |
| ℹ️ `prefer_using_for_temp_resources` | Recommended | INFO | Use using() extension for scoped resources. Detect try-finally for temp resources. |
| ℹ️ `require_resource_tracker` | Comprehensive | INFO | Track resources for leak detection. Detect undisposed resources in debug mode. |
| ℹ️ `prefer_cancellation_token_pattern` | Professional | INFO | Use CancelToken pattern for cancelable operations. Detect manual cancellation. |
| ℹ️ `require_dispose_verification_tests` | Professional | INFO | Test dispose is called properly. Detect disposable without dispose test. |

### 5.46 Hot Reload Compatibility Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `require_init_state_idempotent` | Essential | WARNING | initState may run multiple times. Detect non-idempotent initialization. |

> **Note:** Package Version Rules (11 rules) have been moved to [ROADMAP_DEFERRED.md](ROADMAP_DEFERRED.md#deferred-pubspec-rules-11-rules) — they require `[PUBSPEC]` YAML analysis which is not supported by custom_lint.

### 5.47 Widget Composition Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⚠️ `avoid_deep_nesting` | Professional | WARNING | Widgets shouldn't nest too deeply. Detect nesting >10 levels. |
| ⚠️ `avoid_repeated_widget_creation` | Professional | WARNING | Cache widget references when possible. Detect identical widgets created in loop. |
| ℹ️ `prefer_builder_pattern` | Professional | INFO | Use Builder for context-dependent children. Detect context issues. |
| ℹ️ `prefer_sliver_for_mixed_scroll` | Professional | INFO | Use slivers for mixed scrollable content. Detect nested scrollables. |
| ℹ️ `prefer_flex_for_complex_layout` | Professional | INFO | Use Flex over Row/Column for dynamic axis. Detect conditional Row/Column. |
| ℹ️ `prefer_layout_builder_for_constraints` | Professional | INFO | Use LayoutBuilder for constraint-aware layout. Detect MediaQuery for widget sizing. |

### 5.49 Secure Storage Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_biometric_protection` | Professional | INFO | Use biometric protection for sensitive data. Detect authenticationRequired option. |
| ⚠️ `avoid_secure_storage_in_background` | Professional | WARNING | Secure storage may fail in background. Detect background access without handling. |

### 5.50 Late Initialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_late_lazy_initialization` | Professional | INFO | Use late for expensive lazy initialization. Detect eager init of rarely-used fields. |
| ⚠️ `require_late_access_check` | Professional | WARNING | Check isInitialized before late access when uncertain. Detect late access without context guarantee. |

### 5.51 Isar Database Rules

<!-- Placeholder - Isar Database Rules is complete -->

### 5.52 Hive Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ℹ️ `prefer_hive_compact_periodically` | Professional | INFO | Hive files grow without compaction. Call box.compact() after bulk deletes to reclaim space. |
| ⚠️ `avoid_hive_large_single_entry` | Professional | WARNING | Entries >1MB degrade performance. Split large data across multiple keys or use chunking. |
| ⚠️ `avoid_hive_datetime_local` | Professional | WARNING | DateTime stored as-is loses timezone. Convert to UTC before storing, local after reading. |

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

Pick a rule from the list above and submit a PR!

---

> **See also**: [ROADMAP_DEFERRED.md](ROADMAP_DEFERRED.md) for rules requiring cross-file analysis, heuristic detection, or technical limitations.

> **Package-specific rule sources** have been moved to [LINKS.md](LINKS.md#package-specific-rule-sources).
