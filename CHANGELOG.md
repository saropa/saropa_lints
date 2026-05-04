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

    Each release (and [Unreleased]) opens with a short plain-language **overview** for humans — user-facing only, casual wording, 2–4 sentences max. Summarize what changed from the user's point of view; do NOT restate implementation details from the `### Added/Changed/Fixed` sections below. Hard bans in the overview: line numbers, file paths, regex snippets, internal flag names (`multiLine: true`, `requiredPatterns`, etc.), specific counts/percentages from particular projects ("22,695 issues on project X", "96.8% of the backlog"), AST/visitor terminology. If a reader would have to open the code to understand a phrase, it belongs in the detailed section — not the overview. End the overview (no linebreak) with: [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md) substituting X.Y.Z.

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

## [Unreleased]

### Added

- Quick fix coverage extended to ten more rules (Batch 13). Each rule now offers a one-step IDE correction so the lint can be cleared without manual edits — no action required if you already had these rules enabled. The newly-fixable rules are `prefer_raw_strings`, `prefer_period_after_doc`, `format_comment_style`, `prefer_const_border_radius`, `prefer_const_widgets_in_lists`, `avoid_redundant_async_on_load`, `avoid_single_cascade_in_expression_statements`, `avoid_escaping_inner_quotes`, `avoid_types_on_closure_parameters`, and `prefer_expression_body_getters`.

### Fixed (Extension)

- Upgrade-check throttle now lets a newly-published `saropa_lints` version break through the dismiss memory immediately instead of being suppressed for up to 24 hours. The previous gate was a single 24h timer, so a release published the morning after a dismiss stayed invisible until that timer elapsed; the gate is now a 1-hour anti-thrash window combined with a per-version dismiss memory, so a new pub.dev version always re-prompts even within the same day. Legacy state self-heals on the next write — no user action required.

<details><summary>Maintenance</summary>

- Version 13.4.2 was bumped in `pubspec.yaml` but never tagged or published — the v13.4.3 publish run jumped past it. No 13.4.2 artifact exists on pub.dev or the Marketplace; consumers go directly from 13.4.1 to 13.4.3.
- `scripts/modules/_version_changelog.py` now refuses to publish when any `## [X.Y.Z]` section in `CHANGELOG.md` has an empty body — that was the exact shape that caused the rename-collision recovery in `apply_version_and_rename_unreleased` to silently skip 13.4.2 and bump straight to 13.4.3. Authors must now either delete the orphan stub or fill in its release notes before re-running publish.
- `scripts/modules/_rule_metrics.py` now finds nested rule tests under `test/rules/{group}/`, fixing the gap report that falsely listed `widget_patterns_avoid_prefer`, `structure`, `async`, `bloc`, and `performance` as missing. The previous flat `test/*_test.dart` glob saw zero rule-category tests; coverage is now reported correctly (116/116 categories tested, 1095 test calls).
- `scripts/modules/_extract_rule_messages.py` now extracts all 2165 rules instead of producing an empty JSON dump. Two bugs landed when the script was moved into `scripts/modules/`: the flat `glob("*_rules.dart")` only matched the barrel export (zero LintCodes), and the `parent.parent` walk pointed at `scripts/lib/src/rules/` — a non-existent path — so even fixing the glob alone would have returned zero. The CLI body is now guarded by `if __name__ == "__main__":` so importing the module no longer mkdirs `reports/` or writes a JSON file as a side effect.
- Moved release notes for `12.5.2` through `12.6.1` from `CHANGELOG.md` to `CHANGELOG_ARCHIVE.md` so the active changelog stays focused on the current `13.x` series. No action required for package users.
- Added file-level doc headers and per-test WHY comments to four low-coverage test files surfaced by the publish-time comment-coverage scan: `test/integrity/plan_additional_rules_21_30_test.dart`, `test/rules/architecture/compile_time_syntax_rules_test.dart`, `test/rules/core/performance_rules_test.dart`, and `extension/src/test/vibrancy/services/dep-graph.test.ts`. Headers explain the contract under test (registration + tier + fixture invariants for the rule packs; two-output shape for the dep-graph parser) so a future reader can change a rule without first decoding what each `it()` was guarding. No action required — no source, severity, tier, message, or fix changed.

</details>

---

## [13.4.3]

Brings the Findings Dashboard back for projects whose report file was last produced by an older saropa_lints plugin — counts and the findings table agree again, no re-analysis needed. The "no analysis report" notice is also clearer: it spells out which piece of project setup is actually missing (pubspec, dev-dependency, analyzer config, or a top-level `saropa_lints:` key that doesn't enrol the plugin) and offers a one-click Set Up Project action for the common cases. [log](https://github.com/saropa/saropa_lints/blob/v13.4.3/CHANGELOG.md)

### Fixed (Extension)

- Findings Dashboard no longer reads "401 findings" with an empty findings table when `reports/.saropa_lints/violations.json` was written by an older saropa_lints plugin (any version <13.4.x with the legacy `critical/high/medium/low/opinionated` impact vocabulary). The reader now normalizes those values to the current `error/warning/info` buckets so the impact filter matches them. No action required after upgrading. Reported as a follow-up to [#208](https://github.com/saropa/saropa_lints/issues/208).
- The "no analysis report" notification now classifies the cause precisely — missing pubspec.yaml, missing `saropa_lints` dev-dependency, missing `analysis_options.yaml`, malformed YAML in `analysis_options.yaml`, or a bare top-level `saropa_lints:` key that doesn't enrol the plugin — and surfaces a one-click **Set Up Project** button as a modal that explicitly states configuration is required and the dashboard cannot show findings without it. The bare-key case (the issue #208 reporter's exact state) shows the valid `include: package:saropa_lints/tiers/recommended.yaml` line inline so users can hand-fix without losing custom analyzer settings. The "no pubspec.yaml" and "exclude list too aggressive" cases stay non-modal — those need user judgment and Set Up Project would either be premature or clobber their customizations.

---

## [13.4.1]

Fixes a line-number drift in the Issues tree and the violations export where reported lines could land tens of lines away from the actual offending code on larger projects. The number now matches the squiggle in the editor again. Re-run analysis once after upgrading and the tree will refresh. [log](https://github.com/saropa/saropa_lints/blob/v13.4.1/CHANGELOG.md)

### Fixed

- Lint violations now resolve their line number from the AST node's own compilation unit instead of a shared analyzer reference that could go stale between files or between library and part files, so the **Issues tree** and `reports/.saropa_lints/violations.json` no longer drift away from the editor's squiggle on large projects. Reported as [#208](https://github.com/saropa/saropa_lints/issues/208). Re-run analysis once after upgrading to refresh the export.

---

## [13.4.0]

This release brings Saropa's severity counts in line with the Dart analyzer — the dashboards, sidebar, and update toasts now headline the same error / warning / info numbers as the IDE Problems tab, dropping the parallel critical / high / medium / low / opinionated vocabulary. Several rules also quiet down on common false-positive patterns, so a handful of `// ignore:` comments and local workarounds may no longer be needed. Squiggle tooltips read tighter — redundant "this is a critical X risk" sentences are gone. Existing CI thresholds and quality-gate configs keep working through back-compat aliases. [log](https://github.com/saropa/saropa_lints/blob/v13.4.0/CHANGELOG.md)

### Fixed

- `avoid_gradient_in_build` no longer flags `LinearGradient` / `RadialGradient` / `SweepGradient` constructed inside a `ShaderMask.shaderCallback` closure — that closure runs at paint time with `Rect bounds` only available there, so there is no "outside build()" location to hoist the gradient to (and the rule's correction message was impossible to satisfy for any animated `ShaderMask`). Bare gradients in `build()` and gradients nested in build-time `BoxDecoration` still fire as before. No action required — remove any `dart:ui.Gradient.linear` workarounds or local suppressions you added for `ShaderMask` shader callbacks.
- `require_https_only` no longer flags `'http://'` literals used in search or comparison positions — needle argument to `String.startsWith` / `endsWith` / `contains` / `indexOf` / `lastIndexOf` / `split`, or operand of `==` / `!=`. Those literals are patterns being searched for or compared against, not URLs being requested, so flagging them forced rule-author and security-detection code to either reach for `// ignore:` or refactor literal patterns. URL construction (`Uri.parse('http://...')`, hardcoded HTTP endpoints, network-call arguments) still fires correctly. No action required.
- `avoid_ios_hardcoded_status_bar` no longer flags `SizedBox` instances that are clearly icon hitboxes or fixed-size containers — the rule now skips a SizedBox whenever `width` is also set or the `child` is an Icon-like widget (`Icon`, `ImageIcon`, `FaIcon`, `CircularProgressIndicator`, `CupertinoActivityIndicator`, `Image`, or any class whose name ends in `Icon`). Pure vertical spacers (`SizedBox(height: 20|44|47|59)` with no `width` and no Icon child) still lint as before. No action required — remove any local suppressions you added for `SizedBox(width: X, height: X, child: Icon(...))` patterns.
- `require_data_encryption` no longer flags denormalized search-index columns whose Drift-generated field name contains "tokens" (`searchTokens`, `lexerTokens`, `parserTokens`, `wordTokens`, `nGramTokens`, `routeTokens`, `cspTokens`) — these are NLP / parser / routing material derived from public data, not credentials. The same fix retires `auth` substring false positives on `author` / `authority` / `authorship` / `authored` / `authoring` (publishing & governance terms). Real credential identifiers — `authToken`, `apiToken`, `accessToken`, `refreshToken`, `bearerToken`, `jwtToken`, `csrfToken`, `sessionToken`, `oauthToken`, `idToken`, `authorize`, `authorization`, `unauthorized`, `authentication` — still match. No action required — remove any local `tokens` → `searchIndex` renames you added to silence the rule.
- `require_rtl_layout_support` no longer flags `Alignment.topLeft` / `Alignment.topRight` / `Alignment.bottomLeft` / `Alignment.bottomRight` (and `TextAlign.left` / `TextAlign.right`) when they appear as the right-hand side of a switch arm whose pattern is a same-named enum constant (e.g. `AlignmentOption.topLeft => Alignment.topLeft`) — that shape is a physical-corner adapter whose enum API has already committed to physical-direction semantics, and converting to `AlignmentDirectional.*Start/*End` would silently flip the result under RTL. Plain `Alignment.topLeft` references and non-identity arms (e.g. `MyEnum.start => Alignment.topLeft`) still fire. No action required — remove any `// ignore_for_file: require_rtl_layout_support` you added to physical-corner enum mappers.
- `require_unique_iv_per_encryption` no longer flags static fields whose initializers contain the substring `IV.` only inside a string literal (e.g. `static const _fixKind = FixKind('...', 50, 'Use IV.fromSecureRandom(16)')`). The check now walks the AST excluding `StringLiteral` descendants so real IV usage (typed as `IV` or initialized via `IV.x(...)` / `IV(...)`) still flags, but message strings that happen to mention the `IV.` token no longer trigger. No action required.
- `avoid_string_substring` no longer flags `s.substring(N)` calls when an enclosing if-statement or `?:` then-branch already proves the receiver is long enough — by calling `s.startsWith(...)` / `s.endsWith(...)` on the same receiver, or by an explicit `s.length` comparison. Idioms like `s.startsWith('v') ? s.substring(1) : s` and `if (s.startsWith('"') && s.endsWith('"')) s = s.substring(1, s.length - 1)` are safe and now pass cleanly. Unguarded `substring()` calls on strings still fire as before. No action required.
- `require_android_permission_request` no longer flags ambiguous method names (`record`, `startRecording`) when the receiver class name ends in a clearly non-audio suffix (`Tracker`, `Logger`, `Tracer`, `Reporter`, `Metrics`, `Telemetry`, `Stats`). Telemetry/logging idioms like `RuleTimingTracker.record(...)` and `MetricsLogger.record(...)` no longer require permission-request scaffolding. Real audio recorders (`Record`, `AudioRecorder`, `FlutterSoundRecorder`) still flag because their class names don't end in those suffixes. No action required.

### Changed

- **BREAKING:** the `LintImpact` taxonomy collapsed from five buckets (`critical / high / medium / low / opinionated`) to three (`error / warning / info`), matching the Dart analyzer's native severity model. The mapping is `critical → error`, `high + medium → warning`, `low + opinionated → info`. This affects the `violations.json` schema (`v.impact` and `summary.byImpact` now emit `error|warning|info`), `LintImpact.values`, every rule's `impact` getter, the health-score weights (`error: 8, warning: 3, info: 0.25` — was `critical: 8, high: 3, medium: 1, low: 0.25, opinionated: 0.05`), and the `bin/impact_report.dart` CLI labels. Migration: external CI scripts and `saropa_quality_gate.yaml` files keep working — `quality_gate` exposes back-compat aliases (`new_critical_issues` reads `error`, `overall_high_issues` reads `warning`, etc.) so existing thresholds don't need to be rewritten in lockstep with the upgrade. New code should use `new_errors / new_warnings / new_info` (and `overall_*` equivalents). See [`plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md`](plan/COLLAPSE_LINT_IMPACT_TO_SEVERITY.md) for the full rationale.
- Lint problem messages no longer pad themselves with stand-alone "This is a critical X risk/issue/flaw." sentences. The surrounding text already names the specific harm (path traversal exposes sensitive files, missing migrations cause data loss, server-side IAP validation is mandatory, etc.), so squiggle tooltips read tighter and stop double-asserting severity. Eight rules updated: `avoid_path_traversal`, `require_sqflite_error_handling`, `require_dio_ssl_pinning`, `require_database_migration`, `avoid_instantiating_in_bloc_value_provider`, `avoid_webview_file_access`, `avoid_instantiating_in_value_provider`, `avoid_animation_in_build`. No action required.

### Changed (Extension)

- The regression-nudge toast and the all-clear celebration now headline must-fix errors instead of a broader "critical" impact tally — `X errors — view.` and `No errors!` replace `X critical issues — view.` and `No critical issues!`. The number now lines up with the Dart analyzer's native severity (error = must fix, warning = could fail or look bad, info = FYI) so the headline count and the IDE Problems tab agree. No action required.
- The Findings Dashboard now shows three severity-keyed KPI cards — **Errors** / **Warnings** / **Info** — replacing the prior five-card layout that mixed severity (Errors / Warnings) and impact (Critical / High). Card filters and tooltips updated to match. Drops the parallel 5-bucket taxonomy that disagreed with the IDE Problems tab and the analyzer's native severity. No action required.
- The Suggestions sidebar card, File Risk tree counts, Triage view group label, the Health Score walkthrough description, and the Triage walkthrough description now read in the three-severity vocabulary (`error / warning / info`) instead of the old five-tier vocabulary (`critical / high / medium / low / opinionated`). The Essential tier picker description now reads "Security and must-fix errors only" instead of "Security and critical issues only". No action required.

<details><summary>Maintenance</summary>

- Plugin internals under `lib/src/native/` and `lib/src/report/` now share the same self-skip path as `lib/src/rules/` and `lib/src/fixes/`, so detection rules no longer self-fire on telemetry hooks (`RuleTimingTracker.record`), CLI report writers (sync I/O, bare `Platform.is*`), or fix-class string literals (`'Use IV.fromSecureRandom(16)'`). Removes ~30 self-firing diagnostics observed in VS Code, which analyzes opened files directly and bypasses `analyzer.exclude`. No user-visible behavior change.
- `ReportConsolidator` bare `catch` clauses (5 sites: session init, cleanup, stale-session sweep, batch read, directory list) are now `on Object catch (e, st)` to match the `avoid_catch_all` rule's recommended form — fatal VM errors (`OutOfMemoryError`, `StackOverflowError`) propagate instead of being silently logged. No user-visible behavior change.
- Internal dogfooding cleanups: `SaropaContext._timingEnabled` now passes explicit `defaultValue:` arguments to `bool.fromEnvironment` / `String.fromEnvironment` (resolves four `avoid_string_env_parsing` self-hits and makes the off-by-default intent explicit), and the `_LintImpactNumeric.numericValue` switch in `ImportGraphTracker` no longer carries duplicate `LintImpact.warning` / `LintImpact.info` arms (dead copy-paste arms — the enum has only three values, so the second arm of each pair was unreachable). No user-visible behavior change.

</details>

---

## [13.3.2]

`saropa_lints` is installable again on Flutter stable. Versions 12.6.0 through 13.3.1 silently broke `flutter pub add saropa_lints` on every Flutter stable channel because the package required a newer `meta` than Flutter ships — Flutter consumers were stuck on 12.5.x. This release relaxes the analyzer constraint so resolution succeeds. Clicking **Upgrade** on the Saropa Lints update notification no longer locks up VS Code while `pub get` runs, and the progress popup now has a working **Cancel** button. The same fix applies to the **Initialize / Update Analysis Options** command. The **?** keyboard-shortcuts overlay on the editor-area dashboards now closes properly via Esc, the × button, or backdrop-click. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- `flutter pub add saropa_lints` now resolves successfully on Flutter stable. Versions 12.6.0 through 13.3.1 required `analyzer ^12.1.0` (which transitively requires `meta ^1.18.0`), but Flutter stable's SDK pins `meta` at 1.17.0 — so every Flutter consumer hit a resolution failure and was forced to pin to `<= 12.5.3`. The constraint is now `>=9.0.0 <12.0.0`, matching the package's documented compatibility contract. No action required — re-run `flutter pub upgrade saropa_lints` to pick up the fix.

### Fixed (Extension)

- The **Upgrade** button on the saropa_lints update notification, and the **Initialize / Update Analysis Options** command, no longer freeze VS Code while `dart pub get` / `flutter pub get` resolves. Both progress notifications are now cancellable; pressing **Cancel** terminates the underlying child process tree (Windows: via `taskkill /T`). No action required.
- The **keyboard-shortcuts overlay** (`?` key on editor-area dashboards) now actually closes when you press **Esc**, click the **×** button, or click the backdrop. The overlay's `display: flex` style was outranking the `hidden` attribute, so close attempts had no visual effect. No action required.

<details><summary>Maintenance</summary>

- `BaselineManager` no longer trips its own `avoid_catch_all` and `avoid_blocking_main_thread` rules on Flutter consumers — bare catches are now `on Object`, the per-file date-baseline preload uses async I/O, and the sync startup path uses `FileSystemEntity.isFileSync` (semantically tighter; we want files specifically). No user-visible behavior change.
- `BaselineDate` cleared the same `avoid_catch_all` / `avoid_blocking_main_thread` self-flags — three git-blame catch sites now use `on Object catch (e, st)`, and `_findGitRoot` walks ancestor `.git` dirs via async `Directory.exists()` instead of `existsSync()` so it never blocks the analyzer isolate. No user-visible behavior change.
- Plugin entrypoint `lib/saropa_lints.dart` now uses `on Object catch (e, st)` for the version-resolver and analysis-config startup catches, matching the `avoid_catch_all` rule's recommended form. No user-visible behavior change.

</details>

---

## [13.3.0]
This release rolls the keyboard-shortcut overlay out to the remaining editor-area dashboards (Command Catalog, Rule Explain, Telemetry, Comparison, Single-package detail, Package Dashboard), introduces inline match highlighting and recent-search dropdowns on the most-used search fields, and surfaces a partial-fetch banner with a Retry button on the Single-package detail panel when README or version-gap data fails to load. Logical CSS positioning brings the dashboards a step closer to right-to-left readiness. Saropa lint rules now skip files under your package's `bin/` directory so CLI executables you write stop producing Flutter-only print and sync-I/O warnings.

### Fixed

- Saropa rules now skip files directly under your package's `bin/` directory. CLI executables are pure command-line code where `print()` and synchronous I/O are legitimate, so Flutter-only rules like `avoid_print_in_release` and `avoid_blocking_main_thread` no longer flag them. No action required.

### Added (Extension)

- The keyboard-shortcut overlay now ships on every editor-area dashboard. Press `?` on Command Catalog, Rule Explain, Telemetry, Comparison, Single-package detail, or Package Dashboard to see the page-level bindings. The Package Dashboard overlay documents the existing arrow-key / `j` / `k` row navigation, `Enter` / `Space` row expansion, and `Alt + ←` back navigation; Command Catalog adds `/` to refocus the search and `Esc` to clear it. No action required — every dashboard has the same `?` affordance.
- Findings, Known Issues, Package Dashboard, and Command Catalog searches now highlight matched substrings inline. Each match is wrapped in a host-themed highlight that survives Dark+, Light+, and both High Contrast themes; multi-word queries on the Command Catalog highlight every matched token. No action required.
- Findings, Known Issues, and Command Catalog now show a **Recent searches** dropdown when the search field is focused empty. The dropdown lists the last ten searches from the current panel session; click an entry to re-apply it, click the per-row × to remove a single entry, or click *Clear* to drop the whole list. Persistence is in-session for now; cross-session persistence is tracked as follow-up work in `plan/UX_GUIDELINES_REMAINING.md`. No action required.
- The **Single-package detail** panel now renders a partial-fetch banner at the top of the page when README, version-gap PRs and issues, or the reverse dependency count fails to load. The banner names which sections are missing data and offers a single **Retry** button that re-runs the failed fetches; rapid clicks are throttled to one retry every two seconds so the panel can't spam pubdev or GitHub. No action required — the banner self-hides when every fetch is clean.

### Changed (Extension)

- The Findings Dashboard's text filter and the Command Catalog's search field bind their `?` overlay trigger to the same hero slot that already houses the full-width toggle, so the trailing actions of every dashboard line up consistently. No action required.

<details><summary>Maintenance</summary>

- Position-based CSS offsets on dropdowns, popovers, the skip link, and search-clear buttons migrated to the logical `inset-inline-start` / `inset-inline-end` pair so More-actions menus open from the trailing edge in either reading direction. The slider knob in the Lints Config dashboard kept its physical `left` because its on-state animation uses `transform: translateX`; full RTL support for the slider is tracked in `plan/UX_GUIDELINES_REMAINING.md`.
- Tier A polish from `plan/UX_GUIDELINES_REMAINING.md` is complete and recorded against the matching items there. Tiers B / C / D remain earned-scope work and stay in the backlog plan.

</details>

---

## [13.2.0]

This release is an accessibility, theming, and reading-quality pass on the editor-area dashboards. Keyboard users can now skip past the hero and toolbar to land directly on the data, screen readers announce filter and sort state changes through a polite live region, and every dashboard exposes proper landmark navigation. The Findings, Code Health, and Known Issues dashboards pick up a `?` keyboard-shortcut overlay so the affordances they already supported (`/` to focus search, `Esc` to clear) become discoverable instead of secret. Light and High Contrast theme rendering is fixed in places where dark-only color fallbacks were leaking through, the Package Vibrancy donut chart respects the OS *Reduce motion* setting, and several dashboards pick up plural-aware counts so "1 finding" reads naturally. Dashboards also print cleanly via your browser or OS print dialog. [log](https://github.com/saropa/saropa_lints/blob/v13.2.0/CHANGELOG.md)

### Added (Extension)

- Every editor-area dashboard now exposes a **Skip to content** keyboard link as the first focusable element so keyboard users can bypass the hero and toolbar to land directly on the primary data. The link stays hidden until focused, then appears at the top-left for one tab cycle. No action required — press Tab on any dashboard to see it.
- Every editor-area dashboard now reports filter and sort state changes to screen readers through a polite live region. Findings, Code Health, and Known Issues announce visible-row counts on every filter change; Package Comparison announces the package being added when you click an Add button. No action required.
- Every editor-area dashboard now wraps its content in proper landmark regions (header / main / aside) so assistive tech can navigate by section instead of tabbing through every element. No action required.
- Editor-area dashboards now print cleanly via the OS print dialog. The print stylesheet hides toolbars and sticky headers, preserves severity and KPI colors so on-paper severity reads correctly, and prevents table rows from splitting across pages. No action required — print from the dashboard tab as you normally would.
- Findings, Code Health, and Known Issues now expose a **keyboard-shortcut overlay**: press `?` (or click the `?` button next to the full-width toggle) for a popup listing the page-level shortcuts. The overlay also documents `/` to focus the search field and `Esc` to clear a focused, non-empty search — bindings that now work consistently across these three dashboards. No action required.
- Every webview search input now carries a properly-associated label for screen readers. Inputs that previously relied on placeholder text alone (Known Issues, Single-package detail's PR-and-issues filter, Package Dashboard) now announce their purpose to assistive technology even when the placeholder is hidden during typing. No action required — visual appearance is unchanged.

### Fixed (Extension)

- The **Single-package detail** panel renders correctly in Light and High Contrast themes. Previously, several borders and backgrounds carried dark-only color fallbacks that bled through whenever the host's theme tokens were briefly undefined, leaving dark patches visible on light themes. The fallbacks are gone and the host theme is now the only source of color. No action required — switch to Light or High Contrast and reopen the panel.
- The **Package Vibrancy** report's donut chart now respects the OS **Reduce motion** preference. When *Reduce motion* is on, the chart segments render in their final position immediately instead of animating in. The chart shape is identical either way; only the in-flight animation differs. No action required.
- Several dashboards now show grammatically correct counts: *1 finding* / *2 findings* in the Findings Dashboard, *1 function* / *2 functions* in Code Health, *1 dimension ranked* / *2 dimensions ranked* in Package Comparison, *1 total event* / *2 total events* in Related Rule Telemetry. Previously these read awkwardly when the count was 1 because "s" was appended unconditionally. No action required.

<details><summary>Maintenance</summary>

- Foundation work for an internal UX-guideline compliance sweep: shared empty-state, error-banner, print, and reduced-motion CSS primitives lifted into the chrome stylesheet so new dashboards inherit them automatically. Helper modules introduced for centralized number / pluralization / timestamp formatting (so a future internationalization pass becomes a config switch instead of a refactor across N surfaces). Structural-snapshot test harness and token-coverage matrix tool added for tracking visual drift. Layout primitives in the chrome use logical CSS properties so the dashboards are ready for right-to-left locales when that work is scheduled. The Command Catalog panel's main content region id changes from `catalog` to `catalog-main` for skip-link targeting (no impact unless external automation pinned the previous id). The compliance plan and per-surface status table live in `plan/UX_GUIDELINES_COMPLIANCE.md`.
- Per-surface stylesheets now use logical CSS properties (`margin-inline-start` / `margin-inline-end` / `padding-inline-start` / `padding-inline-end` / `border-inline-start` / `border-inline-end`) instead of physical `*-left` / `*-right` directions. Visual layout is identical in left-to-right locales; the dashboards are now closer to right-to-left ready when that work is scheduled. Position-based `left:` / `right:` (absolute / fixed positioning) is intentionally untouched and tracked in `plan/UX_GUIDELINES_REMAINING.md`.
- Backlog plan added at `plan/UX_GUIDELINES_REMAINING.md` covering the deferred guideline work (multi-column sort, multi-select, virtualization, column resize, offline / stale states, theme verification automation, and others), each with a sketch and an explicit *Earn it when* trigger so the items don't drift into "implement everything" scope creep.
- Historical release notes rewritten for readability — older releases were revised in this version to drop code-internal vocabulary (HTML element names, CSS class names, em values, hex codes, internal tier-N button vocabulary) and reframe each bullet around what the user sees. Substance preserved across every entry; only the phrasing changes. Affected releases: 13.1.0 and earlier where applicable.
- Publish script (`scripts/modules/_publish_steps.py`) now treats the mid-publish stale-plugin error as analyze-passed, removing two interactive prompts that previously fired on every release. When `analysis_options.yaml`'s plugin pin matches the local `pubspec.yaml` but is newer than pub.dev's latest (the normal state of a release commit before `dart pub publish` lands), the audit recognizes this as a transient resolution error rather than a real lint failure and proceeds without surfacing the *Fix / Skip* downgrade prompt or the *Ignore / Retry / Abort* failure prompt. The downgrade prompt still appears for genuine drift (pin disagrees with both pubspec and pub.dev). No action for package or extension users.
- Root `analysis_options.yaml` no longer pins the `saropa_lints` plugin to a hard-coded version. The pin used to chase the local `pubspec.yaml` version on every release, which made `dart analyze` fail in this repo whenever the bumped version had not yet propagated to pub.dev. Without the pin the analyzer resolves the plugin from the workspace source itself (the package has no self-dependency in `pubspec.yaml`), so the chicken-and-egg between version bump and publish is gone. Consumer projects regenerating their config via `dart run saropa_lints:init` continue to receive a `version:` pin matching their installed package — only the in-repo dogfood file is affected. No action for package or extension users.

</details>

---

## [13.1.0]

This release polishes the VS Code extension's editor-tab dashboards and side panels so they read as one consistent product instead of a stack of one-off pages. KPI strips collapse cleanly when there is nothing to report, empty states offer a real next-action button instead of staring back blank, secondary buttons step out of overflow menus so the primary action stays obvious, and the Rule Explain, Command Catalog, Related Rule Telemetry, Single-package detail, Package Comparison, and Known Issues panels pick up the same card-style sections and toolbar layout already used on the main dashboards. Two long-standing rendering bugs are also fixed: the Package Vibrancy size-distribution bars now scale to their actual share, and the Command Catalog jump-to-section highlight reliably appears in webview environments where it previously did nothing. [log](https://github.com/saropa/saropa_lints/blob/v13.1.0/CHANGELOG.md)

### Changed (Extension)

- The **Findings Dashboard** title now reads *Saropa Findings Dashboard* in the page heading (previously only the editor tab carried the *Saropa* prefix), and the toolbar's Copy JSON / Save report buttons have moved into the **More actions ▾** overflow menu so the visible action row stays scannable. No action required — both exports remain reachable from the same overflow menu that already housed the rest of the palette.
- The **Findings Dashboard** suppressions list now styles rule names the same way as rule names in the findings table; previously the two surfaces rendered the same data differently, so suppression rows looked pre-highlighted compared to findings rows. No action required.
- The **Code Health Dashboard** KPI strip now suppresses zero-count categories and collapses to a single muted *all clear* line when every category is zero, instead of greeting healthy projects with a row of identical zeros. No action required — categories reappear as their counts grow.
- The **Code Health Dashboard** filtered table now shows an empty-state banner with a *Reset filters* button when search or a flag-card filter narrows it to zero rows, instead of leaving the user staring at an empty table with no cue. No action required — the banner appears and disappears with the filter state.
- The **Code Health Dashboard** gate-failure banner now carries an *Open Code Health settings* button so the user can act on a failing quality gate from inside the banner; previously it offered only explanatory text. No action required.
- The **Rule Explain** panel now uses the same card-style sections as the Findings and Code Health dashboards: each block (Problem / How to fix / OWASP / Related rules / Migration / Documentation) renders as a card with consistent subsection headings, OWASP entries display as a label/value list, and the documentation link appears as a button instead of a plain anchor. The panel also picks up the shared content width cap and full-width toggle, so it reads as part of the same product. No action required.
- The **Rule Explain panel** now omits the *Problem* section entirely when a rule carries no message, instead of advertising a *No message* placeholder card. No action required.
- The **Command Catalog** panel cleans up its toolbar: the search-tokenization hint moves below the toolbar so the toolbar reads as a pure control surface, the *Frequent* tiles render more quietly so toolbar buttons keep visual emphasis, and category-count badges grow a hover/focus outline so the click target is obvious before you commit. No action required.
- The **Related Rule Telemetry** panel right-aligns the Count column so wide numbers stay readable, drops *Refresh* out of the primary-action color (this read-only counter table doesn't have a dominant action), disables *Reset counters* when there's nothing to reset, and replaces the blank counter table with an *Open Findings Dashboard* button when no events have been recorded yet. No action required.
- The **Single-package detail** panel cleans up several rendering gaps. The page heading no longer doubles up the word *Package* (it reads *Saropa http* instead of *Saropa Package: http*), the external-link strip appears only once at the foot of the page (was duplicated under the hero), the gap-summary numbers read as KPIs at proper hero size, the version-gap filter row reads as a quiet segmented control instead of a row of identically-colored buttons, sections have visible card depth, and external links open without underline by default while in-panel links keep underline always so the two are distinguishable. The panel also renders correctly in Light and High Contrast themes — dark-only color fallbacks that bled through on lighter themes have been removed. No action required.
- The **Package Comparison** panel grows a summary row (Leading package, Packages compared, Dimensions ranked) and a toolbar with a *Package Dashboard* button, so the page no longer jumps from hero straight to a bare table. The empty state offers an *Open Package Dashboard* button instead of just explanatory text. Per-row *Add to Project* buttons render as secondary actions so the multiple inline buttons no longer compete with the toolbar for emphasis. No action required.
- The **Known Issues Library** panel now lights up the matching summary card when you click *Has replacement* or *No replacement*, so you can see at a glance which filter is on (the cards were clickable before but didn't visually reflect the active state). It also shows an active-filter strip below the toolbar with [×] buttons to remove individual constraints, and offers a *Reset filters* button when your search or filter narrows the table to zero packages. No action required.

### Fixed (Extension)

- The **Size Distribution** chart in the Package Vibrancy report now draws each bar at a length proportional to its percentage — previously every bar rendered at the full track width regardless of the package's share, making the visualization unreadable. No action required — reopen the report after updating.
- The **Command Catalog** category-jump flash (the brief tint that highlights a section after you click its count badge) now reliably appears in webview environments where CSS `var()` references inside `@keyframes` fail to resolve — the highlight previously did nothing on those builds. No action required.

---

## [13.0.2]

The Top Rules table in the Findings Dashboard now lets you choose between hiding a noisy rule just for yourself or disabling it across the whole project — two buttons per row, side by side, so the commitment is obvious before you click. Hide stays personal and reversible; Disable writes the rule into your project config and re-runs analysis on the spot. [log](https://github.com/saropa/saropa_lints/blob/v13.0.2/CHANGELOG.md)

### Added (Extension)

- Each row in the **Findings Dashboard** Top Rules table now has a **Disable** button next to the existing **Hide** button — Hide is workspace-only (per-user, reversible via Clear Suppressions) while Disable writes the rule to `analysis_options_custom.yaml` so the whole project stops running it (team-shared, persistent, re-runs analysis automatically). No action required — open the Findings Dashboard to use it.

---

## [13.0.1]

The Findings Dashboard gets a Top Rules table that ranks the noisiest rules by count and gives you a one-click Hide button per row, so a screen full of repeated INFO lints stops drowning out the warnings you actually need to see. Behind the scenes the Code Health Dashboard scan no longer stacks parallel processes when you click rescan in quick succession, and every visible label, toast, and Command Catalog entry now uses the on-screen "Code Health" name instead of the older "Project Vibrancy" wording. [log](https://github.com/saropa/saropa_lints/blob/v13.0.1/CHANGELOG.md)

### Added (Extension)

- The **Findings Dashboard** now shows a **Top Rules** triage table above the findings list, ranking the noisiest rules by count with severity and a per-row Hide button so a single click suppresses a rule across the workspace findings (same hide as the Issues tree's "Hide rule", reversible via Clear Suppressions). No action required — open the Findings Dashboard to use it.

### Fixed (Extension)

- The **Code Health Dashboard** scan no longer stacks parallel `dart run` processes when the command fires repeatedly (sidebar item, rescan button, command palette) — concurrent invocations now share one in-flight scan, and the progress notification is cancellable so a runaway scan can be stopped from the toast. No action required.
- Renamed every user-facing **Project Vibrancy** label to **Code Health** so toasts, banners, tooltips, the toolbar settings button, the Settings group title, the README section, and the Command Catalog all match the dashboard panel name. The setting keys (`saropaLints.projectVibrancy.*`) and the underlying CLI executable (`saropa_lints:project_vibrancy`) are unchanged so existing `settings.json` files keep working. The old name still appears once in the LCOV-path setting description as a migration breadcrumb so users searching for "Project Vibrancy" still find it. No action required.
- Moved the **Open Code Health Dashboard** and **Open Code Health Settings** entries in the Command Catalog from the **Package Vibrancy** category to a new **Code Health** category — Code Health scores your own source, Package Vibrancy scores your dependencies, and they should not appear under the same heading.
- Removed two factually wrong claims from the README's Code Health section: the dashboard is an editor tab (not a sidebar webview, which was removed in v13.0.0), and the **Refresh Project Vibrancy Sidebar** command no longer exists. The section now describes the editor-tab dashboard, the KPI-card filters, and the actual ways to launch a scan.

---

## [13.0.0]

This release rebuilds the VS Code extension around a single dashboard look so the **Findings**, **Lints Config**, **Code Health Dashboard**, **Package Dashboard**, **Known Issues**, and **Package Comparison** editor tabs all share the same hero band, status line, KPI cards that double as filters, sticky toolbars, and sortable tables. The Saropa activity bar collapses into one flat **Saropa Lints** sidebar — many duplicate tree views are gone in favor of the editor tabs they were always pointing at, so there is one obvious place to land for each task. A common nullable build-context guard pattern no longer trips the after-await context lints, and a handful of webview, path-resolution, and cache fixes round things out. [log](https://github.com/saropa/saropa_lints/blob/v13.0.0/CHANGELOG.md)

### Added (Extension)

- The **Lints Config** header now carries a coverage gauge (red→amber→green) showing what fraction of the packs detected in your pubspec are actually enabled, so you can tell at a glance whether your config is taking advantage of the available tooling. No action required.
- The **Pack coverage** chart now renders a donut companion next to the existing horizontal-bar list — segments are clickable filters on the same pack contract as the bars, and they cross-highlight when a bar or segment is selected. No action required.
- A **Copy config** toolbar action copies a paste-ready `analysis_options.yaml` snippet (tier + enabled rule packs, sorted) to the clipboard so you can replicate the configuration in another project. No action required.
- The **Code Health Dashboard** now opens with a status line (generated, function count, average score, gate state), an average-score gauge in the header, and KPI cards (Unused, Uncovered, Stub-tested, Suspicious coverage, Test drift) that double as click-to-filter presets on the table. No action required — open *Saropa Lints: Open Code Health Dashboard* to see the new layout.

### Changed (Extension)

- The **Lints Config** editor tab is rebuilt around the gold-standard dashboard pattern: a status line under the title now shows tier, pack coverage, applicable SDK migrations, and analysis freshness instead of marketing copy; KPI cards are clickable preset filters with hero-sized numbers; the tier selector is a real radio segmented control (replacing the read-only chips and the separate *Set tier* toolbar button); the toolbar is a banded sticky strip with one primary *Run analysis* action and a *Enable applicable packs ▾* split-button for the breaking / deprecation variants. No action required — open the **Lints Config** tab to see the new layout.
- The two pack tables (*SDK migration packs* and *Package rule packs*) are merged into one searchable, sortable table with **Type** and **Risk** columns; the table now supports text search, type filter, *Detected only* / *Enabled only* checkboxes, and an active-filter chip strip with per-chip removal and *Clear all*. The *Pack coverage* chart is hidden when no pack is enabled or detected, and its bars now click through to filter the table. The suppressions snapshot, target platforms, and docs links move to a diagnostics band below the table. No action required.
- **Findings**, **Lints Config**, and **Code Health** dashboards now share one visual chrome (header band with status line and gauge, KPI cards as preset filters, banded sticky toolbar with density tiers, segmented filter controls, active-filter chip strip, sortable sticky-header table, bar+donut chart pair). Class names and tokens are unified so a user moving between the three sees the same buttons, fields, and layout grid. No action required.
- Every editor-area dashboard now adopts the gold-standard hero band — **Saropa Package Dashboard**, **Saropa Package Comparison**, **Saropa Known Issues**, **Saropa Package Detail**, **Saropa Rule Explain**, **Saropa Related Rule Telemetry**, and **Saropa Lints — About** all carry a Saropa-prefixed title, version stamp, and a status-line strip of facts (last run, counts, freshness) so each tab telegraphs *what it knows right now* without scrolling. Sidebar webviews and tree views keep their unprefixed labels because the activity bar already supplies the product context. No action required.
- Every editor-area dashboard now constrains content to a readable max-width (~1280px) with a **↔ full-width toggle** in the status line, so panels stay legible on ultrawide monitors but can stretch on demand for wide tables and side-by-side comparisons. The toggle persists per webview session. No action required.
- Severity, impact, and replacement filter toggles render with an inverted visual model: included values stay quiet (the resting state) while excluded values are struck through and faded, so the dashboard greets you with calm chrome at defaults instead of a wall of blue pills, and only shouts when you have actively narrowed the view. The pressed-state vocabulary no longer collides with the **Run analysis** primary button. No action required.
- Tier and footprint-mode toggles (where exactly one option is active at a time) now read more quietly: the active option is marked with a subtle backdrop tint instead of a bright button-colored fill, so it no longer competes with the toolbar's *Run analysis* button for visual priority. The **Lints Config** *Show detected* / *Show enabled* filter uses a related quiet style. No action required.
- The **Saropa Known Issues** library now treats its summary cards as click-to-filter presets (Showing / Total / Has replacement / No replacement) and replaces the binary checkbox with a multi-toggle segmented control, so each card maps to a distinct filter state instead of acting as decoration. No action required.
- The **Saropa Package Comparison** panel moves the recommendation summary below the comparison table — the user's reason for opening the panel is the data, not the synthesis — and the empty-state still leads with the Saropa-prefixed hero so the page identity is visible before content arrives. No action required.
- The **Saropa Related Rule Telemetry** panel adopts the shared toolbar layout, the same empty-state pattern as other dashboards, and a clear button hierarchy (*Refresh*, *Copy JSON*, *Reset counters* with the destructive action visually distinct), so it reads as part of the same product instead of a one-off debug page. No action required.
- The **Saropa Package Dashboard** and **Saropa Command Catalog** hero bands now match the contained, rounded look of the Findings dashboard — replacing the bare top section and the full-width gradient stripe respectively, so all four editor dashboards open with the same visual signature. No action required.
- The **Command Catalog** editor tab is redesigned around the editor-dashboard guidelines so the 156-command list no longer reads as one uniform wall: the marketing subtitle is replaced with a real status line (commands, categories, recent count, internal-hidden), search and the context-menu toggle live in one sticky toolbar band with an inline (×) clear and an active-filter chip strip, the **Recent** strip caps at six chips behind **+N more** above a new usage-ranked **Frequent** band, rows are slimmed to icon + title + one-line description with the command id revealed via a hover-only **copy** affordance and tooltip, category cards lose their borders for sticky uppercase microlabel headers, count badges become click-to-jump anchors that flash the target section, and Up/Down/Home/End navigate visible rows for keyboard-first browsing. No action required.
- The Saropa activity bar now hosts a **single flat sidebar** named **Saropa Lints** instead of the previous **Dashboards** + **Overview & options** split, with no in-panel group headers; editor-tab dashboards, run/discover actions, project status rows, settings toggles, triage groups, and help links all sit at the top level so duplicate copies of **Run analysis**, **Getting Started**, **About**, and **pub.dev** are gone. No action required; if you set `saropaLints.sidebar.showOverview` to `false` it now hides the unified view.
- The **Dashboards** activity-bar hub drops the **Violations tools** row group; the same filter, grouping, suppression, and navigation commands remain on the **Findings Dashboard** tab (toolbar + **More commands**) and in the Command Palette. No config change.
- The **Findings Dashboard** adds **Refresh extension** (full `saropaLints.refresh`: trees, annotations, report-backed views) next to **Refresh from disk**. No config change.
- The Saropa activity bar keeps **Dashboards** and **Overview & options** only; per-section `saropaLints.sidebar.show*` toggles under Overview were removed with the migrated views. **`saropaLints.exportOwaspReport`** is available from the Command Palette when the workspace has violations.
- The five dashboard hub labels drop the **Saropa** prefix (now **Lints Config**, **Package Dashboard**, **Code Health Dashboard**, **Findings Dashboard**, **Command Catalog**) so the activity-bar tree stops reading as "Saropa Saropa Lints …"; editor-tab titles and primary headings keep the **Saropa** prefix so the tabs stay findable in Quick Open, Recent Files, and the editor tab dropdown. No action required.
- Package Vibrancy timestamped JSON, Markdown, and SBOM exports now save under **`<workspace>/reports/`** instead of **`report/`**, matching cross_file CLI defaults and other Saropa on-disk report paths. No action required if you only use extension commands and webviews.
- Automation that consumed **`report/*_saropa_vibrancy.*`** must use **`reports/`**; first-time vibrancy history backfill still scans legacy **`report/`** when importing old timestamped JSON into `.saropa/vibrancy-history.json`.
- The **Dashboards** hub lists editor dashboards only (the extra “Violations sidebar” jump row is removed because that tree no longer exists). No action required.
- The **Findings Dashboard** adds a compact **More commands** row (palette actions for filters, help, vibrancy, config, and **Copy tree JSON**) so shortcuts that lived on the old Violations title bar stay one click away in the editor tab. No action required.
- **Help & resources** retains the full set of menu items after the hub trim so previously-promoted commands stay one click away. No action required.
- The **Findings Dashboard** editor tab now includes **Suppressions (export)** (same breakdown as the violations export summary) and **Issues view hides** (workspace list filters) with actions to clear filters, drill by rule or file, and clear view hides, so you can review suppressions without a separate Violations tree. No action required.
- The **Findings Dashboard** is redesigned around a hero strip (title, version stamp, last-run pill, severity-weighted health gauge), interactive KPI cards that double as preset filters (Errors, Warnings, Critical+High, Files affected, Top rule), an active-filters chip strip with one-click removal, a sortable sticky-header findings table with per-row Copy and group expand/collapse, a Save-report button that writes timestamped JSON under `reports/YYYYMMDD/`, and an overflow **More ▾** menu replacing the flat 14-button palette row; severity/impact mix renders as bars + donut and the card hides entirely when every slot is zero. No action required—filters and existing actions remain in place.
- The **Findings Dashboard** suppressions block drops the inert **By kind** sub-list (clicks did nothing) and inlines the kind breakdown next to the section title, so every visible row is now actionable—rule and file rows still drill into Findings; analyzer / view-hide sections collapse to a one-line muted footer when there is nothing to show. No action required.
- The **Findings Dashboard** TODOs, HACKS, and Drift Advisor sections render in density-first order above empty placeholders so actionable markers stay above the fold; sections with no data collapse to a single muted footer rather than reserving full bordered bands. No action required.
- The **Config Dashboard** shows a read-only **Suppressions (export)** strip (totals and by-kind snapshot from the current report, after the disabled-rule filter) plus **Open Findings Dashboard** for the full breakdown; browse, clear view hides, and drill-down stay on Findings. No action required.
- Package Vibrancy user-facing text now refers to the **activity-bar list**, **Package Dashboard** (editor tab), and **CodeLens** instead of generic “tree view” wording; **Saropa Lints: Open Package Dashboard** is the palette label for `saropaLints.packageVibrancy.showReport` (same command id). No config change.
- **Open Package Vibrancy**, **Open Code Health Dashboard**, and **Open Project Vibrancy Settings** now have toolbar icons, and the **Dashboards** hub title bar includes **Open Package Vibrancy** and **Open Code Health Dashboard** in Dart workspaces so the main vibrancy webviews stay one click away from the activity bar. No config change.
- **Config Dashboard** (rule packs, tiers, charts) opens as an **editor tab** instead of a Saropa sidebar webview so the layout matches a real dashboard width. No action required.
- **Open Config Dashboard** has a toolbar icon on the **Dashboards** hub in Dart workspaces (Overview title unchanged); the `saropaLints.sidebar.showRulePacks` setting is removed because that sidebar section no longer exists—delete the key from settings JSON if you set it explicitly. No other migration.
- **Composite analyzer plugin scaffold** shows an explanatory notification with **Continue** and **Open guide** before the folder prompt so the flow is obvious; **Open guide** opens the composite-plugin documentation in the browser without writing files. No action required.
- Editor-area dashboards (**Package Vibrancy**, **Package Details**, **Telemetry**, **Command Catalog**) now share a consistent pill-shaped button style that contrasts correctly in Light, Dark, and High Contrast themes, so the toolbar buttons read the same across all four dashboards. No action required.
- Improved readability of detail and summary panels in the **Package Vibrancy** report and **Package Details** view: increased the small text size and replaced an over-faded muted-label color with the theme's standard description color, so panels like **Health Score**, summary cards, and gap-table cards meet WCAG contrast in Light, Dark, and High Contrast themes. No action required.
- The **Findings Dashboard** **Severity mix** and **Impact mix** charts hide rows whose count is zero (and show a single muted **No findings.** line when every bucket is empty) so empty tracks no longer pad the chart cards. No action required.
- The **Lints Config** *Rule packs* table and *Disabled rules* block are now collapsible expanders — packs open by default, the (previously wall-of-text) disabled-rules block starts collapsed — so the dashboard reads as two intentional sections instead of one long scroll. No action required.
- The **Lints Config** *Disabled rules* block now ships with a search input and groups rules by their owning rule pack (with a *Tier-only (no pack)* bucket last), so triaging large override lists is one search box instead of an alphabetical scroll. No action required.

### Removed (Extension)

- The **Composite analyzer plugin (scaffold)** row is removed from the Saropa Lints sidebar (both the **Config** tree and the sectioned sidebar) because the action only applies to teams that ship their own custom analyzer rules alongside Saropa, and the term was jargon for the typical user. The action stays available via the command palette (`Saropa Lints: Create Composite Analyzer Plugin (scaffold)`), `Saropa Lints: Show All Commands`, the CLI flag `dart run saropa_lints:init --emit-composite-plugin-scaffold`, and `doc/guides/composite_analyzer_plugin.md`. No action required.
- The palette entry **Saropa Lints: Focus Violations View** (`saropaLints.focusView`) is removed because it did not focus a violations tree and duplicated **Open Overview** behavior; the main Saropa status bar still opens the Overview view via the same underlying focus command. No action unless you referenced `saropaLints.focusView` in keybindings or tasks—use `saropaLints.overview.focus` instead.
- The **Violations** activity-bar tree (`saropaLints.issues`) is **removed from the extension manifest** so lint findings are not hosted in a duplicate sidebar; use the **Findings Dashboard** editor tab and the `$(warning)` status item. The **`saropaLints.sidebar.showIssues`** setting is removed—delete it from JSON if present.
- The **Commands** sidebar webview (`saropaLints.commandCatalogSidebar`) and **`saropaLints.sidebar.showCommandCatalog`** are removed; **Browse All Commands** / **Command Catalog** open the **editor tab** only.
- The Project Vibrancy sidebar view and its refresh command are removed so function-level vibrancy lives only in the editor-area report, which removes duplicate UI and avoids cramped sidebar layouts. Use **Saropa Lints: Open Code Health Dashboard** (Command Palette or Saropa navigation where offered). No config change.
- **Summary**, **Suppressions**, **Suggestions**, **Security Posture**, **File Risk**, **TODOs & Hacks**, **Drift Advisor**, **Package Vibrancy** (dependency tree), and **Package Details** (sidebar webview) are **removed from the Saropa activity bar**; use the **Findings Dashboard**, **Lints Config**, **Package Dashboard**, and Command Palette instead. Delete **`saropaLints.sidebar.showSummary`** through **`saropaLints.sidebar.showDriftAdvisor`** from settings JSON if you set them explicitly—only **`saropaLints.sidebar.showOverview`** remains under Activity bar.

### Fixed

- **`avoid_context_across_async`** and **`avoid_context_after_await_in_static`** no longer report the idiomatic compound nullable guard `context != null && context.mounted ? context : null` (used by extension methods and static helpers that take a `BuildContext?` parameter); both the null-check `context` and the then-branch `context` are now recognized as part of the guard. Remove any temporary `// ignore` workarounds you added for that pattern.

### Fixed (Extension)

- The **Package Dashboard**'s *Active filters:* strip no longer flashes an empty *"Active filters: Clear all"* band when no filters are active — previously a layout race could leave the strip visible at zero height with just the label and the *Clear all* link showing. The strip now stays reliably hidden until you set at least one filter. No action required.
- Reclicking the **Lints Config** entry in the Saropa sidebar when the dashboard tab is already open now moves keyboard focus into the dashboard, instead of leaving focus on the sidebar tree row (which made the reclick feel like a no-op). No action required.
- Header gauges on the **Findings**, **Lints Config**, **Code Health**, and **Package** dashboards now render their arc at the correct level and animate in on first paint, instead of appearing as a tiny dot next to the grade letter. Previously the gauge fill was being suppressed by the dashboard's security settings and only redrew on later score changes, so the very first render of any dashboard looked broken. No action required.
- The **Rescan** button in the Package Vibrancy report now clears the per-package pub.dev cache before scanning, so the report reflects current pub.dev versions instead of silently re-using cached entries within the 24-hour TTL. A new **Saropa: Rescan Packages (Fresh)** command exposes the same behavior from the Command Palette; the existing **Scan Packages** command stays cache-friendly for the file watcher and startup paths. No action required.
- **Dashboards** hub rows no longer show stale **Saropa**-prefixed labels after the quick-actions split (**Full-width tabs**, **Lints Config**, **Package Dashboard**, **Project Dashboard**, and quick-action descriptions without redundant **Saropa** wording); reload the window after upgrading the VSIX or dev build to pick up the tree provider. No config change.
- Opening a file from the Project Vibrancy report now resolves report paths against the workspace root on Windows and mixed path styles, so jump-to-file from a hit works reliably instead of failing on path shape. No action required.
- The **Code Health Dashboard** now invokes `dart run saropa_lints:project_vibrancy` (registered package executable) instead of the source path `bin/project_vibrancy.dart`, so the dashboard works in every consumer workspace instead of failing with *"Could not find file `bin/project_vibrancy.dart`"* outside the saropa_lints repo. No action required.
- Hardened three editor-area panels against script injection from untrusted content: the **Package Details** panel tightens its content-security policy so a malicious package or registry response cannot inject script tags via the panel's HTML, the **About** panel renders unsafe markdown link schemes (`javascript:`, `data:`, `vbscript:`, `file:`) as plain text instead of a clickable link, and the **Rule Explain** panel safely escapes rule names that contain script-terminating sequences. No action required.
- The **About Saropa Lints** panel now indents sub-bullets under their parent in sections like **VS Code Extensions** and **Smart Features**, restoring the parent/child hierarchy that previously collapsed into a flat sibling list and made product descriptions blur into the product names. No action required.

<details><summary>Maintenance</summary>

- VS Code Project Vibrancy scan startup now resolves the Dart executable per platform (`dart.bat` on Windows, `dart` elsewhere) and surfaces the underlying spawn error in the notification when startup fails, which prevents false “Dart SDK missing” messages on Windows PATH setups.
- Added `scripts/run_extension_local.py` to compile `extension/` and launch an Extension Development Host (shared `scripts/modules/_utils` branding, step progress, Node/npm/`dist` checks); see `scripts/README.md`. No action for pub.dev or Marketplace users.
- Recorded the native-plugin quick-fix migration as structurally complete in [`plan/TESTING_AND_RELEASE.md`](plan/TESTING_AND_RELEASE.md) §3 — `lib/` has 0 `extends DartFix` and 221 `extends SaropaFixProducer` files; remaining work is end-to-end verification, not migration.
- Added [`doc/troubleshooting.md`](doc/troubleshooting.md) covering the three IDE-specific failure modes (custom_lint not running, rules absent from Problems panel, missing lightbulb fix), separate from the broader README §Troubleshooting.
- Added a "Supported Versions" note to [`README.md`](README.md) describing the active 12.x line and security-only backport policy for earlier majors.
- `scripts/run_extension_local.py` auto-detect now prefers `code` (VS Code) over `code-insiders` and other VS Code-compatible CLIs, so devs with multiple editors installed get the VS Code Extension Development Host by default; override with `--editor <name>` or `SAROPA_VSCODE_CLI`.
- `scripts/run_extension_local.py` now starts a detached `npm run watch` after compile so `.ts` saves rebuild `dist/extension.js` automatically for the running EDH session — previously the bundle stayed frozen at launch and every code change required re-running the script. Disable with `--no-watch`; logs land in `extension/.watcher.log`.
- Expanded [`plan/guides/UX_UI_GUIDELINES.md`](plan/guides/UX_UI_GUIDELINES.md) with toolbar density tiers, mandatory active-filter chip strip, status-line under H1, button hierarchy beyond primary/secondary, "same row visual = same row contract" rule, and a new §14 anti-pattern catalog (bait-and-switch rows, doubled empty states, placeholder-as-content, flat-toolbar overflow, buried high-value sections, decorative weight without depth, density-first content ordering, inert KPI cards, status-line absence, identical-twin KPI cards) so future surfaces avoid the failure modes that prompted the Findings Dashboard redesign.
- `scripts/modules/_git_ops.py` `_push_with_retry` now prompts the developer to retry or abort on hard push failures (missing remote, auth error, network outage) instead of aborting the whole publish. Empty input defaults to retry so the dev can fix the underlying issue (e.g. re-add `origin`) and press Enter to continue from the same release commit.

</details>

---

## [12.8.3]

This patch release focuses on reducing noisy false positives so everyday Flutter and Dart code reads cleaner in the editor. Common animation flows, validated parsing paths, numeric loop accumulation, parent-data lifecycle field patterns, and guarded render-object parentData casts should now lint the way you expect. No config updates are needed; re-run analysis and you should see fewer distracting reports. [log](https://github.com/saropa/saropa_lints/blob/v12.8.3/CHANGELOG.md)

### Fixed

- **`avoid_redundant_await`** no longer flags `await` on `AnimationController.forward()` and `.reverse()` sequencing calls that return `TickerFuture`, so valid animation orchestration is not misreported as redundant. No action required.
- **`avoid_inert_animation_value_in_build`** no longer reports `Animation.value` reads inside child widget `build()` methods when that child is instantiated from a listening builder callback (for example `AnimatedBuilder`), so tick-driven subtrees are not misclassified as inert snapshots. No action required.
- **`prefer_try_parse_for_dynamic_data`** now skips `parse(...)` calls when the input is provably safe (valid numeric literals and digit-only regex-validated captures/substrings), so common validated parsing paths are no longer false positives. Remove any temporary local suppressions you added for those patterns.
- **`avoid_memory_intensive_operations`** now reports loop `+=` only when the operation is on strings, so numeric accumulation patterns no longer produce false positives. No action required.
- **`avoid_unassigned_late_fields`** no longer reports `late` fields declared on RenderObject parent-data classes (types in the `ParentData` inheritance chain), so lifecycle-initialized layout fields are not misclassified as unassigned. No action required.
- **`avoid_unsafe_cast`** no longer flags guarded `RenderObject.parentData` casts to `*ParentData` types when the enclosing class safely initializes that parent data shape in `setupParentData(...)`, so valid render-object parent-data workflows are not misclassified as unsafe casts. No action required.

---

## [12.8.2]

The VS Code extension now registers the **Suppressions** sidebar at startup, so you should see fewer “view not registered” glitches after an update or a full window reload. **avoid_redundant_await** also stops mis-flagging `await` on some third-party async builder-style APIs. No config change. [log](https://github.com/saropa/saropa_lints/blob/v12.8.2/CHANGELOG.md)

### Fixed

- **`avoid_redundant_await`** no longer flags `await` when the expression’s static type is a class that implements `Future` or `Stream` (e.g. Postgrest/Supabase builder APIs) instead of the plain `Future<…>` type, so legitimate awaits are not misreported as redundant. Remove any temporary `// ignore` workarounds you added for that pattern.
- **`avoid_inert_animation_value_in_build`** no longer reports `Animation.value` reads inside child widget `build()` methods when that child is instantiated from a listening builder callback (for example `AnimatedBuilder`), so tick-driven subtrees are not misclassified as inert snapshots. No action required.

### Fixed (Extension)

- The **Suppressions** tree binds at activation like other first-class sidebar trees, which avoids intermittent registration failures for that view. No action required; if a one-off error persists from an older session, use **Developer: Reload Window**.

<details><summary>Maintenance</summary>

- Tag-publish and CI analyze jobs run nested `dart pub get` (discovered under `packages/`, with the same retries as the root install) before `dart analyze` so nested packages resolve on fresh checkouts. No action for pub.dev or extension users.

</details>

---

## [12.8.0]

Cross-file and snapshot loading forgive bad JSON or YAML on disk, so one broken l10n file should not take down a whole run. Many rules now offer IDE quick fixes where a mechanical edit is safe, and you can cap which cumulative tier runs with an environment variable or plugin config if you do not want to hand-edit huge rule lists. A handful of rules were renamed for clarity, and exports plus the extension **Issues** view prioritize and label findings a bit more helpfully—re-run analysis if you rely on `violations.json`. [log](https://github.com/saropa/saropa_lints/blob/v12.8.0/CHANGELOG.md)

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

Package Vibrancy and cross-file analysis get proper extension UI and several new CLI modes, metadata-rich exports make related rules and triage easier, and security hotspots plus suppressions are more workable end-to-end. This is a big extension-focused drop—update the VS Code side if you use those panels or vibrancy. Most Dart-only users still just upgrade the package and re-run analysis. [log](https://github.com/saropa/saropa_lints/blob/v12.7.0/CHANGELOG.md)

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
- Rule execution profiling now records actual callback timing and exposes a stable JSON contract (`ruleName`, `totalMs`, `callCount`, `avgMs` per rule), so CI can detect performance regressions without parsing human-formatted logs. No action required unless you are consuming timing data, in which case switch to the JSON payload.
- Diagnostic statistics now support per-rule threshold gates and baseline-diff reporting in both the analysis report and `violations.json`, so CI can fail on targeted rule regressions and track newly introduced violations without custom parsers. To adopt this workflow, generate a baseline with `dart run saropa_lints:diagnostic_baseline` and reference it under `diagnostic_statistics.baseline.file` in `analysis_options_custom.yaml`.
- Project Vibrancy scoring no longer crashes when LCOV coverage is missing or unreadable, when the on-disk vibrancy cache file is corrupt, or when individual `git log` / `git blame` / `git hash-object` calls fail for a single file. The scan reports a short diagnostic and degrades gracefully (zero coverage, empty cache, missing timestamps) instead of aborting the whole run. No action required.

<details>
<summary>Maintenance</summary>

- Discussion #59 (custom suppression prefixes) is now explicitly deferred as policy-blocked in its discussion document, so contributors do not accidentally implement plugin-side custom ignore parsing under current project policy. No action required for package users.
- Added a dedicated `diagnostic-baseline-strict` GitHub Actions workflow for maintainers to fail fast when `violations.json` is missing before baseline refresh, so strict baseline regeneration can be run independently without changing default CI behavior. No action required for package users.
- Added a dedicated Project Vibrancy GitHub Actions workflow that emits a JSON artifact on pull requests that touch Project Vibrancy sources (see workflow `paths:` filters) and on `workflow_dispatch` manual runs, so maintainers can inspect code-health snapshots from CI without running the CLI locally. No action required for package users.
- Added sidebar UI-state regression checks for Project Vibrancy scope badge/count and persisted filter wiring, so future extension refactors are less likely to silently break the primary filtering flow. No action required for package users.
- Removed many tautological `isNotNull` expectations on guaranteed-non-null rule metadata strings in package tests (CI already enforces stub integrity), preserving rule instantiation, fixture checks, and substantive assertions such as fix metadata and AST-backed tests. No action required for pub.dev or Marketplace users.

</details>

---

## [12.6.1] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 12.6.1.

