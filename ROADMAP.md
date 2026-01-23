# Roadmap: Aiming for 2,000 Lint Rules
<!-- cspell:disable -->

## Current Status

See [CHANGELOG.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md) for implemented rules. Goal: 2000 rules.

## ⭐ Next in Line for Implementation

Rules marked with ⭐ are the **next batch** prioritized for implementation. These have been selected for:

 🐙 [`require_android_manifest_entries`](https://github.com/saropa/saropa_lints/issues/36) | Essential | ERROR | `[CROSS-FILE]` Android features need manifest entries. Detect feature without manifest. |
 🐙 [`require_desktop_window_setup`](https://github.com/saropa/saropa_lints/issues/37) | Professional | INFO | `[CROSS-FILE]` Desktop apps need window configuration. Detect desktop target without setup. |
## Maintenance Rules

**IMPORTANT: When a rule is implemented:**

1. **REMOVE the rule from this ROADMAP entirely** - do NOT mark it with ✅ or "DONE"
2. **Document aliases in the rule's doc header** - not here in ROADMAP
   - Example: `/// Alias: require_props_consistency` in the rule's Dart file
3. **Add to CHANGELOG.md** under the appropriate version
4. **Register in saropa_lints.dart** and **tiers.dart**

This ROADMAP is for **planned/unimplemented rules only**.

## Deferred: Pubspec Rules (6 rules)

> **Note**: saropa_lints currently only analyzes `.dart` files using the Dart AST. These pubspec rules require YAML parsing which is not yet supported.

| Rule | Tier | Description |
|------|------|-------------|
| `avoid_any_version` | Essential | `any` version constraint in dependencies |
| `prefer_publish_to_none` | Recommended | Private package without `publish_to: none` |
| `prefer_semver_version` | Essential | Version not matching `x.y.z` format |
| `prefer_caret_version_syntax` | Stylistic | Version constraint without `^` prefix |
| `avoid_dependency_overrides` | Recommended | `dependency_overrides` without explanatory comment |
| `prefer_correct_package_name` | Essential | Package name not matching Dart conventions |

## Implementation Difficulty Warning

> **Not all rules are created equal.** Rules that appear simple often require multiple revisions due to false positives from heuristic-based detection.

### Truly Easy Rules (low false-positive risk)
- Match **exact API/method names**: `jsonDecode()`, `DateTime.parse()`
- Check **specific named parameters**: `shrinkWrap: true`, `autoPlay: true`
- Detect **missing required parameters**: `Image.network` without `errorBuilder`
- Match **constructor + dispose pattern**: `ScrollController` without `dispose()`

### Deceptively Hard Rules (high false-positive risk)
- **Variable name heuristics**: `money`, `price`, `token` → matches `audioVolume`, `cadence`, `tokenizer`
- **Generic terms**: `cost`, `fee`, `balance` have many non-target meanings
- **Short abbreviations**: `iv` matches `activity`, `private`, `derivative`
- **String content analysis**: Must distinguish `$password` from `${password.length}`

**See [CONTRIBUTING.md](CONTRIBUTING.md#avoiding-false-positives-critical)** for detailed guidance on avoiding false positives.

### Risk Legend (used in rule descriptions below)

| Marker | Meaning | Example Pattern |
|--------|---------|-----------------|
| — | Safe: Exact API/parameter matching | `Image.network` without `errorBuilder` |
| `[CONTEXT]` | Needs build/test context detection | Detect if inside `build()` method |
| `[HEURISTIC]` | Variable name or string pattern matching | Detect "money" in variable names |
| `[CROSS-FILE]` | Requires analysis across multiple files | Check if type is registered elsewhere |
| `[TOO-COMPLEX]` | Pattern too abstract for reliable AST detection | Detect "loading state" or "user feedback" generically |
| `[PUBSPEC]` | Requires pubspec.yaml analysis (not Dart AST) | Check package versions, detect deprecated packages |
| 🐙 | Tracked as GitHub issue | [#0000](https://github.com/saropa/saropa_lints/issues/0000) |
| 💡 | Planned enhancement tracked as GitHub Discussion | [Discussion: Diagnostic Statistics](https://github.com/saropa/saropa_lints/discussions/000) |

## Deferred: Cross-File Analysis Rules (2 rules)

> **Note**: These rules require **cross-file dependency graph analysis**. The `avoid_circular_imports` rule has been implemented using the `ImportGraphCache` infrastructure.

| Rule | Tier | Severity | Why Complex |
|------|------|----------|-------------|
| `avoid_provider_circular_dependency` | Essential | ERROR | Requires tracking **Provider dependencies across files** (Provider A depends on Provider B in another file which depends on Provider A). Needs cross-file type resolution and dependency graph construction. |
| 🐙 [`avoid_provider_circular_dependency`](https://github.com/saropa/saropa_lints/issues/2) | Essential | ERROR | Requires tracking **Provider dependencies across files** (Provider A depends on Provider B in another file which depends on Provider A). Needs cross-file type resolution and dependency graph construction. |
| 🐙 [`avoid_riverpod_circular_provider`](https://github.com/saropa/saropa_lints/issues/1) | Essential | ERROR | Requires tracking `ref.watch()` and `ref.read()` calls across **multiple provider definitions in different files** to detect cycles. Needs cross-file provider dependency graph. |

**Implementation Requirements**:
1. Build on existing `ImportGraphCache` infrastructure
2. Add Provider/Riverpod-specific dependency tracking
3. Extend cycle detection for provider dependencies

## Performance Architecture

The `custom_lint` plugin architecture runs inside the Dart analysis server process. This provides excellent IDE integration (real-time squiggles, quick fixes, hover info).

### Blocked Optimizations (Requires custom_lint Framework Changes)

- ❌ `ThrottledAnalysis.recordEdit()` - needs IDE keystroke events
- ❌ `SpeculativeAnalysis.recordFileOpened()` - needs IDE file open events
- ❌ `RuleGroupExecutor` batch execution - custom_lint runs rules independently

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

## Quick Fix Implementation Plan

**Target: 90% of rules with useful quick fixes that DO NOT break apps.**

Current status: ~200 fixes for ~1530 rules (13%). Goal: ~1377 fixes (90%).

### Guiding Principles

1. **Safety first**: A fix that breaks code is worse than no fix. When in doubt, don't add a fix.
2. **No HACK comments**: `// HACK: fix this manually` adds no value. Either fix it properly or don't add a fix.
3. **Context matters**: The "correct" fix often depends on surrounding code that the AST doesn't reveal.
4. **Multiple valid fixes**: When there are several correct approaches, offer multiple fix options or skip the fix.

### Fix Categories by Feasibility

#### Category A: Safe Transformations (Target: 100% coverage)

These fixes have exactly one correct transformation and cannot break code:

| Pattern | Example Rule | Fix |
|---------|--------------|-----|
| Operator replacement | `prefer_not_equals` | `!(a == b)` → `a != b` |
| Constant replacement | `prefer_const_constructor` | Add `const` keyword |
| Remove redundant code | `unnecessary_this` | Remove `this.` prefix |
| Add missing keyword | `prefer_final_locals` | Add `final` keyword |
| Invert condition | `prefer_if_null_operators` | `x != null ? x : y` → `x ?? y` |
| Simplify expression | `prefer_is_empty` | `list.length == 0` → `list.isEmpty` |

**Estimated rules in this category: ~200**

#### Category B: Contextual Transformations (Target: 80% coverage)

These fixes are correct in most contexts but need validation:

| Pattern | Context Check Required | Fix |
|---------|----------------------|-----|
| Add `await` | Function must be `async` | Insert `await` (only if already async) |
| Add `await` | Function is sync lifecycle method | Offer `unawaited()` with import |
| Wrap with widget | Must maintain child relationship | Wrap expression, preserve indentation |
| Add parameter | Default value must be sensible | Add parameter with documented default |
| Add null check | Must not change semantics | Add `?.` or `?? defaultValue` |

**Estimated rules in this category: ~400**

**Implementation approach:**
1. Check preconditions in the fix's `run()` method
2. If preconditions not met, don't apply the fix (return early)
3. Document which contexts the fix handles in the rule's doc comment

#### Category C: Multi-Choice Fixes (Target: 50% coverage)

Multiple valid fixes exist; offer choices or pick the safest:

| Scenario | Options | Approach |
|----------|---------|----------|
| Dispose missing | Add to existing `dispose()` vs create override | Check if `dispose()` exists; add appropriately |
| Error handling | try-catch vs `.catchError()` vs `.onError` | Offer multiple fix options in IDE |
| Async in sync context | `unawaited()` vs extract to async method vs `.then()` | Offer options; `unawaited()` as default |
| Missing import | Multiple packages export same symbol | Don't auto-import; leave to IDE |

**Estimated rules in this category: ~300**

#### Category D: Human Judgment Required (Target: 0% fix coverage)

Do NOT add fixes for these. Document why in the rule's doc comment:

| Scenario | Why No Fix |
|----------|-----------|
| Architecture decisions | "Extract to service" - where? which service? |
| Business logic | "Add validation" - what validation logic? |
| Naming conventions | "Use descriptive name" - that's subjective |
| Complex refactoring | "Split large class" - how to split? |
| Cross-file changes | "Move to separate file" - what filename? |

**Estimated rules in this category: ~600**

### Implementation Phases

#### Phase 1: Category A Rules (Safe Transformations)

Audit all rules to identify Category A patterns. These can be implemented quickly with high confidence:

- [ ] Audit `stylistic_rules.dart` - many are simple transformations
- [ ] Audit `unnecessary_code_rules.dart` - removal/simplification patterns
- [ ] Audit `formatting_rules.dart` - whitespace/keyword additions
- [ ] Audit `equality_rules.dart` - operator replacements

#### Phase 2: Category B Rules (Contextual Transformations)

Create helper utilities for common context checks:

- [ ] `isInAsyncFunction(node)` - check if containing function is async
- [ ] `isInLifecycleMethod(node)` - check if in initState/dispose/build
- [ ] `hasExistingDispose(classNode)` - check for dispose override
- [ ] `getContainingWidget(node)` - find enclosing widget class

Then implement fixes that use these utilities.

#### Phase 3: Category C Rules (Multi-Choice)

For rules where multiple fixes are valid:

- [ ] Implement `getFixes()` returning multiple `Fix` instances
- [ ] Each fix has distinct `message` explaining the approach
- [ ] User chooses in IDE quick-fix menu

#### Phase 4: Documentation

For Category D rules (no fix possible):

- [ ] Add `/// **No quick fix**: [reason]` to doc comments
- [ ] Ensure `correctionMessage` gives actionable human guidance

### Tracking Progress

Update `scripts/audit_rules.py` to track:
- Rules with fixes vs without
- Rules documented as "no fix possible" vs "fix TODO"
- Category breakdown (A/B/C/D)

### Safety Checklist for Every Fix

Before merging any fix:

- [ ] **Does not delete code** (comment out instead, if removal needed)
- [ ] **Does not change runtime behavior** (except to fix the lint issue)
- [ ] **Does not add imports** (unless absolutely required and unambiguous)
- [ ] **Works in edge cases** (empty files, nested structures, generated code)
- [ ] **Tested in example fixtures** (both success and failure cases)

## Part 1: Detailed Rule Specifications

### 1.1 Widget Rules

#### Layout & Composition

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Text & Typography

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.2 State Management

#### Riverpod Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_riverpod_override_in_tests` | Professional | INFO | `[CROSS-FILE]` Tests using real providers have hidden dependencies and unpredictable state. Override providers with mocks for isolated, deterministic tests. |
| 🐙 [`require_riverpod_override_in_tests`](https://github.com/saropa/saropa_lints/issues/3) | Professional | INFO | `[CROSS-FILE]` Tests using real providers have hidden dependencies and unpredictable state. Override providers with mocks for isolated, deterministic tests. |

#### Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_bloc_test_coverage` | Professional | INFO | `[CROSS-FILE]` Blocs should have tests covering all state transitions. Untested state machines have hidden bugs in edge cases. |
| 🐙 [`require_bloc_test_coverage`](https://github.com/saropa/saropa_lints/issues/4) | Professional | INFO | `[CROSS-FILE]` Blocs should have tests covering all state transitions. Untested state machines have hidden bugs in edge cases. |

#### Provider Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### GetX Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.3 Performance Rules

#### Build Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Memory Optimization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_pool_pattern` | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| 🐙 [`prefer_pool_pattern`](https://github.com/saropa/saropa_lints/issues/13) | Comprehensive | INFO | Frequently created/destroyed objects cause GC churn. Object pools reuse instances (e.g., for particles, bullet hell games, or recyclable list items). |
| `require_expando_cleanup` | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |
| 🐙 [`require_expando_cleanup`](https://github.com/saropa/saropa_lints/issues/14) | Comprehensive | INFO | Expando attaches data to objects without modifying them. Entries persist until the key object is GC'd. Remove entries explicitly when done. |

#### Network Performance

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_compression` | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| 🐙 [`require_compression`](https://github.com/saropa/saropa_lints/issues/15) | Comprehensive | INFO | Large JSON/text responses should use gzip compression. Reduces bandwidth 60-80% for typical API responses. |
| `prefer_batch_requests` | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| 🐙 [`prefer_batch_requests`](https://github.com/saropa/saropa_lints/issues/16) | Professional | INFO | Multiple small requests have more overhead than one batched request. Combine related queries when the API supports it. |
| `avoid_blocking_main_thread` | Essential | WARNING | Network I/O on main thread blocks UI during DNS/TLS. While Dart's http is async, large response processing should use isolates. |
| 🐙 [`avoid_blocking_main_thread`](https://github.com/saropa/saropa_lints/issues/17) | Essential | WARNING | Network I/O on main thread blocks UI during DNS/TLS. While Dart's http is async, large response processing should use isolates. |
| `prefer_binary_format` | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |
| 🐙 [`prefer_binary_format`](https://github.com/saropa/saropa_lints/issues/18) | Comprehensive | INFO | Protocol Buffers or MessagePack are smaller and faster to parse than JSON. Consider for high-frequency or large-payload APIs. |

### 1.4 Testing Rules

#### Unit Testing

#### Widget Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Integration Testing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_test_ordering` | Professional | INFO | Integration tests may depend on database state from previous tests. Document dependencies or use `setUp` to ensure required state. |
| `prefer_retry_flaky` | Comprehensive | INFO | Integration tests on real devices are inherently flaky. Configure retry count in CI (e.g., `--retry=2`) rather than deleting useful tests. |
| `prefer_test_data_reset` | Professional | INFO | Each test should start with known state. Reset database, clear shared preferences, and log out users in setUp to prevent test pollution. |
| `require_e2e_coverage` | Professional | INFO | `[CROSS-FILE]` Integration tests are expensive. Focus on critical user journeys: signup, purchase, core features. Don't duplicate unit test coverage. |
| 🐙 [`require_e2e_coverage`](https://github.com/saropa/saropa_lints/issues/5) | Professional | INFO | `[CROSS-FILE]` Integration tests are expensive. Focus on critical user journeys: signup, purchase, core features. Don't duplicate unit test coverage. |
| `avoid_screenshot_in_ci` | Comprehensive | INFO | Screenshots in CI consume storage and slow tests. Take screenshots only on failure for debugging, not on every test. |
| `prefer_test_report` | Comprehensive | INFO | Generate JUnit XML or JSON reports for CI dashboards. Raw console output is hard to track over time. |
| `require_performance_test` | Professional | INFO | Measure frame rendering time and startup latency in integration tests. Catch performance regressions before they reach production. |
| `avoid_test_on_real_device` | Recommended | INFO | Real devices vary in performance and state. Use emulators/simulators in CI for consistent, reproducible results. |
| `prefer_parallel_tests` | Comprehensive | INFO | Independent integration tests can run in parallel with `--concurrency`. Reduces total CI time significantly for large test suites. |

### 1.5 Security Rules

#### Authentication & Authorization

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_oauth_pkce` | Professional | INFO | Mobile OAuth without PKCE is vulnerable to authorization code interception. Use PKCE (Proof Key for Code Exchange) for secure OAuth flows. |
| ⭐ `require_session_timeout` | Professional | INFO | Sessions without timeout remain valid forever if tokens are stolen. Implement idle timeout and absolute session limits. |
| `prefer_deep_link_auth` | Professional | INFO | Deep links with auth tokens (password reset, magic links) must validate tokens server-side and expire quickly. |
| `avoid_remember_me_insecure` | Recommended | WARNING | "Remember me" storing unencrypted credentials is a security risk. Use refresh tokens with proper rotation and revocation. |
| `require_multi_factor` | Comprehensive | INFO | Sensitive operations (payments, account changes) should offer or require multi-factor authentication for additional security. |

#### Data Protection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_keychain_access` | Professional | INFO | iOS Keychain requires proper access groups and entitlements. Incorrect configuration causes data loss on app reinstall. |
| `require_backup_exclusion` | Professional | INFO | Sensitive data should be excluded from iCloud/Google backups. Backups are often less protected than the device. |
| `prefer_root_detection` | Professional | INFO | Rooted/jailbroken devices bypass security controls. Detect and warn users, or disable sensitive features on compromised devices. |

#### Input Validation & Injection

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_whitelist_validation` | Professional | INFO | Validate input against known-good values (allowlist) rather than blocking known-bad values (blocklist). Blocklists miss novel attacks. |
| `prefer_csrf_protection` | Professional | WARNING | State-changing requests need CSRF tokens. Without protection, malicious sites can trigger actions on behalf of logged-in users. |
| `prefer_intent_filter_export` | Professional | INFO | Android intent filters should be exported only when necessary. Unexported components can't be invoked by malicious apps. |

### 1.6 Accessibility Rules

#### Screen Reader Support

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_redundant_semantics` | Comprehensive | INFO | An Image with semanticLabel inside a Semantics wrapper announces twice. Remove duplicate semantic information. |
| ⭐ `prefer_semantics_container` | Professional | INFO | Groups of related widgets should use Semantics `container: true` to indicate they form a logical unit for navigation. |
| `prefer_semantics_sort` | Professional | INFO | Complex layouts may need `sortKey` to control screen reader navigation order. Default order may not match visual layout. |
| `avoid_semantics_in_animation` | Comprehensive | INFO | Semantics should not change during animations. Screen readers get confused by rapidly changing semantic trees. |
| `prefer_announce_for_changes` | Comprehensive | INFO | Important state changes should use `SemanticsService.announce()` to inform screen reader users of non-visual feedback. |

#### Visual Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_color_only_meaning` | Essential | WARNING | Never use color alone to convey information (red=error). Add icons, text, or patterns for colorblind users. |
| `prefer_high_contrast_mode` | Professional | INFO | Support MediaQuery.highContrast for users who need stark color differences. Provide high-contrast theme variant. |
| `prefer_dark_mode_colors` | Professional | INFO | Dark mode isn't just inverted colors. Ensure proper contrast, reduce pure white text, and test readability. |
| `require_link_distinction` | Comprehensive | INFO | Links must be distinguishable from regular text without relying on color alone. Use underline or other visual treatment. |
| `prefer_outlined_icons` | Comprehensive | INFO | Outlined icons have better visibility than filled icons for users with low vision. Consider icon style for accessibility. |

#### Motor Accessibility

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_external_keyboard` | Comprehensive | INFO | Support full keyboard navigation for users who can't use touch. Ensure all actions are reachable via Tab and Enter. |
| `require_switch_control` | Comprehensive | INFO | Switch control users navigate sequentially. Ensure logical focus order and that all interactive elements are focusable. |

### 1.7 Animation Rules

> **All rules in this section have been IMPLEMENTED** in `animation_rules.dart`. See "Moved to Implementation" section above.

### 1.8 Navigation & Routing Rules

#### Navigator & GoRouter

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_go_router_redirect` | Professional | INFO | Auth checks in redirect() run before build, preventing flash of protected content. Checking in build shows then redirects. |

#### Deep Linking

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_branch_io_or_firebase_links` | Professional | INFO | Raw deep links break when app not installed. Branch.io or Firebase Dynamic Links provide install-then-open flow. |

### 1.9 Forms & Validation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_form_bloc_for_complex` | Professional | INFO | Forms with >5 fields, conditional logic, or multi-step flows benefit from form state management (FormBloc, Reactive Forms). |
| ⭐ `prefer_input_formatters` | Professional | INFO | Phone numbers, credit cards, dates should auto-format as user types using TextInputFormatter for better UX. |

### 1.10 Database & Storage Rules

#### Local Database (Hive/Isar/Drift)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_isar_for_complex_queries` | Comprehensive | INFO | Hive's query capabilities are limited. Isar supports complex queries, full-text search, and links between objects. |

### 1.11 Platform-Specific Rules

#### iOS-Specific

> **Implemented in v2.4.0** - See [Apple Platform Rules Guide](doc/guides/apple_platform_rules.md) for 104 iOS/macOS rules including entitlements, launch storyboard, background processing, in-app purchases, and more.

#### macOS-Specific

> **Implemented in v2.4.0** - See [Apple Platform Rules Guide](doc/guides/apple_platform_rules.md) for macOS-specific rules including entitlements, sandbox exceptions, hardened runtime, ATS, and notarization.

#### FFI/Native Interop (iOS/macOS)

> **Note**: These are built-in Dart analyzer diagnostics, not custom lint rules. They are automatically enabled when using `dart:ffi` for iOS/macOS native code integration. Listed here for documentation purposes.

| Diagnostic | Type | Description |
|------------|------|-------------|
| `ffi_native_must_be_external` | Built-in | Functions with `@Native` annotation must be declared `external` to bind to native iOS/macOS code. |
| `ffi_native_invalid_multiple_annotations` | Built-in | Native functions must have exactly one `@Native` annotation. |
| `native_function_missing_type` | Built-in | Type hints required on `@Native` annotations to infer native function types. |
| `native_field_invalid_type` | Built-in | Native fields must use valid FFI types: pointers, arrays, numeric types, or structs/unions. |
| `native_field_not_static` | Built-in | Native fields binding to iOS/macOS symbols must be static. |
| `leaf_call_must_not_return_handle` | Built-in | FFI leaf calls (for performance) cannot return Handle types. |
| `leaf_call_must_not_take_handle` | Built-in | FFI leaf calls cannot accept Handle arguments. |
| `packed_annotation_alignment` | Built-in | Struct packing (for C interop) only supports 1, 2, 4, 8, and 16 byte alignment. |

#### Web-Specific

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_large_assets_on_web` | Recommended | WARNING | Web has no app install; assets download on demand. Lazy-load images and use appropriate formats (WebP) for faster loads. |

#### Desktop-Specific (Windows/macOS/Linux)

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.12 Firebase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.13 Offline-First & Sync Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_optimistic_updates` | Professional | INFO | Update local state immediately, sync to server in background. Waiting for server makes UI feel slow. |
| `require_conflict_resolution_strategy` | Professional | WARNING | Offline edits that conflict with server need resolution: last-write-wins, merge, or user prompt. Define strategy upfront. |
| ⭐ `avoid_full_sync_on_every_launch` | Professional | WARNING | Downloading entire dataset on launch is slow and expensive. Use delta sync with timestamps or change feeds. |

### 1.14 Background Processing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_foreground_service_android` | Professional | INFO | Android kills background services aggressively. Use foreground service with notification for ongoing work. |

### 1.15 Push Notification Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_local_notification_for_immediate` | Recommended | INFO | flutter_local_notifications is better for app-generated notifications. FCM is for server-triggered messages. |

### 1.16 Payment & In-App Purchase Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_grace_period_handling` | Professional | INFO | Users with expired cards get billing grace period. Handle "grace period" status to avoid locking out paying customers. |
| `avoid_entitlement_without_server` | Professional | WARNING | Client-side entitlement checks can be bypassed. Verify subscription status server-side for valuable content. |

### 1.17 Maps & Location Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_continuous_location_updates` | Professional | WARNING | GPS polling drains battery fast. Use significant location changes or geofencing when you don't need real-time updates. |
| ⭐ `prefer_geocoding_cache` | Professional | INFO | Reverse geocoding (coords to address) costs API calls. Cache results; coordinates rarely change for same address. |

### 1.19 Theming & Dark Mode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_semantic_colors` | Professional | INFO | Name colors by purpose (errorColor, successColor) not appearance (redColor). Purposes stay constant; appearances change with theme. |

### 1.20 Responsive & Adaptive Design Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_master_detail_for_large` | Professional | INFO | On tablets, list-detail flows should show both panes (master-detail) rather than stacked navigation. |
| ⭐ `prefer_adaptive_icons` | Recommended | INFO | Icons at 24px default are too small on tablets, too large on watches. Use IconTheme or scale based on screen size. |
| `require_foldable_awareness` | Comprehensive | INFO | Foldable devices have hinges and multiple displays. Use DisplayFeature API to avoid placing content on fold. |

### 1.21 WebSocket & Real-time Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.22 GraphQL Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.23 Audio & Video Player Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_audio_in_background_without_config` | Essential | ERROR | `[CROSS-FILE]` Background audio requires proper iOS/Android configuration. Detect audio playback in apps without background audio capability. |

### 1.24 Bluetooth & IoT Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.25 PDF & Document Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.26 QR Code & Barcode Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.27 Clipboard Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.28 Analytics & Tracking Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_analytics_event_naming` | Professional | INFO | Consistent event naming improves analysis. Detect analytics events not matching configured naming pattern (e.g., snake_case). |
| 🐙 [`require_analytics_event_naming`](https://github.com/saropa/saropa_lints/issues/19) | Professional | INFO | Consistent event naming improves analysis. Detect analytics events not matching configured naming pattern (e.g., snake_case). |
| ⭐ `require_analytics_error_handling` | Recommended | INFO | Analytics failures shouldn't crash the app. Detect analytics calls without try-catch wrapper. |
| [⭐ `require_analytics_error_handling`](https://github.com/saropa/saropa_lints/issues/20) | Recommended | INFO | Analytics failures shouldn't crash the app. Detect analytics calls without try-catch wrapper. |

### 1.29 Feature Flag Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_feature_flag_type_safety` | Recommended | INFO | Use typed feature flag accessors, not raw string lookups. Detect string literal keys in feature flag calls. |
| 🐙 [`require_feature_flag_type_safety`](https://github.com/saropa/saropa_lints/issues/21) | Recommended | INFO | Use typed feature flag accessors, not raw string lookups. Detect string literal keys in feature flag calls. |

### 1.30 Date & Time Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_timezone_display` | Recommended | INFO | When displaying times, indicate timezone or use relative time. Detect time formatting without timezone context. |
| 🐙 [`require_timezone_display`](https://github.com/saropa/saropa_lints/issues/22) | Recommended | INFO | When displaying times, indicate timezone or use relative time. Detect time formatting without timezone context. |
| ⭐ `avoid_datetime_comparison_without_precision` | Professional | INFO | DateTime equality fails due to microsecond differences. Detect direct DateTime equality; suggest difference threshold. |
| 🐙 [`avoid_datetime_comparison_without_precision`](https://github.com/saropa/saropa_lints/issues/23) | Professional | INFO | DateTime equality fails due to microsecond differences. Detect direct DateTime equality; suggest difference threshold. |

### 1.31 Money & Currency Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.32 File I/O Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_temp_file_cleanup` | Professional | INFO | `[CROSS-FILE]` Temp files accumulate over time. Detect temp file creation without corresponding delete. |
| 🐙 [`require_temp_file_cleanup`](https://github.com/saropa/saropa_lints/issues/6) | Professional | INFO | `[CROSS-FILE]` Temp files accumulate over time. Detect temp file creation without corresponding delete. |

### 1.33 Encryption & Cryptography Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.34 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_json_codegen` | Professional | INFO | Manual fromJson/toJson is error-prone. Detect hand-written fromJson methods; suggest json_serializable/freezed. |
| 🐙 [`prefer_json_codegen`](https://github.com/saropa/saropa_lints/issues/24) | Professional | INFO | Manual fromJson/toJson is error-prone. Detect hand-written fromJson methods; suggest json_serializable/freezed. |
| `require_json_date_format_consistency` | Professional | INFO | Dates in JSON need consistent format. Detect DateTime serialization without explicit format. |
| 🐙 [`require_json_date_format_consistency`](https://github.com/saropa/saropa_lints/issues/25) | Professional | INFO | Dates in JSON need consistent format. Detect DateTime serialization without explicit format. |

### 1.35 GetIt & Dependency Injection Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_getit_unregistered_access` | Essential | ERROR | `[CROSS-FILE]` Accessing unregistered type crashes. Detect GetIt.I<T>() for types not registered in visible scope. |
| 🐙 [`avoid_getit_unregistered_access`](https://github.com/saropa/saropa_lints/issues/7) | Essential | ERROR | `[CROSS-FILE]` Accessing unregistered type crashes. Detect GetIt.I<T>() for types not registered in visible scope. |
| `require_getit_dispose_registration` | Professional | INFO | Disposable singletons need dispose callbacks. Detect registerSingleton of Disposable types without dispose parameter. |
| 🐙 [`require_getit_dispose_registration`](https://github.com/saropa/saropa_lints/issues/26) | Professional | INFO | Disposable singletons need dispose callbacks. Detect registerSingleton of Disposable types without dispose parameter. |

### 1.36 Logging Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_log_level_for_production` | Professional | INFO | Debug logs in production waste resources. Detect verbose logging without level checks. |
| 🐙 [`require_log_level_for_production`](https://github.com/saropa/saropa_lints/issues/27) | Professional | INFO | Debug logs in production waste resources. Detect verbose logging without level checks. |
| `avoid_expensive_log_string_construction` | Professional | INFO | Don't build expensive strings for logs that won't print. Detect string interpolation in log calls without level guard. |

### 1.37 Caching Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_cache_in_build` | Essential | WARNING | `[CONTEXT]` Cache lookups in build() may be expensive. Detect cache operations inside build methods. |

### 1.38 Pagination Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_pagination_for_large_lists` | Essential | WARNING | Loading all items at once causes OOM and slow UI. Detect ListView/GridView with large itemCount without pagination. |
| `avoid_pagination_refetch_all` | Professional | WARNING | Refetching all pages on refresh wastes bandwidth. Detect refresh logic that resets all paginated data. |
| `require_pagination_error_recovery` | Recommended | INFO | Failed page loads need retry option. Detect pagination without error state handling. |

### 1.39 Search & Filter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_search_cancel_previous` | Professional | INFO | Cancel previous search request when new search starts. Detect search without CancelToken or similar mechanism. |

### 1.41 Image Loading & Optimization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.42 ListView & ScrollView Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_sliverfillremaining_for_empty` | Professional | INFO | Empty state in CustomScrollView needs SliverFillRemaining. Detect empty state widget as regular sliver. |

### 1.44 Internationalization (L10n) Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_rtl_layout_support` | Recommended | WARNING | RTL languages need directional awareness. Detect hardcoded left/right in layouts without Directionality check. |

### 1.45 Gradient & CustomPaint Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.46 Dialog & Modal Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.47 Snackbar & Toast Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_snackbar_duration_consideration` | Recommended | INFO | `[HEURISTIC]` Important messages need longer duration. Detect SnackBar without explicit duration for important content. |

### 1.48 Tab & Bottom Navigation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.49 Stepper & Multi-step Flow Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_stepper_state_management` | Professional | INFO | Stepper state should handle back navigation. Detect Stepper without preserving form state across steps. |

### 1.50 Badge & Indicator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 1.51 Avatar & Profile Image Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_avatar_loading_placeholder` | Recommended | INFO | Show placeholder while avatar loads. Detect CircleAvatar without placeholder during load. |

### 1.52 Loading State Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_loading_timeout` | Essential | WARNING | `[TOO-COMPLEX]` Infinite loading states lose users. Cannot reliably detect "loading state" generically via AST - would need package-specific implementations (dio timeout, etc.). |
| 🐙 [`require_loading_timeout`](https://github.com/saropa/saropa_lints/issues/9) | Essential | WARNING | `[TOO-COMPLEX]` Infinite loading states lose users. Cannot reliably detect "loading state" generically via AST - would need package-specific implementations (dio timeout, etc.). |
| `require_loading_state_distinction` | Recommended | INFO | `[TOO-COMPLEX]` Initial load vs refresh should differ. Cannot reliably distinguish "initial load" vs "refresh" states in static analysis. |
| 🐙 [`require_loading_state_distinction`](https://github.com/saropa/saropa_lints/issues/10) | Recommended | INFO | `[TOO-COMPLEX]` Initial load vs refresh should differ. Cannot reliably distinguish "initial load" vs "refresh" states in static analysis. |

### 1.53 Pull-to-Refresh Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_refresh_completion_feedback` | Recommended | INFO | `[TOO-COMPLEX]` Refresh without visible change confuses users. Cannot detect "visible change" or "user feedback" generically - setState could update anything. |
| 🐙 [`require_refresh_completion_feedback`](https://github.com/saropa/saropa_lints/issues/11) | Recommended | INFO | `[TOO-COMPLEX]` Refresh without visible change confuses users. Cannot detect "visible change" or "user feedback" generically - setState could update anything. |

### 1.54 Infinite Scroll Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_infinite_scroll_end_indicator` | Recommended | INFO | `[TOO-COMPLEX]` Detect when all items loaded. Pattern requires detecting scroll listener + hasMore flag + end indicator - too many variables for reliable detection. |
| 🐙 [`require_infinite_scroll_end_indicator`](https://github.com/saropa/saropa_lints/issues/12) | Recommended | INFO | `[TOO-COMPLEX]` Detect when all items loaded. Pattern requires detecting scroll listener + hasMore flag + end indicator - too many variables for reliable detection. |
| ⭐ `prefer_infinite_scroll_preload` | Professional | INFO | Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll. |
| 🐙 [`prefer_infinite_scroll_preload`](https://github.com/saropa/saropa_lints/issues/28) | Professional | INFO | Load next page before reaching end. Detect ScrollController listener triggering at 100% scroll. |
| `require_infinite_scroll_error_recovery` | Recommended | INFO | Failed page loads need retry. Detect infinite scroll without error state and retry button. |
| ⭐ `avoid_infinite_scroll_duplicate_requests` | Professional | WARNING | Prevent multiple simultaneous page requests. Detect scroll listener without loading guard. |

### 1.55 Architecture Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_banned_api` | Professional | WARNING | Configurable rule to restrict usage of specific APIs based on source package, class name, identifier, or named parameter, with include/exclude file patterns. Useful for enforcing layer boundaries (e.g., UI cannot call database directly). Inspired by solid_lints' `avoid_using_api`. |

### 1.56 Type Safety & Casting Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_explicit_type_declaration` | Stylistic | INFO | Prefer type inference over explicit type declarations where the type is obvious. |

### 1.57 Error Handling Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `handle_throwing_invocations` | Professional | INFO | Invocations that can throw should be handled appropriately. |
| `prefer_correct_throws` | Professional | INFO | Document thrown exceptions with `@Throws` annotation. |

### 1.58 Class & Inheritance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_accessing_other_classes_private_members` | Professional | WARNING | Detect access to private members of other classes through workarounds. |
| `avoid_referencing_subclasses` | Professional | INFO | Base classes should not reference their subclasses directly. |
| `avoid_renaming_representation_getters` | Professional | INFO | Extension type representation getters should not be renamed. |
| `avoid_suspicious_super_overrides` | Professional | WARNING | Detect suspicious super.method() calls in overrides. |
| `prefer_class_destructuring` | Professional | INFO | Use record destructuring for class field access when beneficial. |

### 1.59 JSON & Serialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_correct_json_casts` | Professional | INFO | Use proper type casts when working with JSON data. |

### 1.60 Ordering & Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `pattern_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in pattern matching. |
| `record_fields_ordering` | Stylistic | INFO | Enforce consistent ordering of fields in record declarations. |

### 1.61 Code Quality Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_deprecated_usage` | Recommended | WARNING | Warn when using deprecated APIs, classes, or methods. |
| `avoid_high_cyclomatic_complexity` | Professional | WARNING | Warn when functions exceed a configurable cyclomatic complexity threshold. |
| ⭐ `avoid_ignoring_return_values` | Recommended | INFO | Warn when function return values are ignored (unless explicitly marked). |
| `avoid_importing_entrypoint_exports` | Professional | INFO | Avoid importing from files that re-export entry points. |
| ⭐ `avoid_missing_interpolation` | Recommended | WARNING | Detect string concatenation that should use interpolation. |
| `avoid_never_passed_parameters` | Professional | INFO | `[CROSS-FILE]` Detect function parameters that are never passed by any caller. |
| 🐙 [`avoid_never_passed_parameters`](https://github.com/saropa/saropa_lints/issues/8) | Professional | INFO | `[CROSS-FILE]` Detect function parameters that are never passed by any caller. |
| `avoid_suspicious_global_reference` | Professional | WARNING | Detect suspicious references to global state in methods. |
| `avoid_unused_local_variable` | Recommended | WARNING | Local variables that are declared but never used. |
| ⭐ `no_empty_block` | Recommended | WARNING | Empty blocks indicate missing implementation or dead code. |
| `tag_name` | Professional | INFO | Validate custom element tag names follow conventions. |
| `banned_usage` | Professional | WARNING | Configurable rule to ban specific APIs, classes, or patterns. |

### 1.62 Bloc/Cubit Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_cubits` | Stylistic | INFO | Prefer Bloc over Cubit for better event traceability. |
| `handle_bloc_event_subclasses` | Professional | INFO | Ensure all event subclasses are handled in event handlers. |
| `prefer_bloc_extensions` | Professional | INFO | Use Bloc extension methods for cleaner code. |

#### Riverpod Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Provider Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### GetX Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Flutter Hooks Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_misused_hooks` | Essential | WARNING | Detect common hook misuse patterns. |
| ⭐ `prefer_use_callback` | Professional | INFO | Use useCallback for memoizing callback functions. |

#### Flame Engine Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

#### Intl/Localization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_missing_tr` | Essential | WARNING | Detect strings that should be translated but aren't. |
| `avoid_missing_tr_on_strings` | Essential | WARNING | User-visible strings should use translation methods. |

#### Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_missing_controller` | Essential | WARNING | Widgets with controllers should have controllers provided. |
| `avoid_missing_test_files` | Professional | INFO | `[CROSS-FILE]` Source files should have corresponding test files. |
| ⭐ `avoid_misused_test_matchers` | Recommended | WARNING | Detect incorrect usage of test matchers. |
| `format_test_name` | Stylistic | INFO | Test names should follow a consistent format. |
| `prefer_custom_finder_over_find` | Professional | INFO | Use custom finders for better test readability and maintenance. |

#### Patrol Testing Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_custom_finder_over_find` | Professional | INFO | Use Patrol's custom finders for clearer integration tests. |

#### Pubspec Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `add_resolution_workspace` | Professional | INFO | Add resolution workspace for monorepo dependency management. |
| `avoid_any_version` | Essential | WARNING | Avoid `any` version constraint - specify version ranges. |
| `avoid_dependency_overrides` | Recommended | WARNING | dependency_overrides should only be used temporarily. |
| `dependencies_ordering` | Stylistic | INFO | Dependencies should be sorted alphabetically. |
| `newline_before_pubspec_entry` | Stylistic | INFO | Add blank lines between major pubspec sections. |
| `prefer_caret_version_syntax` | Stylistic | INFO | Use `^1.0.0` caret syntax for version constraints. |
| `prefer_commenting_pubspec_ignores` | Professional | INFO | Document why pubspec rules are ignored. |
| `prefer_correct_package_name` | Essential | ERROR | Package name must follow Dart naming conventions. |
| `prefer_correct_screenshots` | Professional | INFO | Screenshots in pubspec should have valid paths and descriptions. |
| `prefer_correct_topics` | Professional | INFO | Topics should be valid pub.dev topics. |
| `prefer_pinned_version_syntax` | Professional | INFO | Pin exact versions for production stability. |
| `prefer_publish_to_none` | Recommended | INFO | Private packages should have `publish_to: none`. |
| `prefer_semver_version` | Essential | WARNING | Version should follow semantic versioning (major.minor.patch). |
| `pubspec_ordering` | Stylistic | INFO | Pubspec fields should follow recommended ordering. |

#### Widget/Flutter Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_collection_mutating_methods` | Professional | WARNING | Avoid methods that mutate collections in place. |
| `avoid_missing_controller` | Essential | WARNING | Widgets requiring controllers should have them provided. |
| `avoid_unnecessary_null_aware_elements` | Recommended | INFO | Null-aware elements in collections that can't be null. |
| ⭐ `prefer_spacing` | Recommended | INFO | Use Spacing widget (or SizedBox) for consistent spacing. |
| `use_closest_build_context` | Professional | INFO | Use the closest available BuildContext for better performance. |

---

## Part 2: Tier Assignments

### Tier 1: Essential

Critical rules that prevent crashes, data loss, and security holes.

### Tier 2: Recommended

Essential + common mistakes, performance basics, accessibility basics.

### Tier 3: Professional

Recommended + architecture, testing, maintainability.

### Tier 4: Comprehensive

Professional + documentation, style, edge cases.

### Tier 5: Insanity

Everything. For the truly obsessive.

### Stylistic / Opinionated Rules (No Tier)

These rules are **not included in any tier** by default. They represent team preferences where there is no objectively "correct" answer. Teams explicitly enable them based on their coding conventions.

> **See [README_STYLISTIC.md](https://github.com/saropa/saropa_lints/blob/main/README_STYLISTIC.md)** for full documentation on implemented stylistic rules.

**Planned:**

| Rule Name | Description |
|-----------|-------------|
| `prefer_grouped_related_statements` | Prefer grouping related statements for readability. |
| `prefer_ungrouped_statements` | Prefer ungrouped statements for certain logic flows. |
| `prefer_blank_line_between_members` | Blank line between class members. |
| `prefer_compact_members` | Compact class member declarations. |
| `prefer_named_constructor_parameters` | Prefer named parameters in constructors for clarity. |
| `prefer_positional_constructor_parameters` | Prefer positional parameters in constructors for brevity. |
| `prefer_explicit_parameter_assignment` | Prefer explicit parameter assignment in constructors. |
| `prefer_const_constructor_declarations` | Prefer declaring constructors as const when possible. |
| `prefer_non_const_constructors` | Prefer non-const constructors when mutation is required. |
| `prefer_factory_constructor` | Prefer factory constructors for object creation patterns. |

### Miscellaneous Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_bool_in_widget_constructors` | Planned | INFO | Avoid using bools in widget constructors; prefer enums for clarity. |
| `avoid_cascades` | Planned | INFO | Discourage use of cascade (..) for clarity and maintainability. |
| `avoid_classes_with_only_static_members` | Planned | INFO | Avoid classes with only static members; use top-level functions or variables. |
| `avoid_double_and_int_checks` | Planned | INFO | Avoid type checks for double/int; use num or generic constraints. |
| `avoid_dynamic_calls` | Planned | INFO | Avoid dynamic calls; prefer static typing for safety. |
| `avoid_equals_and_hash_code_on_mutable_classes` | Planned | INFO | Avoid overriding equals/hashCode on mutable classes. |
| `avoid_escaping_inner_quotes` | Planned | INFO | Prefer consistent quote usage to avoid escaping. |
| `avoid_field_initializers_in_const_classes` | Planned | INFO | Avoid field initializers in const classes; use constructor initializers. |
| `avoid_function_literals_in_foreach_calls` | Planned | INFO | Prefer method references over function literals in forEach. |
| `avoid_implementing_value_types` | Planned | INFO | Avoid implementing value types; use composition instead. |
| `avoid_js_rounded_ints` | Planned | INFO | Avoid relying on JS number rounding for ints. |
| `avoid_null_checks_in_equality_operators` | Planned | INFO | Avoid null checks in == operator; use identical or null-aware logic. |
| `avoid_positional_boolean_parameters` | Planned | INFO | Avoid positional boolean parameters; use named or enums. |
| `avoid_private_typedef_functions` | Planned | INFO | Avoid private typedef functions; prefer public for clarity. |
| `avoid_redundant_argument_values` | Planned | INFO | Avoid redundant argument values; use defaults. |
| `avoid_redundant_await` | Planned | INFO | Avoid redundant await; return the future directly. |
| `avoid_returning_null_for_future` | Planned | INFO | Avoid returning null for Future; return Future.value(). |
| `avoid_returning_null_for_void` | Planned | INFO | Avoid returning null for void; just return. |
| `avoid_returning_this` | Planned | INFO | Avoid returning this from methods; prefer fluent interfaces. |
| `avoid_setters_without_getters` | Planned | INFO | Avoid setters without corresponding getters. |
| `avoid_shadowing_type_parameters` | Planned | INFO | Avoid shadowing type parameters in generics. |
| `avoid_single_cascade_in_expression_statements` | Planned | INFO | Avoid single cascade in expression statements; use direct call. |
| `avoid_types_on_closure_parameters` | Planned | INFO | Avoid explicit types on closure parameters when unnecessary. |
| `avoid_unnecessary_containers` | Planned | INFO | Avoid unnecessary Container widgets in Flutter. |
| `avoid_unused_constructor_parameters` | Planned | INFO | Avoid unused constructor parameters; remove or use them. |
| `avoid_void_async` | Planned | INFO | Avoid async functions that return void. |
| `prefer_asserts_in_initializer_lists` | Planned | INFO | Prefer asserts in initializer lists for constructors. |
| `prefer_const_constructors_in_immutables` | Planned | INFO | Prefer const constructors in immutable classes. |
| `prefer_const_declarations` | Planned | INFO | Prefer const declarations where possible. |
| `prefer_const_literals_to_create_immutables` | Planned | INFO | Prefer const literals to create immutable collections. |
| `prefer_constructors_over_static_methods` | Planned | INFO | Prefer constructors over static factory methods. |
| `prefer_expression_function_bodies` | Planned | INFO | Prefer expression function bodies for simple functions. |
| `prefer_final_fields` | Planned | INFO | Prefer final fields for immutability. |
| `prefer_final_locals` | Planned | INFO | Prefer final for local variables. |
| `prefer_foreach` | Planned | INFO | Prefer forEach over for-in for readability. |
| `prefer_if_elements_to_conditional_expressions` | Planned | INFO | Prefer if elements in collections to conditional expressions. |
| `prefer_inlined_adds` | Planned | INFO | Prefer inlined adds in collection literals. |

| `fold` | Planned | INFO | (Stylistic) Use fold for collection reduction where appropriate. |
| `prefer_asmap_over_indexed_iteration` | Planned | INFO | Prefer asMap().entries for indexed iteration over manual index. |
| `prefer_cascade_assignments` | Planned | INFO | Prefer using cascade (..) for assignments to the same object. |
| `prefer_const_constructor_declarations` | Planned | INFO | Prefer declaring constructors as const when possible. |
| `prefer_constructor_over_literals` | Planned | INFO | Prefer List()/Map() constructors over literals in certain contexts. |
| `prefer_explicit_null_checks` | Planned | INFO | Prefer explicit null checks for clarity. |
| `prefer_explicit_parameter_assignment` | Planned | INFO | Prefer explicit parameter assignment in constructors. |
| `prefer_factory_constructor` | Planned | INFO | Prefer factory constructors for object creation patterns. |
| `prefer_fire_and_forget` | Planned | INFO | Prefer fire-and-forget async calls where result is not needed. |
| `prefer_fold_over_reduce` | Planned | INFO | Prefer fold over reduce for collections when initial value is needed. |
| `prefer_foreach_over_map_entries` | Planned | INFO | Prefer forEach for map iteration over map.entries. |
| `prefer_grouped_related_statements` | Planned | INFO | Prefer grouping related statements for readability. |
| `prefer_if_else_over_guards` | Planned | INFO | Prefer if-else over guard clauses for certain logic. |
| `prefer_named_constructor_parameters` | Planned | INFO | Prefer named parameters in constructors for clarity. |
| `prefer_non_const_constructors` | Planned | INFO | Prefer non-const constructors when mutation is required. |
| `prefer_null_aware_method_calls` | Planned | INFO | Prefer null-aware method calls (?.) for nullable objects. |
| `prefer_positional_constructor_parameters` | Planned | INFO | Prefer positional parameters in constructors for brevity. |
| `prefer_separate_assignments` | Planned | INFO | Prefer separate assignments over chained or compound assignments. |
| `prefer_then_catcherror` | Planned | INFO | Prefer then().catchError() over try/catch for async error handling. |
| `prefer_ungrouped_statements` | Planned | INFO | Prefer ungrouped statements for certain logic flows. |

#### Import & File Organization

| Rule Name | Description |
|-----------|-------------|
| `prefer_sorted_imports` | Alphabetically sort imports within groups |
| `prefer_import_groups` | Group imports: dart, package, relative (with blank lines) |
| `prefer_deferred_imports` | Use deferred imports for large libraries |
| `prefer_show_hide` | Explicit `show`/`hide` on imports |
| `prefer_part_over_import` | Use `part`/`part of` for tightly coupled files |
| `prefer_import_over_part` | Use imports instead of `part`/`part of` |

#### Naming Conventions

| Rule Name | Description |
|-----------|-------------|
| `prefer_lowercase_constants` | Constants in `lowerCamelCase` (Dart style guide) |
| `prefer_verb_method_names` | Methods start with verbs (`get`, `set`, `fetch`, `compute`) |
| `prefer_noun_class_names` | Class names are nouns or noun phrases |
| `prefer_adjective_bool_getters` | Boolean getters as adjectives (`isEmpty` vs `getIsEmpty`) |
| `prefer_i_prefix_interfaces` | Interface classes use `I` prefix (`IRepository`) |
| `prefer_no_i_prefix_interfaces` | Interface classes without `I` prefix |
| `prefer_impl_suffix` | Implementation classes use `Impl` suffix |
| `prefer_base_prefix` | Base classes use `Base` prefix |
| `prefer_mixin_prefix` | Mixins use `Mixin` suffix or no suffix |
| `prefer_extension_suffix` | Extensions use `Extension` or `X` suffix |

#### Member Ordering

| Rule Name | Description |
|-----------|-------------|
| `prefer_constructors_first` | Constructors before other members |
| `prefer_getters_before_setters` | Getters immediately before their setters |
| `prefer_static_before_instance` | Static members before instance members |
| `prefer_factory_before_named` | Factory constructors before named constructors |
| `prefer_overrides_last` | `@override` methods at bottom of class |

#### Comments & Documentation

| Rule Name | Description |
|-----------|-------------|
| `prefer_no_commented_code` | Disallow commented-out code blocks |
| `prefer_inline_comments_sparingly` | Limit inline comments; prefer self-documenting code |

#### String Preferences

| Rule Name | Description |
|-----------|-------------|
| `prefer_raw_strings` | Raw strings `r'...'` when escapes are heavy |
| `prefer_adjacent_strings` | Adjacent strings over `+` concatenation |
| `prefer_interpolation_to_compose` | String interpolation `${}` over concatenation |

#### Function & Method Style

| Rule Name | Description |
|-----------|-------------|
| `prefer_function_over_static_method` | Top-level functions over static methods |
| `prefer_static_method_over_function` | Static methods over top-level functions |
| `prefer_expression_body_getters` | Arrow `=>` for simple getters |
| `prefer_block_body_setters` | Block body `{}` for setters |
| `prefer_positional_bool_params` | Boolean parameters as positional |
| `prefer_named_bool_params` | Boolean parameters as named |
| `prefer_optional_positional_params` | `[optional]` over `{named}` |
| `prefer_optional_named_params` | `{named}` over `[positional]` |

#### Type & Class Style

| Rule Name | Description |
|-----------|-------------|
| `prefer_final_fields_always` | All instance fields should be `final` |
| `prefer_mixin_over_abstract` | Mixins over abstract classes when appropriate |
| `prefer_extension_over_utility_class` | Extension methods over static utility classes |
| `prefer_inline_function_types` | Inline function types over `typedef` |
| `prefer_sealed_classes` | Sealed classes for closed type hierarchies |

**Usage:**

```yaml
custom_lint:
  rules:
    - prefer_relative_imports: true
    - prefer_explicit_types: true
```

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

## Part 4: Modern Dart & Flutter Language Features

This section tracks new Dart/Flutter language features that developers should learn, and corresponding lint rules to help adopt them.

### 4.1 Dart Language Features

| Version | Date | Feature | Description | Lint Rule |
|---------|------|---------|-------------|-----------|
| 3.10 | Nov 2025 | Specific Deprecation Annotations | Finer-grained deprecation control | `use_specific_deprecation` |
| 3.9 | Aug 2025 | Improved Type Promotion | Null safety assumed for type promotion/reachability | `avoid_redundant_null_check` |
| 3.5 | Aug 2024 | Web Interop APIs (Stable) | `dart:js_interop` at 1.0 | `prefer_js_interop_over_dart_js` |
| 3.3 | Feb 2024 | Extension Types | Zero-cost wrappers for types | `prefer_extension_type_for_wrapper` |
| 3.0 | May 2023 | Records | Tuple-like data: `(String, int)` | `prefer_record_over_tuple_class` |
| 3.0 | May 2023 | Sealed Classes | Exhaustive type hierarchies | `prefer_sealed_for_state` |

**Not lintable:** Some Dart features are tooling/infrastructure changes:
- **Analyzer Plugin System** (3.10) — Official plugin architecture. Saropa Lints may migrate from custom_lint in future, but new system doesn't support assists yet. See [migration guide](https://leancode.co/blog/migrating-to-dart-analyzer-plugin-system).
- **JNIgen** (3.5) — Code generator for Java/Kotlin interop. Generates bindings, doesn't produce patterns needing lint rules.
- **Sound Null Safety Only** (3.9) — `--no-sound-null-safety` flag removed. No code patterns to lint.
- **Auto Trailing Commas** (3.8) — Formatter handles commas automatically.
- **Tall Style Formatter** (3.7) — New vertical formatting style.
- **Pub Workspaces** (3.6) — Monorepo support, tooling feature.

---

### 4.2 Flutter Widget Features

| Version | Date | Feature | Description | Lint Rule |
|---------|------|---------|-------------|-----------|
| 3.38 | Nov 2025 | OverlayPortal.overlayChildLayoutBuilder | Render overlays outside parent constraints | `prefer_overlay_portal_layout_builder` |
| 3.27 | Dec 2024 | Cupertino widget updates | CupertinoCheckbox, CupertinoRadio | Cupertino rules |

**Not lintable:** Some Flutter features cannot be detected through static analysis:
- **Impeller** (3.24-3.27) — Runtime rendering engine with no Dart code patterns to analyze
- **Swift Package Manager** (3.24) — Native iOS build tooling, outside Dart static analysis scope
- **WebAssembly support** (3.22) — Compilation target, not detectable code patterns

---

### 4.3 Modern Dart Rules Summary

#### High Priority (Widely Applicable)

| Rule Name | Tier | Description | Version |
|-----------|------|-------------|---------|

#### Medium Priority (Architecture/Design)

| Rule Name | Tier | Description | Version |
|-----------|------|-------------|---------|
| `prefer_sealed_for_state` | Professional | Use sealed classes for state | Dart 3.0 |
| `prefer_extension_type_for_wrapper` | Professional | Zero-cost wrappers | Dart 3.3 |
| `require_exhaustive_sealed_switch` | Essential | Exhaustive switches on sealed types | Dart 3.0 |

---

## Contributing

Want to help implement these rules? See [CONTRIBUTING.md](https://github.com/saropa/saropa_lints/blob/main/CONTRIBUTING.md) for guidelines.

Pick a rule from the list above and submit a PR!

---

## Sources

- **Dart 3.x Release Notes** — New language features by version
  https://dart.dev/guides/language/evolution

- **Flutter Release Notes** — Widget and framework changes
  https://docs.flutter.dev/release/release-notes

- **custom_lint Documentation** — Building custom lint rules
  https://pub.dev/packages/custom_lint

- **Dart Analyzer API** — AST visitor documentation
  https://pub.dev/documentation/analyzer/latest/

- **Riverpod Documentation** — State management patterns
  https://riverpod.dev/

- **Bloc Documentation** — Bloc pattern best practices
  https://bloclibrary.dev/

- **WCAG 2.1 Guidelines** — Accessibility success criteria
  https://www.w3.org/WAI/WCAG21/quickref/

- **OWASP Mobile Security** — Mobile application security testing
  https://owasp.org/www-project-mobile-security-testing-guide/

---

## Part 5: Package-Specific Rules (500 New Rules)

Based on research into the top 20 Flutter packages and their common gotchas, anti-patterns, and best practices.

### 5.1 Dio HTTP Client Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 5.2 go_router Navigation Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_go_router_deep_link_test` | Professional | INFO | `[CROSS-FILE]` Routes should be testable via deep link. Detect routes without deep link tests. |
| `prefer_go_router_builder` | Professional | INFO | Use go_router_builder for compile-time route safety. Detect hand-written route paths. |

### 5.3 Provider State Management Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_provider_circular_dependency` | Essential | ERROR | `[CROSS-FILE]` Circular provider dependencies cause stack overflow. Detect A watches B watches A patterns. |
| ⭐ `avoid_provider_listen_false_in_build` | Recommended | INFO | `listen: false` in build prevents rebuilds but may show stale data. Detect inappropriate usage. |
| `require_provider_update_should_notify` | Professional | INFO | ChangeNotifiers should implement efficient notifyListeners. Detect notifying on every setter. |

### 5.4 Riverpod Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_riverpod_circular_provider` | Essential | ERROR | `[CROSS-FILE]` Circular provider dependencies crash. Detect provider A reading provider B reading A. |
| `require_riverpod_test_override` | Professional | INFO | `[CROSS-FILE]` Tests should override providers. Detect ProviderContainer without overrides in tests. |
| `require_riverpod_lint_package` | Recommended | INFO | Install riverpod_lint for official linting. Detect Riverpod usage without riverpod_lint dependency. |
| `avoid_riverpod_string_provider_name` | Professional | INFO | Provider.name should be auto-generated. Detect manual name strings in providers. |
| `prefer_riverpod_code_gen` | Professional | INFO | Use @riverpod annotation for type-safe providers. Detect hand-written provider declarations. |
| `prefer_riverpod_keep_alive` | Professional | INFO | Long-lived state should use ref.keepAlive(). Detect state loss from auto-dispose. |

### 5.5 Bloc/Cubit Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_bloc_one_per_feature` | Professional | INFO | `[HEURISTIC]` Each feature should have its own Bloc. Detect single Bloc handling unrelated events. |
| `avoid_behavior_subject_last_value` | Professional | WARNING | BehaviorSubject retains value after close. Use PublishSubject when appropriate. |

### 5.6 GetX Anti-Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_getx_for_everything` | Professional | INFO | `[HEURISTIC]` GetX shouldn't be used for all patterns. Detect project over-reliance on GetX. |
| `prefer_getx_builder_over_obx` | Recommended | INFO | GetBuilder is more explicit than Obx for state. Detect mixed patterns. |
| ⭐ `avoid_getx_static_get` | Professional | WARNING | Get.find() is hard to test. Prefer constructor injection. Detect Get.find in methods. |
| `avoid_getx_rx_nested_obs` | Professional | WARNING | Nested .obs creates complex reactive trees. Detect Rx<List<Rx<Type>>>. |
| `avoid_getx_build_context_bypass` | Essential | ERROR | Bypassing BuildContext hides Flutter fundamentals. Detect excessive Get.context usage. |

### 5.7 Hive Database Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_hive_type_modification` | Professional | WARNING | Modifying Hive type fields breaks existing data. Detect field type changes. |
| `prefer_hive_compact` | Professional | INFO | Large boxes should be compacted periodically. Detect long-running box without compact. |
| ⭐ `avoid_hive_synchronous_in_ui` | Essential | WARNING | Hive operations can block UI. Use isolates for large operations. |
| `prefer_hive_web_aware` | Recommended | INFO | Hive web has different behavior. Detect Hive usage without web considerations. |

### 5.8 SharedPreferences Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_shared_prefs_large_data` | Professional | WARNING | SharedPreferences isn't for large data. Detect storing >1KB values. |
| `avoid_shared_prefs_sync_race` | Professional | WARNING | Multiple writers can race. Detect concurrent SharedPreferences writes. |

### 5.9 sqflite Database Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_sqflite_index_for_queries` | Professional | INFO | Frequently queried columns need indexes. Detect slow queries without index. |
| `prefer_sqflite_encryption` | Professional | WARNING | Sensitive databases need encryption. Use sqlcipher_flutter_libs. |

### 5.10 cached_network_image Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_cached_image_device_pixel_ratio` | Professional | INFO | Consider devicePixelRatio for sizing. Detect fixed sizes without DPR. |
| `avoid_cached_image_web` | Recommended | WARNING | CachedNetworkImage lacks web caching. Detect web usage; suggest alternatives. |
| ⭐ `avoid_cached_image_unbounded_list` | Essential | WARNING | Image lists need bounded cache. Detect ListView with many CachedNetworkImages. |

### 5.11 image_picker Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `avoid_image_picker_quick_succession` | Professional | WARNING | Multiple rapid picks cause ALREADY_ACTIVE error. Detect pickImage without debounce. |

### 5.12 permission_handler Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `prefer_permission_request_in_context` | Professional | INFO | Request permissions when needed, not at startup. Detect all permissions in main(). |
| `avoid_permission_handler_null_safety | Essential | ERROR | Use null-safe permission_handler version. Detect outdated package version. |
| `require_permission_lifecycle_observer` | Professional | INFO | Re-check permissions on app resume. Detect missing WidgetsBindingObserver. |
| `prefer_permission_minimal_request` | Recommended | INFO | Request only needed permissions. Detect requesting unused permissions. |
| `avoid_permission_request_loop` | Professional | WARNING | Don't repeatedly request denied permission. Detect request in loop or retry. |

### 5.13 geolocator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_geolocator_background_without_config` | Essential | ERROR | `[CROSS-FILE]` Background location needs manifest/plist entries. Detect background usage without config. |
| `prefer_geolocator_coarse_location` | Recommended | INFO | ACCESS_COARSE_LOCATION for city-level. Detect fine permission for coarse needs. |

### 5.14 flutter_local_notifications Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_notification_icon_kept` | Essential | ERROR | `[CROSS-FILE]` ProGuard can remove notification icons. Check keep rules exist. |
| `avoid_notification_overload` | Recommended | WARNING | `[HEURISTIC]` Too many notifications annoy users. Detect high-frequency notification calls. |
| `prefer_notification_custom_sound | Professional | INFO | Important notifications may need custom sound. Document sound configuration. |

### 5.15 connectivity_plus Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_connectivity_equals_internet` | Essential | WARNING | Connectivity type doesn't mean internet access. Detect using status to skip network call. |
| `require_connectivity_timeout` | Essential | WARNING | Always set timeout on network requests. Connectivity status can be misleading. |
| `prefer_internet_connection_checker` | Professional | INFO | Use internet_connection_checker for actual internet verification. |
| `require_connectivity_resume_check` | Professional | INFO | Re-check connectivity when app resumes. Android 8+ stops background updates. |
| `avoid_connectivity_ui_decisions` | Professional | WARNING | Don't block UI based on connectivity alone. Detect conditional UI from connectivity. |
| `prefer_connectivity_debounce` | Professional | INFO | Debounce rapid connectivity changes. Detect status handler without debounce. |

### 5.16 url_launcher Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_url_launcher_sandbox_issues` | Professional | WARNING | Launched apps run in Flutter sandbox. Document back navigation issues. |

### 5.17 freezed/json_serializable Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_freezed_invalid_annotation_target` | Recommended | INFO | Disable invalid_annotation_target warning in analysis_options. |
| `prefer_freezed_union_types` | Professional | INFO | Use Freezed unions for sealed state. Detect manual sealed class hierarchies. |
| `avoid_freezed_any_map_issue` | Professional | WARNING | any_map in build.yaml not respected in .freezed.dart. Document workaround. |

### 5.18 equatable Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_equatable_nested_equality | Professional | WARNING | Nested Equatables should also be immutable. Detect mutable nested objects. |

### 5.19 http Package Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_ssl_pinning_sensitive` | Professional | WARNING | Sensitive APIs need certificate pinning. Detect auth endpoints without pinning. |
| `avoid_stack_trace_in_production` | Essential | WARNING | Don't show stack traces to users. Detect printStackTrace in error handlers. |
| `require_input_validation` | Essential | WARNING | Validate user input before sending. Detect raw input in API calls. |
| `require_content_type_validation` | Professional | INFO | Verify response Content-Type. Detect JSON parsing without content-type check. |
| `require_error_handling_graceful` | Essential | WARNING | Show friendly errors, not technical ones. Detect raw exception messages in UI. |

### 5.20 Animation Performance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_clip_during_animation` | Professional | WARNING | Pre-clip content before animating. Detect ClipRect in animated widget. |
| ⭐ `avoid_excessive_rebuilds_animation` | Essential | WARNING | Don't wrap entire screen in AnimatedBuilder. Detect large subtree in builder. |
| `avoid_multiple_animation_controllers` | Professional | WARNING | Multiple controllers on same widget conflict. Detect multiple controllers without coordination. |
| ⭐ `prefer_spring_animation` | Recommended | INFO | SpringSimulation feels more natural. Suggest for drag/fling gestures. |

### 5.21 Stream/StreamBuilder Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_stream_transformer` | Professional | INFO | Use transformers for complex operations. Detect manual stream manipulation. |
| `require_stream_cancel_on_error` | Professional | INFO | Consider cancelOnError for critical streams. Detect error-sensitive streams. |
| `prefer_rxdart_for_complex_streams` | Professional | INFO | RxDart provides better operators. Detect complex stream transformations. |

### 5.22 Future/Async Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_cancellable_operations` | Professional | INFO | Long operations should be cancellable. Detect Completer without cancel mechanism. |

### 5.23 Widget Lifecycle Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_expensive_did_change_dependencies` | Professional | WARNING | didChangeDependencies runs often. Detect heavy work in didChangeDependencies. |
| `prefer_deactivate_for_cleanup` | Professional | INFO | Use deactivate for removable cleanup. Detect dispose-only cleanup that could be in deactivate. |

### 5.24 Form/TextFormField Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_input_formatters` | Professional | INFO | Use inputFormatters for controlled input. Detect manual onChange filtering. |
| `avoid_form_validation_on_change` | Professional | WARNING | Validating every keystroke is expensive. Detect onChanged triggering validation. |
| `prefer_form_bloc_for_complex` | Professional | INFO | Complex forms benefit from FormBloc. Detect forms with >5 fields and conditionals. |
| `require_error_message_clarity` | Recommended | INFO | Error messages should explain fix. Detect generic "Invalid" messages. |

### 5.25 ListView/GridView Performance Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_const_list_items` | Professional | INFO | List items should be const when possible. Detect non-const static items. |
| `prefer_cache_extent` | Professional | INFO | Tune cacheExtent for performance. Detect default cacheExtent with issues. |
| `require_addAutomaticKeepAlives_off` | Professional | INFO | Disable for memory savings in long lists. Detect long list with default true. |
| `prefer_find_child_index_callback` | Professional | INFO | Use for custom child positioning. Detect custom index needs. |

### 5.26 Navigator Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_will_pop_scope | Professional | INFO | Handle back button appropriately. Detect navigation without back handling. |
| ⭐ `require_navigation_result_handling` | Professional | INFO | Handle pushed route's result. Detect push without await or then. |
| `prefer_named_routes_for_deep_links` | Professional | INFO | Named routes enable deep linking. Detect anonymous route construction. |

### 5.27 auto_route Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| ⭐ `require_auto_route_guard_resume` | Essential | WARNING | Call resolver.next(true) after guard condition met. Detect guard without resume. |
| `avoid_auto_route_context_navigation` | Professional | WARNING | Use router instead of context for nested navigation. Detect context.push in nested route. |
| `require_auto_route_page_suffix` | Stylistic | INFO | Page classes should have Page suffix. Detect @RoutePage without suffix. |
| `prefer_auto_route_path_params_simple` | Recommended | INFO | Path params should be simple types. Detect complex objects in path. |
| `require_auto_route_full_hierarchy` | Essential | WARNING | Navigate with full parent hierarchy. Detect child route without parent. |
| `prefer_auto_route_typed_args` | Professional | INFO | Use strongly typed route arguments. Detect dynamic args passing. |
| `avoid_auto_route_keep_history_misuse` | Professional | WARNING | Understand keepHistory: false behavior. Detect unintended stack modification. |
| `require_auto_route_deep_link_config` | Professional | INFO | Configure deep links properly. Detect routes without path configuration. |

### 5.28 Internationalization (intl) Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_l10n_yaml_config` | Recommended | INFO | Use l10n.yaml for configuration. Detect missing configuration file. |
| `require_rtl_support` | Professional | INFO | Support RTL layouts. Detect hardcoded left/right in layouts. |

### 5.29 Firebase Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_firestore_security_rules` | Essential | ERROR | `[CROSS-FILE]` Firestore needs security rules. Detect Firestore without rules file. |
| `avoid_firestore_admin_role_overuse` | Professional | WARNING | Limit admin roles. Detect excessive admin claims assignment. |
| `require_firebase_reauthentication` | Essential | WARNING | Sensitive operations need recent auth. Detect sensitive ops without reauthenticateWithCredential. |
| `require_firebase_email_enumeration_protection` | Professional | INFO | fetchSignInMethodsForEmail was removed. Detect usage in code. |
| `require_firebase_token_refresh` | Essential | WARNING | Handle token refresh on idTokenChanges. Detect missing refresh handler. |
| `avoid_firebase_user_data_in_auth` | Professional | WARNING | Auth claims limited to 1000 bytes. Detect large data in custom claims. |
| `require_firebase_offline_persistence` | Recommended | INFO | Configure Firestore offline persistence. Detect Firestore without persistence settings. |
| `require_firebase_composite_index` | Essential | ERROR | Compound queries need indexes. Detect complex queries without index. |
| `prefer_firebase_transaction_for_counters` | Professional | INFO | Use transactions for counters. Detect read-then-write pattern. |
| `require_firebase_app_check_production` | Professional | WARNING | Enable App Check for production. Detect production without App Check. |

### 5.30 WebView Security Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_webview_local_storage_access` | Professional | WARNING | Limit WebView local storage access. Detect unrestricted storage settings. |
| `require_webview_user_agent` | Professional | INFO | Set custom user agent for analytics. Detect default user agent. |
| `prefer_webview_sandbox` | Professional | INFO | Use sandbox attribute for iframes. Detect iframe without sandbox. |
| `avoid_webview_cors_issues` | Professional | WARNING | WebView has CORS limitations. Document CORS handling. |

### 5.31 Testing Best Practices Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_test_golden_threshold` | Professional | INFO | Set golden test threshold for CI differences. Detect default threshold. |
| 🐙 [`require_test_golden_threshold`](https://github.com/saropa/saropa_lints/issues/30) | Professional | INFO | Set golden test threshold for CI differences. Detect default threshold. |
| 🐙 [`require_test_coverage_threshold`](https://github.com/saropa/saropa_lints/issues/31) | Professional | INFO | Set minimum coverage threshold. Detect coverage below threshold. |

### 5.32 Dispose Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|

### 5.33 Memory Optimization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_large_object_in_state` | Professional | WARNING | Large objects in widget state cause memory issues. Detect >1MB objects in state. |
| `require_image_memory_cache_limit` | Professional | INFO | Set PaintingBinding.imageCache limits. Detect default unlimited cache. |
| `avoid_retaining_disposed_widgets` | Essential | ERROR | Don't store references to disposed widgets. Detect widget references in non-widget classes. |
| `prefer_weak_references` | Comprehensive | INFO | Use Expando for optional associations. Detect strong refs where weak would work. |
| `avoid_closure_capture_leaks` | Professional | WARNING | Closures can capture and retain objects. Detect closures capturing large objects. |
| `avoid_unbounded_collections` | Essential | WARNING | Collections without size limits cause OOM. Detect growing collections without limits. |
| `prefer_streams_over_polling` | Professional | INFO | Streams are more memory-efficient than polling. Detect Timer-based polling. |

### 5.34 Error Handling Best Practices Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_error_recovery` | Professional | INFO | Error handlers should enable recovery. Detect catch without user-recoverable action. |
| `prefer_result_type` | Professional | INFO | Use Result/Either types for expected failures. Detect try-catch for business logic. |
| `prefer_zone_error_handler` | Comprehensive | INFO | Use Zone for unhandled async errors. Detect async without zone handling. |

### 5.35 Platform-Specific Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_ios_info_plist_entries` | Essential | ERROR | `[CROSS-FILE]` iOS features need Info.plist entries. Detect feature without plist. |
| 🐙 [`require_ios_info_plist_entries`](https://github.com/saropa/saropa_lints/issues/35) | Essential | ERROR | `[CROSS-FILE]` iOS features need Info.plist entries. Detect feature without plist. |
| `avoid_platform_specific_imports` | Recommended | WARNING | Use conditional imports for platform code. Detect dart:io in web code. |
| `prefer_platform_widget_adaptive` | Recommended | INFO | Use platform-adaptive widgets. Detect Material widgets in iOS-only context. |
| `require_desktop_window_setup` | Professional | INFO | `[CROSS-FILE]` Desktop apps need window configuration. Detect desktop target without setup. |

### 5.36 API Response Handling Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_api_response_validation` | Professional | INFO | Validate API response structure. Detect direct field access without validation. |
| `require_api_version_handling` | Professional | INFO | Handle API version changes. Detect hardcoded response expectations. |

### 5.37 Build Context Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_context_read_not_watch | Professional | INFO | Use context.read in one-time operations. Detect context.watch in single-use callback. |
| `prefer_closest_context` | Professional | INFO | Use closest BuildContext for better performance. Detect distant context usage. |
| `require_context_in_build_descendants` | Professional | INFO | Use Builder for updated context. Detect context issue after widget creation. |
| ⭐ `avoid_context_dependency_in_callback` | Essential | WARNING | Callbacks may run with stale context. Detect Theme.of(context) in future callback. |

### 5.38 Code Organization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_feature_folders` | Professional | INFO | `[HEURISTIC]` Organize by feature, not type. Detect flat structure with many files. |
| `prefer_composition_over_inheritance` | Professional | INFO | Use composition for flexibility. Detect deep inheritance hierarchies. |
| `require_barrel_files` | Professional | INFO | Use barrel files for exports. Detect multiple individual imports. |
| `prefer_layer_separation` | Professional | INFO | `[CROSS-FILE]` Keep UI, business logic, data separate. Detect layer violations. |
| `require_interface_for_dependency` | Professional | INFO | Use interfaces for testability. Detect concrete class dependencies. |
| `avoid_util_class | Professional | INFO | `[HEURISTIC]` Util classes are code smells. Detect classes named Util/Helper. |
| `prefer_extension_methods` | Professional | INFO | Use extensions for type-specific utilities. Detect static methods that could be extensions. |
| `require_single_responsibility` | Professional | INFO | `[HEURISTIC]` Classes should have one responsibility. Detect mixed concerns. |

### 5.39 Caching Strategy Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_cache_invalidation` | Essential | WARNING | `[HEURISTIC]` Caches need invalidation strategy. Detect cache without clear/invalidate. |
| `prefer_lru_cache` | Professional | INFO | Use LRU for memory-bounded cache. Detect Map used as cache without eviction. |
| 🐙 [`require_cache_invalidation`](https://github.com/saropa/saropa_lints/issues/38) | Essential | WARNING | `[HEURISTIC]` Caches need invalidation strategy. Detect cache without clear/invalidate. |
| 🐙 [`require_cache_ttl`](https://github.com/saropa/saropa_lints/issues/39) | Recommended | WARNING | `[HEURISTIC]` Caches need TTL. Detect cache entry without expiration. |
| `avoid_over_caching` | Professional | WARNING | `[HEURISTIC]` Not everything needs caching. Detect excessive cache usage. |
| `prefer_stale_while_revalidate` | Professional | INFO | Show stale data while refreshing. Detect blocking refresh pattern. |
| `avoid_cache_stampede` | Professional | WARNING | Prevent thundering herd on cache miss. Detect cache without locking. |
| `prefer_disk_cache_for_persistence` | Professional | INFO | Use disk cache for persistence across sessions. Detect memory-only cache for persistent data. |

### 5.40 Debugging & Logging Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_log_levels` | Professional | INFO | Use log levels appropriately. Detect single log level usage. |
| `require_crash_reporting` | Professional | INFO | `[CROSS-FILE]` Production apps need crash reporting. Detect production without Crashlytics/Sentry. |
| 🐙 [`require_crash_reporting`](https://github.com/saropa/saropa_lints/issues/40) | Professional | INFO | `[CROSS-FILE]` Production apps need crash reporting. Detect production without Crashlytics/Sentry. |
| `avoid_excessive_logging` | Professional | WARNING | `[HEURISTIC]` Too much logging impacts performance. Detect high-frequency log calls. |
| `prefer_conditional_logging` | Professional | INFO | Expensive log message construction should be conditional. Detect expensive string in log. |
| `require_error_context_in_logs` | Professional | INFO | Errors need context for debugging. Detect error log without context. |
| `prefer_log_timestamp` | Professional | INFO | Include timestamps in logs. Detect logs without time information. |

### 5.41 Configuration & Environment Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_env_file_gitignore` | Essential | ERROR | `[CROSS-FILE]` .env files shouldn't be committed. Detect .env without gitignore entry. |
| 🐙 [`require_env_file_gitignore`](https://github.com/saropa/saropa_lints/issues/41) | Essential | ERROR | `[CROSS-FILE]` .env files shouldn't be committed. Detect .env without gitignore entry. |
| `prefer_flavor_configuration` | Professional | INFO | Use Flutter flavors for environments. Detect manual environment switching. |
| `avoid_string_env_parsing` | Recommended | WARNING | Parse environment strings properly. Detect raw String.fromEnvironment usage. |
| `prefer_compile_time_config` | Professional | INFO | Use const for compile-time config. Detect runtime config lookup for static values. |
| `require_config_validation` | Professional | INFO | Validate configuration on startup. Detect config usage without validation. |

### 5.42 Dependency Injection Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_injectable_package` | Professional | INFO | Use code generation for DI. Detect manual registration boilerplate. |
| `avoid_service_locator_abuse` | Professional | WARNING | `[HEURISTIC]` Don't use GetIt everywhere. Detect GetIt.I in business logic. |
| `require_di_module_separation` | Professional | INFO | Separate DI configuration into modules. Detect monolithic registration. |

### 5.43 Accessibility Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_text_scale_factor_awareness` | Essential | WARNING | UI should handle text scaling. Detect fixed-size text containers. |
| 🐙 [`require_text_scale_factor_awareness`](https://github.com/saropa/saropa_lints/issues/42) | Essential | WARNING | UI should handle text scaling. Detect fixed-size text containers. |
| 🐙 [`avoid_insufficient_contrast`](https://github.com/saropa/saropa_lints/issues/43) | Essential | WARNING | `[HEURISTIC]` Text needs sufficient contrast. Detect low contrast color combinations. |
| 🐙 [`require_focus_order`](https://github.com/saropa/saropa_lints/issues/44) | Professional | INFO | Ensure logical focus order. Detect FocusTraversalGroup misconfiguration. |
| 🐙 [`require_reduced_motion_support`](https://github.com/saropa/saropa_lints/issues/45) | Recommended | INFO | Check MediaQuery.disableAnimations. Detect animations without reduced motion check. |
| 🐙 [`prefer_readable_line_length`](https://github.com/saropa/saropa_lints/issues/46) | Professional | INFO | Lines shouldn't exceed ~80 characters. Detect wide text without constraints. |
| 🐙 [`require_heading_hierarchy`](https://github.com/saropa/saropa_lints/issues/47) | Professional | INFO | Use proper heading structure. Detect inconsistent heading levels. |

### 5.44 Auto-Dispose Pattern Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_automatic_dispose | Professional | INFO | Use packages with auto-dispose. Detect manual disposal patterns. |
| 🐙 [`prefer_automatic_dispose`](https://github.com/saropa/saropa_lints/issues/48) | Professional | INFO | Use packages with auto-dispose. Detect manual disposal patterns. |
| 🐙 [`require_subscription_composite`](https://github.com/saropa/saropa_lints/issues/49) | Professional | INFO | Group subscriptions for batch disposal. Detect multiple individual subscriptions. |
| 🐙 [`prefer_using_for_temp_resources`](https://github.com/saropa/saropa_lints/issues/50) | Recommended | INFO | Use using() extension for scoped resources. Detect try-finally for temp resources. |
| 🐙 [`require_resource_tracker`](https://github.com/saropa/saropa_lints/issues/51) | Comprehensive | INFO | Track resources for leak detection. Detect undisposed resources in debug mode. |
| 🐙 [`prefer_cancellation_token_pattern`](https://github.com/saropa/saropa_lints/issues/52) | Professional | INFO | Use CancelToken pattern for cancelable operations. Detect manual cancellation. |
| 🐙 [`require_dispose_verification_tests`](https://github.com/saropa/saropa_lints/issues/53) | Professional | INFO | Test dispose is called properly. Detect disposable without dispose test. |

### 5.46 Hot Reload Compatibility Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `require_init_state_idempotent` | Essential | WARNING | initState may run multiple times. Detect non-idempotent initialization. |

### 5.47 Package Version Rules

> **Design Note**: These rules require **pubspec.yaml analysis**, not Dart AST analysis. The `custom_lint` package is designed for Dart source code analysis. Implementing these rules requires one of:
> 1. A separate analyzer plugin that processes YAML files
> 2. A standalone CLI tool that checks pubspec.yaml
> 3. Integration with `dart pub` or custom pubspec parsing
>
> **External dependencies**:
> - `prefer_latest_stable` requires pub.dev API calls to check latest versions
> - `require_compatible_versions` needs a maintained database of known conflicts
> - `require_null_safe_packages` needs SDK constraint parsing

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `[PUBSPEC]` `require_compatible_versions` | Essential | ERROR | Check for incompatible package versions. Detect known version conflicts. |
| `[PUBSPEC]` `prefer_latest_stable` | Recommended | INFO | Use latest stable versions. Detect outdated packages. |
| `[PUBSPEC]` `avoid_deprecated_packages` | Essential | WARNING | Don't use deprecated packages. Detect known deprecated packages. |
| `[PUBSPEC]` `require_null_safe_packages` | Essential | ERROR | All packages should be null-safe. Detect pre-null-safety dependencies. |
| `[PUBSPEC]` `prefer_first_party_packages` | Recommended | INFO | Prefer official Flutter/Dart packages. Detect unofficial alternatives. |

### 5.48 Widget Composition Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `avoid_deep_nesting` | Professional | WARNING | Widgets shouldn't nest too deeply. Detect nesting >10 levels. |
| `prefer_extract_widget` | Professional | INFO | `[HEURISTIC]` Large build methods should be split. Detect build >100 lines. |
| `avoid_repeated_widget_creation` | Professional | WARNING | Cache widget references when possible. Detect identical widgets created in loop. |
| `prefer_builder_pattern` | Professional | INFO | Use Builder for context-dependent children. Detect context issues. |
| `prefer_sliver_for_mixed_scroll` | Professional | INFO | Use slivers for mixed scrollable content. Detect nested scrollables. |
| `prefer_flex_for_complex_layout` | Professional | INFO | Use Flex over Row/Column for dynamic axis. Detect conditional Row/Column. |
| `prefer_layout_builder_for_constraints` | Professional | INFO | Use LayoutBuilder for constraint-aware layout. Detect MediaQuery for widget sizing. |

### 5.49 Secure Storage Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_biometric_protection` | Professional | INFO | Use biometric protection for sensitive data. Detect authenticationRequired option. |
| `require_secure_key_generation` | Essential | ERROR | Encryption keys need secure generation. Detect hardcoded or predictable keys. |
| `avoid_secure_storage_in_background` | Professional | WARNING | Secure storage may fail in background. Detect background access without handling. |

### 5.50 Late Initialization Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_late_lazy_initialization` | Professional | INFO | Use late for expensive lazy initialization. Detect eager init of rarely-used fields. |
| `require_late_access_check` | Professional | WARNING | Check isInitialized before late access when uncertain. Detect late access without context guarantee. |

### 5.51 Isar Database Rules

<!-- Placeholder - Isar Database Rules is complete -->

### 5.52 Hive Advanced Rules

| Rule Name | Tier | Severity | Description |
|-----------|------|----------|-------------|
| `prefer_hive_compact_periodically` | Professional | INFO | Hive files grow without compaction. Call box.compact() after bulk deletes to reclaim space. |
| `avoid_hive_large_single_entry` | Professional | WARNING | Entries >1MB degrade performance. Split large data across multiple keys or use chunking. |
| `require_hive_web_subdirectory` | Essential | ERROR | Hive web needs explicit subDir in init. Detect Hive.initFlutter without subDir on web platform. |
| `avoid_hive_datetime_local` | Professional | WARNING | DateTime stored as-is loses timezone. Convert to UTC before storing, local after reading. |

---

## Part 5 Sources

- **DCM Blog: Common Flutter Mistakes** — 15 Common Mistakes in Flutter and Dart Development
  https://dcm.dev/blog/2025/03/24/fifteen-common-mistakes-flutter-dart-development

- **DCM Blog: Async Misuse** — The Hidden Cost of Async Misuse in Flutter
  https://dcm.dev/blog/2025/05/28/hidden-cost-async-misuse-flutter-fix

- **Riverpod Documentation** — Official Riverpod best practices
  https://riverpod.dev/docs/

- **Bloc Documentation** — Official Bloc library documentation
  https://bloclibrary.dev/

- **Dio Package** — HTTP client documentation
  https://pub.dev/packages/dio

- **go_router Package** — Navigation documentation
  https://pub.dev/packages/go_router

- **Flutter Firebase** — FlutterFire documentation
  https://firebase.flutter.dev/

- **permission_handler** — Permission handling best practices
  https://pub.dev/packages/permission_handler

- **flutter_secure_storage** — Secure storage documentation
  https://pub.dev/packages/flutter_secure_storage

- **cached_network_image** — Image caching documentation
  https://pub.dev/packages/cached_network_image

- **Isar Database** — Fast cross-platform NoSQL database documentation
  https://isar.dev/

- **Hive Database** — Lightweight key-value database documentation
  https://pub.dev/packages/hive

---

## Deferred & Complex Rules (Consolidated)

This section consolidates all rules that are deferred or marked as too complex for reliable AST detection. These rules are listed here for tracking purposes and should NOT be implemented until the underlying complexity is resolved.

### Why Rules Are Deferred

| Marker | Reason | Implementation Barrier |
|--------|--------|------------------------|
| `[HEURISTIC]` | Variable name or string pattern matching | High false-positive risk from matching non-target patterns |
| `[CONTEXT]` | Needs build/test context detection | Requires tracking widget lifecycle state |
| `[CROSS-FILE]` | Requires analysis across multiple files | Single-file AST analysis cannot detect these |
| `[TOO-COMPLEX]` | Pattern too abstract for reliable detection | No clear AST pattern exists |
| `DEFERRED` | Explicitly deferred for various reasons | See individual rule descriptions |

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

### Deferred: Heuristic Variable Name Detection

| Rule | Reason | Description |
|------|--------|-------------|
| `require_snackbar_duration_consideration` | HEURISTIC | "Important content" is subjective |

### Deferred: Cross-File Analysis Required

| Rule | Reason | Description |
|------|--------|-------------|
| `avoid_never_passed_parameters` | CROSS-FILE | Requires analyzing all call sites |
| `avoid_getit_unregistered_access` | CROSS-FILE | Registration may be in separate file |
| `require_temp_file_cleanup` | CROSS-FILE | Delete may be in separate function |
| `avoid_misused_hooks` | CONTEXT | Hook rules vary by context |
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
