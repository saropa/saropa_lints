# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 4.9.0.

** See the current published changelog: [saropa_lints/changelog](https://pub.dev/packages/saropa_lints/changelog)

---
## [4.11.1]

- **Improved `prefer_using_list_view` Rule:**
  - Upgraded `problemMessage` to clearly define the performance pitfalls of eager-loading `Column` widgets inside scroll views.
  - Rewrote `correctionMessage` into a detailed technical guide. It now explicitly recommends `ListView.separated` as the direct replacement for layouts requiring specific spacing, provides guidance on handling `Flex` constraints, and explains the mechanics of lazy loading.
  
---
## [4.11.0]

### Changed
- Centralized the duplicated violation-parsing logic from the `baseline` and `impact_report` tools. This resolves a structural issue highlighted by the regex fix in PR #84 and makes future updates more robust. (Thanks [@icealive](https://github.com/icealive!))

---
## [4.10.2]

### Readme
- **Screenshots** added to several sections in [README.md](./README.md).
- **Clarifications** to some wording and tables. Plus **badges** were updated in [README.md](./README.md).

### Tiers
- **Renamed** the `"Insanity"` tier ruleset to the `"Pedantic"` for clarity.

---
## [4.10.1]

### Added

- **New rule `verify_documented_parameters_exist`** (Professional, WARNING): Detects when dartdoc `[paramName]` references parameters that do not exist in the function signature. Complements the existing `require_parameter_documentation` rule which checks the inverse direction. Handles edge cases: uppercase type references, single-letter generics, dotted enum/field references, class field names, `this.` and `super.` constructor parameters.
- **Added Documentation Rules section to ROADMAP** (section 1.63): Lists all 9 documentation rules including the new `verify_documented_parameters_exist`.

---
## [4.10.0]

### Fixed

- **Removed duplicate rule `prefer_async_only_when_awaiting`**: This rule detected the same issue as `avoid_redundant_async` (async function without await), causing duplicate diagnostics. The quick fix has been ported to `avoid_redundant_async`, which has broader detection scope and more robust await detection.
- **Registered 10 Windows/Linux platform rules**: 5 Windows rules (`avoid_hardcoded_drive_letters`, `avoid_forward_slash_path_assumption`, `avoid_case_sensitive_path_comparison`, `require_windows_single_instance_check`, `avoid_max_path_risk`) and 5 Linux rules (`avoid_hardcoded_unix_paths`, `prefer_xdg_directory_convention`, `avoid_x11_only_assumptions`, `require_linux_font_fallback`, `avoid_sudo_shell_commands`) were implemented but not registered in the plugin or assigned to tiers.

### Added

- **7 new quick fixes for dialog, freezed, and accessibility rules**:
  - `require_snackbar_duration`: adds `duration: const Duration(seconds: 4)`
  - `require_dialog_barrier_dismissible`: adds `barrierDismissible: false`
  - `prefer_adaptive_dialog`: converts `AlertDialog()` to `AlertDialog.adaptive()`
  - `avoid_freezed_json_serializable_conflict`: removes redundant `@JsonSerializable()` annotation
  - `require_freezed_arrow_syntax`: converts `fromJson` block body to arrow syntax
  - `require_freezed_private_constructor`: inserts `const ClassName._()`
  - `avoid_icon_buttons_without_tooltip`: adds `tooltip` parameter to `IconButton`

### Changed

- **Improved diagnostic messages on 503 rules across 76 files**: Expanded short `problemMessage` and `correctionMessage` strings using DartDoc context, fixed vague language ("consider" to direct commands, "should be" to "must be"), and appended category-specific consequences and testing advice. All 503 rules now fully pass DX quality thresholds.
- **Rewrote DX messages on 24 rules to pass all quality checks**: Replaced generic boilerplate with rule-specific explanations (18 rules), fixed passive voice to active (3 rules: `require_freezed_explicit_json`, `prefer_on_field_submitted`, `prefer_intl_name`), removed escaped single quotes that broke audit regex parsing (2 rules: `require_content_type_check`, `prefer_go_router_redirect_auth`), and eliminated vague "should be" phrasing (`prefer_absolute_imports`). All rules now pass the full DX quality audit at 100%.
- **Publish script defers version prompt until after analysis**: The `publish_to_pubdev.py` script no longer asks for the publish version upfront. Audits, prerequisites, tests, formatting, and static analysis all run first; the version prompt now appears at Step 8 only after all analysis passes.

- **`prefer_expanded_at_call_site` severity upgraded to ERROR**: Bumped from WARNING to ERROR and impact from medium to critical — returning Expanded/Flexible/Spacer from `build()` causes the same class of runtime crash (ParentDataWidget error) as `avoid_expanded_outside_flex`. Moved from recommended tier to essential tier.
- **`prefer_expanded_at_call_site` now detects `Spacer`**: Added `Spacer` to the detection set alongside `Expanded` and `Flexible`. Returning `Spacer` from `build()` has the same crash risk since it wraps `Expanded` internally.
- **`avoid_expanded_outside_flex` now detects `Spacer`**: Same `Spacer` gap fixed in the sibling rule.
- **`prefer_expanded_at_call_site` quick fix now unwraps**: Replaced the `// HACK` comment insertion with a proper code transformation that extracts the `child` argument and returns it directly. Not offered for `Spacer` (no child to extract).
- **`avoid_expanded_outside_flex` improved diagnostic messages**: Expanded `problemMessage` to explain the FlexParentData/RenderFlex mechanism and the indirect `build()` return case. Expanded `correctionMessage` with actionable guidance for reusable widgets. Added "Why This Crashes" dartdoc section explaining the ParentDataWidget error.

### Fixed

- **Corrected misattributed DartDoc on 3 rules**: `avoid_unbounded_constraints` had keyboard-shortcuts DartDoc, `prefer_sliver_app_bar` had FutureBuilder error-handling DartDoc, and `require_should_rebuild` had TextStyle theming DartDoc. Each now has DartDoc matching its actual rule behavior.
- **`avoid_expanded_outside_flex` no longer duplicates `prefer_expanded_at_call_site`**: When Expanded/Flexible/Spacer is returned directly from `build()` without an intermediate widget wrapper, `avoid_expanded_outside_flex` now defers to `prefer_expanded_at_call_site` instead of reporting a second diagnostic on the same node. Expanded nested inside a non-Flex widget within `build()` is still reported by `avoid_expanded_outside_flex`.
- **`avoid_single_child_column_row` reduced false positives on collection-if and collection-for**: Rule now treats `IfElement` and `ForElement` as dynamic-count elements (like `SpreadElement`). Previously, a `children` list containing a single collection-if or collection-for was incorrectly flagged as a single-child Column/Row, even though these elements can produce 0, 1, or many children at runtime.
- **`avoid_manual_date_formatting` reduced false positives on non-display contexts**: Rule now verifies the target object is actually `DateTime` via static type checking (properties named `year`, `month`, etc. on non-DateTime types are no longer flagged). Additionally, string interpolations used as map keys, cache keys, or arguments to map methods (`putIfAbsent`, `containsKey`, `remove`) are skipped. Variables with internal-use names containing `key`, `cache`, `tag`, `hash`, `bucket`, or `identifier` are also excluded.
- **`avoid_nested_assignments` false positive on for-loop update clauses**: Compound assignments in standard for-loop updaters (`i += step`, `i *= 2`, `i = next(i)`, etc.) are no longer flagged. The rule now skips `ForParts` nodes alongside the existing `ForEachParts` skip.

---
## [4.9.20]

### Added

- **Linux platform rules (5 new rules)**: `avoid_sudo_shell_commands` (ERROR — detects Process.run with sudo/pkexec, OWASP M1), `avoid_hardcoded_unix_paths` (WARNING — detects `/home/`, `/tmp/`, `/etc/` literals), `avoid_x11_only_assumptions` (WARNING — detects X11-only tools and DISPLAY access without Wayland check), `prefer_xdg_directory_convention` (INFO — detects manual `~/.config/` path construction), `require_linux_font_fallback` (INFO — detects non-Linux fonts without fontFamilyFallback, quick fix adds fallback fonts)
- **Windows platform rules (5 new rules)**: `avoid_hardcoded_drive_letters` (WARNING — detects `C:\`, `D:\` literals), `avoid_forward_slash_path_assumption` (WARNING — detects `/` path concatenation instead of path.join()), `avoid_case_sensitive_path_comparison` (WARNING — detects path equality without case normalization, quick fix adds `.toLowerCase()`), `require_windows_single_instance_check` (INFO — detects missing single-instance enforcement in Windows main()), `avoid_max_path_risk` (INFO — detects deeply nested paths that may exceed 260-char MAX_PATH)

### Fixed

- **`avoid_nested_assignments` reduced false positives on arrow function bodies**: Rule now skips `ExpressionFunctionBody` parents — `setState(() => _field = value)` and other arrow functions whose sole body is an assignment are no longer flagged. The arrow syntax `() => x = value` is semantically equivalent to `() { x = value; }`, which was already correctly skipped. Also downgraded severity from WARNING to INFO.
- **`require_intl_currency_format` reduced false positives on non-currency interpolations**: The `StringInterpolation` handler used `node.toSource()` to check for currency symbols, but every interpolated string's source representation contains `$` (Dart's interpolation syntax), causing `r'$'` in `_currencySymbols` to always match. This made the rule flag any `toStringAsFixed()` inside a string interpolation — compass bearings, GPS coordinates, temperatures, percentages, etc. — as manual currency formatting. The fix checks only the literal text segments (`InterpolationString.value`) for currency symbols, consistent with how the `BinaryExpression` handler already works.
- **`prefer_implicit_boolean_comparison` reduced false positives on nullable booleans**: Rule now checks the static type of the left operand and only fires when it is non-nullable `bool`. Previously the rule flagged `== true` / `== false` on `bool?` operands, where the explicit comparison is semantically necessary — removing it either causes a compile error or changes runtime behaviour (treating `null` the same as `false`). This also resolves a conflict with the sibling rule `prefer_explicit_boolean_comparison`, which recommends `== true` for nullable booleans.
- **`prefer_stream_distinct` reduced false positives**: Three fixes — (1) rule now skips `Stream<void>` and `Stream<Null>` where `.distinct()` would suppress all events after the first (breaks `Stream.periodic` timers and signal-only streams like Isar's `watchLazy()`); (2) chain detection now walks the full method invocation chain instead of only checking the immediate parent, so `stream.distinct().map(f).listen(...)` is correctly recognised as already having `.distinct()`; (3) replaced string-based type matching (`getDisplayString().contains('Stream')`) with proper `InterfaceType` checking to avoid false matches on non-stream types.
- **`prefer_edgeinsets_symmetric` reduced false positives**: Detection logic now matches the quick-fix validation — the rule no longer fires on `EdgeInsets.only()` calls that have a symmetric pair (e.g. `top == bottom`) but also contain an unpaired side (e.g. `right` without `left`) or a non-symmetric axis (e.g. `top != bottom`), since `EdgeInsets.symmetric()` cannot express these cases without chaining `.copyWith()`.

---
## [4.9.19]

### Fixed

- **`require_did_update_widget_check` reduced false positives**: Rule now recognises function-based comparisons (`listEquals`, `setEquals`, `mapEquals`, `identical`, `DeepCollectionEquality().equals`) as valid property-change checks. Previously the regex only matched `oldWidget` adjacent to `!=`/`==` operators, so standard Flutter collection comparisons were falsely flagged.
- **`prefer_const_widgets_in_lists` reduced false positives**: Two fixes — (1) rule now verifies list elements are actually `Widget` subclasses instead of treating any `InstanceCreationExpression` as a widget, eliminating false positives on `List<Color>`, `List<Offset>`, `List<EdgeInsets>`, and other non-widget types with const constructors; (2) rule now recognises implicitly const lists inside `static const` fields, `const` variable declarations, enum bodies, annotations, and const constructor calls, instead of only checking for an explicit `const` keyword on the list literal itself.
- **`avoid_positioned_outside_stack` / `avoid_table_cell_outside_table` / `avoid_spacer_in_wrap` reduced false positives in builder callbacks**: `_findWidgetAncestor` now treats named-parameter callbacks (e.g. `BlocBuilder.builder`, `StreamBuilder.builder`, `Builder.builder`, `LayoutBuilder.builder`) as indeterminate boundaries. Previously the AST walk crossed callback boundaries and incorrectly flagged widgets whose runtime parent depends on the call site, not the builder widget itself. Also applied the same fix to the inline ancestor walk in `avoid_flex_child_outside_flex`.

---
## [4.9.18]

### Fixed

- **`avoid_empty_setstate` reduced severity and corrected message**: Changed severity from WARNING to INFO — an empty `setState(() {})` still triggers a rebuild, so the previous message ("has no effect") was factually incorrect. Reworded to acknowledge that state is often modified before the call (e.g. after an async gap with a `mounted` check). This is a valid Flutter pattern, not a bug.
- **`require_yield_between_db_awaits` improved messages and quick fix**: Expanded `problemMessage` and `correctionMessage` to explain why yielding matters (shared isolate, frame starvation, perceived jank). Quick fix now inserts a blank line, an explanatory comment (`// Let the UI catch up to reduce locks`), the `yieldToUI()` call, and a trailing blank line. Quick fix description also expanded.

---
## [4.9.17]

### Fixed

- **`avoid_positioned_outside_stack` reduced false positives**: Two fixes to `_findWidgetAncestor`: (1) `AssignmentExpression` is now treated as an indeterminate boundary — when `Positioned` is assigned via `x = Positioned(...)` to an already-declared variable that is later used inside a `Stack`, the rule no longer flags it; (2) when the AST walk reaches the enclosing `build()` method without finding a `Stack` and without passing through any intermediate widget constructor, the `Positioned` is the root widget of that `build()` — its eventual parent depends on how the caller places the widget, so the result is now `indeterminate` instead of `notFound`. Also benefits `avoid_table_cell_outside_table` which shares the same ancestor-walking logic.
- **`avoid_unbounded_listview_in_column` / `avoid_textfield_in_row` reduced false positives**: Both rules now stop the ancestor walk at callback boundaries — when a scrollable widget or text field is inside a named builder callback (e.g. `Autocomplete.optionsViewBuilder`, `SearchAnchor.suggestionsBuilder`, `PopupMenuButton.itemBuilder`), the rule no longer treats the callback's AST ancestors as runtime widget ancestors. The standard `builder` parameter name is excluded from this boundary since widgets like `Builder` and `LayoutBuilder` render their output in place.

### Changed

- **README: Added platform and package configuration documentation**: Expanded the platform configuration section with a table showing rule counts and examples for all 6 platforms (iOS, Android, macOS, Web, Windows, Linux), shared platform groups (Apple, Desktop), and how shared rules are handled. Added a new package configuration section documenting all 21 configurable packages grouped by category (state management, storage, networking, etc.) with full YAML example.

### Package Publishing

- **Publish script: version prompt with timeout**: Script now prompts for the publish version (pre-filled with pubspec value, 30s timeout) allowing major/minor bumps without manual pubspec edits
- **Publish script: [Unreleased] renamed to version before publishing**: The `[Unreleased]` section in CHANGELOG.md is automatically renamed to the publish version at the start of the workflow
- **Publish script: duplicate version detection**: Publishing fails immediately if the git tag or GitHub release already exists, instead of continuing silently
- **Publish script: GitHub release failure is now a blocker**: Script exits on release creation failure instead of warning and continuing to post-publish steps
- **Publish script: removed automatic post-publish version bump**: The script no longer commits an unpublished version number to the repository after publishing

---
## [4.9.16]

### Added

- **New rules: `require_yield_between_db_awaits`, `avoid_return_await_db`**: Two database/IO yield rules that detect missing `yieldToUI()` calls after heavy DB or file I/O awaits. Prevents UI jank caused by blocking the main thread with consecutive database operations. Both rules include quick fixes that insert `await DelayUtils.yieldToUI();` automatically. Heuristic detection covers Isar, sqflite, Hive, and file I/O methods, with configurable target identifiers. Assigned to Recommended tier with WARNING severity.

- **Extracted package rules into dedicated files**: Bloc rules (52) to `bloc_rules.dart`, Provider rules (26) to `provider_rules.dart`, Dio rules (14) to `dio_rules.dart`, SharedPreferences rules (10) to `shared_preferences_rules.dart`, GetIt rules (3) to `get_it_rules.dart`. Also Riverpod rules (37) expanded in `riverpod_rules.dart`, GetX rules (20) expanded in `getx_rules.dart`, Equatable rules in `equatable_rules.dart`. Supabase rules to `supabase_rules.dart`, Workmanager rules to `workmanager_rules.dart`. No behavior changes — rules remain in their original tiers with the same detection logic.

### Changed

- **Moved ~40 opinionated rules from tier sets to stylistic tier**: Rules with no performance or correctness benefit — code style preferences, formatting, ordering, and naming conventions — are now in `stylisticRules` instead of their original tier sets (recommended, professional, comprehensive, insanity). Each moved rule's `LintImpact` is set to `opinionated`, and its `problemMessage` explicitly states there is no performance benefit. The 6 rules that remained in their original tiers (`prefer_sized_box_for_whitespace`, `prefer_padding_over_container`, `prefer_align_over_container`, `prefer_correct_identifier_length`, `prefer_match_file_name`, `prefer_correct_test_file_name`) now document their objective justification (performance benefit or discoverability) in doc headers and problem messages. Conflicting pair `prefer_type_over_var` / `prefer_var_over_explicit_type` are both in the stylistic tier with explicit conflict notes.

- **Audit report now includes DX Message Quality section**: The full audit markdown report (`reports/*_full_audit.md`) now exports the complete DX quality analysis — summary tables by impact level and tier, issues grouped by type, and a searchable per-rule failing table with tier, impact, score, and specific issues. Previously, DX data was only shown in the console during the audit run but omitted from the exported report.

- **Improved DX message quality for 28 lint rules**: Rewrote `problemMessage` and `correctionMessage` for rules whose messages started with imperative "Avoid" phrasing or were under 200 characters. Messages now use declarative statements that describe what was detected, explain the specific consequence, and provide concrete fix guidance. Affected rules: `avoid_nested_shorthands`, `avoid_string_substring`, `avoid_debug_print`, `avoid_di_in_widgets`, `no_magic_number`, `no_magic_string`, `no_magic_number_in_tests`, `no_magic_string_in_tests`, `avoid_nested_records`, `avoid_one_field_records`, `avoid_positional_record_field_access`, `avoid_single_field_destructuring`, `avoid_nullable_async_value_pattern`, `avoid_returning_void`, `avoid_hardcoded_colors`, `avoid_real_timer_in_widget_test`, `avoid_top_level_members_in_tests`, `avoid_casting_to_extension_type`, `avoid_dynamic_type`, `avoid_nullable_interpolation`, `avoid_null_assertion`, `avoid_non_null_assertion`, `avoid_context_in_initstate_dispose`, `avoid_late_context`, `avoid_sized_box_expand`, `avoid_hardcoded_layout_values`, `prefer_expanded_at_call_site`, `require_hive_initialization`.

### Fixed

- **`avoid_async_call_in_sync_function` reduced false positives**: Five improvements: (1) exempts `cancel()` and `close()` calls in lifecycle methods (`dispose()`, `didUpdateWidget()`, `deactivate()`) — these synchronous overrides cannot be made async, and subscription/controller cleanup is the standard idiomatic pattern; (2) recognises `.ignore()` as an explicit fire-and-forget chain alongside `.then()`, `.catchError()`, and `.whenComplete()`; (3) exempts `StreamController.close()` inside `onDone`/`onError` callbacks, which are `void Function()` and cannot use await; (4) walks through transparent expression wrappers (`ParenthesizedExpression`, `PostfixExpression`) to correctly detect handled Futures like `(asyncCall())` passed to argument lists; (5) refactored visitor into `_shouldReport()` for clarity. Added test fixture with BAD and GOOD cases covering `unawaited()`, lifecycle cleanup, `.ignore()` chains, and void callbacks.

- **`avoid_late_for_nullable` reduced false positives**: Exempts `late final` fields with inline initializers (e.g. `late final Stream<bool>? _stream = _init()`). The `late` keyword provides lazy evaluation in this pattern — the initializer runs on first access, so `LateInitializationError` is impossible. The nullable return type carries semantic meaning and should not be flagged.

- **`prefer_nullable_over_late` reduced false positives**: Two exemptions: (1) `late final` fields with inline initializers — same lazy evaluation rationale as above; (2) `late` fields in `State` subclasses — Flutter's lifecycle guarantees `initState()` runs before `build()`, making `late` assignment safe and idiomatic.

- **`avoid_unbounded_constraints` reduced false positives**: Three improvements: (1) checks only direct children for `Expanded`/`Flexible` via AST instead of string-matching the entire nested subtree, eliminating false positives on parent Columns that contain nested Rows with `Expanded`; (2) scroll-direction-aware — only flags when the widget axis matches the scroll axis (e.g. `Row` with `Expanded` in a vertical `SingleChildScrollView` is no longer flagged); (3) constraint widget detection (`ConstrainedBox`/`SizedBox`/`Container`) now only counts widgets between the Column/Row and the scroll view, not above it.

- **`avoid_positioned_outside_stack` now recognises `Stack` subclasses**: The rule previously only matched the exact types `Stack` and `IndexedStack` by name. Widgets that extend `Stack` (e.g. `Indexer` from `package:indexed`) triggered a false positive. The rule now uses the analyzer type hierarchy (`allSupertypes`) to accept any subclass of `Stack` as a valid parent.

- **Platform-aware filtering for keyboard/focus/hover rules**: `avoid_gesture_only_interactions`, `require_focus_indicator`, and `avoid_hover_only` now respect the project's `platforms:` configuration. These rules enforce desktop/web-specific patterns (keyboard alternatives, focus indicators, hover alternatives) and are auto-disabled for mobile-only projects where they produced false positives. Also corrected `require_focus_indicator` tier grouping — moved from Recommended to Professional in `webPlatformRules` to match its actual tier assignment.

- **`avoid_unbounded_constraints` LintImpact upgraded to high**: Reclassified from `medium` to `high` — Expanded/Flexible in an unbounded scroll axis is a crash path (RenderFlex overflow), not merely a code quality issue.

- **`require_deep_link_fallback` reduced false positives**: Two improvements: (1) methods returning Widget types (`Widget`, `Future<Widget>`, `PreferredSizeWidget`, etc.) are now skipped as UI builders rather than deep link handlers; (2) a positive body signal check requires at least one deep link pattern (`Uri`, `pathSegments`, `queryParameters`, `Navigator`, `GoRouter`, or navigation calls) before flagging — methods like `linkAccounts()` or `logRouteChange()` that have link/route in their name but no URI parsing or navigation in their body are no longer flagged.

### Removed

- **3 duplicate rules removed**: `require_prefs_key_constants` (duplicate of `require_shared_prefs_key_constants`), `require_equatable_immutable` (duplicate of `avoid_mutable_field_in_equatable`), `avoid_equatable_mutable_collections` (duplicate of `prefer_unmodifiable_collections`). Removed from rule files, `_allRuleFactories`, tiers, and analysis options.

### Archive

- Rules 4.9.0 and older moved to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)

---
## [4.9.145]

### Fixed

- **`require_ios_lifecycle_handling` rewritten and renamed to `require_app_lifecycle_handling`**: The rule used file-level string matching, causing false positives when unrelated classes in the same file contained lifecycle keywords. Rewritten with per-class AST detection via `addClassDeclaration` — each `State` subclass is independently checked for `WidgetsBindingObserver` mixin, `didChangeAppLifecycleState` method, and `AppLifecycleListener` fields. Also added one-shot `Timer()` constructor detection with word-boundary regex to avoid false positives from types like `MyTimer`. Renamed to `require_app_lifecycle_handling` (backward-compatible alias preserved) and moved from `ios_rules.dart` to `lifecycle_rules.dart` since the rule is platform-agnostic.

---
## [4.9.14]

### Added

- **9 layout crash detection rules** (Essential tier): Static analysis for Flutter widget hierarchy errors that cause runtime crashes (Red Screen, assertion failures, unbounded constraints):
  - `avoid_table_cell_outside_table` (ERROR) — TableCell outside Table causes ParentData crash
  - `avoid_positioned_outside_stack` (ERROR) — Positioned outside Stack causes ParentData crash
  - `avoid_spacer_in_wrap` (ERROR) — Spacer/Expanded/Flexible in Wrap causes flex paradox crash
  - `avoid_scrollable_in_intrinsic` (ERROR) — scrollable in IntrinsicHeight/IntrinsicWidth causes geometry loop
  - `require_baseline_text_baseline` (ERROR) — baseline alignment without textBaseline causes assertion failure; **quick fix**: adds `textBaseline: TextBaseline.alphabetic`
  - `avoid_unconstrained_dialog_column` (WARNING) — Column in AlertDialog/SimpleDialog without `MainAxisSize.min` can overflow; **quick fix**: adds `mainAxisSize: MainAxisSize.min`
  - `avoid_unbounded_listview_in_column` (ERROR) — ListView/GridView in Column without Expanded causes unbounded constraints crash; **quick fix**: wraps in `Expanded`
  - `avoid_textfield_in_row` (ERROR) — TextField in Row without width constraint causes unbounded width crash; **quick fix**: wraps in `Expanded`
  - `avoid_fixed_size_in_scaffold_body` (WARNING) — Scaffold body Column with TextField but no ScrollView causes keyboard overflow

### Fixed

- **`avoid_expanded_outside_flex` false positive with Wrap**: The rule included `Wrap` in its valid flex parent types, but Wrap does not extend Flex. Expanded/Flexible inside Wrap causes a ParentData crash. Removed `Wrap` from the accepted parent set.

---
## [4.9.13]

### Fixed

- **`check_mounted_after_async` false positive on `await showDialog()`**: The rule flagged `await showDialog(...)` (and `showModalBottomSheet`, `showSnackBar`) as needing a mounted check even when no prior await existed. The `_hasAwaitBefore()` helper searched for `'await '` in the source text before the `MethodInvocation` offset, but when the call was itself the awaited expression (`await showDialog(...)`), its own `await` keyword appeared in that substring. Now uses the parent `AwaitExpression`'s offset when the target is directly awaited, so only genuinely preceding awaits are detected.

---
## [4.9.12]

### Fixed

- **`avoid_late_for_nullable` false positive on generic inner type nullability**: The rule used string-based detection (`toSource().endsWith('?')`) which could false-positive when `?` appeared on inner generic parameters (e.g., `late Future<String?>` or `late Future<({List<CountryEnum>? countries, int count})>`). Replaced with AST-based `question` token check that only detects nullability on the outer type itself.

- **`avoid_nested_assignments` false positive on cascade expressions**: The rule flagged idiomatic Dart cascade property setters (`obj..field = value`) as nested assignments. In the AST, cascade sections are `AssignmentExpression` nodes with a `CascadeExpression` parent, which was not in the skip list. Added `CascadeExpression` parent check so cascades are correctly treated as safe sequential assignments.

- **Audited all string-based nullability checks across 8 rule files**: Replaced fragile `toSource().endsWith('?')` patterns with AST-based `question` token checks in `dependency_injection_rules`, `equatable_rules`, `hive_rules`, `type_safety_rules`, `stylistic_null_collection_rules`, `disposal_rules`, and `async_rules`. Extracted shared `isOuterTypeNullable()` utility to `type_annotation_utils.dart`.

### Changed

- **DX audit now enforces message length on opinionated rules**: The `_audit_dx.py` scoring previously skipped all length checks for `LintImpact.opinionated` rules (stylistic tier), allowing 30-50 character messages to score 100%. Added 100-character minimum threshold (-10 penalty). Also added "opinionated" to the per-impact breakdown display so these rules appear in the DX report alongside critical/high/medium/low.

- **Improved problemMessage for ~98 stylistic rules**: Expanded short problem messages (many under 50 characters) to include rationale and consequences, matching the quality bar already enforced on critical/high/medium rules. Each message now explains what was detected AND why it matters, giving users enough context to evaluate whether to enable the rule.

- **`init` CLI now outputs ANSI colors on Windows**: The `dart run saropa_lints:init` command previously produced monocolor output on Windows terminals because the color detection was too conservative. Now enables Virtual Terminal Processing via the Windows API (`SetConsoleMode`) at startup, uses `stdout.supportsAnsiEscapes` as the primary check, and detects VS Code's integrated terminal (`TERM_PROGRAM`). Honors `NO_COLOR` and `FORCE_COLOR` environment variables. Color support result is cached for performance.

- **Aligned DiagnosticSeverity with actual risk across ~28 rules**: Audited all 1,681 rules for severity-vs-impact mismatches. Upgraded 9 crash-path rules from INFO to ERROR (permission failures, missing error boundaries, unhandled navigation results). Upgraded 14 conditional-failure rules from INFO to WARNING (unsafe casts, missing platform checks, unlogged errors). Downgraded 9 style-only rules from WARNING to INFO (naming conventions, test cleanup, empty spreads). Downgraded 2 borderline ERROR rules to WARNING (`avoid_nested_scaffolds`, `require_focus_node_dispose`). Also aligned `LintImpact` for 3 rules whose internal impact level was inconsistent with their crash-path language.

---
## [4.9.11]

### Fixed

- **`require_auth_check` false positive on Flutter UI functions**: The rule flagged any async function whose name contained a protected keyword (e.g. `settings`, `user`, `profile`) because the return type check `contains('Future')` matched every async function, not just API response handlers. Functions like `showContactSettingsDialog({required BuildContext context})` were incorrectly reported as missing auth checks. Now requires `Response`/`HttpResponse` in the return type or a `Request`/`HttpRequest` parameter to confirm the function is a server-side handler. Also skips Flutter UI function prefixes (`show`, `build`, `init`, `dispose`, `create`, `navigate`, `on`, etc.), private functions, and functions with Flutter UI parameter types (`BuildContext`, `Widget`, etc.). Expanded recognized auth check patterns to include `requireAuth`, `validateToken`, `hasPermission`, `authGuard`, and others.

- **`no_equal_conditions` false positive on `if-case` chains**: The rule flagged `if (x case 1) {} else if (x case 2) {}` as duplicate conditions because it only compared the scrutinee expression (`x`) and ignored the differing `case` pattern values (`1` vs `2`). Each `if-case` branch tests a distinct constant pattern, so they are not duplicates. Now compares the full `if-case` expression including the pattern, not just the scrutinee.

- **`avoid_unsafe_cast` false positive on safe casts**: The rule flagged all non-nullable `as` casts regardless of type safety. Now skips provably safe casts: cast to `Object` (every Dart value is an Object), same-type casts, and upcasts to a supertype (e.g. `int as num`). Fixes false positives on patterns like `error as Object` in catch handlers.

- **`nullify_after_dispose` false positive on debounce/reset patterns**: The rule flagged `.cancel()` calls on nullable `Timer` or `StreamSubscription` fields even when the field was immediately reassigned to a new instance in the same block (e.g., cancel-then-recreate debounce pattern). Since the field is reassigned right after, nullifying it is pointless. Now checks for reassignment after the cancel call and skips reporting when the field receives a new non-null value.

- **`prefer_fractional_sizing` false positive in collection contexts**: The rule flagged `MediaQuery.size * fraction` inside `.add()` calls and list literals, where `FractionallySizedBox` cannot work because parent constraints may be unbounded (e.g. widgets assembled into a list for a horizontal `ScrollView`). Now walks up the AST and skips reporting when the expression is inside a `ListLiteral`, `.add()`, or `.insert()` call.

### Added

- **`prefer_clip_r_superellipse`** (stylistic): Suggests `ClipRSuperellipse` instead of `ClipRRect` for smoother rounded corners. Quick fix replaces the widget preserving all arguments. Requires Flutter 3.32+.
- **`prefer_clip_r_superellipse_clipper`** (stylistic): Suggests `ClipRSuperellipse` instead of `ClipRRect` when a custom clipper is present. No quick fix — `CustomClipper<RRect>` must be manually rewritten as `CustomClipper<RSuperellipse>`.

### Changed

- **Audit report filenames include project name**: Exported audit reports now include the project name from `pubspec.yaml` in the filename (e.g. `20260202_090730_saropa_lints_full_audit.md` instead of `20260202_090730_full_audit.md`). Applies to both full audit and DX audit reports.

- **DX audit per-tier breakdown**: The DX Message Quality report now includes a "By tier" section showing passing/total counts and percentages for each tier (Essential, Recommended, Professional, Comprehensive, Insanity, Stylistic), color-coded to match the tier distribution display.

- **DX message quality improvements (27 rules)**: Improved problem and correction messages to pass DX audit checks. Essential tier now 159/159 (100%), Stylistic tier 134/134 (100%). Eliminated all "should have" (3), passive voice (2), and "better" (1) violations. Rewrote 4 "Avoid" prefix messages (`avoid_throw_in_finally`, `avoid_test_sleep`, `avoid_nested_scaffolds`, `avoid_inherited_widget_in_initstate`) to state what was detected. Expanded short messages for 15 essential rules including `avoid_unsafe_collection_methods`, `always_remove_listener`, `require_scroll_controller_dispose`, `require_focus_node_dispose`, and others. Fixed curly-quote encoding in `require_animation_disposal` and `avoid_mounted_in_setstate`.

- **DX audit grouping**: Length-based issue categories no longer fragment by exact character count. Rules that are "too short" or have a "correction too short" are now grouped into single buckets per threshold instead of one bucket per distinct length.

- **`analysis_options_custom.yaml` now includes a STYLISTIC RULES section**: All opinionated/stylistic rules are listed by category between PLATFORM SETTINGS and RULE OVERRIDES, with descriptions read from rule metadata. Users can toggle individual rules (`true`/`false`) to opt in without the `--stylistic` flag. Existing files are automatically updated on next `init` run — new rules are added as `false`, existing values are preserved, and rules already in RULE OVERRIDES are skipped.

- **`avoid_shrink_wrap_in_scroll` reclassified as stylistic** (fixes [#75](https://github.com/saropa/saropa_lints/issues/75)): Downgraded from WARNING to INFO and moved from Recommended tier to Stylistic (opinionated). The rule flags every `shrinkWrap: true` unconditionally, but `shrinkWrap` is often required (e.g. `ListView` inside a `Column` with `NeverScrollableScrollPhysics` and bounded `itemCount`). The genuinely dangerous cases are already covered by `avoid_shrinkwrap_in_scrollview` (context-aware, nested-scrollable + physics check) and `avoid_shrink_wrap_expensive` (physics-aware). Updated correction message to acknowledge legitimate use cases. Fixed DartDoc that was a copy-paste error from a Form/validator rule.

- Renamed report files from `_saropa_full.log` / `_saropa_summary.md` to `_saropa_lint_report_full.log` / `_saropa_lint_report_summary.log` for clearer identification and consistent `.log` extension

---
## [4.9.10]

### Fixed

- **`prefer_late_final` false positive on helper methods called from multiple sites**: The rule counted assignment AST nodes rather than effective runtime assignments. A late field assigned in a helper method (e.g., `_fetchData()`) that was called from multiple sites (e.g., `initState()` and `didUpdateWidget()`) was incorrectly flagged as single-assignment. Now tracks which methods assign to which fields and counts call sites — if an assigning method is called from N > 1 sites, the field is treated as reassigned.

---
## [4.9.9]

### Fixed

- **`require_ios_push_notification_capability` false positive on unrelated identifiers**: The rule used substring matching on the target expression's source code to detect push notification class names, but also matched method-name patterns (e.g., `onMessage`) against target source. This caused false positives on classes like `CommonMessagePanel` which contains the substring `onMessage`. Now splits patterns into class names (`FirebaseMessaging`, `OneSignal`, `UNUserNotificationCenter`) and method names (`onMessage`, `getToken`, etc.) — only class names are checked against target source, while method names are matched exactly against the invoked method name only.

- **`require_dispose_pattern` false positive on widget classes**: The rule flagged `StatefulWidget` and `StatelessWidget` subclasses that receive disposable types (e.g., `TextEditingController`) as constructor parameters. Widget classes are immutable and have no `dispose()` method — lifecycle cleanup belongs in the corresponding `State` class, which was already skipped. Now skips `StatefulWidget` and `StatelessWidget` in addition to `State`.

---
## [4.9.8]

- **`avoid_unguarded_debug` no longer flags `debug()` calls**: The rule previously flagged every bare `debug()` call without a guard or `level:` parameter. The project's `debug()` function is production-safe logging infrastructure with its own level filtering and Crashlytics routing — it does not need external guards. The rule now only flags `debugPrint()`, which bypasses all filtering and writes directly to the console. Also added recognition of `debug*`/`_debug*` method names as implicit guards for `debugPrint()` calls inside debug helper methods.

- **`prefer_dispose_before_new_instance` false positive on `late final` fields**: The rule flagged assignments to `late final` fields in helper methods called from `initState()`. Since `late final` fields can only be assigned once, there is no previous instance to leak. The rule now skips `late final` fields entirely.

- **`avoid_unused_instances` false positive on fire-and-forget constructors**: The rule flagged `Future.delayed(...)`, `Timer(...)`, and similar constructors as unused instances, even though they are intentionally used for side effects without capturing the return value. Added an allowlist for `Future` and `Timer` types to skip the warning for known fire-and-forget patterns.

- **`nullify_after_dispose` false positive on final/non-nullable fields**: The rule flagged disposal calls on fields declared as `final` or with non-nullable types (e.g., `final ScrollController _scrollController`), where setting the field to `null` is impossible. Now skips fields that are `final` or have a non-nullable type, only flagging nullable non-final fields where nullification is actionable.

- **`avoid_change_notifier_in_widget` false positive on non-ChangeNotifier classes**: The rule used substring matching on type names (`Model`, `Controller`, `Notifier`, `ViewModel`), causing false positives on plain data classes like `ContactModel` that don't extend `ChangeNotifier`. Now resolves the actual class hierarchy via the analyzer's type system and checks `allSupertypes` for `ChangeNotifier`. Falls back to name matching (without the overly broad `Model` pattern) only when type resolution is unavailable.

---
## [4.9.7]

### Added

- **Quick fixes for 8 rules across 5 files**: Added one-click fixes for `require_deprecation_message` (replace `@deprecated` with `@Deprecated`), `avoid_bluetooth_scan_without_timeout` (add scan timeout parameter), `require_geolocator_error_handling` (wrap in try-catch), `avoid_touch_only_gestures` (add `onLongPress` callback), `prefer_catch_over_on` (remove `on` clause from catch), `prefer_expect_over_assert_in_tests` (replace `assert` with `expect`), `require_pdf_error_handling` and `require_sqflite_error_handling` (wrap in try-catch).

- **Shared `WrapInTryCatchFix` utility**: Extracted common try-catch wrapping fix to `ignore_fixes.dart` for reuse across rules that require error handling (PDF, SQLite, geolocation, etc.).

### Improved

- **DX message quality for code_quality_rules**: Expanded `problemMessage` and `correctionMessage` text for all 87 rules with DX issues in `code_quality_rules.dart`. Removes "Avoid" prefixes, fixes vague language, explains consequences, and brings messages above minimum length thresholds.

- **DX message quality for control_flow_rules**: Expanded `problemMessage` and `correctionMessage` text for all 28 rules with DX issues in `control_flow_rules.dart`. Removes "Avoid" prefixes, explains consequences of control flow anti-patterns, and meets minimum message length thresholds.

---
## [4.9.5]

### Added

- **Platform configuration in `analysis_options_custom.yaml`**: New `platforms:` section lets you disable lint rules for platforms your project doesn't target. Only `ios` and `android` are enabled by default — enable `macos`, `web`, `windows`, or `linux` if your project targets those platforms. Rules shared across multiple platforms (e.g., Apple Sign In applies to both iOS and macOS) stay enabled as long as at least one of their platforms is active. User overrides still take precedence over platform filtering.

- **Platform migration for existing configs**: Running `dart run saropa_lints:init` on projects with an existing `analysis_options_custom.yaml` automatically adds the `platforms:` section if missing, without disturbing existing settings.

### Removed

- **Removed rule: `prefer_const_child_widgets`**: Redundant. When the parent widget is `const`, Dart's const context propagation already makes all children implicitly `const` — there is no additional performance benefit. When the parent is non-const, the built-in `prefer_const_literals_to_create_immutables` lint already covers the same case.

### Fixed

- **`init` created backup files even when nothing changed**: Running `dart run saropa_lints:init` repeatedly created a timestamped `.bak` file on every invocation, even when the output content was identical. Backups are now only created when the file content has actually changed.

- **Plugin tier logging always showed `essential`**: The `getLintRules()` log message reported `tier: essential` regardless of the actual tier configured via `dart run saropa_lints:init`. The plugin read tier from a YAML key that the init command never wrote, so it always fell back to `essential`. Now infers the effective tier by comparing the final enabled rule set against each tier's definition, reporting the correct tier (e.g., `tier: professional`).

- **`// ignore_for_file:` directives now respected**: File-level ignore directives were not being checked by custom lint rules. Rules still fired even when `// ignore_for_file: rule_name` was present. The check now runs once per rule per file before any AST callbacks, efficiently skipping the entire rule when the file opts out. Supports both underscore (`rule_name`) and hyphen (`rule-name`) formats.

- **Unresolvable rules now reported**: Rules defined in tier configurations or explicit YAML overrides but missing from the rule factory registry are now logged as warnings during plugin initialization. This makes the rule count mismatch between `init` and the plugin visible (e.g., `WARNING: 18 rule(s) could not be resolved`).

- **`require_isar_nullable_field` false positive on static fields**: The rule incorrectly flagged `static` fields in `@collection` classes. Static fields are not persisted by Isar and should be skipped.

### Improved

- **DX message quality for widget_patterns_rules**: Expanded `problemMessage` and `correctionMessage` text for all 87 rules in `widget_patterns_rules.dart`. Messages now explain consequences, remove vague language ("Avoid", "Consider", "best practices"), and meet minimum length thresholds for the DX audit.

- **`prefer_spacing_over_sizedbox` rule rewritten**: Now detects the alternating `[content, spacer, content, ...]` pattern in Row/Column children instead of just counting SizedBox widgets. Also detects `Spacer()` widgets, removed false `Wrap` support, and added a quick fix that inserts the `spacing` parameter and removes spacer children.

### Changed

- **`init` skips writing unchanged `analysis_options.yaml`**: Running `dart run saropa_lints:init` with the same tier and options no longer overwrites the file if the content is identical. Shows `✓ No changes needed` instead.

- **Plugin version now read dynamically from `pubspec.yaml`**: The version in `createPlugin()` was hardcoded at `4.8.0` and never updated. Replaced with a lazy resolver that reads the actual version from `pubspec.yaml` via `.dart_tool/package_config.json` at runtime. Works for both path dependencies and pub cache installs. The version string never needs manual updates again.

### Added

- **New rule: `avoid_ignore_trailing_comment`** (Recommended tier, WARNING): Warns when `// ignore:` or `// ignore_for_file:` directives have trailing text after the rule names — either a `//` comment or a ` - ` explanation. The `custom_lint_builder` framework uses exact string matching on rule codes, so any trailing text silently breaks suppression. Quick fix moves the text to a `//` comment on the line above the directive.

- **New rule: `prefer_positive_conditions`** (Stylistic, INFO): Warns when an if/else or ternary uses a negative condition (`!expr` or `!=`) that can be flipped to a positive form with branches swapped. Only flags straightforward cases — skips compound conditions, else-if chains, and complex negations. Quick fix available to invert the condition and swap both branches.

- **New rule: `prefer_positive_conditions_first`** (Stylistic, INFO): Warns when guard clauses use negated conditions (`== null`, `!expr`) with early returns, pushing the happy path deeper into the function. Suggests restructuring to place the positive condition first. Opinionated — not included in any tier by default.

- **New rule: `missing_use_result_annotation`** (Comprehensive tier, INFO): Warns when a function returns a value without `@useResult` annotation. Callers may accidentally ignore the return value, leading to missed error handling or lost data transformations.

- **VS Code extension: Scan file or folder**: Right-click any `.dart` file or folder in the Explorer sidebar and select "Scan with Saropa Lints" to instantly see all diagnostics for that path. Uses diagnostics already computed by the Dart analysis server — no re-scanning required.

- **Quick fixes for 7 stylistic widget rules**: Added one-click fixes for `prefer_sizedbox_over_container`, `prefer_container_over_sizedbox`, `prefer_borderradius_circular`, `prefer_expanded_over_flexible`, `prefer_flexible_over_expanded`, `prefer_edgeinsets_symmetric`, and `prefer_edgeinsets_only`. Each fix handles const preservation and argument reordering.

---
## [4.9.4]

### Changed

    Strict Isar migration safety: Replaced require_isar_non_nullable_migration with require_isar_nullable_field. The previous rule allowed non-nullable fields if they had default values, but Isar bypasses constructors/initializers during hydration, leading to crashes on legacy data. The new rule mandates that all fields in @collection classes (except Id) must be nullable (String?) to strictly prevent TypeError during version upgrades.

### Added

    Auto-fix for Isar fields: Added dart fix support for the new require_isar_nullable_field rule to automatically append ? to non-nullable fields in Isar collections.

---
## [4.9.3]

### Fixed

- **Progress bar terminal compatibility**: Use stdout with space-overwrite approach instead of ANSI escape codes for broader terminal support. Added clear labels (`Files:`, `Issues:`, `ETA:`) to progress output for clarity.

- **Version detection when run from other projects**: Fixed `init` command showing "vunknown" when run via `dart run saropa_lints:init` from dependent projects. Now correctly reads version from package location found in `package_config.json`.

- **Full filenames in progress**: Removed truncation of long filenames in progress display.

---
## [4.9.2]

### Added

- **Dynamic version detection in init**: The `init` command now reads the version from `pubspec.yaml` at runtime instead of using a hardcoded constant. Also displays the package source (local path vs pub.dev) to help diagnose version mismatches.

### Changed

- **Full problem messages in generated config**: The `init` command now outputs complete rule descriptions in `analysis_options.yaml` comments instead of truncating at 60 characters. This improves searchability when looking for specific rule behaviors.

---
## [4.9.1]

### Added

- **In-place progress bar with colors**: Terminal output now shows a visual progress bar (`████████░░░░`) that updates in-place instead of scrolling thousands of lines. Includes color coding (green for progress, red/yellow for issues, cyan for file counts), ETA display, and current file indicator. Cross-platform color detection for Windows Terminal, ConEmu, and Unix terminals. Disable with `SAROPA_LINTS_PROGRESS=false`.

- **Issue limit for large codebases**: New `max_issues` setting (default: 1000) stops running WARNING/INFO rules after the limit is reached, providing real speedup on legacy projects. ERROR-severity rules always run regardless of limit. Configure in `analysis_options_custom.yaml`:
  ```yaml
  max_issues: 500  # Or 0 for unlimited
  ```
  The init command now generates this file automatically with sensible defaults.

### Changed

- **Summary output reduced**: Final summary now shows top 5 files/rules instead of 10, with color-coded severity indicators and slow file tracking (files taking >2s are reported at the end instead of interrupting progress).

---

## [4.9.0] and Earlier

For details on the initial release and versions 0.1.0 through 4.9.0, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).
