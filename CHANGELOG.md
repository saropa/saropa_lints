<!-- markdownlint-disable-file MD024 MD033 -->
# Changelog

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTEANCE NOTES -- IMPORTANT --

    All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

    Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

    Each release (and [Unreleased]) opens with a short plain-language **overview** for humans — user-facing only, casual wording, 2–4 sentences max. Summarize what changed from the user's point of view; do NOT restate implementation details from the `### Added/Changed/Fixed` sections below. Hard bans in the overview: line numbers, file paths, regex snippets, internal flag names (`multiLine: true`, `requiredPatterns`, etc.), specific counts/percentages from particular projects ("22,695 issues on project X", "96.8% of the backlog"), AST/visitor terminology. If a reader would have to open the code to understand a phrase, it belongs in the detailed section — not the overview. End the overview with:
    [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)
    substituting X.Y.Z.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

    **CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

    **Score** — [pub.dev/packages/saropa_lints/score](https://pub.dev/packages/saropa_lints/score)

    **Maintenance entries** — Anything with **no end-user impact** (publish/CI tooling, internal refactors, test harness tweaks, plan-folder housekeeping, developer-only scripts) goes INSIDE a collapsed `<details><summary>Maintenance</summary>...</details>` block at the *bottom* of its version section — NOT in `### Added` / `### Changed` / `### Fixed`, which are reserved for user-visible changes that ship in the `.dart` / `.vsix` artifacts. Rule of thumb: if a pub.dev / Marketplace user running the published package would notice the difference, it belongs in a top-level section; otherwise it belongs in the Maintenance expander.

-->

---

## [12.4.0]

Three new animation rules catch silent bugs in press-and-bounce gestures, single-controller states using the plural ticker mixin, and `Animation.value` reads inside `build()` that never re-run. Seven platform-specific rules now skip projects that can't produce a build for the failure mode they warn about — e.g. `avoid_platform_specific_imports` goes quiet in mobile-only apps. `depend_on_referenced_packages` is renamed to `saropa_depend_on_referenced_packages` to stop double-reporting alongside the Dart SDK lint of the same name, and a long-broken pubspec dependency parser underneath it has been repaired — which quietly unblocks every package-gated rule in the plugin. Large-backlog analysis reports now lead with concentration and triage guidance, and the VS Code extension's `Run Analysis` popup shows real issue counts instead of progress-bar stderr.

### Added

- **New rule: `avoid_inert_animation_value_in_build` (Recommended tier, ERROR severity).** Detects `Animation.value` reads inside a widget `build(BuildContext ...)` method when the read is not wrapped by a listening builder — the silent-correctness bug where an animation appears wired (controller starts, tween exists) but is visually inert because `build()` is never re-invoked on a controller tick and the snapshot captured at build time never updates. Motivated by the `widget.child.withOpacity(_opacityAnimation.value)` read that shipped undetected in `saropa-contacts`' `common_inkwell.dart`, silently dropping the opacity half of one of three core animation primitives. Type-resolved via the existing `_isAnimationType` helper — catches `AnimationController`, `CurvedAnimation`, `ReverseAnimation`, `Tween.animate(...)` results, and any custom `Animation` subclass, while skipping same-named `.value` getters on `TextEditingController`, `ValueNotifier`, and other non-`Animation` classes. Parent-walks from the access site so reads inside `AnimatedBuilder` / `ListenableBuilder` / `ValueListenableBuilder` `builder:` callbacks short-circuit as safe (those widgets re-invoke their builder on every tick), and writes (`_controller.value = 0.3`, `_controller.value += 0.1`) are explicitly excluded — the rule targets inert reads, not assignments. `requiredPatterns: {'.value'}` keeps the rule off files that never touch `.value`. Implemented in [animation_rules.dart](lib/src/rules/ui/animation_rules.dart). Registered in [saropa_lints.dart](lib/saropa_lints.dart) `_allRuleFactories` and added to `recommendedOnlyRules` in [tiers.dart](lib/src/tiers.dart). Bug report: [bugs/infra_propose_avoid_inert_animation_value_in_build.md](bugs/infra_propose_avoid_inert_animation_value_in_build.md). Fixture: [avoid_inert_animation_value_in_build_fixture.dart](example/lib/animation/avoid_inert_animation_value_in_build_fixture.dart). Tests: [animation_rules_test.dart](test/animation_rules_test.dart).
- **New rule: `prefer_single_ticker_provider_state_mixin` (Recommended tier, INFO severity).** Flags `State<T>` subclasses that mix in `TickerProviderStateMixin` but declare only one `AnimationController` field, recommending the `SingleTickerProviderStateMixin` variant. The plural mixin exists for multi-ticker states and carries per-instance bookkeeping for a list of tickers; the Single variant stores one nullable ticker and is the Flutter framework's documented default for single-controller state — cheaper at runtime and intent-revealing to a reader scanning the class header. Real-world trigger: `saropa-contacts`' `common_inkwell.dart` shipped `TickerProviderStateMixin` with exactly one `AnimationController` driving derived `ScaleTransition` / `FadeTransition` animations — the exact shape the Single variant is designed for. Forms a three-way staircase with its siblings by controller count: one → this rule, two → no lint (plural mixin correct), three+ → existing `avoid_multiple_animation_controllers` (WARNING). Detection gates: `extends State<T>` (typeArguments required, mirrors `avoid_multiple_animation_controllers`), own `WithClause` names `TickerProviderStateMixin` (mixin inheritance up the supertype chain is intentionally not resolved — keeps scope tight and prevents false reports on subclasses that inherit the mixin from a base state class), exact-count check over explicitly-typed `AnimationController` / `AnimationController?` fields plus inferred-type fields whose initializer is a direct `AnimationController(...)` constructor call. Collections drop out naturally — `List<AnimationController>` has NamedType lexeme `List`, not `AnimationController`, and the inferred-type arm only matches direct constructor calls (not `late final _a = otherController` aliases). `requiredPatterns: {'TickerProviderStateMixin'}` keeps the rule off files that never mention the mixin. One-token quick fix rewrites just the mixin name — both mixins live in `package:flutter/widgets.dart` and expose the same `vsync: this` protocol, so no import changes or argument restructuring are needed. Report site is the mixin `NamedType` itself so the squiggle lands exactly on what the user will change. Implemented in [animation_rules.dart](lib/src/rules/ui/animation_rules.dart); quick fix in [prefer_single_ticker_provider_state_mixin_fix.dart](lib/src/fixes/animation/prefer_single_ticker_provider_state_mixin_fix.dart). Registered in [saropa_lints.dart](lib/saropa_lints.dart) `_allRuleFactories` and added to `recommendedOnlyRules` in [tiers.dart](lib/src/tiers.dart). Bug report: [bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md](bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md). Fixture: [prefer_single_ticker_provider_state_mixin_fixture.dart](example/lib/animation/prefer_single_ticker_provider_state_mixin_fixture.dart).
- **New rule: `prefer_animation_controller_forward_from_zero` (Recommended tier, WARNING severity).** Flags `AnimationController.forward()` (no arguments) inside a press/tap gesture callback (`onTap`, `onLongPress`, `onDoubleTap`, `onPressed`, etc.) when the same class wires the controller to auto-reverse on completion via `addStatusListener` → `<receiver>.reverse()` on `AnimationStatus.completed` — the canonical "press-and-bounce" pattern. Without `from: 0.0`, a rapid re-press while the controller is mid-reverse resumes from the in-flight value, so the animation plays only the remaining fraction of its duration and rapid taps feel sticky and inconsistent. Real-world hit in `saropa-contacts`' `common_inkwell.dart` (three call sites across `onTap` / `onLongPress` / `onDoubleTap`). Detection gates: method name `forward`, empty argument list, resolved static target type is `AnimationController` (or a subtype), receiver source matches one of the class's auto-reverse controllers, enclosing ancestor walk passes through a `FunctionExpression` whose parent is a `NamedExpression` with a press-gesture name (drag/pan callbacks excluded — they drive `.value` directly), and no preceding `<receiver>.reset()` sits in the same `Block` (the reset-then-forward idiom is equivalent and called out as the alternative fix). Listener-to-forward pairing uses the receiver source text so a status listener on controller A cannot flag `forward()` calls on controller B in the same class. `requiredPatterns: {'addStatusListener'}` keeps files that never wire a status listener out of AST registration entirely. Quick fix inserts `from: 0.0` into the empty parens — guarded to bail when the argument list is already non-empty. Implemented in [animation_rules.dart](lib/src/rules/ui/animation_rules.dart); quick fix in [prefer_animation_controller_forward_from_zero_fix.dart](lib/src/fixes/animation/prefer_animation_controller_forward_from_zero_fix.dart). Registered in [saropa_lints.dart](lib/saropa_lints.dart) `_allRuleFactories` and added to `recommendedOnlyRules` in [tiers.dart](lib/src/tiers.dart). Fixture: [prefer_animation_controller_forward_from_zero_fixture.dart](example/lib/animation/prefer_animation_controller_forward_from_zero_fixture.dart). Tests: [animation_rules_test.dart](test/animation_rules_test.dart).

### Changed

- **Analysis report now leads with triage guidance instead of a flat inventory.** On a large backlog — the real-world trigger was a `saropa-contacts` run with 23,434 issues where one rule (`depend_on_referenced_packages`) accounted for 96.8% — the existing text report enumerated everything but did not surface the one fact the triage depends on. The consolidated log at `reports/<yyyymmdd>/<hhmmss>_saropa_lint_report.log` now opens with three synthesized sections before `OVERVIEW`: (1) `CONCENTRATION` names the top rule(s), their share, and the residual issue count if each were suppressed — fires when a single rule contributes ≥ 25% or the top three together contribute ≥ 80%; (2) `CHANGE SINCE LAST RUN` reads the most recent sibling `*_saropa_lint_report.log` in the same date folder, parses its `Total issues:` line, and prints signed delta + percent change so the user sees whether work is converging or diverging; (3) `RECOMMENDED TRIAGE` splits rules into a suppress step (non-fixable rules, highest counts, with residual-after-suppress math) and an auto-fix step (rules with registered quick fixes, `dart fix --apply`), plus a pointer to the existing `FILE IMPORTANCE` ranking for manual cleanup. The `TOP RULES` table gains three columns — `% of total`, `Source` (`saropa` / `dart-lints` / `flutter-lints` / `other`), and `Fixable?` — so each row itself answers "is this mine to change, and can `dart fix` resolve it?" without cross-referencing other sections. Synthesis sections are gated by thresholds (`CONCENTRATION` ≥ 500 total, `RECOMMENDED TRIAGE` ≥ 1000) so small projects still see the concise original format. All computations are pure functions over the existing consolidated batch data — no new AST passes, no new disk scans. Pure logic lives in the new [report_synthesis.dart](lib/src/report/report_synthesis.dart) module so future machine-readable formats (JSON, Markdown) can reuse the same values. Bug report: [bugs/infra_analysis_report_insufficient_for_large_backlogs.md](bugs/infra_analysis_report_insufficient_for_large_backlogs.md). Tests: [report_synthesis_test.dart](test/report_synthesis_test.dart).

### Fixed

- **Seven sibling "breaks on platform X" rules now consult the host project's actual platform targets before reporting.** Audit prompted by the `avoid_platform_specific_imports` fix (below) found that six sibling rules whose failure mode is "breaks on web" (`require_platform_check`, `prefer_platform_io_conditional`, `avoid_secure_storage_on_web`, `avoid_isar_web_limitations`, `prefer_hive_web_aware`) and the inverse rule (`avoid_web_only_dependencies` — "crashes on mobile/desktop") all fired on every qualifying AST node regardless of whether the project could even produce a build for the problematic platform. A seventh rule (`prefer_cursor_for_buttons`) fired on every InkWell/GestureDetector `onTap` regardless of whether the project targets a platform that renders a cursor by default. Two new predicates added alongside `hasWebSupport`: `ProjectContext.hasNonWebPlatform(filePath)` returns `true` when the project root contains any of `android/`, `ios/`, `macos/`, `windows/`, `linux/` (or is a pure Dart library); `ProjectContext.hasPointerPlatform(filePath)` returns `true` when the root contains `web/`, `macos/`, `windows/`, or `linux/` (or is a pure Dart library) — mobile is excluded despite technical support for external pointers (ChromeOS / iPad Magic Keyboard) because the default render path shows no cursor. All three predicates cache six `Directory.existsSync()` probes per project root (one scan, not per-file), and all three default `true` on unknown/un-introspectable projects to preserve the unknown-defaults-to-strict philosophy shared with `flutterSdkAtLeast`. Each of the seven rules gained a single `if (!ProjectContext.has<Predicate>(context.filePath)) return;` as the first line of `runWithReporter`; all existing gates (conditional-import escape hatches, `isFlutterProject` checks, platform-directory file-path skips, `kIsWeb`-in-content checks) are preserved verbatim and run AFTER the new gate, so behavior on projects that DO target the relevant platform is unchanged. Real-world impact on `saropa-contacts` (mobile-only): six rules go quiet on code paths that were structurally incapable of the crash they warned about. Implemented across [project_context_project_file.dart](lib/src/project_context_project_file.dart), [platform_rules.dart](lib/src/rules/config/platform_rules.dart), [firebase_rules.dart](lib/src/rules/packages/firebase_rules.dart), [isar_rules.dart](lib/src/rules/packages/isar_rules.dart), [hive_rules.dart](lib/src/rules/packages/hive_rules.dart), [web_rules.dart](lib/src/rules/platforms/web_rules.dart), [widget_patterns_avoid_prefer_rules.dart](lib/src/rules/widget/widget_patterns_avoid_prefer_rules.dart). Bug report: [bugs/platform_gate_missing_from_sibling_rules.md](bugs/platform_gate_missing_from_sibling_rules.md). Tests: [project_context_platform_gates_test.dart](test/project_context_platform_gates_test.dart) — 24 cases across `hasNonWebPlatform` (10), `hasPointerPlatform` (11), and cross-predicate sanity (3).
- **`avoid_platform_specific_imports` no longer fires in mobile-only Flutter projects that don't target web.** The rule's entire justification is "dart:io breaks web builds", but it previously reported on every `dart:io` import regardless of whether the host project could even produce a web build. In a pure mobile Flutter app (android / ios / macos, no `web/` directory) that failure mode is structurally impossible, so every diagnostic the rule raised was pure noise. Real-world hit: `saropa-contacts`' `lib/database/drift/migration/isar_to_drift_migrator.dart` — a mobile-only data-migration module that uses `io.File` / `io.Directory` for on-device Isar cleanup and cannot run on web because the project has no `web/` directory at root. Added `ProjectContext.hasWebSupport(filePath)` that returns `true` when the project root contains a `web/` directory OR the project is a pure Dart library (no `flutter:` / `sdk: flutter` in pubspec — library authors can't know their caller's platform targets), and `false` otherwise. Unknown projects (no path, no pubspec, unparseable) default to `true` to match the existing `flutterSdkAtLeast` philosophy — prefer to warn on the cautious side rather than silently skip a real cross-platform issue. `AvoidPlatformSpecificImportsRule.runWithReporter` consults the predicate as a new first gate before the existing platform-directory skip and conditional-import escape hatch; both existing gates are preserved unchanged. Result is cached on `_ProjectInfo` per-project, so the `Directory.existsSync()` check runs once per project, not once per file. Implemented in [project_context_project_file.dart](lib/src/project_context_project_file.dart) (added `hasWebSupport` field + accessor) and [config_rules.dart](lib/src/rules/config/config_rules.dart). Bug report: [bugs/avoid_platform_specific_imports_false_positive_non_web_project.md](bugs/avoid_platform_specific_imports_false_positive_non_web_project.md). Tests: [avoid_platform_specific_imports_web_gate_test.dart](test/avoid_platform_specific_imports_web_gate_test.dart) — 6 cases covering Flutter + `web/`, Flutter without `web/`, pure Dart library without `web/`, null path, empty path, and orphan path.
- **Pubspec dependency parser was silently returning an empty set — the real source of the 22,695-issue `depend_on_referenced_packages` storm on `saropa-contacts`.** [project_context_project_file.dart:257](lib/src/project_context_project_file.dart#L257) used `RegExp(r'^\s+(\w+):').allMatches(content)` without `multiLine: true`. `^` without the multiLine flag anchors only at position 0 of the string, so `allMatches` could return at most one hit — and since every real `pubspec.yaml` starts with `name:` at column 0 (no leading whitespace), the regex matched **zero** lines. `_ProjectInfo.dependencies` was an empty `Set<String>` on every project, which meant `ProjectContext.hasDependency(...)` returned `false` for every query everywhere. The collision-rename alone would not have fixed anything: `saropa_depend_on_referenced_packages` was flagging `package:flutter/material.dart`, `package:provider/provider.dart`, and every other legitimate dependency because the rule's `if (ProjectContext.hasDependency(context.filePath, packageName)) return;` guard always fell through to the "not declared" branch. Adding `multiLine: true` restores the intended behavior: pubspec deps (and dev-deps) are now discovered on first access and cached per project root. This quietly unblocks every other rule in the plugin that gates itself on `hasDependency(...)` — package-specific rules like `flutter_hooks`, `riverpod`, `bloc`, `supabase`, and others that were silently skipping their own positive guard and either over-firing or under-firing depending on whether they use it as an inclusion or exclusion check. Regression coverage added in [defensive_coding_test.dart](test/defensive_coding_test.dart) — positive assertions that `hasDependency` resolves `analyzer`, `path`, and `test` from saropa_lints' own pubspec, and that `getPackageName` returns `'saropa_lints'` — so the silent empty-set failure cannot come back without a loud red test. An inline block comment at the regex site spells out the failure mode and the OOM-scale impact so a future reader cannot "clean up" the flag without reading the history. Bug report: [bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md](bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md) §"Secondary — possible over-firing on the saropa side".
- **`depend_on_referenced_packages` renamed to `saropa_depend_on_referenced_packages` to end double-reporting with the Dart SDK lint of the same name.** The Dart SDK ships a built-in lint called `depend_on_referenced_packages` via `package:lints/core.yaml` (transitively enabled by `package:flutter_lints/flutter.yaml`). saropa_lints previously defined its own rule with the identical `LintCode` name, so projects that enabled both — the normal configuration, since `recommended` tier enables saropa's copy and almost every Flutter project `include:`s `flutter_lints` — saw **two** diagnostics per qualifying import: one from the SDK analyzer, one from the custom_lint plugin. Every downstream count was inflated by up to 2×: Problems panel, `reports/.saropa_lints/violations.json`, and the `TOP RULES` / `CONCENTRATION` sections of the consolidated `*_saropa_lint_report.log`. On a real `saropa-contacts` run this rule accounted for 22,695 of 23,434 reported violations (96.8%), at least half of which was double-counting of the SDK lint's own firings. Fix renames saropa's `LintCode` to `saropa_depend_on_referenced_packages` in [config_rules.dart](lib/src/rules/config/config_rules.dart) and updates the registration in `essentialRules` in [tiers.dart](lib/src/tiers.dart); the SDK lint keeps its original name, so existing `// ignore: depend_on_referenced_packages` comments in user projects continue to suppress the SDK lint unchanged. Users who want to suppress saropa's version should now use `// ignore: saropa_depend_on_referenced_packages` (or disable it in the `plugins: saropa_lints: rules:` block). **Breaking for anyone who was previously suppressing saropa's version by name** — but the number of projects in that position is effectively zero, since until now the two rules fired as a pair and there was no way to suppress one without suppressing the other. Bug report: [bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md](bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md). Test: [config_rules_test.dart](test/config_rules_test.dart).
- **Report `CONFIGURATION` block is no longer empty on analyzer-plugin runs.** Every report previously printed `(not available — config was not captured)` because `AnalysisReporter.setAnalysisConfig` was never called from the plugin path — only the CLI scan runner populated it. The one-shot lazy config reload in [saropa_context.dart](lib/src/native/saropa_context.dart) now captures a `ReportConfig` snapshot immediately after `loadNativePluginConfigFromProjectRoot` runs, so the reporter can render enabled rule count, user exclusions, `max_issues`, and saropa_lints version. Tier / platform / package filters stay empty on this path — they're not available to the analyzer plugin (the scan CLI already supplies them for its own path).
- **VS Code extension `Run Analysis`: warning popup now shows the real issue count instead of `dart analyze`'s progress-bar stderr.** When analysis exited non-zero, the follow-up `showWarningMessage` used to splice the first 200 chars of stderr into the popup body, which on any run long enough to emit progress output landed on the `░░░░ N% │ Files: … │ Issues: … │ ETA: …` bar — frozen mid-line, with no count and no action buttons. The new helper in [setup.ts](extension/src/setup.ts) reads `reports/.saropa_lints/violations.json` (already written by the plugin and already consumed by the success-path status-bar message) and composes `Saropa Lints: N issues found.` with `[View Violations]` and `[Show Output]` buttons wired to the existing `saropaLints.focusIssues` and `saropaLints.showOutput` commands. Falls back to `Saropa Lints analysis finished with a non-zero exit. See Output for details.` when `violations.json` is missing or unreadable. The `openEditorsOnly` branch uses the same helper with a scope label. Bug report: [bugs/infra_run_analysis_popup_dumps_progress_stderr.md](bugs/infra_run_analysis_popup_dumps_progress_stderr.md). Test: [formatAnalysisIssuesMessage.test.ts](extension/src/test/formatAnalysisIssuesMessage.test.ts).

<details>
<summary>Maintenance</summary>

- **`prefer_animation_controller_forward_from_zero` internal detection: AST walk replaces source-text `.contains()` on the listener body.** The auto-reverse-controller collector ([animation_rules.dart](lib/src/rules/ui/animation_rules.dart) `_AddStatusListenerVisitor`) previously tested `bodySource.contains('AnimationStatus.completed')` and `bodySource.contains('$receiverSource.reverse')` against `FunctionExpression.body.toSource()`. Both patterns are on the banned list in [test/anti_pattern_detection_test.dart](test/anti_pattern_detection_test.dart) (pattern `bodySource\.contains\(` and the `.toSource().contains(` family) — the publish-script CI gate caught the regression and blocked the v12.4.0 release. Replaced with a dedicated `_ReverseOnCompletedScanner` (RecursiveAstVisitor) that walks the listener body once and sets two independent flags: `sawCompleted` from any `PrefixedIdentifier` or `PropertyAccess` resolving to `AnimationStatus.completed` (covers both parse shapes — standalone equality and chained access — matching the shape-blind behavior of the prior substring scan), and `sawReverseOnReceiver` from any `reverse(...)` `MethodInvocation` whose receiver's `toSource()` equals the listener's receiver. Receiver match uses exact-string equality (not the banned `.toSource().contains(...)` substring search) so a `controllerReverseCount` getter or a `reverse` method on an unrelated field cannot mimic the idiom. Detection contract is unchanged — both signals still required, receiver still gated to prevent listener-on-A flagging forward-on-B — but the false-positive surface where a comment string or string literal inside the listener body happened to contain the matched text is eliminated. Canonical fixture case (`status == AnimationStatus.completed` then `_controller.reverse()`) exercises both code paths unchanged.

</details>

---

## [12.3.4]

New rule `avoid_drift_insert_missing_conflict_target` catches a class of production-crash patterns that existing Drift rules let slip: inserts targeting a table with `@TableIndex(..., unique: true)` on a non-PK column, where the insert omits a matching `onConflict: DoUpdate(target: [uniqueCol])`. Without that target, SQLite falls back to `ON CONFLICT("id")` and raises `SqliteException(2067)` the moment the unique value already exists on disk or appears twice in one batch — the exact failure mode that crashed the Saropa contacts app mid-import, frozen silently on splash by a `debugger()` in `debugException`.

### Added

- **New rule: `avoid_drift_insert_missing_conflict_target` (Essential tier, ERROR severity).** Detects `batch.insert(...)`, `batch.insertAll(...)`, `into(table).insert(...)`, and `table.insertOnConflictUpdate(...)` against tables that declare `@TableIndex(..., unique: true)` on a non-PK column when the call does not pass a matching `onConflict: DoUpdate(target: [<UNIQUE col>])` / `DoUpdate.withExcluded(target: [...])` or `mode: InsertMode.replace`. `insertOnConflictUpdate` is always flagged against a UNIQUE-indexed non-PK column because the method defaults to `ON CONFLICT("id")` — the PK — and silently misses the UNIQUE index, which is the "looks safe but isn't" case that motivated the rule. Implemented in [drift_rules.dart](lib/src/rules/packages/drift_rules.dart) via a compilation-unit scan that collects `@TableIndex(unique: true)` annotations (excluding UNIQUE-on-PK, where Drift's default conflict handling is safe), then resolves call-site table identifiers through Drift's lower-first getter convention (`class ContactPoints` → `db.contactPoints`). Generated `.g.dart` files are exempt. Registered in [saropa_lints.dart](lib/saropa_lints.dart) `_allRuleFactories` and added to `essentialRules` and `driftPackageRules` in [tiers.dart](lib/src/tiers.dart). Severity matches the sibling `avoid_drift_enum_index_reorder` (ERROR) — same class of "silent data corruption / runtime crash" hazard. Bug report: [bugs/infra_new_rule_drift_insert_missing_conflict_target.md](bugs/infra_new_rule_drift_insert_missing_conflict_target.md). Fixture: [avoid_drift_insert_missing_conflict_target_fixture.dart](example_packages/lib/drift/avoid_drift_insert_missing_conflict_target_fixture.dart). Tests: [drift_rules_test.dart](test/drift_rules_test.dart).

---

## [12.3.3]

`avoid_path_traversal` and `require_file_path_sanitization` no longer flag private helpers whose tainted parameter only ever receives compile-time string literals, or whose caller resolves the path through a trusted Dart-SDK API (`Isolate.resolvePackageUri`, `Directory.systemTemp`, `Platform.resolvedExecutable`, `Platform.script`, `Directory.current`, `File.fromUri` / `Directory.fromUri` / `Link.fromUri`). `avoid_null_assertion` no longer flags the common `RegExpMatch.group(N)!` idiom — iterating `allMatches` / `firstMatch` over a literal regex and force-unwrapping a group is now recognized as a safe pattern. `prefer_debug_print` no longer pesters pure Dart packages to call a Flutter-only API.

### Fixed

- **`avoid_path_traversal` + `require_file_path_sanitization` false positive on internal-resolver parameters (shared helper `isFromPlatformPathApi`).** Both rules use a purely syntactic "parameter name appears in path source" heuristic whose one escape hatch — [isFromPlatformPathApi](lib/src/platform_path_utils.dart) — previously recognized only eight Flutter `path_provider` names. That missed two large classes of safe code: (1) private helpers whose every call site passes a `StringLiteral` (e.g. `_sendWebAsset('assets/web/style.css')`), and (2) parameters resolved from trusted Dart-SDK APIs that cannot carry HTTP-origin input without developer-written bridging. Two coordinated fixes in [platform_path_utils.dart](lib/src/platform_path_utils.dart): (a) `platformPathApis` gains `resolvePackageUri`, `resolvedExecutable`, `systemTemp`, `Platform.script`, `Directory.current`, `File.fromUri`, `Directory.fromUri` alongside the existing `path_provider` allowlist — covers the resolver-parameter case; (b) new helper `isParamPassedOnlyLiteralsAtCallSites(node, paramName)` traces every same-scope call site of the enclosing private method and accepts the helper as safe only when every observed call site passes `SimpleStringLiteral` / `AdjacentStrings` / `StringInterpolation`-without-expressions at the tainted parameter's position (handles both positional and named params) — covers the literal-only call-site case. Conservatively returns false when zero call sites are observed (cannot prove all callers pass literals). Both [AvoidPathTraversalRule](lib/src/rules/security/security_network_input_rules.dart) and [RequireFilePathSanitizationRule](lib/src/rules/resources/file_handling_rules.dart) consume the new helper immediately after the existing `isFromPlatformPathApi` check. HTTP-origin taint paths (public functions with user-input parameters, private helpers reachable from non-literal call sites) still lint — regression guards added to both fixtures. Bug reports: [bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md](bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md), [bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md](bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md). Fixtures: [avoid_path_traversal_fixture.dart](example/lib/security/avoid_path_traversal_fixture.dart), [require_file_path_sanitization_fixture.dart](example/lib/file_handling/require_file_path_sanitization_fixture.dart).
- **`prefer_debug_print` false positive on pure Dart packages (rule version v1 → v2).** The rule told authors to replace `print()` with `debugPrint()`, but `debugPrint` lives in `package:flutter/foundation.dart` — so on a package that does not depend on Flutter (e.g. `saropa_drift_advisor` 3.3.3, which has zero runtime dependencies by design), the recommendation was categorically unactionable: "fix it" meant "add Flutter as a dependency just to silence this lint," which is the wrong direction. Fix: [PreferDebugPrintRule.runWithReporter](lib/src/rules/testing/debug_rules.dart) now returns early when `ProjectContext.getProjectInfo(...).isFlutterProject` is `false`, matching the existing gate in the sibling [AvoidPrintInReleaseRule](lib/src/rules/testing/debug_rules.dart) in the same file. Flutter projects see unchanged behavior. Five false-positive sites reported in `saropa_drift_advisor` (`lib/src/error_logger.dart`, `lib/src/drift_debug_server_io.dart`) stop firing. Rule version bumped `{v1}` → `{v2}` and `Updated:` → `v12.3.3`. Fixture [prefer_debug_print_fixture.dart](example/lib/debug/prefer_debug_print_fixture.dart) gains a pure-Dart regression guard (`_pureDartNoLint`) and the existing BAD/GOOD pair now documents that the example package itself is pure-Dart, so the recommendation shape is retained without asserting `expect_lint`. Bug report: [bugs/prefer_debug_print_false_positive_pure_dart_package.md](bugs/prefer_debug_print_false_positive_pure_dart_package.md). ([debug_rules.dart](lib/src/rules/testing/debug_rules.dart))
- **`avoid_null_assertion` false positive on `RegExpMatch.group(N)!` (rule version v7 → v8).** The rule previously fired on every `match.group(1)!` / `match.group(2)!` inside `for (final match in regex.allMatches(s))` and `final match = regex.firstMatch(s); if (match != null) match.group(1)!` — pushing authors to add dead `?? ''` fallbacks. Triggered in real code in `saropa_drift_advisor`'s `_parseCallerFrame` where the regex `r'#\d+\s+\S+\s+\((.+?):(\d+):\d+\)'` has two explicit, non-optional capture groups so `group(1)` / `group(2)` are statically non-null on a successful match. Fix: `AvoidNullAssertionRule` gains a fifth safe-pattern predicate `_isSafeRegExpMatchGroup(node)` that recognizes `<receiver>.group(<nonNegativeIntLiteral>)!` when the receiver's static type resolves to `dart:core` `RegExpMatch` or `Match`. Intentional narrow heuristic (Hypothesis B in the bug report) — the rule does *not* inspect the regex pattern string to count non-optional groups, so a user-written regex with an optional capture group like `(a)?b` followed by `match.group(1)!` is an accepted miss. Rationale: `avoid_null_assertion` is INFO severity, the optional-group case is rare, and pattern-string inspection is expensive and brittle (alternations, nested optionals, named groups). Rule version bumped `{v7}` → `{v8}` and `Updated:` → `v12.3.3`. Fixture [avoid_null_assertion_fixture.dart](example/lib/type/avoid_null_assertion_fixture.dart) gains three new cases: the `allMatches` loop, the `firstMatch` guard, and the accepted-miss optional-group case (documented as a known limit). Bug report: [bugs/avoid_null_assertion_false_positive_regex_match_group.md](bugs/avoid_null_assertion_false_positive_regex_match_group.md). ([type_rules.dart](lib/src/rules/data/type_rules.dart))

---

## [12.3.2]

### Fixed

- **Plugin-internal code cleanup: `dart analyze --fatal-infos` passes on the package's own source.** The pre-publish audit was blocked by 4,106 issues (468 warnings + 3,638 infos) produced when the package's own rules ran against the plugin's own implementation. Many were categorical false positives — the rules target consumer Flutter / Dart *application* code patterns (SSRF guards, stack-trace-to-UI leaks, UTC-for-storage, iOS deployment-target drift, cache-TTL requirements) which do not apply to a Dart-VM analyzer plugin, its CLI tooling in [bin/](bin/), and rule-definition source whose string literals match rule-name patterns. Changes:
  - **Real code fixes** in [lib/src/](lib/src/), [bin/](bin/), [test/](test/) and [tool/](tool/): safe substring helpers via new [string_slice_utils.dart](lib/src/string_slice_utils.dart) (`prefix` / `suffix` / `slice` / `afterIndex` / `afterPrefix`), `.toUtc()` at every `toIso8601String()` storage-adjacent call site (scan timestamps, plugin log entries, LRU cache `_lastRelieve`, incremental-priority `savedAt`, batch JSON `u`), null-coalescing defaults at nullable interpolations, `on Object catch` replacing bare `catch`, `developer.log(..., stackTrace: st)` replacing swallowed exceptions in baseline / rule-pack / cache-stats / violation-export paths, refactored `CompilationUnitDerivedData` analysis to return-not-mutate, `_LruNode.linkAsHead(...)` method so linked-list updates happen as instance state rather than parameter mutation, bounded `LazyPatternCache` with 2048-entry ceiling and full-clear eviction, explicit `AnalysisReporter.dispose()` for the debounce [Timer], `lastOrNull` + null guard in [tool/rule_pack_audit.dart](tool/rule_pack_audit.dart), and `hasLength(...)` test matchers replacing `expect(list.length, N)`. `string_slice_utils.dart` is wired as an import in every file that used `.substring(...)` — the extension methods clamp indices so previously-throwing range calls now return an empty / clamped slice.
  - **Dogfood-only rule disables** in [analysis_options.yaml](analysis_options.yaml) (scope: this package's own `dart analyze` run — consumers and the shipped `plugins: saropa_lints:` manifest are untouched): `avoid_platform_specific_imports`, `avoid_global_state`, `require_ios_deployment_target_consistency`, `avoid_stack_trace_in_production`, `require_catch_logging`, `require_cache_expiration`, `avoid_path_traversal`, `require_file_path_sanitization`, `require_url_validation`, `avoid_money_arithmetic_on_double`, `avoid_unbounded_cache_growth`, plus the stylistic / opt-in info rules (`prefer_blank_line_*`, `prefer_capitalized_comment_start`, `prefer_sentence_case_comments`, `prefer_period_after_doc`, `prefer_readable_line_length`, `prefer_no_commented_out_code`, `prefer_debug_print`, `prefer_final_locals`, `prefer_static_method`, `move_variable_closer_to_its_usage`, `require_test_description_convention`, `avoid_misused_set_literals`, `avoid_null_assertion`, `avoid_ignoring_return_values`, `require_file_exists_check`, `avoid_large_list_copy`, `avoid_nested_assignments`, `avoid_variable_shadowing`, `avoid_very_long_length_files`, `prefer_setup_teardown`, `prefer_boolean_prefixes`, `prefer_doc_comments_over_regular`, `prefer_null_aware_method_calls`, `prefer_where_or_null`, `prefer_const_declarations`, `prefer_inlined_adds`, `prefer_json_serializable`, `avoid_redundant_async`, `avoid_duplicate_test_assertions`). Each disable carries an inline justification comment explaining the specific plugin-infrastructure pattern that makes the rule categorically a false positive on this source (CLI `print()`, analyzer `!` on framework-guaranteed non-null fields, plugin session caches, `{}` inside already-typed `Map<K, Map<…>>`, etc.).

<details>
<summary>Maintenance</summary>

- **Publish script:** New interactive mode **`7) Publish existing .vsix (skip packaging; newest in extension/)`**. Motivated by the 12.3.0 → 12.3.1 → 12.3.2 version-drift seen during the 12.3.1 hotfix: `publish.py` auto-bumps `pubspec.yaml` and `extension/package.json` to the *next* version after a successful pub.dev publish, so re-running mode **6 (Extension only)** to finish an interrupted extension publish would repackage the .vsix at the bumped (unpublished) version — `saropa-lints-12.3.2.vsix` while pub.dev was at `12.3.1` — and shipping that would mismatch the Dart plugin version on Marketplace / Open VSX. Mode 7 skips the repackage step entirely: it scans `extension/*.vsix` sorted by mtime (newest first), selects the newest, and hands it straight to the existing install/Marketplace/Open VSX prompts. If multiple .vsix files exist, all are listed with the selected one flagged. Hard-errors (no auto-fix) when `extension/` is missing or contains zero `.vsix` files (user should run mode 6 first to package one). Reuses `_prompt_extension_install_and_publish()` and `publish_extension()` so install + store publish behavior is identical to mode 6. ([publish.py](scripts/publish.py), [_publish_workflow.py](scripts/modules/_publish_workflow.py))

</details>

---

## [12.3.1]

Hotfix on top of 12.3.0: the `scan` CLI (and any caller that invoked the plugin with a tier) crashed with `Unsupported operation: Cannot change an unmodifiable set` as soon as the second source file was visited, because tier rule-sets are `const` and the plugin's rule-pack reloader tried to mutate them in place. 12.3.0 was tagged but never actually published to pub.dev because this surfaced on the CI test step — republishing as 12.3.1 with the fix. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.1/CHANGELOG.md)

### Fixed

- **Plugin crash on second analyzed file when enabled rules came from a tier (`essential`, `recommended`, …).** `ScanRunner._resolveRuleNames()` returns the exact `const Set<String>` literal from [tiers.dart](lib/src/tiers.dart) (e.g. `essentialRules`) and assigns it directly to the static `SaropaLintRule.enabledRules`. Later, on every analyzed file, `ProgressTracker.recordFile` calls `loadRulePacksConfigFromProjectRoot`, which calls `_reloadRulePacksFromRoot` — that function read `SaropaLintRule.enabledRules` back as `enabled` and then called `enabled.removeAll(_packContributedCodes!)` (and `enabled.add(code)` via `mergeRulePacksIntoEnabled`). Both mutations throw `Unsupported operation: Cannot change an unmodifiable set` against a `const` set. The crash was order-dependent: the first call through the function took the early-return `content == null` branch and only set `_packContributedCodes = {}`, so the failure only materialized on the *second* call into `_reloadRulePacksFromRoot` (when `_packContributedCodes` was non-null and `removeAll` actually got executed). That's why the bug slipped through local testing — `dart test` happens to schedule the `scan_runner_test.dart` cases in an order that either avoids the second call or avoids a project root with a rule-packs block; CI's parallel test runner hit the failing ordering and blew up with `##[error]8507 tests passed, 1 failed.` on `test/scan_runner_test.dart: ScanRunner run with tier returns non-null list`, which aborted the publish workflow before the `pub publish` step ran. Fix: `_reloadRulePacksFromRoot` now takes a mutable copy (`final enabled = <String>{...?SaropaLintRule.enabledRules};`) at function entry, so `removeAll` / `add` always succeed regardless of whether the source set is a `const` tier literal, a `Set.union(...)` composite, or a previously-assigned mutable set. The fix is defensive at the mutation site rather than the single known producer (`ScanRunner`), so any future caller that assigns an unmodifiable set to `enabledRules` stays safe. ([config_loader.dart](lib/src/native/config_loader.dart))

---

## [12.3.0]

Windows users get their vibrancy reports back (CLI spawn + transitive footprint fixes), the plugin now logs to `reports/.saropa_lints/plugin.log` so silent failures are visible, and the report toolbar gains Rescan, Open Project, and Copy All JSON buttons — plus a new `prefer_listenable_builder` rule. — [log](https://github.com/saropa/saropa_lints/blob/v2.3.0/CHANGELOG.md)

### Fixed

- **Extension:** Vibrancy scan CLI commands (`dart pub outdated --json`, `dart pub deps --json`) silently failed on Windows, which produced a cascade of silent downstream failures: the Transitives column was hidden for every project, the Footprint toggle (Own / +Unique / +All) showed identical numbers, and upgrade-blocker analysis was skipped. Root cause: Flutter installs ship `dart.bat` (not `dart.exe`) on Windows, and Node's `execFile('dart', ...)` does **not** consult `PATHEXT` the way a shell does — so even when `dart pub deps --json` ran fine from a terminal, the extension's child process failed with `ENOENT`. The failure surfaced as a single log line `Blocker analysis skipped — CLI commands failed` with no underlying reason. Fix: (a) both `runDartCommand` and `runFlutterCommand` in [flutter-cli.ts](extension/src/vibrancy/services/flutter-cli.ts) now pass `shell: true` on `win32` so cmd.exe resolves `.bat`/`.cmd` extensions. Args are all hardcoded (`['pub', 'deps', '--json']`) and `cwd` is a workspace folder path, so there's no shell-injection surface. (b) `CommandResult` gained an `errorMessage` field; `DepGraphResult` and `PubOutdatedResult` propagate it; [blocker-enricher.ts](extension/src/vibrancy/services/blocker-enricher.ts) now logs concrete stderr (`pub outdated: ... | pub deps: ...`) at `ERROR` level so the log self-diagnoses future regressions. ([flutter-cli.ts](extension/src/vibrancy/services/flutter-cli.ts), [dep-graph.ts](extension/src/vibrancy/services/dep-graph.ts), [pub-outdated.ts](extension/src/vibrancy/services/pub-outdated.ts), [blocker-enricher.ts](extension/src/vibrancy/services/blocker-enricher.ts))
- **Extension:** Vibrancy report Footprint toggle (Own / + Unique / + All) silently showed identical sizes across all three modes even when the Transitives column was populated. Root cause: `enrichTransitiveInfo` computes `uniqueTransitiveSizeBytes` and `sharedTransitiveSizeBytes` by looking each transitive up in a `sizeLookup` map — but the map was built only from direct-dep results (since only direct deps get full vibrancy analysis). Transitives like `image` (pulled in by `crop_your_image`) were absent from the map, so `sawAnySize` stayed false and both size fields ended up `null`. All three computed labels (`own`, `own + unique`, `own + unique + shared`) collapsed to `own`. Fix: [extension-activation.ts](extension/src/vibrancy/extension-activation.ts) now collects the union of every transitive package name across all direct deps (excluding those already in `sizeLookup`), fetches their archive sizes in parallel via the existing cached `fetchArchiveSize`, and merges them into the lookup before calling `enrichTransitiveInfo`. First scan in a project pays N parallel HEAD requests against pub.dev; subsequent scans are zero-cost because `fetchArchiveSize` caches under `pub.archiveSize.<name>`. Progress notification now reports "Fetching N transitive sizes...". ([extension-activation.ts](extension/src/vibrancy/extension-activation.ts))
- **FATAL plugin silence affecting all consumers — saropa_lints emitted zero diagnostics when the analyzer was launched with a cwd different from the consumer's project root** (e.g. every VS Code user who opened their workspace via the file picker, every Flutter project where the analyzer inherited a parent cwd). Three interlocking bugs produced a silent, hook-less failure mode where the plugin successfully handled `analysis.setContextRoots` and `analysis.updateContent` requests but never emitted a single diagnostic. Root cause chain: (1) `analysis_server_plugin`'s `Plugin.register` is called **synchronously in the `PluginServer` constructor** — before `start()`, before the channel, before any context-root info — so the plugin cannot know the consumer project root at registration time. (2) `SaropaLintsPlugin.start()` called `loadNativePluginConfig()` with no project-root argument, which read `analysis_options.yaml` relative to `Directory.current.path` — which for analyzer-launched plugins is the analysis-server process's cwd, not the consumer project. The read returned null and `_loadDiagnosticsConfig` silently early-returned, leaving `SaropaLintRule.enabledRules = null`. (3) `registerSaropaLintRules` had a kill-switch: `if (enabled == null || enabled.isEmpty) return;` — so **zero rules were ever registered with the `PluginRegistry`** when config read failed. `register()` runs once, so there was no recovery path. Fix: (a) `registerSaropaLintRules` now registers **every** rule unconditionally at plugin-init (all ~2100), honoring `disabledRules`/`configAliases` as before. Per-rule enablement is then filtered by the analyzer's own `Registry.ruleRegistry.enabled(diagnosticConfigs)` — the analyzer parses `plugins > saropa_lints > diagnostics:` natively and only installs AST visitors for rules marked `true`, so the 2100-rule registration has **zero hot-path cost**: disabled rules never reach `registerNodeProcessors` and never dispatch a single visitor callback. Register-time cost is ~2100 lightweight rule-instance allocations (~1 MB, permanent). (b) New `loadNativePluginConfigFromProjectRoot(projectRoot)` in [config_loader.dart](lib/src/native/config_loader.dart) reloads all config (severities, diagnostics, rule packs, baseline, banned-usage, output) from a known project root. (c) `SaropaContext._wrapCallback` lazily invokes this loader on the first visitor call that has a usable file path — the real project root is derived via `ProjectContext.findProjectRoot(filePath)` (walks up to nearest `pubspec.yaml`). This piggyback is essential for severity-override, rule-pack, and baseline features to work in the IDE-launched path. (d) `_loadDiagnosticsConfig` now logs via `developer.log` when `analysis_options.yaml` is missing or lacks a `plugins > saropa_lints > diagnostics:` block, so the "plugin loaded but silent" failure mode is observable. New test suite `test/native/config_loader_project_root_test.dart` exercises the project-root-aware loader; the existing `saropa_plugin_registration_test.dart` was updated to match the new "register all, let analyzer filter" semantics. ([saropa_lints.dart](lib/saropa_lints.dart), [config_loader.dart](lib/src/native/config_loader.dart), [saropa_context.dart](lib/src/native/saropa_context.dart))

### Added

- **User-visible plugin log at `reports/.saropa_lints/plugin.log`** so consumers can see what the analyzer plugin is doing without spelunking `%LOCALAPPDATA%\.dartServer\logs\` (Windows) or `~/.dartServer/logs/` (macOS/Linux). The new [PluginLogger](lib/src/native/plugin_logger.dart) buffers log events emitted before the project root is known (during `Plugin.start()` — see the FATAL fix above for why the root isn't known at that point), then flushes them to disk as soon as `SaropaContext._wrapCallback` resolves the real project root on the first analyzed file. Every significant plugin event now writes a line the user can tail: `Plugin.start() — loading initial config`, `Plugin.register() — registering rules with analyzer`, `registerSaropaLintRules: registered N rules (M candidates, K disabled)`, `Config loaded from <path> — enabledRules: N`, and every silent-failure path in [config_loader.dart](lib/src/native/config_loader.dart) (missing `analysis_options.yaml`, missing `plugins > saropa_lints > diagnostics:` block, I/O errors). Logs are best-effort — write failures are swallowed so a read-only filesystem or permission issue cannot kill the analysis isolate. `developer.log` mirroring is preserved for CI log harvesting. New unit tests in [plugin_logger_test.dart](test/native/plugin_logger_test.dart) cover: buffering before root, flush on root, post-root direct-to-disk, idempotent setProjectRoot (first root wins), empty-root no-op, error + stack trace formatting. ([plugin_logger.dart](lib/src/native/plugin_logger.dart), [config_loader.dart](lib/src/native/config_loader.dart), [saropa_context.dart](lib/src/native/saropa_context.dart), [main.dart](lib/main.dart), [saropa_lints.dart](lib/saropa_lints.dart))

- **Rule `prefer_listenable_builder`** (Recommended tier, INFO): Flags `AnimatedBuilder(animation: <plainListenable>, ...)` and recommends `ListenableBuilder` instead. The rule only fires when the analyzer can resolve the `animation:` argument's static type and that type implements `Listenable` but is not a subtype of `Animation` — so `AnimationController`, `CurvedAnimation`, `Tween.animate(...)` results, and custom `Animation` subclasses are correctly left alone. `ValueNotifier`, `ChangeNotifier`, and custom `Listenable` implementations trigger the migration hint. Ships a one-token quick fix that renames the constructor (the two widgets share the same `animation:`/`builder:`/`child:` parameter surface). Runtime-gated by `ProjectContext.flutterSdkAtLeast(3, 13, 0)` so projects pinned below Flutter 3.13 (when `ListenableBuilder` was added) are silently skipped. Promoted from [plan/054](plan/054-prefer_listenable_builder_over_animated_builder.md). ([animation_rules.dart](lib/src/rules/ui/animation_rules.dart), [prefer_listenable_builder_fix.dart](lib/src/fixes/animation/prefer_listenable_builder_fix.dart))
- **`ProjectContext.flutterSdkAtLeast(filePath, major, minor, patch)`** — new helper that parses `environment.flutter` from `pubspec.yaml` and returns whether the project's declared minimum Flutter SDK is ≥ the requested version. Handles exact (`"3.13.0"`), caret (`"^3.13.0"`), range (`">=3.13.0 <4.0.0"`), and pre-release (`"3.13.0-0.0.pre"`) constraint forms; returns `true` (assume modern) for missing / `any` / unparseable constraints so rules still fire by default on unusual pubspec formats. Reusable gate for future SDK-migration lints. ([project_context_project_file.dart](lib/src/project_context_project_file.dart))
- **Extension:** Vibrancy report toolbar now has a **Copy All JSON** button that copies every row's full record — including all expander content (health factors with letter grade, full vulnerability list, every file reference, the complete transitive dependency list with shared markers, and pub.dev/repo links) — as a JSON array to the clipboard. The per-row JSON was also enriched with `health.grade`, `transitives.deps`, and `transitives.sharedDeps` so the single-row copy button produces the same shape. ([report-html.ts](extension/src/vibrancy/views/report-html.ts), [report-script.ts](extension/src/vibrancy/views/report-script.ts))
- **Extension:** Vibrancy report toolbar now has a **Rescan** button that runs `Package Vibrancy: Scan` without leaving the report. Previously, refreshing required opening the Command Palette; the button posts a `rescan` message to the host, which awaits the scan and then re-invokes `showReport` so the open panel picks up the fresh results in place. The button is disabled while a scan is in flight and reverts automatically when the webview rebuilds (with a 60s fallback for canceled scans). ([report-html.ts](extension/src/vibrancy/views/report-html.ts), [report-script.ts](extension/src/vibrancy/views/report-script.ts), [report-webview.ts](extension/src/vibrancy/views/report-webview.ts))
- **Extension:** New command `Open Another Project for Vibrancy Scan...` (`saropaLints.packageVibrancy.openOtherProject`) and matching **Open Project…** toolbar button on the Vibrancy report. Pops a file picker scoped to `pubspec.yaml`, then opens the selected file's parent folder in a new VS Code window via `vscode.openFolder` with `forceNewWindow: true`. Lets you diagnose multiple Flutter/Dart projects (e.g. compare transitive resolution across repos) without closing the current workspace — each window gets its own extension host and runs the scan against its local `pubspec.lock`, `.dart_tool`, and source tree. ([extension-activation.ts](extension/src/vibrancy/extension-activation.ts), [package.json](extension/package.json), [report-html.ts](extension/src/vibrancy/views/report-html.ts), [report-script.ts](extension/src/vibrancy/views/report-script.ts), [report-webview.ts](extension/src/vibrancy/views/report-webview.ts))

### Changed

- **Extension:** Vibrancy Command Palette entries are now consistently grouped under a single **`Saropa:`** category and renamed for brevity. Previously, typing "vibrancy" returned a grab-bag — one entry had a `Saropa Lints:` prefix (the auto-generated view-focus command), the rest had no prefix, and titles drifted between "Package Vibrancy", "Vibrancy Report", and "Vibrancy Scan". Now all palette-visible vibrancy commands share the `"category": "Saropa"` field and use short, consistent titles: `Scan Packages`, `Show Report`, `Export Report`, `Scan Another Project...`, `Clear Cache`, `Browse Known Issues`, `Export SBOM`, `Toggle Badges`. The redundant `Show Vibrancy Badges` and `Hide Vibrancy Badges` palette entries (which were already state-gated to show one at a time) are now hidden from the palette entirely — `Toggle Badges` is the sole entry for that function. No command IDs changed, so keybindings and external references continue to work. ([package.json](extension/package.json))
- **Extension:** Vibrancy report **Stars** column was replaced with **Likes** (pub.dev like count) and a new **Downloads** column (pub.dev `downloadCount30Days`). GitHub stars are a repository-level signal, so every package published out of a monorepo (e.g. `firebase/flutterfire`, `bloclibrary/bloc`, `flutter/packages`) reported an identical star count — which was misleading when comparing packages in the same project. Pub.dev likes and 30-day downloads are per-package, so the two new columns give a true package-specific trust signal. Both cells link to the package's pub.dev `/score` tab (e.g. `https://pub.dev/packages/crop_your_image/score`). Numbers use a compact format (`8.3M`, `1.2k`) with the full count in the cell tooltip. The per-row JSON (Copy Row / Copy All JSON) still surfaces the GitHub star count — now as a structured `stars: { count, repoUrl, monorepoSiblings }` block, where `monorepoSiblings` counts how many other packages in the same project share the repo URL (0 = dedicated repo, N > 0 = monorepo context so the raw count should be discounted). Row JSON also gained top-level `likes`, `downloadCount30Days`, and a `links.score` pub.dev score URL. ([report-html.ts](extension/src/vibrancy/views/report-html.ts), [pub-dev-api.ts](extension/src/vibrancy/services/pub-dev-api.ts), [types.ts](extension/src/vibrancy/types.ts))
- **Extension:** Vibrancy report **Update** column is now right-aligned, matching the other numeric/compact columns (Likes, Downloads, Issues, PRs, Size, References, Transitives, Deps). Both the update-arrow cells (e.g. `\u2192 2.0.0`) and the dimmed en-dash placeholder now align on the right edge. ([report-html.ts](extension/src/vibrancy/views/report-html.ts))

### Fixed

- **Extension:** Vibrancy report **References** column no longer double-counts a source file when it both imports and re-exports the same package. Example: `lib/utils/system/share_utils.dart` contains both `import 'package:share_plus/share_plus.dart';` (internal use) and `export 'package:share_plus/share_plus.dart' show XFile, ShareResult, ShareResultStatus;` (public API re-export). The import scanner previously emitted one `PackageUsage` per directive, so the cell rendered `2` even though only one physical file references the package. The scanner now merges same-file usages into a single entry keyed by `(filePath, isCommented)`, with the directive locations split into new `importLine` and `exportLine` fields on `PackageUsage`. The References cell tooltip, detail section, package detail panel, and both JSON exports (`Copy All JSON` on the toolbar and the markdown/JSON `report-exporter`) now show both line numbers — e.g. JSON `files: [{ "path": "lib/utils/system/share_utils.dart", "import": 7, "export": 1 }]` — while the file-level count stays accurate. ([import-scanner.ts](extension/src/vibrancy/services/import-scanner.ts), [report-html.ts](extension/src/vibrancy/views/report-html.ts), [package-detail-html.ts](extension/src/vibrancy/views/package-detail-html.ts), [report-exporter.ts](extension/src/vibrancy/services/report-exporter.ts))
- **Extension:** Vibrancy report and Known Issues search boxes now trim leading/trailing whitespace from the query, and each gained an inline clear (×) button that appears as soon as there is text in the field. Clicking the × empties the input, re-runs the filters, and returns focus to the search box. Pasting a package name from a terminal, pubspec excerpt, or wrapped text list previously swallowed all matches because the row data values have no surrounding whitespace, while the search compared the raw input — copy-paste now works regardless of surrounding spaces, tabs, or newlines. ([report-html.ts](extension/src/vibrancy/views/report-html.ts), [report-script.ts](extension/src/vibrancy/views/report-script.ts), [report-styles.ts](extension/src/vibrancy/views/report-styles.ts), [known-issues-html.ts](extension/src/vibrancy/views/known-issues-html.ts), [known-issues-script.ts](extension/src/vibrancy/views/known-issues-script.ts))
- **Extension:** Vibrancy report header gauge now actually fills to its target arc length. The static CSS rule `.gauge-fill { stroke-dasharray: 0 999 }` was overriding the inline SVG `stroke-dasharray` attribute (CSS rules trump SVG presentation attributes), so the gauge always rendered empty even when the project grade was B/C/D/E. The inline `--gauge-target` / `--gauge-arc` CSS variables set on the `<circle>` are now consumed by the rule, and the load-time fill animation moved to a `@keyframes` so the resting state actually paints. ([report-styles.ts](extension/src/vibrancy/views/report-styles.ts))
- **Extension:** Violations view file rows now open the file on click. Previously each `FileItem` only set `resourceUri`, so clicking the filename merely toggled the row's expand/collapse state; a `vscode.open` command is now attached when the file exists on disk, so the row opens the file directly while the expand triangle still shows the per-line violations. Moved/deleted files remain non-clickable (the existing "(file moved or deleted)" tooltip already explains the stale state, and attempting to open a missing file would surface a confusing error). ([issuesTree.ts](extension/src/views/issuesTree.ts))

<details>
<summary>Maintenance</summary>

- **Plan housekeeping (`plan/deferred/`):** Reviewed all 66 auto-generated SDK release-note plans (`005-*.md` through `134-*.md`). Only one — #054 (`prefer_listenable_builder_over_animated_builder`) — had a defensible detection path; promoted it to [`plan/054-prefer_listenable_builder_over_animated_builder.md`](plan/054-prefer_listenable_builder_over_animated_builder.md) with full detection strategy, quick-fix plan, SDK-gate note (Flutter 3.13+), and false-positive guards (must not fire on `Animation` subtypes). The other 64 files — Flutter engine/tooling internals, CI/build infra, docs-only notes, Dart-Code VS Code extension features, and deprecations already covered by `deprecated_member_use` — were archived verbatim (via `git mv`) into [`plan/deferred/_archive/`](plan/deferred/_archive/). Nothing was deleted; original PR descriptions and labels are preserved.
- **Plan housekeeping (`plan/deferred/`):** Consolidated 66 individual plan files into a single landing doc at [`plan/deferred/sdk_release_notes_review.md`](plan/deferred/sdk_release_notes_review.md) with a verdict table grouped by rejection category and per-plan one-liner. Removed the redundant `plan/deferred/README.md` — its category-file index (`compiler_diagnostics`, `cross_file_analysis`, `external_dependencies`, `framework_limitations`, `unreliable_detection`, `not_viable`, `plan_additional_rules_41_through_50`) and the "before adding a new entry" checklist were folded into the review doc so there is one landing page instead of two.
- **Publish script:** Pre-publish audit no longer auto-aborts when British English spellings are found. The spelling check now prints the report and prompts **[R]etry** (re-scan after fixing) or **[I]gnore** (continue the publish with the hits in place). Default on empty input is Retry, the safer option; Ctrl+C still aborts. Previously the only recourse was "fix every hit then re-run the entire 30-second audit" — minor user-facing copy could block a release even when the spelling was intentional (e.g. quoting a third-party API, product-name casing). When the user chooses Ignore, the consolidated audit reports the check as a ⚠ warning (not ✗ fail) so the decision is visible in the run log; when Retry is chosen, the script rescans in-place without re-running any other audit step. ([_publish_steps.py](scripts/modules/_publish_steps.py))
- `scripts/publish.py` — display the Saropa logo before prompting for the publish mode. The interactive menu (`Full publish`, `Audit only`, etc.) was printed before `show_saropa_logo()`, violating the "logo always comes first" rule for Saropa scripts. `main()` now accepts `mode=None` and prompts interactively after setup + logo; `__main__` just calls `main()`.
- **Tests:** Harden the teardown of the `use_existing_variable` integration test ([test/code_quality_rules_test.dart](test/code_quality_rules_test.dart)) against a Windows-only flake. The test creates a temp package under `build\test_tmp\`, spawns `dart pub get` + `dart analyze` subprocesses, then deletes the temp directory in `addTearDown`. On Windows, directory handles from the exited subprocesses can linger briefly after `Process.run()` returns, so `Directory.delete(recursive: true)` would fail with `PathAccessException: ... errno = 32` (EBUSY) and error the test even though all assertions passed. The teardown now retries up to 5 times with exponential backoff (100 ms → 1600 ms) and swallows the final failure — leaving a temp dir is harmless because the OS cleans `%TEMP%` and `build/test_tmp/` eventually, and a cleanup race should never fail an otherwise-passing test.

</details>

---

## [12.2.1]

Publish script now verifies Marketplace and Open VSX separately, so an expired Marketplace token surfaces a concrete ACTION REQUIRED warning and auto-opens the manage page instead of a silent 0-exit. — [log](https://github.com/saropa/saropa_lints/blob/v2.2.1/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- **Publish script (`scripts/publish.py`):** Store-publication verification now reports Marketplace and Open VSX results separately. When the Marketplace times out on the expected version, the script prints an `ACTION REQUIRED` warning with the manage URL (<https://marketplace.visualstudio.com/manage/publishers/Saropa>) and the exact `.vsix` filename to upload, then auto-opens the manage page in the default browser. Open VSX failures surface their own warning. Motivating case: `vsce publish` exiting 0 while the Marketplace never actually serves the new version (expired PAT / missing scope).

</details>

---

## [12.2.0]

Letter-only grading for package vibrancy across the report and detail views, plus a new "true footprint" view that links shared dependency size into per-package cost. — [log](https://github.com/saropa/saropa_lints/blob/v12.2.0/CHANGELOG.md)

### Added

- **Quick fixes (Batch 12):** Added 10 new quick fixes (9 new producers, 1 reuse) for previously fix-less rules:
  - `avoid_redundant_positional_field_name` (record_pattern) — deletes the redundant `$N` name from a positional record field.
  - `prefer_wildcard_pattern` (record_pattern) — replaces an unused pattern variable name (`unused`, `ignore`, …) with `_`.
  - `prefer_wildcard_for_unused_param` (naming_style) — renames an unused positional parameter to the `_` wildcard.
  - `avoid_non_null_assertion` (type_safety) — reuses the existing `RemoveNullAssertionFix` to strip the `!` operator.
  - `prefer_const_constructor_declarations` (class_constructor) — inserts `const` before a generative constructor.
  - `prefer_const_constructors_in_immutables` (class_constructor) — inserts `const` on the first non-const generative constructor in an @immutable / Widget class.
  - `prefer_final_fields` and `prefer_final_fields_always` (class_constructor) — adds `final` to a mutable instance field (replacing a leading `var` when present).
  - `avoid_double_and_int_checks` (control_flow) — rewrites `x is int || x is double` / `&&` to the equivalent `x is num` check.
  - `deprecated_new_in_comment_reference` (documentation) — strips the deprecated `new ` keyword from `[new Foo]` doc references.
- **Rule:** `prefer_type_sync_over_is_link_sync` (WARNING, Recommended tier) — flags static `FileSystemEntity.isLinkSync(path)` calls, which return `false` unconditionally on Windows per documented `dart:io` behavior and silently break cross-platform symbolic-link checks. Suggests the portable replacement `FileSystemEntity.typeSync(path, followLinks: false) == FileSystemEntityType.link`. Plan #079.
- **Rule:** `avoid_removed_js_number_to_dart` (WARNING, Recommended tier) — flags the removed `JSNumber.toDart` getter from `dart:js_interop` (Dart SDK 3.2). Surfaces a more actionable migration message than the analyzer default, directing developers to the type-explicit `toDartDouble` (floating-point) or `toDartInt` (integer) getters. No auto-fix because the numeric target type is a semantic choice. Plan #090.
- **Extension:** Footprint-mode toggle (Own / + Unique / + All) in the vibrancy report toolbar — switches what the Size column shows: the package's own archive (default), own + transitives used only by this dep (the size you'd save by removing it), or own + all transitives including ones shared with other direct deps. Sorting by Size respects the active mode.
- **Extension:** "True Footprint" row in the package detail panel — for any direct dep with transitives, surfaces the breakdown as `unique &middot; +shared = total` with a tooltip explaining how much disappears if you remove the dep vs. how much stays pulled in by other deps. Lets you spot cases like `crop_your_image` where the bulk of the size comes from a shared `image` transitive.
- **Extension:** `TransitiveInfo.uniqueTransitiveSizeBytes` and `sharedTransitiveSizeBytes` fields, computed in `enrichTransitiveInfo` from the per-package archive sizes already gathered during scan.
- **Extension:** Re-export awareness throughout the vibrancy report. Each `PackageUsage` now carries an `isExport: boolean` flag. The Single-use summary card excludes packages whose only reference is a `export 'package:...'` directive (they're public-API surface, not removable). The detail panel tags individual re-export lines with a "re-export" badge and a "public API surface" header note. The report row's References cell shows a "↪" badge after the count and prepends a warning to its tooltip when re-exported, and the muted single-use styling no longer applies to re-exports. `hasActiveReExport()` helper exposed alongside `activeFileUsages()`.
- **Extension:** Startup-scan skip-gate. The package vibrancy scan that runs on every VS Code restart now persists a fingerprint of the last successful scan (sha256 of pubspec.lock + scoring weights/allowlist/repo-overrides/publisher-trust-bonus, plus the result snapshot). On the next startup, when the lock file and scan-config inputs are unchanged AND the prior scan finished within the configured skip window, results are silently rehydrated and the progress notification is suppressed. Falls back to a normal scan on any cache miss, schema mismatch, malformed blob, or clock skew.
- **Extension:** New setting `saropaLints.packageVibrancy.startupScanSkipTtlMinutes` (default 60, min 0, max 10080 = one week). Skip-window for the startup scan in minutes. Set to `0` to always run the startup scan and disable skipping entirely.
- **Extension:** New setting `saropaLints.packageVibrancy.showStartupScanSkipStatusBar` (default false). When the startup scan is skipped, briefly show a status bar item (`✓ Vibrancy: cached (Nm)`) so users notice the skip; clicking it triggers a fresh scan. Off by default — silent rehydrate is the point.
- **Extension:** Existing `saropaLints.packageVibrancy.cacheTtlHours` setting (declared but previously unused) is now wired to `CacheService` so the per-package pub.dev/GitHub response cache TTL honors the user's configured value (default 24 hours).
- **Extension:** Clear Cache command (`saropaLints.packageVibrancy.clearCache`) now also clears the persisted last-scan fingerprint so the next startup performs a fresh scan instead of silently rehydrating stale cached results.

### Fixed

- **Extension:** Vibrancy report column headers no longer wrap to two lines when many optional columns are visible. Headers, right-aligned numeric cells, and the footprint-mode toggle buttons now use `white-space: nowrap` so each value stays on a single line.
- **Extension:** Vibrancy report version-age suffix no longer shows `(new)` for packages published within the last month. The label was misleading (a recently published version of a mature package isn't "new") and didn't carry useful information, so the suffix is now omitted entirely under one month.

### Changed

- **Extension:** Vibrancy report Category column now shows the letter grade badge only — the category label ("Vibrant", "Stable", etc.) and the dimmed `(n/10)` suffix were removed. Full label and score breakdown remain available via the hover tooltip.
- **Extension:** Report summary filter cards (Vibrant/Stable/Outdated/Abandoned/End-of-Life) now display the grade letter (A/B/C/E/F) as their label. The full category name moved to a `title` tooltip on each card.
- **Extension:** Report average-score summary card renamed to "Project Package Grade" and now shows a single letter derived from the average vibrancy score, replacing the old `n/10` value.
- **Extension:** Radial gauge in the report header now displays the project package grade letter instead of the `n` / `/10` stack. Tooltip label updated to "Project Package Grade".
- **Extension:** Sidebar detail view header replaced the `n/10` score pill plus standalone category-badge with a single letter pill. Category name is surfaced via the pill's `title` tooltip.
- **Extension:** Package detail panel header badge (top-right) now shows the letter grade only; the `n/10` score and inline category label were dropped (label moved to the title tooltip).
- **Extension:** Expanded row "Health Score" detail card dropped the redundant "Overall" numeric row — the aggregate is already shown as the letter badge in the card header; the factor rows (Resolution Velocity, Engagement Level, Popularity, Publisher Trust) remain.
- **Extension:** Health breakdown tooltip (shown on hover over a row's grade cell) now leads with "Grade: X" instead of "Vibrancy Score: n/10". Factor rows unchanged.
- **Extension:** CodeLens titles changed from "emoji n/10 Label" to "emoji X" (letter). The `indicatorStyle: text` variant now shows only the text indicator since a letter next to the text label was redundant; `indicatorStyle: none` shows the letter alone.
- **Extension:** pubspec hover tooltips show "**X** Category" (letter + label) in place of "**n/10** Category". Alternatives list shows "(X)" per alt (letter derived from the alt's score via `scoreToGrade`).
- **Extension:** Diagnostic messages trail with "(X)" (grade letter) instead of "(n/10)". Applies to Review/Monitor/Deprecated verbs and to blocker annotations.
- **Extension:** Vibrancy tree view blocker row switched from "score (category)" to a single letter grade. Alternatives group shows "(X)" per suggestion.
- **Extension:** Package comparison view row renamed "Vibrancy Score" → "Vibrancy Grade"; cell displays the letter derived from the 0-100 score (ranking still uses the numeric score so ordering stays precise).
- **Extension:** Markdown report export renamed the "Score" column to "Grade" and displays the letter. The JSON sibling preserves the numeric `health.score` field unchanged so downstream automation keeps working.
- **Extension:** Budget-exceeded message for the `minAverageVibrancy` rule now reads "Project Package Grade X is below minimum Y" instead of showing `n/10` actual vs limit.
- **Extension:** DetailLogger output channel prints "name — X (Category)" and "Blocker grade: X" instead of `n/10` forms.
- **Extension:** New `scoreToGrade(score)` helper in `category-dictionary.ts`, re-exported from `status-classifier`, providing a single source of truth for score-to-letter thresholds used by the gauge, summary card, alternatives, comparison view, and budget messages.

---

## [12.1.0]

Vibrancy report gets a radial health gauge, A–F letter grade badges, expandable detail cards with score breakdowns, keyboard navigation, and a new Deps column highlighting shared transitives. — [log](https://github.com/saropa/saropa_lints/blob/v12.1.0/CHANGELOG.md)

### Added

- **Extension:** Report renamed from "Package Vibrancy Report" to "Saropa Package Vibrancy" with the extension version shown as dimmed text next to the title.
- **Extension:** Animated radial gauge in the report header (floating top-right) showing the overall project health score on a color-coded 270-degree arc that fills on load.
- **Extension:** Letter grade badges (A through F) in the Category column, synced with the extension's category dictionary (A=Vibrant, B=Stable, C=Outdated, E=Abandoned, F=End-of-Life). Displayed as color-coded pill badges alongside the category label.
- **Extension:** Expandable detail cards — click any row (or press Enter with keyboard focus) to reveal an inline card with score breakdown, vulnerability list, file references, transitive dependency cloud, and external links. Collapse with a second click or Escape.
- **Extension:** Keyboard navigation in the report table — arrow keys (or j/k) move a visible focus highlight between rows, Enter/Space toggles expansion, Escape collapses all.
- **Extension:** New "Deps" column showing transitive dependency count per package with a tree icon. Shared dependencies are highlighted with a badge, and a tooltip lists all transitives with shared ones marked.
- **Extension:** Detail card dependency cloud highlights shared transitive deps in bold with a "shared" badge, so blast-radius of package removal is immediately visible.

### Fixed

- **Extension:** Radial gauge grade thresholds now match the category classifier boundaries (>=70 Vibrant/A, >=40 Stable/B, >=20 Outdated/C, <20 Abandoned/E) instead of diverging display-score thresholds.
- **Extension:** Table sorting now keeps detail rows paired with their parent package row. Previously, sorting would break the pairing and cluster orphaned detail rows together.
- **Extension:** Table filtering now correctly hides detail rows when their parent row is filtered out, preventing orphaned expanded cards from remaining visible.

---

## [12.0.3]

Upgrade plans skip git, path, and SDK deps that can't be bumped, surface real error reasons instead of "pub get failed", and keep going to the next package when one step fails. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.3/CHANGELOG.md)

### Fixed

- **Extension:** Upgrade plan no longer includes git, path, or SDK dependencies that cannot be upgraded via version constraint bump. Previously these would appear in the plan and immediately fail with an unhelpful "pub get failed" message.
- **Extension:** Upgrade report now shows the actual error reason (e.g. version conflict details) instead of just "pub get failed" or "flutter test failed".
- **Extension:** Upgrade plan continues to the next package after a step failure instead of halting the entire plan. Each failed step rolls back independently so subsequent packages still get attempted.

---

## [12.0.2]

Size Distribution chart splits unique vs shared transitives (with an "Exclude shared" toggle) so you can spot when a package's apparent weight is really deps you already carry. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.2/CHANGELOG.md)

### Added

- **Extension:** Size Distribution chart now separates transitive dependencies into distinct "Unique transitives" and "Shared transitives" segments instead of burying them in a single "Other" bucket. Unique transitives are the real cost of adding a package — shared transitives are already pulled in by other direct deps. A new "Exclude shared" checkbox hides shared transitive segments from both charts and the table, recalculating percentages for the remaining packages. This makes inflated size reports (e.g. a 63 MB package whose weight is entirely from a dep you already carry) immediately visible.
- **Extension:** Report renamed from "Package Vibrancy Report" to "Saropa Package Vibrancy" with the extension version shown as dimmed text next to the title.
- **Extension:** Animated radial gauge in the report header (floating top-right) showing the overall project health score on a color-coded 270-degree arc that fills on load.
- **Extension:** Letter grade badges (A through F) in the Category column, synced with the extension's category dictionary (A=Vibrant, B=Stable, C=Outdated, E=Abandoned, F=End-of-Life). Displayed as color-coded pill badges alongside the category label.
- **Extension:** Expandable detail cards — click any row (or press Enter with keyboard focus) to reveal an inline card with score breakdown, vulnerability list, file references, transitive dependency cloud, and external links. Collapse with a second click or Escape.
- **Extension:** Keyboard navigation in the report table — arrow keys (or j/k) move a visible focus highlight between rows, Enter/Space toggles expansion, Escape collapses all.
- **Extension:** New "Deps" column showing transitive dependency count per package with a tree icon. Shared dependencies are highlighted with a badge, and a tooltip lists all transitives with shared ones marked.
- **Extension:** Detail card dependency cloud highlights shared transitive deps in bold with a "shared" badge, so blast-radius of package removal is immediately visible.

---

## [12.0.1]

New users get a prominent "Set Up Project" banner in the Overview sidebar (and an activation toast) when `saropa_lints` isn't yet in `pubspec.yaml`, so the setup action is one click away. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.1/CHANGELOG.md)

### Changed

- **Extension:** Prominent "Set Up Project" banner at the top of the Overview sidebar when `saropa_lints` is not yet in `pubspec.yaml` — new users no longer have to hunt for the setup action
- **Extension:** Auto-detect notification on activation when a Dart project lacks `saropa_lints`, offering one-click setup directly from the toast

---

## [12.0.0]

Rolled back from analyzer 12 to analyzer 11 — analyzer 12 requires `meta ^1.18.0` but Flutter stable (3.41.6 / Dart 3.11.4) pins `meta` to `1.17.0`, which made saropa_lints `>=10.3.0` unresolvable for every Flutter project on stable. The pub solver would reject the package outright with a `meta` version conflict. This downgrade restores compatibility with Flutter stable while keeping all 2134 rules and 254 quick fixes intact.  — [log](https://github.com/saropa/saropa_lints/blob/v12.0.0/CHANGELOG.md)

### Fixed

- **Critical:** Downgrade `analyzer` from `^12.0.0` to `>=9.0.0 <12.0.0` — analyzer 12 requires `meta ^1.18.0` which conflicts with Flutter stable's pinned `meta 1.17.0`, making saropa_lints unresolvable for all Flutter consumers (see `bugs/infra_meta_pin_flutter_incompatible.md`)
- Downgrade `analyzer_plugin` from `^0.14.7` to `>=0.11.0 <0.14.7` for analyzer 11 compatibility
- Add `ClassBodyMembersCompat` extension to bridge analyzer 11's sealed `ClassBody` (where `.members` is only on `BlockClassBody`, not the base type)


---

## [11.1.0]

Ten new quick fixes — click the lightbulb and let the IDE rewrite `late`, `abstract final`, `unawaited()`, `toString()`, and more for you. — [log](https://github.com/saropa/saropa_lints/blob/v11.1.0/CHANGELOG.md)

### Added

- **Quick fix:** `unnecessary_library_name` — remove the library name, leaving bare `library;`
- **Quick fix:** `avoid_late_for_nullable` — remove the `late` keyword from nullable field/variable declarations
- **Quick fix:** `prefer_late_final` — change `late` to `late final` for single-assignment variables
- **Quick fix:** `prefer_abstract_final_static_class` — add `abstract final` modifiers to static-only classes
- **Quick fix:** `avoid_async_call_in_sync_function` — wrap unhandled Future call with `unawaited()`
- **Quick fix:** `avoid_default_tostring` — generate a `toString()` override listing all instance fields
- **Quick fix:** `missing_use_result_annotation` — add `@useResult` annotation before builder/factory methods
- **Quick fix:** `avoid_unnecessary_local_late` — remove `late` from immediately-initialized local variables
- **Quick fix:** `avoid_unnecessary_late_fields` — remove `late` from constructor-assigned fields
- **Quick fix:** `avoid_positional_boolean_parameters` — convert positional bool parameter to required named

### Changed

- **Quick fix:** `RemoveLateKeywordFix` now handles `VariableDeclarationStatement` nodes (used by `avoid_unnecessary_local_late`)

<details>
<summary>Maintenance</summary>
- **Security:**  Fix CVE in transitive dependency `serialize-javascript` (RCE via RegExp.flags and Date.toISOString) by adding npm `overrides` to pin `>=7.0.5`
</details>

---

## [11.0.0]

A major extension UX upgrade featuring a new searchable command catalog sidebar, embedded health dashboards, rich package details with logos and README images, unique vs. shared dependency breakdowns, and workspace-wide diagnostic suppression tracking. — [log](https://github.com/saropa/saropa_lints/blob/v11.0.0/CHANGELOG.md)

### Added

- **Extension:** Commands sidebar section — a searchable, always-visible index of every extension command as the first sidebar section. Includes recent command history and one-click execution. The full editor-tab catalog remains available via the "Open full catalog" link.
- **Extension:** Overview now embeds Health Summary, Next Steps, and Riskiest Files groups directly — users see violation breakdowns, prioritized actions, and risky files without enabling standalone sidebar sections. Clicking items filters the Violations view. Standalone sections remain available for users who prefer dedicated views.
- **Extension:** Package Details sidebar section now defaults to visible — it only appears when a Vibrancy scan has results (gated by the existing `when` clause), so no clutter for users who haven't scanned.
- **Extension:** Vibrancy scoring now includes an ecosystem adoption bonus based on reverse dependency count — how many published packages on pub.dev depend on a given package. Packages with dependents get a score boost (up to +10 points on a logarithmic curve); packages with zero dependents are unaffected (bonus-only, no penalty). The count is displayed in the Community group of the tree view, sidebar detail, and full detail panel with a clickable link to the pub.dev search results.
- **Extension:** Package detail panel and sidebar now show package description (truncated with "read more" link), topic badges linking to pub.dev topic search, likes count in the Community section, direct dependencies as clickable chips, and a Documentation link to the pub.dev API reference.
- **Extension:** Package detail panel and sidebar now show the package logo (first non-badge image from README) in the header and a README Images gallery section. Both are lazy-loaded from the GitHub API when the detail panel opens. HTTP-only images are filtered out to prevent silent CSP failures.
- **Extension:** Package detail and sidebar CSP updated to allow HTTPS images for logo and README screenshots.
- **Plugin:** Suppression tracking — every diagnostic silenced by `// ignore:`, `// ignore_for_file:`, or baseline is now recorded as a full `SuppressionRecord` (rule, file, line, kind). Records are included in batch data for cross-isolate merging, deduplicated with normalized paths, and exported in `violations.json` with `byKind`, `byRule`, and `byFile` breakdowns. Counts appear in the console summary log and the extension Overview tree. Foundation for Discussion #56 suppression audit trail.

### Changed

- **Extension:** Size Distribution chart in the vibrancy report now has an "Include transitives" checkbox. Unchecking it hides transitive packages from both the bar chart and donut chart, recalculating percentages for direct dependencies only. Helps identify whether a package's apparent size is real or inflated by shared transitive weight.
- **Extension:** Package Vibrancy tree now shows unique vs shared transitive dependency breakdown in the Dependencies group. Shared transitives are already in the project via other direct deps — only unique transitives represent added weight. Package rows show a compact `N% shared` indicator so misleading size reports (e.g. a 63MB package whose weight is entirely from a dep you already carry) are immediately visible.
- **Extension:** Package detail sidebar webview now includes a Dependencies section with a visual unique/shared bar, counts, and shared dependency names.
- **Extension:** Package Vibrancy tree row inline icons replaced: removed redundant go-to-file icon (row click already navigates) and added Copy as JSON (`$(clippy)`) and Focus Details (`$(preview)`) inline actions.
- **Extension:** File Risk section moved above Violations in the sidebar so it acts as a natural file selector before the detail view.
- **Extension:** File Risk summary replaced the confusing "Top N files have X% of critical issues" label with a flat breakdown: file count, critical, high, and other counts.
- **Extension:** Clicking a file in the File Risk tree now opens the file in the editor (in addition to filtering the Violations view).
- **Extension:** File Risk tree now has a Copy All toolbar button (clipboard icon) for copying the full tree as JSON.
- **Extension:** File Risk file items now have right-click context menu actions: Show Violations for File, Hide File, Copy Path, and Copy as JSON.
- **Extension:** File Risk summary node is now clickable — opens all violations in the Violations view.
- **Extension:** File Risk tree now respects view-level suppressions from the Violations view (hidden folders, files, rules, severities, and impacts).
- **Extension:** File Risk tree shows a "Scanned Xd ago" timestamp node at the bottom. When scan data is older than 24 hours, the node shows a warning icon and clicking it runs analysis to refresh.
- **Extension:** All tree views (Violations, File Risk, Summary, Security Posture, Suggestions) now respect rules disabled in `analysis_options.yaml` (`diagnostics:` section) and `analysis_options_custom.yaml` (`RULE OVERRIDES` section). Violations for disabled rules are automatically hidden even when `violations.json` is stale.
- **Extension:** Right-clicking a violation in the Violations tree now offers "Disable rule(s)" to persistently disable the rule via `analysis_options_custom.yaml`, in addition to the existing view-level "Hide Rule" suppression.
- **Extension:** Package Vibrancy tree items now show the category label in parentheses (e.g. `(Stable)`, `(Outdated)`) instead of the verbose `3/10 — Outdated — 1 problem` format, consistent with the vibrancy report terminology. The full score remains in the hover tooltip and detail views.
- **Extension:** Group node counts now use brackets (e.g. `Dependencies [5]`) instead of parentheses for visual distinction from the grade.
- **Extension:** "Source" node renamed to "Source Code" with a shorter description (e.g. `2.5k lines, 18 files`). Full detail shown in tooltip. Double-clicking opens the package's local source folder.
- **Extension:** Hover tooltip in pubspec.yaml now includes all information from the detail panel — version, community stats, size, file usages, alerts, vulnerabilities, platforms, alternatives, and action items. Footer links include pub.dev, Changelog, Versions, Repository, Open Issues, and Report Issue.
- **Extension:** Links in the package detail panel and sidebar detail view now render as underlined hyperlinks for discoverability. Added direct links to Changelog, Versions, Open Issues, and Report Issue alongside existing pub.dev and Repository links.

### Fixed

- **Extension:** Violations tree file items no longer expand to empty. `getChildren()` re-read `violations.json` on every expansion — if the file was temporarily unavailable (write lock during scan, concurrent rewrite), the early-return guards returned `[]` before reaching the file-item handler. File and group nodes now resolve from their embedded data before any disk read, so already-loaded children survive a transient I/O hiccup.
- **Extension:** Pubspec validation no longer shows duplicate diagnostics on startup. `onDidOpenTextDocument` fires retroactively for already-loaded documents, and the `visibleTextEditors` loop covered them again — deduplicating the initial sync prevents `update()` from running twice for the same file.
- **Extension:** `stale-override` no longer false-positives on overrides that resolve SDK-pinned transitive conflicts (e.g. `meta: 1.18.0` when `flutter_test` pins `1.17.0` but `analyzer ^12` requires `^1.18.0`). The override analyzer now compares the overridden version against the dep-graph resolved version — if they differ, the override is classified as active.


<details>
<summary>Maintenance</summary>

- Consolidated 7 example fixture packages into 2 (`example/` and `example_packages/`). Merged `example_async`, `example_core`, `example_platforms`, `example_style`, and `example_widgets` into the main `example/` directory. Only `example_packages` remains separate (it requires the `bloc` dependency). Reduces pubspec/lockfile/analysis_options maintenance from 7 projects to 2.
</details>

---

## [10.12.2]

Pubspec inline suppression comments, l10n.yaml false-positive fix, and scan logger cleanup. — [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- **Extension:** Inline suppression for pubspec validation rules via `# saropa_lints:ignore <rule_code>[, ...]` comments. Place the directive on the line above (or inline after) a flagged entry to suppress specific diagnostics without disabling the rule globally. All 11 pubspec rules support suppression automatically.

### Fixed

- **Extension:** `prefer_l10n_yaml_config` no longer fires when `l10n.yaml` already exists alongside `pubspec.yaml`. Flutter tooling requires `generate: true` in pubspec even with a dedicated l10n config file — flagging it was a false positive.
- **Extension:** Package Vibrancy scan logger no longer creates a separate log file per scan. Scans are debounced (5 s after last `pubspec.lock` change), logs append to one file per day, and identical-result scans are skipped entirely.

---

## [10.12.1]

Publishing fix — removed stale publish_to field that blocked CI. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.1/CHANGELOG.md)

### Fixed

- **Publishing:** Removed `publish_to: "none"` from pubspec.yaml — the template placeholder blocked `dart pub publish` in CI. The field defaults to pub.dev when absent.

---

## [10.12.0]

False-positive fixes across hardcoded config, dependency ordering, adoption gate, and pubspec diagnostics; plus a help hub, comment-preserving sort, and command catalog refresh. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.0/CHANGELOG.md)

### Fixed

- **`avoid_hardcoded_config` (v5):** No longer reports URL/key-like string literals used as initializers for top-level `const` declarations or `static const` class fields. Those are the usual single-source-of-truth pattern; mutable `static final` / locals still warn.
- **`dependencies_ordering` (extension):** No longer flags SDK dependencies (`flutter`, `flutter_localizations`, `flutter_test`, `integration_test`) as out of alphabetical order when they appear before pub-hosted packages. SDK deps are now exempt from the alphabetical sort; only pub-hosted entries are checked.
- **Adoption Gate (extension):** No longer shows false "Discontinued" badge on SDK dependencies (`flutter`, `flutter_test`, `flutter_localizations`, `integration_test`, etc.). SDK packages are not hosted on pub.dev; looking them up produced misleading warnings because the pub.dev `flutter` placeholder is marked discontinued. Also fixed badge placement: `findPackageLine` now only matches within dependency sections, so badges no longer appear on `environment:` constraint lines.
- **`prefer_publish_to_none` (extension):** No longer flags packages that have `topics:`, `homepage:`, or `repository:` fields — these are pub.dev publication signals, so suggesting `publish_to: none` was a false positive on intentionally published packages.
- **Pubspec diagnostics (extension):** All 11 pubspec.yaml validation messages now include the `[saropa_lints]` prefix, matching the convention used by the Dart-side lint rules.
- **`isLintPluginSource` guard (infra):** The per-file guard that prevents rules from firing on their own source code was broken in the native analyzer model — it ran once at registration time, not per-file. Moved the check into `_shouldSkipCurrentFile()` so it evaluates per-file and removed the 43 dead per-rule guards across 12 rule files. Fixes 8 false positives from `avoid_ios_in_app_browser_for_auth` on its own OAuth URL pattern definitions, plus potential false positives in all other affected rule files.

### Added (Extension)

- **Help hub**: New “Saropa Lints: Help” command (`saropaLints.openHelpHub`) opens a quick pick for Getting Started, About, Browse All Commands, and pub.dev. **Overview** intro links are grouped under a permanent collapsible **Help & resources** tree section; the title bar shows only the Command Catalog icon (help is in the tree). **Violations** always shows a **Help & resources** row at the top when the tree has content, plus both Help and Command Catalog icons in the title bar.

### Fixed (Extension)

- **Pubspec sorter**: Comments that precede a dependency entry (description, changelog URL, version-pin notes) now travel with the entry during sorting instead of being stripped. Trailing decorative comment blocks (section dividers) at the end of a section are also preserved. Previously, running "Sort Dependencies" on a richly commented pubspec would silently delete all comments.

### Changed (Extension)

- **Command catalog**: Sidebar title actions on Overview and Violations open the catalog; Codicons load in the webview; recent command runs are stored for one-click replay with a clear control; UI refresh (hero header, cards, command IDs). **Toolbar trim**: fewer Package Vibrancy and Violations title-bar entries (secondary actions remain in the command palette and catalog). **Context menu**: removed “Log package details” from package rows. **Catalog UX**: categories ordered setup → analysis → violations → rules → security → reporting → vibrancy → …; entries sorted A–Z within each section; search indexes title, description, and command id (including spaced tokens); responsive layout for narrow panes.

<details>
<summary>Maintenance</summary>

- **SDK_PACKAGES (extension):** Consolidated three duplicate `SDK_PACKAGES` sets (annotate-command, unused-detector, pubspec-sorter) into a single shared constant at `sdk-packages.ts`. Added missing `integration_test` and `flutter_driver` entries to the pubspec-sorter set.
</details>

---

## [10.11.0]

New graph command for import visualization, a searchable command catalog in the extension, eleven pubspec validation diagnostics with quick fixes, and a batch of bug fixes. — [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- **cross_file graph command**: New `dart run saropa_lints:cross_file graph` command exports the import graph in DOT format for Graphviz visualization. Use `--output-dir` to control where `import_graph.dot` is written.

### Added (Extension)

- **Command catalog webview**: New "Saropa Lints: Browse All Commands" command opens a searchable, categorized catalog of every extension command (117 commands across 13 categories). Features instant text search, collapsible category sections, click-to-execute, and a toggle to reveal context-menu-only commands. Accessible from the command palette, welcome views, and the getting-started walkthrough.
- **Enablement audit**: Seven copy-as-JSON commands (`Copy Violations as JSON`, `Copy Config as JSON`, etc.) previously hidden from the command palette are now visible when a Dart project is open. Commands have unique titles so they are distinguishable in the palette.
- **Walkthrough expansion**: Three new getting-started walkthrough steps — Package Health (dependency scanning and SBOM), TODOs & Hacks (workspace-wide marker scanning), and Browse All Commands (command catalog).
- **Welcome view links**: Both welcome views (non-Dart project intro and no-analysis-yet prompt) now include a "Browse All Commands" link to the command catalog.
- **Pubspec validation diagnostics**: Eleven inline checks on `pubspec.yaml`, shown in the Problems panel and as editor squiggles:
  - `avoid_any_version` (Warning): Flags `any` version constraints in dependencies
  - `dependencies_ordering` (Info): Flags unsorted dependency lists
  - `prefer_caret_version_syntax` (Info): Flags bare version pins (`1.2.3`) — suggests caret syntax (`^1.2.3`)
  - `avoid_dependency_overrides` (Warning): Flags `dependency_overrides` entries without an explanatory comment
  - `prefer_publish_to_none` (Info): Flags pubspec files missing `publish_to: none` field
  - `prefer_pinned_version_syntax` (Info): Stylistic opposite of `prefer_caret_version_syntax` — flags caret ranges, prefers exact pins (opt-in)
  - `pubspec_ordering` (Info): Flags top-level fields not in recommended order (name, description, version, ...)
  - `newline_before_pubspec_entry` (Info): Flags top-level sections without a preceding blank line
  - `prefer_commenting_pubspec_ignores` (Info): Flags `ignored_advisories` entries without an explanatory comment
  - `add_resolution_workspace` (Info): Flags workspace roots missing `resolution: workspace` field
  - `prefer_l10n_yaml_config` (Info): Flags inline `generate: true` under flutter — suggests `l10n.yaml`
- `prefer_pinned_version_syntax` and `prefer_caret_version_syntax` are mutually exclusive stylistic rules — controlled via `saropaLints.pubspecValidation.preferPinnedVersions` setting (default: off = caret preferred). Changes take effect immediately on open pubspec files.
- **Quick-fix code actions** for 5 pubspec diagnostics: `prefer_caret_version_syntax` (add `^`), `prefer_pinned_version_syntax` (remove `^`), `prefer_publish_to_none` (insert field), `newline_before_pubspec_entry` (insert blank line), `add_resolution_workspace` (insert field). Available from the lightbulb menu and `Ctrl+.`.
- Diagnostics update live as you edit pubspec.yaml (300ms debounce). SDK/path/git dependencies and `dependency_overrides` are handled correctly.
- **Package vibrancy sort spacing**: Sort Dependencies now inserts blank lines between packages for readability. Related packages that share a common name prefix (e.g. `drift`, `drift_flutter`, `drift_dev`) are kept together without a separator. SDK packages are always separated from non-SDK packages.

### Fixed (Extension)

- **Duplicate annotation comments**: The annotate-packages feature could leave duplicate description comments above a dependency (e.g. two identical `# A composable, multi-platform...` lines) when re-run on a pubspec that already had annotations from a prior run. The scanner now removes all consecutive auto-description lines above a URL, not just the single closest one.

### Fixed

- **Sidebar section toggles not responding**: Clicking an "Off" sidebar toggle in Overview & options produced no feedback. Root cause: the `toggleSidebarSection` command was registered at runtime but not declared in `contributes.commands`, so VS Code silently ignored tree-item clicks. Added the command declaration and a `commandPalette` hide entry, and wrapped the handler in try/catch so config-update failures now surface as error notifications.
- **avoid_stream_subscription_in_field**: Fixed false positive when `.listen()` is inside a conditional block (`if`/`for`) and assigned to a properly-named subscription field. The parent-walk loop now stops at closure (`FunctionExpression`) boundaries to prevent escaping into outer scopes. **Note:** this also fixes false negatives where a bare `.listen()` inside a closure was incorrectly suppressed because an outer scope had a properly-named subscription assignment — those uncaptured subscriptions will now correctly fire the lint.
- **cross_file HTML reporter**: Fixed string interpolation bug in index page — file counts were rendered as list objects instead of numbers.
- **cross_file --exclude**: The `--exclude` glob flag is now applied to filter results. Previously it was parsed but silently ignored.

<details>
<summary>Maintenance</summary>

- **Unified pubspec.yaml listener**: Pubspec validation and SDK constraint diagnostics now share a single `registerPubspecDocListeners` helper with one debounce timer (300ms), eliminating duplicate event subscriptions. Includes error boundary — a pubspec validation failure does not block SDK diagnostics.
- **Internal**: `parseDependencySections()` now accepts a pre-split lines array, eliminating a duplicate `content.split('\n')` call per validation run.
- **Roadmap restructure**: Split deferred rules into focused documents in `plan/deferred/` by barrier type (cross-file, unreliable detection, external dependencies, framework limitations, compiler diagnostics, not viable). Trimmed ROADMAP.md to actionable content only. Moved cross-file CLI design to `plan/cross_file_cli_design.md`.
- **Bug Report Guide**: Added `bugs/BUG_REPORT_GUIDE.md` — structured template and investigation checklist for filing lint rule bugs (false positives, false negatives, crashes, wrong fixes, performance)
- **Changelog Archive**: Moved [9.9.0] and older logs to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md)
- **Plan history restore**: Restored 21 active plan/discussion/bug documents plus `deferred/` and `implementable_only_in_plugin_extension/` directories back to `plan/` root — these were incorrectly swept into `plan/history/` by the consolidation commit. Added `plan/history/INDEX.md` as a searchable index for the 1,069 history files.

</details>

---

## [10.10.0]

Ten new rules targeting deprecated APIs, performance traps, and migration gotchas across Dart and Flutter. — [log](https://github.com/saropa/saropa_lints/blob/v10.10.0/CHANGELOG.md)

### Added

- **prefer_isnan_over_nan_equality**: Flags `x == double.nan` (always false) and `x != double.nan` (always true) — use `.isNaN` instead (IEEE 754). Includes quick fix.
- **prefer_code_unit_at**: Flags `string.codeUnits[i]` which allocates an entire List just to read one code unit — use `string.codeUnitAt(i)` instead (Flutter 3.10, PR #120234). Includes quick fix.
- **prefer_never_over_always_throws**: Flags the deprecated `@alwaysThrows` annotation from `package:meta` — use `Never` return type instead (Dart 2.12+).
- **prefer_visibility_over_opacity_zero**: Flags `Opacity(opacity: 0.0, ...)` which inserts an unnecessary compositing layer — use `Visibility(visible: false, ...)` instead (Flutter 3.7, PR #112191).
- **avoid_platform_constructor**: Flags `Platform()` constructor usage deprecated in Dart 3.1 — all useful Platform members are static.
- **prefer_keyboard_listener_over_raw**: Flags deprecated `RawKeyboardListener` — use `KeyboardListener` which handles IME and key composition correctly (Flutter 3.18). Includes quick fix.
- **avoid_extending_html_native_class**: Flags extending native `dart:html` classes (`HtmlElement`, `CanvasElement`, etc.) which can no longer be subclassed (Dart 3.8 breaking change).
- **avoid_extending_security_context**: Flags extending or implementing `SecurityContext` from `dart:io` which is now `final` (Dart 3.5, breaking change #55786).
- **avoid_deprecated_pointer_arithmetic**: Flags deprecated `Pointer.elementAt()` from `dart:ffi` — use the `+` operator instead (Dart 3.3). Includes quick fix.
- **prefer_extracting_repeated_map_lookup**: Flags 3+ identical `map[key]` accesses in the same function body — extract into a local variable for readability and type safety (Flutter 3.10, PR #122178).

---

## [10.9.0]

Four new rules catching deprecated media query params, codec shorthand, a removed AppBar field, and iterable cast cleanup. — [log](https://github.com/saropa/saropa_lints/blob/v10.9.0/CHANGELOG.md)

### Added

- **prefer_iterable_cast**: Flags `Iterable.castFrom(x)` (and `List.castFrom`, `Set.castFrom`, `Map.castFrom`) and suggests the more readable `.cast<T>()` instance method (Flutter 3.24, PR #150185). Includes quick fix.
- **avoid_deprecated_use_inherited_media_query**: Flags the deprecated `useInheritedMediaQuery` parameter on `MaterialApp`, `CupertinoApp`, and `WidgetsApp` (deprecated after Flutter 3.7). The setting is ignored. Includes quick fix to remove the argument.
- **prefer_utf8_encode**: Flags `Utf8Encoder().convert(x)` and suggests the shorter `utf8.encode(x)` from `dart:convert` (Dart 2.18 / Flutter 3.16, PR #130567). Includes quick fix.
- **avoid_removed_appbar_backwards_compatibility**: Flags the removed `AppBar.backwardsCompatibility` parameter (removed in Flutter 3.10, PR #120618). Includes quick fix to remove the argument.

### Fixed

- **avoid_global_state**: Report diagnostic at declaration level instead of individual variable nodes to prevent wrong line numbers when doc comments precede the declaration

---

## [10.8.1]

Vibrancy report polish — better empty-cell display, smarter column layouts, and clickable package names. — [log](https://github.com/saropa/saropa_lints/blob/v10.8.1/CHANGELOG.md)

### Changed

- **Vibrancy Report**: Empty cells now show an em-dash with an explanatory tooltip instead of blank space (stars, published date, issues, PRs, size, license, description, and other optional columns)
- **Vibrancy Report**: Merged Health column into Category as a dimmed suffix, e.g. "Abandoned (1/10)"
- **Vibrancy Report**: Package name now opens pubspec.yaml at the dependency entry (was: pub.dev link) and shows description as tooltip
- **Vibrancy Report**: Published date now links to the pub.dev package page and shows the version age suffix (moved from Version column)
- **Vibrancy Report**: "Files" column renamed to "References" — click the count to search your workspace for that package's imports
- **Vibrancy Report**: Update column shows a dimmed en-dash instead of a checkmark when no update is available; all placeholder dashes are now dimmed
- **Vibrancy Report**: License and Description columns are now hidden by default (Description changed from icon to plain-text column)

---

## [10.8.0]

Vibrancy report gets GitHub issue and PR counts, plus a toolbar toggle for Drift Advisor integration. — [log](https://github.com/saropa/saropa_lints/blob/v10.8.0/CHANGELOG.md)

### Added

- **Vibrancy Report**: New "Issues" and "PRs" columns show open GitHub issue and pull request counts, linking directly to the repository's issues and pulls pages
- **Drift Advisor**: Toolbar toggle button in the Drift Advisor view — `$(plug)` enables integration, `$(circle-slash)` disables it. No more hunting through Settings to find `saropaLints.driftAdvisor.integration`.

---

## [10.7.0]

Vibrancy health categories renamed for clarity, report gains copy-as-JSON, file usage tracking, and clickable summary cards. — [log](https://github.com/saropa/saropa_lints/blob/v10.7.0/CHANGELOG.md)

### Changed

- **Vibrancy**: Renamed health categories for clarity — "Quiet" → **Stable**, "Legacy-Locked" → **Outdated**, "Stale" → **Abandoned**. Vibrant and End of Life are unchanged.
- **Vibrancy**: Raised Abandoned threshold from score <10 to score <20 so packages untouched for 4+ years with only bonus points are correctly flagged instead of escaping into Outdated
- **Vibrancy Report**: Overrides summary card is now clickable — filters the table to show only overridden packages
- **Vibrancy Report**: All table column headings now have tooltips explaining what each column represents (e.g. Published = "Date the installed version was published to pub.dev")

### Added

- **Vibrancy Report**: Copy-as-JSON button appears on row hover — copies a detailed JSON of all package fields and links to clipboard
- **Vibrancy Report**: New "Files" column shows how many source files import each package, with clickable file paths in the detail view that open at the exact import line
- **Vibrancy Report**: "Single-use" summary card filters to packages imported from only one file
- **Vibrancy Report**: Exported JSON and Markdown reports now include per-package file-usage data (file paths and line numbers)

### Fixed

- **Vibrancy Report**: Commented-out imports (e.g. `// import 'package:foo/foo.dart'`) are no longer counted as active usage for unused-package detection

### Breaking

- **Vibrancy Settings**: `budget.maxStale` renamed to `budget.maxAbandoned`; `budget.maxLegacyLocked` renamed to `budget.maxOutdated`. Users who customized these settings will need to update their config.
- **Vibrancy Exports**: JSON/Markdown export schemas use new category keys (`stable`, `outdated`, `abandoned` instead of `quiet`, `legacy_locked`, `stale`)
- **Generated CI scripts**: Previously generated CI workflows reference old threshold variable names. Regenerate after updating.

---

## [10.6.1]

Updated README screenshots. — [log](https://github.com/saropa/saropa_lints/blob/v10.6.1/CHANGELOG.md)

### Changed

Updated screenshots in [README.md](./README.md).

---

## [10.6.0]

Extension UX refinements — split workspace options into Settings and Issues sections, hide "Apply fix" for unfixable violations, and auto-expand violations tree on programmatic navigation. — [log](https://github.com/saropa/saropa_lints/blob/v10.6.0/CHANGELOG.md)

### Changed

- **Extension:** Overview sidebar splits the former "Workspace options" section into two focused sections: **Settings** (lint integration, tier, detected packages, config actions) and **Issues** (triage groups by violation count); Issues hides when no analysis data exists
- **Extension:** "Apply fix" context menu item is now hidden for violations without a quick fix, instead of showing a dead-end "No quick fix available" message
- **Extension:** Violations tree now auto-expands all levels when navigated to from settings, dashboard links, summary counts, or triage groups

### Fixed

- **Extension:** `rulesWithFixes` from `violations.json` was not extracted, causing all violations to appear fixable regardless of actual fix availability

---

## [10.5.0]

Replacement complexity metric — analyzes local pub cache to estimate feasibility of inlining, forking, or replacing each dependency; removed inline vibrancy summary diagnostic. — [log](https://github.com/saropa/saropa_lints/blob/v10.5.0/CHANGELOG.md)

### Added

- **(Extension)** Package Vibrancy: replacement complexity metric — analyzes local pub cache to count source lines in each dependency's `lib/` directory and classifies how feasible it would be to inline, fork, or replace (trivial / small / moderate / large / native). Shown in Size tree group, detail sidebar, and CodeLens for stale/end-of-life packages with feasible migration

### Changed

- **(Extension)** Removed the `vibrancy-summary` inline diagnostic from `pubspec.yaml` — the Package Vibrancy sidebar and report already surface this information. The `inlineDiagnostics` setting no longer offers a `"summary"` mode; the default is now `"critical"` (end-of-life packages only)

---

## [10.4.1] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 10.4.1.
