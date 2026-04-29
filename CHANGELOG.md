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

    **Bullet density (HARD RULE — applies to every entry under `### Added` / `### Changed` / `### Fixed` / `### Removed`, including `### Added (Extension)` / `### Fixed (Extension)` / `### Changed (Extension)` and similar)** — One sentence per bullet. That sentence answers, in order: *what changed* → *why the user cares* → *what the user must do* (say "No action required" explicitly when true). A second sentence is allowed ONLY when a concrete user action (migration step, config line to remove) cannot fit in the first. Three-sentence bullets are forbidden — split into multiple bullets, or move the detail to the commit message, PR description, bug report, or inline code comment. When a bullet genuinely needs more context, LINK OUT to those places; do not inline the explanation. Concision edits may touch historical sections on purpose.

    Hard bans inside bullets (send any of these to the commit message / PR / code comments instead):
    - **PR archaeology** — narrative of prior failed attempts, rename history, "after X didn't hold…". The changelog describes the landed state.
    - **File-by-file inventories** — `Removed from config_rules.dart, saropa_lints.dart, tiers.dart, …`. That's the git diff.
    - **Test counts** — `8,585 Dart tests pass` / `817 passing, 1 failing (unrelated)`. That's CI output.
    - **Code-internal names** — AST visitor classes, regex flags (`multiLine: true`), function signatures (`flushReport(root, options?)`), field names, type names, private identifiers. If a reader would need the source to understand the phrase, it does not belong here.
    - **Bug-report / fixture / test file paths** — those belong in the commit message footer.
    - **How-the-decision-was-made paragraphs** — one-clause reasoning is fine; a paragraph is not.

    **Maintenance** `<details>` bullets: keep them short and free of the same bans (no test counts, no file inventories); the strict what → why → must-do template is optional there when the change is infra-only.

    **Tagged changelog** — Published versions use git tag **`vx.y.z`**; each section below ends its summary line with **[log](url)** to that snapshot (or a standalone **[log](url)** when there is no summary). Compare to [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version**: See field "version": "x.y.z" in [package.json](./package.json)

    **CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

    **Score** — [pub.dev/packages/saropa_lints/score](https://pub.dev/packages/saropa_lints/score)

    **Maintenance entries** — Anything with **no end-user impact** (publish/CI tooling, internal refactors, test harness tweaks, plan-folder housekeeping, developer-only scripts) goes INSIDE a collapsed `<details><summary>Maintenance</summary>...</details>` block at the *bottom* of its version section — NOT in `### Added` / `### Changed` / `### Fixed`, which are reserved for user-visible changes that ship in the `.dart` / `.vsix` artifacts. Rule of thumb: if a pub.dev / Marketplace user running the published package would notice the difference, it belongs in a top-level section; otherwise it belongs in the Maintenance expander.

-->

---

## [12.8.2]

The VS Code extension registers the **Suppressions** sidebar at activation so you are less likely to see a “no view registered” error after an update or host restart. No config change. — [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed (Extension)

- The **Suppressions** tree binds at activation like other first-class sidebar trees, which avoids intermittent registration failures for that view. No action required; if a one-off error persists from an older session, use **Developer: Reload Window**.

---

## [12.8.1]

### Fixed

- **`avoid_redundant_await`** no longer flags `await` when the expression’s static type is a class that implements `Future` or `Stream` (e.g. Postgrest/Supabase builder APIs) instead of the plain `Future<…>` type, so legitimate awaits are not misreported as redundant. Remove any temporary `// ignore` workarounds you added for that pattern.

<details><summary>Maintenance</summary>

- Tag-publish and CI analyze jobs run nested `dart pub get` (discovered under `packages/`, with the same retries as the root install) before `dart analyze` so nested packages resolve on fresh checkouts. No action for pub.dev or extension users.

</details>

---

## [12.8.0]

### Fixed

- Cross-file **unused-l10n** and snapshot loading from disk tolerate corrupt JSON and YAML so a broken ARB or snapshot file no longer aborts the whole run; if results look incomplete, fix or regenerate that file. No config change.

### Added

- Many **widget flex/scroll**, **GetX**, **iOS lifecycle**, **iOS capabilities**, and **security auth/storage** rules now register IDE quick fixes where a safe mechanical edit applies (layout unwraps, physics helpers, HTTPS in string URLs, GetX `super` lifecycle inserts, and similar). No config change; use the lightbulb when the offered fix matches your intent.

- Optional **runtime tier cap** lets you set `SAROPA_TIER` to `essential`, `recommended`, `professional`, `comprehensive`, or `pedantic` so analysis skips rules above that cumulative band without editing generated rule lists, or set the same value as `saropa_tier` in `analysis_options_custom.yaml` or as `runtime_tier` / `saropa_tier` under `plugins.saropa_lints` when you prefer file-based config; the environment variable wins if both are set. No action required until you want CI or local runs to enforce a lower band than your YAML enables.

### Changed

- **Lint identifiers:** `annotate_redeclares`, `document_ignores`, `duplicate_constructor`, and `package_names` were renamed to `annotate_inherited_member_redeclaration`, `document_analyzer_ignore_rationale`, `duplicate_constructor_declarations`, and `pubspec_package_name_convention` for clearer multi-word names; update `analysis_options.yaml` / Saropa config if you toggled those rules by id.
- **`prefer_schedule_microtask_over_window_postmessage`** is included in the **Professional** cumulative tier (alongside other web guidance). No change unless you rely on tier lists for automation.
- **VS Code:** the Triage tree no longer shows volume or critical groups when `violations.json` is missing, is older than four hours, or lacks `summary.issuesByRule`, because those states would mislead group-level rule actions; a single row with a **Run analysis** action explains the issue instead. Re-run analysis to refresh; no config change.
- **Plugin:** report import graph lookup now uses a path key index and caches the analyzed file set after `compute`, which cuts report-side overhead on large projects. No action required.
- **Plugin + VS Code:** each entry in `violations.json` now includes a numeric **`priority`** (same combined score as the report’s FIX PRIORITY section), and the Saropa **Issues** tree sorts findings by that score (then line) so the extension matches “fix what matters first” without opening the log. Re-run analysis to refresh the export; Problems tab behavior is unchanged.
- Cross-file `dart run saropa_lints:cross_file report` writes `feature-deps.html` and a shared `report.css` (light and dark via the browser) into the output folder, and the README explains that the CLI analyzes one package root at a time so monorepo users know to run it per package. Re-run `report` to refresh an existing output directory; no config changes.

<details><summary>Maintenance</summary>

- Release tooling: full publish builds `extension/saropa-lints-*.vsix` before the optional “re-run failed CI and watch” step so a long or interrupted watch does not leave the tree without a packaged extension when `npm`/`vsce` succeeded. No action for pub.dev or extension users.
- Stopping a CI run watch with Ctrl+C during publish is treated as “done watching” and the pipeline continues to tag, pub upload, and extension install or store publish; use **n** at the watch prompt to skip waiting. Maintainers only.
- `scripts/README.md` documents `python -m unittest discover` for the Python `scripts/tests/` suite (no pytest). Maintainers and CI already use the same command.

</details>

---

## [12.7.0]

### Added

- Project Vibrancy now has primary extension UI surfaces: a dedicated sidebar webview (filters, quick unused/uncovered slices, persisted filter state, and `--since` git-ref scoped scans) plus a full report webview command with **clickable file links** per function row (opens the editor at the reported line range), so teams can use project-level code-health scoring directly in the IDE instead of CLI-only output. No action required beyond updating the extension and opening **Project Vibrancy** from the Saropa sidebar.
- Project Vibrancy now emits `stub_tested`, `suspicious_coverage`, and `test_drift` per function with summary counts in JSON, the sidebar, and the full report, plus optional `--max-stub-tested`, `--max-suspicious-coverage`, and `--max-test-drift` CI gates. No action required unless you adopt those gates in automation.
- Related-rule guidance is now available end-to-end via exported data (`config.relatedRulesByRule` / `config.ruleMetadataByRule` in `violations.json`, plus `consumer_contract.json`), extension surfaces (Violations/Issues tree hovers with **See also:** related rules, Rule Explain links, Suggestions), and init post-write hints so users can discover complementary rules faster without manual lookup. No action required.
- The VS Code extension now exposes cross-file analysis commands (unused files, circular dependencies, import stats, DOT graph export, and HTML report) with command-catalog and walkthrough discoverability, so CLI-only cross-file features are usable from the UI. No action required beyond updating the extension and running the new `Saropa Lints: Cross-File — ...` commands.
- Cross-file CLI now includes `feature-deps` output that reports feature-to-feature adjacency and concrete cross-feature import edges for `lib/features/<name>/...` projects, so architecture boundary drift is visible without custom scripts. No action required unless you want to consume the new `featureDependencies` / `crossFeatureImports` fields from JSON output.
- Cross-file CLI now includes a first-pass `unused-symbols` mode that reports likely unused top-level declarations across project files, so teams can identify dead public code quickly before deeper cleanup passes; use `--exclude-public-api` to skip exported lib files and `--include-private` to widen detection. No action required unless you want to run the new command and review candidates.
- The VS Code extension cross-file command set now includes feature dependency and unused symbol actions in addition to file/cycle/stats/graph/report, so new cross-file CLI capabilities stay discoverable in the command palette, walkthrough, and command catalog. No action required beyond updating the extension and running the added `Saropa Lints: Cross-File — ...` commands.
- Cross-file CLI now includes a first-pass `dead-imports` mode for likely dead relative imports, with extension command support, so teams can spot stale local imports during architecture cleanup without custom scripts; later bullets in this section add combinator imports, local re-export awareness, and deferred `loadLibrary()` handling on top of the first pass, while full analyzer-accurate symbol resolution remains future work. No action required unless you want to run the new command and review candidates.
- Cross-file `dead-imports` detection now understands aliased and combinator imports (`as` / `show` / `hide`) in its first-pass heuristic, so cleanup results are more accurate on common Dart import patterns without needing analyzer-level symbol resolution. No action required.
- Cross-file CLI now includes a first-pass `watch` mode that re-runs analysis on Dart file changes with configurable debounce and command targeting, so teams can iterate on architecture checks without manually re-running commands after each edit. No action required unless you want to use `watch` with `--command` and optional `--watch-debounce-ms`.
- Cross-file `watch` mode now prints per-rerun delta summaries (new vs resolved finding sets for `unused-files`, `circular-deps`, `feature-deps`, `dead-imports`, and `unused-symbols`, or per-rerun `import-stats` file/total-import count deltas), so ongoing edits are easier to track than re-reading full output each time. No action required.
- Cross-file text reporting now includes a feature dependency matrix view alongside adjacency listings, so boundary relationships are easier to scan visually in terminal and CI logs without post-processing. No action required.
- Added `tool/cross_file_benchmark.dart` to run repeatable cross-file performance benchmarks on synthetic 1000+-file projects, so maintainers can measure analysis throughput and compare optimization changes with a consistent harness. No action required unless you want to run benchmark checks locally or in CI.
- Cross-file `dead-imports` now understands local file re-exports when determining whether imported symbols are referenced, so barrel-file import patterns are less likely to be misreported as dead imports in the first-pass heuristic. No action required.
- Cross-file `dead-imports` now treats deferred imports as used when their prefix is used to call `loadLibrary()`, reducing false positives in lazy-loading patterns while semantic resolution work continues. No action required.
- Package Vibrancy now persists per-package score snapshots in workspace-local history and renders inline sparklines in the report so users can see score direction at a glance without external tracking. No action required.
- Package Vibrancy now auto-exports Markdown and JSON reports after each successful scan, so report files are always available without manual export clicks; set `saropaLints.packageVibrancy.autoExportReportsOnScan` to `false` if you prefer manual-only exports. No action required unless you want to disable auto-export.
- Package Vibrancy now runs a one-time historical backfill from existing vibrancy JSON report files with visible progress and completion messaging, so long-time users get trend sparklines without manually rebuilding history. No action required.
- Rule metadata now ships in analysis export output (`ruleMetadataByRule` in config and per-violation metadata) with summary breakdowns by `ruleType` and `ruleStatus`, so downstream tooling can build metadata-aware reports and gates without re-parsing rule classes. No action required unless you consume `violations.json`, in which case the new fields are available immediately.
- Violations view now supports metadata-driven workflows with Summary drill-down and direct toolbar filtering by rule metadata (`ruleType` / `ruleStatus`), so users can isolate vulnerability/hotspot/beta clusters in one click instead of hand-curating rule lists. No action required.
- Security hotspots now have a persisted review workflow (`open`, `reviewed-safe`, `reviewed-fixed`) with Issues actions and Summary/Overview progress counts, so teams can track triage completion across scans without external spreadsheets. No action required unless you want to start recording hotspot review state from the Violations context menu.
- Rule Packs now include SDK-gated packs (`dart_sdk_3_2`, `dart_sdk_3_4`, `flutter_sdk_3_0`, `flutter_sdk_3_7`, `flutter_sdk_3_10`, `flutter_sdk_3_16`, `flutter_sdk_3_18`, `flutter_sdk_3_19`, `flutter_sdk_3_22`, `flutter_sdk_3_24`, `flutter_sdk_3_28`, `flutter_sdk_3_29`, `flutter_sdk_3_32`, `flutter_sdk_3_35`, `flutter_sdk_3_38`) driven by pubspec `environment` constraints, so migration packs can be suggested/enabled by target SDK level instead of only dependency names. No action required unless you want these packs, in which case add them under `plugins.saropa_lints.rule_packs.enabled`.
- `dart run saropa_lints:init --emit-composite-plugin-scaffold [dir]` writes a minimal **composite** analyzer-plugin package (Saropa registrars + hook for your rules) so orgs can wire a single `plugins:` key without hand-authoring boilerplate from scratch; the VS Code extension exposes the same flow as a command (see **Added (Extension)**). No action required unless you are building a meta-plugin, in which case use the command or flag and follow `doc/guides/composite_analyzer_plugin.md`.
- The repo now includes **`saropa_lints_api`** (`packages/saropa_lints_api/`), a thin re-export of `registerSaropaLintRules` and the Saropa YAML loaders for composite plugins that prefer a small dependency surface. No action required unless you maintain a meta-plugin, in which case you may depend on `saropa_lints_api` instead of importing `saropa_lints` directly.

### Added (Extension)

- **Saropa Lints: Create Composite Analyzer Plugin (scaffold)** is available from the command palette and from **Saropa Lints → Config** (sidebar), prompting for a workspace-relative output folder and running the same scaffold as `dart run saropa_lints:init --emit-composite-plugin-scaffold`, so composite meta-plugins do not require CLI-only setup. No action required unless you are building a meta-plugin, in which case use the command and follow `doc/guides/composite_analyzer_plugin.md`.

### Changed

- Cross-file `unused-symbols` now uses the Dart analyzer to resolve references (with automatic fallback to the prior regex heuristic if resolution fails), so type annotations and constructor type names count as real uses instead of being misreported as unused. No action required unless you need the old behavior, in which case pass the heuristic-only flag shown in `dart run saropa_lints:cross_file --help`.
- Extension UX now promotes a dedicated **Config Dashboard** plus **Triage** naming, default-on Dashboard/Package Vibrancy sidebar sections, and direct open commands, so users can reach configuration and dependency-health surfaces without hunting through tree views. No action required.
- Config Dashboard rule-pack UX now includes staged SDK rollout controls (all, breaking-only, deprecation-only), risk-first SDK grouping/badges, and a confirmation prompt before bulk enablement, so teams can adopt migration packs incrementally with less accidental churn in `analysis_options.yaml`. No action required beyond using the new SDK rollout actions.
- Violations grouping now includes `Rule Type` and `Rule Status` in addition to Severity/File/Impact/Rule/OWASP, so teams can pivot directly by semantic class and lifecycle state during triage. No action required.
- Rule-pack config parsing now tolerates quoted ids, inline comments, and spacing variations while preserving legacy `migration_packs` read compatibility and normalizing writes to canonical `rule_packs`, so mixed/older configs keep working and converge automatically; if your config still uses `migration_packs`, run init or toggle any Rule Pack once to rewrite it. No action required for already-canonical `rule_packs` setups.
- Rule-pack ownership is now authoritative over tiers: **every** rule code assigned to any registered rule pack (library packs such as Bloc/Dio/Firebase, SDK-gated migration packs, and similar) is subtracted from tier-derived enables first, then only re-enabled when its pack is listed under `plugins.saropa_lints.rule_packs.enabled`, so pack toggles control those diagnostics instead of tier defaults alone. Action required if you relied on tier-only activation for any pack-listed rule—enable the corresponding packs to restore those lints.
- Package Vibrancy now surfaces a dedicated Activity grade (A-F) based on both recent commits and release cadence across table, hover, and detail surfaces, so users can distinguish "quiet but active" packages from genuinely dormant ones at a glance; review Activity badges and dormancy hints in the report when triaging dependencies. No action required.
- Suppression tracking now surfaces as a dedicated extension sidebar section with by-kind/by-rule/by-file drilldown, includes suppression-rate context in Overview, and is reflected in export/governance outputs so teams can audit ignored diagnostics without custom tooling. No action required unless you consume report exports, in which case `summary.suppressions` is now documented for CI use.

### Fixed

- `avoid_money_arithmetic_on_double` no longer treats standalone `rate` as a money word (so bare `*Rate` suffixes such as `frameRate`/`sampleRate`/`heartRate` are not financial intent by themselves), while expressions that pair a money-named operand with a `*Rate` factor—e.g. `amount * taxRate`—still trigger because identifiers like `amount`/`tax` match the financial heuristics. No action required.
- `prefer_skeleton_over_spinner` no longer reports determinate `CircularProgressIndicator`/`LinearProgressIndicator` usage (`value` named argument present and not `null`) inside conditional UI branches, so real progress meters are not mislabeled as loading placeholders; indeterminate indicators in `if` / ternary / collection-`if` branches continue to be reported (spinners not under those constructs are out of scope for this rule). No action required.
- `prefer_layout_builder_for_constraints` now skips `MediaQuery` size reads in non-build scopes (for example lifecycle/setup methods and callbacks without a `BuildContext` parameter), which removes false positives where `LayoutBuilder` cannot be applied while still reporting build-phase and builder-callback sizing misuse. No action required.
- `prefer_single_ticker_provider_state_mixin` now skips State classes that hand off `vsync: this` to external helpers, which prevents unsafe suggestions to downgrade to `SingleTickerProviderStateMixin` when multiple ticker consumers exist. No action required.
- Rule execution profiling now records actual callback timing and exposes a stable JSON contract (`ruleName`, `totalMs`, `callCount`, `avgMs`) through `RuleTimingTracker.summaryJson`, so CI can detect performance regressions without parsing human-formatted logs. No action required unless you are consuming timing data, in which case switch to the JSON payload.
- Diagnostic statistics now support per-rule threshold gates and baseline-diff reporting in both the analysis report and `violations.json`, so CI can fail on targeted rule regressions and track newly introduced violations without custom parsers. To adopt this workflow, generate a baseline with `dart run saropa_lints:diagnostic_baseline` and reference it under `diagnostic_statistics.baseline.file` in `analysis_options_custom.yaml`.
- Project Vibrancy scoring tolerates missing or unreadable LCOV (empty coverage), missing or non-object on-disk vibrancy cache JSON (with short **stderr** diagnostics instead of crashing), and git subprocess failures per path (`git log` timestamps, `git blame` ages, `git hash-object` blob keys degrade to null/empty data rather than aborting the scan). No action required.

<details>
<summary>Maintenance</summary>

- Discussion #59 (custom suppression prefixes) is now explicitly deferred as policy-blocked in its discussion document, so contributors do not accidentally implement plugin-side custom ignore parsing under current project policy. No action required for package users.
- Added a dedicated `diagnostic-baseline-strict` GitHub Actions workflow for maintainers to fail fast when `violations.json` is missing before baseline refresh, so strict baseline regeneration can be run independently without changing default CI behavior. No action required for package users.
- Added a dedicated Project Vibrancy GitHub Actions workflow that emits a JSON artifact on pull requests that touch Project Vibrancy sources (see workflow `paths:` filters) and on `workflow_dispatch` manual runs, so maintainers can inspect code-health snapshots from CI without running the CLI locally. No action required for package users.
- Added sidebar UI-state regression checks for Project Vibrancy scope badge/count and persisted filter wiring, so future extension refactors are less likely to silently break the primary filtering flow. No action required for package users.
- Removed many tautological `isNotNull` expectations on guaranteed-non-null rule metadata strings in package tests (CI already enforces stub integrity), preserving rule instantiation, fixture checks, and substantive assertions such as fix metadata and AST-backed tests. No action required for pub.dev or Marketplace users.

</details>

---

## [12.6.1]

More rules now ship IDE quick fixes for repetitive, low-risk edits (secure URL schemes, image and HTTP/Firestore/Drift call shapes), so you can apply the suggested remediation from the lightbulb menu instead of typing boilerplate by hand. Update the package and re-analyze to see new fix actions where diagnostics already appear. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- `require_image_error_builder`, `require_image_dimensions`, `require_placeholder_for_network`, `require_https_over_http`, and `require_wss_over_ws` gain quick fixes that insert a minimal `errorBuilder`, placeholder `width`/`height`, a loading/placeholder callback, or rewrite `http://` / `ws://` prefixes where the rule already fires, so common widget and URL hygiene fixes are one action in the IDE. No action required beyond updating and using the fix when offered; adjust inserted dimensions to your layout.
- `require_websocket_error_handling` gains a quick fix that appends a stub `onError` argument to flagged `listen` calls so you can fill in logging or reconnection logic without retyping the signature. No action required beyond updating and using the fix when offered.
- `incorrect_firebase_parameter_name` offers a quick fix that rewrites hyphenated Analytics parameter keys to underscores when that alone satisfies Firebase’s naming rules, so common `item-id` style keys become `item_id` in one step. No action required beyond updating and using the fix when offered; reserved-prefix violations still need a manual rename.
- `avoid_firestore_unbounded_query` offers a quick fix that inserts `limit(100).` before `.get` / `.snapshots` on flagged collection chains so you can cap reads without manually editing the method chain. Review the chosen limit for your product before shipping. No action required to adopt beyond the package update.
- `prefer_timeout_on_requests` and `require_request_timeout` offer quick fixes that append `.timeout(const Duration(seconds: 30))` after the flagged HTTP client call when the rule applies, matching the documented remediation pattern. Tune the duration in code if 30 seconds is not right for your endpoints. No action required beyond updating and using the fix when offered.
- `avoid_drift_enum_index_reorder` offers a quick fix that renames `intEnum` to `textEnum` on flagged Drift column builders so you can switch to name-backed enum storage in one step; you must still migrate existing stored ordinals and adjust related `TypeConverter` code the rule flags separately. No action required beyond updating and using the fix when offered.

---

## [12.6.0]

New recommended-tier migrations cover Flutter scrollbar theme lookup and several Dart 3.2 `dart:js_interop` signature changes. The interop rules only fire when the real SDK library is resolved, so local types or extensions that reuse the same names should stay quiet, and outdated `.toDart` chains are still caught when the bool result is cast through dynamic first. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- `prefer_scrollbar_theme_of` guides `ScrollbarTheme.of(context)` instead of `Theme.of(context).scrollbarTheme` so inherited scrollbar themes are not skipped. No action required until you enable or adopt the recommended tier.
- `avoid_legacy_jsboolean_return_assumptions`, `prefer_string_for_typeof_equals`, and `prefer_int_for_jsarray_with_length` target Dart 3.2 `dart:js_interop` changes around `typeofEquals`, `instanceof`, and `JSArray.withLength`. No action required until you enable or adopt the recommended tier.

### Fixed

- `avoid_legacy_jsboolean_return_assumptions`, `prefer_string_for_typeof_equals`, and `prefer_int_for_jsarray_with_length` no longer treat unresolved elements or same-named user declarations as `dart:js_interop`, which removes false positives in mock-heavy code while keeping real interop call sites covered. No action required.

---

## [12.5.4]

This release tightens a noisy repeated-map-lookup lint that could still report in code where extraction was not actually appropriate. The rule now stays out of assignment/update patterns and avoids conflating similarly named variables across different scopes when type resolution is ambiguous. If you were seeing stubborn false positives in loop-heavy or shadowed-variable code, those should now be gone. [log](https://github.com/saropa/saropa_lints/blob/v12.5.4/CHANGELOG.md)

### Fixed

- `prefer_extracting_repeated_map_lookup` now hard-skips write contexts (`[]=`, compound assignment, and increment/decrement), only buckets map-like targets with resolved elements, and refuses unresolved target bucketing, which prevents lingering false positives in shadowed/sibling scopes and mixed read+write loops that users could not safely "extract" anyway. No action required.
- Diagnostics from the same rule at the same file offset are now deduplicated in reporter emission paths, which reduces duplicate warnings when multiple AST callbacks converge on one location while preserving distinct reports at different offsets or from different rules. No action required.

---

## [12.5.3]

This release focuses on reducing high-noise false positives in common Flutter patterns so teams can keep strict lint settings enabled without fighting the tool. Several rules now better distinguish real risks from valid callback, const-context, lifecycle, and helper-ownership code. You should see cleaner results in existing codebases with fewer diagnostics that require no meaningful code change. [log](https://github.com/saropa/saropa_lints/blob/v12.5.3/CHANGELOG.md)

### Fixed

- `avoid_setstate_in_build` no longer fires on `setState` calls inside event-handler closures (`onTap:`, `onPressed:`, `onChanged:`, `Future.then`, etc.) passed during `build()`, since those closures are stored as callbacks and invoked later — not synchronously during the build pass. The visitor now skips `FunctionExpression` subtrees, eliminating the structural false positive while still catching genuine inline `setState` calls in `build()`. No action required.
- `avoid_opacity_animation` no longer fires on an `Opacity` widget whose `opacity:` argument is a constant numeric literal, even when it sits inside an `AnimatedBuilder` that drives a sibling property (icon swap, color, layout). A constant value cannot animate, so the rebuild cost the rule targets does not exist; replacing it with `FadeTransition` would introduce flicker. Genuine animation-driven opacity expressions still warn. No action required.
- `prefer_const_literals_to_create_immutables` no longer fires on collection literals whose enclosing constructor is already `const` (explicitly or via const context). The Dart language auto-promotes inner literals in that case, so adding an explicit `const` would be redundant and trigger the standard analyzer's `unnecessary_const` — leaving the user with no valid resolution. Genuine cases (non-const parent with all-const elements) still warn. No action required.
- `require_database_close` no longer fires on opener helpers whose lifetime is owned by their caller — methods named `init*` / `_init*` / `open*` / `_open*` / `setup*` / `_setup*` that return `Future<bool>` / `Future<void>` / `bool` / `void`. A success-flag return signals the helper hands control back to a caller that closes in `try { … } finally { close(); }`, the standard pattern for background-isolate / WorkManager / migration setup. Methods returning a connection (`Future<Database>` etc.) still warn because the return type transfers ownership. No action required.
- `prefer_extracting_repeated_map_lookup` no longer fires on assignment targets (`map[key] = value`, `map[k] += 1`) — those cannot be hoisted into a local since the `[]=` operation must remain on the map. The rule also stops conflating same-spelled variables in different scopes: `cache[uuid]` written inside three sequential `for` loops, each declaring its own `uuid`, is three independent lookups and is no longer flagged. Bucketing now uses the resolved `Element` for variable keys instead of source text. No action required.
- `require_clipboard_paste_validation` no longer fires on reusable paste helpers that hand the pasted string to a callback parameter (`callback.call(text)`, `onPaste?.call(text)`, `(callback)(text)`) — those helpers have no semantic context to validate against, so the security boundary lives at the caller, not the paste site. Genuine cases (clipboard text written directly into a field with no validation regex nearby and no callback dispatch) still warn. No action required.
- `use_setstate_synchronously` no longer fires on a `setState` that lexically precedes the first `await`, even when both calls live inside a single compound statement (`try`, `if`, `for`, `switch`). Previously the rule iterated only top-level statements, so any descendant `await` made every `setState` in the same enclosing block look post-await — which broke every codebase that wraps method bodies in mandatory `try { … } on Object catch (e, st) { … }` blocks. The walker now tracks await position and `if (!mounted) return;` guard scope in source order across nested blocks. No action required.

<details>
<summary>Maintenance</summary>

- Archived the resolved `avoid_opacity_animation` constant-opacity false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.

</details>

---

## [12.5.2]

This release is a quality pass aimed at precision: fewer accidental matches, fewer environment-related false alarms, and better handling of real-world project layouts. Notification, animation, platform-import, and permission checks now behave more predictably in production-style code. Most users only need to update and re-run analysis to get quieter, more actionable output. [log](https://github.com/saropa/saropa_lints/blob/v12.5.2/CHANGELOG.md)

### Fixed

- `require_intl_plural_rules` now treats comparisons to the integer literal **1** only when that digit is not part of a longer numeral, so helpers that branch on values like 12 or 100 (12-hour labels, build bands, and similar) are not misclassified as manual plural logic. No action required.
- Long-task name matching for the `dbProcessAll…` skip now uses bounded character checks instead of `substring`, so the package’s own `dart analyze --fatal-infos` run stays clean under `avoid_string_substring`. No action required.
- `avoid_excessive_rebuilds_animation` now only considers `AnimatedBuilder` and `ListenableBuilder` when the listenable resolves to an `Animation` subtype, so `FutureBuilder`, `StreamBuilder`, `ValueListenableBuilder`, and non-animation listenables no longer get a misleading “every frame” warning. No action required.
- `require_notification_for_long_tasks` now matches long-operation tokens on camelCase boundaries (so names like `ImportAllowed` no longer hit `importAll`), skips `dbProcessAll…` DB helpers, skips the whole file when common in-app progress or notification-plugin strings appear, and splits example fixtures so BAD cases are not suppressed by GOOD escape hatches in the same file. No action required.
- Rules that read `Info.plist` through the shared helper now re-read when the file’s size or modification time changes, match keys with whitespace-tolerant XML checks, and normalize analyzer `file:` URIs to OS paths, so `require_image_picker_permission_ios` no longer false-positives once `NSCameraUsageDescription` is present. No action required.
- `require_image_picker_permission_android` now reads `AndroidManifest.xml` like the iOS camera rule reads `Info.plist`, so it stays silent when `android.permission.CAMERA` is already declared; it also covers `pickVideo` as well as `pickImage` for `ImageSource.camera`. No action required.
- `avoid_platform_specific_imports` and sibling rules that consult `ProjectContext.hasWebSupport` now run that check while visiting each library, so Flutter projects without a root `web/` directory are correctly treated as non-web and `dart:io` imports stop false-alarming there; pure Dart packages still get web-portability warnings by default. No action required.
- `prefer_layout_builder_for_constraints` no longer double-reports on `MediaQuery.of(context).size.width` / `.height`, skips intentional screen fractions and numeric breakpoint comparisons, documents when `MediaQuery` sizing is appropriate, and treats `MediaQuery.sizeOf(context).width` / `.height` like the `.of().size.*` pattern. No action required.

<details>
<summary>Maintenance</summary>

- Archived the closed `require_notification_for_long_tasks` foreground false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.
- Archived the resolved `avoid_excessive_rebuilds_animation` false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.
- Archived the resolved `prefer_layout_builder_for_constraints` false-positive report under `plan/history/2026.04/2026.04.26/` and removed it from `bugs/`. No action required for package users.

</details>

---

## [12.5.1]

This release cleans up disposal and accessibility false positives that were noisy in mature widget codebases and design-system wrapper layers. The fixes improve confidence that warnings point to real leaks or UX issues instead of valid cleanup and companion-indicator patterns. If these lints were previously too chatty in your project, this update should be noticeably calmer. [log](https://github.com/saropa/saropa_lints/blob/v12.5.1/CHANGELOG.md)

### Fixed

- **`require_change_notifier_dispose` false positive**: The rule no longer flags owned notifier fields when disposal runs on a local initialized from the field (for example capturing a nullable controller before `dispose()`). No action required.
- `require_scroll_controller_dispose` and `require_focus_node_dispose` now treat disposal through a local copy of the field, disposal only in `didUpdateWidget`, and disposal inside private helpers called from `dispose` or `didUpdateWidget` as valid cleanup, so the common nullable-controller pattern no longer reports a leak when the controller is actually released. No action required.
- `avoid_color_only_meaning` now treats `Checkbox`/`Switch`/`Radio` (including `*ListTile` variants) as companion state indicators, so selection rows with conditional background color are not incorrectly reported as color-only meaning. No action required.
- `avoid_color_only_meaning` now recognizes common design-system widget names built as a short prefix plus a known companion type (for example thin `Icon`/`Text` wrappers), so conditional surface color next to an icon swap or label in those widgets is not treated as color-only meaning when the remainder matches a real companion. No action required.

<details>
<summary>Maintenance</summary>

- Archived the closed `avoid_color_only_meaning` design-system wrapper companion false-positive report under `plan/history/2026.04/2026.04.25/` and removed it from `bugs/`. No action required for package users.
- The publish script’s combined coverage report now treats `repo_integrity` rules as using the shared `config` example fixtures, matching where those files already live. Additional validated example fixtures cover stylistic null-and-collection rules, stylistic whitespace and constructor preferences, and `prefer_semantics_sort`, with matching mock types for analysis. No action required for package users.

</details>

---

## [12.5.0]

New rules help you catch missing Android permissions, missing iOS privacy strings, desktop window setup, and gaps around background audio and location, notifications, Firestore rules, and secrets on disk before they bite at review or runtime. A couple of noisy false positives in internationalization and iOS camera permission checks are gone, and the cross-file CLI can warn when library code has no matching test file. — [log](https://github.com/saropa/saropa_lints/blob/v12.5.0/CHANGELOG.md)

### Fixed

- `avoid_builder_index_out_of_bounds` now treats `idx`, `realIndex`, and `itemIndex` inside bracket lookups like the existing `index`/`i` handling, so Carousel-style and similar builder callbacks get the same bounds heuristics. No action required unless you relied on the blind spot; add guards where the rule now applies.
- The same rule’s DartDoc now states that each list subscripted with the builder index needs its own visible bound or matching item count when lengths are not provable from the source. No action required.
- `require_intl_plural_rules` no longer treats code between string literals (for example `(hour == …)` next to AM/PM labels) as if it were text inside a quoted string, so 12-hour clock helpers are not mistaken for manual noun pluralization. No action required.
- `require_image_picker_permission_ios` now reads `ios/Runner/Info.plist` through the shared plist checker so it does not warn when `NSCameraUsageDescription` is already present. No action required.

### Added

- Added `require_android_manifest_entries` to flag permission-gated Android API usage when the app manifest is missing required `android.permission.*` entries, so runtime-denied features are caught during analysis instead of on devices. Add the missing `<uses-permission>` rows in `android/app/src/main/AndroidManifest.xml` where reported.
- Added `require_ios_info_plist_entries` to report permission-gated iOS API usage when required `NS*UsageDescription` keys are absent from `Info.plist`, so App Store rejection and runtime permission crashes are caught during analysis. Add the missing key(s) to `ios/Runner/Info.plist` where reported.
- Added `require_desktop_window_setup` to report desktop window-manager API usage when desktop runner setup files are missing, so desktop-only configuration gaps are surfaced before runtime. Ensure the relevant `windows/`, `linux/`, or `macos/` runner files are present when using desktop window APIs.
- Added `avoid_audio_in_background_without_config` to flag background audio usage when iOS `UIBackgroundModes` audio or Android manifest foreground-service / audio declarations are missing, so store review and runtime failures are caught during analysis.
- Added `avoid_geolocator_background_without_config` to flag `Geolocator.getPositionStream` when iOS background location or Android background location permission is not reflected in platform config files.
- Added `require_notification_icon_kept` to warn when FCM or local notifications are used but ProGuard/R8 rules do not appear to keep notification icon resources.
- Added `require_firestore_security_rules` to report `FirebaseFirestore` usage when no `firestore.rules` file exists at the project root.
- Added `require_env_file_gitignore` to report `.env` / `.env.*` files at the project root that are not covered by `.gitignore` patterns.
- Extended `dart run saropa_lints:cross_file` with **missing mirror test** detection: each `lib/**/*.dart` (except `main.dart`, generated-style names, and `lib/generated/`) is checked for a matching `test/**/*_test.dart`; results appear in text/JSON output, HTML report, baselines (format version 2), and non-zero exit when present.

<details>
<summary>Maintenance</summary>

- Archived closed `avoid_builder_index_out_of_bounds` false-positive investigation under `plan/history/2026.04/2026.04.25/` (removed duplicate from `bugs/`). No action required for package users.
- Closed false-positive report for `require_image_picker_permission_ios` (existing `NSCameraUsageDescription`) under `plan/history/2026.04/2026.04.25/`. No action required for package users.

</details>

---

## [12.4.4]

`require_animation_controller_dispose` stops nagging when you really did tear down an `AnimationController` using a disposeSafe-style helper next to `dispose`, and the help text you read in the editor now matches what the linter reports. Rule counts and Marketplace-facing copy line up across the package and extension, publish and audit flows are a little sturdier, and you do not need new analysis_options toggles to pick any of this up. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.4/CHANGELOG.md)

### Fixed

- `require_animation_controller_dispose` now treats `disposeSafe(…)` like `dispose(…)` in your `State.dispose()` so custom safe-dispose extensions are not reported, and the rule message was refreshed so on-screen wording stays aligned with that behavior. No action required; remove suppression comments you added only for this false positive.

<details>
<summary>Maintenance</summary>

- Deferred SDK plan notes consolidated under `plan/deferred/`; publish audit spelling prompt now retry/ignore; publish menu shows logo first; Windows temp-dir teardown hardened in one integration test. No action required for package users.
- Rounded rule-count messaging is aligned to **2100+** / **~2100** everywhere (pub.dev description, extension listings, walkthrough, tier headers, and guides) so numbers match the current rule set. No action required.
- Extension publish still tries Open VSX after a failed VS Code Marketplace upload, so the Open VSX listing can move forward when Marketplace auth fails but your Open VSX token is fine. No action required for package users.
- Publish work-report “unsolved bug” count excludes the bug-filing guide at repo root so only real open bug files inflate that bar. No action required for package users.
- Clarified internal helper documentation for `isFieldCleanedUp` so extension method names are not implied by a generic `dispose` check. No action required for package users.
- Dropped placeholder-only example rule fixtures and matching fixture-existence test entries so the suite does not imply behavioral coverage for unfilled TODO stubs. No action required for package users.
- Follow-up removed additional stylistic and related stub fixtures, added migration and SDK-migration batch fixtures with shared mocks, and expanded unit tests for compile-time syntax and image filter tier metadata. No action required for package users.
- Internal doc comment reference style, plan notes, extension copy, script helpers, and archive indexing were updated. No action required for package users.

</details>

---

## [12.4.2]

`saropa_depend_on_referenced_packages` is removed because the Dart SDK already ships the same check via `lints` / `flutter_lints`, and saropa’s copy kept false-positiveing on legitimate imports. You still get the behavior from the SDK; nothing breaks if you leave old config in place. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.2/CHANGELOG.md)

### Removed

- Removed `saropa_depend_on_referenced_packages` so duplicate / noisy import checks go away while the SDK lint keeps the same coverage for you. No action required; delete any `saropa_depend_on_referenced_packages` entry from `analysis_options.yaml` when you tidy config.

<details><summary>Maintenance</summary>

- Publish script: extension-only and publish-existing-.vsix modes now run the same Marketplace + Open VSX verification as the full flow so a “successful” store publish cannot slip through undetected. No action required for package or rule users.

</details>

---

## [12.4.1]

Analysis reports and the Run Analysis popup now show which saropa_lints build ran, and the popup can copy or open the latest consolidated report without digging through folders. Theme- and platform-driven color branches no longer trip `avoid_color_only_meaning`, and `prefer_final_locals` stops suggesting `final` where the variable is reassigned inside nested blocks or closures. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.1/CHANGELOG.md)

### Added

- Run Analysis popup adds Copy Report and Open Report (plus palette commands) so you can share or open the latest `*_saropa_lint_report.log` in one step instead of browsing dated folders under `reports/`. No action required.

### Changed

- Extension Run Analysis stamps extension reports and the issue popup with the resolved saropa_lints version and source (hosted / path / git) when `pubspec.lock` allows, so you can confirm which build ran without opening files. No action required.

### Fixed

- `prefer_final_locals` no longer false-positives when a local is reassigned inside nested blocks, control flow, or closures, so the quick fix matches real code and you can rely on the rule again. No action required; details in [bugs/prefer_final_locals_false_positive_nested_assignments.md](bugs/prefer_final_locals_false_positive_nested_assignments.md).
- `avoid_color_only_meaning` skips ordinary theme, platform, and directionality-driven color branches so theming code stays clean without ignores. No action required; details in [bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md](bugs/avoid_color_only_meaning_false_positive_theme_dark_mode_conditional.md).
- Analyzer-plugin text reports now show a real `Version:` from your project root instead of `unknown`, so each report identifies the plugin build that produced it. No action required.

---

## [12.4.0]

Three animation-focused rules catch inert `Animation.value` reads in `build`, mis-matched ticker mixins, and press-and-bounce `forward()` without `from: 0.0`. Several platform rules and `avoid_platform_specific_imports` quiet down when the project cannot hit the failure mode (for example mobile-only apps without `web/`). Pubspec dependency discovery works again, saropa’s import rule is renamed to `saropa_depend_on_referenced_packages` so it no longer doubles the SDK lint, large reports open with triage-oriented sections, and Run Analysis popups show real issue counts. — [log](https://github.com/saropa/saropa_lints/blob/v12.4.0/CHANGELOG.md)

### Added

- Added `avoid_inert_animation_value_in_build` (recommended, error) so you catch opacity and other reads that never refresh because `build` does not rerun on ticks, without noise on listening builders. No action required; see [bugs/infra_propose_avoid_inert_animation_value_in_build.md](bugs/infra_propose_avoid_inert_animation_value_in_build.md).
- Added `prefer_single_ticker_provider_state_mixin` (recommended, info) so single-controller states use the lighter mixin and intent is obvious. No action required; see [bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md](bugs/infra_propose_prefer_single_ticker_provider_state_mixin.md).
- Added `prefer_animation_controller_forward_from_zero` (recommended, warning) with a quick fix so press-and-bounce gestures always restart from zero and feel consistent on rapid taps. No action required.

### Changed

- Consolidated analysis logs now lead with concentration, delta-since-last-run, and triage hints on large backlogs, and the top-rules table adds share, source, and fixable columns so you can prioritize work. No action required; see [bugs/infra_analysis_report_insufficient_for_large_backlogs.md](bugs/infra_analysis_report_insufficient_for_large_backlogs.md).

### Fixed

- Several “wrong platform” rules now bail when the repo cannot build the platform they warn about, so mobile-only and similar setups stop getting irrelevant noise. No action required; see [bugs/platform_gate_missing_from_sibling_rules.md](bugs/platform_gate_missing_from_sibling_rules.md).
- `avoid_platform_specific_imports` stays silent when the Flutter app has no `web/` tree, since `dart:io` web breakage is not applicable there. No action required; see [bugs/avoid_platform_specific_imports_false_positive_non_web_project.md](bugs/avoid_platform_specific_imports_false_positive_non_web_project.md).
- Pubspec dependency names parse correctly again so `hasDependency`-gated rules and import checks behave; this removes the flood of bogus “not in pubspec” findings. No action required; see [bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md](bugs/depend_on_referenced_packages_name_collision_with_sdk_lint.md).
- Renamed saropa’s duplicate lint to `saropa_depend_on_referenced_packages` so counts and ignores align with the SDK’s `depend_on_referenced_packages`. Use `// ignore: saropa_depend_on_referenced_packages` or disable that code in `plugins: saropa_lints` if you only want to silence saropa’s copy; `// ignore: depend_on_referenced_packages` still targets the SDK lint only.
- Analyzer-plugin reports populate the configuration block instead of showing “not captured,” so reports stay self-describing. No action required.
- Extension Run Analysis warning popups show the real issue count from `violations.json` instead of a slice of progress stderr. No action required; see [bugs/infra_run_analysis_popup_dumps_progress_stderr.md](bugs/infra_run_analysis_popup_dumps_progress_stderr.md).

<details>
<summary>Maintenance</summary>

- Internal tweak to `prefer_animation_controller_forward_from_zero` detection so publish CI anti-pattern gates stay satisfied; rule behavior unchanged. No action required for consumers.

</details>

---

## [12.3.4]

New `avoid_drift_insert_missing_conflict_target` flags Drift inserts that omit the right `onConflict` target on tables with a non-primary unique index, matching the class of SQLite `UNIQUE` failures you otherwise hit at runtime. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.4/CHANGELOG.md)

### Added

- Added `avoid_drift_insert_missing_conflict_target` (essential, error) so Drift inserts declare the correct conflict target when a non-PK unique index exists and you avoid silent `SqliteException` failures. No action required; see [bugs/infra_new_rule_drift_insert_missing_conflict_target.md](bugs/infra_new_rule_drift_insert_missing_conflict_target.md).

---

## [12.3.3]

Path-safety rules ignore clearly safe literal-only helpers and common Dart SDK path sources, `avoid_null_assertion` skips typical `RegExpMatch.group(n)!` after a match, and `prefer_debug_print` stops recommending Flutter-only APIs in pure Dart packages. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.3/CHANGELOG.md)

### Fixed

- `avoid_path_traversal` and `require_file_path_sanitization` no longer flag private helpers fed only literals or paths resolved via trusted SDK entry points, so asset helpers and similar code stay clean while real taint stays covered. No action required; see [bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md](bugs/avoid_path_traversal_false_positive_internal_resolver_parameter.md) and [bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md](bugs/require_file_path_sanitization_false_positive_internal_resolver_parameter.md).
- `prefer_debug_print` is skipped for non-Flutter packages so you are not told to import Flutter just to silence `print` guidance. No action required; see [bugs/prefer_debug_print_false_positive_pure_dart_package.md](bugs/prefer_debug_print_false_positive_pure_dart_package.md).
- `avoid_null_assertion` allows `RegExpMatch.group(n)!` on matched regex results so you are not pushed into dead null-fallbacks for common parsing loops. No action required; see [bugs/avoid_null_assertion_false_positive_regex_match_group.md](bugs/avoid_null_assertion_false_positive_regex_match_group.md).

---

## [12.3.2]

`saropa_lints` itself passes `dart analyze --fatal-infos` again thanks to dogfood-only disables and small plugin fixes; publish script gains a publish-existing-.vsix mode. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.2/CHANGELOG.md)

### Fixed

- `dart analyze --fatal-infos` is clean on saropa_lints itself via targeted code fixes plus dogfood-only disables in this repo’s `analysis_options.yaml`, so maintainers can ship without thousands of self-applied rule hits while published consumer behavior is unchanged. No action required for package users.

<details>
<summary>Maintenance</summary>

- Publish script adds mode 7 to publish the newest packaged `.vsix` without repackaging after `pubspec`/`package.json` post-publish bumps, avoiding version skew when finishing a partial extension release. No action required for package users.

</details>

---

## [12.3.1]

Hotfix: tier-based `scan` and similar flows no longer crash on the second file when rule packs merge into an unmodifiable tier set. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.1/CHANGELOG.md)

### Fixed

- Rule-pack reload now copies enabled-rule sets before mutating them, so `scan` with `essential`/`recommended` tiers and pack merges no longer throws on the second analyzed file. No action required.

---

## [12.3.0]

Windows vibrancy scans run again, footprint sizes reflect transitive packages, the analyzer plugin logs to `reports/.saropa_lints/plugin.log` and no longer goes silent when the server cwd differs from your project, the vibrancy report toolbar adds rescan / open-project / copy-all-json, and `prefer_listenable_builder` nudges `AnimatedBuilder` uses that should be `ListenableBuilder`. — [log](https://github.com/saropa/saropa_lints/blob/v12.3.0/CHANGELOG.md)

### Added

- Plugin log file at `reports/.saropa_lints/plugin.log` surfaces startup and config-load issues without digging in Dart server logs. No action required.
- `prefer_listenable_builder` (recommended, info) with quick fix for `Listenable` sources that are not `Animation`, gated below Flutter 3.13. No action required; see [plan/054-prefer_listenable_builder_over_animated_builder.md](plan/054-prefer_listenable_builder_over_animated_builder.md).
- `ProjectContext.flutterSdkAtLeast` lets future rules respect declared Flutter lower bounds. No action required.
- Vibrancy report toolbar adds Copy All JSON, Rescan, and Open Another Project for side-by-side scans. No action required.

### Changed

- Vibrancy commands are grouped under the Saropa palette with shorter titles; command IDs unchanged. No action required.
- Stars column becomes Likes + Downloads (per-package signals) with JSON fields updated accordingly. No action required.
- Update column right-aligns with other numeric columns. No action required.

### Fixed

- Extension vibrancy CLI on Windows now resolves `dart.bat` via the shell so pub graph and outdated data load instead of failing quietly. No action required.
- Footprint modes now include sizes for transitives pulled from pub cache so Own / +Unique / +All differ when deps exist. No action required.
- Analyzer plugin registers all rules then honors `diagnostics:` from the real project root, so IDE sessions no longer show zero saropa diagnostics when config was read from the wrong cwd. No action required.
- Import+export on the same file counts once in References, with both line locations preserved in tooltips and exports. No action required.
- Report and Known Issues search trims whitespace and adds a clear control so pasted names match rows. No action required.
- Header gauge fill renders correctly after CSS fix. No action required.
- Violations tree filenames open the editor on click when the file exists. No action required.

---

## [12.2.1]

Publish script now verifies Marketplace and Open VSX separately, so an expired Marketplace token surfaces a concrete ACTION REQUIRED warning and auto-opens the manage page instead of a silent 0-exit. — [log](https://github.com/saropa/saropa_lints/blob/v12.2.1/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- Publish script verifies Marketplace and Open VSX separately with actionable warnings when a store never shows the new version. No action required for package users.

</details>

---

## [12.2.0]

Letter grades replace fractional scores across the vibrancy report, tree, exports, and related UI, and footprint views clarify unique versus shared transitive size. Ten new quick fixes land for common style rules, plus two new Dart rules for symlink checks and JS interop migration. — [log](https://github.com/saropa/saropa_lints/blob/v12.2.0/CHANGELOG.md)

### Added

- Ten new quick fixes cover record wildcards, `const`/`final` tweaks, `unawaited`, doc `new` cleanup, and related style nags so lightbulb workflows cover more rules. No action required.
- `prefer_type_sync_over_is_link_sync` (recommended, warning) steers you off Windows-broken `isLinkSync` toward `typeSync` link detection. No action required.
- `avoid_removed_js_number_to_dart` (recommended, warning) flags removed `JSNumber.toDart` and points to typed `toDartDouble` / `toDartInt`. No action required.
- Vibrancy report adds footprint toggles, true-footprint detail, re-export-aware single-use logic, optional startup-scan skip with settings, wired cache TTL, and clear-cache resets the skip fingerprint. No action required.

### Changed

- Vibrancy surfaces grades (A–F) instead of `n/10` in reports, cards, gauge, tooltips, CodeLens, diagnostics, exports (JSON still carries numeric score), and logger output for consistent scanning. No action required.

### Fixed

- Dense report headers stay on one line with nowrap layout, and the “(new)” age suffix under one month is dropped as misleading. No action required.

---

## [12.1.0]

The vibrancy report adds a radial gauge, letter-grade badges, expandable per-package detail, keyboard navigation, and a Deps column that highlights shared transitives. — [log](https://github.com/saropa/saropa_lints/blob/v12.1.0/CHANGELOG.md)

### Added

- Saropa Package Vibrancy report shows version, gauge, A–F badges, expandable rows with full package context, keyboard navigation, and a Deps column with shared-transitive emphasis so dependency risk is obvious at a glance. No action required.

### Fixed

- Gauge thresholds match category cutoffs; sorting and filtering keep detail rows attached to their parent so expanded cards never orphan. No action required.

---

## [12.0.3]

Package upgrade plans skip constraints you cannot bump via semver, show real resolver errors, and keep iterating after a single package fails. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.3/CHANGELOG.md)

### Fixed

- Upgrade planner omits git/path/SDK entries that cannot be semver-bumped, prints concrete pub errors instead of generic “pub get failed,” and advances to the next package after each rollback. No action required.

---

## [12.0.2]

Size Distribution splits unique versus shared transitives and adds “Exclude shared” so apparent package weight reflects deps you do not already carry. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.2/CHANGELOG.md)

### Added

- Size Distribution chart separates unique and shared transitive weight with an optional hide-shared toggle so bar, donut, and table percentages reflect removable cost. No action required.

---

## [12.0.1]

Overview shows a Set Up Project banner and activation toast when `saropa_lints` is missing from `pubspec.yaml`, so onboarding is one click. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.1/CHANGELOG.md)

### Changed

- Extension surfaces setup banner plus activation toast for Dart workspaces without saropa_lints so install/configure is obvious. No action required.

---

## [12.0.0]

Analyzer 11 compatibility is restored so saropa_lints resolves on current Flutter stable (analyzer 12 required `meta` versions Flutter does not ship yet). Rule and quick-fix counts are unchanged from the prior release line. — [log](https://github.com/saropa/saropa_lints/blob/v12.0.0/CHANGELOG.md)

### Fixed

- Dependency stack pins `analyzer` and `analyzer_plugin` to ranges compatible with Flutter stable’s pinned `meta`, fixing pub resolution failures. No action required; see [bugs/infra_meta_pin_flutter_incompatible.md](bugs/infra_meta_pin_flutter_incompatible.md).
- Small compatibility shim keeps class-body iteration working on analyzer 11. No action required.


---

## [11.1.0]

Ten new quick fixes cover library names, `late` patterns, `unawaited`, `toString`, `@useResult`, and positional booleans so more saropa rules are one-click fixable in the IDE. — [log](https://github.com/saropa/saropa_lints/blob/v11.1.0/CHANGELOG.md)

### Added

- Quick fixes ship for `unnecessary_library_name`, `avoid_late_for_nullable`, `prefer_late_final`, `prefer_abstract_final_static_class`, `avoid_async_call_in_sync_function`, `avoid_default_tostring`, `missing_use_result_annotation`, `avoid_unnecessary_local_late`, `avoid_unnecessary_late_fields`, and `avoid_positional_boolean_parameters`, reducing manual cleanup. No action required.

### Changed

- `RemoveLateKeywordFix` also covers local variable statements used by `avoid_unnecessary_local_late`. No action required.

<details>
<summary>Maintenance</summary>

- Extension npm overrides pin `serialize-javascript` to a patched release for a transitive CVE. No action required for Dart-only consumers.

</details>

---

## [11.0.0]

Extension Overview gains command search, embedded health and risk summaries, richer vibrancy package detail (logos, README shots, adoption bonus), unique-vs-shared dependency insight, File Risk workflow polish, and suppression records exported with violations for auditing. — [log](https://github.com/saropa/saropa_lints/blob/v11.0.0/CHANGELOG.md)

### Added

- Command catalog sidebar, embedded health/risk cards, richer vibrancy detail (topics, likes, docs, README imagery with CSP updates), reverse-dependency scoring bonus, and plugin suppression tracking in `violations.json` so ignored diagnostics are measurable. No action required.

### Changed

- Vibrancy charts and trees highlight unique vs shared transitives; File Risk moves up with JSON export, click-to-open, diagnostics-aware hiding, persistent disable actions, cleaner labels, and richer pubspec hovers with outbound links. No action required.

### Fixed

- Violations tree survives transient `violations.json` read gaps; pubspec diagnostics dedupe on startup; stale-override detection respects active SDK-pin overrides. No action required.

<details>
<summary>Maintenance</summary>

- Example fixture packages consolidated from seven layouts to two to reduce repo maintenance. No action required for package users.

</details>

---

## [10.12.2]

Pubspec lines can opt out of specific saropa pubspec checks with inline comments, `prefer_l10n_yaml_config` stops false-positiveing split l10n setups, and vibrancy scan logging is calmer. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.2/CHANGELOG.md)

### Added

- `# saropa_lints:ignore <codes>` on pubspec lines suppresses individual pubspec validation hits without turning rules off globally. No action required.

### Fixed

- `prefer_l10n_yaml_config` ignores the normal `generate: true` + `l10n.yaml` combo. No action required.
- Vibrancy scan logs debounce, append per day, and skip duplicate runs instead of spawning endless log files. No action required.

---

## [10.12.1]

CI publish unblocked by removing a stray `publish_to: "none"` placeholder from the package manifest. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.1/CHANGELOG.md)

### Fixed

- Repository `pubspec.yaml` no longer carries a template `publish_to: "none"` so automated pub publish succeeds. No action required for consumers.

---

## [10.12.0]

Pubspec and adoption tooling see fewer false positives, diagnostics pick up a consistent `[saropa_lints]` prefix, plugin self-fire guards work per-file, Help hub and command catalog UX improve, and dependency sort preserves comments. — [log](https://github.com/saropa/saropa_lints/blob/v10.12.0/CHANGELOG.md)

### Fixed

- `avoid_hardcoded_config`, pubspec ordering, adoption badges, `prefer_publish_to_none`, and prefixed pubspec diagnostics trim false positives on normal Flutter/SDK layouts. No action required.
- Plugin self-source checks run per-file so rules no longer fire on their own fixture literals. No action required.

### Added (Extension)

- Help hub command plus Overview/Violations entry points surface onboarding, catalog, and pub.dev links without hunting the palette. No action required.

### Fixed (Extension)

- Sort Dependencies keeps per-entry comments and trailing section banners instead of deleting them. No action required.

### Changed (Extension)

- Command catalog gains refreshed layout, codicons, recent-command replay, tighter toolbars, and better search ordering for narrow layouts. No action required.

<details>
<summary>Maintenance</summary>

- Shared SDK package name list deduped for annotate/unused/sort paths with missing SDK entries restored. No action required for package users.

</details>

---

## [10.11.0] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 10.11.0.

