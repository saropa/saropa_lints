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

   **Unreleased convention** — While work is in progress, the top section MUST be headed `## [X.Y.Z] — Unreleased`. Put all new entries in this ONE section: never create a second unreleased section or bump the version. The publish script strips ` — Unreleased` (and typo variants like ` - Unreleased`) via `_strip_unreleased_suffix()`. `pubspec.yaml` and `package.json` stay at the LAST PUBLISHED version until the publish script updates them. After publishing, manually add a new `## [X.Y.Z] — Unreleased` section for the next cycle.

   **Tagged changelog** — Published versions use git tag `vx.y.z`, and each section ends its summary with `[log](url)` pointing to that tag's snapshot. Compare against [current `main`](https://github.com/saropa/saropa-lints/blob/main/CHANGELOG.md).

   **Published version** — `"version": "x.y.z"` in [package.json](./package.json).

   **CI** — [actions](https://github.com/saropa/saropa_lints/actions). **Score** — [pub.dev score](https://pub.dev/packages/saropa_lints/score).

-->

---

## [16.4.0] — Unreleased

Minor release adding a new essential-tier rule that catches an unguarded `dart:developer` `debugger()` call before it can hang a test run. It also fixes the extension's CI switch for workflows whose jobs already carry their own conditions.

### Added

`guard_debugger_against_test_environment` flags any `debugger()` call not lexically guarded against the test environment. A VM service attaches during `flutter test` too, so an unguarded call pauses the isolate and hangs the run with no verdict — `kDebugMode` does not help, since `flutter test` itself runs in debug mode. Guard it with a condition mentioning an `isTestEnvironment`-shaped check or `FLUTTER_TEST`, anywhere up the enclosing `if` chain. The negated `if` (`if (!isTestEnvironment) { … }`), the inverted branch (`if (isTestEnvironment) { } else { … }`) and the early-return guard clause (`if (isTestEnvironment) return;`) all count. `&&` and `||` are not interchangeable: one guarded term guards an `&&`, but every term of an `||` must guarantee non-test, so `if (isBreak || !isTestEnvironment)` is still reported. No action required unless the rule fires.

### Fixed

- `prefer_utc_for_storage` no longer flags `.toIso8601String()`/epoch calls on a `final` local variable whose initializer is already UTC — directly, through a `.add()`/`.subtract()` call on a UTC value, or when the variable is read inside a nested closure — even though the receiver's own source at the call site has no `.toUtc()`/`.utc` text. `.toUtc().toLocal()` is now correctly still reported, on the receiver itself or through a local variable, since `.toLocal()` undoes the UTC conversion. No action required.
- `always_specify_parameter_names` no longer flags calls to Dart SDK (`dart:*`) methods such as `String.substring` — their positional-only parameter lists can never be changed by any caller, so the rule's own suggestion was always inapplicable there. No action required.
- `avoid_case_sensitive_path_comparison` no longer flags:
  - a path comparison on `.uri`, `.requestedUri`, or `.url` of a `dart:io` `HttpRequest` or package:shelf `Request` — an HTTP route path, not a filesystem path
  - the root-walk idiom when the `.parent` hop is held in a `final` local before the comparison

  Filesystem URIs, plain `Uri` parameters, and reassigned locals are still reported. No action required.
- `avoid_duplicate_string_literals` and `avoid_duplicate_string_literals_pair` no longer flag a URI repeated across `import`/`export`/`part` directives — Dart requires a directive URI to be a string literal, so there is no legal way to deduplicate it. No action required.
- `avoid_misused_set_literals` now flags an empty `{}` only when nothing gives it a type. It is no longer flagged when its position already supplies a `Map`/`Set` type, or when it initializes a declaration with an explicit `Map` annotation. `var x = {}` — genuinely ambiguous — is still reported. No action required.
- `avoid_stack_trace_in_production`:
  - It now recognizes a debug guard reached through a `final` local or a zero-argument helper, `!bool.fromEnvironment('dart.vm.product')`, and `kDebugMode == true`-style comparisons.
  - Behavior change: `&&`/`||`/`!` are now evaluated soundly, so a condition such as `if (verbose || kDebugMode)`, which the old text match silenced, is now reported. No action required unless a condition like this was previously silent for you, in which case it was never soundly guarded.
- `avoid_throw_in_catch_block` no longer flags `throw Error.throwWithStackTrace(...)`, including a `core.`-prefixed call and in the unresolved CLI scan pass. No action required.
- `avoid_unused_assignment` no longer flags a closure-captured variable's reset that the closure's own next invocation reads back. No action required.
- `function_always_returns_null` no longer flags null-only members in the web-side stub of a `dart.library.io`/`.ffi` conditional import — a null-only body there is the documented contract, mirrored by the native sibling file. No action required.
- `move_variable_closer_to_its_usage` no longer suggests moving an `await`-initialized declaration inside a `try` block that has a `catch`/`finally` — moving it could let an intervening statement's side effects run before the possible throw instead of after. No action required.
- `prefer_cached_getter` no longer flags repeated `.length`/`.isEmpty`/`.isNotEmpty`/`.first`/`.last` reads on a `List`, `String`, `Set`, or `Map`, or an unoverridden `.hashCode`. A lazy `Iterable` (for example a `.where(...)` result) is still reported, since those accessors are not O(1) there. No action required.
- `prefer_typed_route_params` no longer flags a parameter passed into a call whose resolved return type is `int`, `double`, or `num` (for example `parseLimit(...)`), regardless of the call's own name. No action required.
- `require_data_encryption` no longer flags auth-status metadata (`authStatusFields`, `authConfigured`, `authScheme`, `authRequired`/`authRequiredMessage`) as a credential. A real credential in the same call is still reported. No action required.
- `require_error_logging` no longer flags a catch block that propagates the error via `return Error.throwWithStackTrace(...)` or a bare call to it. No action required.
- `require_yield_after_db_write` and `suggest_yield_after_db_read` no longer fire in packages that do not depend on Flutter — their premise, protecting a UI thread, does not apply there. No action required.

### Added (Extension)

- Package Vibrancy now checks what an upgrade would break before recommending it, and replaces the upgrade nudge with the reason when dependents cap the package below the new version or the new version needs a newer dependency than your Flutter SDK pins (for example `analyzer` 13, which needs a newer `meta` than Flutter stable ships) or needs a dependency that is itself held back (for example a `drift_dev` release that requires `analyzer` 13). Blocked packages are also skipped by "upgrade all". No action required.

### Fixed (Extension)

- Package Vibrancy's known-issues data now marks `cubit`, `shared_preferences_ios`, `url_strategy` and `integration_test` as end of life, no longer flags eight revived packages (such as `alice` and `rubber`), and stops flagging current `flutter_secure_storage` versions for a pre-5.0 problem. No action required.
- The Analysis Optimizer's git-based scan now also covers Dart code inside git submodules and nested repositories. No action required.
- The nested-package warning is now translated into all supported languages. No action required.
- The Analysis Optimizer now lists Dart files through git in one pass when the project is a git repository, so scans are faster, ignored files never count, and the 50,000-file cap no longer applies there. Projects without git keep the previous scan. No action required.
- The System Health panel warns when a Dart project contains git-ignored nested package roots, which the analysis server treats as separate contexts, and offers a one-click exclude or a per-folder dismiss. No action required.
- The Analysis Optimizer now lists nested Dart package contexts as a high-priority exclusion row, and its scan honors `files.exclude` and `.gitignore`. No action required.
- The Analysis Optimizer's scan now detects `StatelessWidget` and `StatefulWidget` classes as widgets. No action required.
- The Package Dashboard no longer shows a white page with unreadable dark text under dark themes; the Feature Inventory tab's browser-only colors were overriding the editor theme. No action required.
- The System Health panel now tracks Dart processes and memory on macOS and Linux instead of only Windows, whatever the system language. No action required.
- The Analysis Optimizer now skips dot-folders such as agent worktree copies, which the Dart analyzer never analyzes, so they no longer inflate costs or crowd out real files, and a scan that hits its file cap now says the results are partial. No action required.
- The file-watcher exclude audit now suggests excluding agent worktree copies when a workspace has any, and dismissing the audit hides only the patterns shown, so a new suggestion can still appear once. Accept the prompt to add the exclusion.
- Turning CI off in the System Health panel no longer breaks a workflow whose job already has its own `if:` condition. It used to add a second `if:`, which GitHub rejects as an invalid workflow. The existing condition is now swapped for `if: false` and put back exactly when CI is turned on again. A workflow with a job it cannot safely switch off is left untouched, and the panel reports that CI is still running.
- Turning CI off no longer misses a job's own `if:` when a comment sits above it at 0-2 spaces of indent. The body scan stopped at the comment, so the `if:` further down was never found, and a second `if: false` was inserted before it — the same duplicate-key failure the previous fix was meant to prevent.
- `buildCiWorkflow`'s dartdoc had been merged into `ciNeedsExplicitTier`'s by a missing blank line, so `--emit-ci`'s workflow-generating function carried no documentation. Restored to the function it describes; no behavior change.
- The CI card and `init --emit-ci` write identical workflow files again. Their header and comments had drifted apart.

### Internal

- Added `scripts/pubdev_snapshot.py`, which downloads the latest pub.dev data for every tracked package into a reusable snapshot and refreshes the Package Vibrancy known-issues data from it; the analyzer entries now record why analyzer 13 and later is held back.
- Test descriptions for the shared CI workflow fixture checks now state the expected behavior, satisfying `require_test_description_convention`.
- `CHANGELOG_ARCHIVE.md` (11k+ lines) split into one file per major.minor line under `changelog/archive/` (e.g. `15.2.x.md`); the old file is now a short index. Every release entry is preserved (plus 10.12.0–12.2.1, recovered from git history where an earlier trim had deleted them without archiving) and stays greppable with `grep -r <term> changelog/archive/`. `scripts/split_changelog_archive.py` regenerates the split and index; `compact_changelog_archive.py` and the rule-version-history scan now read the directory, and `changelog/` is excluded from the pub.dev package.

## [16.3.0]

Minor release adding a GitHub Actions integration: a composite action, a CLI flag that writes the workflow for you, and a switch in the extension that turns it on and off. [log](https://github.com/saropa/saropa_lints/blob/v16.3.0/CHANGELOG.md)

### Added

A composite GitHub Action at the repository root runs saropa_lints against a project's pull requests. Reference it as `saropa/saropa_lints@v16`, which now tracks the latest 16.x. `mode` decides what a finding does — `annotate` posts SARIF to the pull request diff, `gate` fails the build, `both` does each. `command` decides which rules produce one — `scan` honors the project's own `analysis_options.yaml`, `audit` runs every rule regardless of configured tier, and `auto` picks per mode. An analysis that could not run fails the job in every mode, so a green check always means it actually ran.

`dart run saropa_lints:init --emit-ci` writes `.github/workflows/saropa-lints.yml` into a project, pinned to the saropa_lints version doing the generating. It refuses to overwrite an existing file, so a re-run cannot discard workflow edits a team has made.

### Added (Extension)

- A **GitHub Actions CI** card in the System Health panel turns CI on and off for the project. ON adds the dependency if missing and writes the workflow; OFF adds one `if: false` line per job rather than deleting the file, so the change is reversible and any customization survives. Neither direction commits anything on its own — the file governs every contributor's pull requests, so it goes through normal review.
- The generated workflow runs the `scan` command, which honors the project's configured tier and per-rule choices rather than reporting all 2332 rules, and carries `continue-on-error` so it reports without failing pull requests. Removing that line makes it enforce.
- Both directions of that switch offer to open a pull request for the change, since nothing reaches CI until it is on the default branch. It is a deliberate step, never automatic: the panel shows the exact git commands it would run, beside a copy button, and cuts no branch until the button is pressed. Only the workflow file is ever staged, the branch is always new and the push is never forced, and a failure names the step that failed and leaves the commands valid to finish by hand.

### Fixed (Extension)

- The Diagnostic Engines section of the System Health panel is no longer hidden when `saropaLints.debug.enabled` is off. These controls decide whether analysis runs at all, and one of them turns off a project's CI.
- Package Vibrancy's "Generate CI Pipeline" produced workflows that always passed: thresholds were printed but never compared, and the generated checker was invoked in a way that never executed it. The generated workflow now compares against `maxOutdated` and fails the job when it is breached. Thresholds that `pub outdated` carries no data for are now stated as unenforceable rather than silently ignored.

---

## [16.2.2] — Unreleased

Patch release correcting follow-on defects in the rule and dashboard changes that shipped in 16.2.1, and fixing how several rules read their project configuration from `analysis_options_custom.yaml`. Two lint rules stopped short of the cases they were meant to cover, three rules could silently pick up settings written under an unrelated section of your config file, and the Config Dashboard could sit on a stale view after you flipped a toggle. [log](https://github.com/saropa/saropa_lints/blob/v16.2.2/CHANGELOG.md)

### Fixed

`google_sign_in_auth_token_from_authenticate` no longer flags `.accessToken` reads on a nullable authorization result — the exact shape v7's scope-authorization call returns — so correctly migrated code is left alone. No action required.

`prefer_late_final` no longer flags a `late` field whose assigning method is captured as a tear-off in a field initializer; the 16.2.1 fix covered only tear-offs written inside a method or constructor body, so taking the suggestion could still produce a late-initialization error at run time. No action required.

`avoid_ignoring_return_values` now reads `safe_to_ignore:` only from its own section of `analysis_options_custom.yaml` instead of silently adopting a same-named list from an unrelated section further down the file. No action required unless a stray allowlist was being picked up, in which case move those names into the rule's own section.

`banned_usage` now reads its banned-identifier list only from its own section of `analysis_options_custom.yaml`, instead of adopting a same-named list from an unrelated section further down the file or appending that section's items to its own. No action required unless stray bans were being picked up, in which case move those identifiers into the rule's own section.

`always_specify_parameter_names` now reads its allowlist only from its own section of `analysis_options_custom.yaml`, with the same fix for adopted and appended entries. No action required unless a stray allowlist was being picked up, in which case move those entries into the rule's own section.

### Fixed (Extension)

- The Config Dashboard now redraws as soon as you toggle a rule pack, enable a rule, or pick a dropdown value, instead of showing "Update pending" until you click somewhere else — only in-progress text entry defers a refresh now.

### Internal

- Section bounding for the line-based config readers is now a single directly tested helper, adopted by all three readers.
- The Flutter SDK contract lookup behind `avoid_public_members_in_states` is computed on demand, so a `State` class with no public overridden members no longer pays for element resolution and a supertype walk.

---

## [16.2.1]

Patch release fixing false positives in two lint rules, adding a project-level allowlist for `avoid_ignoring_return_values`, and resolving unwanted reload behavior in the Config and Findings Dashboards when editing text fields. [log](https://github.com/saropa/saropa_lints/blob/v16.2.1/CHANGELOG.md)

### Added

`avoid_ignoring_return_values` now supports a project-level allowlist via `analysis_options_custom.yaml` — add method names under `avoid_ignoring_return_values: safe_to_ignore:` to exempt project-specific methods whose return values are safely ignored. No action required unless you have project-specific methods you want to allowlist.

### Fixed

`google_sign_in_auth_token_from_authenticate` no longer flags `.accessToken` reads on already-migrated `GoogleSignInClientAuthorization` results or unrelated model classes with a same-named field. No action required.

`avoid_public_members_in_states` no longer flags `WidgetsBindingObserver`/`RouteAware`/`AutomaticKeepAliveClientMixin` callback methods (e.g. `didChangeAppLifecycleState`, `didPushNext`, `wantKeepAlive`) on a `State` class that carries the interface via `with` or `implements` — their public spelling is mandated by the framework, so the rule's own suggested private-rename fix would have silently broken dispatch. No action required.

`prefer_late_final` no longer flags a `late` field whose assigning method is passed elsewhere as a bare tear-off (e.g. `setState(_initFutures)`) — the tear-off's runtime call count can't be bounded from the declaration site, so the field may genuinely be reassigned even though only one direct call site is visible in the AST. No action required.

`avoid_ignoring_return_values` no longer flags a project-local `extension` method whose name follows a mutate-verb convention (`add*`, `append*`, `insert*`, `remove*`, `update*`, `set*`) and returns `bool` — the same structural shape as allowlisted stdlib mutators like `List.add`, where the bool is a "did it happen" convenience the caller is not required to consult. No action required.

`require_ios_accessibility_large_text` no longer flags `TextStyle(fontSize:)` when the value comes from a non-const getter, method call, or property access — only bare numeric literals and const identifiers are flagged. Previously the rule pattern-matched source text for `textScaleFactor`/`textScaler`/`MediaQuery` substrings and missed any design-system token that applies Dynamic Type scaling through a helper. No action required.

### Fixed (Extension)

- The Config Dashboard and Findings Dashboard no longer constantly reload while you type into a search box or text field — a background refresh (triggered by the analyzer's live diagnostics, config-file saves, or workspace tree updates) was rebuilding the whole panel on every tick regardless of whether you were mid-edit, which also made the Config Dashboard's "Matching rules" → "in `<package>`" links appear dead since the panel they lived in kept getting torn down. Both dashboards now wait until you leave the field before redrawing.
- The Config Dashboard's collapsible sections (packs, disabled rules, shed rules, style & opinions) now remember whether you left them open or closed, the same way the Findings Dashboard's sections already did.

---

## [16.2.0]

The audit command now gives you complete visibility into suppressed warnings across your codebase, revealing exactly what is being silenced in your project. A new diagnostic flags unbounded images that waste memory, while the extension introduces robust workspace hazard scans and a fully collapsible Findings Dashboard. [log](https://github.com/saropa/saropa_lints/blob/v16.2.0/CHANGELOG.md)

### Added

The audit command now gives you complete visibility into suppressed warnings across your codebase. You can optionally expose findings previously hidden by ignore directives or baseline files to understand exactly what is being silenced in your project. [log](https://github.com/saropa/saropa_lints/blob/v16.2.0/CHANGELOG.md)

New rule `avoid_unbounded_image_in_full_bleed_container`: flags an `Image`/`Image.asset`/`Image.network`/`Image.memory`/`Image.file` with no `width`/`height`/`cacheWidth`/`cacheHeight` sitting inside a full-bleed ancestor (`Positioned.fill`, `SizedBox.expand`, or a `Stack` with `fit: StackFit.expand`) — the image decodes at native resolution and is then stretched to fill an arbitrarily large parent, wasting decode memory. Skips false positives where a nearer `SizedBox`/`Container`/`ConstrainedBox`/`AspectRatio` already constrains the image's own size.

### Added (Extension)

- New file-watcher exclusion audit checks the workspace's `files.watcherExclude` setting on activation and recommends missing patterns for heap dumps, build output, and tooling caches that can crash VS Code when tracked. "Add All" writes them into workspace settings in one click; "Dismiss" suppresses the prompt permanently for that workspace.
- Extension host process memory monitoring: the ProcessMonitor now samples the Node.js extension host RSS and heap on each poll, with trend tracking and a configurable warning threshold (`extensionHostWarningGB`, default 1 GB) that surfaces in the status bar — the blind spot behind the 2026-09-05 crash.
- Workspace hazard scan: on activation, scans for dangerously large files (heap dumps, oversized logs, any file >100 MB) not excluded from the file watcher. Warns with a one-click action to add `files.watcherExclude` patterns. Disable via `saropaLints.systemHealth.workspaceHazardScan`.
- Workspace readiness indicator: combines hazard scan, watcher exclude audit, and extension host memory into a single status bar signal with a `saropaLints.showWorkspaceReadiness` command that opens an actionable quick-pick listing each issue.
- Every top-level section of the Findings Dashboard (Overview KPIs, Charts, TODO/HACK, Drift Advisor, Suppressions, Top Rules, Findings) is now individually collapsible via a native disclosure triangle. Each section remembers its open/closed state per workspace, and a collapsed section still shows its counter so you know how many items are inside without expanding it.
- Unified every counter on the Findings Dashboard (chart totals, section headers, TODO/HACK counts, and the big KPI stat-card numbers) onto the same pill component already used by the status-line pills, for one consistent counter look across the page. Severity colors are unchanged.
- "Include suppressed" checkbox in the Findings Dashboard toolbar (visible only in audit mode) passes the new `--include-suppressed` CLI flag through the UI — check it, run audit, and suppressed violations appear in the findings table with an orange "Suppressed" pill badge. No config files are touched.
- New "Copy everything as JSON" and "Save everything report" items in the More-actions menu (audit mode only) export the raw, unfiltered audit result — bypassing all dashboard filters and including suppressed findings — so you can get a true everything-export without manually clearing filters first.
- New "Suppressed Findings" collapsible section appears in the dashboard when audit mode has `--include-suppressed` active and there are suppressed violations. Groups findings by suppression kind (ignore, ignore_for_file, baseline) with a mini table and per-row "Unsuppress" button (currently shows a hint — full comment-removal is planned).
- New "Suppress all visible" bulk action in the Findings Dashboard's More-actions menu inserts `// ignore: <rule>` above every finding currently shown in the table, in one confirmed, all-or-nothing edit across every affected file. Disabled when there are no findings to suppress.
- New extension-native check flags a `bugs/*.md` report marked Fixed, Closed, or Declined that is still sitting in `bugs/` instead of being archived to `plans/history/`, as a Problems-panel hint on the report's `Status:` line. No action required — this only surfaces reports that were left un-archived.
- New extension-native check (mirror image of the above) flags a markdown file filed under the configured archive directory (default `plans/history/`) that still reads as open work — an open `Status:`/`Severity:` field or an unaddressed action-items heading — as a Problems-panel hint suggesting it be moved to the open-issues directory instead. Archive glob, open-issues directory, and the open/closed signal patterns are all configurable via `saropaLints.docPlacement.*` settings; disable with `saropaLints.docPlacement.enabled`.

### Fixed (Extension)

- Drift Advisor integration now supports authenticated servers via a new `saropaLints.driftAdvisor.authToken` setting, with matching guidance states in both the tree view (linking to Settings) and the Findings Dashboard status pill when a token is missing or was rejected by the server.

- Fixed Code Health dashboard KPI tiles silently losing their semantic color coding (red/amber/info) after the pill-unification refactor — `kpiCard()` was missing the `.pill` class that the updated CSS selectors require.

- Fixed silent status bar disappearance when `updateAllStatusBars` throws (e.g. corrupted `workspaceState` after a VS Code hard crash). The bar now catches errors, shows a visible `$(error) Saropa Lints: Error` state with an error-themed background, and logs to the output channel so the failure is discoverable.

### Internal

- Converted the workspace hazard scan's recursive directory walk from synchronous `fs.readdirSync`/`fs.statSync` to async `fs.promises.readdir`/`fs.promises.stat`, preventing the extension host thread from blocking on large workspaces. Subdirectory walks and file stat calls now fan out concurrently via `Promise.all`.
- Extracted duplicate watcher-exclude merge logic (read config, spread, set keys, write at workspace level) from both `workspaceHazardScan.ts` and `watcherExcludeAudit.ts` into a shared `mergeWatcherExcludes` helper in `watcherExcludeHelpers.ts`.
- Added a guard around the watcher-exclude audit's `workspaceState.get` call so a corrupted workspace state after a VS Code crash does not prevent the audit from running.
- Fixed extension version scheme so stable releases supersede their betas on Marketplace and Open VSX. Stable versions now bump minor to the next even above the prerelease odd minor (e.g. `16.2.x` > `16.1.x`).
- Documented the split between Dart AST rules (`lib/src/rules/`, scoped to resolved `.dart` files) and ad hoc extension-native checks (`extension/src/`, full workspace file access, own `DiagnosticCollection` each, not yet surfaced in the web report) in `bugs/ISSUE_REPORT_GUIDE.md`, so non-Dart-file issues are routed correctly instead of being misfiled as out of scope. No action required.

---

## [16.0.1]

Adds a "What's New" panel that surfaces on activation, flagging the v16 diagnostic engine change (LSP server replacing the Analyzer Plugin), the new machine health monitoring, and the sidebar redesign — with a one-click revert to the previous engine. [log](https://github.com/saropa/saropa_lints/blob/v16.0.1/CHANGELOG.md)

### Added (Extension)

- New "What's New" panel opens on activation, summarizing the v16 diagnostic engine change (Analyzer Plugin → LSP server, on by default), the new machine health monitoring, and the sidebar redesign — with one-click actions including reverting to the Analyzer Plugin, plus a live rule-count stat strip and a discovery grid linking straight into the Findings, Package, and Rules & Tiers dashboards. The panel keeps reappearing on every activation until you scroll through it and uncheck "Show this next time"; reopen it anytime from the Command Palette or Help Hub ("Saropa Lints: What's New"). No action required unless your diagnostics look different after this upgrade, in which case the panel's revert button restores the previous engine.

### Added (Lint Rules)

- New `always_specify_parameter_names` rule (Professional tier) flags call sites passing 2+ consecutive positional arguments of the same or confusable type (e.g. two Strings, int+double), where named arguments could prevent silent swap bugs. Allowlists idiomatic Dart/Flutter constructors like `Offset(dx, dy)` (matched by declaring library, so a project's own same-named class is never silently exempted); add project-specific allowlist entries under `always_specify_parameter_names: allowlist:` in `analysis_options_custom.yaml`.

### Fixed (Lint Rules)

- Fixed `avoid_unbounded_dependency` false positive in Melos/pub-workspace monorepos where a dependency with `any` constraint is paired with a `path:` entry in `dependency_overrides:`. The `any` is inert in that case because pub resolves via the local path, not the loose constraint. Only `path:` overrides suppress the lint; `git:` and `hosted:` overrides do not.

### Improved (Extension)

- "Run analysis" now reads live VS Code diagnostics instead of spawning a cold `dart analyze` subprocess, completing in milliseconds instead of tens of seconds on large projects. The three analysis paths (full workspace, per-file, and post-config-change) all use the live diagnostic stream. The data written to `violations.json` is structurally identical to what the Problems panel shows, eliminating stale-data divergence between runs.

### Internal

- Fixed the publish workflow authenticating to pub.dev with a stale OIDC token. `setup-dart` mints the credential once, right after SDK install; Analyze plus the full test suite then run for 9-10 minutes before the publish step, long enough for the short-lived token to expire and be rejected as `Invalid JWT token: invalid timestamps`. This had been misdiagnosed twice (beta.6, beta.9) as a transient pub.dev outage. `setup-dart` now re-runs immediately before `dart pub publish` so the token is minted at the point of use.
- Bumped GitHub Actions across all workflows to Node.js 24-compatible major versions (`actions/checkout` v4→v5, `actions/setup-python` v5→v6, `actions/setup-node` v4→v5 with runtime bumped to Node 22, `actions/upload-artifact` v4→v5, `actions/github-script` v7→v8), resolving the Node.js 20 deprecation warning on GitHub-hosted runners.

---

## [16.0.0-beta.9]

Activation is now resilient — commands register and the sidebar warns on failure instead of going blank. The Findings Dashboard absorbs the full-project audit as a scope selector and gains severity coloring, clickable file paths and rule names, a filter-aware page limit, and JSON export. Sidebar rows show live counts, and per-file analysis no longer blocks the extension host. Publish-pipeline fixes stop the i18n audit from launching Ollama and the local pub.dev fallback from flooding the terminal. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.9/CHANGELOG.md)


### Fixed (Extension)

- Fixed "command not found" errors for dashboard and config commands when unrelated activation setup threw an error. The 80-command registration block now always executes regardless of whether earlier setup (providers, watchers, LSP) succeeded or failed. No action required.
- When activation setup fails, the sidebar now shows a warning banner ("Activation Error — Check Extension Host log for details") instead of empty panels. No action required.
- Fixed "Prune ignores" crashing the Flutter daemon on Windows by spawning `dart` directly instead of via a `cmd.exe` wrapper, eliminating process-tree complexity that competed for SDK resources. All `dart` CLI invocations now use direct spawn; `flutter` (a `.bat` wrapper) retains the shell path, and an ENOENT fallback retries with a shell for legacy SDK installs. No action required.
- Fixed per-file analysis (`runAnalysisForFiles`) blocking the extension host with a synchronous `spawnSync` call for the entire `dart analyze` duration. Converted to the async `runInWorkspaceAsync` variant that the full-workspace analysis already uses, keeping the event loop responsive and adding a Cancel button to the progress notification. No action required.
- "Run Analysis" now reads live VS Code diagnostics instantly instead of spawning a `dart analyze` subprocess. Completes in milliseconds instead of tens of seconds. The zero-violations case now shows a confirmation message instead of silent completion. Config-change rescans use an event-driven freshness gate instead of a fixed delay. No action required.
- Sidebar dashboard rows now show live counts instead of static labels — Findings Dashboard shows violation count and health score, Package Dashboard shows how many packages have features to adopt, and the activity bar badge now reflects only lint violations. No action required.
- Findings Dashboard sidebar row now shows "updated Ns ago" once live diagnostics have changed at least once this session, so a stale-looking count can be told apart from a genuinely fresh one at a glance. The freshness timestamp now only updates for `.dart` file diagnostics, not unrelated file types, and the row's icon switches from a warning triangle to a clock once the timestamp is over an hour old, so an aging count no longer reads as an up-to-date warning. No action required.

### Improved (Extension)

- Full Audit is now a "Source" scope selector inside the Findings Dashboard toolbar (Live diagnostics / Full project / Changed vs main / Changed vs branch) instead of a separate sidebar entry that opened a VS Code quick-pick menu and a second report panel. Progress and results render in the same dashboard you already have open, the chosen scope is remembered across sessions, and a legacy `saropa_lints` version's audit output normalizes to the current severity vocabulary the same way the batch report already did.
- Audit report: severity is now color-coded — error rows get a red left border, warning rows amber, and severity pills/chips use tinted text for quick scanning.
- Audit report: all counts use thousands separators (e.g. 151,919 instead of 151919) for readability.
- Audit report: filter chip counts use a consistent badge style instead of bare parenthesized numbers.
- Audit report: removed the duplicate read-only KPI chip strip — the interactive filter chips already show the same counts.
- Audit report: the 500-row page limit now applies after filtering, not before. The pagination note clarifies this.
- Audit report: added "Export JSON" button that saves the full diagnostics to a user-chosen file.
- Audit report: file paths are visually clickable (link color + underline on hover) and now jump to the diagnostic line instead of just opening the file.
- Audit report: rule names are clickable — clicking one filters the table to show only findings for that rule, with a dismissible banner.
- Audit report: when errors or warnings exist, INFO findings are hidden by default so actionable findings are immediately visible. Click the INFO chip to show them.
- Audit report: a severity summary bar below the header shows the error/warning/info ratio as colored segments with tooltips. No action required.
- Audit report: clicking a file path now jumps to the exact column, not just the line. No action required.

### Internal

- Sidebar data is now computed once per refresh cycle (`prepareRefreshCycle`) instead of being cleared and rebuilt by each provider independently. Eliminates redundant `readVisibleLiveViolations` + `computeLiveHealthScore` calls when multiple sidebar sections refresh together.
- Fixed i18n audit (`--mode audit`) probing Ollama engine availability via `low_quality_entries()`, which self-provisioned the daemon and pulled the model — an expensive, risky side effect during a read-only coverage check. Audit now uses `audit_only=True` to scan cache provenance tags without any subprocess calls. No action required.
- Fixed `dart pub publish --force` (local fallback) printing its full file-tree listing to stdout, flooding the terminal and pushing prior publish-step output out of the scrollback buffer. Output is now captured; only the pub.dev confirmation line is surfaced. No action required.
- Added manual translations to `dictionaries.py` for 5 gaps across 4 locales (ar, de, fil, pt) that MT engines did not translate: RSS warning description, "Dev Tool Budget", "Set Cap", "Translation Engine (Ollama)". No action required.
- Added `COGNATES` approval list to `dictionaries.py` for words that are spelled identically in specific target languages (e.g. "Source" in French). Previously each cognate needed a per-locale `"X": "X"` passthrough scattered across the file; the centralized list merges them at import time, with locale-code validation (typos raise `ValueError`), empty/duplicate-locale guards, drift detection (`--fail-on-drift`), and a `--check-cognates` flag (now in the publish pipeline) that catches conflicts and DO_NOT_TRANSLATE redundancies. No action required.

---

## [16.0.0-beta.8]

🌍 **Milestone: 25 languages, 2,319 translated fields** — extension ships in 25 locales (Arabic, Bengali, Chinese, Dutch, English, Farsi, Filipino, French, German, Hebrew, Hindi, Indonesian, Italian, Japanese, Korean, Polish, Portuguese, Russian, Spanish, Swahili, Thai, Turkish, Ukrainian, Urdu, Vietnamese).

Fixed a sidebar action that could crash on a project's first scan or run twice on rapid clicks, and shortened several sidebar labels. System Health now monitors the whole machine — not just saropa_lints' own processes — with proactive warnings and one-click fixes. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.8/CHANGELOG.md)

### Added (Extension)

- Machine-wide health monitoring: system RAM, every Dart analysis server, Flutter daemon, and Ollama/llama-server process grouped by category with contextual recommendations and one-click actions (restart server, set heap cap, reclaim orphans, unload model). Accessible from the sidebar and command palette. No action required.
- Dev Tool Budget indicator: a single percentage showing how much of the machine's RAM dev tools consume versus a configurable target (`saropaLints.systemHealth.devToolBudgetPercent`, default 60%). Warns when dev tools exceed the budget. No action required.
- Proactive warnings when free RAM drops below a configurable threshold (`saropaLints.systemHealth.systemMemoryWarningPercent`, default 15%) or any single analysis server exceeds a configurable size (`saropaLints.systemHealth.analysisServerWarningGB`, default 4 GB), plus a one-time session-start check. System-wide free RAM now appears in the status bar tooltip. No action required.

### Fixed (Extension)

- Fixed "Fix stale ignores" sidebar action crashing with ENOENT when the `reports/.saropa_lints/` directory does not yet exist (e.g. first run on a project). The directory is now created before the scan CLI writes its JSON output. No action required.
- Fixed all stale-ignore commands allowing concurrent execution when double-clicked or triggered in rapid succession, which could launch duplicate CLI processes. A busy guard now shows a brief status-bar message and drops the duplicate click. No action required.

### Changed (Extension)

- Shortened sidebar action labels: "Fix stale ignores" → "Prune ignores", "Initialize / Update config" → "Update config". Descriptions now carry the detail the labels shed. No action required.

### Internal

- Extracted `createBusyGuard` to `commandGuards.ts` as a reusable concurrency guard with visible status-bar feedback, replacing four identical inline busy-flag patterns in the stale-ignore commands. No action required.
- Routed the three sidebar Actions labels ("Run analysis", "Prune ignores", "Update config") through `l10n()` with new `sidebar.actions.*` keys in `en.json`, closing an i18n gap where two of the three labels were hardcoded English. No action required.
- Hardened Machine Health dashboard: Windows-only platform guard with localized message, narrow viewport wrapping/scrolling, two-tier query/notification throttle (2 min / 10 min) to reduce unnecessary PowerShell shell-outs, undefined-arg guard on Unload Ollama Model command. No action required.
- System memory warning now honors the user's configured threshold directly instead of silently clamping to a 20% minimum at session start. No action required.

---

## [16.0.0-beta.7]

Process Health now tracks only saropa-owned memory, so other VS Code windows no longer trigger false alerts. The tooltip adds a trend arrow, sparkline chart, and early leak detection. Also fixes the dashboard's "Enable all recommended packs" button showing stale results. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.7/CHANGELOG.md)

### Added

- New rule `add_resolution_workspace` (recommended tier, WARNING): flags a package listed in a Dart pub workspace that is missing `resolution: workspace` in its pubspec.yaml, catching version drift before `pub get` fails. Quick fix inserts the key after the `environment:` block. No action required.
- New rule `flag_missing_workspace_member` (recommended tier, INFO): flags a workspace root whose subdirectories contain pubspec.yaml files not listed in the `workspace:` list, catching packages that silently resolve independently instead of joining the shared lockfile. Scans up to 3 levels deep, skips listed members' children (no example/ false positives). No action required.
- New rule `workspace_dependency_version_sync` (recommended tier, INFO): flags a workspace whose member packages declare different version constraints for the same dependency, catching version drift that produces misleading pubspecs since all members share one lockfile. No action required.
- New rule `workspace_member_order` (recommended tier, INFO): flags a workspace root whose `workspace:` list entries are not in alphabetical order, making large workspaces easier to scan and reducing merge conflicts from unordered insertions. No action required.
- New rule `prefer_publish_to_none` (recommended tier, INFO): flags a pubspec.yaml that has no `publish_to` field and appears to be an application (missing homepage/repository metadata), guarding against accidental `dart pub publish` to pub.dev. Quick fix inserts `publish_to: none` after `description:` (or after `name:` if there is no description). No action required.
- New rule `avoid_dependency_overrides` (recommended tier, WARNING): flags any non-empty `dependency_overrides:` section in pubspec.yaml, which silently diverges the resolved dependency graph from declared constraints and masks real conflicts. No action required.
- New rule `prefer_pinned_version_syntax` (stylistic tier, INFO): flags caret-range version constraints (`^X.Y.Z`) in app pubspecs (`publish_to: none`), suggesting exact pins for reproducible builds. Conflicting pair with `prefer_caret_constraint_in_app` — opt-in only. No action required.
- Process Health tooltip now shows an RSS trend arrow (↑ rising / → stable / ↓ falling) next to the saropa section header. A rising trend is an early memory-leak warning before the red threshold trips. Based on a 5-sample split-mean with a 10% change threshold. No action required.
- Process Health tooltip includes a Unicode sparkline chart (▁▂▃▄▅▆▇█) showing saropa RSS over the last ~30 minutes. Gives a visual memory profile at a glance without opening a panel. No action required.
- Process Health now detects monotonically rising RSS and shows a one-time "possible memory leak" notification before the red threshold trips. Based on 8/10 consecutive non-decreasing comparisons, tolerating brief GC dips. No action required.

### Fixed

- Fixed Process Health status bar falsely attributing system-wide Dart memory to saropa_lints. The red/yellow thresholds now evaluate saropa-owned process RSS only (scan daemon, CLI scans), not the aggregate of all Dart processes. A 12GB analysis server from another VS Code window no longer makes the saropa_lints indicator go red.
- Process Health tooltip now shows a per-process breakdown: saropa-owned processes first (with health check), Flutter daemons, then other Dart processes as informational. Top 3 processes per category listed by RSS. Hints when multiple analysis servers are detected.
- Fixed "Enable all recommended packs" button showing "no applicable rule packs detected" while the dashboard table correctly showed 87 detected packs. The button now uses `getDetectedPackIds`, a shared helper that both the table and the button call, so the two surfaces can never diverge. No action required.

### Internal

- Hardened `add_resolution_workspace` quick fix: re-verifies `resolution: workspace` absence before inserting (guards against stale diagnostics and batch "fix all" duplicates), added trailing-newline guard when inserting after the environment block, and tolerates blank lines inside the environment block. The detection regex now also accepts quoted forms (`"workspace"` / `'workspace'`).
- Hardened `flag_missing_workspace_member` scan: deduplicated path-normalization logic into a shared public helper, extended case-insensitive path comparison to macOS (default APFS), and made the `build/` directory skip case-insensitive.
- Extracted `findDivergentDependencyConstraints` from `workspace_dependency_version_sync` into the pubspec constraint parser, creating a pure-function seam for unit testing and removing an unreachable block-dep guard that the parser already handles.
- Hardened Process Health tooltip: process labels truncated at 30 chars for width safety, analysis server detection broadened with `--protocol=lsp` for future binary rename resilience, ✓/↑ conflict resolved (rising trend suppresses the healthy checkmark to avoid mixed signals), and partition assertion added to catch filter coupling drift.
- Expanded RSS history ring buffer from 5 to 30 samples for sparkline rendering while preserving trend computation on the most recent 5.
- Added monotonic growth detector as a pure function with 8/10 threshold — fires a one-time informational toast directing the user to the health panel.
- Hardened sparkline renderer to use reduce loops instead of spread for stack safety, and ProcessMonitor returns a defensive copy of the RSS history buffer.
- Added `classifyProcess()` as a discriminated union (`ProcessCategory` + label) replacing the duplicated predicate chains across tooltip, snapshot, and label functions. Boolean predicates (`isSaropaProcess`, `isDaemonProcess`, `isAnalysisServerProcess`) now delegate to it, and the tooltip builder uses a single-pass partition instead of three independent filter passes with a runtime assertion.
- Fixed leak detection "Open Health Panel" button silently no-oping because it called unregistered command `showHealthPanel` instead of the registered `showProcessHealth`.
- Added 45 tests total in the systemHealth suite (90 passing): `classifyProcess` discriminated union (8), process partition mutual exclusivity (3), marker substring containment invariant (1), plus the existing `processLabel` (9), `isAnalysisServerProcess` (4), `truncateLabel` (5), RSS trend boundary (2), `renderSparkline` (6), `detectMonotonicGrowth` (7).
- Extracted `getDetectedPackIds` in `rulePackDefinitions.ts` as the single source of truth for pack applicability. The dashboard table and "Enable all" button both call it instead of inlining `isPackDetected` filters independently.
- Replaced the collapsed HTML Maintenance expander changelog convention with a `### Internal` heading, enforced by a pre-commit hook and a publish-time gate. No action required.

---

## [16.0.0-beta.6]

Fixes a false positive in the l10n diagnostic provider and catches more CI-only test failures locally before publishing. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.6/CHANGELOG.md)

### Fixed

- Fixed the l10n diagnostic provider (`saropa-l10n`) reporting false-positive "expects params but none passed" warnings when `l10n()` receives its params via a variable or expression instead of an inline object literal. The parser now recognizes non-literal second arguments and skips static key extraction for them. No action required.
- Fixed the l10n diagnostic silently accepting `l10n('key', undefined)` and `l10n('key', null)` without warning when the template expects params. These keyword arguments are now correctly treated as "no params passed." No action required.

### Internal

- Introduced a branded `OpaqueParams` type for the l10n parser sentinel, preventing accidental use of the sentinel string in key-extraction functions at compile time.
- Extracted `extractBalancedBrace` as a shared export from `l10nParsers.ts`, deduplicating the brace-matching loop previously inlined in `extractParamsBlock`.
- Added missing `usesTypeResolution` override to `AvoidCaseSensitivePathComparisonRule` (uses `staticType`).
- Added 4 missing codes to the `flutter_skill_lints` migration pack that moved from TODO/PARTIAL to HAVE.
- Publish script: `create_git_tag` now prompts before moving a stale remote tag to HEAD on retry instead of hard-failing.
- Publish script: `_find_workflow_run` skips already-failed runs so retry doesn't re-attach to old workflows.
- Publish script: delta test pass now includes integrity and config test suites when rule/config files change, catching cross-cutting failures locally instead of deferring to CI.

---

## [16.0.0-beta.5]

Hardens memory safety and scan reliability across the extension and CLI. Memory pressure detection now attributes usage correctly, preventing false pauses on large projects, and a stalled scan on save can no longer disable the feature for the session. Also fixes false positives in timer-lifecycle and manifest rules, and adds orphaned-process detection at startup. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.5/CHANGELOG.md)

### Added

- Memory debug mode: set `SAROPA_LINTS_DEBUG_MEMORY=1` to log per-cache size breakdowns on every periodic memory trend line. Helps diagnose which plugin caches are growing when investigating memory pressure. No action required.
- Orphaned process check: finds model host and Dart processes left behind by earlier sessions, reports how much memory they hold, and offers to reclaim them after you confirm. Runs once shortly after startup and is also available from the Process Health panel and the command palette. No action required.
- New `saropaLints.scanOnSave.timeoutSeconds` setting (default 180, range 30 to 1800) caps how long a single scan on save may run before it is abandoned. Raise it on very large projects if scans are cut short. No action required.
- Diagnostic triage script: `python scripts/triage_scan.py` post-processes `--format json` scan output into five priority buckets (errors → bulk fixes → individual triage → dev code → forked code), replacing manual categorization of bulk lint sweeps. Supports `--suppress-dirs`, `--dev-dirs`, `--bulk-threshold`, and `--format json` for machine-readable output. No action required.

### Fixed

- Fixed stale diagnostics persisting in the Problems panel after adding `// ignore:` directives or fixing code. The scan CLI now honors `// ignore:` and `// ignore_for_file:` directives, and "Restart Analysis Server" now also clears scan-on-save diagnostics and rescans open editors. No action required.
- Fixed hard RSS valve pausing all rules based on the analysis server's total process memory instead of the plugin's own contribution. On large projects the server's AST caches and resolved element model consume 70–90% of RSS, tripping the valve even when the plugin's estimated footprint is under 100 MB. The valve now checks plugin attribution: it only pauses rules when the plugin's estimated memory exceeds 100 MB or 5% of process RSS. A separate unconditional panic threshold at 90% of system RAM provides last-resort OOM protection. No action required.
- Fixed the Drift Advisor integration opening every Dart file in the workspace on each 30-second poll, which could cascade into repeated whole-project scans and exhaust system memory until VS Code crashed. Table lookups now read files directly without creating editor documents, and results are cached until Dart sources change. No action required; the integration is off by default, so only users who enabled it were affected.
- Fixed scan on save treating a file opened by other extension code as a file the user opened, which let any extension's background file access trigger lint scans. Scans now run only for files you actually have open or have saved. No action required.
- Fixed a stalled scan permanently disabling scan on save for the rest of the session. Scans now time out, are canceled when a newer save supersedes them, and release their slot on every failure path. No action required.
- Fixed the memory status bar showing a red critical badge next to a healthy memory figure when the real trigger was orphaned background processes. The badge now names whichever condition actually tripped, and a memory reading shows the same total the warning threshold is compared against. No action required.
- Fixed every level of memory pressure painting the status bar error red, including informational ones such as a light rule shed. Only genuinely severe states are red now, with moderate states amber and informational states left uncolored. No action required.
- Fixed a Dart file open only as one side of a diff or merge view never receiving scan on save diagnostics, because only ordinary tabs were recognized. No action required.
- Fixed a canceled scan leaving an orphaned Dart process on macOS and Linux, and a failure to launch the process cleanup command being able to crash the extension host. No action required.
- Fixed the memory status bar showing plugin state that was no longer live, so a project with the analyzer plugin switched off could still display paused rules and a large memory figure from an earlier session. Nothing is shown now unless the plugin is enrolled and the reading is from the current session. No action required.
- Fixed the memory safety valve never resuming rules after it paused them. Clearing the plugin's own caches made it a minor memory contributor, but release was tested against total process memory, which the analysis server keeps high, so rules stayed paused indefinitely. No action required.
- Fixed the memory valve repeatedly re-measuring every cache while the analysis server sat above the memory cap, which made the common case the most expensive one. No action required.
- Fixed the translation tooling abandoning multi-gigabyte model host processes on every run, by terminating whole process trees rather than a parent alone, sweeping for survivors, and refusing to start when abandoned processes are already present. No action required.
- Fixed `require_copy_with_null_handling` firing on `copyWith` methods where all fields using `??` are non-nullable types. The sentinel/wrapper pattern adds no value when a field cannot be null, so `??` is the correct pattern. The rule now checks class field nullability before emitting. No action required.
- Fixed `require_permission_manifest_android` asserting a missing manifest entry when it cannot read AndroidManifest.xml. Downgraded to INFO severity since the rule is advisory only. No action required.
- Fixed `require_url_launcher_queries_android` asserting missing `<queries>` blocks when it cannot read AndroidManifest.xml. Downgraded to INFO severity since the rule is advisory only. No action required.
- Fixed `require_workmanager_for_background` firing on `Timer.periodic` inside `State` subclasses with proper `cancel()` in `dispose()`. UI-lifecycle timers are not background tasks. No action required.
- Extended `require_workmanager_for_background` to also detect `Stream.periodic` — the same background-polling anti-pattern using the stream API. No action required.
- Fixed `avoid_ios_battery_drain_patterns` firing on `Timer.periodic` inside `State` subclasses with proper `cancel()` in `dispose()`. Widget-bound timers cannot drain battery in the background. No action required.

### Internal

- Triage script (`scripts/triage_scan.py`): added diagnostic-key validation (warns when `filePath`/`severity`/`ruleName` are missing), and a 29-test unit-test suite covering path classification, bucket assignment, and output formatting. No action required.
- Changelog guard hook (`scripts/hooks/changelog_guard.py`): removed the `package.json` version-drift check that false-alarmed every beta cycle because VS Code uses a different version scheme. Guard 1 (multiple unreleased sections) still triggers on `package.json` edits. No action required.
- Extracted shared `isTimerLifecycleBoundToDisposableState()` helper to eliminate duplicate private implementations across timer lifecycle rules. No action required.

---

## [16.0.0-beta.4]

Adds five new lint rules covering unsafe late-final fields, constructor and widget ordering, and Equatable prop sorting. Extends the dashboards with inline rule guidance, embedded Package Dashboard tabs, live sidebar data, and scan progress in Health Panel and Project Map. Also fixes several false-positive and over-suppression bugs in existing rules. [log](https://github.com/saropa/saropa_lints/blob/v16.0.0-beta.4/CHANGELOG.md)

### Added

- New rule `avoid_public_late_final_without_initializer`: flags public `late final` fields with no initializer — a runtime crash waiting to happen if any caller reads the field before it is assigned. No action required.
- New rule `avoid_unnecessary_factory_constructor`: flags `factory` constructors whose body just returns `ClassName(...)` — a factory keyword adds indirection with no benefit when the constructor could be a regular named or unnamed constructor. No action required.
- New rule `no_internal_method_docs`: flags DartDoc comments on private methods in non-library code — internal-only methods rarely benefit from doc comments and the noise makes public API docs harder to find. No action required.
- New rule `prefer_state_class_below_widget`: flags a `State<X>` class declared above its `StatefulWidget X` — the conventional Flutter ordering places the widget's public API first. Closes the DCM `keep-state-below-its-widget` gap. No action required.
- New rule `prefer_sorted_equatable_props`: flags an Equatable `props` getter whose field order doesn't match the class's field declaration order — props that drift out of declaration order are harder to audit for missing fields. Closes the DCM `sort-equatable-props` gap. No action required.
- Findings dashboard: the top-rules expander now shows each rule's how-to-fix guidance, OWASP mapping, related rules, and supersedes/migration notes inline, instead of requiring a jump to the separate Rule Explain screen. This detail is now also available during live analysis, not only after a batch export. No action required.
- Package Dashboard: the Upgrades, Full report, and Known issues tabs now render their content inline instead of opening a separate editor tab. Compare still opens as its own panel. No action required.
- Analysis Optimizer (embedded in the Lints Config dashboard): sortable columns and a working select-all, matching the standalone panel. Sort choice is remembered per dashboard. No action required.
- Project Map: a live percentage progress bar with a file count during scanning, plus pause and cancel, and a Files / Lines / Size summary in the header. Older engines without progress support fall back to the previous elapsed-time view. No action required.
- Project Map reports: the severity and doctor reports now render as sortable typed tables rather than preformatted text, via a new `--format json` mode on both command-line tools. No action required.
- Health Panel: engine cards now show live scan progress ("Scan: N/M files") while the language server is scanning a workspace. No action required.
- Lints Config, Config file tab: a "Migrate config keys" action now appears there when legacy plugin-block keys remain, replacing the sidebar row that previously carried it. No action required.
- Findings dashboard status line and the sidebar's Code Health row now show quality-gate state. A failing gate previously appeared only inside the Code Health screen, so it was invisible unless you went looking for it. No action required.
- Sidebar Code Health and Project Map rows now show live data — health grade and score, and how long ago the project was last scanned — instead of fixed descriptive text. Both read already-computed results and never start a scan. No action required.
- Scan CLI: `--no-exclude` flag disables all hardcoded path exclusions (`example/`, `build/`, `.dart_tool/`, etc.) so the scan covers every `.dart` file it finds. User-supplied `--exclude-globs` still apply. No action required.
- LSP Server: new `saropaLints.lspServer.workspaceScanDelay` setting (default 5 seconds) defers the workspace scan after the analyzer is ready, letting VS Code's startup burst settle first. Set to 0 for immediate scan. No action required.

### Changed

- `require_test_description_convention` now recognizes 23 additional action verbs as good description indicators and uses word-boundary matching to prevent false negatives on substring matches (e.g. "maps" no longer matches inside "hashmaps"). No action required.
- `require_test_description_convention` quick fix now handles interpolated test descriptions — previously it silently skipped them because the full string value was null. No action required.
- `prefer_state_class_below_widget` now detects third-party widget/state pairs — Riverpod's `ConsumerStatefulWidget`/`ConsumerState` and flutter_hooks' `HookStatefulWidget`/`HookState` — in addition to core Flutter's `StatefulWidget`/`State`. No action required.
- Renamed engine names throughout the extension: "Analyzer Plugin" → "Live Analysis", "Scan Daemon" → "Scan on Save" in the Health Panel; "Turn Off Lint Integration" → "Disable Saropa Lints" and "Re-enable In-Process Plugin" → "Re-enable Live Analysis" in the command catalog. Updated notification strings that referenced "Lint integration" to say "Scan on save". No action required.

- Sidebar restructured into three sections totalling 14 rows: Dashboards, Status, and Actions. Rows that open a screen, rows that report state, and rows that run something are now separated, so a row's section tells you what clicking it will do. No setting is flipped from the sidebar any more. No action required.
- Package Dashboard now uses the shared dashboard chrome for page spacing and typography. Body padding, base font size, and line height change slightly as a result; layout is otherwise unchanged.
- The bundled rule catalog now carries correction text and OWASP mappings for every rule, so live analysis can show them without a batch export. This grows the packaged catalog by roughly 0.5 MB. No action required.

### Fixed

- Fixed LSP Server flooding the output channel with `didClose` messages on startup — VS Code sends a burst of didClose notifications for files from the previous session; these are now trace-level and only visible with verbose logging. No action required.
- Fixed `avoid_string_substring` false positives where the index was already guaranteed in bounds by a regex `hasMatch()` guard, an `indexOf()`/`lastIndexOf()` result, or a `RegExpMatch`'s `.start`/`.end`/`.group()`. No action required.
- Fixed `avoid_case_sensitive_path_comparison` false positives on non-path string comparisons: CLI flag literals, Dart import URI comparisons, filesystem root-detection idioms (`dir.path != dir.parent.path`), and identifiers where "path" was embedded in an unrelated word (e.g. "pathology"). Also fixed import-URI suppression failing to detect camelCase `Uri` segments (e.g. `namedUri`) because the boundary check ran on the lowercased name. No action required.
- Fixed `avoid_unsafe_cast` false positives on `ProcessResult.stdout`/`.stderr` cast to `String` — the SDK default encoding always decodes to `String`, so the cast is only unsafe when the call explicitly passes a `null` encoding to request raw bytes. Also fixed a false positive when a cast is preceded by an exact-type `is` check on the same expression in an enclosing `if` condition (e.g. `if (v is List) { v as List }`); only `&&` compounds are recognized as guards — an `is` check inside `||` does not guarantee the type. No action required.
- Fixed `avoid_nullable_interpolation` false positive when a `!= null` guard for the interpolated expression is buried inside a compound `&&` condition (e.g. `if (isChurning(f) && f.churn != null)`), not just a bare `if (expr != null)`. No action required.
- Fixed `avoid_stack_trace_in_production` false positives in developer-tool code: `dart:developer`'s `log()` is now recognized as a diagnostics API (never user-visible output) regardless of package type, and files under a `bin/`/`tool/` directory are skipped even in mixed packages that aren't wholly CLI tools. No action required.
- Fixed `require_url_validation` false positive on local `file://` path validation — the scheme-guard heuristic now also recognizes `.isScheme('file')` checks and the `file` scheme, not just `.scheme` reads against `https`/`http`. No action required.

- Fixed `runtime_tier` being silently ignored when set in `analysis_options_custom.yaml`. The Config file tab writes this key, but the parser only ever recognized `saropa_tier`, so the chosen value was written to disk and then dropped with no warning. It is now recognized as a deprecated alias and reports a migration warning. Set the tier in the `plugins: saropa_lints:` block to have it take effect.
- Fixed the Health Panel reporting scan-on-save as "idle" while it was actually disabled — the status only tracked memory-pressure suspension and never read the master switch, so a disabled scanner looked healthy. No action required.
- Fixed `--format` being swallowed as the target path by the severity report and doctor command-line tools, so the flag had no effect and the positional path was lost. No action required.
- Fixed selecting a package from the embedded Upgrades tab opening the detail pane behind a hidden tab; the dashboard now switches back to Overview first. No action required.
- Fixed Package Dashboard's Full report and Upgrades embedded tabs showing "Generating…" forever on first open, and rendering stale data from the previous scan on subsequent opens. The async builders now read the current scan results instead of the not-yet-assigned options object. No action required.
- Fixed Full report tab's "Expand/Collapse all" button toggling every `<details>` element in the Package Dashboard (charts, package filters, grade breakdown in Overview), not just the Feature Inventory's own disclosures. The script is now IIFE-wrapped and scoped to its own tab container. No action required.
- Fixed the Health Panel engine card showing "scanning N/M files" indefinitely after a canceled workspace scan. The LSP server's scan progress notification now carries an explicit `done` flag on terminal ticks (cancel or completion), so the client no longer relies solely on the filesScanned/totalFiles ratio. No action required.
- Fixed severity report and doctor typed tables falling back to raw text on the first run after install or `pub get`, because Dart's "Building package executable…" stderr banner was mixed into the JSON parse buffer. Only stdout is now accumulated for JSON parsing. No action required.
- Fixed Project Map progress bar never reaching 100% when the CLI's final progress event arrived without a trailing newline. The partial-line flush on process exit now routes through the progress parser instead of bypassing it. No action required.
- Fixed `avoid_nullable_interpolation` false positive on `Match[n]` and `Match.group(n)` in string interpolations — when the regex pattern literal is visible, a group-count parser now verifies the accessed index refers to a required capture group; the parser now also traces through variable assignments (`final re = RegExp(r'...'); re.firstMatch(...)`) and correctly handles groups containing alternation (e.g. `(a|b)` is always required). No action required.
- Fixed `avoid_dynamic_calls_extended` over-suppression: dynamic calls inside catch clauses and finally blocks are no longer wrongly exempted by the try/catch guard (only the try body is exempted). Bare `catch(e)` and `on Object` no longer suppress dynamic-call warnings — only `on NoSuchMethodError` and `on TypeError` indicate intentional duck-typing. No action required.
- Fixed `require_catch_logging` over-suppression: `catch (e) { return null; }` with an unused exception variable was falsely exempt — the return/continue/break exemption now fires only when the exception variable is actually referenced. No action required.
- Fixed `require_url_validation` over-suppression: substring `'file'` no longer matches inside identifiers like `profileId`; `startsWith` guards are now checked against the actual URL variable; CLI exemption is scoped to the file's directory rather than disabling the rule project-wide. No action required.
- Fixed `avoid_global_state` over-suppression: `_hasClearOrResetFunction` now matches exact identifier tokens instead of substrings; `??=` lazy-init detection uses a word-boundary regex instead of raw source text; multi-variable declarations no longer fire duplicate diagnostics. No action required.
- Fixed `require_cache_expiration` over-suppression: `.clear()` detection is now scoped to the flagged cache class's own Map fields rather than matching any `.clear()` in the file; `HashMap`/`hashCode` are no longer treated as crypto-hash indicators. No action required.
- Fixed `avoid_string_substring` over-suppression: `indexOf` results are recognized as safe index sources alongside `RegExpMatch.start`/`.end`/`.group()`; a regex `hasMatch()` guard on the receiver is now accepted in `if`-condition and ternary branches. No action required.
- Fixed `avoid_case_sensitive_path_comparison` over-suppression: the root-detection idiom check now verifies both sides of a `||` share the same base expression. No action required.
- Fixed `require_test_description_convention` false positives on data-driven test descriptions built with string interpolation (e.g. `test('${'$'}{c.rule} should ...', ...)`) — the rule read `stringValue`, which is always null for a non-constant string, so every interpolated description was flagged regardless of its actual wording. It now reads the literal text segments instead. No action required.

### Internal

- Archived 36 tier-1 quick-win proposals already covered by existing rules — 19 implemented under the same name, 8 under a different name or alias, and 9 identified as functional duplicates of rules shipped in prior versions. Updated 15 migration guides to reflect the closures (TODO → HAVE with correct saropa rule name). No action required.
- Added fixture coverage for `require_ios_deployment_target_consistency`'s collection-literal guard — GOOD cases with a rule-name string inside a `Set` and as a `Map` value, confirming `isDataLiteralElement()` (shipped in beta.3) already prevents the false positive reported in a duplicate bug report. No action required.
- Added GOOD fixture cases for `require_catch_logging` and `avoid_swallowing_exceptions` covering fallback-return, loop-continue, and loop-break catch bodies, confirming the return/continue/break handling guard closes the intentional-fallback false positive reported against both rules. No action required.
- Fixed 12 false-positive rule implementations: `avoid_unsafe_reduce` now skips non-empty list/set literals; `avoid_accessing_collections_by_constant_index` now skips write targets (DP row init); `require_catch_logging` and `avoid_swallowing_exceptions` now accept return/continue/break as valid handling; `avoid_dynamic_calls_extended` now exempts Object methods and try/catch-guarded duck-typing; `avoid_unsafe_cast` now recognizes preceding `is` checks; `avoid_global_state` now exempts lazy-init (`??=`) and managed-lifecycle globals; `avoid_case_sensitive_path_comparison` now skips root-detection idioms and CLI flag literals; `avoid_platform_specific_imports`, `avoid_stack_trace_in_production`, `require_cache_expiration`, `avoid_unbounded_cache_growth`, and `require_url_validation` now skip CLI tool and analyzer plugin packages via new `ProjectContext.isCliOrToolPackage()`. No action required.
- Extended `avoid_global_state`'s managed-lifecycle exemption to also recognize a same-file `dispose*` function (previously only `clear*`/`reset*`), and confirmed `late final` globals were already exempt via the existing const/final skip. No action required.
- Fixed `avoid_unnecessary_factory_constructor` compile error against analyzer 12.x — used removed `ClassDeclaration.name` getter instead of `nameToken`, causing the LSP server to crash on startup (exit 255).
- Fixed unsafe `as Map<String, dynamic>` cast in `audit_baseline.dart` — `jsonDecode` on a valid-but-non-object baseline file (e.g. `[]`) threw `TypeError` instead of returning `null` per the documented contract. Replaced with `is!` type check.
- Fixed 6 broken `// ignore:` comments missing the `saropa_lints/` prefix — suppressions in `project_context.dart`, `pubspec_constraint_parser.dart` (3), `project_context_parallel_batch.dart`, and `project_vibrancy_resolved_usage.dart` were silently ineffective.
- Fixed case-sensitive path comparison in `project_vibrancy.dart` — `--file` CLI argument now compared with `p.equals()` for Windows/macOS compatibility.
- Fixed nullable interpolation in `health_export_markdown.dart` — `churn` field interpolated without null guard, producing "null commits" in markdown export.
- Fixed forward-slash path construction in `log_writer.dart` (2 sites) and `init_runner.dart` — replaced string interpolation with `p.join()`/`p.basename()` for cross-platform correctness.
- Filed 13 false-positive bug reports across 13 rules against own-dogfood scan findings (305 total, 295 confirmed FP). See `bugs/` for details.
- Fixed `commandCatalogRegistry.test.ts` failures: added 17 missing catalog entries for commands that existed in `package.json` but had no catalog registration, and marked 15 palette-hidden commands as `internal`. All 17 catalog sync tests now pass.
- Fixed remaining `require_cache_expiration` / `avoid_unbounded_cache_growth` false positives on content-addressed caches: both rules now skip classes keyed by hash/sha/fingerprint/digest (a stale entry under an unchanged key is structurally impossible), skip files under a `bin/`/`tool/` directory in addition to the existing whole-package check, and skip caches with an explicit `.clear()` call anywhere in the same file. No action required.

- Partially migrated the Package Dashboard's parallel stylesheet onto the shared dashboard chrome: the accessibility helper, hero header, status line, and page layout families now come from the shared layer. The remaining duplicated families cannot be adopted piecemeal because the shared chrome's exported functions bundle unrelated rules — adopting the motion helper would also restyle inline code, and adopting the layout helper drags a full body reset with it. Splitting the chrome into single-concern exports is a prerequisite for finishing this.
- Reworked the embedded Known issues tab to prefix element ids and scope its script, preventing collisions with the host dashboard's own search and table when both render in one document.
- Added regression coverage for the areas above: the scan progress event schema and cancel path, the language server's progress notification shape, the rule-catalog correction/OWASP backfill, the report totals parser, the optimizer sort and bulk-select, the rule-detail expander, and the embedded tab contracts.
- Added CI compile-check gate (`dart compile kernel`) for all `bin/` entry points — catches build-breaking analyzer API changes that `dart analyze` misses because rule files are loaded at runtime.
- Added CI `check_analyzer_api_compat.py` script that greps rule files for known-removed analyzer package APIs (e.g. `ClassDeclaration.name.lexeme`) before they reach users as a crash.

- Extracted shared `catchHandlesViaControlFlow()` and `catchBodyUsesException()` utilities into `catch_body_logging_utils.dart` — eliminates duplicated return/continue/break and exception-usage checks between `require_catch_logging` and `avoid_swallowing_exceptions`. No action required.

- Split the shared dashboard chrome stylesheet into single-concern exports, with the existing public functions preserved as compositions so every consumer renders identically. The previous bundling made the layer un-adoptable piecemeal: taking the hero animation also took an unrelated monospace rule, and taking the full-width toggle dragged a whole body reset with it. A unit test now pins each composition.
- Removed a duplicate `.sr-only` accessibility rule from the token layer after confirming every consumer already pairs it with the accessibility helper; the test suite now pins that rule as defined exactly once.
- Fixed 9 self-dogfood lint warnings in test files: 3 `avoid_misused_test_matchers` (raw `true`/`false` → `isTrue`/`isFalse`), 5 `require_test_description_convention` (added "should" keyword to interpolated test descriptions), and 1 `prefer_setup_teardown` (hoisted repeated `_violationsForExample()` call into `setUpAll`).
- Adopted the shared hero animation and reduced-motion rules in the Package Dashboard stylesheet. The summary cards, table toolbar, and footprint toggle stay local by decision, not omission — each differs from its chrome counterpart in layout semantics, domain color vocabulary, or ARIA interaction model, and the reasons are documented in the code. See `plans/PLAN_ext_ui_report_styles.md` for the full disposition.
- Fixed 2 stale curated dictionary keys in `dictionaries.py`: removed the `de` entry whose English source text was rewritten (daemon label, LSP/plugin separation), and capitalized the `fil` "Analyzer Plugin" key to match the current source strings. Patched 48 missing translations across 21 locales — 4 format/loanword strings added to `DO_NOT_TRANSLATE`, 15 locale-specific entries hand-translated. Added `--strict-dnt` flag to `generate_locales.py` — treats `DO_NOT_TRANSLATE` collision warnings as errors for CI gating.
- Added "Make member public (remove underscore)" quick fix for `no_internal_method_docs` — strips the leading `_` from the declaration name as an alternative to the existing "Convert to a regular comment" fix.
- Added fixture files for `no_internal_method_docs`, `prefer_state_class_below_widget`, and `prefer_sorted_equatable_props`. Extended `avoid_public_late_final_without_initializer` fixture with static and multi-variable edge cases.
- Added `DeprecatedNewInCommentReferenceRule` instantiation test to the documentation rules test suite.
- Fixed scan CLI silently excluding `example_packages/` fixtures: the hardcoded `/example` substring in `scan_runner.dart` matched `example_packages/`, the `--files` flag applied exclusions to explicitly named files, and `shouldSkipFile`'s fixture-skip exemption missed relative paths and `example_packages/`. Three-part fix: tightened the substring to `/example/`, bypassed exclusions when `--files` is explicitly provided, and added `startsWith` checks for relative paths.
- Fixed three CodeQL `js/bad-tag-filter` alerts (two reported, one preemptive) in test infrastructure — closing-tag regexes now tolerate attributes and case variants. No action required.
- Added `check_html_tag_regex.py` CI script that detects HTML tag regexes missing case-insensitive flags or attribute-tolerant closing tags before CodeQL reports them on push. No action required.
- Moved `require_test_description_convention` fixture from `example/lib/testing_best_practices/` (where `isTestPath` never matched, so the `FileType.test`-gated rule silently never ran) to `example/lib/test/` with real BAD/GOOD examples covering simple strings and interpolated descriptions. Added to `expectedFromFixtures` in the integration test.
- Added `check_fixture_filetype_match.py` CI script that audits all rules with `applicableFileTypes => {FileType.test}` and verifies their fixture files live at paths matching `isTestPath()` — wired into the publish pipeline as a blocking check via `run_pre_publish_audits()`, and supports `--fix` to bulk-relocate misplaced fixtures via `git mv`. No action required.

---

## Historical Changelog Archive

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for older versions.
