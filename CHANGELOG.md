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

## [15.2.12] — Unreleased

### Fixed

- **LSP server handles all standard notifications without crashing.** Added explicit no-op cases for `textDocument/didChange`, `$/cancelRequest`, `$/setTrace`, and `workspace/didChangeConfiguration` so the inert server stays alive under normal VS Code traffic. No action required.

### Added

- **New `doctor` command** scans consumer project configuration for misplaced keys, missing custom file, and other issues that produce SDK warnings. Run `dart run saropa_lints doctor [directory]`.

<details>
<summary>Maintenance</summary>

- Pre-commit hook now auto-regenerates category map and migration pack codes when rule files, tier definitions, or migration guides change — eliminates the recurring CI failures from stale generated indexes.
- Closed `unsupported_option` bug for `rule_packs` and `log_level` — investigation confirmed the fix was already implemented; consumer projects just need to run `dart run saropa_lints migrate-config`.
- `migrate-config` now removes orphan `rule_packs:` keys that have no `enabled:` child, and handles trailing comments on the key line.
- Config parser (`_leadingSpaces`) now counts tabs as indentation, matching the scalar parser — fixes silent parse failures on tab-indented YAML.

</details>

---

## [15.2.11]

Removed Phase 0 fake LSP test diagnostics that shipped in 15.2.10. The standalone LSP server infrastructure remains (off by default) but no longer emits test squiggles. [log](https://github.com/saropa/saropa_lints/blob/v15.2.11/CHANGELOG.md)

### Fixed

- **LSP server no longer emits fake test diagnostics.** Phase 0 proof-of-concept diagnostics were being published to every open `.dart` file when the LSP server was enabled. No action required — the setting now defaults to off.

### Changed

- **`saropaLints.lspServer.enabled` now defaults to `false`.** Previously defaulted to `true`, which activated the fake LSP server for all users. No action required.

<details>
<summary>Maintenance</summary>

- Regenerated category map and migration pack codes for 18 new rules added in 15.2.10 that were missing from the generated indexes.

</details>

---

## [15.2.10]

> **Known issue:** This release shipped `saropaLints.lspServer.enabled` defaulting to `true`, causing fake test diagnostics to appear in every open `.dart` file. Update to 15.2.11 immediately.

Seventeen new lint rules across testing, equality, control flow, constructor style, widget lifecycle, formatting, code quality, documentation, and architecture. Cross-platform SARIF output fix, dead-link hardening for published docs, and orphan-publish recovery for the publish script. [log](https://github.com/saropa/saropa_lints/blob/v15.2.10/CHANGELOG.md)

### Fixed

- Fixed SARIF writer emitting `../C:/project/...` URIs on Linux CI — switched from `p.relative()` to prefix stripping after forward-slash normalization so Windows-style paths resolve correctly cross-platform.
- Fixed broken links in `README.md` and `doc/README.md` to removed guide files (`upgrading_to_v7.md`, `migration_v4_to_v5.md`).
- Fixed wrong relative path in `using_with_flutter_lints.md` link to VGA migration guide.
- Fixed `always_put_doc_comments_before_annotations` false-negative — the old token-walking detection assumed `documentationComment == null` for misplaced comments, but the analyzer populates it regardless of position. Replaced with offset comparison against the first annotation.

### Added

- New rule `avoid_focused_tests` (Essential) — flags `test()`/`group()` calls with `solo: true` left in committed code, which silently skips the rest of the suite in CI.
- New rule `avoid_exit_outside_entrypoint` (Recommended) — flags `exit()` calls outside the top-level `main()` function, which kill the process bypassing cleanup and `finally` blocks.
- New rule `avoid_labeled_statements` (Comprehensive) — flags labeled statements (`label: for/while/switch`) that force readers to track names across nested blocks instead of reasoning locally.
- New rule `avoid_null_checks_in_equality_operators_extended` (Recommended) — flags dead `other == null` checks inside `operator ==` overrides under sound null safety. Named with `_extended` suffix to avoid collision with the core Dart lint.
- New rule `avoid_unnecessary_else_after_control_flow` (Recommended) — flags `else` blocks after `if` bodies that end with `return`, `throw`, `break`, or `continue`.
- New rule `prefer_initializing_formals_extended` (Comprehensive) — flags constructor body assignments that could be `this.param` initializing formals. Named with `_extended` suffix to avoid collision with the core Dart lint.
- New rule `avoid_skipped_tests` (Recommended) — flags `test()`/`group()` calls with `skip: true` or a skip message left in committed code.
- New rule `no_optional_operators_in_tests` (Comprehensive) — flags `?.` and `??` operators in test files that silently swallow failures.
- New rule `avoid_public_members_in_states` (Recommended) — flags public fields and methods in `State` subclasses that leak internal state as public API.
- New rule `prefer_blank_line_before_break` (Stylistic) — requires a blank line before `break` in multi-statement blocks for visual separation.
- New rule `prefer_blank_line_before_continue` (Stylistic) — requires a blank line before `continue` in multi-statement blocks.
- New rule `prefer_blank_line_before_throw` (Stylistic) — requires a blank line before `throw` statements in multi-statement blocks.
- New rule `avoid_unnecessary_parentheses` (Comprehensive) — flags redundant parentheses that don't change evaluation order or precedence.
- New rule `always_put_doc_comments_before_annotations` (Recommended) — flags `///` doc comments placed after annotations instead of before, which breaks dartdoc association.
- New rule `start_comments_with_space` (Pedantic) — flags `//comment` missing a space after the slashes.
- New rule `constructor_parameters_and_fields_should_have_the_same_order` (Comprehensive) — flags constructors where parameter order doesn't match field declaration order.
- New rule `todo_with_story_links` (Professional) — flags TODO/FIXME comments lacking an issue tracker reference.
- New quick fix for `always_put_doc_comments_before_annotations` — auto-moves misplaced `///` doc comments above all annotations with correct indentation. Supports bulk "Fix All" application across files.
- New rule `prefer_doc_comment_after_annotations` (Stylistic) — inverse of `always_put_doc_comments_before_annotations`, for teams that prefer `///` doc comments adjacent to the declaration keyword rather than above annotations. Registered as a conflicting pair. Includes quick fix with bulk "Fix All" support.

<details>
<summary>Maintenance</summary>

- Added doc-link validation to `.githooks/pre-commit` — broken or excluded-path links in shipped docs are now caught before commit, not just in CI.
- Publish script now detects orphaned version bumps from aborted publishes at startup and offers to reset versions, preventing cascading state corruption.
- New publish mode **9) Pub.dev only** — runs the full publish pipeline (audit, format, analyze, tests, version, commit, tag, pub.dev publish, GitHub release) but skips all extension packaging and Marketplace/Open VSX publishing. Use when the VSIX was already published separately or when only the Dart package needs a release.
- Fixed `--fail-on error` scan test failing when error-level diagnostics exist in the fixture — test now uses `--fail-on-count 9999` to decouple exit-code assertion from project error count.
- Fixed CI failure: `.pubignore` now excludes `doc/guides/migration_guides/` so shipped docs no longer contain dead links to `.pubignore`-excluded `plans/` proposals.
- Fixed `check_doc_links_excluded_paths.py` not filtering out source docs that are themselves `.pubignore`-excluded — the script now skips docs under excluded prefixes instead of scanning them for link targets.
- New `scripts/fix_ignores.py` migration tool rewrites stale `// ignore:` comments and `analysis_options.yaml` rule names from pre-rename saropa_lints rule names to their current `_extended`/`_strict`/`_with_fix` equivalents. Run `python scripts/fix_ignores.py <dir>` (dry run) or `--apply` to rewrite.
- Publish audit now checks `CORE_DART_LINT_NAMES` freshness against the live Dart SDK linter — warns (non-blocking) if the reference set is stale.
- New `test/integrity/core_lint_collision_test.dart` catches rule name collisions with core Dart lints during `dart test`, not only at publish time.

</details>

---

## [15.2.9]

The system health monitor now separates memory used by Saropa Lints from the total across all Dart processes, so users can see the real footprint instead of being blamed for the entire analysis server. The scan daemon auto-suspends under heavy memory pressure to reclaim its analyzer cache, and orphaned scan daemons are now detected and cleaned up alongside Flutter daemons. A new Full Audit command scans a project against every rule regardless of its configured tier and opens the results in a filterable report panel. [log](https://github.com/saropa/saropa_lints/blob/v15.2.9/CHANGELOG.md)

### Added

- New Full Audit command scans a project against every lint rule regardless of the configured tier — choose the whole project, only changed files versus a branch, or a comparison against a saved baseline. Results open in a dedicated report panel with tier/severity/category filters, search, file grouping, and a "Copy JSON" export. Run it from the Explorer context menu ("Saropa: Audit Folder...") or the audit icon in the dashboards sidebar.
- Full Audit supports `--format sarif` for SARIF 2.1.0 output, so results can feed GitHub code-scanning annotations directly on a PR diff — particularly useful combined with `--since <ref>`.
- Status bar tooltip now shows Saropa Lints process count and memory separately from the system-wide Dart total — no more blaming the extension for the entire analysis server. No action required.
- Scan daemon auto-suspends when memory-pressure shedding reaches level 2+ (most rules shed), reclaiming the daemon's warm analyzer cache; resumes automatically when pressure drops. No action required.
- Orphaned scan daemon detection — scan daemons left running after a VS Code crash are now identified and included in the Clean Up command alongside Flutter daemons. No action required.
- Health panel marks Saropa Lints processes with a "Saropa" type pill so they are visually distinct from analysis servers and other Dart processes. No action required.
- Standalone LSP server infrastructure (Phase 0) — proves two LSP servers coexist in the same VS Code Problems panel. **Bug:** `saropaLints.lspServer.enabled` shipped defaulting to `true`, causing fake test diagnostics to appear in every open `.dart` file. Fixed in 15.2.11 — setting now defaults to `false` and test diagnostics have been removed.
- Debug Panel sidebar — shows status and toggle controls for all three diagnostic engines (Analyzer Plugin, Scan Daemon, LSP Server) with PID, rule count, RSS, and a live log tail. **Bug:** Debug panel was enabled by default, which also activated the LSP server toggle. Disable via `saropaLints.debug.enabled` if not needed.
- Migration packs for 24 alternative lint packages — when a project still depends on an alternative (e.g. `pyramid_lint`, `solid_lints`, `dcm`), the extension surfaces a "Migrate from …" pack in the Rule Packs dashboard that enables all equivalent saropa rules in one click. No action required.

### Fixed

- Fixed double-unescape vulnerability in pub.dev changelog entity decoder — `&amp;lt;` was incorrectly decoded to `<` instead of the literal `&lt;` (CodeQL #19, CWE-116).
- Fixed case-insensitive script-tag matching in snapshot harness so upper-case `<SCRIPT>` tags are normalized correctly (CodeQL #20).
- Status bar warning/critical suffix now shows Saropa Lints RSS when available instead of the misleading system-wide total. No action required.
- Fixed 12 rule files (28 rule classes) that accessed `.constructorName.type.element` without declaring `usesTypeResolution => true` — these rules silently produced zero findings in the light analysis lane. The integrity test now detects this access pattern.
- Fixed Full Audit showing a confusing second "output could not be read" error after canceling an audit — the forced process-tree kill on cancel could still fire a late completion event with truncated output.
- Fixed Full Audit cancellation silently failing to stop the underlying `dart` process on macOS/Linux — the audit CLI kept running in the background after the "Audit canceled" toast, because killing the shell process alone (with `shell: true`) doesn't reach its `dart` child on POSIX.
- Fixed Full Audit accumulating a temp file per run for large (>10MB) result sets with no cleanup, and silently swallowing a temp-file write failure instead of warning the user.
- Fixed accuracy report and audit CLI showing most rules as silent — the Problems-tab issue cap (500) was silently dropping diagnostics before they reached the listener. Added `disableIssueCap` parameter to `ScanRunner` so batch CLI tools opt out of the IDE cap at construction, rather than each caller needing to know about `ProgressTracker`.
- Fixed LSP server failing to spawn on Windows — `dart.bat` requires `shell: true` for PATHEXT resolution, matching the convention used by every other dart spawn in the extension.
- Fixed fake LSP test diagnostics inflating the real score — changed the diagnostic source to `saropa_lsp_test` and added a source filter in `liveDiagnosticsModel` so status bar, Issues tree, and dashboard ignore them.
- Fixed stop/dispose race when toggling the LSP server setting — `dispose()` was called before `stop()` completed, causing a double-stop. Now awaits stop before dispose.
- Wired Kill All / Restart All buttons in the Debug Panel — previously they were rendered but nothing subscribed to the click events.
- Replaced hardcoded English engine names and status words in the Debug Panel with `l10n()` calls — added explicit `key` field to `EngineStatus` so toggle messages don't depend on locale-sensitive substring matching.
- Removed hand-typed rule counts (203, 2140) from the Debug Panel engine status — these drifted as rules were added. The LSP server retains its fixed count of 4 (the actual test diagnostic count).
- Fixed 4 migration packs that had drifted from their source guides: `migrate_dcm` was missing 9 documented rules and carried one typo'd rule name that never matched anything; `migrate_dart_code_metrics_presets` was missing 1 rule; `migrate_dart_code_linter` and `migrate_awesome_lints` each carried rules not backed by any guide row. Enabling these packs previously gave less (or, for the typo, slightly wrong) coverage than the migration guide promised.
- Fixed 5 migration guides (`dcm`, `dart_code_linter`, `pyramid_lint`, `mad_lint`, `solid_lints`) that mapped a source rule to a saropa Dart *class* name (`NewlineBeforeReturnRule`) or a rule that never existed (`avoid_magic_numbers`) instead of the real rule codes (`prefer_blank_line_before_return`, `no_magic_number`). Every affected migration pack was silently missing that rule's coverage — the phantom code matched nothing.
- Fixed `many_lints` migration pack referencing the removed rule `prefer_returning_shorthands` instead of its replacement `prefer_arrow_functions` — the pack was silently missing coverage for that rule.

<details>
<summary>Maintenance</summary>

- Compiled alternative landscape gap analysis (`plans/GAP_ANALYSIS.md`) — rule-by-rule audit of 48 Dart/Flutter lint packages against saropa_lints' catalog, with gap themes and per-package detail sections for planning future rule additions.
- Hardened dead-package language in migration guides for `accessibility_lint` (archived), `design_system_lints` (defunct since 2022), and `flutter_refactor_plugin` (source repo 404) — migration is mandatory, not optional.
- Added migration packs plan (`plans/MIGRATION_PACKS_PLAN.md`) — rule packs that surface saropa equivalents for each alternative package in the extension's Config dashboard.
- Added `// LINT_MESSAGE:`, `// LINT_NOT:`, and `// LINT_COUNT:` fixture marker infrastructure — declarative message validation, false-positive guards, and whole-fixture count assertions for resolved harness tests.
- `audit` CLI: fixed `RuntimeTierCap` silently capping the rule set — added `bypassTierCap` flag on `ScanRunner` so audit runs every rule regardless of the project's configured tier.
- `audit` CLI: fixed tier enrichment bug — was looking up `entry['rule']` instead of `entry['ruleName']`, so tier field was never populated in JSON output.
- `audit` CLI: added per-diagnostic `category` field to JSON output (derived from rule source file directory), with generated category map and drift-catching unit tests.
- Fixed l10n diagnostic param-extraction by replacing the regex with a state-machine parser that handles nested expressions, spread syntax, template literal interpolations, regex literals, and value-expression skipping after explicit keys. Also added comment-aware scanning to prevent false positives from code comments.
- Moved `PACKAGE_VIBRANCY.md` from `plans/guides/` to the repo root to match the path the extension's SDK vibrancy table expects; excluded `plans/` from the pub.dev package (already public on GitHub, this only trims the published tarball); added CI check `scripts/check_doc_links_excluded_paths.py` to catch shipped docs linking into `.pubignore`-excluded paths (resolves link targets relative to the linking file, reads exclusion prefixes directly from `.pubignore`, and checks both inline and reference-style Markdown links). Fixed 6 dead links it found across `README.md`, `doc/troubleshooting.md`, and `doc/guides/`.
- Added GitHub issue form templates (`.github/ISSUE_TEMPLATE/`) for bug reports and feature requests, enforcing the structure from `bugs/ISSUE_REPORT_GUIDE.md` at filing time. Blank issues disabled.
- Moved `rule_packs` config from `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level key in `analysis_options_custom.yaml`, eliminating the false `unsupported_option` warning from the Dart SDK's plugin-block validator. Existing configs are read with deprecation fallback; run `dart run saropa_lints migrate-config` to migrate automatically.
- Added `--dry-run` flag to `migrate-config` CLI — previews what would change without writing files.
- Fixed CRLF line-ending handling in `rule_packs` write/migrate paths (Windows files with `\r\n` could silently corrupt regex matches).
- Filed 336 new-rule and extension proposals (`bugs/proposal_*.md`) covering every DCM gap, partial-coverage rule, and all 46 alternative-package migration-guide gaps, each traceable back to `plans/GAP_ANALYSIS.md` via a "Closes gap" line. All migration-guide TODO rows now link to their proposal.
- Created 46 migration guides (`doc/guides/migration_guides/`) — one per alternative lint package audited in the gap analysis — with rule-mapping tables (HAVE / PARTIAL / TODO) and migration steps.
- Added cross-referencing requirement to `bugs/ISSUE_REPORT_GUIDE.md`: implementing a proposal that closes a migration-guide gap must flip the corresponding table row from TODO/PARTIAL to HAVE/ENHANCED.
- Corrected stale `prefer-container` false-gap entry in `plans/GAP_ANALYSIS.md` — saropa already covers this via `PreferContainerRule`.
- Closed 11 i18n translation gaps across 8 locales (de, fil, id, it, nl, pl, pt, sw) via curated dictionary entries — cognate passthroughs (`Status:`, `Debug`), manual translations (`Panel ng Debug`, `tulivu`), and fixed Swahili `active` MT garbage.
- Added dictionary locale-integrity validator (`_check_dictionary_locale_integrity`) — AST-based check that detects entries misrouted to the wrong locale section, with duplicate-key detection and cross-locale diagnostic hints. Runs as a hard gate before translation.
- Added unit tests for the Full Audit POSIX process-group kill path (5 cases covering Linux, macOS, fallback, Windows, and no-pid edge cases) and the >10MB deferred-payload temp-file lifecycle (write, cleanup, and fallback behavior) — 11 new tests total.
- Documented the circular-fallback risk when `globalStorageUri` temp-file write fails for large audit payloads — the fallback inlines a payload that was too large for inlining, which may stall the webview for 50MB+ results.
- Documented GitHub code-scanning CI recipe in `doc/guides/cli.md` — example workflow using `--since` and `--format sarif` with `upload-sarif@v3` for inline PR annotations.
- Confirmed SARIF `properties` bag carrying `tier`/`category`/`baselineStatus` is compatible with GitHub code-scanning and VS Code SARIF Viewer per SARIF 2.1.0 §3.8 — added spec-reference comment.
- Eliminated redundant JSON.stringify of the full diagnostics array in the audit report render path — the array is now serialized once in `openAuditReport` and the same string feeds both the size check and the inline embed.
- Added `test/config/rule_packs_migration_guide_sync_test.dart` — re-derives each migration pack's expected rule set from its guide's HAVE/ENHANCED table and fails if the pack file drifts from the guide (caught the 4 packs fixed above).
- `rule_pack_migration_codes.dart` is now generated, not hand-maintained: `tool/generate_migration_pack_codes.dart` parses the HAVE/ENHANCED rows out of every migration guide, validates each referenced saropa rule against `tiers.dart`, and rewrites the pack file — run it after editing any migration guide instead of hand-syncing the pack's `Set<String>`. Shared parsing lives in `tool/migration_pack_guide_sync.dart` so the generator and the drift test can't disagree.
- Hardened the migration pack generator's tiers.dart validation to skip comment lines (commented-out rule names were false-passing), added validation for the carried-forward `flutter_skill_lints` code set, and extracted a shared dedup constant so the generator and drift test can't silently disagree on the count.
- Hardened migration pack generator further: `extractBlock`/`extractPackCodes` now use balanced brace counting instead of fragile `\n};`/`\n  },` string markers; `activeQuotedIdentifiers` strips `/* */` block comments in addition to `//` lines; `.dart_tool/` temp directory is created before use; diff output shows per-pack `+ added`/`- removed` codes in both normal and `--check` modes.
- l10n diagnostic provider: excluded `l10nParsers.test.ts` from validation (false positives from dummy keys in test fixtures), added extra-params detection (Hint when code passes params the template doesn't use), added `// l10n-ignore-next-line` comment directive for per-call suppression, and added dead-key detection with single and bulk quick-fixes to remove unreferenced en.json keys from all 25 locale files at once.

</details>

---

## [15.2.8]

Rule shedding under memory pressure is now cost-aware — expensive rules that drive the most memory consumption are shed first, keeping cheap syntactic rules running longer. The Config Dashboard surfaces which rules are currently shed and why, and the status bar tooltip shows shed category breakdowns. [log](https://github.com/saropa/saropa_lints/blob/v15.2.8/CHANGELOG.md)

### Added

- Config Dashboard now shows a "Shed rules" section when memory pressure is active — lists every temporarily disabled rule grouped by shed category (type-resolving, high-cost, INFO, WARNING) with clickable links to each rule's explanation.
- Shed rules are marked with a "shed" badge inside expanded pack rows so you can see at a glance which rules in a pack are temporarily inactive.
- "Restart analyzer" button in the shed section clears memory pressure by restarting the analysis server — shed rules restore automatically when RSS resets. No action required.

### Changed

- Cost-aware rule shedding: memory pressure now sheds type-resolving and high-cost rules first (level 1), then INFO-severity (level 2), then WARNING-severity (level 3). No action required.
- Status bar tooltip shows shed rule breakdown by category (type-resolving, high-cost, INFO, WARNING) when shedding is active. No action required.

---

## [15.2.7]

Adds graduated rule shedding under memory pressure — the analyzer plugin now progressively disables low-severity rules when RSS approaches its cap, keeping essential rules running. The VS Code extension surfaces shedding state in the status bar and tooltip. Also includes publish script hardening. [log](https://github.com/saropa/saropa_lints/blob/v15.2.7/CHANGELOG.md)

### Added

- Graduated memory-pressure rule shedding (opt-in via `shed_rules: true` in `analysis_options_custom.yaml`): shed level 1 disables INFO-severity rules, level 2 adds WARNING-severity rules, essential-tier rules are always protected. Without opt-in, soft-limit warnings still log but no rules are shed.
- Memory pressure indicator in the VS Code status bar and tooltip, fed by `memory_state.json` written on shed-level transitions — no polling.
- VS Code warning notification when the analyzer hits memory pressure but rule shedding is not enabled — "Enable" writes `shed_rules: true` directly into `analysis_options_custom.yaml`, "Learn More" opens the docs. Shows once per workspace root per session, with a persistent status-bar indicator so pressure stays visible after dismissing the toast.
- `memory_mode: aggressive` option in `analysis_options_custom.yaml` — applies balanced-mode unchanged-file skipping to the scan daemon and CLI too, reducing daemon RSS on incremental scans at the cost of potentially missing violations in unchanged files whose dependencies changed.

<details>
<summary>Maintenance</summary>

- **Publish script: preflight version verification** — a visible "PREFLIGHT: VERSION VERIFICATION" step now runs early in the publish pipeline (before badge validation, CI gate, and extension packaging), checking that `pubspec.yaml` and `extension/package.json` carry the correct version. Two additional safety-net gates run later (after staging and before tagging) as a last resort. No action required.
- Severity registration at plugin startup maps each rule to a 0-based shed index for the graduated shedding mechanism.
- `memory_state.json` state file written alongside `plugin.log` on shed-level transitions for extension consumption.
- Periodic memory log line now includes soft limit and shed level.
- `PluginLogger.logFilePath` public getter for the memory-state writer.
- `getStats()` now includes `softLimitMb`, `softLimitTripped`, `shedLevel`, and `shedRuleCount`.
- Fixed negative recovery thresholds when the hard RSS limit is below ~366 MB — soft-limit recovery and de-escalation checks now clamp to zero instead of going negative, which would lock shedding on permanently.
- Shed level updates skip the full rule-set rebuild when the level hasn't actually changed.
- Shedding opt-in moved from the env-var-only `SAROPA_LINTS_SHED_RULES=true` to a `shed_rules: true` key in `analysis_options_custom.yaml` (the env var still works, but is no longer the only way in — `dart run saropa_lints:init` now writes a commented `shed_rules` line so the setting is discoverable). `_refreshSoftLimit` split into `_tripSoftLimit`/`_recoverSoftLimit`/`_refreshEscalation` helpers. Status-bar and tooltip memory-pressure text now share one priority-order function (`memoryPressureTooltipLine`) instead of two independently maintained decision trees.
- **`usesTypeResolution` audit complete** — 180 false claims flipped to `false` across 9 rule files, freeing those rules from unnecessary scan-daemon routing. Integrity test unskipped and now guards both directions (missing flag + false claim). Test regex extended with `formalParameters` to catch modern element-model resolution APIs.
- **Full Audit i18n** — added all 50 missing `audit.*` keys to `en.json` (scope picker, progress, errors, and report webview) plus 3 missing `findingsDash.script.*` accessibility keys, and localized the inline progress-bar message. No action required.
- **`check_l10n_keys.py`** — new CI script cross-references every `l10n()` call in `extension/src/` against `en.json`, with `--check-params` to validate interpolation tokens match between call sites and catalog values. Handles template-literal `${}` interpolations, spread properties, and dynamic-key prefixes. No action required.
- **Live l10n diagnostics** — new `saropa-l10n` diagnostic provider shows inline warnings for missing `en.json` keys and param mismatches on save. Re-validates when `en.json` changes. No action required.
- **`check_l10n_keys.py` param checker hardened** — fixed false positives: consecutive shorthand properties (`{ a, b }`) were missed due to trailing-delimiter consumption; template-literal interpolations (`${suffix}`) were misidentified as extra params; plural keys (`*One`/`*Other`) with `{count}` are now skipped since `pluralize()` handles substitution. No action required.
- **`usesTypeResolution` false flips fixed** — 8 rules across 4 files (`stylistic_rules.dart`, `ui_ux_rules.dart`, `widget_lifecycle_rules.dart`, `widget_patterns_ux_rules.dart`) were incorrectly set to `usesTypeResolution: false` despite using `NamedType.element` for superclass resolution; integrity test regex now catches `.superclass.element`. No action required.
- **Reports-dir single source of truth** — extracted `REPORTS_DIR` and `SAROPA_LINTS_DATA_DIR` constants plus path-builder helpers into `reportsPaths.ts`, replacing 27 hardcoded `'reports'`/`'.saropa_lints'` string literals across 18 production files. No action required.
- **Config loader deduplication** — extracted `_resolveEnvThenYaml` shared helper in `config_loader.dart`, replacing duplicated env-var-then-yaml lookup logic in `_loadShedRulesConfig` and `_loadMemoryMode`. No action required.
- **Scan-loop RSS guard** — the scan CLI now samples RSS between files and stops early (returning partial results) when memory exceeds the configured hard limit, preventing OOM on very large codebases. No action required.
- **CodeQL security fixes (13 alerts)** — added `permissions: contents: read` to 2 workflow YAMLs; fixed incomplete Markdown escaping in issue-tree tooltips; replaced substring URL check with parsed-hostname `isGitHubUrl()`; hardened pub.dev changelog HTML-to-markdown against tag-stripping bypasses and double-unescaping. No action required.
- **Shared `markdownUtils.ts`** — extracted `escapeMarkdown()` and added `buildMarkdownString()` structured builder for safe MarkdownString construction with mixed trusted/untrusted segments. Applied defense-in-depth escaping to hover-provider for external metadata (package names, vulnerability advisories, issue titles, file paths). No action required.

</details>

---

## [15.2.6]

Restores the Full Audit sidebar button and fixes `require_ignore_comment_plugin_prefix` showing the wrong diagnostic message when an ignore comment uses `saropa_lints/` prefix with an unregistered rule name. No new rules or breaking changes. [log](https://github.com/saropa/saropa_lints/blob/v15.2.6/CHANGELOG.md)

### Fixed

- **Full Audit sidebar button** — the "Full Audit" entry was missing from the extension sidebar despite being documented in 15.2.5. Now appears between Findings Dashboard and Command Catalog with a shield icon, plus a title-bar shortcut icon in the Editor Dashboards view header (visible only in Dart projects).
- **`require_ignore_comment_plugin_prefix` wrong message for unknown prefixed rule** — `// ignore: saropa_lints/nonexistent_rule` showed the "add prefix" message instead of the "not a registered rule" message. The reporter always reads `diagnosticCode` and ignores per-diagnostic `LintCode` overrides; fixed by temporarily swapping `diagnosticCode` during the unknown-prefix report.
- **Tier-change toast count mismatch with Findings Dashboard** — changing tier showed a toast with a violation count from the stale `violations.json` file while the dashboard read live diagnostics (often empty during re-analysis), producing "toast says N, dashboard shows 0". The toast now defers until the first diagnostics refresh settles, so both surfaces show the same count. The dashboard shows a "Re-analyzing..." progress indicator during the gap. A 15-second safety fallback fires if the analysis server never produces results.

<details><summary>Maintenance</summary>

- **`generate_translations.py` auto-commits** — the translation wrapper script now auto-detects every file the pipeline touches (no hardcoded path list) and commits them after a successful run. Pre-staged files are left untouched. Null-delimited git output handles unusual filenames. SIGINT is restored before git calls so Ctrl+C can abort a stuck commit. Pass `--no-commit` to skip the auto-commit for CI or review workflows.

</details>

---

## [15.2.5]

This patch moves `log_level`, `lane`, and `memory_mode` configuration from the `plugins > saropa_lints:` block in `analysis_options.yaml` to top-level keys in `analysis_options_custom.yaml`, eliminating false `unsupported_option` warnings from the Dart SDK's plugin-block validator. Projects using the old location get a deprecation warning and automatic fallback — the keys still work from the plugin block, but moving them to the custom file silences the warnings. [log](https://github.com/saropa/saropa_lints/blob/v15.2.5/CHANGELOG.md)

### Added

- **Full Audit CLI** — `dart run saropa_lints audit <dir>` runs every rule (pedantic + stylistic) against a codebase regardless of the project's configured tier. Produces enriched JSON with per-diagnostic `tier` and `category` fields. Supports `--since <ref>` to audit only changed files, `--min-severity`/`--min-impact` post-filters, `--profile` timing, and `--exclude-globs`/`--include-globs`.
- **Full Audit sidebar button** — new "Full Audit" entry in the extension sidebar launches the audit with a scope quick-pick (full project, changed vs main, or pick a branch) and opens a filterable report webview with search, tier/severity/impact filter chips, sortable columns, and JSON export. The progress notification shows real-time percentage, file count, issue count, and current filename.
- **Audit report keyboard navigation** — use ↑/↓ arrow keys to move between rows and Enter to open the file at that diagnostic. A "no matches" state now appears when filters exclude all results.
- **Audit baseline diffing** — `--save-baseline` saves the current audit as a project baseline at `.saropa/audit_baseline.json`; `--baseline` compares against the saved baseline and tags each diagnostic as new or unchanged. The sidebar quick-pick shows a "Compare to baseline" option when a baseline exists, and the report webview has a "Save as baseline" button and new/unchanged filter chips.
- **Migrate Config** — `dart run saropa_lints migrate-config` and a sidebar button ("Migrate config keys") automatically move `log_level`, `lane`, and `memory_mode` from the old plugin block to `analysis_options_custom.yaml`. Safe to run multiple times; already-migrated keys are skipped.
- **Configurable `max_declarations_per_file`** — set `max_declarations_per_file: N` in `analysis_options_custom.yaml` to allow up to N top-level declarations before `prefer_single_declaration_per_file` fires (default 1). No action required — existing behavior is unchanged.
- **Sealed hierarchy size nudge** — set `max_sealed_hierarchy_lines: N` in `analysis_options_custom.yaml` to get a lint when a sealed class file exceeds N lines, suggesting `part`/`part of` to split subtypes while keeping them in the same library (default 0 = disabled).

### Fixed

- `log_level`, `lane`, and `memory_mode` plugin configuration keys no longer trigger `unsupported_option` warnings from the Dart SDK analyzer. These keys now live as top-level entries in `analysis_options_custom.yaml` instead of under `plugins > saropa_lints:`. Projects still using the old location get a deprecation warning with the key's value honored as a fallback; `dart run saropa_lints init` generates the updated layout automatically.
- `prefer_sorted_parameters` no longer conflicts with `dart format`. The rule now respects `always_put_required_named_parameters_first`: required named parameters come first, then optional named parameters, each group sorted alphabetically. Includes a quick fix that reorders parameters automatically. ([#321](https://github.com/saropa/saropa_lints/issues/321))
- `require_text_overflow_handling` and `require_text_overflow_in_row` correction messages no longer default to `TextOverflow.ellipsis`. The guidance now recommends wrapping in `Expanded`/`Flexible` first — ellipsis is a last resort when truncation is intentional. Both rules offer context-aware quick fixes: "Wrap in Expanded" inside Row/Column/Flex, or "Add maxLines" elsewhere. ([#320](https://github.com/saropa/saropa_lints/issues/320))
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

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.
