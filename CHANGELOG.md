# Changelog

```text
                                    ....
                             -+shdmNMMMMNmdhs+-
                          -odMMMNyo/-..``.++:+o+/-
                       /dMMMMMM/               `````
                      dMMMMMMMMNdhhhdddmmmNmmddhs+-
                      /MMMMMMMMMMMMMMMMMMMMMMMMMMMMMNh/
                    . :sdmNNNNMMMMMNNNMMMMMMMMMMMMMMMMm+
                    o     ..~~~::~+==+~:/+sdNMMMMMMMMMMMo
                    m                        .+NMMMMMMMMMN
                    m+                         :MMMMMMMMMm
                    /N:                        :MMMMMMMMM/
                     oNs.                    +NMMMMMMMMo
                      :dNy/.              ./smMMMMMMMMm:
                       /dMNmhyso+++oosydNNMMMMMMMMMd/
                          .odMMMMMMMMMMMMMMMMMMMMdo-
                             -+shdNNMMMMNNdhs+-
                                     ``

Made by Saropa. All rights reserved.

Learn more at https://saropa.com, or mailto://dev.tools@saropa.com
```

2100+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTENANCE NOTES -- IMPORTANT --

    Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/). Versioning: [SemVer](https://semver.org/spec/v2.0.0.html). Omit dates from headers; [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays them.

    **Overview** — Every release (and [Unreleased]) opens with a 2–4 sentence user-facing summary. Do not restate the detailed bullets. Banned in the overview: file paths, line numbers, regex snippets, internal flag names, project-specific counts or percentages, and AST or visitor terminology. End with `[log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)` (no preceding line break), substituting the version.

    **Bullet density (HARD RULE)** — Applies to every bullet under `### Added`, `### Changed`, `### Fixed`, `### Removed`, and their `(Extension)` variants. One sentence per bullet, ordered: *what changed → why the user cares → what the user must do* (write "No action required" when true). A second sentence is permitted only when a required user action does not fit in the first. Three-sentence bullets are forbidden — split, or move detail to the commit message, PR, bug report, or code comment, and link out. Concision edits may touch historical sections.

    **Banned inside bullets** (move to commit message, PR, or code comment):
    - **PR archaeology** — prior attempts, rename history, "after X didn't hold". Describe the landed state only.
    - **File-by-file inventories** — that is the git diff.
    - **Test counts** — that is CI output.
    - **Code-internal names** — AST classes, regex flags, function signatures, field or type names, private identifiers.
    - **Bug-report, fixture, or test paths** — commit message footer only.
    - **Decision-making narrative** — one clause of reasoning is fine; a paragraph is not.

    **Maintenance `<details>` bullets** — Same bans apply (no test counts, no file inventories). The what→why→must-do template is optional for infra-only entries.

    **Maintenance section** — Changes with no end-user impact (publish/CI tooling, internal refactors, test harness, plan housekeeping, developer scripts) belong in a collapsed `<details><summary>Maintenance</summary>...</details>` block at the bottom of the version section, never in `### Added` / `### Changed` / `### Fixed`. Test: if a pub.dev or Marketplace user would notice, it is top-level; otherwise Maintenance.

    **Tagged changelog** — Published versions use git tag `vx.y.z`. Each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

    **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [14.3.7]

Updates the Dio linting behavior to favor dependency injection and factory patterns over static singletons. The updated rule flags top-level and static `Dio` declarations while permitting instantiation inside methods, constructors, and callbacks, resolving an architectural contradiction with anti-singleton guidelines.[log](https://github.com/saropa/saropa_lints/blob/v14.3.7/CHANGELOG.md)

### Changed

- **Breaking:** Renamed `require_dio_singleton` to `require_dio_factory` — the rule now flags `Dio()` in static fields and top-level variables (the singleton anti-pattern) instead of recommending them. `Dio()` inside methods, constructors, closures, and DI callbacks is allowed. Resolves the architectural contradiction with `avoid_singleton_pattern` ([#274](https://github.com/saropa/saropa_lints/issues/274)). No action required if already using factory/DI patterns.
- **`require_dio_factory` config alias:** Projects using `require_dio_singleton` in `analysis_options.yaml` continue working via `configAliases` — no config migration required on upgrade.

### Added

- **Hardened `require_dio_factory` detection:** Added coverage for `late static final Dio` fields, static getters, nested closures, and mixin method bodies. No action required.

<details><summary>Maintenance</summary>

- Closed Dependabot PR #271 bug (js-yaml 4.1.1 → 4.3.0): lock file already resolves to 4.3.0 via mocha; archived as fixed.
- Publish audit now detects dangling `bugs/*.md` references in active documents (skips frozen `plans/history/`).

</details>

---

## [14.3.6]

Removes the `avoid_debug_print` rule, which contradicted the existing `prefer_debug_print` and left no valid console output path. Also fixes false positives in `avoid_redundant_null_check` and `avoid_redundant_await` when types are nullable or resolve across package boundaries. A new `--debug-rule` flag on the scan CLI traces type resolution for any named rule, making it easier to diagnose false positives.
[log](https://github.com/saropa/saropa_lints/blob/v14.3.6/CHANGELOG.md)

### Removed

- **`avoid_debug_print` rule deleted.** The rule contradicted `prefer_debug_print` — one said "use debugPrint," the other said "don't" — leaving no valid console output function for projects without a custom logging wrapper. `prefer_debug_print` remains and covers the `print()` → `debugPrint()` upgrade path. No action required unless your config explicitly enabled `avoid_debug_print`; if so, remove the entry.
- **`CommentOutDebugPrintFix` quick fix deleted** (was the only fix for the removed rule). No action required.

### Added

- **`--debug-rule <name>` flag for the scan CLI.** Emits per-node type-resolution trace output (staticType, staticInvokeType, returnType) for the named rule during a scan. Use with `--resolve` for full type information. Designed for diagnosing false positives caused by type-resolution divergence in the analyzer plugin context. No action required.

### Fixed

- `avoid_redundant_null_check` no longer fires on variables, parameters, fields, or getters declared with a nullable type (`Type?`). The rule cross-checks the element's declared type against the resolved `staticType` and guards against `InvalidType` from failed type resolution, preventing false positives in cross-package contexts.
- `avoid_redundant_await` no longer fires on `await` of static methods returning `Future<T>`. The rule now guards against `InvalidType` (unresolvable types) and falls back to checking the invoked method signature's return type via `staticInvokeType` when `staticType` fails to resolve for cross-file static invocations.

---

## [14.3.5]

This update improves the precision of our accessibility lints by isolating Flutter UI components from lower-level graphics classes. Projects utilizing external image processing libraries alongside Flutter will no longer experience irrelevant warnings. [log](https://github.com/saropa/saropa_lints/blob/v14.3.5/CHANGELOG.md)

### Added

- `isFlutterWidgetNamed(Element?, String)` shared utility for verifying a resolved element is a Flutter SDK widget by name and library origin, with `TypeAliasElement` unwrapping.

### Fixed

- `require_image_semantics`, `require_image_description`, `require_accessible_images` no longer fire on non-Flutter classes named `Image` (e.g. `package:image`'s pixel-buffer `Image` or `dart:ui`'s `Image`). All three rules now verify the declaring library is `package:flutter/` before reporting, with `TypeAliasElement` unwrapping for typedef'd widget references.

---

## [14.3.4]

Adds a cross-tool data channel so sibling Saropa Suite tools can pull this project's daily health snapshot, adds a validated `fresh_code` risk flag to the Code Health report, and revives a batch of lint rules that never fired for anyone: seven that were missing their most common bad-code shape, and fourteen whole-file rules (desktop, BLoC, Riverpod, iOS, testing, navigation, i18n, and animation checks) that reported through an end-of-file step the analysis engine ignored. Also fixes a broken age signal that scored every function as maximally stale. No action required — the API is opt-in and the new flag and fixes take effect automatically. [log](https://github.com/saropa/saropa_lints/blob/v14.3.4/CHANGELOG.md)

### Added

- **`fresh_code` flag in the Code Health (vibrancy) report.** Functions with cyclomatic complexity above 10 whose body was written or rewritten within the last 90 days are now flagged, because validation against real bug-fix history showed recently rewritten complex code causes incidents far more often than old code. No action required — the flag appears in the CLI report and as a filterable pill in the extension's Code Health view.
- **(Extension) `getDailySummary(date)` on the extension's public API.** Sibling Saropa Suite tools can now read this project's current health score, violation counts, and error-level trouble items for a given day via `getExtension('saropa.saropa-lints').exports.getDailySummary('YYYY-MM-DD')`, which resolves to a documented `DailySummary` (or `undefined` before any analysis has run). No action required — the summary is built lazily on call, reads only local analysis output, and transmits nothing.

### Fixed

- **`prefer_notifier_over_state` false positives eliminated.** The rule matched `StateProvider` by scanning serialized source text, which could match unrelated identifiers containing that substring; it now checks the constructor/invocation name directly via the AST. The `MethodInvocation` branch is restricted to the known Riverpod factory methods (`autoDispose`, `family`) to prevent false positives from unrelated static methods. A fixture pins all three detection branches and a false-positive decoy. No action required.
- **Code Health age scores were stuck at zero.** A broken decay formula scored every function with git history as maximally stale, so the age component contributed nothing to health rankings; ages now decay correctly from 100 (touched today) toward 0 over years. Overall scores rise slightly on recently maintained code — no action required.
- **`prefer_list_contains` now flags `indexOf(x) != -1`.** The rule only recognized a bare `0` or `-1` on the right of the comparison, but `-1` is written as a negation, not a plain number, so the most common presence check — `list.indexOf(x) != -1` — was never flagged. It now is. No action required.
- **`avoid_map_keys_contains` now flags `map.keys.contains(k)` on a plain variable.** The rule previously matched only chained receivers (like `this.map.keys.contains(k)`) and missed the ordinary `map.keys.contains(k)` on a simple map variable — the usual shape. Its quick fix (`map.containsKey(k)`) now applies to those cases too. No action required.
- **`avoid_unnecessary_collections` now flags `List.of([...])`/`Set.of(...)`/`Map.of(...)`.** The rule missed these wrapped-literal constructors during full analysis because they are constructor calls, which analysis represents differently from the method-call shape the rule looked for. Both shapes are now flagged. No action required.
- **`prefer_asmap_over_indexed_iteration` now flags `for (i = 0; i < list.length; i++)`.** The rule required the loop bound to be a chained property read and missed the ordinary `list.length` on a plain list variable — the usual shape — so it effectively never fired. It now does. No action required.
- **`require_key_for_collection` now flags `ListView.builder`/`GridView.builder` during full analysis.** These are constructor calls, which full analysis represents differently from the method-call shape the rule looked for, so keyless items in the most common list builders went unflagged; only a few less-common widgets were caught. All shapes are now flagged. No action required.
- **`prefer_commenting_future_delayed` now works during full analysis and stops flagging already-commented delays.** `Future.delayed` is a constructor call (represented differently from a method call during full analysis), so the rule never fired for anyone; and it looked for the explanatory comment on the wrong token, so an `await Future.delayed(...)` with a comment above it was treated as uncommented. Both are fixed: the rule fires on uncommented delays and stays quiet when a comment precedes the statement. No action required.
- **`avoid_sequential_awaits` now fires.** The rule registered for a callback the analysis engine silently ignores, so three or more independent sequential awaits (which could run together with `Future.wait`) were never flagged for anyone. It now registers correctly and reports. No action required.
- **Four more rules that never fired now work: `prefer_single_exit_point`, `prefer_guard_clauses`, `require_getit_registration_order`, and `require_hive_adapter_registration_order`.** All registered through the same ignored callback as `avoid_sequential_awaits`, so none produced a diagnostic for anyone. All four now register correctly and report. No action required.
- **`pass_correct_accepted_type` now fires, and `prefer_correct_identifier_length` now checks parameter names.** Both registered for a parameter callback the engine ignores: `pass_correct_accepted_type` never fired at all, and `prefer_correct_identifier_length` only checked variable names, silently skipping parameters. Both now register correctly. No action required.
- **Fourteen more whole-file rules that never fired now work.** Each aggregated information across the whole file and then reported through an end-of-file callback the analysis engine silently ignores, so none produced a diagnostic for anyone. The revived rules are `require_menu_bar_for_desktop`, `require_window_close_confirmation`, `require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state`, `require_apple_sign_in`, `require_error_case_tests`, `avoid_test_coupling`, `require_test_cleanup`, `prefer_test_variant`, `require_route_transition_consistency`, `prefer_shell_route_for_persistent_ui`, `require_intl_locale_initialization`, and `prefer_implicit_animations`. All now scan the file in a single pass and report correctly; `require_intl_locale_initialization` also stops missing usages that a duplicate registration had been discarding, and `require_apple_sign_in` now recognizes the standard `GoogleSignIn().signIn()` call shape (a constructor-call receiver) that its detection had been skipping. No action required.

<details>
<summary>Maintenance</summary>

- Fixed the rule-liveness report (`accuracy_report`) so it exercises stylistic rules. No tier — not even pedantic — contains the stylistic rules, so the previous tier-scoped scan never enabled them and falsely reported stylistic rules with fixtures as silent; correcting it flipped 80 previously-false-silent rules to firing (the silent worklist dropped from 744 to 664). The report now defaults to all defined rules (`--tier <name>` narrows it), via a new optional explicit rule-set on the scan runner.
- Repaired the collection and async rule fixtures so the liveness instrument exercises the rules that were correct but sitting on inadequate fixtures. Collection reached full coverage (all 27 rules fire). Async went from 13 silent to 4: eight fixtures made realistic (typed streams/futures, class-method context, matching heuristic identifiers, a real `WebSocketChannel`). The four remaining are two rules whose fixtures resolve to zero diagnostics under the full-corpus scan (cause not yet isolated with per-file tooling) and two `expect_lint` markers naming rules that were never implemented.
- Added an integrity test that fails the build if any rule calls one of the three no-op registration stubs (`addPostRunCallback`, `addFunctionBody`, `addFormalParameter`), which silently discard their callback and were the root cause of the fourteen dead whole-file rules revived this release. The guard forces authors to the real registrations instead.
- Repaired the liveness fixtures for the revived whole-file rules and added fixtures for three that had none (`require_error_state`, `avoid_circular_provider_deps`, `prefer_notifier_over_state`). Because these rules judge the whole file, a fixture that placed a BAD and a GOOD example together let the GOOD example mask the BAD; the compliant examples were moved to sibling `*_good.dart` files, path-gated fixtures were relocated, and mock classes (`GoogleSignIn`, `CupertinoPageRoute`, `FadeTransitionRoute`) were added so constructor-based rules resolve. All fourteen are confirmed firing (six in the full corpus scan, eight in isolated scans — the eight hit the pre-existing full-corpus-scan measurement limitation with the crowded test-fixture directory, already noted for the async cluster).
- Fixed the Code Health `unused` flag producing ~50% false positives on multi-package repos. Nested `pubspec.yaml` files fragmented the analysis context, the resolved-usage pass silently degraded, and every `@override` method and `bin/`-only-called function was flagged dead. The fix scopes the analysis context to `lib/`, `test/`, `bin/` (preventing fragmentation), includes `bin/` files in the usage set (so CLI delegates get real caller counts), and adds a syntactic `@override` safety net that protects polymorphic methods even if resolution degrades. No action required.
- Split the Issues tree provider's ~220-line tree-item renderer into a sibling module so the provider class carries only its stateful filter/index logic. Behavior-identical; the tree-item tests pin the render output.
- Closed the oversized view-file breakdown plan and archived it to plan history — all ten tracked files are decomposed, and the two residual stateful controllers are accepted as cohesive final-state modules.
- Ran the flight-risk scoring research gate (predictive-score validation) and recorded a negative result: on a 16-incident corpus mined from this repo's fix history, the candidate composite formula lost to the complexity-alone baseline, so the feature stays unbuilt and its plan stays open with the findings and re-attempt conditions documented.
- Closed the sidebar-and-affordance inventory snapshot and archived it to plan history — every count had drifted from the manifest, and the one durable decision (the palette-only JSON-export tree providers are intentionally never registered as views) now lives as a comment at their construction site.
- Fixed the `loadHealthHistory` test so it asserts real behavior instead of silently passing on empty results. The test had `if (points.isEmpty) return`, which meant a completely broken function still produced a green test. It now requires non-empty results (this repo has tags), asserts `codeLoc > 0`, the `codeLoc <= loc` invariant, and distinct tags when two points are returned.
- Added `HistoryPoint.toMarkdownRow()`, `HistoryPoint.markdownHeader`, and `HistoryPoint.toMarkdownTable()` for rendering health trajectory as markdown tables.
- Fixed the performance-rules fixture verification test: renamed `require_window_close_confirmation_desktop_fixture.dart` to match the rule-name convention, and added 8 fixture files that existed on disk but were missing from the verification list.
- Replaced the hardcoded fixture list in the performance test with a directory scan, so new fixture files are verified automatically without manual list maintenance. Also renamed the stale `require_window_close_confirmation_desktop_good.dart` to drop the `_desktop` suffix.
- Converted all 126 remaining test files from hardcoded fixture lists to the same `Directory.listSync()` auto-discovery pattern. Every fixture verification group now scans its directory on disk, so adding a fixture file is automatically tested — no manual list to maintain or drift out of sync. The `android_rules_test` retains one explicit test for a cross-directory fixture (`require_android_manifest_entries` in `example/lib/platform/`). Two files (`roadmap_15_rules_test`, `migration_rules_test`) were excluded because their fixture groups contain content-validation tests beyond simple existence checks.
- Extracted fixture auto-discovery into a shared `discoverFixtures()` helper (`test/helpers/fixture_discovery.dart`) and migrated all 127 fixture-verification test files to use it. The helper returns an empty list when the directory is missing, so the guard test fails with a clear assertion instead of a `FileSystemException` aborting the group. Removes ~7 lines of duplicated `listSync` chain per file.
- Added a fixture-vs-tiers integrity test (`test/integrity/fixture_integrity_test.dart`) that cross-references every `*_fixture.dart` on disk against `getAllDefinedRules()`. Catches stale or misspelled fixture files whose names don't match any registered rule. Group/category fixtures (covering multiple rules) are logged but not failed. Includes a regression floor at >2300 exact-match fixtures.

</details>

---

## [14.3.3]

Adds a rule pack for device_calendar_plus, a maintained replacement for the abandoned device_calendar plugin with a different API (no relation to the existing device_calendar rule pack, which stays as-is). Also fixes the Package Dashboard's Opportunities detection so document files like README.md are never counted as an adoptable API, and adds an Opportunities section to the Package Detail sidebar with per-feature links to the package's source code and documentation. No action required — the new rules and the Opportunities fixes take effect automatically. [log](https://github.com/saropa/saropa_lints/blob/v14.3.3/CHANGELOG.md)

### Added

- **New device_calendar_plus rule pack (3 rules).** Flags data operations (create/update/delete/list) called with no permission check anywhere in the file; flags all-day events (`isAllDay: true`) given a UTC-converted date, which can shift the event to the wrong calendar day; and flags `updateEvent` calls that change no field, a no-op the package treats as silently harmless. No action required — rules run automatically wherever `device_calendar_plus` is imported.
- **(Extension) Opportunities section in the Package Detail sidebar.** Each unadopted changelog feature now lists its introducing bullet plus, per named API, a link to search the package's source repository and a link to its online documentation, so you can review a feature without leaving the sidebar. No action required — the section appears automatically for any package with unadopted features.

### Fixed

- **(Extension) Opportunities detection no longer treats document files as adoptable APIs.** A changelog bullet mentioning `README.md`, `CHANGELOG.md`, or `pubspec.yaml` was being extracted as if it were a dotted API reference (like `ReelText.rich`), so the Package Dashboard's Opportunities column and count could include filenames instead of real code. Extraction now excludes filename-shaped tokens. No action required — rescanning drops the false entries.
- **(Extension) Sidebar views now show an icon.** The Banner, Editor Dashboards, Status, Settings, and Help views in the activity bar panel were missing an icon, so they rendered as unlabeled entries when moved to another panel. No action required — icons appear automatically.

<details>
<summary>Maintenance</summary>

- Added false-positive-guard fixtures and additional UTC-shape cases for the device_calendar_plus all-day-event rule, closing a regression-coverage gap where the resolved-receiver-type check shipped in 14.3.3 had no fixture or test exercising it.
- Fixed an inconsistent `target`/`realTarget` accessor in the device_calendar_plus UTC-taint helper's `DateTime.parse` branch (no behavior change — not a realistic cascade shape).

</details>

---

## [14.3.2]

Cuts sustained editor CPU while you type. The analyzer plugin runs inside the Dart analysis server, which re-analyzes a file on nearly every keystroke; until now each pass re-ran the entire configured tier over code that was still in flux. During rapid editing the plugin now defers all of its rules until editing settles — the Dart analyzer still reports compile errors live. Full-fidelity batch analysis is unchanged. [log](https://github.com/saropa/saropa_lints/blob/v14.3.2/CHANGELOG.md)

### Fixed

- While a file is being rapidly edited in the editor, the analyzer plugin now defers all of its rules until editing settles, instead of re-running the configured tier on every keystroke-triggered pass over code still in flux — cutting sustained CPU during active development. Batch and CLI analysis (`dart run saropa_lints scan`, `dart analyze`) still run every rule at full fidelity, and the Dart analyzer keeps reporting compile errors live while you type. No action required; saropa_lints diagnostics reappear once editing pauses.

---

## [14.3.1]

Fix for raised issue: https://github.com/saropa/saropa_lints/issues/269  [log](https://github.com/saropa/saropa_lints/blob/v14.3.1/CHANGELOG.md)

### Fixed

- The baseline generator (`dart run saropa_lints:baseline`) parsed `dart analyze` output with the wrong format matcher and so reported **every** project as clean, generating an empty baseline. It now reads the analyzer's diagnostic format correctly and captures real violations. Re-run the command to regenerate an accurate baseline.
- The baseline generator no longer reports a false "clean codebase" success and exits 0 when the underlying analysis fails to run — for example when an analyzer plugin crashes and produces no output. It now detects the failed analysis, prints the error, and exits non-zero so CI cannot mistake a crash for a clean pass. No action required.

---

## [14.3.0]

Stops the analyzer plugin from driving the Dart analysis server to a multi-GB out-of-memory hang on large projects. Because the plugin runs inside the analysis server, running rules there forces the editor to hold the project's resolved model in memory. A real-memory safety valve now pauses rule execution before the server saturates RAM, previously-inert cache eviction bounds the plugin's own footprint, and a project that has enabled no rules at all defaults to the essential set in-editor. Rules you have explicitly enabled always run as configured. [log](https://github.com/saropa/saropa_lints/blob/v14.3.0/CHANGELOG.md)

### Changed

- The in-editor analyzer plugin defaults to the **essential** rule set only when a project has configured no rules at all, so an unconfigured editor session stays light. Rules you explicitly enable (via `dart run saropa_lints:init`, a `diagnostics:` entry, or a severity override) always run in-editor exactly as configured — the memory default never silently drops an opted-in rule. An explicit `SAROPA_TIER` (or `saropa_tier` / `runtime_tier`) still caps as before; full coverage runs anytime out-of-process with `dart run saropa_lints scan`.

### Fixed

- The plugin now pauses rule execution when the analysis-server process crosses a memory cap and resumes when it recovers, a backstop against the server saturating RAM and hanging the editor. Set `SAROPA_LINTS_MAX_RSS_MB` to tune the cap (0 disables it).
- The native plugin now bounds and evicts its internal caches under memory pressure instead of retaining them for the entire analysis-server session. No action required.

---

## [14.2.4]

Fixes a false positive in the hardcoded-API-URL rule so it no longer flags endpoints you have already moved into a named configuration constant — the exact fix the rule asks for. [log](https://github.com/saropa/saropa_lints/blob/v14.2.4/CHANGELOG.md)

### Fixed

- `avoid_hardcoded_api_urls` no longer fires on a URL that is already the value of a `const`/`static const` field, a const collection entry, or an environment-config enum default; it now flags only inline URLs at call sites. No action required — any `// ignore:` you added on a config file can be removed.

---

## [14.2.3]

This is a maintenance release with no changes to lint rules or analysis behavior. It fixes the release process so the VS Code extension reliably reaches the Marketplace alongside Open VSX, and slims the published extension by dropping development-only files that were never used at runtime, so the download is smaller. [log](https://github.com/saropa/saropa_lints/blob/v14.2.3/CHANGELOG.md)

<details><summary>Maintenance</summary>

- Trimmed the VS Code extension package from 1200 files (17.7 MB) to the runtime set by excluding dev-only fixtures and outputs from `.vscodeignore`: UX test screenshots (`test-ux/`), the i18n translation-audit reports (`reports/`), and source maps (`**/*.map`). The bare `*.md` rule only matched the package root, so nested `reports/*.md` had been shipping; it is now `**/*.md` with the README and CHANGELOG re-included. Packaging only. No action required.
- Fixed the publish script silently skipping the VS Code Marketplace when `VSCE_PAT` was unset, even though vsce held a valid stored `vsce login` credential. The Marketplace step now falls back to the stored credential (verified read-only with `vsce verify-pat`) instead of skipping, so a logged-in machine publishes to the Marketplace as well as Open VSX. Publish tooling only. No action required.

</details>

---

## [14.2.2]

This release adds an Essential lint rule that catches a common Flutter layout crash: animating a widget's size directly inside a wrapping or flowing layout, which throws a render error on every frame once the animation starts. The rule points you to the safe alternatives so the problem is caught in the editor instead of on a device. [log](https://github.com/saropa/saropa_lints/blob/v14.2.2/CHANGELOG.md)

### Added

- **New rule `avoid_animated_size_in_wrap` (Essential) flags `AnimatedSize` placed directly inside a `Wrap` or `Flow`.** That combination throws "RenderAnimatedSize was mutated in its own performLayout" every frame once the size animates, because `Wrap`/`Flow` lay each child out within their own measurement pass while `AnimatedSize` re-dirties itself. Move the `AnimatedSize` into a `Column`/`ListView`, or put a bounded box (`SizedBox`/`ConstrainedBox`) between the two.

<details><summary>Maintenance</summary>

- Excluded the regenerated Dart `build` output from VS Code's file watcher in `.vscode/settings.json`. VS Code does not skip `build/` by default, so its 1.14 GB of gitignored output was crawled on every open, adding watcher and index load. Editor config only. No action required.
- Quieted the publish flow's extension locale audit on a clean pass. With every locale fully covered it printed all ~80 lines of the per-locale table and coverage matrix as info, burying the result; a passing audit now prints only the "fully translated" confirmation and the report path. Gaps and low-quality lines still surface as warnings on a failing audit. Publish tooling only. No action required.
- Collapsed git's per-file "CRLF will be replaced by LF" warnings during the commit step into a single "Normalized N files (CRLF -> LF)" line. A locale regen touches dozens of JSON files, each emitting one such stderr warning; they are expected (`core.autocrlf` is set right after) so they are now counted rather than dumped, while any unexpected stderr still prints. Publish tooling only. No action required.
- Made temp-dir cleanup in `project_vibrancy_cli_test.dart` tolerate the transient Windows file lock. On Windows the analyzer briefly keeps file handles open after a scan, so the teardown's immediate `deleteSync` intermittently failed with `PathAccessException` (errno 32) and flaked the suite; cleanup now retries briefly and ignores a residual lock. Test harness only. No action required.

</details>

---

## [14.2.1]

This release introduces a dedicated "Upgrade Opportunities" dashboard to help you discover unused features in your dependencies and instantly generate contextual upgrade prompts for AI assistants. It also adds a new lint rule to prevent runtime SQL crashes with Drift acronym columns, alongside smarter hardcoded API URL detection. Finally, the extension interface is polished with correctly translated tooltips, collapsible changelog histories, and cleaner table layouts. [log](https://github.com/saropa/saropa_lints/blob/v14.2.1/CHANGELOG.md)

### Added

- **New rule `require_named_for_acronym_drift_columns` (Professional) flags Drift column getters with an acronym that omit `.named()`.** Drift's snake_case converter inserts an underscore before every uppercase letter, so `contactSaropaUUID` becomes the SQL column `contact_saropa_u_u_i_d` — not the `contact_saropa_uuid` a human predicts — and raw SQL written against the expected name crashes with "no such column" at runtime. The rule is report-only because pinning a column that already shipped renames it and needs a migration; add `.named('snake_case')` on new acronym columns to keep source and schema in sync. No action required.

### Fixed

- **`avoid_hardcoded_api_urls` now flags hardcoded URLs on an `api.` host, not just `/api` paths.** The detection pattern previously required `/api` in the URL path, so the most common shape — an `api.` subdomain with an ordinary path such as `https://api.example.com/users` — slipped through and the rule missed its own documented bad example. URLs with neither an `api.` host nor an `/api` path still pass, so ordinary links are unaffected. No action required. [log](https://github.com/saropa/saropa_lints/blob/v14.2.1/CHANGELOG.md)

### Added (Extension)

- **New "Upgrade Opportunities" dashboard — a focused view of the dependencies you have under-adopted.** Separate from the dense Package Dashboard table, it lists only packages that have changelog features your code does not yet use, ranked by relevance, and for each shows the package, description, README logo, the unused features, the exact project files that import it (click to jump to the line), and a one-click "Copy upgrade prompt for AI". Open it from the Saropa Lints sidebar ("Upgrade Opportunities", shown once a scan finds any) or the command palette ("Open Upgrade Opportunities"). No action required.
- **Package Vibrancy detail pane adds a "Copy upgrade prompt for AI" button.** It assembles a ready-to-paste prompt from the package's changelog — the new features classified as adoption candidates, plus your project's own call sites for that package — so you can hand an AI everything it needs to suggest where the new features fit, instead of pasting a raw changelog. The button appears whenever a package has adoptable features; open a package and click it to copy. No action required.
- **Adoption opportunities now surface for up-to-date packages, not just outdated ones.** A caret constraint quietly carries a package across releases whose new features you may never have adopted — being on the latest version does not mean you use everything it offers. The scan now mines each package's full changelog history and cross-references it against the symbols your code actually uses, so a fully up-to-date package with unused capabilities still flags features worth reviewing. No action required.
- **Package Vibrancy table gains a sortable "Opportunities" column to find the needles across many packages.** Each package shows the count of changelog features it offers that your code does not yet use (the unused feature names are in the cell tooltip); sort by the column to bring the most under-adopted packages to the top. The column hides itself when nothing is unadopted. No action required.
- **Toolbar adds "Copy opportunities for AI" to triage the whole project in one paste.** It bundles the AI upgrade prompts of the highest-relevance under-adopted packages into a single clipboard copy, so one AI round can review the project instead of opening each package. The button appears only when at least one package has an adoptable feature. No action required.
- **The Package Dashboard sidebar row shows a count of packages with features worth adopting.** The "Package Dashboard" entry in the Saropa Lints sidebar (Editor dashboards section) now reads "… · N to adopt" after a scan, so under-used dependencies are visible without opening the dashboard. The count refreshes with each scan and clears when nothing is unadopted. No action required.

### Fixed (Extension)

- **The "Unused features" tooltip now reads cleanly in 20 non-English locales.** Machine translation had appended hallucinated text after the `{features}` placeholder (stray sentences and leaked `_PH0_` sentinel fragments), so the tooltip displayed garbage in languages such as German, Spanish, Japanese, and Russian. Each locale's value was rewritten to the plain "<unused features>: {features}" form. No action required.

### Changed (Extension)

- **Package Vibrancy dashboard moves "copy as JSON" out of every table row and into the detail pane header.** The per-row clipboard icon added a column to an already-dense table; the copy button now sits next to the detail pane's close button and copies whichever package is open in the pane. Open a package to copy its JSON. No action required.
- **The package detail panel's changelog now collapses each version, with only the latest expanded.** A long upgrade gap could fill the panel with every intermediate release's notes; each version is now a fold-out, opened by default only for the newest release. Click any version to expand its notes. No action required.

<details><summary>Maintenance</summary>

- Added a changelog opportunity miner (engine behind the "Copy upgrade prompt for AI" button) that classifies a package's full changelog history into adoption candidates ("a new feature you could use") using text heuristics only — no AI — extracts the API names each feature introduces, and cross-references them against the symbols the project actually uses to rank what is genuinely unadopted. The project source is walked once, shared between the import scan and the symbol-usage scan. Service layer with unit tests. No action required.
- Added a rule-liveness report (`dart run saropa_lints:accuracy_report`) that scans the `expect_lint` fixtures and flags any rule declared in a fixture but never firing there — a gap the marker-text contract tests cannot catch. Report-only; not yet wired into CI. No action required.
- Made every api_network fixture actually exercise its rule. The bad examples were stubs — top-level functions where the rule visits class methods, or missing the package import the rule gates on — so 20 of the network rules never fired on their own fixtures. Each bad example is now a realistic class method with the required import; all 34 api_network rules now trigger. Fixtures only; no rule behavior changed. No action required.
- Started the same fixture-adequacy pass on code_quality rules: wrapped four bad examples the rule could never see (positional/named bool params and an unnecessary override need a class method; a duplicate-const example needed top-level declarations) so the rules now trigger. Fixtures only; no rule behavior changed. No action required.
- Stopped the publish audit's duplicated-message check from flagging correctionMessages that enumerate parallel code examples. The inline-repeat heuristic, which exists to catch a prose paragraph pasted twice into one message, fired on two share_plus rules whose messages intentionally repeat an API/call fragment across before/after migrations; repeated windows that look like code (call syntax, method chains, casts, camelCase) are now exempt while prose duplication is still caught. Audit tooling only. No action required.

</details>

---

## [14.2.0]

Consolidates four overlapping `shrinkWrap: true` rules down to one. A single scrollable could be flagged by up to four differently-named diagnostics, so a site suppressed under one rule name was re-flagged under another; the redundant three are now deprecated and `avoid_shrink_wrap_expensive` is the canonical rule covering the whole concern. [log](https://github.com/saropa/saropa_lints/blob/v14.2.0/CHANGELOG.md)

### Changed

- **Deprecated three redundant shrinkWrap rules in favor of `avoid_shrink_wrap_expensive`.** `avoid_shrink_wrap_in_scroll`, `avoid_shrink_wrap_in_lists`, and `avoid_shrinkwrap_in_scrollview` all policed the same `shrinkWrap: true` concern, so one site drew up to four diagnostics and an acknowledgment under one rule name did not suppress the others; the canonical `avoid_shrink_wrap_expensive` flags nested and non-nested cases alike while exempting the safe `NeverScrollableScrollPhysics` pattern. Deprecated rules are dropped from freshly generated tier configs — re-run init or write-config to clear them, or remove them from `analysis_options.yaml` by hand.

### Fixed

- **`prefer_static_final_for_session_constant` no longer flags `ThemeCommonSize` or `ThemeCommonFontSize` arithmetic.** Those getters fold the avatar-scale preference and the system text scale, so hoisting them to a `static final` would freeze a value the user can change and show a stale UI; the rule now treats only `ThemeCommonSpace` as session-constant. No action required.
- **`prefer_boolean_prefixes` no longer flags boolean fields whose name is a serialization or schema contract.** Fields on an Isar `@collection`/`@embedded` class, a Drift `@DataClassName` row, or carrying `@JsonKey` map their Dart name to a stored property, column, or wire key, so a rename would break persisted data or desync serialization; these are now exempt while ordinary private and state booleans still flag. No action required.

### Changed (Extension)

- **Code Health usage counts and the `unused` flag are now resolved per declaration, not matched by name.** Previously every function sharing a name pooled into one count, so a heavily-used `_dispose` made every other `_dispose` look used and hid true orphans; usage is now attributed to the exact declaration each reference binds to, and runtime entry points (`main`, `@pragma('vm:entry-point')`, framework `@override` lifecycle hooks) are no longer mislabeled `unused`. No action required; scans fall back to the prior name-based count when a project cannot be resolved.
- **Manage Rule Packs treats a package's version variants as a pick-one choice.** Packs targeting different majors of the same dependency (`dio` vs `dio 5.x`, Riverpod 2 vs 3, `app_links` vs `app_links 6.x`, and similar) now carry a "Pick one version" tag and are mutually exclusive — enabling one variant turns its siblings off, and `rule_packs.enabled` can never list two versions of the same package at once. No action required; the lockfile already gates rules to the version you ship.

<details><summary>Maintenance</summary>

- Split the extension's 1709-line Package Vibrancy report builder into a thin composer plus four focused sibling modules (shared helpers, top chrome, package table, data payloads). Behavior-preserving — the rendered report is byte-identical. No action required.
- Split the 1356-line command-catalog registry into a types module, three per-group entry data files, and a thin composer. Behavior-preserving — the composed catalog is identical (162 entries, same order). No action required.
- Extracted the Issues tree's node types and its command layer (hide/suppress, copy, apply-fix) out of the 1340-line `issuesTree.ts` into sibling modules, leaving the tree-data provider in place. Behavior-preserving; the tree's tests pass unchanged. No action required.
- Split the two largest dashboard stylesheets (`dashboardChromeStyles.ts`, `violationsDashboardStyles.ts`) into per-section sibling modules behind thin composers. The generated CSS is byte-identical. No action required.
- Decomposed the remaining oversized webview view files into focused sibling modules: the report stylesheet, the command-catalog webview (its CSS and client script), the Project Vibrancy / Code Health controller (its client script), the Findings wide-report stats, and the Package Vibrancy report client script. All byte-identical or test-verified. No action required.

</details>

---

## [14.2.0]

Adds a performance rule that flags arithmetic in a widget's `build()` whose operands are all fixed for the app session — number literals, constants, and design-token size getters — so the value is computed once in a `static final` field instead of on every frame. The Package Dashboard now shows a live progress bar while a rescan runs, so a refresh no longer looks like the page has frozen behind a lone notification. The Rule Packs sidebar gains a wave of new concern packs so every rule now belongs to a selectable pack, including cross-cutting "lens" packs that group rules by task — memory leaks, UI polish, release readiness — rather than by category. [log](https://github.com/saropa/saropa_lints/blob/v14.2.0/CHANGELOG.md)

### Added

- **New rule `prefer_static_final_for_session_constant` (Professional tier, info).** Flags compound expressions in `build()` built only from session-constant operands (literals, `const` fields, and design-token getters such as `ThemeCommonSpace.Footer.size`) that recompute on every rebuild; hoist them to a `static final` field, which—unlike `const`—works because the token getters resolve at runtime. Bare single getters and anything depending on `context`, `widget`, parameters, or locals are not flagged.

### Added (Extension)

- **The Package Dashboard shows a live progress bar during a rescan.** A rescan previously updated only a VS Code notification while the dashboard sat on stale data, so it read as hung; the dashboard now fills a determinate bar as each package is scanned and clears it when results refresh. No action required.
- **The package detail pane's Upgrade and Retry buttons now show a busy state.** An upgrade runs `pub get` plus the full test suite (minutes) and a retry re-fetches over the network, but the buttons gave no in-pane signal; they now disable, show a spinner, and relabel ("Upgrading…" / "Retrying…") until the work finishes. No action required.
- **The Saropa Dashboards launchpad now carries the full Actions, Settings, and Help controls.** A control band under the hero exposes run analysis, initialize config, the lint-integration / tier / run-after / UI-language settings (each showing its current value), and the help links, so the launchpad is a complete entry point rather than only a dashboard-of-dashboards; toggling a setting updates its label in place without restarting the scans. No action required.
- **Findings can now be grouped by Tier and by Pack(s).** The Findings dashboard "Group by" dropdown and the Issues view group-by picker gain two dimensions: Tier (Essential → Pedantic) and Pack(s) (ecosystem, platform, and concern packs). Pack grouping is multi-key like OWASP — a rule belonging to several packs appears under each — and findings whose rule is in no pack collect under "No pack". Both resolve from bundled rule metadata, so they work on an existing report without re-running analysis.
- **Manage Rule Packs gains rule-finding aids.** Searching now lists every matching rule in a "Matching rules" panel (each linking to its explanation and to its owning pack), shows a live "N packs · M rules" count beside the box, and highlights the matched text in rule names; section and domain headers read "12 packs · 340 rules" so you can see where rules concentrate before opening a group. No action required.
- **16 new concern packs broaden Rule Packs coverage and overlap.** Thirteen coverage packs give every previously-unpacked rule file a home — Widgets & build, Layout & scrolling, Animation & motion, Dialogs & overlays, Notifications, Naming & conventions, Class & constructor design, BuildContext safety, In-app purchase, Hardware & sensors, Freezed (codegen), File I/O & handles, and Project config & integrity — and three cross-cutting "lens" packs (Memory & resource leaks, UI polish & UX, Release readiness) deliberately span categories so the same rules can be opted into through a task-shaped lens. Packs are additive, so enabling several never double-flags a shared rule.

### Changed (Extension)

- **The sidebar Actions panel merged into Settings.** The Actions and Settings panels sat directly adjacent and read as duplicates, so run-analysis and initialize-config now lead the Settings panel (the title-bar play button still runs analysis); the duplicate "Pick UI language" action was dropped because the Settings "UI language" row already shows the current language and changes it on click. No action required.
- **"Saropa Dashboards" is now a launchpad for all six dashboards.** It opens instantly with the page chrome and live summary cards for Lints Config, Findings, Package, and Command Catalog (each with an "Open full screen" link), then streams Project Map and Code Health in as their scans finish instead of blocking on both. Each heavy pane has its own Rescan and an inline Retry when a scan fails. The "Saropa Dashboards" row now leads the sidebar's Editor dashboards list as its entry point. No action required.
- **Manage Rule Packs merges each pack's rule count and "View" link into one "N rules" link.** The table previously carried a separate count column and a separate "View" button that did the same thing; clicking the "N rules" link now both shows the count and expands the pack's rule list. No action required.

### Fixed (Extension)

- **The consolidated dashboard no longer hangs on a blank "Scanning…" screen or renders corrupted CSS.** Both scans ran behind one all-or-nothing gate, and Project Map's stylesheet was double-wrapped so its theme CSS spilled onto the page as visible text and the treemap rendered blank; panes now load independently and the stylesheet is injected verbatim. No action required.
- **The Manage Rule Packs coverage gauge now fills its arc instead of showing the percentage over an empty ring.** The gauge's fill level was delivered through an inline style attribute the webview's content-security policy silently dropped, so the arc stayed empty; it is now set from the page script and animates up to the score. No action required.
- **Manage Rule Packs search now finds individual rules, not just pack names.** Typing a rule name (or a problem area such as "storage") surfaces the pack that owns it and expands its rule list, where previously search matched only the pack's title. No action required.
- **Toggling several rule packs in quick succession no longer stacks multiple analyses.** Each toggle re-ran analysis without stopping the previous run, leaving several "Running analysis" notifications and overlapping analyzer processes; a new run now cancels the in-flight one so only the latest runs. No action required.

<details><summary>Maintenance</summary>

- Removed a redundant import from the pubspec constraint parser test that `dart analyze --fatal-infos` flagged (`unnecessary_import`), unblocking the publish analysis gate.

</details>

---

## [14.1.1]

Fixes the rule detail panel, which displayed a wall of raw JavaScript instead of the rule's documentation, and removes its dead "View in ROADMAP" button. [log](https://github.com/saropa/saropa_lints/blob/v14.1.1/CHANGELOG.md)

### Changed (Extension)

- **Removed the "View in ROADMAP" button from the rule detail panel.** It linked to a redirect stub that no longer holds per-rule documentation, so the link led nowhere useful. No action required.

### Fixed (Extension)

- **Opening a rule in the detail panel no longer dumps raw script text into the view.** A code comment in the panel's inline script contained a literal closing-script-tag sequence that terminated the script block early, so the browser parsed the rest as visible text. No action required.

---

## [14.1.0]

Resolves a false positive in the color-only status indicator rule so decorative active-state bars and indicators paired with another visual cue are no longer flagged. The extension's "Create baseline" suggestion now actually creates the baseline. Package Vibrancy override analysis now recognizes overrides that resolve a transitive dependency cap, naming the package responsible instead of marking the override removable, and upgrade-blocker explanations trace the dependency path to a package you can act on. The "Annotate pubspec" command now writes why each pinned dependency sits where it does. The Findings Dashboard sheds a stray analysis banner and a redundant Run analysis button, the TODO/HACK file-limit note gains a one-click way to raise the limit, and Drift Advisor can now reach a server running on another device over your network. Package Vibrancy also stops re-scanning on every restart — unchanged projects load instantly from cache and refresh quietly in the background. [log](https://github.com/saropa/saropa_lints/blob/v14.1.0/CHANGELOG.md)

### Added

- **New rule `require_android_exact_alarm_permission` flags exact-alarm scheduling when the manifest declares neither `SCHEDULE_EXACT_ALARM` nor `USE_EXACT_ALARM`.** Android 14 (API 34) denies the exact-alarm capability by default, so a `zonedSchedule(..., androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle)` (or `AndroidAlarmManager.oneShotAt(..., exact: true)`) is silently downgraded to inexact and fires late or never, with no error anywhere. Inexact schedule modes are not flagged. Essential tier; declare the permission or switch to an inexact mode.
- **New rule `require_android_partial_media_permission` suggests `READ_MEDIA_VISUAL_USER_SELECTED` when broad media permissions are declared.** When the manifest already declares `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` and the app uses a gallery plugin, omitting the partial-access permission hides Android 14's "Select photos" option and forces all-or-nothing library access. Advisory (Professional tier); it fires only once the broad permissions are present, so it stays quiet for Photo Picker apps.
- **New rule `avoid_package_js_for_wasm` flags `package:js` imports, which break `flutter build web --wasm`.** `package:js` has no WebAssembly implementation, so its presence fails the Wasm build; the supported replacement is the built-in `dart:js_interop`. Distinct from the existing `dart:js`/`dart:html` rules, which do not cover the third-party `package:js`. Comprehensive tier (Wasm is opt-in).
- **New rule `avoid_platform_incompatible_dependency` warns when you import a plugin with no implementation for a platform your project builds for.** A Flutter plugin compiles into every target even when its native side is missing, so importing, for example, `sqflite` (no web) into a project with a `web/` directory builds cleanly and then throws at runtime on web only — a failure the compiler never flags. The rule fires only when the project has the matching platform directory and the import is unconditional, and is backed by a hand-verified package list (`sqflite`, `local_auth`, `path_provider`, `firebase_messaging`, `camera`, `permission_handler`). Opt in via the Comprehensive tier; guard the import conditionally or switch packages to resolve.
- **Platform rule packs — iOS, Android, Web, Windows, macOS, and Linux — group each target's rules so you can enable a platform's checks without raising your whole tier.** Each is recommended automatically when its embedder folder (`ios/`, `web/`, …) is present, and enabling a pack only adds rules on top of your tier. Open Manage Rule Packs and toggle the platforms you ship.
- **Concern rule packs — Security, Performance, Accessibility, Networking, Error handling, and nine more — group existing rules by what they protect rather than by package.** They surface a whole problem area (for example every security rule) that would otherwise stay buried behind the Professional tier, and a rule may belong to several packs at once. Opt in from Manage Rule Packs under the Concerns section.

### Added (Extension)

- **A "Create Baseline" command that suppresses your existing violations so only new code is flagged.** The Suggestions view already prompted you to baseline once findings existed, but the prompt opened the config editor and left you to run the baseline tool from a terminal yourself. The prompt — and a new command-palette entry, "Saropa Lints: Create Baseline" — now run it directly, with a cancellable progress notification, and refresh the views when it finishes. No action required.
- **The "Annotate pubspec" command now writes why each pinned dependency sits where it does, so you no longer paste pub's conflict output by hand.** Above each affected dependency it adds a comment explaining whether the version is held back by a shared dependency (naming the path to a package you can edit), forced up to a required minimum by another package, or incompatible with a Flutter SDK pin. Re-running the command refreshes these notes in place and leaves your own hand-written comments untouched. Run "Saropa Lints: Annotate pubspec" after a scan to populate them.
- **Drift Advisor can now connect to servers running off-box, via a new `saropaLints.driftAdvisor.hosts` setting.** Discovery previously scanned localhost only, so a Drift server running on a phone reached over Wi-Fi debugging was never found. List one or more LAN IPs (for example `192.168.1.151`) to probe in order; each is scanned across the port range, or pin an exact endpoint with `host:port`. Defaults to `["127.0.0.1"]`, so no action is required unless a server is remote.
- **Pack recommendations now read your project's folders and config files, not just pubspec dependencies.** The Config dashboard suggests platform packs from the embedder folders you build for (`ios/`, `web/`, …) and Firebase from a `google-services.json` / `GoogleService-Info.plist`, so a pack is offered even when the signal is a folder or file rather than a dependency line. Review and enable from the startup suggestion or Manage Rule Packs.

### Fixed (Extension)

- **Package Vibrancy no longer mislabels a `dependency_overrides` entry as removable when it exists to resolve a transitive version cap.** Override analysis only checked your direct constraint and an SDK-pin heuristic, so an override pinning a dependency that a sibling package caps below the resolved version showed as "stale," inviting you to delete an override the resolver actually needs. It now reads each constrainer's declared range and names the binding package as the override's reason. No action required.
- **The Findings Dashboard no longer shows a stray "Analysis started" banner above the header or a second blue "Run analysis" button in the empty state.** The accessibility announcer rendered visibly because this view's stylesheet omitted the rule that hides it, and the no-data panel duplicated the toolbar's Run analysis and Refresh; the announcer is hidden again and the empty panel now relies on the toolbar action. No action required.

### Changed (Extension)

- **Upgrade-blocker explanations now trace the dependency path to a package you can edit.** When the package capping a shared dependency was buried deep in the transitive graph, the report named a constrainer absent from your pubspec.yaml, leaving you with no actionable line. The explanation now appends the chain from a direct dependency down to that constrainer (for example, `build_runner → build → analyzer_plugin`). No action required.
- **The TODO/HACK scan "file limit reached" note is now actionable instead of a dead end.** It previously named the setting key in prose with no way to act on it; it now offers a "Raise the limit" button that opens the relevant setting directly. No action required.
- **Package Vibrancy no longer re-runs the full scan on every restart — when pubspec.lock and your settings are unchanged, cached results load instantly with no progress popup.** The startup gate previously expired after an hour, forcing a 10-minute network scan even though nothing had changed; it now reuses the cache as long as the lockfile is identical, and only refreshes silently in the background once the data passes a staleness window (`backgroundRefreshStalenessHours`, default 24h; set 0 to disable). No action required.
- **Cold scans are faster on large projects: package analysis now runs 6 in parallel (was 3) and is tunable via `saropaLints.packageVibrancy.scanConcurrency`.** Raise it above the default only with a GitHub token configured, to avoid hitting unauthenticated rate limits. No action required.

### Changed

- **Rule packs are now additive: enabling a pack adds its rules on top of your tier instead of replacing tier coverage.** Previously any rule that belonged to a pack was switched off unless that pack was enabled, so a tier could silently lose rules it should have kept; now a rule is active when your tier or an enabled pack includes it. Version-specific migration rules remain the exception — a rule for a package or SDK major you are not on (for example a dio 5 rule on a dio 4 project) stays off even if your tier lists it. Expect more rules to fire on projects that use packaged dependencies; no action required.

### Fixed

- **`avoid_color_only_indicators` no longer fires when the state is already conveyed by a non-color cue or when the color is just a show/hide toggle.** The rule inspected a `Container` in isolation, so a thin active-tab underline whose color toggles to `Colors.transparent` (a presence cue, not a red-vs-green hue) and a colored swatch sitting next to a sibling `Text`/`Icon` that reacts to the same state (bold weight or distinct glyph) were both reported as inaccessible. The rule now suppresses both: a branch resolving to `Colors.transparent` is treated as a visibility toggle, and a sibling Text/Icon-family widget referencing the same condition counts as the required secondary cue — which also fixes the rule's own documented GOOD example (a `Row` with a conditional `Icon` beside the colored `Container`). Genuine standalone red/green indicators with no secondary cue still warn. No action required.

<details><summary>Maintenance</summary>

- When `dart pub get` / `dart pub deps` fails on a version conflict, the scan log now captures pub's own "Because … is forbidden / is required" reasoning verbatim, instead of only a generic "version solving failed". Diagnostic only.
- The new concern and platform rule packs now carry pubspec markers, restoring the registry invariant that every pack has a marker entry. The rule-pack generator emits the concern-pack markers so they stay in sync. Fixes a unit-test failure that blocked the build. No user-facing change.
- Publish runs the unit-test step roughly twice as fast: it now uses all logical cores and excludes the five `slow`-tagged full-repo integration tests (scanner / cross-file / health-history), which CI still runs in full on every push and release. Run them locally with `dart test -t slow`. Developer tooling only.

</details>

---

## [14.0.7]

 A quick fix for better honoring `// ignore`. [log](https://github.com/saropa/saropa_lints/blob/v14.0.7/CHANGELOG.md)

### Fixed

- **A `// ignore:` written below a `///` doc comment and directly above the declaration is now honored on declarations the rule flags as a whole.** The conventional placement (doc comment, then `// ignore:`, then the `static`/`final`/type line) previously did nothing for rules that report the whole declaration — e.g. `avoid_global_state`, `require_http_status_check`, `require_file_close_in_finally` — forcing the directive above the doc comment or onto a trailing line. The suppression check keyed off the doc-comment line instead of the declaration line; it now matches the declaration line, consistent with how the same placement already worked for nested diagnostics. No action required; existing above-doc and trailing placements still work.

<details><summary>Maintenance</summary>

- Hardened the `analyzer` constraint guard in `pubspec.yaml`. The `analyzer: ^12.1.0` cap now carries a boxed HARD STOP note documenting that analyzer 13 renamed the public AST classes the package is built on (`NamedExpression` → `NamedArgument`, `SimpleFormalParameter` → `RegularFormalParameter`, `DefaultFormalParameter` removed) with no deprecated aliases — a bump is a ~912-reference source migration across ~148 files, on top of the existing `meta ^1.18.3` Flutter-stable resolution blocker. No published constraint or behavior change.

</details>

---

## [14.0.5]

This release resolves two false positive scenarios to make your linting experience smoother. The keyboard dismissal rule now correctly ignores scrollable areas that do not actually contain editable text fields. We have also exempted specific Flutter render-object overrides from parameter mutation warnings, recognizing that the framework inherently requires in-place modification for these methods. [log](https://github.com/saropa/saropa_lints/blob/v14.0.5/CHANGELOG.md)

### Fixed

- **`require_keyboard_dismiss_on_scroll` no longer fires on scroll views that contain no text field.** The rule now warns only when a `ListView` / `GridView` / `CustomScrollView` / `SingleChildScrollView` actually contains an editable field (`TextField`, `TextFormField`, `CupertinoTextField`, or a custom `*TextField`), matching its own "containing text fields" precondition; a pure content list (contacts, avatars, a continent list) has no keyboard to dismiss and is now left alone. Builder/opaque content with no syntactically visible children is intentionally not flagged. No action required.
- **`avoid_parameter_mutation` no longer fires inside Flutter render-object overrides where mutating the framework-supplied object is mandatory.** `updateRenderObject(BuildContext, RenderObject)` (pushing the widget's new config onto the render object) and `setupParentData(RenderObject child)` (assigning `child.parentData`) are now exempt — there is no copy alternative, so the in-place mutation is the framework contract, not caller-data corruption. Same render-object blind spot previously fixed for `avoid_unassigned_late_fields` and `avoid_unsafe_cast`.

---

## [14.0.4]

This release introduces four thematic rule packs that bundle quality standards for UI, localization, documentation, and testing into simple opt-in groups. The standalone scanner now supports full type resolution to accurately evaluate complex rules, and it will no longer abort an entire run if a single check fails. Additionally, this update delivers significant accuracy improvements by eliminating false positives across recursion, initialization, and platform-specific code. [log](https://github.com/saropa/saropa_lints/blob/v14.0.4/CHANGELOG.md)

### Added

- **Four thematic rule packs group cross-cutting quality rules into one-click bundles.** `ui_excellence` (keyboard ergonomics, visible async feedback, image layout stability, formatted numbers, predictable dialogs/lists), `localization` (externalize strings, locale-aware `intl` formatting, plurals/RTL), `documentation` (public-API dartdoc completeness), and `testing` (deterministic, isolated, well-structured tests). Enable them in the VS Code **Manage Rule Packs** dashboard under the new **Quality standards** domain, or add the id under `rule_packs.enabled` in `analysis_options.yaml`. Until now every pack was tied to a package or SDK version; these are the first packs that name a quality standard.
- **`scan --resolve` runs the standalone scanner with full type resolution.** Rules that fire on constructor calls like `File('x')` (or that need resolved types) only see violations under resolution, because the default syntactic pass parses an implicit constructor as a method call and never triggers them. The flag is slower and needs the target project's `pub get`; the default fast path is unchanged.

### Changed

- **The rules in the new `ui_excellence` / `localization` / `documentation` / `testing` packs are now pack-owned, so they are opt-in like every other rule pack.** A pack-owned rule fires only when its pack is enabled (in the dashboard or `rule_packs.enabled`), even though it remains catalogued in a tier. These rules were previously enabled implicitly by tier selection; to keep them on, enable the matching pack(s). An explicit `false` in `diagnostics:` still wins over pack opt-in.

### Fixed

- **The `scan` CLI no longer silently under-reports instance-creation and type-based rules.** The default scan is syntactic, where an implicit constructor (`File('x')`) is not yet an instance-creation node, so every rule on that channel quietly never fired; run `scan --resolve` (or check via the IDE/`custom_lint` plugin, which is always resolved) to evaluate those rules. The default fast pass still covers all other rules and is unchanged.
- **A misbehaving rule can no longer abort the whole `scan` run.** A rule that throws while visiting one file is now reported by name and skipped for that file, instead of crashing the scanner and losing every result; the remaining files and rules still run. No action required.
- **`avoid_recursive_calls` no longer fires on recursion that has a terminating base case.** It now suppresses the warning when a guard clause returns or throws before recursing, when a ternary's other branch terminates, or when every self-call is bounded by a loop over a collection (tree/JSON walks, divide-and-conquer) — instead of flagging every direct self-call. No action required.
- **`avoid_unassigned_fields` no longer fires on a field initialized by a `required this.field` (or optional `this.field` / `super.field`) named parameter.** Named and optional parameters wrap the initializing formal in a `DefaultFormalParameter`, which the constructor scan did not unwrap, so the common const-data-class pattern (`const C({required this.x})`) was wrongly reported as unassigned. Only positional `this.field` parameters were recognized before; now named, optional-positional, and super formals are all treated as assigning the field.
- **`avoid_throw_objects_without_tostring` no longer fires on `throw Error.throwWithStackTrace(obj, stack)` when `obj`'s class has a useful `toString()`.** That call always returns `Never`, so the rule was checking `Never` instead of the actually-thrown object and flagging every such throw. It now inspects the first argument's type, and recognizes a `toString()` override inherited from any non-`Object` superclass (not only one declared directly on the thrown class). Genuine violations — a thrown class with no `toString()` — are still reported, including when thrown via `throwWithStackTrace`.
- **`prefer_final_fields` no longer suggests `final` for a field that is reassigned from another class, and is now limited to private fields.** It previously counted only `this`-qualified writes inside the declaring class, so a field mutated through an instance held elsewhere (`entry.count++`, `ctx.flag = x`) was wrongly reported as never reassigned — and applying the fix failed to compile. Writes are now matched by resolved element across the whole file, and only private (`_`-prefixed) fields are flagged, because a write to a public field in another library cannot be seen by single-file analysis. Use `prefer_final_fields_always` to flag every non-final field.
- **`move_variable_outside_iteration` no longer suggests hoisting a loop variable whose value changes each iteration.** It now suppresses the warning when the declaration's initializer reads a local that is reassigned elsewhere in the loop (an ancestor walk's `dir = dir.parent`, a `for` counter, a `j++`), since hoisting would freeze it at the first iteration's value and break the loop. Genuinely invariant declarations are still flagged. No action required.
- **`require_platform_check` no longer fires on `dart:io` usage inside the native branch of a conditional import or export (the `*_io.dart` file selected by `if (dart.library.io)`).** Such files never load on web — the web build resolves to a separate stub — so the file split itself is the platform guard and no `kIsWeb` check is needed. The rule now applies the same conditional-import suppression the sibling `prefer_platform_io_conditional` rule already used; the underlying scanner additionally recognizes conditional `export` directives (not only `import`) and the `*_io.dart`/`*_stub.dart` naming pair. A file that is also reached by an unconditional import can still load on web, so it is still flagged. No action required.
- **`require_permission_status_check` no longer fires on methods that merely share a gated name (`startRecording`, `startScan`, `getContacts`, and similar) when the receiver is an unrelated app-domain type.** It now requires the call target to resolve to a recognized media/permission source (camera, geolocator, image picker, scanner, speech, audio recorder, contacts, permission) before flagging, instead of matching the bare method name — so a plain in-process recorder or scanner is no longer reported. Genuine camera, location, or microphone calls without a permission check still are. No action required.
- **A leading `// ignore:` now suppresses a diagnostic reported on a node nested inside a multi-line statement.** When a rule flagged an expression that sat on a later line than the statement it belonged to — for example `avoid_recursive_calls` pointing at the inner self-call of a multi-line `return` — an `// ignore:` written directly above the statement was silently ignored, because the suppression check compared the directive against the flagged expression's line rather than the statement's. The directive above the statement now works, matching how `// ignore:` behaves for single-line statements. No action required.

<details><summary>Maintenance</summary>

- **The `reports/organize_reports.py` helper now runs standalone instead of requiring the contacts repo cloned alongside.** The shared move/prune organizer was imported only from `../contacts/scripts/.shared/`, so the script aborted on any checkout without the sibling repo. A vendored copy now lives at `scripts/.shared/reports_organizer.py` and the launcher loads it first, falling back to the contacts copy only when the vendored module is absent. Dev-only.

</details>

---

## [14.0.3]

A new `avoid_cascade_shuffle` rule catches a subtle bug where `(collection..shuffle()).first` permanently reorders a shared list just to read one element. Five new pubspec rules review your version-constraint hygiene — flagging an open-ended SDK bound, dependencies pinned to `any`, and (for applications) ranges so wide the team drifts onto different versions. Turning off Lint integration now actually stops the analyzer. Previously "Lint integration: Off" only flipped an internal flag, so saropa_lints diagnostics kept appearing in the Problems pane. [log](https://github.com/saropa/saropa_lints/blob/v14.0.3/CHANGELOG.md)

### Added

- **New `avoid_cascade_shuffle` rule (Recommended tier).** Flags `(collection..shuffle()).first` and similar, where `..shuffle()` is cascaded onto a stored list whose result is consumed, because `shuffle()` mutates in place and corrupts the shared collection for every other reader; shuffle a copy instead — `(List.of(collection)..shuffle()).first`.
- **Five new pubspec version-constraint rules.** `require_sdk_upper_bound` (Recommended) flags an SDK constraint with no upper bound, which lets `pub get` resolve against an untested future SDK major. `avoid_unbounded_dependency` (Recommended) flags dependencies pinned to `any`. `require_dependency_lower_bound` (Professional) flags constraints with only an upper bound. For applications only (`publish_to: none`), `prefer_caret_constraint_in_app` (Professional) suggests `^1.2.3` over the equivalent `>=1.2.3 <2.0.0`, and `avoid_overly_wide_app_constraint` (Comprehensive) flags ranges spanning two or more majors. The app-only rules stay silent for published packages, which legitimately need wide ranges.

### Fixed (Extension)

- "Lint integration: Off" now comments out the `plugins:` block in analysis_options.yaml so the analyzer stops emitting saropa_lints diagnostics; toggling it back On restores the block with your rule packs and overrides intact. No action required.
- Drift Advisor anomalies and index suggestions no longer appear twice in the Problems panel when the standalone Saropa Drift Advisor extension is also installed; the Lints integration now defers the Problems publish to that extension while it is active, and resumes if you disable it. No action required.
- When a Drift Advisor server connects and the standalone Saropa Drift Advisor extension is not installed, a one-time per-workspace toast now recommends installing it for the full Problems-panel experience; it honors the existing proactive-nudge opt-out. No action required.
- The "Drift Advisor" product name is now shielded from machine translation so it stays in English across every locale instead of being transliterated; affected catalogs correct themselves the next time locales are regenerated. No action required.

<details><summary>Maintenance</summary>

- The locale audit now treats strings that are entirely brand terms, `{placeholders}`, and punctuation (e.g. `Saropa Lints: {message}`) as skipped rather than missing, since machine translation can only echo them; this clears two perpetual false-positive coverage gaps.

</details>

---

## [14.0.2]

This release introduces a unified multi-pane dashboard that lets you review your project map and code health metrics side by side, alongside an on-demand shortcut to quickly re-check for package updates. It also addresses key interface stability issues, preventing extension host freezes during upgrades and stopping the primary dashboard header from flickering during active analysis. [log](https://github.com/saropa/saropa_lints/blob/v14.0.2/CHANGELOG.md)

### Fixed (Extension)

- **The Findings Dashboard header no longer flickers constantly.** The dashboard reloads itself whenever the analyzer republishes diagnostics, and each reload replayed the header's entrance animation — so in an actively-analyzing project the header strobed nonstop. It now skips the reload when nothing you can see has changed, and only animates the header on first open. No action required.
- **The "Upgrading Saropa Lints to X" notification no longer hangs open after you accept an upgrade.** The upgrade ran a full project analysis on the blocking call path, which froze the extension host for the whole analysis and left the progress notification (and its Cancel button) unresponsive until VS Code was reloaded. Analysis now runs without blocking and is cancellable, so the notification closes when the upgrade finishes. No action required.

### Added (Extension)

- **New "Saropa Lints: Open Saropa Dashboards" command shows the Project Map and Code Health dashboards side by side on one page.** Each pane keeps its full interactive content — the treemap, churn-complexity scatter, and hot-spot table, beside the score status line, KPI filters, and sortable function table — so you can compare where size and complexity concentrate against which functions score worst without switching tabs. Clicking a row opens the file; "Open full screen" on either pane reopens the standalone dashboard. The two standalone commands are unchanged. No action required.
- **Click the "Scanned X ago" pill on the Package Dashboard to rescan and re-check for package updates.** The pill is now a button: clicking it refreshes the dashboard and re-runs the pub.dev version check, re-surfacing the "Update available" notification even after you dismissed it. The same action is available from the command palette as "Saropa Lints: Check for Package Updates Now". No action required.

---

## [14.0.1]

The Project Map dashboard now hides machine-generated and localization files from its size map and hot-spot rankings, so the files it surfaces are ones you can actually improve. Previously a single generated database file or a megabyte of translation tables would dominate the list and bury the real issues. [log](https://github.com/saropa/saropa_lints/blob/v14.0.1/CHANGELOG.md)

### Fixed

- **The Project Map dashboard no longer ranks generated and localization files in its size map and hot spots.** Files emitted by code generators (`.g.dart`, freezed, drift, auto_route, injectable, protobuf, and similar) and the `app_localizations*` / `intl_*` translation tables now stay out of the rankings, matching the Code Health dashboard's existing behavior. These files are long, mechanical, and unimprovable, so they crowded out the hand-written code that hot spots are meant to highlight. No action required.

### Changed

- **The warnings for `require_keyboard_visibility_dispose`, `avoid_openai_key_in_code`, and `require_speech_stop_on_dispose` now spell out the failure each prevents.** The three messages were far shorter than the rest of the catalog and stopped at the symptom; they now describe the leaked widget, the billable key abuse, and the held microphone in full. No action required.

- **The Saropa dashboards now share one consistent visual style, and the Project Map follows your editor theme.** The Project Map dashboard previously rendered a fixed palette that ignored your light / dark / high-contrast theme; it now tracks the active theme in the editor (while standalone HTML reports keep their styled palette). The Code Health scanning screen, the About panel, the rule-violations dashboard, the command catalog, and the package-details sidebar were all brought onto the shared design system, so colors, spacing, and type match across every surface. No action required.

<details><summary>Maintenance</summary>

- **Removed three orphaned localization keys left by the Suggestions sidebar removal.** `configSuggestions.packAvailable`, `configSuggestions.initMissing`, and `configSuggestions.badgeTooltip` were only ever read by the deleted Suggestions tree provider; no code referenced them after that view was removed. Dev-only.
- **Generated-file detection is now one shared predicate, used by every CLI.** The list of code-generator suffixes plus gen-l10n table detection lived inline in several scanners; it is now a single `isGeneratedDartPath` helper the analysis CLIs share, so extending the list updates every consumer at once. The cross-file analyzers (unused symbols, duplicates, unused l10n, missing mirror tests), `project_vibrancy`, and the Project Map size scanner all delegate to it; the predicate also recognizes a `generated` path segment and the full codegen-suffix set, so each consumer now agrees on what counts as generated. Dev-only.
- **Added a cross-project dashboard style guide.** A canonical design-system document (`docs/design/SAROPA_DASHBOARD_STYLE_GUIDE.md`) defines one token set, component contract, and accessibility gate for every Saropa dashboard surface, so the extension's dashboards stop diverging into separate visual styles. Docs-only.
- **The shared dashboard chrome now carries the full token scale, and the six non-conforming surfaces adopt it.** `dashboardChromeStyles.ts` gained the spacing / radius / type / elevation / motion / z-index tokens (plus an exported `getDashboardTokens()` for surfaces that keep bespoke components), and the About panel, Code Health scan screen, Project Map, rule-violations dashboard, command catalog, and package-details sidebar were re-tokened onto it — bespoke layouts (the score gauge, command tiles, package badges, scan stepper) kept, only their values converged. Dev-only.
- **Clarified the dashboard style guide's scope after first adoption.** Added an explicit exemption for high-density log/terminal consoles, a note that VS Code collapses the four-step surface ramp onto two host backgrounds, and brought Saropa Log Capture's dashboard webview panels into the per-platform adoption section. Docs-only.
- **Adopted the style guide's button, badge, and grade-color hardening rules.** Secondary buttons in the shared chrome now carry a fallback fill and a guaranteed border, so host themes that leave `--vscode-button-secondaryBackground` undefined no longer render buttons as bare text; and letter grades across the Code Health report and the scan screen now drive off one shared A–F ramp derived from the semantic tokens instead of per-surface grade colors. Dev-only.
- **Reconciled the style guide body with its VS Code reference implementation** — the surface-0 caveat, 13px type base, and standalone `--brand-glow` value now match `chromeTokens()` instead of disagreeing with it. Docs-only.
- **Began a consolidated "Saropa Dashboards" view that shows Project Map and Code Health on one page.** A new `saropaLints.openDashboards` command opens a host webview that embeds each dashboard's full interactive report in its own iframe, side by side, preserving every chart and interaction (no summarizing). The Project Map pane plus the iframe drill-down message bridge are in place; the Code Health pane follows once the iframe mechanism is confirmed in the Extension Development Host. The standalone Project Map and Code Health commands are unchanged. Dev-only until complete.
- **Added instantiation-pin tests for six package rule packs that had none** (Envied, Keyboard Visibility, Google Fonts, OpenAI, Speech to Text, uuid), fixing the tier-integrity check that requires every rule category to carry a test and closing the gap that let a sub-standard message ship unnoticed. Dev-only.
- **A release-commit push to `main` no longer triggers a redundant `ci` run.** The publish workflow already validates that exact tagged commit and the publish script mirrors the full gate locally, so cutting a release stops firing three overlapping workflows at once. Dev-only.
- **Closed the stub-test tracking plan by dropping its deferred follow-up scope.** The plan's stub removal and the hard zero-gate that keeps empty-body `test`/`testWidgets` stubs out are complete and verified; the never-started "rewrite removed stubs as fixture-backed tests" backlog was removed as not needed. Docs-only.

</details>

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for version 14.0.0 and older.

