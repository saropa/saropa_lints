# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are not included in version headers — [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays publish dates separately.

> **Looking for older changes?** \
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 6.2.0.

**Package** — [pub.dev / packages / saropa_lints](https://pub.dev/packages/saropa_lints)

**Score** — [pub.dev / packages / saropa_lints / score](https://pub.dev/packages/saropa_lints/score)

**CI** — [github.com / saropa / saropa_lints / actions](https://github.com/saropa/saropa_lints/actions)

**Releases** — [github.com / saropa / saropa_lints / releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com / items ? itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org / extension / saropa / saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

Each version (and [Unreleased]) has a short commentary line in plain language — what this release is about for humans. Only discuss user-facing features; vary the phrasing.

---

## [9.4.1]

_Housekeeping: plugging minor gaps carried over from the Package Vibrancy merge._

### Fixed

- **Extension** — dispose the upgrade-plan output channel on deactivation (was never cleaned up, minor resource leak)
- **Extension** — declare `focusIssuesForOwasp` command in `package.json` so VS Code can validate it; hidden from Command Palette since it requires a structured argument
- **Extension** — set `showPrereleases` context key via `setContext` so the show/hide prerelease toggle buttons reflect the actual state (context key was never set, causing when-clauses to mis-evaluate)

---

## [9.4.0]

_Package Vibrancy is now built into Saropa Lints. One extension, one sidebar — lint analysis and dependency health together._

### Added

- **Package Vibrancy integration** — merged the standalone Saropa Package Vibrancy extension into Saropa Lints
  - Three new collapsible sidebar panels: Package Vibrancy, Package Problems, Package Details
  - Dependency vibrancy scoring, vulnerability scanning (OSV + GitHub Advisory), SBOM export (CycloneDX)
  - Upgrade planning with test gates, bulk updates (latest/major/minor/patch)
  - CodeLens badges on pubspec.yaml dependencies showing vibrancy scores
  - Unused dependency detection, pubspec annotation, dependency sorting
  - Background version watching with configurable polling intervals
  - Budget enforcement (max dependencies, total size, min average vibrancy)
  - Private registry support with secure token storage
  - CI pipeline generation for dependency health checks
  - Package comparison view for side-by-side evaluation

### Changed

- **Build system** migrated from raw tsc to esbuild (bundled single file, smaller .vsix, faster startup)
- Extension minimum VS Code version remains ^1.74.0

---

## [9.3.0]

### Added

- "About Saropa Lints" screen showing extension version and full company/product info from `ABOUT_SAROPA.md` — accessible from the Overview welcome buttons and command palette
- "Getting Started" walkthrough button in Overview welcome content
- Overview intro text describing the two components (pub.dev package + VS Code extension)
- Version number shown in status bar tooltip for deployment verification
- `precompile` script auto-copies root `ABOUT_SAROPA.md` into extension bundle so the About screen stays in sync with the source of truth

### Changed

- Consolidated three status bar items into one — shows score + tier (e.g. `Saropa: 72% · recommended`), version in tooltip only
- Score display uses `%` format instead of `/100`
- Sidebar views hidden when empty — Issues appears with a Dart project, Config when enabled, Summary/Suggestions/Security Posture/File Risk after analysis has data
- Removed 15 redundant welcome content entries for views now hidden by `when` clauses
- "Learn More" button renamed to "Learn more online" to clarify it opens a website

### Administration

- **CRITICAL** Fixed extension never reaching VS Code Marketplace after v9.0.2 — `run_extension_package()` used `next(glob("*.vsix"))` which returned the stale 9.0.2 `.vsix` (alphabetically before 9.1.0/9.2.0) instead of the newly created one; now deletes old `.vsix` files before packaging and looks for the expected filename first
- Changed extension Marketplace publish prompt default from No to Yes (`[Y/n]`) — previous default silently skipped publishing with no warning
- Replaced misleading "package already published" error messages with clear descriptions of what actually failed

---

## [9.2.0]

Extension reliability and subdirectory project support.

### Fixed

- **IMPORTANT** Fixed YAML corruption in `ensureSaropaLintsInPubspec()` — regex backtracking placed the dependency on the same line as `dev_dependencies:`, producing invalid YAML that caused `dart run saropa_lints:init` to fail on every project
- Fixed `DEFAULT_VERSION` from stale `^8.0.0` to `^9.1.0`
- Fixed `fs` import shadowing in OWASP export handler (dynamic `import('fs')` shadowed static `import * as fs`)
- Fixed `package_config.json` verification to match exact `"saropa_lints"` instead of substring
- Removed unreachable fallback branch in inline annotations path computation

### Added

- Subdirectory pubspec detection — projects with `pubspec.yaml` one level deep (e.g. `game/pubspec.yaml`) are now discovered automatically
- Centralized project root discovery (`projectRoot.ts`) with per-session caching
- Workspace folder change listener invalidates cached project root
- Added `workspaceContains:*/pubspec.yaml` activation event

### Changed

- All 13 source files now use `getProjectRoot()` instead of scattering `workspaceFolders[0]` references
- Line-based YAML insertion preserves original CRLF/LF line endings

---

## [9.1.0]

### Changed

- Welcome views and status bar now detect non-Dart workspaces and show appropriate guidance instead of a misleading "Enable" button

### Removed

- **Logs view:** Removed the Logs panel from the sidebar — it was a file browser for the `reports/` directory, which the built-in file explorer already provides.

---

## [9.0.2]

Sidebar icon refinement.

### Changed

- **Sidebar icon:** Changed activity bar icon from solid fill to wireframe (stroked outline) for consistency with VS Code's icon style.

### Administration

- **Open VSX publish:** The publish script now prompts for an OVSX_PAT when the environment variable is missing, with platform-specific setup instructions, instead of silently skipping.
- **Stale plugin-cache repair:** `dart analyze` failures caused by a stale analyzer plugin cache are now detected automatically. The script offers to update `analysis_options.yaml` and clear the cache in one step.
- **Post-publish version sync:** After publishing, `analysis_options.yaml` plugin version is updated to the just-published version so `dart analyze` resolves correctly.

---

## [9.0.1]

Sidebar polish — fixed the broken activity bar icon, removed repetitive enable buttons, and auto-enabled the extension for existing users.

### Added

- **Auto-enable for existing projects:** The extension now detects `saropa_lints` in pubspec.yaml and enables itself automatically — no manual "Enable" click needed for projects that already depend on the package. New projects still see the welcome prompt.

### Fixed

- **Sidebar icon:** Replaced oversized colorful PNG with monochrome SVG that renders correctly in the VS Code activity bar and respects theme colors.
- **Repetitive enable buttons:** Removed duplicate "Enable Saropa Lints" buttons from Config, Logs, Suggestions, Security Posture, File Risk, and Summary views. The enable button now appears only in Overview and Issues; other views show a text pointer instead.

---

## [9.0.0]

The VS Code extension is now the primary way to use saropa_lints. One-click setup, health scoring, rule triage, inline annotations, OWASP compliance reports, and file risk analysis — all from the sidebar. The CLI remains for CI and scripting but interactive setup has moved entirely to the extension. Run “Saropa Lints: Getting Started” from the command palette to get started.

### Added

- **Health Score & Trends:** 0–100 project quality score in the Overview view and status bar, computed from violation count and impact severity. Color bands (green/yellow/red), score delta from last run, trend tracking over last 20 snapshots, milestone celebrations (50/60/70/80/90), and regression alerts when score drops.
- **Issues & Inline Annotations:** Error Lens-style decorations showing violation messages at the end of affected lines. Issues tree grouped by severity and file with text/severity/impact/rule filters, persistent suppressions, focus mode, group-by presets (Severity/File/Impact/Rule/OWASP), and context-menu quick fixes. Code Lens per file with critical count. Bulk “Fix all in this file” with progress and score delta. “Show in Saropa Lints” from the Problems view.
- **Security Posture:** OWASP Top 10 coverage matrix (Mobile and Web) with violation and rule counts per category. Click to filter Issues. “Export OWASP Compliance Report” generates a markdown report for audits.
- **Triage & Config:** Rules grouped by priority (critical, volume bands A–D, stylistic) with estimated score impact per group. Right-click to disable/enable rules — writes overrides to YAML and re-runs analysis. Packages auto-detected from `pubspec.yaml`. Custom config reduced from ~420 to ~40 lines.
- **File Risk:** Files ranked by weighted violation density — riskiest first. Flame icon for critical, warning icon for high. Summary shows “Top N files have X% of critical issues”.
- **First-run & Welcome:** "Getting Started" walkthrough with guided tour of all features (Health Score, Issues, Security, Triage, Trends, and About Saropa). Score-aware notification after enabling with actionable buttons. Native welcome states on all views when disabled or no data. Analysis auto-focuses Overview to show score delta. Extension report writer logs actions for audit trail.

### Deprecated

- **CLI init interactive mode:** `dart run saropa_lints:init` is now headless-only — defaults to `recommended` tier. Use the VS Code extension for interactive setup. CLI remains for CI/scripting with `--tier`, `--target`, `--no-stylistic`. Removed `--stylistic` (interactive walkthrough) and `--reset-stylistic` flags; use `--stylistic-all` for bulk enable.

### Changed

- **Custom config notice:** `analysis_options_custom.yaml` now includes a prominent "DO NOT EDIT MANUALLY" banner directing users to the VS Code extension for rule overrides.
- **Smart Tier Transitions:** Upgrading to a higher tier auto-filters the Issues view to critical + high violations so users aren't overwhelmed. Notification shows violation delta and "Show All" escape hatch. Tier picker shows rule counts, descriptions, and current-tier marker; same-tier selection is a no-op.
- Progress indicators for Run Analysis, Initialize Config, and Set Tier.
- Debounced refresh (300 ms) on `violations.json` changes.
- Summary view uses stable node IDs for expansion state.
- Status bar update logic consolidated across all command handlers.

### Fixed

- Health Score NaN guard for non-numeric JSON values.
- Run history dedup compares severity breakdown and score, not just total.
- Celebration messages only fire on genuinely new snapshots.
- Snapshot recorded before tree refresh so Overview reads fresh history.
- Inline annotations cache violations data; re-read only on file-watcher change.
- Test runner hanging indefinitely: added global 2-minute timeout (`dart_test.yaml`) and per-test timeouts on integration tests that spawn `Process.run` without a cap.
- Security Posture caches OWASP counts; OWASP filter clears prior filters; ID normalization handles short and long forms; data validation for malformed JSON.
- Output channel uses singleton pattern.
- Tree view fixes: root folder path prefix, severity/impact suppression timing, tier status bar immediate update.

### Administration

- Unified publish script (`scripts/publish.py`) for package and extension; extension version synced with package version.

---

## [8.2.2]

### Changed

- Release version bump

---

## [8.2.0]

### Added

- **Init `--target` flag:** `dart run saropa_lints init --target /path/to/project` generates configuration for any project directory, not just the current working directory.
- **Standalone scan command:** `dart run saropa_lints scan [path]` runs lint rules directly against any Dart project without requiring saropa_lints as a dependency. Reads the project's `analysis_options.yaml` (generated by `init`) to determine which rules to run. Results are written to a report file with a compact summary on terminal.

### Changed

- **Init tool modularization:** Extracted `bin/init.dart` (4,819 lines) into 21 focused modules under `lib/src/init/`, reducing the entry point to 15 lines. No behavior changes.
  - `cli_args.dart` — CLI argument parsing and `CliArgs` class
  - `config_reader.dart` — user customization extraction
  - `config_writer.dart` — YAML generation for `analysis_options.yaml`
  - `custom_overrides_core.dart` — override file creation and settings
  - `display.dart` — ANSI color support and `InitColors` class
  - `init_runner.dart` — main orchestrator (`runInit`)
  - `init_post_write.dart` — post-write phase (ignore conversion, walkthrough, analysis)
  - `log_writer.dart` — `LogWriter` class, report file management
  - `migration.dart` — V4/V7 migration detection and conversion
  - `platforms_packages.dart` — platform and package settings
  - `preflight.dart` — pre-flight environment checks
  - `project_info.dart` — project and package detection
  - `rule_metadata.dart` — rule metadata cache and lookups
  - `stylistic_rulesets.dart` — stylistic rule category data
  - `stylistic_section.dart` — stylistic section builder
  - `stylistic_section_parser.dart` — stylistic section parsing
  - `stylistic_walkthrough.dart` — interactive walkthrough orchestrator
  - `stylistic_walkthrough_prompts.dart` — walkthrough UI prompts
  - `tier_ui.dart` — tier selection UI
  - `validation.dart` — post-write config validation
  - `whats_new.dart` — release notes display (moved from `bin/`)

### Fixed

- **19 false positive bugs fixed across scan rules:**
  - **Self-referential false positives (8 rules):** `avoid_asset_manifest_json`, `avoid_ios_in_app_browser_for_auth`, `avoid_mixed_environments`, `avoid_purchase_in_sandbox_production`, `require_database_migration`, `require_https_only`, `require_unique_iv_per_encryption`, `require_websocket_reconnection` — rules no longer flag their own detection pattern strings in `lib/src/rules/` and `lib/src/fixes/` directories
  - **Flutter-only rules skip non-Flutter projects (5 rules):** `avoid_blocking_main_thread` (-170 FPs), `avoid_print_in_release` (-197 FPs), `avoid_long_running_isolates`, `prefer_platform_io_conditional`, `require_android_permission_request` — rules now check `ProjectContext.isFlutterProject` and skip CLI tools, servers, and analysis plugins
  - **Detection logic improvements (6 rules):** `avoid_api_key_in_code` skips regex patterns; `avoid_catch_all` allows `developer.log(error:, stackTrace:)` defensive catches; `avoid_hardcoded_config` whitelists `pub.dev`/`github.com` URLs; `avoid_parameter_mutation` no longer flags collection accumulator methods (`.add()`, `.addAll()`, etc.); `require_catch_logging` recognizes `developer.log` and `stderr`; `require_data_encryption` checks argument text only (not receiver names)

---

## [8.0.11]

Reduces false-positive noise: strings with embedded quotes (like SQL literals) and non-HTTP `.get()`/`.post()` calls (like map lookups and server handlers) are no longer incorrectly flagged.

### Fixed

- **`prefer_single_quotes` false positive on interpolated strings containing single quotes (v7):** The `StringInterpolation` handler now skips double-quoted strings whose literal parts contain `'` characters (e.g. SQL literals like `"WHERE $col = 'active'"`), matching the existing `SimpleStringLiteral` behavior.
- **`require_network_status_check` false positive on local store lookups and server handlers (v3):** Removed overly broad `.get(`/`.post(` regex patterns that matched any method call (e.g., `_sessionStore.get()`, `Map.get()`). Replaced with specific HTTP client patterns (`dio.get(`, `client.get(`, etc.). Methods with server-side handler parameters (`HttpRequest`, `HttpResponse`, `Request`, `RequestContext`) are now excluded.

### Archive

- Rules 6.2.0 and older moved to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md)

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

- Version bump for release testing

---

## [7.0.1] _(retracted)_

_Retracted: required analyzer 10; Flutter does not yet support analyzer 10. Use [8.0.0](#800) instead._

In this release we’re preparing bug fixes and small rule refinements.

### Fixed

- **avoid_renaming_representation_getters** — No longer reports when the representation is private and there is exactly one public getter that exposes it under a different name (e.g. `String get sql => _sql`). Resolves conflict with prefer_private_extension_type_field. See bugs/history/bug_extension_type_avoid_renaming_vs_prefer_private_conflict.md.

- **prefer_const_constructor_declarations** — No longer suggests const when: (1) any constructor parameter has a function type (callbacks cannot be const); (2) the class extends a superclass with no const constructor (e.g. ChangeNotifier); (3) the constructor initializer list or super arguments use non-const expressions (method calls, non-const constructor calls, binary/conditional). Resolves bug_prefer_const_constructor_declarations_callback_field, bug_prefer_const_constructor_declarations_change_notifier, bug_prefer_const_constructor_declarations_non_const_initializers.

- **prefer_safe_area_consumer** — No longer reports when the Scaffold has no `appBar` and no `bottomNavigationBar`. In that case the body extends under system UI and SafeArea is appropriate. Resolves bug_prefer_safe_area_consumer_scaffold_without_appbar.

- **require_api_response_validation** — No longer reports when the decoded value is validated by a subsequent type check (e.g. `if (decoded is! Map && decoded is! List) throw`) in the same block (validation-helper pattern). Resolves bug_require_api_response_validation_require_content_type_in_validator_impl.

- **require_content_type_validation** — No longer reports when a dominating content-type guard returns or throws (not only return) before `jsonDecode`, and when the guard is nested inside an outer if block. Resolves bug_require_api_response_validation_require_content_type_in_validator_impl.

- **prefer_webview_sandbox** — Internal: removed null assertion in controller root helper; handle nullable `PropertyAccess.target` to satisfy avoid_null_assertion.

---

## [7.0.0] _(retracted)_

_Retracted: required analyzer 10; Flutter framework does not yet support analyzer 10. Use [8.0.0](#800) instead._

In this release we move to the analyzer 10.x API and Dart SDK 3.9+. Rule names now use lowerCaseName—see the migration guide for updating your config.

**Breaking: Analyzer 10 upgrade** — This release upgraded to the analyzer 10.x API. See [Upgrading to v7](doc/guides/upgrading_to_v7.md) for migration steps. **This version was retracted** because Flutter does not yet support analyzer 10.

### Requirements _(retracted release)_

- **Dart SDK:** 3.9 or later.
- **Analyzer:** 10.x only. **saropa_lints 6.2.2** was the last release compatible with analyzer &lt; v10 before retraction; **8.0.0** is the current release for analyzer 9.

### Breaking changes _(retracted release)_

- **Dependencies:** Required `analyzer: ^10.0.0`, `analysis_server_plugin: ^0.3.10`, and `analyzer_plugin: ^0.14.0`. Dropped support for analyzer 9.x.
- **Config keyed by lowerCaseName:** Rule identifiers and config keys would use the analyzer's **lowerCaseName**. Use `prefer_debugprint` instead of `prefer_debugPrint`. Update `analysis_options.yaml` and any `// ignore:` comments that reference rule names.
- **AST API:** All rule files were migrated to analyzer 10 `body` and `namePart` API (e.g. `(node.body as BlockClassBody).members`, `node.namePart.typeName`).
- **Init:** Running `dart run saropa_lints:init` on an existing v6 config would normalize rule names to lowerCaseName; pre-flight warned if Dart SDK &lt; 3.9 when using v7.

### Changed _(retracted release)_

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

## [6.2.0] and Earlier

For details on the initial release and versions 0.1.0 through 6.2.0, please refer to [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md).
