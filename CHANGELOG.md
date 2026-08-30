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

2300+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

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

    **Unreleased convention** — The top changelog section MUST use the heading `## [X.Y.Z] — Unreleased` (with ` — Unreleased` suffix) while work is in progress. All new entries go into this ONE section — never create a second unreleased section or bump the version number. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) at publish time via `_strip_unreleased_suffix()`. The version numbers in `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle.

    **Tagged changelog** — Published versions use git tag `vx.y.z`. Each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

    **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

    **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [15.2.5] — Unreleased

This patch moves `log_level`, `lane`, and `memory_mode` configuration from the `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level keys in `analysis_options_custom.yaml`, eliminating false `unsupported_option` warnings from the Dart SDK's plugin-block validator. Projects using the old location get a deprecation warning and automatic fallback — the keys still work from the plugin block, but moving them to the custom file silences the warnings.

### Fixed

- `log_level`, `lane`, and `memory_mode` plugin configuration keys no longer trigger `unsupported_option` warnings from the Dart SDK analyzer. These keys now live as top-level entries in `analysis_options_custom.yaml` instead of under `plugins > saropa_lints:`. Projects still using the old location get a deprecation warning with the key's value honored as a fallback; `dart run saropa_lints init` generates the updated layout automatically.

### Added

- **Full Audit CLI** — `dart run saropa_lints audit <dir>` runs every rule (pedantic + stylistic) against a codebase regardless of the project's configured tier. Produces enriched JSON with per-diagnostic `tier` and `category` fields. Supports `--since <ref>` to audit only changed files, `--min-severity`/`--min-impact` post-filters, `--profile` timing, and `--exclude-globs`/`--include-globs`.
- **Full Audit sidebar button** — new "Full Audit" entry in the extension sidebar launches the audit with a scope quick-pick (full project, changed vs main, or pick a branch) and opens a filterable report webview with search, tier/severity/impact filter chips, sortable columns, and JSON export. The progress notification shows real-time percentage, file count, issue count, and current filename.
- **Audit report keyboard navigation** — use ↑/↓ arrow keys to move between rows and Enter to open the file at that diagnostic. A "no matches" state now appears when filters exclude all results.
- **Audit baseline diffing** — `--save-baseline` saves the current audit as a project baseline at `.saropa/audit_baseline.json`; `--baseline` compares against the saved baseline and tags each diagnostic as new or unchanged. The sidebar quick-pick shows a "Compare to baseline" option when a baseline exists, and the report webview has a "Save as baseline" button and new/unchanged filter chips.
- **Migrate Config** — `dart run saropa_lints migrate-config` and a sidebar button ("Migrate config keys") automatically move `log_level`, `lane`, and `memory_mode` from the old plugin block to `analysis_options_custom.yaml`. Safe to run multiple times; already-migrated keys are skipped.

### Fixed

- `prefer_sorted_parameters` no longer conflicts with `dart format`. The rule now respects `always_put_required_named_parameters_first`: required named parameters come first, then optional named parameters, each group sorted alphabetically. Includes a quick fix that reorders parameters automatically. ([#321](https://github.com/saropa/saropa_lints/issues/321))
- `require_text_overflow_handling` and `require_text_overflow_in_row` correction messages no longer default to `TextOverflow.ellipsis`. The guidance now recommends wrapping in `Expanded`/`Flexible` first — ellipsis is a last resort when truncation is intentional. This prevents AI agents from blindly hiding text behind ellipsis. ([#320](https://github.com/saropa/saropa_lints/issues/320))
- `prefer_single_declaration_per_file` no longer fires on sealed class hierarchies. Dart requires sealed subtypes in the same library, so co-locating them is mandatory, not a style violation. ([#322](https://github.com/saropa/saropa_lints/issues/322))
- `avoid_unused_parameters` no longer fires on abstract, external, or native method declarations. These methods have no implementation body, so their parameters define the interface contract and cannot be "used." ([#319](https://github.com/saropa/saropa_lints/issues/319))

### Changed (Extension)

- The lane picker now reads and writes `lane:` from `analysis_options_custom.yaml` instead of `analysis_options.yaml`. No action required — the extension handles the new location transparently.

---

## [15.2.4]

This patch release focuses on refining the avoid_unguarded_debug rule to eliminate several false positives. The rule now correctly recognizes early-exit returns and safely resolves variable-indirection chains for debug mode checks. Behind the scenes, early-exit and guard-evaluation utilities were unified across multiple core rules to ensure consistent behavior moving forward. [log](https://github.com/saropa/saropa_lints/blob/v15.2.4/CHANGELOG.md)

### Fixed

- `avoid_unguarded_debug` no longer false-positives when `debugPrint()` is dominated by an early-return guard (`if (!kDebugMode) return;`) at the top of the enclosing block. Also recognizes `kDebugMode == false`, `kDebugMode != true`, reversed operand order (`false == kDebugMode`), and multi-statement then-blocks ending in `return`. No action required.

### Added

- `avoid_unguarded_debug` now recognizes variable-indirection guards: `final isDebug = kDebugMode; if (!isDebug) return;` is accepted, including chained assignments up to 3 levels deep and top-level/static `const` fields in the same file. Only `final` and `const` are trusted — mutable assignments are correctly rejected. No action required.

<details><summary>Maintenance</summary>

- Extracted shared `early_exit_guard_utils.dart` — `containsEarlyExit`, `endsWithEarlyExit`, `findPrecedingGuardInBlock`, and `hasDominatingEarlyExitGuard` replace five independent reimplementations across `debug_rules.dart`, `collection_rules.dart`, `async_rules.dart`, `type_rules.dart`, and `code_quality_avoid_rules.dart`.
- `hasDominatingEarlyExitGuard` now supports a `stopAtClosureBoundary` parameter — runtime-mutable guards (collection emptiness) stop at closure/function boundaries; compile-time constants (`kDebugMode`) opt out since closures in the guarded zone are safe.
- `endsWithEarlyExit` now recognizes `break` and `continue` statements, matching the coverage of `containsEarlyExit`.
- Variable-indirection resolver follows chained `final`/`const` assignments up to 3 levels with cycle detection, and resolves top-level/static class fields via pure AST walk (no type resolution — rule stays in the light analysis lane).
- `_findLocalInitializer` now only considers declarations preceding the usage site (offset-based guard prevents forward-reference resolution).

</details>

---

## [15.2.3]

Major scan CLI expansion: lane control (`--lane full|light`, `--lane-stats`), CI gating by rule impact or tier (`--fail-on-impact`, `--fail-on-tier`), stale-ignore detection (`--find-stale-ignores`), SDK compatibility audit (`--check-sdk-compat`), and include/exclude glob filters for fine-grained file targeting. Eight false-positive fixes across core rules including `avoid_context_in_async_static`, `avoid_large_list_copy`, `avoid_datetime_constructor`, `no_equal_nested_conditions`, and the context-across-async family. An OOM crash fix for projects over 4 000 files adds per-file memory budgeting and adaptive RSS caps. Two new rules: `prefer_primary_constructor` (Dart 3.13+ syntax) and `require_sdk_syntax_match` (catches AI-generated code using syntax the project's SDK constraint doesn't support). [log](https://github.com/saropa/saropa_lints/blob/v15.2.3/CHANGELOG.md)

> The `analyzer ^13.1.0` migration (Dart 3.13+ / Flutter 3.47.1+, released 2026-08-19) is complete and tested but held off `main` — adoption of 3.47.1 is near zero. It is parked on the `analyzer-13-migration` branch and will ship as a `<n+1>`.0.0 major bump once adoption is widespread.

### Fixed

- `avoid_context_in_async_static` no longer false-positives when `BuildContext` is passed solely as an argument to the awaited call and never read after the `await` resumes (e.g. `await showDialog(context: context)`). The rule now walks all context usages in the method body and suppresses the diagnostic when every usage is consumed synchronously inside the awaited expression. No action required.
- `avoid_large_list_copy` no longer false-positives when `.toList()` feeds a `??` expression, a `List<T>`-typed argument, an explicit `List<T>` variable, a `List<T>` return type, a cascade, a property access, or a collection literal — all cases where removing `.toList()` would cause a compile error. No action required.
- `avoid_datetime_constructor` and `avoid_datetime_constructor_unvalidated` no longer flag `DateTime()` / `DateTime.utc()` calls when all three date components (year, month, day) are property accesses on a `DateTime`-typed expression, since the source object already guarantees valid components. Day arithmetic (`dt.day ± N`) is also suppressed because Dart documents rollover behavior. No action required.
- `no_equal_nested_conditions` no longer false-positives when the condition variable is reassigned between the outer and inner checks (e.g. `if (x == null) { x = compute(); if (x == null) ... }`). Simple, null-aware (`??=`), and compound (`+=`) assignments are all recognized. No action required.
- `avoid_future_in_build` (v3) removed name-prefix heuristic that only caught methods starting with `fetch`/`load`/`get`/etc. Now flags ANY method invocation in `FutureBuilder(future:)` inside `build()`. Also detects non-deterministic `Future` constructors while exempting `Future.value()` and `Future.error()`. Scoped to `FutureBuilder` only (no longer flags custom widgets with a `future:` parameter). Widget class detection now covers third-party bases (`HookWidget`, `ConsumerWidget`, etc.). No action required.
- `pass_existing_future_to_future_builder` (v9) no longer flags `Future.value()` and `Future.error()` constructors. Cache-method exemption now also recognizes `@cachedFuture` annotation from `package:saropa_lints/annotations.dart`. No action required.
- `require_error_widget` no longer false-positives when error handling is delegated to an extension method on the snapshot parameter (e.g. `snapshot.snapLoadingProgress()`). Any method invocation on the snapshot is now recognized as delegated error handling. No action required.
- **OOM crash on large projects (4000+ files):** The in-process analyzer plugin could exhaust memory on projects with thousands of files because forward-accumulating trackers were never evicted under pressure, the hard RSS safety valve defaulted too high, and violation tracking continued after the valve tripped. The plugin now sheds tracker data under memory pressure, stops accumulating records while memory-critical, adapts the default RSS cap to 60% of system RAM (capped at 8 GB on high-RAM machines), warns when the project exceeds 2000 files, and includes tracker sizes in the memory estimate. No action required — set `SAROPA_LINTS_MAX_RSS_MB` to override the adaptive cap.
- **Scan CLI:** Rules with `usesTypeResolution`, INFO severity, or cost above `low` were silently blocked by the analysis-server lane gate, which defaulted to `light` in the CLI path. The scanner now runs at full lane coverage so all enabled rules fire correctly. No action required.
- `avoid_context_across_async` and `avoid_retaining_disposed_widgets` now check the resolved type (when type information is available, e.g. in-editor or `--resolve` scans) instead of matching on the bare identifier/type name alone. Fixes false positives on non-Flutter classes that happen to be named `context` or `Element` (an analyzer `Element`, a custom `Context` type, etc.). No action required.
- Scan CLI now excludes platform ephemeral directories (`ephemeral/`, `.plugin_symlinks/`) by default. Previously these symlinked plugin sources appeared in scan results even though the user doesn't control them. No action required — the exclusion is automatic. ([#313](https://github.com/saropa/saropa_lints/issues/313))

### Added

- **`DateUtils.dateOnly()` quick fix** for `avoid_datetime_constructor` and `avoid_datetime_constructor_unvalidated` — recognizes the strip-time idiom `DateTime(x.year, x.month, x.day)` and the explicit-midnight-zeros variant `DateTime(x.year, x.month, x.day, 0, 0, 0)`, replacing both with `DateUtils.dateOnly(x)`. Appears above the existing `DateTime.tryParse()` fix when both apply. Not offered for `.utc()` constructors, nullable receivers, non-DateTime types, or pure Dart projects without Flutter. No action required.
- **Per-file memory budget:** On large projects approaching the RSS cap, the plugin now skips cold (unmodified >24h) files and prioritizes recently edited files for lint analysis — partial coverage instead of all-or-nothing OOM. The analysis summary reports how many files were skipped. No action required.
- **`@cachedFuture` annotation** (`package:saropa_lints/annotations.dart`) — marks a method as returning a cached Future, suppressing `pass_existing_future_to_future_builder` without needing the heuristic (private method + `Future?` field). Use when your naming convention doesn't match the heuristic.
- New rule: `prefer_primary_constructor` (Professional, INFO) — flags classes eligible for Dart 3.13+ primary constructor syntax when the project's SDK lower bound is >=3.13.0. Reduces boilerplate for simple data classes that AI generators consistently produce in the verbose pre-3.13 form. Detection only for now — the quick fix ships with the analyzer 13 migration on the `analyzer-13-migration` branch. No action required.
- New rule: `require_sdk_syntax_match` (Comprehensive, WARNING) — flags Dart syntax features that require a newer SDK than the lower bound declared in pubspec.yaml, with a quick fix to raise the SDK lower bound. Catches AI-generated code that uses records, switch expressions, extension types, or digit separators when the project's SDK constraint doesn't support them. No action required.
- Scan CLI: `--lane full|light` flag controls which rule lane the scanner uses. Defaults to `full` (every enabled rule); `light` restricts to the same cheap, resolution-free subset the analysis server runs in its default lane. No action required — existing scans are unaffected.
- Scan CLI: `--lane-stats` prints how many of the loaded rules are light-lane vs full-only; when in light lane, lists every blocked rule name so the gate's effect is fully observable.
- Scan CLI: `--check-sdk-compat` standalone audit cross-references the pubspec SDK lower bound against Dart syntax features in `lib/`. Prints a grouped summary showing which files force each version bump. Exits 1 on mismatch, 0 when compatible — suitable for CI gating.
- Scan CLI: `--exclude-globs <pattern>...` flag excludes files matching glob patterns from the scan. Supports `**` (any path segments), `*` (any non-separator chars), and `?` (single char). Use it to skip vendored code, generated directories, or any paths the hardcoded exclusions don't cover. ([#313](https://github.com/saropa/saropa_lints/issues/313))
- Scan CLI: `--include-globs <pattern>...` flag overrides the hardcoded exclusions for matching paths — when a path matches both a default exclusion and an include-glob, the include wins. Use it to force-scan third-party plugin code in ephemeral or generated directories. ([#313](https://github.com/saropa/saropa_lints/issues/313))
- Scan CLI: `--fail-on-impact <level>` flag exits 1 when any saropa rule's declared impact meets the threshold (info/warning/error). Unlike `--fail-on` (which uses analyzer severity), this checks the rule author's business-consequence rating — use it to gate CI on high-impact rules regardless of their configurable severity. Pair with `--fail-on-impact-count <n>` to tolerate a known baseline during migration. ([#312](https://github.com/saropa/saropa_lints/issues/312))
- Scan CLI: `--fail-on-tier <name>` flag exits 1 only when a diagnostic comes from a rule in the specified tier or below. Scan at a high tier for visibility but only fail on essential-tier findings during incremental adoption — e.g. `--tier comprehensive --fail-on-tier essential`. ([#312](https://github.com/saropa/saropa_lints/issues/312))
- Scan CLI: `--find-stale-ignores` flag detects `// ignore:` comments whose suppressed saropa_lints rule no longer fires on the target line — the code was fixed but the ignore was left behind. Reports each stale ignore with file path, line number, and rule name. Supports `--format json` for CI integration. Exits 1 if any stale ignores found, 0 if clean. No action required.
- Scan CLI: `--fix-stale-ignores` flag detects AND automatically removes stale `// ignore:` directives from source files. Standalone comments are deleted entirely; inline comments are stripped preserving the code; multi-rule comments have only the stale rules pruned. Prints a summary of files modified. No action required.
- **VS Code extension: Stale Ignore commands** — two new command palette entries ("Find Stale Ignore Comments" and "Fix Stale Ignore Comments") plus sidebar action rows in the Settings panel. Find runs the scan and publishes stale ignores as warnings in the Problems panel with squiggly lines on the offending comment lines. Fix confirms before auto-removing dead `// ignore:` comments from source files. A lightbulb quick fix on each stale-ignore diagnostic offers a file-scoped "Fix stale ignores in this file" action with no confirmation prompt, for cleaning up one file at a time without leaving the editor. No action required.

### Changed

- `avoid_wildcard_cases_with_enums` (v6) now suppresses the diagnostic when the switched enum has more than 20 members, where exhaustive case listing is impractical and a `default:` catch-all is the correct design choice. Also upgraded from string heuristic to proper `EnumElement` resolution when type information is available. No action required.
- `avoid_stream_in_build` (v3) now also detects `StreamBuilder(stream: method())` where a method invocation creates a new subscription on every rebuild. Previously only caught `StreamController()` instantiation inside `build()`. Excludes safe constructors (`Stream.value()`, `Stream.empty()`) and the `??=` caching idiom. A new quick fix converts a simple `StatelessWidget` flagged this way into a `StatefulWidget` with the stream cached in `initState()`. No action required.
- **known_issues.json** — reviewed 51 flagged entries against live pub.dev data. Version-scoped 2 entries (flutter_calendar_carousel, keyboard_actions) whose issues were fixed in newer releases. Updated workmanager and flutter_email_sender from stale caution to active. Fixed missing reason on flutter_vibrate. Updated better_player from stale maintenance_mode to active.
- **known_issues.json** — source-verified the remaining 10 UNCLEAR entries from that review. Removed 5 entries with no corroborating evidence in changelogs or issue trackers (agora_rtc_engine end-of-life claim, badges Material 3 bug, flutter_cache_manager disk-space bug, fluttertoast overlay/context leak, google_fonts thread-blocking claim). Version-scoped or corrected 6 entries against confirmed fix versions (animations, audioplayers, flutter_downloader, flutter_modular, graphql, shimmer). No action required.

<details><summary>Maintenance</summary>

- Extracted shared `isWidgetOrStateClass()` and `isInsideBuildMethod()` utilities into `target_matcher_utils.dart` — used by `avoid_stream_in_build` and `avoid_future_in_build`; replaces per-rule private duplicates.
- **Publish script: fixed Dart frontend_server crash** — `dart test -j <all-cores>` (24 on a 24-core machine) caused native access violations (`STATUS_ACCESS_VIOLATION`) and `front_end` compiler exceptions during test compilation. The test step now auto-tunes concurrency by probing a single test at increasing `-j` levels (4, 6, 8, 10, 12), caching the result in `build/.dart_test_max_j`; crash retries halve concurrency automatically, the failure prompt offers `[F]ewer workers` to halve manually, and set `SAROPA_TEST_MAX_J=N` to skip the probe entirely.
- **Publish script: fixed test temp dir location** — kernel-cache `.dill` files were written inside the project tree (`build/test_tmp/`), causing `uri_does_not_exist` scan errors and filling the C: drive. Temp dir now defaults to `<system_temp>/saropa_dart_test` outside the project tree; set `SAROPA_TEST_TMP` to override (validated: falls back if inside project tree).
- Removed `plans/known_issues_review.md` from git tracking (generated file, regenerated each publish run).
- **New `dart run saropa_lints:memory_report` command** — summarizes the analysis server's RSS trend from `plugin.log` for post-crash diagnosis. The in-process plugin now writes a memory sample line roughly every 30 seconds; the command reports min/max/latest RSS, percent of the configured cap, and a CAVEAT when `plugin.log` was rotated mid-session (so the summary is known to be incomplete rather than silently wrong). A one-time log line now also flags when RSS sampling itself is unavailable on the current platform, so an empty trend log is diagnosable instead of looking identical to "plugin never ran".
- Reorganized the memory-monitor proposal into `plans/PLAN_analyzer_memory_monitor.md` (phased checklist: soft RSS threshold, selective rule shedding, VS Code status-bar integration), matching the repo's `PLAN_*` convention. Added `scripts/check_plan_naming.py` — an informational, non-blocking report of `plans/*.md` files that don't follow the `PLAN_<name>.md` naming convention.
- **Publish script: `--dry-run` CLI flag** — runs dependency resolution, audit, format, analysis, tests, and `dart pub publish --dry-run` with no commit, tag, version bump, or publish. Needs no pub.dev credentials; intended for CI pre-merge validation.
- **Publish script: further crash-detection hardening** — test-temp-dir contents are wiped before each run instead of accumulating across publish attempts, the temp dir is write-verified before use (falls back to system temp on failure), and the auto-tune concurrency cache key now includes an available-RAM bucket so a level probed safe on an idle machine doesn't get trusted indefinitely under memory pressure.
- **known_issues review script** — now skips entries with `appliesToMaxVersion` or `replacementObsoleteFromVersion` to avoid false-positive flagging of version-scoped entries that are correct by design.
- `require_sdk_syntax_match` quick fix: removed dead `Map<Type, String>` lookup (analyzer concrete types are private `*Impl` classes that never matched abstract keys); hardened regex with triple-quoted raw string to handle embedded quotes.
- `bugs/BUG_REPORT_GUIDE.md` renamed to `bugs/ISSUE_REPORT_GUIDE.md` and extended with a feature request template, proposal naming patterns, and lifecycle, alongside the existing bug report process.
- `_rule_metrics.py`'s bug counter now reports open feature proposals separately from unsolved bugs in the publish "WORK REPORT" banner, instead of lumping both into one count.
- Scan daemon and accuracy report now pass `lane: RuleLane.full` explicitly instead of relying on the constructor default.
- Scan CLI warns when `--lane light` is combined with `--exclude-light-lane` (degenerate: zero rules to scan).
- Fixed the 17 real ERROR-severity findings the full-lane self-scan surfaced against this package's own source: `double.parse(x.toStringAsFixed(n))` round-trip patterns in the project-health/vibrancy models now round arithmetically via a shared `roundToDecimalPlaces` helper instead of parsing a self-produced string; a regex-guaranteed-digits `int.parse` triple in the pubspec constraint parser is annotated as a verified false positive.
- **Changelog version-drift guard** — new `scripts/hooks/changelog_guard.py` (dual-mode: Claude PostToolUse + git pre-commit) blocks commits that introduce multiple unreleased sections in CHANGELOG.md or bump version numbers in pubspec.yaml / package.json ahead of the publish script. Publish script also gained `assert_single_unreleased_section()` as a belt-and-suspenders gate.
- **Publish script: live test progress** — `dart test` output now streams to the terminal with a real-time progress bar showing elapsed time, pass/skip/fail counts, and the current test name. Failure details print immediately instead of silently accumulating in a log file. Full output is still written to `reports/` for post-mortem analysis.
- **Publish script: delta-first testing** — the test step now automatically detects changed files via `git diff`, maps them to corresponding test files, and runs only those first (seconds instead of minutes). If the delta pass fails, it stops immediately without compiling the full 340+ file suite. Infrastructure changes (tiers, registration, pubspec) bypass delta and run the full suite.
- **Full Audit plan** — design for a "run every rule" audit feature: CLI subcommand (`dart run saropa_lints audit`), visible sidebar button + Explorer context menu, filterable webview report with tier/severity/impact/category facets, diff mode (`--since <ref>`) as a UI quick-pick, and baseline diffing (`--save-baseline` / `--baseline`) with datetime-stamped outputs. Plan at `plans/PLAN_full_audit.md`.
- **i18n translation pipeline: deferred Qwen/Ollama provisioning** — `extension/scripts/i18n/generate_locales.py` and `mt_fallback.py` previously resolved the primary MT engine (self-provisioning Ollama: starting the daemon, pulling a multi-GB model on first use) unconditionally before checking whether any locale actually had untranslated strings. A fully-cached run now never touches Qwen/Ollama at all — engine resolution is deferred until a string is confirmed missing from every cached engine's keyspace.
- **Publish script: no more forced retry on real test failures** — a failing test pass used to always re-run once automatically before asking the user anything, silently doubling the wait on a run that was never going to pass. The automatic retry now only fires when the failure is diagnosed as transient (VM crash or file lock) AND the pass is cheap (delta); the expensive full-suite ("fast") pass always goes straight to the Continue/Retry/Abort prompt on any failure, transient or not, so a multi-minute compile is never silently repeated without the user deciding.
- **`scan_cli_args_test.dart`: five untagged process groups now marked `tags: ['slow']`** — the `(process)` groups shell out to real `dart run saropa_lints:scan` subprocesses (including full essential-tier scans of the project itself) and were timing out at 2 minutes each under full-suite `-j` contention, failing the fast publish pass. Only the process-spawning groups are tagged; the ~250 in-memory `parseScanArgs` unit tests in the same file remain in the fast pass.
- **Publish script: fixed `dart fix` audit crash on Windows** — the two `dart fix` subprocess calls in the pre-publish audit were the only `dart` invocations in the publish modules missing shell mode, so they crashed with `WinError 2` on Windows where `dart` resolves to a `.bat` wrapper that `CreateProcess` cannot launch directly. Both calls now pass shell mode like every other subprocess in the pipeline.
- **`scan_cli_args_test.dart`: slow process groups given an explicit 5-minute timeout** — the publish delta pass runs changed test files with tag filters deliberately ignored, so the `slow` tag alone could not protect these tests there; each cold-starts an uncompiled scan CLI that can exceed the 2-minute default. Known limitation: the `--fail-on` group can still exceed even 5 minutes under contention — the durable fix (a precompiled scan snapshot) is tracked separately.

</details>

---

## [15.2.2]

**[CLI reference guide](https://github.com/saropa/saropa_lints/blob/v15.2.1/doc/guides/cli.md)** — complete flag tables, CI examples, and exit codes for every CLI command.

The scan CLI gains three new flags that make it easier to wire into CI and automation pipelines. `--min-impact` filters by the rule author's declared impact rather than the configurable analyzer severity, `--fail-on` decouples the exit code from display filtering so you can show everything but fail only on errors, and `--json-file-path` writes machine-readable output to a file without stdout redirection. A `--quiet` flag silences all progress chatter for fully headless runs. The Problems-tab cap (`max_issues`) is now actually enforced instead of just tracked. [log](https://github.com/saropa/saropa_lints/blob/v15.2.2/CHANGELOG.md)

### Added

- Scan CLI: `--min-impact` flag filters diagnostics by the rule's declared impact level (error, warning, info) instead of the analyzer severity. Some rules have info severity but warning impact; `--min-impact warning` excludes the truly-info ones. JSON output now includes an `impact` field per diagnostic. ([#308](https://github.com/saropa/saropa_lints/issues/308))
- Scan CLI: `--json-file-path <path>` writes JSON output directly to a file instead of stdout, so automation harnesses can consume the result without stdout redirection. Implies `--format json`. ([#310](https://github.com/saropa/saropa_lints/issues/310))
- Scan CLI: `--fail-on <severity>` decouples the exit code from display filtering — the scan shows all diagnostics (or those matching `--min-severity`) but exits 1 only when the full set contains at least one diagnostic at or above the threshold (e.g. `--fail-on error`). Pair with `--fail-on-count <n>` to tolerate a known baseline (exit 1 only when the count exceeds n). JSON output includes a `failOn` metadata object when the flag is active. ([#309](https://github.com/saropa/saropa_lints/issues/309))
- Scan CLI: `--quiet` / `-q` flag suppresses all stderr progress and status messages. The caller gets only the exit code and stdout output (report or JSON). Useful for fully silent automation paired with `--json-file-path`.
- Scan CLI: `--json-file-path` now creates parent directories if they don't exist, so callers don't need to `mkdir` first.

### Fixed

- The `max_issues` Problems-tab cap (default 500, configurable via `max_issues:` in `analysis_options_custom.yaml`) is now actually enforced. It previously tracked the count and printed a "N issues in Problems tab" message without withholding anything — every issue still reached the Problems tab regardless of the configured limit. ERROR-severity diagnostics always surface regardless of the cap; `violations.json` and the text report remain uncapped either way. No action required.
- Scan CLI progress messages ("Loaded N rules…", "Scanning N files…") now go to stderr instead of stdout, so `--format json` output is valid JSON when redirected to a file. No action required. ([#310](https://github.com/saropa/saropa_lints/issues/310))

### Added (docs)

- New standalone [CLI reference guide](doc/guides/cli.md) documents every CLI command (`init`, `scan`, `cross_file`, `project_vibrancy`, `quality_gate`, `baseline`, `rule_count`, `project_health`) with complete flag tables, CI examples, exit codes, and JSON output schema. The README scanner section is also updated with the full flag set. No action required.

<details><summary>Maintenance</summary>

- Publish script test runner now detects Dart VM heap corruption crashes and Windows file-lock races as transient infrastructure failures, shows a clear diagnosis, and recommends Retry instead of leaving the user to parse raw stack traces.

</details>

---

## [15.2.0]

Rule execution is roughly twice as fast, and the analysis server now reports the ~200 most important error and warning rules by default without holding the full resolved type model in memory — the remaining rules fire on save via the scan daemon so nothing is lost. Measured at +0.6% memory over the plugin-off baseline (vs +77.2% for full in-process coverage), so this is safe for every project with the `plugins:` block enabled, with no config change required. The About panel and tier picker now show live rule counts from a single source of truth, replacing stale hand-typed numbers. [log](https://github.com/saropa/saropa_lints/blob/v15.2.0/CHANGELOG.md)

### Added

- New `rule_count` CLI (`dart run saropa_lints:rule_count`, or `--format json`) reports the live rule count per tier plus opt-in stylistic rules, computed directly from `lib/src/tiers.dart`. No action required.
- New `--profile` flag on the scan CLI records per-rule execution timing and writes it to `reports/.saropa_lints/rule_timings.json` (slowest first, with call counts and averages). Timing was previously collected but never written anywhere; this makes slow rules measurable so performance work targets real offenders. No action required.
- New `lane` setting under `plugins.saropa_lints` controls which rules run inside the analysis server. `light` (the default when the key is absent) runs only the ~200 error and warning rules that need no type resolution, so those findings appear in the editor shortly after typing pauses rather than only after a save, without the editor holding the whole project's resolved type model; the rest still fire on save via the scan daemon. Set `lane: full` to keep the previous behavior of running every enabled rule in-process.

### Changed

- Rule execution is roughly twice as fast: project-root lookups are now memoized instead of re-walking the directory tree on every AST node, the hottest platform/import rules run their cheap syntactic checks before project gates, repeated file probes are cached, and deprecation checks are computed once per API element instead of once per reference — a 47% rule-time reduction on a 165-file before/after benchmark, confirmed at scale on a 4,487-file production app. No action required.

### Fixed

- `prefer_moving_to_variable`, `prefer_pattern_destructuring`, `avoid_multiple_stream_listeners`, and `require_sqflite_transaction` no longer re-scan nested scopes once per enclosing block, which removes duplicate diagnostics for the same code. Each nested block (an `if`/`else` arm, a loop or `try` body, any brace-delimited scope) is now judged on its own rather than summed with its enclosing scope — this also means a pattern split across a block boundary (e.g. 2 writes before a loop plus 1 inside it) may no longer trigger `require_sqflite_transaction` or `avoid_multiple_stream_listeners` where it previously did. No action required.
- Dropping a `.saropa_stop` file in the scan target root now actually aborts a running scan between files with a partial report, instead of being silently ignored by the scan CLI; the sentinel is consumed so the next scan runs normally. No action required.

### Added (Extension)

- (Extension) The About Saropa Lints panel now shows a live rule-count strip (total plus per-tier breakdown) fetched from the new `rule_count` CLI when a project is open, replacing the static number previously baked into the panel's markdown copy. No action required.
- (Extension) The Manage Rule Packs tier picker now shows each tier's live rule count next to its name (e.g. "essential 331 rules"), fetched once per panel open from the same `rule_count` CLI. No action required.
- (Extension) On-save scans now skip the rules the in-process plugin already reports when a project runs `lane: light`, so a finding is not listed twice in the Problems panel; the skip applies only while the plugin is verifiably reporting, so nothing is hidden if it is off or silent. No action required.
- (Extension) New "Saropa Lints: Set Analysis Lane" command (command palette, or the sidebar's Lane row) switches between `light` and `full` in-process analysis without hand-editing `analysis_options.yaml`. Picking a lane restarts the Dart analysis server so the change takes effect immediately.

<details>
<summary>Maintenance</summary>

- Widened the `rule_count` CLI's extension-side timeout from 10s to 25s — a cold `dart run` invocation measured at 8.4s, leaving too little margin under the old cap on a slower first run.
- Fixed the pre-commit hook's dart-fix and recommended.yaml gates: `subprocess.run(['dart', ...])` silently failed to find `dart` on Windows (Flutter ships `dart.bat`, which Python's subprocess can't resolve without `shell=True`), so both gates had been no-op'ing on every commit. Now resolved via `shutil.which('dart')`.

</details>

---

## [15.1.2]

The Upgrade Opportunities panel's AI prompt is more accurate and less noisy: it now surfaces the deprecated APIs a project actually calls, dual-dependency version risk, and possible local reimplementations of library code, while dropping dev-only and transitive dependencies that aren't actionable. The old per-card clipboard copy is replaced by "Write Report" buttons — global (all packages in one file) and per-card (single package) — that save dated files and copy the path. Seven actively-maintained packages were removed from the known-issues database after being incorrectly flagged as end-of-life. [log](https://github.com/saropa/saropa_lints/blob/v15.1.2/CHANGELOG.md)

### Added (Extension)

- (Extension) The Upgrade Opportunities AI prompt now includes deprecated APIs the project actually calls (with call sites), the package's vibrancy score/license/vulnerabilities/known-issue status, and any GitHub issues flagged as breaking or deprecation-related — previously only new-feature changelog bullets were included. No action required.
- (Extension) The Upgrade Opportunities panel no longer lists dev-only or transitive dependencies with zero source imports (e.g. `build_runner`), since new features in a package the project never calls are not actionable. No action required.
- (Extension) The AI prompt now flags "dual dependency" risk — a direct dependency that is also required transitively through another direct dependency — since a major version bump on either side can diverge type identity for shared exported classes. No action required.
- (Extension) The AI prompt now flags possible local reimplementation — project code (a class, mixin, extension, or function) whose name matches something the dependency's own source already exports — as a candidate for deletion in favor of the library version. No action required.

### Changed (Extension)

- (Extension) The Upgrade Opportunities panel replaces the per-card "Copy for AI" clipboard button with "Write Report" buttons — a global one in the header that writes all packages' prompts to one file, and a per-card one that writes just that package's prompt. Both save a dated markdown file under `reports/` and copy the absolute path to the clipboard. No action required.
- (Extension) The AI prompt's task instruction now asks two separate questions per feature — does it replace something the project does manually (retrofit), and does it solve a problem the project has never addressed (greenfield) — instead of only "does it fit an existing call site". No action required.

### Fixed (Extension)

- (Extension) Removed 7 stale entries from the Package Dashboard's known-issues database (`timezone`, `retrofit`, `sqflite_sqlcipher`, `intl_translation`, `window_size`, `routemaster`, `flutter_keychain`) that flagged actively-maintained packages as end-of-life based on outdated data. No action required.

<details><summary>Maintenance</summary>

- Added a pre-publish audit check that cross-checks `known_issues.json` lifecycle claims (end-of-life/caution/maintenance-mode) against live pub.dev data and warns when a package has since shipped a non-discontinued release contradicting the recorded reason. Non-blocking (network-dependent, 5s per-request timeout); run standalone with `python scripts/check_known_issues_freshness.py`.
- The pre-publish audit now also regenerates `plans/known_issues_review.md` on every publish run (previously only via manually running `scripts/generate_known_issues_review.py`), sharing one pub.dev fetch pass with the freshness check above instead of double-fetching the overlapping entries.
- Added unit test coverage for the freshness-check and review-report generator modules, and promoted their shared internals (candidate loading, pub.dev fetch, staleness rule) from private cross-module imports to an explicit shared surface.
- Corrected the advertised rule count from a stale "2100+"/"2134" to the current 2332 (2109 tiered + 223 opt-in stylistic) across the README, extension manifest, and marketing copy.

</details>

---

## [15.1.1]

Five new quick fixes for stylistic rules: convert regular comments to doc comments, remove redundant type annotations, replace string `+` concatenation with adjacent literals, simplify `BorderRadius.all(Radius.circular(r))` to `BorderRadius.circular(r)`, and replace sizing-only `Container` with `SizedBox`. [log](https://github.com/saropa/saropa_lints/blob/v15.1.1/CHANGELOG.md)

### Added

- Quick fix for `prefer_doc_comments_over_regular`: converts `//` comments to `///` doc comments with one click. No action required.
- Quick fix for `avoid_explicit_type_declaration`: removes the redundant type annotation, letting the compiler infer the type. No action required.
- Quick fix for `prefer_adjacent_strings`: strips `+` operators between string literals, producing idiomatic adjacent-string syntax. No action required.
- Quick fix for `prefer_borderradius_circular`: rewrites `BorderRadius.all(Radius.circular(r))` to the shorter `BorderRadius.circular(r)`. No action required.
- Quick fix for `prefer_sizedbox_over_container`: replaces sizing-only `Container` with `SizedBox`. No action required.

<details><summary>Maintenance</summary>

- Publish script now strips `- Unreleased` suffix (and typo variants) from versioned CHANGELOG headings at publish time, so `## [X.Y.Z] - Unreleased` is cleaned to `## [X.Y.Z]` before version sync.

</details>

---

## [15.1.0]

**Breaking:** 35 rule names that collided with core Dart/Flutter lint names are renamed with semantic suffixes (e.g. `prefer_single_quotes` → `prefer_single_quotes_strict`); 3 duplicates with no behavioral difference are removed. Old names are deprecated aliases for one release cycle. Use `--fix-ignores` to migrate downstream projects. [log](https://github.com/saropa/saropa_lints/blob/v15.1.0/CHANGELOG.md)

`require_ignore_comment_plugin_prefix` now validates prefixed ignore comments against the rule registry. Four false-positive fixes across gradient-in-build, dartdoc cross-refs, cyclomatic-complexity flat switches, and large-objects-in-state recomputed caches.

### Fixed

- `avoid_gradient_in_build` no longer flags gradients inside `AnimatedBuilder.builder`, `TweenAnimationBuilder.builder`, `ListenableBuilder.builder`, or `ValueListenableBuilder.builder` closures, where the gradient intentionally varies every animation frame. Also exempts gradients in any `builder:` closure when the gradient's arguments reference a closure-unique parameter (e.g. a tween value), making the gate work for custom animation builders too. No action required.
- `verify_documented_parameters_exist` no longer flags valid dartdoc cross-references to methods, functions, or getters as stale parameter names. No action required.
- `require_ignore_comment_plugin_prefix` now validates the suffix of already-prefixed ignore comments against the rule registry. A prefixed name that doesn't match any registered rule (typo, renamed rule, or fabricated name) now produces a diagnostic with a "did you mean?" suggestion and a quick fix to auto-replace the typo. No action required.
- `avoid_high_cyclomatic_complexity` no longer flags flat switch dispatch tables where every case is a single return, break, or expression with no nested branching — these are enum-to-value lookups with mechanical complexity, not logical branching. No action required.
- `avoid_large_objects_in_state` no longer flags collection fields that are reassigned wholesale in method bodies without accumulating mutations. Accumulation detection now uses element-resolved field matching (immune to shadowed locals), per-variable tracking for multi-variable declarations, constructor initializer list walking, and treats `??=` as a conditional reassignment instead of growth. No action required.

<details><summary>Maintenance</summary>

- Consolidated animation-builder widget name sets into `kAnimatedRebuilders` in `compound_performance_patterns.dart`, used by both compound-performance rules and `avoid_gradient_in_build`.
- Publish audit now blocks on core Dart lint name collisions (Check 8 in tier integrity), auto-updated from dart-lang/linter via `python scripts/update_core_lint_names.py`.
- Publish pipeline steps now prompt Retry / Ignore / Abort on failure instead of hard-exiting, so the developer can fix issues in another terminal without losing the publish session. Irreversible steps (git push, tag, pub.dev publish, GitHub release) only offer Retry / Abort.
- Removed unused `tiers.dart` import from formatting rules.
- MT cache serialization (`mt_fallback.py`) now streams entries to disk one-by-one instead of building the full JSON string in memory, fixing a `MemoryError` crash on large caches.

</details>

### Added (Extension)

- **Diagnostics** sidebar section — four severity toggles (`saropaLints.severity.error`, `.warning`, `.info`, `.hint`) plus the Lint integration, Analyzer plugin, and Tier controls (moved from Settings). Each severity has a colored icon (red/yellow/blue/green), requires double-click to toggle (preventing accidental flips), and shows an inline eye button on hover as a single-click fallback. No action required.

### Changed

- **Breaking:** 35 rules renamed with semantic suffixes to resolve name collisions with core Dart/Flutter lints. Update `analysis_options.yaml` and `// ignore:` comments to use the new names (e.g. `prefer_single_quotes` → `prefer_single_quotes_strict`). Old names remain as deprecated aliases for one release cycle.

### Removed

- **Breaking:** `avoid_private_typedef_functions`, `missing_code_block_language_in_doc_comment`, and `prefer_initializing_formals` removed — identical to core Dart lints with no behavioral difference. Use the core Dart lint instead; no action required if already enabled.

---

## [15.0.4]

Switching Lint integration on is now near-instant instead of a two-minute wait that looked like a freeze. Every command the extension shells out to a Dart tool for now uses the Dart executable directly rather than routing through Flutter, and the dependency resolve is skipped altogether when nothing needs resolving. [log](https://github.com/saropa/saropa_lints/blob/v15.0.4/CHANGELOG.md)

### Fixed (Extension)

- Turning Lint integration on took around two minutes on a Flutter project and looked frozen, so it got canceled and the project seemed impossible to re-enable. The extension now runs `dart` rather than `flutter` for `pub get` and `analyze` — the same work without the Flutter tool's startup cost, measured at 1.9 s versus 116 s on the same project — and skips `pub get` entirely when `pubspec.yaml` is unchanged and the package is already resolved. No action required.
- Upgrading the saropa_lints version from the extension paid the same two-minute Flutter startup cost on every upgrade. It now uses the same fast path, falling back to Flutter only when the resolve genuinely fails on the Flutter SDK. No action required.

<details><summary>Maintenance</summary>

- (Extension) Every command the extension shells out to is now timed into the extension report and output channel, so a slowness report carries its own measurements instead of needing a stopwatch. No action required.

</details>

---

## [15.0.3]

The scan CLI now lets users filter diagnostics by severity, so AI agents and CI pipelines can suppress info-level noise and focus on warnings and errors. The extension also stops losing the in-editor analyzer plugin when Lint integration is switched off and back on, and now reports that plugin's real state instead of implying it from a setting that does not control it. [log](https://github.com/saropa/saropa_lints/blob/v15.0.3/CHANGELOG.md)

### Added

- `--min-severity` flag for the `scan` command filters diagnostics by severity threshold — `--min-severity warning` excludes info-level output from both stdout and the report file, reducing noise for AI agents and CI pipelines. No action required.
- `--max-severity` flag for the `scan` command caps output at a severity ceiling — `--max-severity warning` hides errors so you can triage lower-priority noise in isolation. No action required.

### Added (Extension)

- When Lint integration and the analyzer plugin disagree in a way you probably did not intend — scan-on-save on with in-editor diagnostics silently off, or the multi-gigabyte plugin still loading while lints read as off — the extension now offers once to reconcile it either way. Answer or dismiss it and it does not ask again for that project.

### Fixed (Extension)

- Clicking a finding in the Problems panel now highlights the full diagnostic span instead of a single character — eliminates the "highlight every matching letter" noise caused by VS Code's occurrence-highlight when the range was only one character wide. No action required.
- Turning Lint integration off and then on again left the in-editor analyzer plugin switched off — the off step comments out the `plugins:` block in `analysis_options.yaml`, and the on step never put it back, so a project silently lost live diagnostics with no indication of why. Enable now restores the block when it was this extension's own Off that commented it out, leaving new projects (which default to the lighter scan-on-save delivery) untouched. This has proven to be tricky!
- The sidebar now reports the analyzer plugin's actual on-disk state as its own row, so "Lint integration: On" can no longer sit above a project whose `plugins:` block is commented out — clicking that row while it reads Off restores the plugin. No action required.
- The record of which side switched the analyzer plugin off is now stored twice, so a VS Code profile switch or extension-storage reset can no longer make Enable silently stop restoring the plugin. No action required.
- The analyzer plugin row and its restore logic now track every folder in a multi-root window and start working in a window that had no folder open at startup, instead of only the one folder present when the extension activated. No action required.
- Changing the tier froze the whole window until the config rewrite finished, behind a notification that showed one static title and no Cancel button — on a large project that is indistinguishable from a hang. The tier change now runs in the background with a live elapsed-time counter and a working Cancel, joins a second invocation to the one already running instead of racing on the same file, and restores the previous tier setting if the change does not complete. No action required.

<details><summary>Maintenance</summary>

- (Extension) Added explicit `"types"` field to both `tsconfig.json` and `tsconfig.test.json` so the TypeScript compiler reliably resolves Node.js globals and test framework types instead of relying on auto-discovery. No action required.
- (Extension) Added `verify-tsconfig-types` build gate that validates both tsconfig files during `precompile` — fails when an imported `@types/*` package is missing from either config's `"types"` array. No action required.
- (Extension) Pinned Filipino translation of "Analyzer plugin" in the curated dictionary so the MT pipeline stops overwriting it with untranslated English on every run. No action required.
- (Extension) The i18n pipeline now warns at the start of every run when a curated dictionary key no longer matches any English source string — catches silent regressions where a renamed en.json string causes the dictionary entry to stop matching and MT takes over. Pass `--fail-on-drift` to hard-gate (added to publish pipeline). No action required.
- (Extension) Fixed 9 orphaned curated dictionary keys across nl, fr, ur, bn, fil, and he — stale from prior en.json renames ("Search Packages" → "Search packages", "Open Lints Config" → "Manage Rule Packs"). No action required.
- Added fixture coverage for `avoid_positioned_outside_stack` — covers the Positioned-in-list-passed-to-custom-widget false positive that was already fixed in v4.13.0 but had no test. No action required.

</details>

---

## [15.0.2]

This release focuses on improving the reliability and user experience of the extension's setup workflows. Progress notifications now provide real-time feedback during lengthy operations to clearly communicate the current status. Safeguards have also been introduced to prevent duplicate, conflicting tasks from executing concurrently if a command is triggered multiple times. [log](https://github.com/saropa/saropa_lints/blob/v15.0.2/CHANGELOG.md)

### Fixed (Extension)

- The "Enabling Saropa Lints" progress notification stayed on a single static title for the entire `pub get` step, which can take over a minute on projects with many plugins — with nothing on screen to distinguish "still working" from "stuck," clicking Cancel (or clicking "Enable" again) mid-run was a reasonable reaction. The notification now shows which step is running and a live elapsed-time counter (e.g. "Running pub get… (45s)"). No action required.
- Clicking "Enable" again while an enable flow was already running started a second, fully concurrent flow — both writing `pubspec.yaml`/`analysis_options.yaml` and shelling out to `pub get`/`write_config` at the same time — instead of joining the one already in progress, which could stack duplicate progress notifications and race on the same files. A second call now joins the in-flight run instead of starting a new one. The same fix applies to "Create Baseline" (`saropa_baseline.json`), which had the same gap. No action required.

---

## [15.0.1]

Version 15.0.1 improves the editor extension's responsiveness and resolves a file-parsing bug that prevented the plugin from re-enabling. The setup flow now executes asynchronously to prevent UI freezes, while deactivated lint configurations generate significantly smaller files by omitting unused inline documentation. [log](https://github.com/saropa/saropa_lints/blob/v15.0.1/CHANGELOG.md)

### Fixed (Extension)

- A project whose `plugins:` block is written commented-out (new projects, or one where "Turn Off Lint Integration" was used) no longer gets the full per-rule description dump on every regenerate — the disabled block now keeps only the `rule_name: true/false` lines needed to restore the exact configured tier, dropping the multi-hundred-line prose and box-drawing headers that served no purpose while inert. A live (uncommented) block is unaffected and keeps its full inline documentation. No action required; re-run `dart run saropa_lints:init` or trigger a config write to see the smaller file.
- "Enabling Saropa Lints" could appear to hang forever on larger projects — the enable flow ran `pub get`, config write, and analysis synchronously, freezing the whole editor for as long as those took instead of just showing progress. The flow now runs them without blocking the UI and can be canceled from the progress notification. Canceling during the final analysis step also no longer silently reports "Enable" as successful — it now stops and logs the cancellation instead of turning the plugin on as if the flow had completed. No action required.
- "Re-enable Plugin" could report "nothing to restore" on a project whose `analysis_options.yaml` mixed CRLF and plain-LF line endings, even though the disabled `plugins:` block was plainly present — line detection now tolerates mixed endings instead of assuming one for the whole file. No action required.

---

## [15.0.0]

Version 15.0.0 adds new quick fixes for error logging and variable placement while introducing a persistent background daemon for significantly faster IDE save-scans. This release resolves false positives across exception handling, lifecycle timers, static method detection, and platform target checks. Project tier management is now unified directly through project configuration, reducing default editor memory overhead. [log](https://github.com/saropa/saropa_lints/blob/v15.0.0/CHANGELOG.md)

### Added

- `require_error_logging` now offers a quick fix: applying it inserts a `debugPrint` call logging the caught error (interpolating the captured exception variable when one exists, or naming the statically-known exception type when it does not) instead of only reporting the missing log call.
- `move_variable_closer_to_its_usage` now offers a quick fix: applying it moves the flagged declaration down to just before its first use. The fix only activates when doing so is provably safe (a single-variable declaration whose initializer shares no identifier with any statement it would move past) and otherwise leaves the diagnostic for manual review, so no action is required beyond reviewing the proposed edit before applying it.

### Fixed

- `avoid_catching_generic_exception` no longer flags `on Object`/`on Exception`/`dynamic` catch clauses whose body forwards the caught error to a logging or crash-reporting call (or rethrows it) before falling back — this is a deliberate pattern for also catching `Error` subtypes and reporting them, not a swallowed exception. Untyped `catch (e)` is unaffected. ([plans/history/2026.08/2026.08.15/avoid_catching_generic_exception_false_positive_logged_broad_catch.md](plans/history/2026.08/2026.08.15/avoid_catching_generic_exception_false_positive_logged_broad_catch.md))
- `require_error_boundary` no longer flags a `MaterialApp`/`CupertinoApp` built inside `main()`'s own `catch` clause when that clause already logged the caught error and its `try` body attempted `runApp(...)` — that's the app's crash-recovery fallback screen, not its normal entry point, and demanding it also carry an error-boundary `builder:` is recursive. The same shape outside `main()`, without logging, or without an `runApp` attempt in the `try` body still requires a `builder:` as before. ([plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md](plans/history/2026.08/2026.08.15/require_error_boundary_false_positive_fallback_ui_inside_catch.md))
- `require_error_logging` no longer flags a `catch`/`on Type` clause with no captured exception variable if its body still calls a recognized logging function — a static message like `on TimeoutException { debug('timed out'); }` is a complete log entry even without touching the exception object. A clause with no captured variable and no logging call is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_error_logging_false_positive_unparamed_catch_with_logged_body.md](plans/history/2026.08/2026.08.15/require_error_logging_false_positive_unparamed_catch_with_logged_body.md))
- `require_app_lifecycle_handling`, `avoid_work_in_paused_state`, and `require_lifecycle_observer` no longer flag a `Timer`/`Stream.periodic`/`.listen()` subscription that is created and canceled/closed within the same `State` class's own `initState`/`dispose()` pair — that's Flutter's standard cleanup contract for a foreground-only ticker that doesn't need to pause on backgrounding, since it stops existing when the widget is disposed. A class whose `dispose()` does not cancel the field it created, or that assigns the Timer/subscription somewhere dispose() can't prove cleanup for, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_app_lifecycle_handling_false_positive_dispose_cancels_timer.md](plans/history/2026.08/2026.08.15/require_app_lifecycle_handling_false_positive_dispose_cancels_timer.md))
- `require_ios_deployment_target_consistency` no longer flags `import 'dart:async'` (or any other import/export URI) as Swift `async`/`await` usage — the rule now skips string literals inside import/export directives before checking them against its tracked iOS 15+ API names. A genuine API name appearing elsewhere in the file is still flagged, as before. The same import/export-URI substring-match false positive was also fixed in `require_ios_live_activities_setup` (triggered by `import 'package:live_activities/...'`) and `require_ios_certificate_pinning` (triggered by package import paths containing segments like `/auth`). ([plans/history/2026.08/2026.08.15/require_ios_deployment_target_consistency_false_positive_import_uri_misattribution.md](plans/history/2026.08/2026.08.15/require_ios_deployment_target_consistency_false_positive_import_uri_misattribution.md))
- `prefer_static_method` no longer flags methods that read instance fields or call instance methods via bare (unprefixed) identifiers — the idiomatic Dart style used throughout most codebases. Previously the rule only recognized an explicit `this.` prefix, so any method touching instance state through a bare identifier (including inside a nested closure) was misdiagnosed as "could be static." A method that truly uses no instance state anywhere is still flagged, as before. ([plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md](plans/history/2026.08/2026.08.15/prefer_static_method_false_positive_implicit_field_access.md))
- `move_variable_closer_to_its_usage` no longer flags a deliberate "load N values, then consume all N in the same order" batch shape (e.g. five sequential `await`-loads followed by five field assignments) — a sibling declaration in the same contiguous run that is itself genuinely used elsewhere, or the first-use site of another such sibling, no longer counts toward the "unrelated intervening statements" distance. A genuinely far-apart single declaration, declarations used out of matching order, or unused padding declarations sitting next to a real one, are all still flagged, as before. ([plans/history/2026.08/2026.08.15/move_variable_closer_to_its_usage_false_positive_batch_declaration_grouping.md](plans/history/2026.08/2026.08.15/move_variable_closer_to_its_usage_false_positive_batch_declaration_grouping.md))
- `require_firebase_app_check_production` and `require_firebase_app_check` no longer flag `Firebase.initializeApp()` when `FirebaseAppCheck`/`AppCheck` activation is deferred to a separate, actually-called function elsewhere in the same file — a common pattern for keeping a slow/flaky Play Integrity check off the startup path. A file where App Check is only mentioned in a comment, or where the activating function exists but is never called from anywhere, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_firebase_app_check_production_false_positive_activation_in_separate_function.md](plans/history/2026.08/2026.08.15/require_firebase_app_check_production_false_positive_activation_in_separate_function.md))
- `require_log_level_for_production` no longer flags a bare verbose-log call (e.g. `debug(...)`) when the called function's own log-level parameter (`level`, `logLevel`, `severity`, or `verbosity`) already defaults to a safe value — demanding an explicit `level:` argument in that case would be a no-op. A callee whose default is itself verbose, unrecognized (numeric or constructor-call), or unresolvable, is still flagged, as before. ([plans/history/2026.08/2026.08.15/require_log_level_for_production_false_positive_default_level_param.md](plans/history/2026.08/2026.08.15/require_log_level_for_production_false_positive_default_level_param.md))

### Changed (Extension)

- Saving a Dart file now scans it in an external process and shows findings as squiggles and Problems panel entries — no separate setting to find or enable, this is what `saropaLints.enabled` now does. Turning that toggle off stops save scans and shuts the scanner down immediately, rather than leaving stale findings in the Problems panel. `saropaLints.scanOnSave.resolveTypes` (default on) controls whether scans fully resolve types so type-based rules fire; turn it off only if save latency matters more than catching those rules.
- Type-resolved save scans run through a persistent `scan_daemon` process that builds the analyzer's project context once and keeps it warm, so a save is checked in a few seconds instead of re-paying a roughly one-minute analyzer warmup on every save. The status bar shows a warming message while the first scan after opening is still resolving; the daemon restarts automatically (with backoff) if it stops. Measured memory is comparable to the in-process analyzer plugin — the daemon's advantage is living outside the editor's own process, not a smaller footprint.
- New projects (`dart run saropa_lints:init` or the extension's Enable) no longer get a live in-process analyzer plugin — the `plugins:` block is written commented out by default, since it can hold several GB of resolved analysis state on large projects for no benefit over the scan-on-save daemon above. A project that already had the plugin running, or had it explicitly turned off, keeps that state through tier changes and re-enabling; uncomment the block in `analysis_options.yaml` to opt back in to live in-editor squiggles, or run the new "Saropa Lints: Re-enable In-Process Plugin" command to do it in one step (it also restarts the Dart analysis server so the plugin reloads immediately).
- New command "Saropa Lints: Scan Whole Project for Issues" runs a cancelable whole-project scan so files you haven't saved this session still show up in the Problems panel — save-triggered scanning alone only checks a file once you save it. It streams results in chunks as it goes and can be canceled mid-scan from the progress notification; run it from the Command Palette when you want full coverage, not automatically on open (a full pass on a large project can take tens of minutes).
- A save-triggered scan of a single file no longer prints a misleading progress bar estimating its position against the whole project (e.g. "Files: 1/4477, ETA: 2h"). That estimate now only appears during the long-lived in-editor plugin session it was designed for; one-shot scans (save-triggered daemon, `scan` CLI) show a plain file count instead.
- `analysis_options.yaml` is now the single source of truth for a project's lint tier. Save-triggered scans, the whole-project baseline scan, and the tier picker's "current tier" display now read the tier straight from `analysis_options.yaml` instead of trusting the (possibly stale) `saropaLints.tier` setting, so a hand-edited or regenerated config file can no longer silently disagree with what the extension shows or scans with. `SAROPA_TIER` remains available as a dev-only override but now logs a warning when it disagrees with the project's own config; `saropa_tier:` in `analysis_options_custom.yaml` is deprecated in favor of `analysis_options.yaml`.

<details>
<summary>Maintenance</summary>

- Investigated a `no_magic_string` false-positive report (string literal inside a `//`-commented-out `debugPrint` call) and confirmed by code inspection it cannot occur — the rule and all its gating helpers are AST-callback-only, with no raw-text scanning. Added a resolved-analyzer regression test pinning this behavior. ([bugs/no_magic_string_false_positive_commented_out_code.md](bugs/no_magic_string_false_positive_commented_out_code.md))
- Manually corrected seven German and Swahili extension strings that had shipped corrupted machine-translation output — a mangled literal `--resolve` CLI flag, two entries collapsed into a repetition loop (one leaking a fragment resembling a stray prompt artifact), and grammatically broken fallback text — and added each as a curated `dictionaries.py` override so a future translation run can never regenerate the same corruption from cache.

</details>

---

## [14.5.9]

This release adds a rule catching a common button-labeling mistake: cramming extra detail into a button's main text using parentheses instead of the dedicated subtitle line. It also closes the last gap in the "Lint integration off" toggle: the analyzer plugin itself now refuses to enable any rules while the integration is disabled, so no fallback configuration can silently re-enable analysis and its multi-gigabyte memory footprint. [log](https://github.com/saropa/saropa_lints/blob/v14.5.9/CHANGELOG.md)

### Added

- New rule `avoid_parenthesized_button_caption` (Comprehensive tier): flags `CommonButton` / `CommonButtonWait` calls where the `text:` parameter contains parenthesized text that belongs in `subtitleText:` instead. No action required.

### Fixed

- The analyzer plugin now enables zero rules whenever "Lint integration" is toggled off, even if it gets loaded anyway — previously fallback configuration could re-enable over a thousand rules and hold several GB of analysis-server memory on a project the user had disabled. No action required.

---

## [14.5.8]

Fixed the extension running lint analysis in the background while "Lint integration" was turned off. Disabling the integration now stops every automatic analysis trigger and background suggestion, not just the editor diagnostics. [log](https://github.com/saropa/saropa_lints/blob/v14.5.8/CHANGELOG.md)

### Fixed (Extension)

- Turning off "Lint integration" now also stops analysis triggered by saving files, changing dependencies, changing tier, changing config, and enabling a rule pack, along with the crash-coverage rule suggestion. Previously only in-editor diagnostics were suppressed. No action required.
- Turning off "Lint integration" now restarts the Dart analysis server immediately, so the plugin's background process actually exits instead of continuing to run (and hold onto several GB of memory) until the next manual reload. No action required.

### Changed (Extension)

- The "Run Analysis" toolbar button is hidden while "Lint integration" is off, instead of appearing clickable and doing nothing useful. No action required.

---

## [14.5.7]

Dependency maintenance release — no rule or extension changes. [log](https://github.com/saropa/saropa_lints/blob/v14.5.7/CHANGELOG.md)

<details>
<summary>Maintenance</summary>

- Bumped `js-yaml` (extension dev dependency, via `mocha`) from 4.3.0 to 4.3.1, resolving GHSA-5p4m-2wfm-xmqj.

</details>

---

## [14.5.6]

This release introduces a new rule to ensure lint suppression comments work correctly in your IDE. The `require_ignore_comment_plugin_prefix` rule flags ignore comments referencing saropa_lints rules that lack the required package prefix, preventing suppressions from failing silently. An automated quick fix is included to instantly apply the missing prefix. [log](https://github.com/saropa/saropa_lints/blob/v14.5.6/CHANGELOG.md)

### Added

- **New rule `require_ignore_comment_plugin_prefix`** (Essential tier, WARNING) — flags `// ignore: rule_name` and `// ignore_for_file: rule_name` comments that reference a saropa_lints rule without the required `saropa_lints/` prefix, which causes the suppression to silently fail in the IDE. A quick fix inserts the prefix. No action required.
- **`dart run saropa_lints scan --fix-ignores`** — bulk-converts bare `// ignore: rule_name` to `// ignore: saropa_lints/rule_name` for all known saropa_lints rules across `lib/`, `test/`, and `bin/`.

### Fixed

- **`require_ignore_comment_plugin_prefix`'s quick fix could insert the prefix into the wrong `// ignore:` comment** when another ignore comment sat nearby in the file. It now targets the exact flagged comment. No action required.
- **`--fix-ignores` skipped hyphenated rule names** (e.g. `avoid-null-assertion`), leaving them unprefixed. It now converts them correctly. No action required.

---

## [14.5.5]

The Analysis Optimizer now makes changes safely: it surgically updates only the patterns you're modifying while preserving your file structure, comments, and ordering, and backs up your configuration before every write for easy manual recovery. The dashboard excludes redundant recommendations when patterns are already covered and automatically rescans to keep the status current. [log](https://github.com/saropa/saropa_lints/blob/v14.5.5/CHANGELOG.md)

### Fixed (Extension)

- **Analysis Optimizer could silently destroy hand-curated `analysis_options.yaml` structure** — every Apply/Remove/Fix Syntax action rebuilt the entire `exclude:` block from scratch, discarding section-header comments and blank-line grouping (which aren't attached to any single pattern) and re-sorting every entry alphabetically. Writes are now surgical: only the lines for patterns actually being added or removed are touched, and every other line — comments, spacing, order — is left exactly as it was. No action required.
- **Folder exclusion recommendations kept showing as "Recommended" even when already covered by a broader applied pattern** (e.g. individual `dependency_overrides/<package>/**` entries never matched as "Applied" despite a `dependency_overrides/**` already excluding them). These redundant recommendations no longer appear. No action required.
- The dashboard now automatically scans on open and rescans after every Apply/Remove/Fix Syntax, instead of requiring a manual "Scan Workspace" click to see current status. No action required.

### Added (Extension)

- Every Analysis Optimizer write now saves a one-step-back copy of `analysis_options.yaml` to `analysis_options.yaml.bak` first, so a change can always be manually reverted. No action required.

---

## [14.5.4]

This release fixes the Analysis Optimizer's exclusion detection, which previously missed patterns already present in analysis_options.yaml and duplicated them on apply. The dashboard's two separate exclusion lists are now one sortable table with clearer status and impact indicators, plus a quick line preview before applying. [log](https://github.com/saropa/saropa_lints/blob/v14.5.4/CHANGELOG.md)

### Fixed (Extension)

- **Analysis Optimizer could write invalid YAML that broke Dart analysis entirely** — an unquoted exclude pattern starting with `**` (routine for Dart globs) is YAML alias syntax, not a literal string, and caused a real `Undefined alias` parse error the moment the analyzer read the file. Every written pattern is now quoted, and previously-malformed unquoted entries are automatically re-quoted the next time any change is applied through the dashboard. No action required.
- **Analysis Optimizer failed to detect existing exclusions** — patterns with an inline `# comment` or a stray trailing quote (`- **/*.g.dart" # ...`) were never recognized as already excluded, so the dashboard kept recommending them and applying created a duplicate line. The reader now strips comments and malformed quoting before comparing, and the writer preserves each pattern's original comment on write. No action required.
- **Analysis Optimizer's "Current exclusions" and "Recommended exclusions" are now one deduplicated "Exclusions" table**, with an Applied/Recommended status column, sortable columns, and the chosen sort order preserved across Apply/Remove actions. No action required.
- An already-applied Analysis Optimizer exclusion that matches zero scanned Dart files (e.g. a non-Dart tool reference) now shows a dash and an explanatory reason instead of a misleading "0". No action required.

### Added (Extension)

- Each Analysis Optimizer recommendation now has a "Preview" toggle showing the approximate line that would be added to `analysis_options.yaml`, without leaving the table. No action required.
- Analysis Optimizer now proactively warns when `analysis_options.yaml` already has invalid exclude syntax and offers a one-click "Fix Syntax" that re-quotes every entry, so a broken file can be repaired without needing to apply or remove a specific pattern first. No action required.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.
