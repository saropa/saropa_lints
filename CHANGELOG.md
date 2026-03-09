# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 5.0.3.

\*\* See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---

## [8.0.10]

Opt-in rule registration (breaking), quick fixes and `source.fixAll` tips for two rules, false-positive fixes for five rules, and a crash fix for `avoid_uncaught_future_errors` on Dart 3.11+.

### Added

- **Quick fix for `prefer_trailing_comma_always`:** Adds trailing comma via lightbulb/`source.fixAll`. Reuses existing `AddTrailingCommaFix`.
- **Quick fix for `prefer_type_over_var`:** Replaces `var` with the inferred explicit type via new `ReplaceVarWithTypeFix`.

### Changed

- **`prefer_trailing_comma_always` correction message:** Now mentions `source.fixAll` editor setting for automatic bulk fixes on save.
- **`prefer_type_over_var` correction message:** Replaced alarming "Verify the change works correctly with existing tests" text with `source.fixAll` tip, since the rule is purely cosmetic.

- **Opt-in rule registration (BREAKING):** Rules are now disabled by default. Only rules explicitly set to `true` in `diagnostics:` or with a severity override (ERROR/WARNING/INFO) are registered. No config = no rules fire (safe default). This eliminates the need for hundreds of `false` entries in `analysis_options.yaml`. Run `dart run saropa_lints:init` to regenerate your config — existing `true` entries continue to work. The init tool no longer generates disabled-rules sections, reducing YAML size by up to 85%.
- **Memory improvement:** Plugin registration now uses `getRulesFromRegistry()` to instantiate only enabled rules instead of all 2050+. Essential tier memory usage drops from ~4GB to ~500MB.

### Fixed

- **`prefer_no_commented_out_code` false positive on prose with parentheses and semicolons:** `_hasStrongCodeIndicators` treated bare `()` and `;` as unambiguous code, bypassing the prose guard on natural English like `Speed slider (0.25×–4×) is local to this tab;`. Refined to require function-call patterns (`\w(`) instead of bare parentheses, and removed the standalone semicolon check. Control-flow keyword + paren detection (`for (`, `if (`, etc.) preserves existing true-positive coverage.

- **`prefer_for_in` false positive on numeric counter loops (v5):** The rule now requires the loop's upper bound to be a `.length` property access before firing. Previously it flagged any `for (var i = 0; i < N; i++)` loop regardless of whether `N` was a collection length, an integer literal, or a plain variable. Numeric counter loops (e.g. `i < 12`, `i < count`) where there is no collection to for-in over are no longer flagged.

- **`avoid_uncaught_future_errors` crash on enum declarations (Dart 3.11+):** `_collectFunctionsWithTryCatch` accessed `.body` on declaration nodes, which throws `UnsupportedError` for `EnumDeclaration` in Dart SDK 3.11. This crashed the entire analyzer plugin (exit code 4), losing all diagnostics for all rules in all files. Fixed by switching all declaration types to use `.members` instead of `.body`, and added `ExtensionTypeDeclaration` support.

- **`prefer_sentence_case_comments` false positive on continuation lines (v6):** Multi-line `//` comment blocks are now recognized as a single logical unit. Continuation lines (where the previous `//` line does not end with `.`, `!`, or `?`) are skipped instead of being flagged for lowercase start. Previously every continuation line in a multi-line comment was a false positive. The relaxed variant (`prefer_sentence_case_comments_relaxed`) receives the same fix (v2).

- **`prefer_cascade_over_chained` false positive on independent actions (v2):** Two consecutive calls with different method names (e.g., `messenger.clearSnackBars(); messenger.showSnackBar(bar);`) are no longer flagged. Cascade is only suggested for batch patterns (same method repeated, e.g., `add`/`add`) or 3+ consecutive calls. The same fix is applied to `prefer_cascade_assignments`.

---

## [8.0.9]

New relaxed sentence-case variant, init wizard code examples, and false-positive fixes for six rules.

### Added

- **`prefer_sentence_case_comments_relaxed` (v1):** New relaxed variant of `prefer_sentence_case_comments` that only enforces sentence case on comments of 5+ words. Comments of 1-4 words are skipped as short annotations/labels. Enable one or the other, not both.

### Changed

- **Init wizard walkthrough:** All 223 stylistic rules now display GOOD/BAD code examples with multi-line support and inline comments. Previously 152 rules had no examples, making walkthrough questions unanswerable. Added `_logExample` helper for proper multi-line rendering and updated `_walkthroughConflicting` to show both GOOD and BAD examples (previously only showed GOOD).

### Fixed

- **`prefer_sentence_case_comments` false positive on short comments (v5):** Rule no longer flags 1-2 word comments (e.g., `// magnifyingGlass`, `// gear`). These are typically identifier annotations or short labels, not prose sentences. Also tightened code-reference detection to only skip camelCase/snake_case identifiers — previously it over-matched all lowercase words, silently suppressing most violations.
- **`prefer_blank_line_before_else` false positive on `else if` (v2):** Rule no longer flags `else if` chains. Only standalone `} else {` blocks are reported. Previously every `else if` in the project generated a false positive — inserting a blank line before `else if` is a Dart syntax error.
- **`prefer_switch_statement` false positives (v2):** No longer flags switch expressions in value-producing positions — arrow bodies (`=> switch (...)`), return statements, variable initializers, assignments, and yield statements are now exempt. Only fires when the switch expression is in a non-value position (e.g. nested in a collection literal or passed as a function argument).
- **`prefer_positive_conditions_first` false positive on null guards (v3):** Null-equality guard clauses (`if (x == null) return;`) are no longer flagged — `== null` is an equality check, not a negation. Rule now only fires on genuinely negated guards (`if (!condition) return;`). Problem message rewritten to accurately describe the narrower scope.
- **`prefer_doc_comments_over_regular` false positive on section headers (v6):** Section-header comments (text between divider lines like `// -----`) and comments separated from declarations by a blank line are no longer flagged. Divider lines (`// ----`, `// ====`, `// ****`) are now detected and skipped along with adjacent section-header text.
- **`prefer_descriptive_variable_names` false positive on short-lived variables (v4):** Added scope-size awareness — short names are now allowed in small blocks (<=5 statements) where context is immediately visible. Also skips C-style for-loop index variables and expands the allowed-names list with common conventions (`i`, `j`, `k`, `e`, `n`).

---

## [8.0.8]

Fix `prefer_single_blank_line_max` false positives by rewriting detection to scan actual line content.

### Fixed

- **`prefer_single_blank_line_max` false positives (v3):** Rewrote detection to scan actual line content instead of comparing top-level declaration positions. Comments, doc comments, and section separators between declarations no longer trigger false positives. Now detects consecutive blank lines everywhere in the file (function bodies, class members), not just between top-level declarations.

---

## [8.0.7]

Fix `prefer_readable_line_length` crash and publish script changelog parsing.

### Fixed

- **`prefer_readable_line_length` crash:** Fixed off-by-one error in `PreferReadableLineLengthRule` that caused `Invalid line number` exception when analyzing files. The loop used 1-based indexing but `LineInfo.getOffsetOfLine()` requires 0-based, crashing on the last line of every file.
- **Publish script changelog logic:** Fixed regexes in `_version_changelog.py` that expected `---\n##` but the actual format uses `---\n\n##` (blank line after separator). This caused `add_version_section` to silently append entries at the end of the file and `add_unreleased_section` to fail entirely. Recovered 8 orphaned changelog entries.

---

## [8.0.6]

Remove Flutter SDK constraint that broke CI and fix 56 unresolved dartdoc references.

### Fixed

- **Removed Flutter SDK constraint from pubspec.yaml** that caused CI publish workflow to fail (`dart pub get` requires only the Dart SDK; this is a pure Dart package).
- **Fixed 56 unresolved dartdoc reference warnings** across rule files.

---

## [8.0.5]

Publish workflow improvements with retry logic and SDK configuration.

### Changed

- **Updated publish workflow** with improved retry logic and SDK configuration.

---

## [8.0.4]

Publish script auto-bumps version on tag conflict; GitHub Actions workflow uses stable Dart SDK.

### Changed

- **Publish script and workflow:** GitHub Actions publish workflow now uses the Dart stable SDK (no exact-version lookup), adds a Verify Dart SDK step, and retries `dart pub get` once on failure. When the release tag already exists on the remote, the script auto-bumps the pubspec version and adds a "Release version" CHANGELOG section instead of failing. The script automatically commits and pushes `.github/workflows/publish.yml` when it has uncommitted changes, so no manual git steps are required.

---

## [8.0.3]

Version bump for pub.dev compatibility.

### Changed

- Version bump

---

## [8.0.2]

Version bump for pub.dev compatibility.

### Changed

- Version bump

---

## [8.0.1]

Fix `lowerCaseName` getter errors in tests and init tool.

### Fixed

- **Tests and init:** Resolve undefined getter `lowerCaseName` on `LintCode` by importing `saropa_lint_rule.dart` (which defines the `LintCodeLowerCase` extension) in test files and `bin/init.dart`.

### Notice

**8.0.0** is the current Flutter-compatible release (analyzer 9). The **7.x line was retracted** (it required analyzer 10, which Flutter does not yet support). Use **saropa_lints ^8.0.0** for new projects and upgrades.

---

## [8.0.0]

**Recommended upgrade from 6.2.x.** This release delivers all fixes and improvements that were in 7.0.0 and 7.0.1 while remaining compatible with **analyzer 9** and the current **Flutter framework**.

### Why v8 and not v7?

- **v7.0.0 and v7.0.1 were retracted.** Those releases upgraded to the analyzer 10.x API. The **Flutter framework does not yet support analyzer 10** (Flutter's own dependency tree pins analyzer 9). Publishing with `analyzer: ^10.0.0` made saropa_lints incompatible with Flutter projects, so 7.x was retracted from pub.dev.
- **v8.0.0** keeps the same rule set and all behavioral fixes from 7.x but stays on **analyzer 9.x**, so Flutter and Dart-only projects can upgrade without waiting for Flutter to adopt analyzer 10.

### Requirements

- **Dart SDK:** 3.6 or later (unchanged from 6.x).
- **Analyzer:** 9.x. Uses `analyzer: ^9.0.0`, `analysis_server_plugin: ^0.3.4`, `analyzer_plugin: ^0.13.0`.

### What's in 8.0.0 (from 7.x)

- All **Fixed** and **Changed** items from [7.0.1](#701) and [7.0.0](#700) (rule fixes, quick fixes, internal use of `lowerCaseName` where needed on analyzer 9, AST adjusted for analyzer 9 `ClassDeclaration.members` and mixin/extension bodies).
- No analyzer 10–only APIs: no `namePart`, no `BlockClassBody`, no dependency on analyzer 10.

### Upgrade

- From **6.2.x**: bump to `saropa_lints: ^8.0.0` and run `dart pub get`. No config or SDK change required if you are already on Dart 3.6+ and analyzer 9.
- If you had temporarily tried **7.x** before it was retracted: switch to **8.0.0** and keep your existing `analysis_options.yaml`; 8.0.0 does not require the analyzer 10 / lowerCaseName config migration that 7.x required.

---

## [7.0.3]

### Changed

- Version bump

---

## [7.0.2]

### Changed

- Version bump

---

## [7.0.1] *(retracted)*

*Retracted: required analyzer 10; Flutter does not yet support analyzer 10. Use [8.0.0](#800) instead.*

In this release we’re preparing bug fixes and small rule refinements.

### Fixed

- **avoid_renaming_representation_getters** — No longer reports when the representation is private and there is exactly one public getter that exposes it under a different name (e.g. `String get sql => _sql`). Resolves conflict with prefer_private_extension_type_field. See bugs/history/bug_extension_type_avoid_renaming_vs_prefer_private_conflict.md.

- **prefer_const_constructor_declarations** — No longer suggests const when: (1) any constructor parameter has a function type (callbacks cannot be const); (2) the class extends a superclass with no const constructor (e.g. ChangeNotifier); (3) the constructor initializer list or super arguments use non-const expressions (method calls, non-const constructor calls, binary/conditional). Resolves bug_prefer_const_constructor_declarations_callback_field, bug_prefer_const_constructor_declarations_change_notifier, bug_prefer_const_constructor_declarations_non_const_initializers.

- **prefer_safe_area_consumer** — No longer reports when the Scaffold has no `appBar` and no `bottomNavigationBar`. In that case the body extends under system UI and SafeArea is appropriate. Resolves bug_prefer_safe_area_consumer_scaffold_without_appbar.

- **require_api_response_validation** — No longer reports when the decoded value is validated by a subsequent type check (e.g. `if (decoded is! Map && decoded is! List) throw`) in the same block (validation-helper pattern). Resolves bug_require_api_response_validation_require_content_type_in_validator_impl.

- **require_content_type_validation** — No longer reports when a dominating content-type guard returns or throws (not only return) before `jsonDecode`, and when the guard is nested inside an outer if block. Resolves bug_require_api_response_validation_require_content_type_in_validator_impl.

- **prefer_webview_sandbox** — Internal: removed null assertion in controller root helper; handle nullable `PropertyAccess.target` to satisfy avoid_null_assertion.

---

## [7.0.0] *(retracted)*

*Retracted: required analyzer 10; Flutter framework does not yet support analyzer 10. Use [8.0.0](#800) instead.*

In this release we move to the analyzer 10.x API and Dart SDK 3.9+. Rule names now use lowerCaseName—see the migration guide for updating your config.

**Breaking: Analyzer 10 upgrade** — This release upgraded to the analyzer 10.x API. See [Upgrading to v7](doc/guides/upgrading_to_v7.md) for migration steps. **This version was retracted** because Flutter does not yet support analyzer 10.

### Requirements *(retracted release)*

- **Dart SDK:** 3.9 or later.
- **Analyzer:** 10.x only. **saropa_lints 6.2.2** was the last release compatible with analyzer &lt; v10 before retraction; **8.0.0** is the current release for analyzer 9.

### Breaking changes *(retracted release)*

- **Dependencies:** Required `analyzer: ^10.0.0`, `analysis_server_plugin: ^0.3.10`, and `analyzer_plugin: ^0.14.0`. Dropped support for analyzer 9.x.
- **Config keyed by lowerCaseName:** Rule identifiers and config keys would use the analyzer's **lowerCaseName**. Use `prefer_debugprint` instead of `prefer_debugPrint`. Update `analysis_options.yaml` and any `// ignore:` comments that reference rule names.
- **AST API:** All rule files were migrated to analyzer 10 `body` and `namePart` API (e.g. `(node.body as BlockClassBody).members`, `node.namePart.typeName`).
- **Init:** Running `dart run saropa_lints:init` on an existing v6 config would normalize rule names to lowerCaseName; pre-flight warned if Dart SDK &lt; 3.9 when using v7.

### Changed *(retracted release)*

- **Version:** 6.2.2 → 7.0.0 (major). Release was later retracted.
- **DiagnosticCode / LintCode:** All internal and test use of `code.name` replaced with `code.lowerCaseName`.
- **Tests:** Expect `rule.code.lowerCaseName` (e.g. `prefer_debugprint`) where rule identity is asserted.

### Fixed

- **require_api_response_validation** — No longer reports when the result of `jsonDecode` is only used as the argument to a `fromJson` call (inline `Type.fromJson(jsonDecode(...))` or variable only passed to `fromJson`). Resolves bug_require_api_response_validation_require_content_type_validation_flow.

- **require_content_type_validation** — No longer reports when a dominating content-type guard exists before `jsonDecode` in the same or outer block (e.g. early return when `contentType?.mimeType != 'application/json'`). Resolves bug_require_api_response_validation_require_content_type_validation_flow.

- **avoid_screenshot_sensitive** — No longer reports on debug/tooling screens: class names containing `debug`, `viewer`, `webview`, `devtool`, or `tooling` are excluded. When the only matched keyword is `settings`, classes whose name contains `fromsettings` (e.g. `_WebViewScreenFromSettings`) are excluded as navigation context. Resolves bug_avoid_screenshot_sensitive_debug_only_screens (debug-only DB viewer, saropa_drift_viewer).

- **prefer_safe_area_consumer** — No longer reports when `SafeArea(top: false, ...)` is used inside a Scaffold body. That pattern only applies bottom (and optionally left/right) insets, so there is no redundant top inset with the AppBar.

- **prefer_named_routes_for_deep_links** — No longer reports when `MaterialPageRoute` or `CupertinoPageRoute` use `settings: RouteSettings(name: ...)` with a non-empty name (literal or variable). Supports path-style names and `onGenerateRoute`-based deep linking. Still reports when there is no `settings`, when `RouteSettings` has no `name`, or when `name` is an empty string literal. Resolves bug_prefer_named_routes_for_deep_links_material_page_route_named.

- **prefer_webview_sandbox** — No longer reports when the controller passed to `WebViewWidget` (or `WebView`) is configured in the same file with `setNavigationDelegate(...)` and/or `setAllowFileAccess(false)` (e.g. in initState). Controller matching is by expression root (e.g. `_controller`, `controller`). Resolves bug_prefer_webview_sandbox_controller_configuration.

---

## [6.2.2]

This is a version bump for compatibility — the last release that supports analyzer < v10 before 7.0.0.

### Changed

- Version bump

---

## [6.2.1]

In this release we fix a few rules (use_existing_variable, require_debouncer_cancel, duplicate bool-param diagnostics), add rules for pagination error recovery and ignore-comment spacing, and ship 28+ new quick fixes. The publish script now runs tests in step 6 and loads analysis_options from the project root.

### Changed

- **Publish script (Step 6 & 7):** Step 6 (analysis) now runs `dart test --chain-stack-traces` after `dart analyze`, piping output to `reports/YYYYMMDD/YYYYMMDD_HHMMSS_chain_stack_traces.log` and checking for failure lines so test failures surface early. Step 7 on failure runs the same command (no retry prompt) and reports the log path and error lines. Shared `_dart_test_env()` for test temp dir; spinner shown during the test run.

### Added

- **require_pagination_error_recovery** — Recommended tier, INFO. Warns when a paginated list (ListView.builder/GridView.builder with loadMore/fetchMore/nextPage) has no visible error recovery in the enclosing scope (retry, onError, catch, hasError, isError, errorBuilder). Failed page loads need a retry option so users can recover. Resolves GitHub #22, #31.

### Fixed

- **require_field_dispose** — Now recognizes cascade notation for disposal (e.g. `_controller..removeListener(_fn)..dispose()`). Previously only matched `_controller.dispose()` on a single line. Resolves GitHub #76.

- **max_issues setting** — `analysis_options_custom.yaml` is now loaded from the project root when it is first known (from the first analyzed file), so `max_issues` and `output` take effect even when the plugin runs with cwd in a temporary directory. Resolves GitHub #92.

### Added (continued)

- **avoid_importing_entrypoint_exports** — Professional tier, INFO. Warns when a file imports from another file that re-exports the entry point (e.g. `main.dart`). Implemented by resolving import URIs to paths and checking the imported file for `export '...main.dart'`. Reduces unintended coupling to the app bootstrap.

- **require_ignore_comment_spacing** — Stylistic tier, INFO. Warns when `// ignore:` or `// ignore_for_file:` has no space after the colon (e.g. `// ignore:rule_name`). The analyzer expects a space so the directive can suppress the lint. Quick fix: add a space after the colon.

- **Quick fixes (Batches 12+):** Added 28+ quick fixes across 28 rules. No new lint rules or tier changes. Fixes include: `avoid_assigning_to_static_field` (DeleteStaticFieldAssignmentFix), `avoid_wildcard_cases_with_enums` / `avoid_wildcard_cases_with_sealed_classes` / `require_exhaustive_sealed_switch` (RemoveWildcardOrDefaultCaseFix), `avoid_duplicate_initializers` (DeleteDuplicateInitializerFix), `avoid_duplicate_patterns` (RemoveDuplicatePatternCaseFix), `avoid_throw_in_finally` (DeleteThrowInFinallyFix), `avoid_duplicate_cascades` (RemoveDuplicateCascadeSectionFix), `avoid_empty_build_when` (RemoveEmptyBuildWhenFix), `avoid_unnecessary_futures` (AvoidRedundantAsyncFix), `avoid_misused_set_literals` (AddSetOrMapTypeArgumentFix), `no_equal_nested_conditions` (FlattenRedundantNestedConditionFix), `avoid_unused_assignment` (RemoveUnusedAssignmentFix), `prefer_any_or_every` (ReplaceWhereIsEmptyWithAnyFix), `avoid_asset_manifest_json` (ReplaceAssetManifestJsonFix), `prefer_null_aware_spread` (SimplifyRedundantNullAwareSpreadFix, ReplaceConditionalSpreadWithNullAwareFix), `prefer_use_prefix` (AddUsePrefixFix), `avoid_passing_default_values` (RemoveDefaultValueArgumentFix), `prefer_enums_by_name` (ReplaceFirstWhereWithByNameFix), `prefer_test_matchers` (ReplaceExpectLengthEqualsZeroWithIsEmptyFix, ReplaceExpectContainsIsTrueWithContainsFix). `AvoidRedundantAsyncFix` now resolves body from function name token for `avoid_unnecessary_futures`. Fixed `replace_expect_contains_is_true_with_contains_fix` to avoid `dart:collection` (use `isEmpty`/`first`). See `bugs/QUICK_FIX_PLAN.md`.

- **Quick-fix presence tests:** Dedicated file `test/rule_quick_fix_presence_test.dart` with 100 unit tests asserting each listed rule has at least one quick fix (`fixGenerators` non-empty), plus one inverse test that a rule without fixes ([AvoidNonFinalExceptionClassFieldsRule]) has empty `fixGenerators`. Replaces duplicate rule entries with distinct rules (e.g. `AvoidEmptyBuildWhenRule`, `AvoidUnnecessaryFuturesRule`, `AvoidUnnecessaryNullableReturnTypeRule`, `AvoidThrowInCatchBlockRule`, `PreferPublicExceptionClassesRule`). Additional fix-presence assertions remain in code_quality_rules_test, complexity_rules_test, and structure_rules_test where relevant.

### Fixed

- **require_debouncer_cancel** — False positive when a `State` subclass (e.g. with `WidgetsBindingObserver` mixin) already had `_debounce?.cancel()` in `dispose()`. The rule now checks every `dispose` method in the class (not only the first) and uses both body source and full method source for cleanup detection, so cancel-in-dispose is reliably found. Added `isFieldCleanedUpInSource` in `target_matcher_utils.dart` and a regression fixture + tests.

- **Duplicate diagnostics (positional bool):** `prefer_named_bool_params` was removed from the stylistic tier so it is no longer enabled by default alongside `avoid_positional_boolean_parameters` (professional tier). Both rules report the same issue (positional boolean parameters) with the same fix (use a named parameter). Enabling both produced two diagnostics per parameter. Use `avoid_positional_boolean_parameters` from the professional tier, or enable `prefer_named_bool_params` explicitly if desired.

- **use_existing_variable** — No longer reports a duplicate when two variables share the same initializer **source** and that initializer uses `Random` or RNG-like APIs (e.g. `rng.nextDouble()`, `Random().nextInt(10)`). Each call yields a different value, so same-source initializers are not duplicates. The rule now explicitly detects `dart:math` Random constructors and instance methods (`nextDouble`, `nextInt`, `nextBool`, `next`) and common RNG receiver names (`rng`, `random`, `rand`, `rnd`), and excludes such initializers from duplicate detection in addition to the existing “contains any invocation” check.

### Added

  - `prefer_geolocation_coarse_location` — Now fully implemented (was stub). Warns when `Geolocator.getCurrentPosition` or `getPositionStream` use `LocationAccuracy.best` or `.high`; suggests `.low` or `.balanced` for battery and privacy. Config alias: `prefer_geolocator_coarse_location`.
  - `prefer_const_constructor_declarations` — Prefer declaring constructors as `const` when the class has only final fields (plain classes; @immutable and Widget subclasses remain covered by `prefer_const_constructors_in_immutables`). INFO, comprehensive tier.

---

## [6.2.0]

We focus on eating our own dog food: new rules for API validation, accessibility, performance, Hive, Riverpod, and more; more quick fixes; and a reorg of rules into subfolders while cleaning up this project’s own lint issues.

**Focus** — We clean up all lint issues in this project so we run the same rules we ship.

### Fixed

- **use_existing_variable** — No longer reports a duplicate when two variables share the same initializer **source** but the initializer contains a method or function invocation (e.g. `Random().nextDouble()`, `DateTime.now()`). Same source was incorrectly treated as same value; such expressions can produce different values at runtime. Initializers whose AST contains any `MethodInvocation` or `FunctionExpressionInvocation` are now excluded from duplicate detection.

- **prefer_correct_for_loop_increment comment exemption** — The rule’s correction message allowed “add a comment explaining why a non-standard increment step is necessary,” but the implementation did not check for comments. The rule now exempts a for loop when a comment on the same line or the line immediately above contains one of: step, increment, spacing, stride, non-standard, intentional (case-insensitive). Unrelated comments or comments two lines above do not exempt. Quick fix: “Add comment explaining non-standard increment” inserts a placeholder comment above the loop.

### Added

- **New stylistic rules (blank-line formatting):** `prefer_blank_line_before_else` — require a blank line before `else` / `else if` clauses. `prefer_blank_line_after_loop` — require a blank line after a for/while loop before the next statement. Both are INFO severity, stylistic tier, with quick fix (Add blank line). See [doc/guides/good_methods.md](doc/guides/good_methods.md).

- **History integration (Phase 2 issues, migration, not_viable/drift):** Integrated 21 `bugs/history` files. Migration guide moved to `doc/guides/migration_v4_to_v5.md` (v4→v5 custom_lint to native plugin); `doc/README.md` now links to it. Drift rules deemed not viable summarized in `bugs/not_viable_drift_rules.md`. Nine resolved-issue files and four migration files (including three Flutter deprecation candidates) and eight not_viable/drift files removed; checklist updated (since removed).

- **Quick fixes and tests:** `avoid_bloc_event_in_constructor` — fixtures and quick-fix tests (do not dispatch BLoC events in constructor). `prefer_const_widgets` — fixtures and quick-fix tests. `prefer_capitalized_comment_start`, `prefer_const_declarations`, `prefer_final_locals` — quick-fix tests and type fixtures with real BAD/GOOD. `avoid_redundant_pragma_inline`, `avoid_unused_parameters` — quick-fix tests. `avoid_weak_cryptographic_algorithms` — quick-fix tests and ReplaceWeakCryptoFix (replaces md5/sha1 with sha256). `avoid_unnecessary_getter` — RemoveUnnecessaryGetterFix. `no_empty_block` — AddNoEmptyBlockIgnoreFix (real fix). Fixtures and unit tests verify fixGenerators. See `bugs/QUICK_FIX_PLAN.md`. Batches 6–9 summary: `bugs/history/quick_fix_plan_batches_6_9_summary.md`.

- **Ten additional quick fixes (Batches 6–9):** `avoid_synchronous_file_io` — ReplaceSyncFileIoFix (sync → async method name). `avoid_constant_assert_conditions` — RemoveConstantAssertFix. `avoid_duplicate_switch_case_conditions` — RemoveDuplicateSwitchCaseFix. `avoid_redundant_else` — RemoveRedundantElseFix. `avoid_adjacent_strings` — CombineAdjacentStringsFix. `avoid_duplicate_map_keys` — RemoveDuplicateMapEntryFix. `avoid_unconditional_break` — RemoveUnconditionalBreakFix. `no_equal_then_else` — ReplaceWithThenBranchFix. `avoid_only_rethrow` — RemoveTryCatchOnlyRethrowFix. `avoid_returning_null_for_void` — ReplaceReturnNullWithReturnFix. Unit tests added for each fixGenerators; no new rules or tier changes.

- **Defensive coding and robustness:** Parameter validation, null/empty handling, and error handling across core utilities and baseline/config. No behavioral change for valid inputs. Covers: `normalizePath`, `BloomFilter`, `ProjectContext` (findProjectRoot, getPackageName, getProjectInfo, hasDependency), config loader, baseline config/manager/file/paths/date, banned usage config, `SaropaContext`/`SaropaFixProducer`, common fix bases (insert/replace/delete), comment/ignore utils, and plugin registration in `main.dart`. New unit tests in `test/defensive_coding_test.dart` (50 cases) for null/empty and edge cases.

- **New rules (INFO severity; professional or recommended tier):**
  - `prefer_semantics_sort` — Suggests sortKey on Semantics for correct screen reader order in complex layouts.
  - `prefer_sliver_for_mixed_scroll` — Suggests CustomScrollView with slivers when mixing scroll and non-scroll content.
  - `prefer_stale_while_revalidate` — Suggests stale-while-revalidate for cached API data.
  - `prefer_stream_transformer` — Suggests Stream.transform() for reusable stream pipelines.
  - `prefer_streams_over_polling` — Prefer Stream over Timer.periodic for reactive updates.
  - `prefer_using_for_temp_resources` — Use try-finally or ensure dispose for temporary files/resources.
  - `prefer_webview_sandbox` — Restrict WebView file access and JavaScript when not needed.
  - `prefer_whitelist_validation` — Prefer allowlist over blocklist for input validation.
  - `require_add_automatic_keep_alives_off` — Set addAutomaticKeepAlives: false on long lists to improve memory efficiency.
  - `require_api_response_validation` — Validate API response shape before use.
  - `require_api_version_handling` — Include API version in URL or headers.
  - `require_auto_route_deep_link_config` — Configure deep links for auto_route routes.
  - `require_backup_exclusion` — Exclude sensitive data from Android backup.
  - `require_cancellable_operations` — Support cancellation for long-running async operations.
  - `require_config_validation` — Validate config (null, range) after loading.
  - `require_connectivity_resume_check` — Re-check connectivity when app resumes.
  - `require_content_type_validation` — Check Content-Type before parsing response body.
  - `require_context_in_build_descendants` — Pass BuildContext or use Builder for descendants that need it.
  - `require_dispose_verification_tests` — Add tests that verify dispose is called on controllers/subscriptions.
  - `require_error_context_in_logs` — Include user/request id in error logs for debugging.
  - `prefer_hive_compact_periodically` — Call box.compact() after Hive bulk deletes to reclaim disk space.
  - `prefer_hive_compact` — Consider calling box.compact() periodically for large Hive boxes.
  - `prefer_hive_web_aware` — Consider web platform when using Hive (e.g. IndexedDB).
  - `prefer_injectable_package` — Prefer injectable package for code-generated GetIt DI.
  - `prefer_internet_connection_checker` — Use connectivity_plus or package to check internet (not just connectivity).
  - `prefer_json_codegen` — Prefer json_serializable/codegen for type-safe JSON.
  - `prefer_late_lazy_initialization` — Prefer late or lazy initialization when appropriate.
  - `prefer_log_levels` — Use log levels (debug, info, warning, error) consistently.
  - `prefer_log_timestamp` — Include timestamps in log output.
  - `prefer_lru_cache` — Prefer LRU cache for bounded caches.
  - `prefer_named_routes_for_deep_links` — Use named routes for deep linking.
  - `prefer_notification_custom_sound` — Prefer custom sound for local notifications when appropriate.
  - `prefer_overlay_portal_layout_builder` — Use OverlayPortal with LayoutBuilder for overlay positioning.
  - `prefer_permission_minimal_request` — Request only permissions needed at the time.
  - `prefer_platform_widget_adaptive` — Use platform-adaptive widgets (e.g. Cupertino/Material).
  - `prefer_readable_line_length` — Keep line length readable (e.g. wrap or break long lines).
  - `prefer_riverpod_code_gen` — Prefer @riverpod and riverpod_generator for type-safe providers.
  - `prefer_riverpod_keep_alive` — Use keepAlive for Riverpod providers that must outlive widget.
  - `prefer_root_detection` — Consider root/jailbreak detection for sensitive apps.
  - `prefer_rxdart_for_complex_streams` — Prefer rxdart for complex stream composition.
  - `require_error_message_clarity` — Use clear, user-facing error messages.
  - `require_error_recovery` — Provide recovery path (retry, fallback) when errors occur.
  - `require_firebase_email_enumeration_protection` — Use same generic message for invalid email and wrong password.
  - `require_firebase_offline_persistence` — Consider Firestore offline persistence (cacheSizeBytes).
  - `require_focus_order` — Set focusOrder for keyboard and screen reader navigation.
  - `require_getit_dispose_registration` — Call getIt.reset() in tearDown or on app shutdown.
  - `require_heading_hierarchy` — Use semantic heading levels (headerLevel 1–6) for screen readers.
  - `require_performance_test` — Consider performance tests for critical paths.
  - `require_image_memory_cache_limit` — Set image cache max size to avoid OOM.
  - `require_interface_for_dependency` — Depend on abstractions (interfaces), not concrete classes.
  - `require_json_date_format_consistency` — Use consistent date format (e.g. ISO 8601) in JSON.
  - `require_keychain_access` — Use Keychain (e.g. flutter_secure_storage) for sensitive data on iOS.
  - `require_permission_lifecycle_observer` — Re-check permissions when app resumes.
  - `require_provider_update_should_notify` — Call notifyListeners() when ChangeNotifier state changes.
  - `require_reduced_motion_support` — Respect MediaQuery.reducedMotion for animations.
  - `require_rtl_support` — Support RTL layouts for Arabic/Hebrew locales.
  - `require_sqflite_index_for_queries` — Add indexes for frequently queried columns.
  - `require_stream_cancel_on_error` — Cancel stream subscriptions on error to avoid leaks.
  - `require_webview_user_agent` — Set custom user agent on WebView when needed.
  - `require_will_pop_scope` — Use PopScope/WillPopScope to handle back button when needed.
  - `require_subscription_composite` — Combine multiple stream subscriptions for single cancel.
  - `use_closest_build_context` — Prefer closest BuildContext to avoid wrong scope.
  - `use_specific_deprecation` — Prefer @Deprecated with replacement and expiry.
  - `avoid_screenshot_in_ci` — Avoid screenshot tests in CI unless stable and fast.
  - `prefer_test_report` — Prefer test reporters (e.g. JSON) for CI.
  - `avoid_semantics_in_animation` — Avoid semantics that change during animation for screen readers.
  - `prefer_announce_for_changes` — Announce live region changes for screen readers.
  - `prefer_show_hide` — Prefer semantics show/hide for conditional content.
  - `require_link_distinction` — Make links distinguishable (e.g. underline, role).
  - `require_switch_control` — Support switch control / external input for key actions.
  - `prefer_deferred_imports` — Use deferred imports for large optional libraries.
  - `prefer_part_over_import` — Prefer part/part of for same-package splits.
  - `prefer_weak_references` — Prefer WeakReference for caches to avoid retaining objects.
  - `prefer_zone_error_handler` — Use runZonedGuarded for top-level errors.
  - `require_multi_factor` — Consider MFA for sensitive auth flows.
  - `prefer_isar_for_complex_queries` — Prefer Isar for complex local queries over raw SQL.
  - `prefer_external_keyboard` — Support external keyboard navigation and shortcuts.
  - `prefer_outlined_icons` — Prefer outlined icons for Material 3 style.
  - `prefer_js_interop_over_dart_js` — Prefer dart:js_interop (Dart 3.5) over deprecated dart:js / dart:js_util.

### Changed

- **Ignore handling:** Removed quick fix that inserted `// ignore: no_empty_block` (project policy: no fixes that add `// ignore:`). `no_empty_block` now uses `IgnoreUtils.isIgnoredForFile` and `IgnoreUtils.hasIgnoreComment` to respect existing ignore comments. Added Cursor rule `.cursor/rules/prohibit-ignore-comments.mdc` and CLAUDE.md guidance to prohibit adding ignore-inserting fixes.

- **Init wizard (stylistic walkthrough):** Replaced per-rule prompts (~193) with ruleset-based prompts (~13–14). One question per ruleset (e.g. Good methods, Ordering & sorting, Naming conventions) with label and description; warnings for noisy rulesets (Ordering, Naming, Formatting, Opinionated). Conflicting style choices gated behind a single “[y/N] Set these now?” prompt. “Other stylistic rules” covers any uncategorized stylistic rules and lists rule names when ≤25. `prefer_readable_line_length` added to Good methods ruleset. See `doc/guides/good_methods.md`.

### Removed

- **Insert-TODO quick fixes (additional):** Removed `WeakCryptoTodoFix` (avoid_weak_cryptographic_algorithms) and `NoEmptyBlockTodoFix` (no_empty_block); replaced with real fixes per project policy (CONTRIBUTING.md, QUICK_FIX_PLAN.md).

### Fixed

- **`prefer_platform_io_conditional`:** No longer reports in files that are the native branch of a conditional import (`if (dart.library.io)` or `if (dart.library.ffi)`). Such files are never loaded on web, so requiring a `kIsWeb` guard inside them was a false positive. Added `conditional_import_utils.dart` to detect native-only targets by scanning `lib/` for conditional import configurations; result cached per project.

- **`avoid_redirect_injection`:** No longer reports when the redirect-related argument is used in a block that indicates allowlist validation. The rule now skips when the enclosing block source contains the substrings `allowed` or `validated` (e.g. `_allowedExportDestinations`, `validatedDestination`), in addition to existing hints (`.host`, `.authority`, `allowlist`, `whitelist`, `trusted`). Fixes false positives where the value is metadata from a fixed set (e.g. `'clipboard'`, `'notes'`) rather than a redirect URL.

- **`require_deep_link_fallback`:** Reduced false positives and clarified scope. (1) Only methods whose body contains a navigation call (e.g. `Navigator`, `GoRouter`, `.go(`, `.push(`, `.goNamed(`, `.pushNamed(`, `.pushReplacement`, `getInitialLink`, `getInitialUri`) are reported; methods that only parse URIs or build link text (e.g. export/share helpers) are no longer flagged. (2) Fallback detection now recognizes `if (x != null)` guard before navigate. (3) Rule DartDoc documents "When we report" / "When we don't report" and a developer note on pattern-based detection. Fixture and tests updated.

- **`avoid_unawaited_future`:** No longer reports when the expression statement is explicitly wrapped in `unawaited(...)`. The rule previously checked `node.parent` (the enclosing block) instead of `node.expression`, so the skip never applied. It now returns early when the statement's expression is a `MethodInvocation` with method name `unawaited`, matching the rule's own correction message and Dart's recommended fire-and-forget pattern. Quick fix "Wrap in unawaited()" added.

- **`avoid_uncaught_future_errors`:** Expression statements that are exactly `unawaited(...);` are never reported. The rule now returns immediately when the statement's expression is a `MethodInvocation` with method name `unawaited`, independent of type resolution or chaining, so all code paths guarantee no report on intentional fire-and-forget. DartDoc and tests updated.

- **`require_database_close`:** No longer reports when the method body only references `openDatabase` (or similar) in string literals or name checks; only actual invocations (`openDatabase(`, `Database(`, `SqliteDatabase(`) are treated as opening a DB. Skips own rule files (`file_handling_rules.dart`, `sqflite_rules.dart`).

- **avoid_high_cyclomatic_complexity and copyWith:** The rule no longer reports methods or functions named `copyWith`. These implement the standard Dart immutable-update pattern; their apparent complexity is mechanical (one null-coalescing branch per parameter), not logical.

- **Duplicate rules (positional boolean parameters):** `avoid_positional_boolean_parameters` and `prefer_named_bool_params` reported the same issue and produced two diagnostics per positional bool. Removed `prefer_named_bool_params` from the default tier so only `avoid_positional_boolean_parameters` runs by default. The rule implementation remains available for consumers who opt in.

### Maintenance

- **Rules layout:** Reorganized `lib/src/rules/` into subfolders to reduce root file count. Category rule files now live under `architecture/`, `code_quality/`, `codegen/`, `commerce/`, `config/`, `core/`, `data/`, `flow/`, `hardware/`, `media/`, `network/`, `resources/`, `security/`, `stylistic/`, `testing/`, `ui/`, and `widget/`. `packages/` and `platforms/` unchanged. Barrel export in `all_rules.dart` and `CODEBASE_INDEX.md` updated. No rule logic or tier changes.

### Documentation

- **History integration (false_positives 37–61):** Integrated 25 bugs/history false_positive files into documentation and tests. Rules/history covered: `avoid_path_traversal` (private helper receiving platform path), `avoid_positioned_outside_stack` (builder callbacks, AssignmentExpression/build root), `avoid_ref_in_build_body` (callbacks inside build), `avoid_ref_watch_outside_build` (Riverpod provider bodies), `avoid_similar_names` (short names, time units), `avoid_single_child_column_row` (IfElement/ForElement), `avoid_static_state` (cached RegExp/immutable static), `avoid_stream_subscription_in_field` (listen as argument to collection.add), `avoid_string_concatenation_l10n` (numeric-only interpolation), `avoid_unbounded_listview_in_column` (overlay callbacks), `avoid_unmarked_public_class` (static utility classes with private constructors), `avoid_unnecessary_nullable_return_type` (conditional null branches, expression bodies, map operator, nullable delegation), `avoid_unnecessary_setstate` (closure callbacks), `avoid_unnecessary_to_list` / `avoid_large_list_copy` (required by return type), `avoid_unused_assignment` (conditional reassignment, definite assignment if/else, loop reassignment), `avoid_url_launcher_simulator_tests` (no launcher usage), `avoid_variable_shadowing` (non-overlapping loop scopes), `check_mounted_after_async` (guard clause, early-return). Fixes already in rule implementations and CHANGELOG_ARCHIVE; added FP test groups and checklist marks. Checklist since removed.

- **History integration (false_positives 62–86):** Integrated 25 bugs/history false_positive files. Rules/history covered: `comment_and_type_arg` (prefer_explicit_type_arguments, prefer_no_commented_out_code fixes), `discussion_062` (false positive reduction audit completed), `false_positives_kykto` (multi-rule), `function_always_returns_null` (async*/sync* generators), `multiple_false_positives_in_utility_library_context` (6 rules in utility lib), `no_empty_string` (standard Dart idiom), `no_equal_conditions` (if-case pattern matching), `no_magic_number` (named default parameters), `prefer_cached_getter` (extension getters), `prefer_compute_for_heavy_work` (pure Dart library), `prefer_const_widgets_in_lists` (non-Widget lists, implicitly const), `prefer_digit_separators` (small numbers, code points), `prefer_edgeinsets_symmetric` (unpaired sides), `prefer_implicit_boolean_comparison` (nullable bool), `prefer_keep_alive` (naive Tab string match), `prefer_list_first` (sibling index access), `prefer_match_file_name` (matching class name), `prefer_named_boolean_parameters` (lambda parameters), `prefer_no_commented_out_code` (prose comments), `prefer_prefixed_global_constants` (Dart lowerCamelCase), `prefer_secure_random` (non-security shuffling), `prefer_setup_teardown` (expect as setup), `prefer_static_method` (extension methods), `prefer_stream_distinct` (void/periodic streams). Fixes in rule implementations and CHANGELOG_ARCHIVE; added FP test groups and checklist marks. Checklist since removed.

- **History integration (false_positives 87–105, rule_bugs 1–7):** Integrated 25 bugs/history files. False_positives: `prefer_switch_expression` (complex case logic), `prefer_trailing_comma_always` (callback arguments), `prefer_unique_test_names` (group scoping), `prefer_wheretype_over_where_is` (negated type check), `require_currency_code_with_amount` (non-monetary totals), `require_dispose_pattern` (borrowed references), `require_envied_obfuscation` (class-level when fields obfuscated), `require_error_case_tests` (defensive source), `require_file_path_sanitization` (private helper platform path), `require_hero_tag_uniqueness` (cross-route pairs), `require_https_only_test` (URL utility tests), `require_intl_currency_format` (dollar interpolation), `require_ios_callkit` (substring/whole-word Agora), `require_list_preallocate` (unknowable size), `require_location_timeout` (permission checks), `require_number_format_locale` (device locale), `string_contains_false_positive_audit`. Rule_bugs: `avoid_empty_setstate` (severity, tier), `avoid_expanded_outside_flex` (documentation), `avoid_large_list_copy` (overly generic), `avoid_long_parameter_list` (ignore not respected), `conflicting_rules` (prefer_static_class vs prefer_abstract_final_static_class), `dartdoc_references_nonexistent_parameter`. Fixes in rule implementations and CHANGELOG_ARCHIVE; added FP test groups and checklist marks. Checklist since removed.

- **History integration (rule_bugs 8–22):** Integrated 15 bugs/history rule_bug files. Covered: `detect_unsorted_imports` (resolved — prefer_sorted_imports, prefer_import_group_comments), `duplicate_rules_async_without_await` (avoid_redundant_async vs prefer_async_only_when_awaiting), `function_always_returns_null_generator_guard_ineffective` (return-type guard Stream/Iterable), `no_magic_number_string_in_tests_severity_miscalibration`, `prefer_catch_over_on_reverse_rule` (flag only on Object catch), `prefer_expanded_at_call_site` (documentation/gaps), `prefer_static_class_regression_on_abstract_final_class` (skip abstract classes), `quick_fixes_not_appearing_in_vscode` (fixed — native plugin migration), `report_avoid_deprecated_usage_analyzer_api_crash` (6.0.10 — staticElement/element), `report_avoid_deprecated_usage_metadataimpl_not_iterable_crash` (6.1.1 — metadata compat), `report_duplicate_paths_deduplication` (path normalization), `report_session_management`, `require_minimum_contrast_ignore_suppression` (IgnoreUtils), `require_yield_between_db_awaits_read_vs_write` (read vs write), `violation_deduplication` (ImpactTracker same-file re-analysis), `yield description and quickfix`. Checklist since removed.

- **History integration (issues, migration, not_viable/drift, framework_upgrade):** Integrated 25 bugs/history files. Issues (9): require_pagination_for_large_lists, prefer_sliverfillremaining_for_empty, require_rtl_layout_support, require_stepper_state_management, avoid_infinite_scroll_duplicate_requests (duplicate issue numbers archived; rules already implemented). Migration (5): v4→v5 migration guide (canonical in doc/guides/migration_v4_to_v5.md); migration-candidate-003/007/008 (Flutter deprecations, not implemented). Not_viable/drift (8): avoid_drift_client_default_for_timestamps, avoid_drift_custom_constraint_without_not_null, avoid_drift_downgrade, avoid_drift_multiple_auto_increment, prefer_drift_modular_generation, require_drift_build_runner, require_drift_table_column_trailing_parens, require_drift_wal_mode (documented as not viable). Not_viable/framework_upgrade (3): migration-candidate-001/002/004 (Flutter framework candidates, not implemented). Files deleted per checklist.

---

## [6.1.2]

In this release we remove 18 quick fixes that only inserted a TODO (project policy). We also add history docs for false positives, a no-stub-fixtures policy, and fixes for avoid_long_parameter_list and plugin crashes (handle_throwing_invocations, CI).

### Removed

- **Insert-TODO quick fixes:** Removed 18 quick fixes that only inserted a `// TODO: ...` comment at the violation (no real code change). They added no value over the lint. Prohibition documented in `bugs/QUICK_FIX_PLAN.md` and `CLAUDE.md`. Rules affected: `avoid_adjacent_strings`, `avoid_late_keyword`, `no_object_declaration`, `avoid_deprecated_usage`, `avoid_duplicate_initializers`, `avoid_duplicate_constant_values`, `avoid_referencing_discarded_variables`, `avoid_duplicate_string_literals_pair`, `avoid_expensive_log_string_construction`, `avoid_missing_interpolation`, `avoid_ignoring_return_values`, `avoid_positional_boolean_parameters`, `avoid_default_to_string`, `avoid_misused_set_literals`, `avoid_global_state`, `avoid_unnecessary_nullable_return_type`, `avoid_unnecessary_local_variable`, `avoid_unused_generics`.

### Documentation

- **History integration (false_positives 11–20):** Rule DartDoc **Exempt** blocks and CHANGELOG_ARCHIVE intent notes for: `avoid_ignoring_return_values` (property setter), `avoid_ios_hardcoded_device_model` (word boundary), `avoid_manual_date_formatting` (map/cache keys), `avoid_medium_length_files` (code-only count, abstract final exempt), `avoid_missing_enum_constant_in_map` (complete maps), `avoid_money_arithmetic_on_double` (word boundary), `avoid_nested_assignments` (for-loop update, arrow body), `avoid_non_ascii_symbols` (invisible/confusable only). False-positive test groups and fixture coverage (e.g. `avoid_nested_assignments` arrow body) added. Checklist since removed.

- **No stub fixtures:** Policy and docs now prohibit stub test fixtures (files with `// expect_lint` and placeholder BAD/GOOD code when the rule does not run or report on that code). Fixtures may only be added when the rule is implemented and the fixture is validated. Updated: `bugs/UNIT_TEST_COVERAGE.md` (policy + §6.3), `CONTRIBUTING.md` (§8 and Testing checklist), `CLAUDE.md` (Test step), `.claude/skills/lint-rules/SKILL.md` (fixture step).

### Fixed

- **avoid_long_parameter_list false positive:** No longer reports on methods or functions named `copyWith` or on any declaration whose parameters are all optional (no required positional or required named). These patterns are self-documenting and do not match the rule's intent.

- **handle_throwing_invocations plugin crash:** On analyzer versions where `Element.metadata` is a wrapper (e.g. `MetadataImpl`) rather than an `Iterable`, the rule no longer crashes with "MetadataImpl is not a subtype of Iterable". `_hasThrowsAnnotation` now uses `readElementAnnotationsFromMetadata` from `lib/src/analyzer_metadata_compat_utils.dart`. Regression test: `test/handle_throwing_invocations_metadata_crash_test.dart`. Consumers on pre-fix versions should upgrade to avoid the plugin crash.

- **CI workflow:** Checkout now uses the exact commit (`github.sha`) on push events instead of the branch ref to avoid races; test job uses the same checkout configuration as the analyze job for consistency.

---

## [6.1.1]

In this release we reach full fixture coverage: 54 new fixture files so every rule has a dedicated fixture. We also fix avoid_deprecated_usage and no_empty_block metrics, and the analyzer metadata crash (MetadataImpl).

### Added

- **Fixture coverage 100%:** Added 54 missing fixture files so the publish script Test Coverage report reaches 1963/1963 (100%) fixture coverage. Categories: stylistic (7), widget_patterns (3), firebase (3), code_quality (4), async (3), widget_layout (2), theming (2), navigation (2), getx (2), config (2), bloc (2), auto_route (2), and one each for state_management, security, riverpod, return, record_pattern, performance, lifecycle, json_datetime, image, geolocator, freezed, forms, error_handling, equatable, disposal, debug, context, connectivity, class_constructor, architecture. All new fixtures are verified in their category test files (Fixture Verification). No new rules; existing rules now have dedicated fixture files for coverage reporting.

### Fixed

- **no_empty_block metrics:** `NoEmptyBlockRule` now uses a string literal for its `LintCode` first argument so `scripts/modules/_rule_metrics.py` can parse the rule name and count the existing fixture. Unnecessary_code category reports 14/14 fixtures.

- **avoid_deprecated_usage plugin crash:** On analyzer versions where `Element.metadata` is a wrapper (e.g. `MetadataImpl`) rather than an `Iterable`, the rule no longer crashes with "MetadataImpl is not a subtype of Iterable". Deprecation detection now uses `lib/src/analyzer_metadata_compat_utils.dart` so metadata is read safely across analyzer API shapes. Regression test: `test/avoid_deprecated_usage_crash_test.dart`. See `bugs/history/rule_bugs/report_avoid_deprecated_usage_metadataimpl_not_iterable_crash.md`. Consumers on pre-fix versions should upgrade to avoid the plugin crash.

---

## [6.1.0]

In this release we add many new stylistic and professional rules (cascade, fold vs reduce, Riverpod/Bloc, naming, structure), split rule files for maintainability, and fix the publish script and report path handling.

### Added

- **avoid_cascade_notation** (Stylistic): Discourage use of cascade notation (..) for clarity and maintainability. Reports every cascade expression. Fixture: `example_style/lib/stylistic_control_flow/avoid_cascade_notation_fixture.dart`.
- **prefer_fold_over_reduce** (Stylistic): Prefer fold() with an explicit initial value over reduce() for collections (clarity and empty-collection safety). Fixture: `example_core/lib/collection/prefer_fold_over_reduce_fixture.dart`.
- **avoid_expensive_log_string_construction** (Professional): Flag log() calls whose message argument is a string interpolation; the string is built even when the log level would not print it. Suggests a level guard or lazy message.
- **avoid_returning_this** (Stylistic): Flag methods that return `this`; prefer explicit return types or void.
- **avoid_cubit_usage** (Stylistic): Prefer Bloc over Cubit for event traceability (Bloc package only). Runs only when bloc package is a dependency.
- **prefer_expression_body_getters** (Stylistic): Prefer arrow (=>) for getters with a single return statement.
- **prefer_final_fields_always** (Stylistic): All instance fields should be final. Stricter than `prefer_final_fields` (which only flags when never reassigned).
- **prefer_block_body_setters** (Comprehensive): Prefer block body {} for setters instead of expression body.
- **avoid_riverpod_string_provider_name** (Professional): Detect manual name strings in Riverpod providers; prefer auto-generated name. Documented in `doc/guides/using_with_riverpod.md`. `avoid_cubit_usage` documented in `doc/guides/using_with_bloc.md`.
- **prefer_factory_before_named** (Comprehensive): Place factory constructors before named constructors in class member order.
- **prefer_then_catcherror** (Stylistic): Prefer .then().catchError() over try/catch for async error handling when handling a single Future.
- **avoid_types_on_closure_parameters** (Stylistic): Closure parameters with explicit types; consider removing when the type can be inferred.
- **prefer_fire_and_forget** (Stylistic): Suggest unawaited/fire-and-forget when await result is unused.
- **prefer_for_in_over_foreach** (Stylistic): Prefer for-in over .forEach() on iterables.
- **prefer_foreach_over_map_entries** (Stylistic): Prefer for-in over map.entries instead of Map.forEach.
- **prefer_base_prefix** (Stylistic): Abstract class names should end with Base.
- **prefer_extension_suffix** (Stylistic): Extension names should end with Ext.
- **prefer_mixin_prefix** (Stylistic): Mixin names should end with Mixin.
- **prefer_overrides_last** (Stylistic): Place override methods after non-override members.
- **prefer_i_prefix_interfaces** (Stylistic): Abstract class (interface) names should start with I.
- **prefer_no_i_prefix_interfaces** (Stylistic): Abstract class names should not start with I (opposite of prefer_i_prefix_interfaces).
- **prefer_impl_suffix** (Stylistic): Classes that implement an interface should end with Impl.
- **prefer_constructor_over_literals** (Stylistic): Prefer List.empty(), Map(), Set.empty() over empty list/set/map literals.
- **prefer_constructors_over_static_methods** (Stylistic): Prefer factory constructor when static method only returns new SameClass().
- **format_test_name** (Stylistic): Test names (first argument to test/testWidgets) must be snake_case.
- **avoid_explicit_type_declaration** (Stylistic): Prefer type inference when variable has initializer.
- **prefer_explicit_null_checks** (Stylistic): Prefer explicit == null / != null over !.
- **prefer_non_const_constructors** (Stylistic): Prefer omitting const on constructors (opinionated).
- **prefer_separate_assignments** (Stylistic): Prefer separate statements over cascade assignments (..).
- **prefer_optional_named_params** (Stylistic): Prefer optional named parameters over optional positional.
- **prefer_optional_positional_params** (Stylistic): Prefer optional positional over optional named for bool/flag parameters.
- **prefer_positional_bool_params** (Stylistic): Boolean parameters as optional positional at call sites.
- **prefer_if_else_over_guards** (Stylistic): Consecutive guard clauses could be expressed as if-else.
- **prefer_cascade_assignments** (Stylistic): Consecutive method calls on same target; consider cascade (..).
- **prefer_factory_constructor** (Stylistic): Prefer factory constructor over static method returning same class.
- **require_auto_route_page_suffix** (Stylistic): AutoRoute page classes should have a Page suffix.
- **prefer_inline_function_types** (Stylistic): Prefer inline function type over typedef.
- **prefer_function_over_static_method** (Stylistic): Static method without "this" could be top-level function.
- **prefer_static_method_over_function** (Stylistic): Top-level function with class-typed first param could be static/extension.
- **avoid_unnecessary_null_aware_elements** (Professional): Flag spread elements using `...?` when the collection is non-null; suggest `...` instead.
- **prefer_import_over_part** (Stylistic): Prefer import over part/part of for modularity.
- **prefer_result_type** (Professional): Functions should declare an explicit return type (except main).
- **avoid_freezed_invalid_annotation_target** (Professional): @freezed should only be used on class declarations.
- **require_const_list_items** (Comprehensive): List items that are no-argument constructor calls should be const when possible.
- **prefer_asmap_over_indexed_iteration** (Professional): Prefer asMap().entries for indexed iteration over manual index loops.
- **avoid_test_on_real_device** (Professional): Flag test names that suggest running on real device; prefer emulators/simulators in CI.
- **avoid_referencing_subclasses** (Professional): Base classes should not reference their subclasses (e.g. return/parameter types).
- **prefer_correct_throws** (Professional): Suggest @Throws annotation for methods/functions that throw.
- **prefer_layout_builder_for_constraints** (Professional): Prefer LayoutBuilder for constraint-aware layout instead of MediaQuery for widget sizing.
- **prefer_cache_extent** (Comprehensive): ListView.builder/GridView.builder should specify cacheExtent for predictable scroll performance. Fixture: `example_widgets/lib/scroll/prefer_cache_extent_fixture.dart`.
- **prefer_biometric_protection** (Professional): FlutterSecureStorage should use authenticationRequired in AndroidOptions/IOSOptions. Fixture: `example_async/lib/security/prefer_biometric_protection_fixture.dart`.
- **avoid_renaming_representation_getters** (Professional): Extension type should not expose the representation via a getter with a different name. Fixture: `example_core/lib/class_constructor/avoid_renaming_representation_getters_fixture.dart`.


### Fixed

- **Publish script (audit failure):** When the pre-publish audit fails, the script now auto-fixes only the missing `[rule_name]` prefix in problem messages when applicable, then re-runs the audit. For other blocking issues (tier integrity, duplicates, spelling, .contains() baseline), it exits with a single clear message pointing to the ✗ lines in the audit output instead of offering the DX message improver (which cannot fix those).

- **Report duplicate paths:** The analysis report log counted the same violation twice when the same issue was reported with both relative and absolute file paths (e.g. `lib/foo.dart` and `D:\proj\lib\foo.dart`). Consolidation now normalizes all paths to project-relative form before deduplication and in stored violation records, so totals and "files with issues" are accurate. See `bugs/history/report_duplicate_paths_deduplication.md`.

### Changed

- **Rule file split (refactor):** Five large rule files were split into smaller, thematically grouped files for maintainability. No behavior or rule counts changed. **code_quality_rules.dart** (106 rules) → `code_quality_avoid_rules.dart`, `code_quality_control_flow_rules.dart`, `code_quality_prefer_rules.dart`, `code_quality_variables_rules.dart`. **widget_patterns_rules.dart** (105) → `widget_patterns_avoid_prefer_rules.dart`, `widget_patterns_require_rules.dart`, `widget_patterns_ux_rules.dart`. **platforms/ios_rules.dart** (86) → `ios_capabilities_permissions_rules.dart`, `ios_platform_lifecycle_rules.dart`, `ios_ui_security_rules.dart`. **widget_layout_rules.dart** (76) → `widget_layout_constraints_rules.dart`, `widget_layout_flex_scroll_rules.dart`. **security_rules.dart** (59) → `security_auth_storage_rules.dart`, `security_network_input_rules.dart`. Exports updated in `all_rules.dart`; tests updated to import the new files. Tier assignments and rule codes unchanged.

### Archive

- Rules 5.0.3 and older moved to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

---

## [6.0.10]

In this release we fix the analyzer 9 crash in avoid_deprecated_usage and clean up duplicated or malformed lint message text in 11 rule files.

### Fixed

- **avoid_deprecated_usage (analyzer 9):** Fixed plugin crash (`NoSuchMethodError: SimpleIdentifierImpl has no getter 'staticElement'`) when running under analyzer 9.x. Rule now uses a compatibility helper that supports both `.element` (analyzer 9+) and `.staticElement` (older). See `bugs/history/report_avoid_deprecated_usage_analyzer_api_crash.md`.
- **Lint message text:** Removed duplicated or malformed text in `correctionMessage` across 11 rule files. No rule logic, tiers, or behavior changed. **code_quality_rules:** `no_boolean_literal_compare` — removed duplicate phrase "!x instead of x == false". **structure_rules:** `prefer_small_length_test_files`, `avoid_medium_length_test_files`, `avoid_long_length_test_files`, `avoid_very_long_length_test_files` — added missing space before "Disable with:". **dependency_injection_rules:** `prefer_constructor_injection` — typo "parameter:." → "parameter.", added space before example. **equatable_rules:** `prefer_equatable_mixin` — fixed "keeping." → "keeping " and sentence order. **widget_lifecycle_rules:** `require_timer_cancellation`, `nullify_after_dispose` — added space before continuation. **ios_rules:** `avoid_ios_deprecated_uikit` — added space before "See Xcode warnings...". **record_pattern_rules:** `avoid_explicit_pattern_field_name` — fixed "instead of." and message order. **widget_layout_rules:** `prefer_spacing_over_sizedbox`, `avoid_deep_widget_nesting`, `prefer_safe_area_aware` — fixed split/space so sentences read correctly. **testing_best_practices_rules:** `avoid_flaky_tests` — fixed "instead of." and sentence order. **test_rules:** `avoid_test_coupling`, `require_test_isolation`, `avoid_real_dependencies_in_tests` — fixed comma/period and continuation order.

---

## [6.0.9]

In this release we focus on cutting false positives: substring checks are replaced with word-boundary regex and type checks in 121+ places. We also reclassify some tiers and severities, add full rule-instantiation tests, and tidy the roadmap and CHANGELOG.

### Fixed

- **False positive reduction:** Replaced substring/`.contains()` with exact match, word-boundary regex, or type checks. CI baselines updated or removed where violations reached 0. Grouped by rule file; all affected rules listed:
  - **animation_rules:** `require_animation_controller_dispose` — dispose check uses `isFieldCleanedUp()` from `target_matcher_utils` instead of regex on `disposeBody`.
  - **api_network_rules:** `require_http_status_check`, `require_retry_logic`, `require_connectivity_check`, `require_request_timeout`, `prefer_http_connection_reuse`, `avoid_redundant_requests`, `require_response_caching`, `prefer_api_pagination`, `require_offline_indicator`, `prefer_streaming_response`, `avoid_over_fetching`, `require_cancel_token`, `require_websocket_error_handling`, `avoid_websocket_without_heartbeat`, `prefer_timeout_on_requests`, `require_permission_rationale`, `require_permission_status_check`, `require_notification_permission_android13`, `require_sqflite_migration`, `require_websocket_reconnection`, `require_typed_api_response`, `require_image_picker_result_handling`, `require_sse_subscription_cancel` — word-boundary regex or exact sets. Baseline removed (0 violations).
  - **async_rules:** `require_feature_flag_default`, DateTime UTC storage rule, stream listen/StreamController rules, `avoid_dialog_context_after_async`, `require_websocket_message_validation`, `require_loading_timeout`, `prefer_broadcast_stream`, mounted/setState visitors, `require_network_status_check`, `require_pending_changes_indicator`, `avoid_stream_sync_events`, `require_stream_controller_close`, `avoid_stream_subscription_in_field`, `require_stream_subscription_no_leak` — exact target set, `extractTargetName` + `endsWith`, word-boundary regex, or exact `StreamSubscription` type. Baseline removed.
  - **disposal_rules:** `require_media_player_dispose`, `require_tab_controller_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close` — `disposeBody.contains(...)` replaced with `isFieldCleanedUp()`. All disposal rules — `typeName.contains(...)` replaced with word-boundary RegExp for media/Tab/WebSocket/VideoPlayer/StreamSubscription/ReceivePort/Socket types. Baseline removed.
  - **file_handling_rules:** PDF rules, sqflite (whereargs, transaction, error handling, batch, close, reserved word, singleton, column constants), large-file rule, `require_file_path_sanitization` — word-boundary regex or static lists. Baseline removed.
  - **navigation_rules:** `avoid_deep_link_sensitive_params`, `prefer_typed_route_params`, `avoid_circular_redirects`, `require_deep_link_fallback`, `require_stepper_validation`, `require_step_count_indicator`, `require_go_router_typed_params`, `require_url_launcher_encoding`, `avoid_navigator_context_issue` — exact property name for queryParameters/pathSegments/pathParameters or word-boundary regex. Baseline removed.
  - **permission_rules:** `require_location_permission_rationale`, `require_camera_permission_check`, `prefer_image_cropping` — word-boundary regex for rationale, camera check, cropper/crop/ImageCropper, profile-context keywords. Baseline removed.
  - **provider_rules:** `avoid_provider_for_single_value` (exact set for Proxy/Multi), `prefer_selector_over_single_watch` (regex for `.select(`), `avoid_provider_value_rebuild` (`endsWith('Provider')`).
  - **security_rules:** RequireSecureStorageRule, RequireBiometricFallbackRule, AvoidStoringPasswordsRule, RequireTokenRefreshRule, AvoidJwtDecodeClientRule, RequireLogoutCleanupRule, RequireDeepLinkValidationRule, AvoidPathTraversalRule, RequireDataEncryptionRule, AvoidLoggingSensitiveDataRule, RequireSecureStorageForAuthRule, AvoidRedirectInjectionRule, PreferLocalAuthRule, RequireSecureStorageAuthDataRule, AvoidStoringSensitiveUnencryptedRule, HTTP client rule, RequireCatchLoggingRule, RequireSecureStorageErrorHandlingRule, AvoidSecureStorageLargeDataRule, RequireClipboardPasteValidationRule, OAuth PKCE rule, session timeout rule, AvoidStackTraceInProductionRule, RequireInputValidationRule — word-boundary RegExp or RegExp.escape. Baseline removed.
  - **widget_lifecycle_rules:** `require_scroll_controller_dispose`, `require_focus_node_dispose` — disposal check uses RegExp for `.dispose()` instead of `disposeBody.contains('.dispose()')`. Baseline 18→16.
  - **False-positive reduction (complete):** All remaining `.contains()` anti-patterns in rule files removed. Tests: `anti_pattern_detection_test` asserts 9 dangerous patterns (sync with publish script); `false_positive_fixes_test` documents word-boundary regression. Discussion 062 archived to `bugs/history/`. Replaced with word-boundary `RegExp`, `isFieldCleanedUp` / `isExactTarget` from `target_matcher_utils`, or exact-set checks in: **accessibility_rules**, **animation_rules**, **bluetooth_hardware_rules**, **collection_rules**, **dependency_injection_rules**, **disposal_rules**, **drift_rules**, **error_handling_rules**, **equatable_rules**, **geolocator_rules**, **get_it_rules**, **getx_rules**, **hive_rules**, **internationalization_rules**, **isar_rules**, **json_datetime_rules**, **memory_management_rules**, **package_specific_rules**, **state_management_rules**, **stylistic_error_testing_rules**, **type_safety_rules**, **ui_ux_rules**, **url_launcher_rules**, **workmanager_rules**. `test/anti_pattern_detection_test.dart` baseline emptied (0 violations); any new dangerous `.contains()` will fail CI.
- **prefer_permission_request_in_context:** Use exact match for Permission target (`Permission` or `Permission.*`) instead of substring match to avoid false positives on unrelated types.

### Changed

- **Roadmap:**
  - Verified all 185 `bugs/roadmap` task files against `lib/src/tiers.dart`; none correspond to implemented rules.
  - Rule quality subsection made self-contained: describes the String.contains() anti-pattern audit (121+ instances across rule files; remediation via exact-match sets or type checks) and `test/anti_pattern_detection_test.dart`; removed references to obsolete review documents.
  - Planned Enhancements table (Discussion #55–#61) removed; details live in `bugs/discussion/` (one file per discussion).
  - Planned rules that have a task file in `bugs/roadmap/` were removed from ROADMAP tables; ROADMAP now points to [bugs/roadmap/](bugs/roadmap/) for task specs.
  - Deferred content merged into ROADMAP.md (Part 2). ROADMAP_DEFERRED.md removed as redundant.
  - Cross-File Analysis CLI roadmap (formerly ROADMAP_CLI.md) merged into ROADMAP.md as **Part 3: Cross-File Analysis CLI Tool Roadmap**. ROADMAP_CLI.md removed.
- **CHANGELOG:** 6.0.7 Added section — consolidated six separate "new lint rules" lists into one list of 55 rules, removed redundant rule-name headers, and ordered entries alphabetically for readability.
- **require_app_startup_error_handling:** Documented that the rule only runs when the project has a crash-reporting dependency (e.g. firebase_crashlytics, sentry_flutter).
- **Tier reclassification (no orphans):** Rule logic, unit tests, and false-positive suppressors unchanged; only tier set membership in `lib/src/tiers.dart` updated. Moved **to Essential:** `check_mounted_after_async`, `avoid_drift_raw_sql_interpolation`. Moved **to Recommended:** `prefer_semver_version`, `prefer_correct_package_name`, `require_macos_notarization_ready`, `avoid_animation_rebuild_waste`, `require_deep_link_fallback`, `require_stepper_validation`, `require_immutable_bloc_state`.
- **Severity reclassification:** `LintCode` severity only; when the rule fires is unchanged. CI using `--fatal-infos` may now fail where it did not. **WARNING → ERROR:** `require_unknown_route_handler`, `avoid_circular_redirects`, `check_mounted_after_async`, `require_https_only`, `require_route_guards`.
- **Discussion 062 (false positive reduction review):** Archived to `bugs/history/discussion_062_false_positive_reduction_review.md` (audit complete 2026-03-01). Ongoing guidance: CONTRIBUTING.md § Avoiding False Positives and `.claude/skills/lint-rules/SKILL.md` § Reducing False Positives.

### Added

- **Publish script (test coverage):** Rule-instantiation status is now derived from the codebase. The Test Coverage report shows a "Rule inst." line (categories with a Rule Instantiation group / categories with a test file) and lists categories missing that group. Implemented in `scripts/modules/_rule_metrics.py` (`_compute_rule_instantiation_stats`); does not read `bugs/UNIT_TEST_COVERAGE_REVIEW.md`.
- **Tests (behavioral):** Added a second test in `test/fixture_lint_integration_test.dart` that runs custom_lint on example_async and asserts specific rule codes (avoid_catch_all, avoid_dialog_context_after_async, require_stream_controller_close, require_feature_flag_default, prefer_specifying_future_value_type) appear in parsed violations when custom_lint runs. When no violations are reported (e.g. resolver conflict), per-rule assertions are skipped. Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §4 (Real behavioral tests — Started).
- **Tests (rule instantiation, full coverage):** Added the Rule Instantiation group to the remaining 45 category test files (bluetooth_hardware, build_method, code_quality, dependency_injection, dialog_snackbar, file_handling, formatting, iap, internationalization, json_datetime, media, money, numeric_literal, permission, record_pattern, resource_management, state_management, stylistic_additional, stylistic_control_flow, stylistic_error_testing, stylistic_null_collection, stylistic, stylistic_whitespace_constructor, stylistic_widget, test, testing_best_practices, unnecessary_code, widget_layout, widget_patterns, plus packages: drift, flame, flutter_hooks, geolocator, graphql, package_specific, qr_scanner, shared_preferences, supabase, url_launcher, workmanager, and platforms: android, ios, linux, macos, windows). All 99 category test files now have Rule Instantiation (one test per rule: code.name, problemMessage, correctionMessage). Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §3.
- **Tests:** `test/fixture_lint_integration_test.dart` — runs `dart run custom_lint` on example_async and asserts output is parseable with `parseViolations`.
- **Missing fixtures (single-per-category):** Added fixtures and test list entries for: freezed (`avoid_freezed_any_map_issue`), notification (`prefer_local_notification_for_immediate`), type_safety (`avoid_redundant_null_check`), ui_ux (`prefer_master_detail_for_large`), widget_lifecycle (`require_init_state_idempotent`).
- **Missing fixtures (two-per-category batch):** Added fixtures and test list entries for: api_network (`prefer_batch_requests`, `require_compression`), code_quality (`avoid_inferrable_type_arguments`), collection (`avoid_function_literals_in_foreach_calls`, `prefer_inlined_adds`), firebase (`avoid_firebase_user_data_in_auth`, `require_firebase_app_check_production`), stylistic_additional (`prefer_sorted_imports`, `prefer_import_group_comments`), web (`avoid_js_rounded_ints`, `prefer_csrf_protection`).
- **Missing fixtures (three-per-category batch):** Added fixtures and test list entries for: control_flow (`avoid_double_and_int_checks`, `prefer_if_elements_to_conditional_expressions`, `prefer_null_aware_method_calls`), hive (`avoid_hive_datetime_local`, `avoid_hive_type_modification`, `avoid_hive_large_single_entry`), performance (`avoid_cache_stampede`, `prefer_binary_format`, `prefer_pool_pattern`), widget_patterns (`avoid_print_in_production`, `avoid_static_route_config`, `require_locale_for_text`).
- **Missing fixtures (naming_style, type, class_constructor):** Added fixtures and test list entries for: naming_style (`prefer_adjective_bool_getters`, `prefer_lowercase_constants`, `prefer_noun_class_names`, `prefer_verb_method_names`), type (`avoid_shadowing_type_parameters`, `avoid_private_typedef_functions`, `prefer_final_locals`, `prefer_const_declarations`), class_constructor (`avoid_accessing_other_classes_private_members`, `avoid_unused_constructor_parameters`, `avoid_field_initializers_in_const_classes`, `prefer_asserts_in_initializer_lists`, `prefer_const_constructors_in_immutables`, `prefer_final_fields`).
- **UNIT_TEST_COVERAGE_REVIEW.md:** Updated §2 table to show 0 missing fixtures for all 27 categories; added completion note and marked recommendation as done.
- **Tests (rule instantiation):** Added Rule Instantiation groups to `animation_rules_test.dart` (19 rules), `collection_rules_test.dart` (25 rules), `control_flow_rules_test.dart` (31 rules), `type_rules_test.dart` (18 rules), `naming_style_rules_test.dart` (28 rules), `class_constructor_rules_test.dart` (20 rules), `structure_rules_test.dart` (45 rules). Each test instantiates the rule and asserts `code.name`, `problemMessage` contains `[code_name]`, `problemMessage.length` > 50, and `correctionMessage` is non-null.
- **Tests (rule instantiation, expanded):** Added the same Rule Instantiation group to 24 additional category test files: `api_network_rules_test.dart` (38), `firebase_rules_test.dart` (28), `performance_rules_test.dart` (46), `ui_ux_rules_test.dart` (19), `widget_lifecycle_rules_test.dart` (36), `type_safety_rules_test.dart` (17), `async_rules_test.dart` (46), `security_rules_test.dart` (55), `navigation_rules_test.dart` (36), `accessibility_rules_test.dart` (39), `provider_rules_test.dart` (26), `riverpod_rules_test.dart` (34), `bloc_rules_test.dart` (46), `getx_rules_test.dart` (23), `architecture_rules_test.dart` (9), `documentation_rules_test.dart` (9), `dio_rules_test.dart` (14), `get_it_rules_test.dart` (3), `image_rules_test.dart` (22), `scroll_rules_test.dart` (17), `equatable_rules_test.dart` (14), `forms_rules_test.dart` (27), and `freezed_rules_test.dart` (10). These tests catch registration and code-name mismatches; behavioral tests (linter-on-code) remain a separate effort. Updated `bugs/UNIT_TEST_COVERAGE_REVIEW.md` §1 and §3 accordingly.
- **Missing fixtures (structure):** Added fixtures and test list entries for: `avoid_classes_with_only_static_members`, `avoid_setters_without_getters`, `prefer_getters_before_setters`, `prefer_static_before_instance`, `prefer_mixin_over_abstract`, `prefer_record_over_tuple_class`, `prefer_sealed_classes`, `prefer_sealed_for_state`, `prefer_constructors_first`, `prefer_extension_methods`, `prefer_extension_over_utility_class`, `prefer_extension_type_for_wrapper`.
- **Tests (rule instantiation + fixtures):** Added rule-instantiation tests (code.name, problemMessage, correctionMessage) and/or missing fixtures for: **Debug:** `prefer_fail_test_case`, `avoid_debug_print`, `avoid_unguarded_debug`, `prefer_commenting_analyzer_ignores`, `prefer_debugPrint`, `avoid_print_in_release`, `require_structured_logging`, `avoid_sensitive_in_logs`, `require_log_level_for_production`. **Complexity:** `avoid_bitwise_operators_with_booleans`, `avoid_cascade_after_if_null`, `avoid_complex_arithmetic_expressions`, `avoid_complex_conditions`, `avoid_duplicate_cascades`, `avoid_excessive_expressions`, `avoid_immediately_invoked_functions`, `avoid_nested_shorthands`, `avoid_multi_assignment`, `binary_expression_operand_order`, `prefer_moving_to_variable`, `prefer_parentheses_with_if_null`, `avoid_deep_nesting`, `avoid_high_cyclomatic_complexity`. **Connectivity:** `require_connectivity_error_handling`, `avoid_connectivity_equals_internet`, `require_connectivity_timeout` (fixture added). **Sqflite:** `avoid_sqflite_type_mismatch`, `prefer_sqflite_encryption` (fixture added). **Config:** `avoid_hardcoded_config`, `avoid_hardcoded_config_test`, `avoid_mixed_environments`, `require_feature_flag_type_safety`, `avoid_string_env_parsing`, `avoid_platform_specific_imports`, `prefer_semver_version`. **Lifecycle:** `avoid_work_in_paused_state`, `require_resume_state_refresh`, `require_did_update_widget_check`, `require_late_initialization_in_init_state`, `require_app_lifecycle_handling`, `require_conflict_resolution_strategy`. **Return:** `avoid_returning_cascades`, `avoid_returning_void`, `avoid_unnecessary_return`, `prefer_immediate_return`, `prefer_returning_shorthands`, `avoid_returning_null_for_void`, `avoid_returning_null_for_future`. **Exception:** `avoid_non_final_exception_class_fields`, `avoid_only_rethrow`, `avoid_throw_in_catch_block`, `avoid_throw_objects_without_tostring`, `prefer_public_exception_classes`. **Equality:** `avoid_equal_expressions`, `avoid_negations_in_equality_checks`, `avoid_self_assignment`, `avoid_self_compare`, `avoid_unnecessary_compare_to`, `no_equal_arguments`, `avoid_datetime_comparison_without_precision`. **Crypto:** `avoid_hardcoded_encryption_keys`, `prefer_secure_random_for_crypto`, `avoid_deprecated_crypto_algorithms`, `require_unique_iv_per_encryption`, `require_secure_key_generation`. **Db_yield:** `require_yield_after_db_write`, `suggest_yield_after_db_read`, `avoid_return_await_db`. **Context:** `avoid_storing_context`, `avoid_context_across_async`, `avoid_context_after_await_in_static`, `avoid_context_in_async_static`, `avoid_context_in_static_methods`, `avoid_context_dependency_in_callback`. **Theming:** `require_dark_mode_testing`, `avoid_elevation_opacity_in_dark`, `prefer_theme_extensions`, `require_semantic_colors`. **Platform:** `require_platform_check`, `prefer_platform_io_conditional`, `prefer_foundation_platform_check`. **Notification:** `require_notification_channel_android`, `avoid_notification_payload_sensitive`, `require_notification_initialize_per_platform`, `require_notification_timezone_awareness`, `avoid_notification_same_id`, `prefer_notification_grouping`, `avoid_notification_silent_failure`, `prefer_local_notification_for_immediate`. **Memory management:** `avoid_large_objects_in_state`, `require_image_disposal`, `avoid_capturing_this_in_callbacks`, `require_cache_eviction_policy`, `prefer_weak_references_for_cache`, `avoid_expando_circular_references`, `avoid_large_isolate_communication`, `require_cache_expiration`, `avoid_unbounded_cache_growth`, `require_cache_key_uniqueness`, `avoid_retaining_disposed_widgets`, `avoid_closure_capture_leaks`, `require_expando_cleanup`. **Disposal:** `require_media_player_dispose`, `require_tab_controller_dispose`, `require_text_editing_controller_dispose`, `require_page_controller_dispose`, `require_lifecycle_observer`, `avoid_websocket_memory_leak`, `require_video_player_controller_dispose`, `require_stream_subscription_cancel`, `require_change_notifier_dispose`, `require_receive_port_close`, `require_socket_close`, `require_debouncer_cancel`, `require_interval_timer_cancel`, `require_file_handle_close`, `require_dispose_implementation`, `prefer_dispose_before_new_instance`, `dispose_class_fields`. **Error handling:** `avoid_swallowing_exceptions`, `avoid_losing_stack_trace`, `avoid_generic_exceptions`, `require_error_context`, `prefer_result_pattern`, `require_async_error_documentation`, `avoid_nested_try_statements`, `require_error_boundary`, `avoid_uncaught_future_errors`, `avoid_print_error`, `require_error_handling_graceful`, `avoid_catch_all`, `avoid_catch_exception_alone`, `avoid_exception_in_constructor`, `require_cache_key_determinism`, `require_permission_permanent_denial_handling`, `require_notification_action_handling`, `require_finally_cleanup`, `require_error_logging`, `require_app_startup_error_handling`, `avoid_assert_in_production`, `handle_throwing_invocations`.

---

## [6.0.7]

In this release we add 55 new lint rules (deprecation, security, structure, Firebase, pagination, and more), remove four rules that were never implemented, and fix require_yield_after_db_write, verify_documented_parameters_exist, and style.

### Fixed

- **Unimplemented rule references:** Removed four rules from the plugin registry, tiers, analysis_options_template, and roadmap fixture that were never implemented: `avoid_equals_and_hash_code_on_mutable_classes`, `avoid_implementing_value_types`, `avoid_null_checks_in_equality_operators`, `avoid_redundant_argument_values`. They remain documented in CHANGELOG 6.0.6 Added; can be re-added when implemented.
- **require_yield_after_db_write:** Suppress when write is last statement, when next statement is `return`, when inside `compute()`/`Isolate.run()`, and when file is in test directory. Recognize `Future.microtask`, `Future.delayed(Duration.zero)`, and `SchedulerBinding.instance.endOfFrame` as valid yields. Replace fragile `toString()` check in SchedulerBinding detection with AST-based identifier check.
- **verify_documented_parameters_exist:** Whitelist built-in types and literals (`[String]`, `[int]`, `[null]`, etc.) to avoid false positives on valid doc references.
- **Style:** Satisfy `curly_braces_in_flow_control_structures` in rule implementation files (api_network, control_flow, lifecycle, naming_style, notification, sqflite, performance, web, security, structure, ui_ux, widget_patterns). Single-statement `if` bodies are now wrapped in blocks; no behavior change.

### Changed

- **Firebase reauth rule:** Reauth is now compared by source offset (earliest reauth in method) so order is correct regardless of visit order.
- **Firebase token rule:** Stored detection now includes VariableDeclaration initializer (e.g. `final t = await user.getIdToken()`).
- **Performance:** Firebase Auth rules set requiredPatterns for earlier file skip when content does not match.
- **no_empty_block:** Confirmed existing implementation in `unnecessary_code_rules.dart`; roadmap task archived.
- **GitHub:**
  - Closed issues [#13](https://github.com/saropa/saropa_lints/issues/13) (prefer_pool_pattern), [#14](https://github.com/saropa/saropa_lints/issues/14) (require_expando_cleanup), [#15](https://github.com/saropa/saropa_lints/issues/15) (require_compression), [#16](https://github.com/saropa/saropa_lints/issues/16) (prefer_batch_requests), [#18](https://github.com/saropa/saropa_lints/issues/18) (prefer_binary_format). Each was commented with resolution version v6.0.7 and closed as completed.
  - Closed issues [#20](https://github.com/saropa/saropa_lints/issues/20), [#29](https://github.com/saropa/saropa_lints/issues/29) (require_pagination_for_large_lists, v6.0.7), [#25](https://github.com/saropa/saropa_lints/issues/25), [#34](https://github.com/saropa/saropa_lints/issues/34) (require_rtl_layout_support, v4.15.1), [#24](https://github.com/saropa/saropa_lints/issues/24), [#33](https://github.com/saropa/saropa_lints/issues/33) (prefer_sliverfillremaining_for_empty, v4.14.5), [#26](https://github.com/saropa/saropa_lints/issues/26), [#35](https://github.com/saropa/saropa_lints/issues/35) (require_stepper_state_management, v4.14.5), [#38](https://github.com/saropa/saropa_lints/issues/38) (avoid_infinite_scroll_duplicate_requests, v4.14.5). Each was commented with the resolution version and closed as completed.

### Added

- 55 new lint rules:
  - `avoid_deprecated_usage` (Recommended, WARNING) — use of deprecated APIs from other packages; same-package and generated files ignored.
  - `avoid_unnecessary_containers` (Recommended, INFO) — Container with only child (and optionally key); remove and use child directly (widget files only).
  - `banned_usage` (Professional, WARNING) — Configurable ban list for identifiers (e.g. `print`). No-op without config in `analysis_options_custom.yaml`. Whole-word match; optional `allowedFiles` per entry.
  - `handle_throwing_invocations` (Professional, INFO) — invocations that can throw (e.g. @Throws, readAsStringSync, jsonDecode) not in try/catch.
  - `prefer_adjacent_strings` (Recommended, INFO) — use adjacent string literals instead of `+` for literal concatenation.
  - `prefer_adjective_bool_getters` (Professional, INFO) — bool getters should use predicate names (is/has/can) not verb names (validate/load).
  - `prefer_asserts_in_initializer_lists` (Professional, INFO) — move leading assert() from constructor body to initializer list.
  - `prefer_batch_requests` (Professional, INFO) — await in for-loop with fetch-like method names; suggest batch endpoints. Resolves [#16](https://github.com/saropa/saropa_lints/issues/16).
  - `prefer_binary_format` (Comprehensive, INFO) — jsonDecode in hot path (timer/stream); suggest protobuf/MessagePack or compute(). Resolves [#18](https://github.com/saropa/saropa_lints/issues/18).
  - `prefer_const_constructors_in_immutables` (Professional, INFO) — @immutable or StatelessWidget/StatefulWidget subclasses with only final fields should have a const constructor.
  - `prefer_const_declarations` (Recommended, INFO) — final variables with constant initializers could be const (locals, static, top-level).
  - `prefer_const_literals_to_create_immutables` (Recommended, INFO) — non-const collection literals passed to immutable widget constructors (widget files only).
  - `prefer_constructors_first` (Professional, INFO) — constructors should appear before methods in a class.
  - `prefer_csrf_protection` (Professional, WARNING) — State-changing HTTP with Cookie header must include CSRF token or Bearer auth. Web/WebView projects only. OWASP M3/A07.
  - `prefer_extension_methods` (Professional, INFO) — top-level functions that could be extension methods on first parameter type.
  - `prefer_extension_over_utility_class` (Professional, INFO) — class with only static methods sharing first param type could be an extension.
  - `prefer_extension_type_for_wrapper` (Professional, INFO) — single-field wrapper class could be an extension type (Dart 3.3+).
  - `prefer_final_fields` (Professional, INFO) — fields never reassigned (except via setter) could be final.
  - `prefer_final_locals` (Recommended, INFO) — local variables never reassigned should be final.
  - `prefer_form_bloc_for_complex` (Professional, INFO) — Form with >5 fields suggests form state management (FormBloc, reactive_forms, etc.).
  - `prefer_getters_before_setters` (Professional, INFO) — setter should appear after its getter.
  - `prefer_if_elements_to_conditional_expressions` (Recommended, INFO) — use if element instead of ternary with null in collections.
  - `prefer_inlined_adds` (Recommended, INFO) — prefer inline list/set literal over empty then add/addAll.
  - `prefer_interpolation_to_compose` (Recommended, INFO) — prefer string interpolation over + with literals.
  - `prefer_local_notification_for_immediate` (Recommended, INFO) — FCM for server-triggered messages; use flutter_local_notifications for app-generated.
  - `prefer_lowercase_constants` (Recommended, INFO) — const/static final should use lowerCamelCase.
  - `prefer_master_detail_for_large` (Professional, INFO) — list navigation without MediaQuery/LayoutBuilder; suggest master-detail on tablets.
  - `prefer_mixin_over_abstract` (Professional, INFO) — abstract class with no abstract members and no generative constructor → mixin.
  - `prefer_named_bool_params` (Professional, INFO) — prefer named bool parameters in small functions.
  - `prefer_no_commented_code` — Alias for existing `prefer_no_commented_out_code` (stylistic).
  - `prefer_noun_class_names` (Professional, INFO) — concrete classes should use noun/agent names, not gerund/-able.
  - `prefer_null_aware_method_calls` (Recommended, INFO) — use ?. instead of if (x != null) { x.foo(); }.
  - `prefer_pool_pattern` (Comprehensive, INFO) — non-const allocation in hot path (timer/animation); suggest object pool. Resolves [#13](https://github.com/saropa/saropa_lints/issues/13).
  - `prefer_raw_strings` (Professional, INFO) — use raw string when only escaped backslashes (e.g. regex).
  - `prefer_record_over_tuple_class` (Professional, INFO) — simple data class with only final fields → record.
  - `prefer_sealed_classes` (Professional, INFO) — abstract class with 2+ concrete subclasses in same file → sealed.
  - `prefer_sealed_for_state` (Professional, INFO) — state/event/result abstract with local subclasses → sealed.
  - `prefer_semver_version` (Essential, WARNING) — pubspec.yaml `version` must be major.minor.patch (e.g. 1.0.0, 2.3.1+4). Reports when invalid.
  - `prefer_sqflite_encryption` (Professional, WARNING) — Sensitive DB paths (user/auth/health/payment etc.) with sqflite should use sqflite_sqlcipher. OWASP M9.
  - `prefer_static_before_instance` (Professional, INFO) — static members before instance in same category.
  - `prefer_verb_method_names` (Professional, INFO) — methods should use verb names, not noun-only.
  - `require_compression` (Comprehensive, INFO) — HTTP get/post/put/delete without Accept-Encoding; suggest gzip. Resolves [#15](https://github.com/saropa/saropa_lints/issues/15).
  - `require_conflict_resolution_strategy` (Professional, WARNING) — Sync/upload/push methods that overwrite data should compare timestamps or show conflict UI.
  - `require_connectivity_timeout` (Essential, WARNING) — HTTP/client/dio requests must have a timeout (e.g. `.timeout(Duration(seconds: 30))`).
  - `require_error_handling_graceful` — flag raw exception (e.toString(), e.message, $e) shown in Text/SnackBar/AlertDialog inside catch blocks; recommend friendly messages.
  - `require_exhaustive_sealed_switch` — switch on sealed types must use explicit cases; avoid default/wildcard (same logic as avoid_wildcard_cases_with_sealed_classes, Essential-tier name).
  - `require_expando_cleanup` (Comprehensive, INFO) — Expando with entries added but no cleanup (expando[key] = null). Resolves [#14](https://github.com/saropa/saropa_lints/issues/14).
  - `require_firebase_reauthentication` — sensitive Firebase Auth ops (delete, updateEmail, updatePassword) must be preceded by reauthenticateWithCredential/reauthenticateWithProvider in the same method (firebase_auth only).
  - `require_firebase_token_refresh` — getIdToken() result stored (variable/prefs) without idTokenChanges listener or forceRefresh (firebase_auth only).
  - `require_init_state_idempotent` (Essential, WARNING) — addListener/addObserver in initState must have matching removeListener/removeObserver in dispose (Flutter widget files).
  - `require_input_validation` (Essential, WARNING) — Raw controller `.text` in post/put/patch body without trim/validate/isEmpty. OWASP M1/M4.
  - `require_late_access_check` (Professional, WARNING) — late non-final field set in a method other than constructor/initState and read in another method without initialization check; risk of LateInitializationError.
  - `require_pagination_for_large_lists` (Essential, WARNING) — ListView.builder/GridView.builder with itemCount from bulk-style list (e.g. allProducts.length) without pagination; OOM and jank risk. Suppressed when project uses infinite_scroll_pagination. Resolves [#20](https://github.com/saropa/saropa_lints/issues/20), [#29](https://github.com/saropa/saropa_lints/issues/29).
  - `require_ssl_pinning_sensitive` (Professional, WARNING) — HTTP POST/PUT/PATCH to sensitive paths (/auth, /login, /token) without certificate pinning; OWASP M5, M3. Suppressed when project uses http_certificate_pinning or ssl_pinning_plugin, and for localhost.
  - `require_text_scale_factor_awareness` — Container/SizedBox with literal height containing Text may overflow at large text scale; recommend flexible layout (widget files only).

---

## [6.0.6]

In this release we add 15 new rules (widget bools, static-only classes, type checks, naming, structure) and improve the init wizard (stylistic walkthrough, progress, clearer boolean examples). require_minimum_contrast now respects ignore comments.

### Added

- 15 new lint rules:
  - `avoid_bool_in_widget_constructors` (Professional, INFO) — widget constructors with named bool params; prefer enum or decomposition
  - `avoid_classes_with_only_static_members` (Recommended, INFO) — prefer top-level functions/constants
  - `avoid_double_and_int_checks` (Professional, INFO) — flag `is int && is double` (always false) and `is int || is double` (use `is num`)
  - `avoid_equals_and_hash_code_on_mutable_classes` (Professional, INFO) — custom ==/hashCode with mutable fields breaks Set/Map
  - `avoid_escaping_inner_quotes` (Stylistic, INFO) — switch quote delimiter to avoid escaped inner quotes
  - `avoid_field_initializers_in_const_classes` (Professional, INFO) — move field initializers to const constructor initializer list
  - `avoid_function_literals_in_foreach_calls` (Stylistic, INFO) — prefer for-in over .forEach with a literal
  - `avoid_implementing_value_types` (Professional, INFO) — implements type with custom ==/hashCode without overriding them
  - `avoid_js_rounded_ints` (Comprehensive, INFO) — integer literals exceeding JS safe integer range (2^53)
  - `avoid_null_checks_in_equality_operators` (Professional, INFO) — redundant other == null when is! type test present
  - `avoid_positional_boolean_parameters` (Professional, INFO) — use named parameters for bools
  - `avoid_private_typedef_functions` (Comprehensive, INFO) — private typedef for function type; prefer inline type
  - `avoid_redundant_argument_values` (Recommended, INFO) — named argument equals parameter default
  - `avoid_setters_without_getters` (Professional, INFO) — setter with no matching getter
  - `avoid_single_cascade_in_expression_statements` (Stylistic, INFO) — single cascade as statement; use direct call

### Changed

- **Init wizard (stylistic walkthrough):** Boolean naming rules are in their own category so "[a] enable all in category" applies to all four; progress shows global position (e.g. 51/143) on resume instead of resetting to 1/N; GOOD/BAD labels are bold and colored; the four boolean rules now have distinct good/bad examples (fields, params, locals, and all booleans) so the wizard differentiates them clearly.

### Fixed

- `require_minimum_contrast` — ignore comments were not honored; rule now respects `// ignore: require_minimum_contrast` and `// ignore_for_file: require_minimum_contrast` (and hyphenated forms) via `IgnoreUtils`

---

## [6.0.5]

In this release we fix path traversal and file sanitization so they no longer flag trusted platform paths (e.g. getApplicationDocumentsDirectory) when passed to private helpers.

### Fixed

- `avoid_path_traversal` — false positive when trusted platform path (e.g., `getApplicationDocumentsDirectory`) is passed to a private helper method; now traces trust through call sites of private methods
- `require_file_path_sanitization` — same false positive as `avoid_path_traversal`; shared inter-procedural platform path trust check

## [6.0.4]

In this release we fix false positives in several rules: path traversal, Riverpod ref/watch, SQL PRAGMA, unsafe collection/reduce guards, require_app_startup_error_handling, require_search_debounce, and require_minimum_contrast.

### Fixed

- `avoid_dynamic_sql` — false positive on SQLite PRAGMA statements which do not support parameter binding; now exempts PRAGMA syntax. Also improved SQL keyword matching to use word boundaries (prevents false positives from identifiers like `selection`, `updateTime`). Intent: flag only user-input interpolation in executable SQL; PRAGMA and other meta-commands are out of scope.
- `avoid_ref_read_inside_build` — false positive on `ref.read()` inside callbacks (onPressed, onSubmit, etc.) defined inline in `build()`; now stops traversal at closure boundaries
- `avoid_ref_in_build_body` — same false positive as above; now shares the corrected visitor with `avoid_ref_read_inside_build`
- `avoid_ref_watch_outside_build` — false positive on `ref.watch()` inside Riverpod provider bodies (`Provider`, `StreamProvider`, `FutureProvider`, etc.); now recognizes provider callbacks as reactive contexts alongside `build()`
- `avoid_path_traversal` — false positive when file path parameter originates from platform path APIs (`getApplicationDocumentsDirectory`, `getTemporaryDirectory`, etc.); now recognizes these as trusted sources
- `require_file_path_sanitization` — same false positive as `avoid_path_traversal`; now recognizes platform path APIs as trusted
- `avoid_unsafe_collection_methods` — false positive on `.first`/`.last` when guarded by early-return (`if (list.isEmpty) return;`) or when the collection is a callback parameter guaranteed non-empty (e.g., `SegmentedButton.onSelectionChanged`)
- `avoid_unsafe_reduce` — false positive on `reduce()` guarded by `if (list.length < N) return;` or `if (list.isEmpty) return;`; now detects early-return and if/ternary guards
- `require_app_startup_error_handling` — false positive on apps without a crash reporting dependency; now only fires when a monitoring package (e.g., `firebase_crashlytics`, `sentry_flutter`) is detected in pubspec.yaml
- `require_search_debounce` — false positive when Timer-based debounce is defined as a class field rather than inline in the callback; now checks enclosing class for Timer/Debouncer field declarations
- `require_minimum_contrast` — false positive when text color is light but background is set via a variable that can't be resolved statically; now recognizes containers with unresolvable background colors as intentionally set

---

## [6.0.3]

In this release we fix the Drift test rule (avoid_drift_close_streams_in_tests) so it runs in test files, and remove dead code from avoid_drift_update_without_where.

### Fixed

- `avoid_drift_close_streams_in_tests` — rule never fired because `testRelevance` was not overridden; the framework skipped test files before the rule could run. Now correctly set to `TestRelevance.testOnly`
- `avoid_drift_update_without_where` — removed unreachable dead code branch

---

## [6.0.2]

In this release we widen the analysis_server_plugin and analyzer_plugin version ranges to reduce conflicts for consumers, and fix the CI publish workflow so it no longer fails on analyzer warnings.

### Changed

- Widened `analysis_server_plugin` and `analyzer_plugin` dependency constraints from pinned to `^` range to reduce version conflicts for consumers

### Fixed

- CI publish workflow: dry run step failed on exit code 65 (warnings) due to `set -e` killing the shell before the exit code could be evaluated; warnings are now reported via GitHub Actions annotations without blocking the publish

---

## [6.0.1]

In this release we add 10 new Drift rules (Value semantics, equalsValue, readTableOrNull, onCreate, schema validation, replace/write, Isar import, foreign keys, onUpgrade) and fix several Drift rule false positives.

### Added

- 10 additional Drift lint rules covering common gotchas, Value semantics, migration safety, and Isar-to-Drift migration patterns (total: 31 Drift rules)
  - `avoid_drift_value_null_vs_absent` (Recommended, WARNING) — detects `Value(null)` instead of `Value.absent()`
  - `require_drift_equals_value` (Recommended, WARNING) — detects `.equals()` with enum/converter columns instead of `.equalsValue()`
  - `require_drift_read_table_or_null` (Recommended, WARNING) — detects `readTable()` with leftOuterJoin instead of `readTableOrNull()`
  - `require_drift_create_all_in_oncreate` (Recommended, WARNING) — detects `onCreate` callback missing `createAll()`
  - `avoid_drift_validate_schema_production` (Professional, WARNING) — detects `validateDatabaseSchema()` without debug guard
  - `avoid_drift_replace_without_all_columns` (Professional, INFO) — detects `.replace()` on update builder instead of `.write()`
  - `avoid_drift_missing_updates_param` (Professional, INFO) — detects `customUpdate`/`customInsert` without `updates` parameter
  - `avoid_isar_import_with_drift` (Recommended, WARNING) — detects files importing both Isar and Drift packages
  - `prefer_drift_foreign_key_declaration` (Professional, INFO) — detects `Id`-suffixed columns without `references()`
  - `require_drift_onupgrade_handler` (Recommended, WARNING) — detects schemaVersion > 1 without `onUpgrade` handler

### Fixed

- `avoid_drift_missing_updates_param` — missing drift import check caused false positives on non-drift `customUpdate()` calls
- `prefer_drift_foreign_key_declaration` — false positives on non-FK column names (`androidId`, `deviceId`, `sessionId`, etc.)
- `require_drift_equals_value` — false positives on non-enum uppercase types (`DateTime`, `Duration`, `BigInt`, etc.)
- `require_drift_onupgrade_handler` — reduced performance cost by checking individual members instead of full class `toSource()`

---

## [6.0.0]

In this release we upgrade to analyzer 9 and Dart SDK 3.10+, and add 21 Drift (SQLite) rules for data safety, migrations, and performance. Drift is now a supported package in package filtering.

### Breaking

- Upgraded `analyzer` from ^8.0.0 to ^9.0.0
- Pinned `analysis_server_plugin` to 0.3.4 (only version targeting analyzer v9)
- Pinned `analyzer_plugin` to 0.13.11 (only version targeting analyzer v9)
- Requires Dart SDK >=3.10.0

### Added

- 21 new Drift (SQLite) database lint rules covering data safety, resource management, SQL injection prevention, migration correctness, performance, and web platform safety
  - `avoid_drift_enum_index_reorder` (Essential, ERROR)
  - `require_drift_database_close` (Recommended, WARNING)
  - `avoid_drift_update_without_where` (Recommended, WARNING)
  - `require_await_in_drift_transaction` (Recommended, WARNING)
  - `require_drift_foreign_key_pragma` (Recommended, WARNING)
  - `avoid_drift_raw_sql_interpolation` (Recommended, ERROR)
  - `prefer_drift_batch_operations` (Recommended, WARNING)
  - `require_drift_stream_cancel` (Recommended, WARNING)
  - `avoid_drift_database_on_main_isolate` (Professional, INFO)
  - `avoid_drift_log_statements_production` (Professional, WARNING)
  - `avoid_drift_get_single_without_unique` (Professional, INFO)
  - `prefer_drift_use_columns_false` (Professional, INFO)
  - `avoid_drift_lazy_database` (Professional, INFO)
  - `prefer_drift_isolate_sharing` (Professional, INFO)
  - `avoid_drift_query_in_migration` (Comprehensive, WARNING)
  - `require_drift_schema_version_bump` (Comprehensive, INFO)
  - `avoid_drift_foreign_key_in_migration` (Comprehensive, INFO)
  - `require_drift_reads_from` (Comprehensive, INFO)
  - `avoid_drift_unsafe_web_storage` (Comprehensive, INFO)
  - `avoid_drift_close_streams_in_tests` (Comprehensive, INFO)
  - `avoid_drift_nullable_converter_mismatch` (Comprehensive, INFO)
- Drift added as supported package in package filtering system

### Changed

- Migrated all `NamedType.name2` references to `NamedType.name` (analyzer v9 API)
- Migrated `VariableDeclaration.declaredElement` to `declaredFragment.element` (analyzer v9 API)
- Removed deprecated `errorCode` parameter from `SaropaDiagnosticReporter.atOffset()`

---

## [5.0.3] and Earlier

For details on the initial release and versions 0.1.0 through 5.0.3, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).

