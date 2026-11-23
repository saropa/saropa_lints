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

2350+ custom lint rules with 250+ quick fixes for Flutter and Dart — static analysis for security, accessibility, performance, and library-specific patterns. Includes a VS Code extension with Package Vibrancy scoring.

**Package** — [pub.dev/packages/saropa_lints](https://pub.dev/packages/saropa_lints)

**Releases** — [github.com/saropa/saropa_lints/releases](https://github.com/saropa/saropa_lints/releases)

**VS Code Marketplace** — [marketplace.visualstudio.com/items?itemName=saropa.saropa-lints](https://marketplace.visualstudio.com/items?itemName=saropa.saropa-lints)

**Open VSX Registry** — [open-vsx.org/extension/saropa/saropa-lints](https://open-vsx.org/extension/saropa/saropa-lints)

<!-- MAINTENANCE NOTES -- IMPORTANT --

   Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/); versioning: [SemVer](https://semver.org/spec/v2.0.0.html). Omit dates from headers, because [pub.dev](https://pub.dev/packages/saropa_lints/changelog) displays them.

   **Overview** — Every release (and [Unreleased]) opens with a 2–4 sentence user-facing summary that doesn't restate the bullets. Banned: file paths, line numbers, regex snippets, internal flag names, project-specific counts or percentages, and AST or visitor terminology. End with `[log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)` (no preceding line break), substituting the version.

   **Bullet density (HARD RULE)** — Applies to every bullet under `### Added`, `### Changed`, `### Fixed`, `### Removed`, and their `(Extension)` variants. Write one sentence per bullet, in the order *what changed → why the user cares → what the user must do* ("No action required" when true). A second sentence is allowed only when a required user action doesn't fit in the first. Never write three; split the bullet, or move the detail to the commit message, PR, bug report, or code comment and link out. Concision edits may touch historical sections.

   **Banned inside bullets** (move to commit message, PR, or code comment):
   - **PR archaeology** — prior attempts, rename history, "after X didn't hold". Describe the landed state only.
   - **File-by-file inventories** — that is the git diff.
   - **Test counts** — that is CI output.
   - **Code-internal names** — AST classes, regex flags, function signatures, field or type names, private identifiers.
   - **Bug-report, fixture, or test paths** — commit message footer only.
   - **Decision-making narrative** — one clause of reasoning is fine, not a paragraph.

   **Internal bullets** — Same bans apply (no test counts, no file inventories). The what→why→must-do template is optional for infra-only entries.

   **Internal section** — Changes with no end-user impact (publish/CI tooling, internal refactors, test harness, plan housekeeping, developer scripts) go under `### Internal` at the bottom of the version section, never in `### Added` / `### Changed` / `### Fixed`. NEVER use `<details><summary>Maintenance</summary>`. Test: if a pub.dev or Marketplace user would notice, it's top-level; otherwise Internal.

   **Unreleased convention** — While work is in progress, the top section MUST be headed `## [X.Y.Z] — Unreleased`. Put all new entries in this ONE section: never create a second unreleased section or bump the version. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) via `_strip_unreleased_suffix()`. `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle. A section is published only when its git tag `vX.Y.Z` exists (`git tag -l vX.Y.Z`). If the top section has no tag, it is the unreleased section even when the ` — Unreleased` suffix is missing, so add entries there.

   **Tagged changelog** — Published versions use git tag `vx.y.z`, and each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [17.7.1] — Unreleased

Published rule counts are now consistent across the README, extension, migration guides and in-product text, and the Vietnamese comparison label reads correctly. [log](https://github.com/saropa/saropa_lints/blob/v17.7.1/CHANGELOG.md)

### Changed

- Rule-count claims in the README, extension README, extension manifest strings, translated catalogs, welcome panel fallback, About pages, Professional Services page and every migration guide now say "2350+" instead of a mix of 1400+, 1500+, 2100+ and 2300+; no action required.

### Fixed

- The Vietnamese label under the package count in the comparison view no longer reads "so sánh trong khi so sánh." and now reads "đang so sánh"; no action required.

---

## [17.7.0]

Scanning now uses your computer's cores while staying careful with its memory: large projects scan several times faster, the VS Code whole-project scan finishes in about a minute instead of tens of minutes, and a scan that would strain your machine slows itself down — and tells you how to fix it — instead of freezing it. [log](https://github.com/saropa/saropa_lints/blob/v17.7.0/CHANGELOG.md)

### Added

- `scan` runs in parallel by default (`--jobs <n|auto|off>`), sized from your CPUs, free memory and container limits, so large scans finish sooner on CI and desktops alike — use `--jobs 1` for the old serial behavior.
- `scan` watches its own memory (`--max-memory-mb`), sheds workers under pressure, and stops early with exit code 3 rather than risk the machine — a gate can no longer pass on a partial scan.
- `scan` recovers from a file that hangs a worker (`--chunk-timeout`), skips and names it, and reports slow files (`--slow-file-ms`) so you can see what makes a scan slow.
- `scan --progress plain` prints a status line every 15 seconds, which is readable in CI logs; the GitHub Action gained `jobs` and `max-memory-mb` inputs.
- VS Code: **Scan Whole Project for Issues** now defaults to a fast parallel scan (`saropaLints.scanOnSave.baselineMode`) and offers the type-aware deep scan afterwards with a time and memory estimate; no action required.
- VS Code: **Saropa Lints: Scan Performance and Memory Settings…** shows what each profile (`gentle`, `balanced`, `fast`) would do on your machine and recommends one; fine-tune with `saropaLints.scan.maxWorkers` and `saropaLints.scan.maxMemoryMb`.
- `scan --max-issues <n>` (also `SAROPA_LINTS_MAX`) sets how many non-error issues are reported; the default is now unlimited so reports and `--fail-on-count` thresholds are complete, and errors are never capped — pass `--max-issues 500` to restore the old cutoff.
- A new `max_rss_mb` key in `analysis_options_custom.yaml` sets the live analyzer plugin's hard memory cap without needing an environment variable; `SAROPA_LINTS_MAX_RSS_MB` still overrides it.
- VS Code: choosing the gentle profile (or opening a project on a small computer with no limits set) offers a one-click, machine-sized memory limit and graceful rule shedding for live analysis, then offers to restart the analysis server.
- VS Code: `saropaLints.scan.maxIssues` controls the issue cap for whole-project and on-save scans (default unlimited).
- VS Code: when free memory is low, the multi-GB type-aware scan is skipped or paused with a notification offering one-click fixes (use the fast scan, turn off type resolution, resume, or open settings) instead of starting on a struggling computer.

### Changed

- The scan CLI and VS Code scan daemon no longer silently drop non-error issues beyond 500, which previously made reports and count-based CI thresholds incomplete; the analyzer plugin keeps its 500-issue Problems-tab default.
- VS Code scan processes now run at reduced CPU priority (`saropaLints.scan.lowPriority`, on by default) so typing stays smooth during a scan; no action required.
- A fast whole-project scan no longer overwrites findings from files that were already scanned with type resolution; no action required.

### Internal

- New locale strings (`scanResources.*`) ship in English in every locale until the translation pipeline is run; they are allowlisted in `english_allowed.json`.

---

## [17.6.0]

The extension's rating prompts, welcome panel, scan progress message and several other strings now read natively in all 24 supported languages instead of falling back to English. Eleven false positives are also fixed. [log](https://github.com/saropa/saropa_lints/blob/v17.6.0/CHANGELOG.md)

### Fixed

- `avoid_context_after_navigation` no longer reports the awaited navigator call itself (e.g. `await Navigator.maybePop(context)`). The `context` argument is evaluated before the await, so only uses after the await are checked.
- `avoid_gesture_only_interactions` no longer flags a GestureDetector when an ancestor `Semantics` supplies `onTap`/`onLongPress`, or when it is an opaque `SizedBox`/`ColoredBox` hit region with nothing to focus.
- `avoid_variable_shadowing` no longer reports Dart 3 wildcard `_` locals, loop variables or parameters.
- `require_ios_accessibility_large_text` no longer flags a literal `TextStyle(fontSize:)` consumed by `Text`/`RichText` (ambient `TextScaler`) or a `TextPainter` with a `textScaler:`. It still reports bare styles and consumers that pin scaling off (`TextScaler.noScaling`, `textScaleFactor: 1`).
- `invalid_field_name` no longer reports contextual keywords (e.g. `when`) used as record field names; only reserved words are flagged.
- `prefer_static_method` no longer flags a state-free method that other code in the library calls through an instance receiver (`widget.button.buildTile()`). Making it static would break those callers.
- `avoid_motion_without_reduce` no longer reports animated widgets whose duration (or enclosing class) is gated through a project reduce-motion helper such as `isMotionReduced`, or that use `Duration.zero`.
- `avoid_public_members_in_states` no longer flags `@override` members that implement a user-defined mixin or base-class contract.
- `prefer_stream_distinct` no longer fires when the `listen` callback ignores its event parameter (`(_) => ...` or an unused parameter).
- `require_permission_manifest_android` now reads the project's AndroidManifest.xml. It no longer reports `permission_handler` imports when the manifest already declares permissions or when there is no manifest to check.
- `avoid_implicitly_nullable_extension_types` now reports only extension types with a nullable or bare-type-parameter representation. Non-nullable representations (`int`, `List<T>`) are no longer flagged.
- `avoid_public_members_in_states` now exempts an `@override` only when it comes from a mixin or an SDK/Flutter type, and again reports overrides of app-defined State base classes. It also now checks transitive State subclasses.
- `avoid_gesture_only_interactions` ignores `Semantics(onTap: null)` and no longer accepts a distant page-level `Semantics`; only a near ancestor counts.
- `avoid_motion_without_reduce` matches reduce-motion helper names on identifier boundaries, so `unreducedMotionDuration` no longer counts as a guard.
- `require_ios_accessibility_large_text` treats `TextScaler.linear(1)` and `textScaleFactor: 1.0` as pinned scaling.
- `avoid_implicitly_nullable_extension_types` also flags `dynamic` and `Null` representation types.
- `require_permission_manifest_android` also reads debug/profile manifests, ignores commented-out `<uses-permission>` entries, and looks up the manifest only once a `permission_handler` import is seen. Flutter's default debug manifest declares INTERNET, so the reminder is now silent for default projects.
- `prefer_static_method` now also treats cascade calls, tear-offs and `this.m()` as instance use, with one pass per file instead of one per method.

### Changed

- Added hand-written translations for the rate-and-feedback prompts, "What's New" panel, workspace scan progress and roughly 100 smaller strings across the translated locales. They have not had native-speaker review.

### Internal

- Scan tests (`git_changed_files_test`, `scan_analyzer_exclude_test`) now compare separator-neutral paths on Windows; the anti-pattern `.contains()` guard is satisfied by the iOS large-text rule.
- Fixed `ScanRunner.runResolved` silently skipping explicitly requested files that the project's `analyzer: exclude:` removes, which broke the resolved-superset-of-syntactic invariant. Also normalized the path in `_createContextUnit` so mixed-separator targets no longer throw "Path must be normalized" on Windows, and made the git-changed-files and analyzer-exclude tests separator-neutral.
- i18n dictionaries: technical labels (pubspec/plugin-route version sources, RSS/heap readout, `WASM`, `GitHub Actions CI`, `N/A`, `UPDATE`) are now passthroughs in every locale, and `dev` is a cognate in the nine locales that kept it. Hand translations live in `extension/scripts/i18n/manual_translations.py` and `manual_translations_gaps.py`.

---

## [17.5.0]

Polish translations in the extension are refreshed, and the release tooling no longer stalls on a stale version number. [log](https://github.com/saropa/saropa_lints/blob/v17.5.0/CHANGELOG.md)

### Changed

- Refreshed the Polish extension translations. No action required.

### Internal

- Publish script: a stale `pubspec.yaml` version found at the pre-commit check is now auto-corrected (and re-staged along with `extension/package.json`) instead of dead-ending at the Retry/Abort menu.

---

## [17.4.9]

Scan notifications are quieter: one progress notification replaces the stack of "N issues found" toasts while the workspace scan runs. The What's New panel no longer shows the red engine-change warning to fresh installs or unconfirmed upgrades, and it gains a "Rate Us" card, a rating nudge after your 5th successful scan, and Help Hub entries for the Marketplace and Open VSX review pages. [log](https://github.com/saropa/saropa_lints/blob/v17.4.9/CHANGELOG.md)

### Changed

- The "N issues found" warning no longer stacks a new toast for every auto-triggered analysis while the workspace scan is still running; a single progress notification shows the scan percentage and the running issue count, and the final toast appears once when the scan completes.
- The What's New panel now shows the red "Default Diagnostic Engine Changed" card and its warning subtitle only when upgrading from a version before v16; fresh installs and upgrades the extension cannot confirm no longer see it. No action required.

### Added

- Added a "Rate Us" call-to-action on the What's New welcome panel with links to the VS Code Marketplace, Open VSX review pages, and GitHub Issues — a gradient-accented card with animated stars, centered between the discovery grid and the show-next-time checkbox.
- Added a scan-gated rating nudge toast that appears after the user's 5th successful scan, linking to both extension stores and the GitHub issues page. Respects the proactive-nudge opt-out and defers gracefully on "Not now".
- Added "Rate on VS Code Marketplace" and "Rate on Open VSX" entries to the Help Hub quick pick, so users can reach the review pages at any time.
- Added `saropaLints.rateOnMarketplace` and `saropaLints.rateOnOpenVsx` commands (Command Palette + Command Catalog).

---

## [17.3.0]

Rules & Tiers results and the "Explain rule" panel can now turn a rule off without a trip to the Overrides tab, and several Health Panel dashboards render correctly again after a CSP directive was silently dropping their inline style updates. The scan CLI is more reliable on large or unusual project layouts: it no longer runs out of memory with `--resolve`, and `--exclude-globs` no longer crashes when the excluded path contains a directory the scan can't read. [log](https://github.com/saropa/saropa_lints/blob/v17.3.0/CHANGELOG.md)

### Added

- Added a disable/enable action directly on Rules & Tiers rule-search results and on the standalone "Explain rule" panel, so a rule can be turned off without switching to the Overrides tab.
- Added `--strict-files` flag to the scan CLI: exits 2 when ANY `--files` entry is skipped (outside the analysis root), not just when all are skipped. Use in CI pipelines that must guarantee every named file was analyzed.

### Changed

- Removed the duplicate rule `prefer_named_boolean_parameters`; `avoid_positional_boolean_parameters_with_fix` reports the same positional `bool` parameters and adds a quick fix. Existing `analysis_options.yaml` entries naming the old rule (disable or severity override) still apply to the surviving rule; a `// ignore: prefer_named_boolean_parameters` comment no longer suppresses it, so rename it to `avoid_positional_boolean_parameters_with_fix`.

### Fixed

- `require_data_encryption` no longer reports writes to network or stream sinks (`HttpResponse`, `IOSink`, `Socket`, `WebSocket`); sending a response body is transport, not storage. `File.writeAsString` and similar persistence calls still report.
- Fixed a webview CSP directive that combined a nonce with `unsafe-inline` for `style-src`, which per spec silently dropped inline style writes across several dashboards (the Rules & Tiers coverage gauge, chart bars, and score pills now render correctly again). No action required.
- The removed `saropaLints.scanOnSave.enabled` setting is now detected and flagged (output channel plus a one-time notification) instead of silently doing nothing; remove it from `settings.json`.
- Fixed the "Explain rule" panel showing "Run analysis to see it in context" for a disabled rule that has never fired; it now explains the rule is disabled and suggests re-enabling it. No action required.
- Fixed the "Explain rule" fallback panel showing an unbounded pack-label list; it now caps at 3 labels with a "(+N more)" indicator. No action required.
- Fixed `scan --resolve` exceeding its memory limit after a single file on most projects by sharing one analysis context across all files instead of creating one per file ([#402](https://github.com/saropa/saropa_lints/issues/402)). No action required.
- Fixed `scan --exclude-globs` crashing with a permission error when the excluded path contained an unreadable directory, because the scan listed every subdirectory before applying exclusions ([#408](https://github.com/saropa/saropa_lints/issues/408)). No action required.
- Fixed `scan --files --resolve` silently exiting 0 when requested files fell outside the analysis context root, letting CI pass having scanned nothing. The scan now exits non-zero and prints which files were skipped. No action required.
- Fixed `avoid_case_sensitive_path_comparison` false positive on route handler methods where `path` is a `String` parameter alongside an `HttpRequest` parameter. The rule now recognizes the route-handler signature and exempts comparisons in that context. No action required.
- Added regression coverage for `avoid_case_sensitive_path_comparison` confirming that the upward directory-walk root check (`parent.path == dir.path` with `dir = parent;` afterwards, on a real `dart:io` `Directory`) and `!=` route comparisons against a local from `req.uri.path` are not flagged, while `File(a).path == File(b).path` still lints. No action required.
- Fixed `require_isolate_for_heavy` false positive on `jsonEncode`/`jsonDecode` of a map or list literal (e.g. a small error-response body in a server handler); literal payloads have fixed small size so no isolate is needed. Non-literal arguments still lint.
- Fixed `avoid_unnecessary_nullable_fields` false positive when a constructor initializer can yield null (e.g. `cond ? Value() : null`, or a `??` chain ending in a nullable expression); only literal `null` was recognized before. No action required.
- Fixed `prefer_cached_getter` false positive on repeated reads of plain `dart:` SDK accessors such as `HttpRequest.method`; lazy `Iterable` and `Stream` getters and user-declared getters are still flagged.
- Fixed `prefer_utc_for_storage` false positive on a `final` field that is UTC by construction (`Entry(DateTime now) : at = now.toUtc();` or `final at = x.toUtc();`); fields set through `this.at` or from non-UTC values still lint.
- Fixed `avoid_platform_specific_imports` false positive on files reachable only through the `dart.library.io` branch of a conditional import or export; the whole io-only subtree is now skipped, while files that the stub/web path can also reach are still reported.

### Internal

- Added "Dart SDK", "Flutter SDK", "Flutter daemons", and "Vibrancy" to `DO_NOT_TRANSLATE` in `extension/scripts/i18n/dictionaries.py`; these proper nouns no longer show as missing translations in every locale.
- Added `extension/scripts/i18n/bad_translations.py`: detects mechanically defective machine translations (leaked shield sentinels and `⁇`, prompt echo, wrong script, hallucinated length, placeholder drift, blocklisted domain-term renderings from `bad_translations_blocklist.json`). `generate_locales.py` now auto-prunes flagged cache entries on every run so they are re-translated; `--check` exits 1 on any flagged shipped string and `--purge` clears the cache on demand.
- Fixed `mt_fallback._SHIELD_RESIDUE_RE` missing bare `ZZ`, `_PH<n>_`, and `ПХ<n>` shield leaks, so such translations were accepted and cached at write time; they are now rejected before caching, matching `bad_translations.py`. `bad_translations.py --purge` now backs the cache up to `mt_strings.json.bak` first.
- Fixed `generate_locales.py` aborting a locale (and discarding its translations) when Qwen failed on a few pruned short labels: the cache is now saved before the english-regression guard, and a string that falls back to English keeps its existing shipped translation instead of regressing.
- Fixed `generate_locales.py` appearing to hang for minutes after a locale's "engines ->" line: the mapping pass re-ran every string the engines had just failed on through Qwen and Google (28 s timeout plus backoff each). The pass is now cache-only (`HybridTranslator(cache_only=True)`), so failed strings fall straight back to English or their shipped translation.
- Qwen translation now runs 2 requests at once (`SAROPA_QWEN_PARALLEL`, 1-4, default 2; sets the daemon's `OLLAMA_NUM_PARALLEL` to match) because a single stream left the GPU 10-30% busy. Each result is keyed to its own source string; progress, checkpoints and Ctrl-C stay on the main thread. Set `SAROPA_QWEN_PARALLEL=1` for the old serial behavior. Speedup unmeasured.
- `generate_locales.py` now prints a VRAM report before a Qwen run (`vram_report.py`): used/free MB, the apps holding GPU memory (Windows counter, allocation not residency), and a per-app tip for turning off hardware acceleration in VS Code, Firefox, Chrome, Edge, Discord, Slack and Teams. Report only; best-effort and silent without `nvidia-smi`.
- Added `extension/scripts/i18n/coverage_report.py`: prints a per-locale translation coverage table and rewrites the marked "Extension language coverage" block in `README.md`. `generate_locales.py` refreshes the block on every coverage write, from the same `locale_coverage.json` the language picker uses.
- Added `extension/scripts/i18n/semantic_check.py`: ranks shipped translations by cross-lingual embedding similarity (local Ollama, default `bge-m3`) to surface meaning drift the mechanical detector cannot see. Report only, no translation performed; precision unmeasured.
- CI now runs `extension/scripts/check_l10n_keys.py --check-params`, failing when a literal `l10n()` key is missing from `en.json` or its call-site params do not match the catalog placeholders. Five checker false positives (variable, spread and webview-substituted params) are marked `l10n:passthrough`.
- Added a GitHub Actions workflow that runs saropa_lints on pull requests.
- Added a master switch card (`saropaLints.enabled`) to the Health Panel's Diagnostic Engines section; the Scan on Save card dims when it is off, since that is the only engine the setting gates. A folder-level override of the setting is flagged on the card and in a warning after a click.
- Eliminated redundant `contextFor` lookups in the resolved scan path: the analysis context is resolved once per file and passed through, removing 1-2 extra hash-map probes per file in `_scanFilesResolved` and `runResolvedWithCollection`.
- The publish script now writes the known-issues review list to the ignored `reports/` folder and prints the queued packages, instead of committing a file to `bugs/`.
- The Qwen translation prompt now includes a short glossary of domain terms (audit, suppress, gate, transitive, hotspot, tier, …) when a string contains them, fixing word-sense mistranslations found in a side-by-side review.

---

## [17.2.0]

Adds a rule that suggests the narrower width and height lookups on `MediaQuery`, so widgets rebuild only when the dimension they read changes. [log](https://github.com/saropa/saropa_lints/blob/v17.2.0/CHANGELOG.md)

### Added

- **`prefer_media_query_width_height_of`:** new rule (comprehensive tier, INFO, quick fix) that flags `MediaQuery.sizeOf(context).width` and `.height`, the `maybeSizeOf` form, and `MediaQuery.of(context).size.width`, because the whole screen size is watched when only one dimension is read; it stays silent on Flutter older than 3.35, where `widthOf` and `heightOf` do not exist, so no action is required there ([#406](https://github.com/saropa/saropa_lints/issues/406)).

### Changed

- **Bug report form is shorter ([#404](https://github.com/saropa/saropa_lints/issues/404)):** only the rule name, a summary, a code sample that shows the problem, expected versus actual behavior, and the saropa_lints version are required. Severity, frequency, the rule's source file and the attribution check are optional. The form says that reports without a code sample, or without replies to follow-up questions, may be closed.
- **Rule pack lists regenerated:** the VS Code extension's pack and tier lists now include every rule. `avoid_reexports` is no longer in the "Migrate from awesome_lints" and "Migrate from DCM" packs, because neither tool has a matching rule; it stays in the architecture pack.

### Fixed

- **`scan --exclude-globs` and `--include-globs` match relative to the scanned folder ([#405](https://github.com/saropa/saropa_lints/issues/405)):** a pattern such as `packages/**` now matches `packages/mypackage/lib/src/x.dart` under the folder being scanned. Before, only `**/packages/**` worked. Every pattern that worked before still works.
- **`scan` honors `analyzer: exclude:` ([#403](https://github.com/saropa/saropa_lints/issues/403)):** `dart run saropa_lints scan` now skips the paths listed under `analyzer: exclude:`. It uses the nearest `analysis_options.yaml` at or above the scanned folder, with patterns relative to that file's folder, which matches how `dart analyze` picks the options file. `--find-stale-ignores` and `--fix-stale-ignores` skip the same files. Explicit `--files` lists are not filtered, same as `--exclude-globs`. No action required.

## [17.1.0]

The 17 line is out of beta: this is the first stable release since the 17.0.1 betas, and it includes all of their changes. It also removes false positives from `avoid_hardcoded_colors` where colors define the theme rather than bypass it. [log](https://github.com/saropa/saropa_lints/blob/v17.1.0/CHANGELOG.md)

### Upgrading from 16.x

- **Requirements:** the 17 line needs Dart 3.11 or newer and analyzer 13 or 14. Projects held on analyzer 12 stay on `^16.7.0`.
- **Rule renamed:** `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended`. Update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name. The extension's compatibility card offers to rewrite them for you.

### Fixed

- **New-project setup picks a current version (extension):** enabling Saropa Lints in a project that does not depend on it yet now writes the newest `saropa_lints` its Dart SDK supports (the same choice the compatibility card makes) instead of the frozen `^16.2.1`. If the Dart version or the pub.dev list cannot be read, it writes `^16.7.0`, and it does the same when the pub.dev lookup takes longer than 8 seconds. `^16.7.0` needs Dart 3.9 or newer.
- **`avoid_hardcoded_colors`:** no longer flags colors written inside `ColorScheme`, `TextTheme`, `*ThemeData` constructors or `ThemeExtension` classes, or a private constant used only there (such as a seed passed to `ColorScheme.fromSeed`), so theme definitions stay clean. No action required.
- **`avoid_hardcoded_colors`:** no longer flags fully transparent colors (`Colors.transparent`, alpha 0), which look the same in every theme. No action required.

### Changed

- **Package Vibrancy known issues:** the pricing notes for 11 hosted-service packages (AppsFlyer, CometChat, Datadog, UXCam, Mapbox, RevenueCat, Scanbot, Stream, Superwall, Syncfusion, ZEGOCLOUD) were re-checked against vendor pricing pages and reworded to plain facts. AppsFlyer and CometChat now show as freemium, as both offer a free tier. The AppsFlyer migration notes no longer recommend Firebase Dynamic Links, which Google shut down in 2025. A new optional `reasonVerified` field in the known-issues schema records the date a person last checked an entry's reason text; those 11 entries carry it. No action required.
- **Package Vibrancy known issues:** the warnings for flutter_sticky_header, google_api_availability and blinkid_flutter were re-checked and reworded to match their changelogs and repositories (blinkid_flutter's wrapper is open source and only the Microblink SDK needs a license key), with statuses unchanged. No action required.

### Internal

- **Known-issues review queue is now a tracked dated file:** the publish-time report is written to `bugs/YYYY-MM-DD_known_issues_review_queue.md` on every run (even with zero entries) instead of the gitignored `plans/known_issues_review.md`; older dated files are kept.
- **CI tests the newest analyzer:** the analyzer matrix now pins analyzer 14.7.0 (with `analysis_server_plugin` 0.3.26) for its Dart 3.13 row instead of 14.6.0, so the range users actually get on Dart 3.13 is the one tested.
- **Known-issues review report skips recently verified paid-package warnings:** the publish-time review no longer re-lists business-model (paid/commercial) entries whose human-set `reasonVerified` date is within the last 183 days, so a warning a person just checked is not flagged again on every release. Tooling-refreshed `as_of` dates do not count.
- **Known-issues review report skips entries verified since the latest release:** any entry (every tier) whose human-set `reasonVerified` date is on or after the package's latest pub.dev release date is no longer re-listed; a newer release brings it back. The publish step and generator write no review file when nothing needs review.
- **CI never changes dependency versions:** jobs now run on the Dart SDK the lockfile requires, fail if installing dependencies would change the lockfile, and the formatting bot can only commit source and test files, so it can no longer push a downgraded analyzer to a pull request.

---

## [17.0.1-beta.9]

Removes a false positive from `avoid_unremovable_callbacks_in_listeners`. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.9/CHANGELOG.md)

### Fixed

- **`avoid_unremovable_callbacks_in_listeners`:** no longer flags `addPostFrameCallback` or `addPersistentFrameCallback`, which have no remove API, so a named function cannot help. No action required.

---

## [17.0.1-beta.8]

New `avoid_reexports` rule; analyzer exclusions check in the VS Code extension; security update for a dependency bundled with the VS Code extension. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.8/CHANGELOG.md)

### Added

- **Extension: analyzer exclusions check.** Suggests excluding folders that need no analysis (`android`, `ios`, `build`, `docs`, `.claude/worktrees` and similar) from `dart.analysisExcludedFolders`, flags folders excluded only in `analysis_options.yaml` (diagnostics hidden but still analyzed), and notes large analyzed file counts on 8 GB machines. Findings appear in the Problems panel on `pubspec.yaml`; the quick action "Add to dart.analysisExcludedFolders" edits only `.vscode/settings.json` for the folders you select. On by default; turn off with `saropaLints.analyzerExclusions.enabled`.
- **`avoid_reexports`:** new rule (comprehensive tier, INFO) that flags every `export` directive; re-exports hide where a symbol is defined. The package entry point `lib/<package_name>.dart` is exempt. No option to allow re-exports.

### Fixed

- **Security (extension):** `minimatch` forced to `>=11.0.1` via npm `overrides` (Dependabot #44, denial of service via globparts amplification). Resolved version is 11.0.4; `npm audit --omit=dev` reports 0 vulnerabilities.

---

## [17.0.1-beta.7]

False-positive hardening for 15 lint rules; the master switch now stops the language server; scan exits 0 when disabled. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.7/CHANGELOG.md)

### Fixed

- **`avoid_unsafe_collection_methods`:** a `.first`/`.last`/`.single` access is no longer flagged when the same line or the line directly above carries `// non-empty: <reason>` (the reason is required). Use it for lists that are non-empty by an API contract the rule cannot see; a marker with no reason is ignored.
- **`require_timezone_display`:** no longer flags `DateFormat.jm()/Hm()/Hms(...).format(local)` (a time of day shown on the user's own device). Still flagged when the formatted value is visibly UTC (`.toUtc()`, `DateTime.utc`, `isUtc`) and for a stored `DateFormat` that is not formatted at the construction site.
- **`require_ios_push_notification_capability`:** no longer flags `requestPermission()` on non-push receivers (`Geolocator.requestPermission()` and similar location/contacts/audio permission APIs). `requestPermission()` is flagged only when its receiver looks like messaging/notification/push (`FirebaseMessaging.instance`, `messaging`, `fcm`); `getToken`, `onMessage`, and the push class patterns are unchanged.
- **`require_data_encryption`:** no longer flags `StringBuffer.write(...)` / `StringSink.write(...)` (an in-memory hash input, not storage), or a static call whose only sensitive-looking word is the receiver class's own name repeated as a leading qualifier (`SuccessCardGate.write([SuccessCardGate.milestoneKey(id)])`; `Card.write([userCreditCard.number])` is still flagged). Real credentials in the payload are still flagged.
- **Master switch (extension):** turning `saropaLints.enabled` off now also stops the standalone language server, even when its own setting is on, and turning it back on restarts it. Before, the server kept running and its findings stayed in the Problems panel after an "Off" toggle. Starting the server by command while the master switch is off now says why it did not start.
- **`scan` command:** `dart run saropa_lints scan` now prints a "disabled" line and exits 0 when the VS Code extension has turned Lint integration off (plugin block commented out), instead of exiting 2 and failing every pre-commit hook. No action required; the README now has a "How to turn saropa_lints completely off" section.
- **`require_catch_logging`:** no longer flags a typed catch (`on _NoV1Rebuild { return null; }`) when another catch clause of the same `try` logs or rethrows (`on Object catch (e, st) { debugException(e, st); }`). A typed catch whose sibling catches are also silent, a lone typed catch, and an empty typed catch, are still flagged.
- **`prefer_asmap_over_indexed_iteration`:** no longer flags an index loop where the index also addresses a second collection (`a[j] + b[j]`), or where the body adds to / removes from the iterated list (BFS-style `group.addAll(...)`). A single-collection loop, including one that mutates a different list, is still flagged.
- **`avoid_unsafe_collection_methods`:** no longer flags `xs!.first` when the guard is written null-aware on the same collection (`xs?.length == 1 ? xs!.first : null`, `(xs?.isNotEmpty ?? false) ? xs!.first : null`). Also no longer flags `parts.first` where `parts` is a local initialized from `s.split(...)` (always non-empty). A guard on a different collection, or no guard, is still flagged.
- **`avoid_string_substring`:** no longer flags `s.substring(...)` on the right side of `&&` when the left side checks the same string (`s.startsWith('c') && s.substring(1) == 'x'`, `s.length > 3 && ...`) or the slice arguments. A guard on a different string, or no guard, is still flagged.
- **`avoid_return_await_db`:** no longer flags `return await dbWrite(...)` inside the body of a `try` that has a `catch` clause or a `finally` block, where the `await` is required for the handler to see the async error. Returns outside a guarded try body (including inside the `catch` itself) are still flagged.
- **`avoid_retaining_disposed_widgets`:** no longer flags a non-static `Widget` / `State` / `BuildContext` field (or `List` of them) that the same class's `dispose()` assigns `null` (`_ghost = null` / `this._cards = null`). Fields `dispose()` does not clear, and static fields, are still flagged.
- **`avoid_nullable_parameters_with_default_values`:** no longer flags a nullable parameter with a default that the body forwards unchanged as an argument to a callee parameter that is itself nullable (`query(isHidden: isHidden)`); the callee gives `null` its meaning. Forwarding to a non-nullable parameter, or not forwarding directly, is still flagged.
- **`avoid_nullable_parameters_with_default_values`:** no longer flags a nullable parameter with a default when the body resolves `null` with `x ??= fallback` or `x ?? fallback` (null is a distinct input, same as the existing `== null` / `!= null` exemption). Parameters whose body never acts on `null` are still flagged.
- **`avoid_nullable_interpolation`:** no longer flags an interpolation guarded by `x != null &&` on its left (e.g. `uuid != null && list.contains('${uuid}|$code')`), or a null-aware chain off a receiver already checked non-null (`if (x != null) '${x?.map(...).join()}'`). Unguarded interpolations and `||` conditions are still flagged.
- **`avoid_nested_assignments`:** no longer flags the grouping idiom `(map[key] ??= <T>[]).add(item)` (a parenthesized `??=` on a map index used as a call, property or index target). Other nested assignments, including `??=` on plain variables and `=` on an index, are still flagged.
- **`avoid_motion_without_reduce`:** no longer flags `FadeTransition` / `SlideTransition` / `ScaleTransition` / `RotationTransition` inside a class that already reads `disableAnimations` / `accessibleNavigation`, or calls a reduced-motion or `settle` helper to settle the controller (matched as identifiers, so comments and words like `settlement` do not count). Transitions in classes with no such handling, and non-transition widgets, are still flagged.
- **`avoid_forward_slash_path_assumption`:** no longer runs in a Flutter app whose only platform folders are `android/` and/or `ios/` (forward slash is correct there). Apps or packages that can run on Windows are still flagged.
- **`avoid_duplicate_string_elements`:** no longer flags empty strings repeated in a list, lists passed as call or constructor arguments (fixed positional slots), or const lookup tables of 6+ elements indexed by position. Set literals and short plain lists with repeats are still flagged.
- **`avoid_accessing_collections_by_constant_index`:** no longer flags `list[0]` / `list[1]` in a loop when the same list's `length` is checked first, in the left side of `&&`, in an enclosing `if` or ternary, or in an earlier `if (...) continue/break/return/throw;`, and the check implies a non-empty list (`> 0`, `>= n`, `== n`, `!= 0`; or the reverse in an else-branch or early exit). `length == 0` / `length < n` in a then-branch, and accesses with no length check, are still flagged.

---

## [17.0.1-beta.6]

The "large files not excluded from the file watcher" warning no longer appears in workspaces that are not Dart projects, and no longer lists tool-managed folders. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.6/CHANGELOG.md)

### Changed

- **Lints switch (extension):** a single click on the sidebar switch row, or on the status bar tooltip link and menu, no longer turns lints on or off. They open Process Health, which holds the toggles. The `Saropa Lints: Toggle` command and the Lints Config dashboard button are unchanged.
- **Lints switch (extension):** the status bar and sidebar showed "Partly off" when every engine was off but the Scan on Save toggle in Process Health had only suspended the scan daemon. A suspended daemon now counts as the setting being off, so the switch shows "Off".
- **Large-file watcher warning (extension):** the message now names the open folder, says the listed paths are relative to it, shows at most 3 files with sizes or file counts plus "and N more", and explains that VS Code watches every file in the folder for changes and large files can slow it down or crash it. The "Exclude from Watcher" button is unchanged.
- **Status bar hover (extension):** the tooltip is now laid out in sections (Status, Project, Problems, Memory, Actions) with tables, colored pills with hover text, and one link per action. Findings read "18,368 findings (all errors)" or "N errors · M warnings", long numbers have thousands separators, each problem names itself with its own link, and the memory detail is unchanged but tabulated. The toggle label follows the real state, and the two conflicting "not set up" messages are now one.
- **Status bar click (extension):** clicking the status bar item no longer flips Lints on or off. It opens a menu (new command `Saropa Lints: Status Menu`) with the status, problems and actions; the toggle is one row.

### Fixed

- **Large-file watcher warning (extension):** the scan now runs only in Dart/Flutter workspaces, and skips `.claude/worktrees` and `.venv` folders, so web or Python workspaces no longer get warnings about virtual-environment files and media assets. The 5 MB default size bar (`saropaLints.watcherExclude.maxFileKb`) is unchanged.

---

## [17.0.1-beta.5]

The VS Code status bar now shows one Saropa item instead of four, the Lints On/Off state now matches what a click does, and 6 rules and the `init` command no longer report problems that are not there. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.5/CHANGELOG.md)

### Changed

- **Status bar (extension):** the four Saropa status bar items (switch, score, "Saropa: ready/disabled", route and memory/workspace issues) are now one item, e.g. `Saropa Lints: On · 90% · V9/10`, `Saropa Lints: Off`, or `Saropa Lints: Partly off`. It turns to the warning color when lints are Off or Partly off, or when memory or workspace issues need attention. The route (`saropa_lints: pubspec 17.0.1`), memory, health and workspace-issue details moved into its tooltip. Click still flips the Lints On/Off switch; the tooltip links open the report. The scan-on-save item now appears only while a scan is running or has just finished.

### Fixed

- **Lints On/Off switch (extension):** the status bar, sidebar and dashboards now read the saved ownership record, so the displayed state matches what a click does (e.g. after `flutter clean` deletes `.dart_tool`).
- **`init`:** a re-run on a project with the default commented-out plugin block no longer exits 1, no longer claims the extension turned lints off, and no longer warns "0 rules found"; it exits 1 only when the extension recorded turning lints off.
- **`avoid_return_await_db`:** no longer treats `db*` reads such as `dbContactLoadDBListByStatus` as writes (the name `LoadDB` contains `add`). Method names are now matched by camel-case word; `compute`, `calculate` and `check` are now read verbs (`dbContactComputeTotals` no longer lints). `dbContactSave` and `dbContactAddToGroup` still lint.
- **`prefer_freezed_for_data_classes`:** no longer flags data classes in projects that do not depend on `freezed` or `freezed_annotation`, where the suggestion could not be acted on. No action required.
- **`require_catch_logging`:** no longer flags a catch whose only statement returns a constructed typed result (e.g. `return const DecryptResult(DecryptStatus.authFailed)`). `return null;`, `return false;` and empty catches still lint.
- **`avoid_memory_intensive_operations`, `avoid_string_concatenation_loop`:** no longer flag `line += buffer.toString()` where `buffer` is a `StringBuffer` (flushing a buffer into a string).
- **`avoid_platform_channel_on_web`:** no longer flags channel calls after `if (!isSupported) return;` when `isSupported` reads a private flag that is only ever set true after a `kIsWeb`-guarded early exit. A flag assigned with no web guard still lints. The guard flag must be false on web (for example `!kIsWeb && ...`); a flag such as `kIsWeb || ...` and writes through `this._flag = ...` are now handled correctly. An early exit `if (!_canUse) return;` on a getter such as `kIsWeb || ...` no longer counts as a web guard; only a getter that is false on web (`!kIsWeb && ...`) does.

---

## [17.0.1-beta.4]

This update removes false positives from 19 rules, mostly the mounted-check and context rules that flagged code that was already safe. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.4/CHANGELOG.md)

### Fixed

- **`check_mounted_after_async`:** no longer treats an `await` inside an always-returning `if` branch as an await before a later `setState`.
- **`require_mounted_check_after_await`, `require_mounted_check`:** an `await` confined to an always-exiting `if` branch no longer triggers `setState` reports after the `if`.
- **`use_setstate_synchronously`:** await and guard state are now restored after an `if` whose awaits all sit in exiting branches.
- **`avoid_platform_channel_on_web`:** no longer flags calls after `if (field == null) return` (field null on web) or after a negated `Platform.isX` early exit, and is skipped in Flutter projects with no `web/` target.
- **`avoid_inert_animation_value_in_build`:** no longer flags an `animation.value` read in a branch whose sibling branch uses an `AnimatedBuilder` or `ListenableBuilder` on the same animation.
- **`avoid_datetime_constructor`:** no longer flags a `DateTime(...)` assigned to a local and then round-trip validated by an `if` on its `month` or `day` that exits.
- **`avoid_retaining_disposed_widgets`:** no longer flags immutable `const` descriptor classes, render-time delegates (`FlowDelegate`, `CustomPainter` and similar), or widgets that reach `Widget` or `State` through a non-listed Flutter base class.
- **`avoid_storing_context`:** no longer flags a `BuildContext` field on render-time delegates, or a `final` field whose every use follows a `.mounted` check.
- **`avoid_parameter_mutation`:** no longer flags `void`/`bool` functions documented as in-place ("in place"/"mutates") or named with a mutator verb (`apply`, `restore`, `rollback`, `inherit`, `carry`, `merge`, `stamp`, `mark`).
- **`move_variable_closer_to_its_usage`:** no longer flags a state snapshot (call or member-read initializer) taken before intervening `await`s.
- **`prefer_asmap_over_indexed_iteration`:** no longer flags pairwise loops (inner start not 0, or index feeding a nested loop bound).
- **`prefer_static_method`:** no longer flags instance methods of singleton classes (private/factory constructors plus a static self-typed instance).
- **`prefer_try_parse_for_dynamic_data`:** `Uri.parse` of an interpolation made only of `const` references and `Uri.encode*` calls is no longer flagged.
- **`require_apple_signin_nonce`:** no longer reports `getAppleIDCredential(scopes: [])`, which only fetches an authorization code for token revocation.
- **`require_data_encryption`:** no longer reports calls that only clear credential fields with `null` or `Value(null)`.
- **`require_drift_equals_value`:** now resolves the argument type and reports only enums, so `static const String` or int arguments pass.
- **`require_qr_permission_check`:** no longer reports `MobileScanner`, which handles camera permission itself.
- **`require_speech_stop_on_dispose`:** follows same-class and externally declared private helpers called from `dispose()`.

---

## [17.0.1-beta.3]

This update makes the command-line setup report problems honestly instead of finishing as if everything worked. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.3/CHANGELOG.md)

### Added

- **VS Code extension:** one On / Off / Partly off switch for Saropa Lints, in the status bar and at the top of the sidebar. One click turns it on or off. "On" means the setting is on and the analyzer plugin block is live or was never turned off by the extension (a new project's default daemon-only block counts as On, and turning On from there does not load the heavy plugin). "Partly off" shows only when the extension itself turned the block off or the setting and block otherwise disagree; it says which part is off and the same click fixes it.
- **VS Code extension:** a version-sync row in the sidebar that, in one click, syncs the plugin version in `analysis_options.yaml` to the version pinned in `pubspec.lock` when they differ.

### Fixed

- **`dart run saropa_lints:init`:** exits with a failure code when the resulting configuration has no active `plugins:` block or lists no rules, and says so plainly when the VS Code extension turned Lint integration OFF.
- **`dart run saropa_lints:init`:** the stale-version warning now reads the version of the `saropa_lints` plugin entry only (it previously could report an unrelated `version:` such as `true`) and names the command that updates it.
- **`dart run saropa_lints:init`:** the deprecation note no longer implies the extension will undo an OFF state that init cannot undo.
- **VS Code extension:** the Lints Config dashboard shows "Lints are off" with a Turn on (or Fix) button instead of coverage numbers while lints are off or partly off.
- **VS Code extension:** Re-enable In-Process Plugin now also turns the `saropaLints.enabled` setting back on, so the two can no longer disagree.
- **`avoid_async_call_in_sync_function`, `avoid_unawaited_future`, `avoid_uncaught_future_errors`:** no longer report `Map<K, Future<V>>.remove(key)` statements.
- **`avoid_context_across_async`, `avoid_context_after_await_in_static`:** no longer treat an `if` as an await when the await sits only in branches that always return or throw.
- **`avoid_drift_value_null_vs_absent`:** no longer reports `Value<T?>(null)` on a nullable column.
- **`avoid_ignoring_return_values`:** no longer reports `Never`-returning calls, or extension methods whose name contains a mutate verb word (for example `dbActivityAdd`).
- **`avoid_implicitly_nullable_extension_types`:** no longer reports an extension type that implements a non-nullable interface.
- **`avoid_memory_intensive_operations`, `avoid_string_concatenation_loop`:** no longer report `+=` on a String declared inside the same loop.
- **`avoid_nullable_interpolation`:** no longer reports interpolation inside a lazy debug-log closure.
- **`avoid_nullable_parameters_with_default_values`:** no longer reports a parameter the body compares to `null`.
- **`avoid_only_rethrow`:** no longer reports a rethrow-only clause when a later clause in the same `try` also catches the exception.
- **`avoid_parameter_mutation`:** no longer reports `Draft`, `Builder`, `Accumulator`, `Collector` and `Buffer` parameters in `void` functions.
- **`avoid_string_substring`:** recognizes a length guard in a collection-for loop condition.
- **`avoid_unbounded_cache_growth`, `require_cache_expiration`:** treat `field = null` on a Map field as invalidation (wholesale-replaced snapshot caches).
- **`avoid_unsafe_collection_methods`:** recognizes `isNotEmpty && ....first` and `isEmpty || ....first` short-circuit guards.
- **`move_variable_closer_to_its_usage`:** no longer reports a declaration whose initializer contains `await`.
- **`prefer_drift_batch_operations`:** no longer reports `batch.insert` inside a batch callback or `update(...).write`.
- **`prefer_transaction_for_batch`:** counts writes per execution path (exclusive branches) and ignores `StreamController.add` and other sinks.
- **`require_data_encryption`:** no longer matches `card` inside `vcard`.
- **`require_dispose_pattern`:** no longer reports abstract classes with only static members.
- **`require_file_close_in_finally`:** no longer reports `File.openRead` (the stream closes itself).

---

## [17.0.1-beta.2]

The latest release, `17.0.1-beta.2`, focuses entirely on refining existing rules to eliminate false positives in specific code contexts.  Key fixes include recognizing `!context.mounted` guards in static methods, allowing constant or literal interpolations in Drift SQL strings, and properly handling RegExp group matches for dynamic data parsing. It also improves checks for hooks outside build methods, platform channel declarations, and null-safe JSON accesses by better analyzing the surrounding code logic and type guards.[log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.2/CHANGELOG.md)

### Fixed

- **`avoid_context_after_await_in_static`:** no longer reports after a `!context.mounted || ...` guard.
- **`avoid_drift_raw_sql_interpolation`:** no longer reports SQL built only from constant or literal interpolations, including loop variables over a literal list of strings.
- **`avoid_drift_raw_sql_interpolation`:** no longer reports SQL built from a private method's parameter when every caller passes a literal.
- **`avoid_hardcoded_credentials`:** no longer reports a short plain word assigned to a bare `token` name (for example `_unitToken = 'unit'`).
- **`avoid_hooks_outside_build`:** no longer reports static `ClassName.useX(...)` helper calls, and only applies to files that import a hooks package.
- **`avoid_platform_channel_on_web`:** no longer reports channel declarations in field or top-level variable initializers; calls inside closures or methods still report.
- **`avoid_platform_channel_on_web`:** unguarded `invokeMethod`, `invokeListMethod` and `invokeMapMethod` calls on field channels are now reported; calls guarded by `kIsWeb` are skipped.
- **`prefer_try_parse_for_dynamic_data`:** digit group lookups on a RegExp match (`match.group(1)`) are recognized, and inline `RegExp(...).firstMatch(...)` matches are checked.
- **`require_ios_face_id_usage_description`:** no longer reports when the project root cannot be found or when Info.plist is missing, and the plist lookup now works for relative file paths.
- **`require_null_safe_json_access`:** no longer reports casts guarded by an `is` test in a conditional, or after the key was assigned earlier in the same block.
- **`require_unique_iv_per_encryption`:** no longer reports IV size constants (`ivLength`, `ivSize`, and similar) or whose initializer is an integer literal.

---

## [17.0.1-beta.1]

This beta focuses heavily on optimizing the VS Code extension's performance and improving the reliability of its Language Server Protocol (LSP) controls. Key updates include a smarter workspace hazard scan that automatically flags massive files or crowded directories for `watcherExclude`—now with built-in coverage for heavy Android and iOS build outputs—to protect extension host memory. It also overhauls the Health Panel's LSP management so server toggles work predictably without infinite spawn loops, and ensures critical upgrade prompts and detailed status tooltips remain visible even when lint integration is temporarily disabled. [log](https://github.com/saropa/saropa_lints/blob/v17.0.1-beta.1/CHANGELOG.md)

### Added

- **Extension:** the Health Panel "Diagnostic Engines" section now states the recommended setup (LSP Server ON, Scan on Save ON, Live Analysis OFF, CI ON only if you want PRs gated, and the fallback if a rule stops firing under LSP) above the cards and as a short note on each card.
- **Extension:** new settings `saropaLints.watcherExclude.maxFileKb` (default 5120) and `saropaLints.watcherExclude.maxFolderFiles` (default 1000). The workspace hazard scan now flags any file above the size bar and any folder with more direct files than the limit, and offers to add them to `files.watcherExclude`. Rules & Tiers > Automation has a new "Watcher excludes" block with both settings, the count of files, folders and missing recommended excludes affected, and a List control for each.
- **Extension:** the recommended watcher excludes now cover Android/iOS build output (`.gradle`, `android/build`, `android/app/build`, `ios/build`, `ios/Pods`, `ios/.symlinks`, `DerivedData`); the hazard scan no longer descends into `.gradle`, `Pods` and `DerivedData`, and files under `.gradle` are excluded with `**/.gradle/**`.

### Changed

- **Extension:** dev dependencies `serialize-javascript` 7.1.0 → 7.1.4 and `undici` bumped (Dependabot, PR #360). No action required.

### Fixed

- **Extension:** the start-up upgrade offer (for example `^16.x` to 17.0.0) now also runs when Lint integration is Off (`saropaLints.enabled` false); it was skipped exactly in the projects that most needed it. The status bar item and upgrade prompt now also appear when Lint integration is Off.
- **Extension:** the status bar "N workspace issue(s)" item now lists each issue in its tooltip (large unexcluded files, missing watcher exclusions, extension host memory). Before, the tooltip showed only process stats, so the red dot gave no hint of the cause.
- **Extension:** the Health Panel "LSP Server" ON toggle no longer does nothing. The setting defaults to true, so clicking ON while the server was stopped (failed start, or after Kill All) rewrote the same value, fired no change event, and started nothing. The toggle now starts or stops the server directly, and the Health Panel refreshes. A failed start now shows an error message with the reason instead of only logging to the output channel.
- **Extension:** Health Panel "Kill All" and "Restart All" buttons now name their target ("Kill All LSP Server", "Restart LSP Server").
- **Extension:** the `saropaLints.lspServer.start` command and Health Panel "Restart All" no longer start the LSP server when `saropaLints.lspServer.enabled` is off; the start command now offers an Enable button. No action required.
- **Extension:** the LSP client no longer spawns `dart run saropa_lints:lsp_server` when `saropa_lints` is missing from `.dart_tool/package_config.json`; it shows one warning ("run `dart pub get`") instead of restarting 5 times with stacked error toasts.
- **Extension:** the "zero rules enabled" modal no longer reopens in a loop after clicking "Set Up Project". If setup does not fix the config, a single non-modal warning is shown instead.
- **Extension:** the "zero rules enabled" modal no longer appears after Enable when `violations.json` was written by the extension itself (live-diagnostics snapshot with no `enabledRuleCount`), e.g. while Lint integration is Off. A missing count is now treated as unknown, not zero.
- **Tests:** the unwritable-location test in `init_emit_ci_test.dart` no longer uses `skip:` (flagged by `avoid_skipped_tests`). It returns early on Windows instead.

---

## [17.0.0] - published as stable by mistake

Published to pub.dev as a stable release by mistake: it was meant to be a beta. It is not retracted. Use 17.0.1-beta.1 or later, or the next stable release.

Moves saropa_lints to the analyzer 13 and 14 lines and keeps analyzer 12 projects on the frozen 16.x line. [log](https://github.com/saropa/saropa_lints/blob/v17.0.0/CHANGELOG.md)

### Changed

- **Breaking:** saropa_lints now requires Dart `>=3.11.0` (analyzer 13.0.0 depends on `_fe_analyzer_shared` 100, which needs 3.11) and `analyzer >=13.0.0 <15.0.0`, and pub picks the newest allowed by your Dart version (3.11 and 3.12 up to 14.5.0, 3.13 14.6.0); projects held on analyzer 12 stay on `saropa_lints: ^16.7.0`, which is frozen with no back-ports.
- `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended`; update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name.
- Reports on named arguments now highlight only the argument name instead of the whole `name: value` text, so editor squiggles and `// ignore:` placement for those reports shift to the name; no action required.
- Widget rules that match by name no longer match record fields that share a widget's name, which removes false positives; no action required.
- The extension now detects at start-up whether a project uses the pubspec route, the plugin route or both, and shows one prompt offering Migrate when a newer saropa_lints works with the project's Dart. Plugin-only projects (saropa_lints only in `analysis_options.yaml`) get the same offer as pubspec projects.

### Internal

- Extension version now keeps the package's major.minor and maps only the patch (10 x package patch + slot; stable uses slot 9, prerelease N uses slot N-1), so every publish is strictly higher; a 10th prerelease of one patch is refused.

---

## [16.10.0]

Restores installation on Flutter 3.44 and older, and renames one rule whose name matched a core analyzer diagnostic. [log](https://github.com/saropa/saropa_lints/blob/v16.10.0/CHANGELOG.md)

### Fixed

- Projects on Flutter 3.44 and older could not add saropa_lints as a dev dependency from 14.0.3 onward: the `meta ^1.18.3` floor conflicted with the `meta 1.18.0` that those Flutter versions pin. The floor is back to `meta ^1.18.0`. No other dependency changed.

### Changed

- `deprecated_new_in_comment_reference` is now `deprecated_new_in_comment_reference_extended` because the old name matched a core analyzer diagnostic that the analyzer is removing; update any `// ignore:` comments, `ignore_for_file` lines and `analysis_options.yaml` entries that use the old name.

---

## [16.9.0]

A false-positive fix for `avoid_async_in_build`. [log](https://github.com/saropa/saropa_lints/blob/v16.9.0/CHANGELOG.md)

### Fixed

- `avoid_async_in_build` no longer flags an async `build` method in a class that is not a Flutter widget or State (for example a Serverpod `WidgetRoute`). Fixes [#359](https://github.com/saropa/saropa_lints/issues/359).

---

## [16.8.0]

Test-suite repair, dependency security updates, and a linting fix. No change to rule behavior or shipped output. [log](https://github.com/saropa/saropa_lints/blob/v16.8.0/CHANGELOG.md)

### Security (Extension)

- Dependency bumps: undici 8.10.0 → 8.11.2 (clears 8 Dependabot alerts); brace-expansion 5.0.9 → 5.0.12 and source-map-js 1.2.1 → 1.2.2 (clears 4 alerts).
- Dependency bump: shell-quote 1.10.0 → 1.12.0 (clears critical command-injection Dependabot alert 33, fixed in 1.11.0; dev-tooling only via npm-run-all2).

### Fixed

- `audit --baseline` now exits 1 only when a finding is new. It used to exit 1 for every finding, baselined or not, so the action's `baseline` input could never let a gate accept a known backlog. Same contract as `cross_file --baseline` and `project_health --baseline`. With no baseline file, every finding still counts.
- `audit --since` works for a project in a subdirectory of its repository (a monorepo package). The changed-file paths were joined onto the project path twice and matched nothing, so the audit covered no files. An unknown ref now also returns an empty list on git versions that report it as a "bad revision", instead of crashing.
- `init --emit-ci` writes the workflow at the repository root, where GitHub runs workflows from, and adds `working-directory` when the project is in a subdirectory. It honors an explicit `--tier`, and reports a write failure instead of printing a stack trace.
- The composite action trims glob patterns (`lib/gen/**, test/**` no longer yields a pattern with a leading space that matches nothing), accepts one pattern per line, and no longer aborts on an empty pattern. It fetches `since` given as a bare branch name, a branch with slashes or a commit SHA, and names the problem when it is on a remote other than origin. It removes a stale SARIF file before the run, creates the SARIF directory, handles an absolute `sarif-file`, and rejects `resolve` values other than true/false and a `fail-on-count` without its `fail-on`.
- Releases no longer start a second publish run for the moving `v16` tag, which matched the publish workflow's `v*` trigger. Pre-releases leave `v16` on the last stable release, the tag points at the release commit rather than whatever is checked out, and re-running the tag step repairs a `v16` push that failed.
- `extension/scripts/check_l10n_keys.py` key-union regex rewritten to eliminate exponential backtracking (ReDoS vulnerability, code-scanning alert 23).
- `avoid_string_substring` now documents that it cannot prove bounds established inside a helper function it would have to inline; suppress with `// ignore:` at the call site when the helper is bounds-safe.

### Fixed (Extension)

- The CI card writes the workflow at the repository root with `working-directory` for a project in a subdirectory. It was written under the project, where GitHub never runs it.
- Publishing the CI change no longer freezes VS Code while git pushes, and pressing the button again after a failure resumes on the same branch instead of failing at `git checkout -b`. It refuses to publish when `pubspec.yaml` already had uncommitted edits of yours (a commit takes whole files, so they would have been pushed too), when there is nothing to publish, and when a branch of the same name already exists on the remote. Opening the pull request gives up after 15 seconds on a connection that never answers and offers the compare page.
- Adding `saropa_lints` to `pubspec.yaml` keeps valid YAML for a `dev_dependencies:` with a trailing comment, four-space indentation, an existing entry at any indentation, and an empty `{}`. It also adds `^16.2.1` instead of the long-stale `^9.1.0`.
- Turning CI off a second time also suspends a job added since the first time, and toggling to the state the file is already in no longer offers an empty pull request.
- Package Vibrancy's "Generate CI Pipeline" counts only direct and dev dependencies that have a newer version, the same measure its suggested threshold now uses. Transitive packages the project cannot upgrade no longer fail a fresh pipeline. `failOnVulnerability` is enforced from the security advisories `pub outdated` reports, where it used to claim there was no data and pass. The pull request comment shows pass or fail against the threshold, the shell script uses a private temporary directory, and the GitLab job uses the maintained Flutter image.

### Internal

- Restored the scripts package markers and the cross-file, structure and example fixture sources that an earlier bulk commit deleted, which had made the CI `test` job fail.
- Health history no longer labels a point with the wrong tag when two tags (such as `v16` and `v16.6.0`) share a commit.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.
