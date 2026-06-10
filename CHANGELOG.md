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

## [Unreleased]

Adds one-click quick fixes for eight more lint rules, so common simplifications can be applied straight from the IDE lightbulb instead of by hand. An if/else (or if plus a following return) that returns `true` in one branch and `false` in the other collapses to a direct return of the condition, a nested `if` with no else on either level merges into a single combined condition, an explicit null-check-then-call becomes the null-aware `?.` form, and a class that holds only static members is marked `abstract final` so it can no longer be instantiated. Redundant arguments and a redundant nullable `?` are now removable in one click too. A severity recalibration moves 46 rules that flag preferences, performance, robustness gaps, or deployment-config issues (not broken or crashing code) from error down to warning, so they no longer fail a strict build; rules that mark genuine compile errors, runtime crashes, data corruption, or security holes keep error severity. No action required. [log](https://github.com/saropa/saropa_lints/blob/v13.12.5/CHANGELOG.md)

### Added

- **`avoid_unnecessary_if` and `prefer_returning_condition` gain a quick fix that returns the condition directly.** `if (c) return true; return false;` becomes `return c;` and the if/else form becomes `return c;` / `return !(c);`; the condition is parenthesized when negated so operator precedence stays correct. No action required.
- **`avoid_collapsible_if` gains a quick fix that merges the nested if into its parent.** `if (a) { if (b) { … } }` becomes `if ((a) && (b)) { … }`, with both conditions parenthesized to preserve precedence. No action required.
- **`prefer_null_aware_method_calls` gains a quick fix that rewrites the guard with `?.`.** `if (x != null) x.foo();` and `x != null ? x.foo() : null` both become `x?.foo()`, reusing the original receiver and arguments verbatim. No action required.
- **`avoid_classes_with_only_static_members` gains a quick fix that adds `abstract final` modifiers.** This makes a static-only utility class non-instantiable, matching the existing `prefer_abstract_final_static_class` fix. No action required.
- **`avoid_icon_size_override` and `avoid_riverpod_string_provider_name` gain a quick fix that removes the flagged named argument.** The `size:` argument on `Icon` and the `name:` argument on a provider are deleted together with their comma so the remaining arguments stay valid. No action required.
- **`avoid_nullable_parameters_with_default_values` gains a quick fix that removes the redundant `?`.** A parameter with a non-null default does not need a nullable type, so `int? x = 0` becomes `int x = 0`. No action required.
- **New `riverpod_2` rule pack gates the Notifier-migration rule on Riverpod 2.x.** `prefer_notifier_over_state` recommends migrating `StateProvider` to `NotifierProvider`, an API that only exists in Riverpod 2.0+. The new pack enables that rule only when `pubspec.lock` resolves `riverpod >= 2.0.0`, so a Riverpod 1.x project is never told to adopt an API it does not have. Enable it with `rule_packs: { enabled: [riverpod_2] }` (the VS Code Rule Packs view lists it when Riverpod 2.x is detected). No action required.

### Changed

- **Severity recalibration: 46 rules downgraded from error to warning.** A rule-by-rule audit against a three-level model (error = broken/crash/exploit/MUST-fix; warning = should-fix; info = FYI) found 46 rules whose error severity over-stated them — Riverpod/Bloc preferences and should-fix patterns, performance rules (`avoid_get_find_in_build`, `require_vsync_mixin`, `avoid_provider_of_in_build`), robustness-fallback rules (`require_error_boundary`, `require_unknown_route_handler`, `require_go_router_fallback_route`, `require_deep_link_fallback`), deployment-config heuristics (`require_android_manifest_entries`, `require_ios_info_plist_entries`, `require_macos_entitlements`, `require_firestore_index`), accessibility (`avoid_hidden_interactive`), and test-quality (`require_test_widget_pump`, `avoid_print_in_release`). They now report as warnings and no longer fail a strict build. Rules that mark genuine compile errors (`duplicate_constructor_declarations`, `uri_does_not_exist`), runtime crashes (`avoid_setstate_in_build`, `avoid_recursive_widget_calls`, `require_provider_scope`, `avoid_circular_redirects`), data corruption/loss (`avoid_isar_enum_field`, `avoid_isar_schema_breaking_changes`), or security holes (`require_https_only`, `require_route_guards`) keep error severity.
- **`prefer_notifier_over_state` moved out of the base `riverpod` rule pack into the new gated `riverpod_2` pack.** If you enable rule packs with `rule_packs: { enabled: [riverpod] }` and want this rule, add `riverpod_2` to the list. The move keeps the rule from reaching Riverpod 1.x projects, where its recommended `NotifierProvider` target does not exist. Tier-based configurations are unaffected.

<details>
<summary>Maintenance</summary>

- The extension translation pipeline now splits an over-long source string on clause boundaries (newlines, then `;:—–,`, never mid-URL) when sentence-splitting alone leaves it past NLLB's per-call token gate, so long config descriptions and markdown link blocks stay on the higher-quality NLLB engine instead of silently dropping to Google. Every string NLLB still cannot translate (Google-served, left English, or unsplittable) is now named in a new `reports/i18n_nllb_fallbacks.md` report instead of a once-only console log, making fallbacks visible and actionable. Build tooling only (excluded from the `.vsix`); no behavior change for users.
- Reduced `ROADMAP.md` to a short redirector pointing at the GitHub `plans/` folder, where the live roadmap, build backlog, and deferred-rule documents already reside. The previous inline copy had drifted out of sync (broken links to plan files since moved or deleted) and duplicated content the `plans/` tree owns. Doc housekeeping only.
- The rule-pack lockfile resolver can now distinguish direct from transitive dependencies (`isDirectDependency`), parsing the `dependency:` field of `pubspec.lock`. This is the resolver primitive behind the ratified "direct-only suggestions" policy; the suggest UX that consumes it is not yet wired. No behavior change for users.
- Corrected stale test paths in the plugin-system migration plan so the documented rule-pack verification command (`test/config/rule_packs_*.dart`) actually runs. Plan housekeeping only.
- Re-keyed the three remaining DX-message audit scripts (`_audit_dx.py`, `_improve_dx_messages.py`, `_audit.py`) from the retired 5-bucket impact taxonomy to the 3-level `error/warning/info` severity model, so their length thresholds and per-severity report tables grade against live values instead of silently defaulting. Internal tooling only; closes SEV-04 of the LintImpact→severity collapse plan.
- Removed 396 empty-body stub tests (`test('…', () {})`) plus 255 `group()` blocks those deletions left empty (651 statements across 47 test files). An empty test body always passes and asserts nothing, giving false coverage confidence. The stub guard now hard-gates the empty-body shape to zero via `scanEmptyBodyStubTests`; 27 legitimate assertion-free tests (does-not-throw and helper-asserted) are retained. Restoring behavioral coverage for the affected rules is tracked as Phase 2 in `plans/BUG_stub_tests_in_suite.md`. Test-suite hygiene only; no rule or runtime change.
- The publish audit now blocks on the stub guard. `run_stub_guard_check` runs the guard test in the audit phase and feeds `AuditResult.stub_guard_passed` into `has_blocking_issues`, so a reintroduced always-pass stub fails the publish audit (exit code 11) instead of only failing the wave-through-able Step 7 test run. Release tooling only.

</details>

## [13.12.4]

Clears a wide round of false positives across the string, exception-handling, async, rebuild, testing, collection, listener, lifecycle, and platform rules, so idiomatic patterns that previously forced project-local ignores now pass cleanly. The Package Dashboard gains a one-click "Save Upgrade Report" that exports just the packages with an available update as a focused worklist, and every Package Vibrancy dashboard is now fully translatable instead of always rendering in English. The localized UI also stops machine-translating brand and tool names — the product name, VS Code, and pub.dev now read identically in every language. No action required unless you added an ignore for one of the corrected patterns. [log](https://github.com/saropa/saropa_lints/blob/v13.12.4/CHANGELOG.md)

### Fixed

- **`avoid_string_concatenation_loop` only fires on a genuine accumulator (`s = s + x`).** Per-element transforms — `.map((e) => e + suffix)`, a fresh per-iteration local, a `RegExp(... + ...)` argument — produce a new string each pass (O(n)), not the O(n²) accumulation the rule targets, and are no longer flagged. No action required.
- **`avoid_swallowing_exceptions` no longer flags a `catch (_)` wildcard whose body handles the error.** The `_` wildcard is a deliberate "discard this object" marker that cannot be referenced; a named-but-unused catch is also exempt when the body logs or rethrows. An empty catch is still flagged. No action required.
- **`avoid_unawaited_future` exempts `close()`/`cancel()` cleanup in synchronous void contexts.** A controller `close()` in `dispose()`, a subscription `cancel()` in a `StreamController.onCancel` closure, and a `close()` in a hand-named teardown method are recognized — awaiting is impossible there. No action required.
- **`avoid_excessive_rebuilds_animation` no longer flags builders that read an animated value at a nested leaf.** It now counts only the genuinely-static (hoistable) widgets — those whose subtree reads no animation `.value` — so a `fontSize: a.value` Text wrapped in required scaffold is exempt, while a large static subtree under `Opacity(opacity: a.value)` still fires. No action required.
- **`prefer_setup_teardown` no longer flags per-test `pumpWidget` or per-group arrange.** Statements bound to a `testWidgets` `WidgetTester` cannot move to `setUp()`, and when the file already declares a real `setUp()` the duplicate threshold is raised so per-group arrange does not trip. No action required.
- **`prefer_single_setstate` no longer merges a `setState` before a loop with one inside the loop after an in-loop `await`.** Loop bodies are scanned as their own execution scope, so calls separated by a per-iteration suspension are not reported as combinable; two consecutive `setState` calls in one iteration still are. No action required.
- **`prefer_value_listenable_builder` no longer flags async-loaded, FutureBuilder-companion, or notifier-backed single-field states.** A State that holds a `Future`/`Stream` field, assigns its field in an `async` setState, or manually wires a `Listenable` is exempt (a `ValueNotifier` cannot replace those); genuine synchronous single-value display state still fires. No action required.
- **`avoid_collection_equality_checks` no longer flags `==`/`!=` on model types whose class name merely starts with a collection keyword.** It now uses a resolved-type check, so `MapClusterModel`, `ListTileData`, and `SetupConfig` are no longer mistaken for `Map`/`List`/`Set`; real `List`/`Map`/`Set` comparisons still fire. No action required.
- **`avoid_unsafe_collection_methods` recognizes seven more non-emptiness guard shapes before flagging `.first`/`.last`/`.single`.** Combined `== null || isEmpty` and `length <= 1` early returns, `continue`/`break` guards in loops, a guard one block above the access, `Map.keys`/`.values` after a guard on the map (or inside a `while (map.length > n)` loop), `isListNullOrEmpty` extension guards, indexed targets (`m[k]!.first`), and `split()` results held in a variable are all treated as non-empty. Genuinely unguarded access still fires. No action required.
- **`avoid_listview_without_item_extent` no longer flags lists where `itemExtent` cannot help or cannot be set correctly.** A `shrinkWrap: true` list (any physics) is exempt because eager layout already defeats lazy extent, and a `ListView.builder` whose item is self-sizing (`ListTile` with optional subtitle, `ExpansionTile`, a `Common*ListTile`/`PanelExpandable` wrapper) is exempt because no constant extent is correct; plain fixed-height lists still fire. No action required.
- **`always_remove_listener` no longer reports a leak when add and remove reach the same listenable through different null-aware operators.** The idiomatic `field!.addListener(cb)` in initState paired with `field?.removeListener(cb)` in dispose now matches. No action required.
- **`avoid_context_in_initstate_dispose` only fires when `context` performs an inherited-widget or render-tree lookup.** A `context` forwarded to an ordinary helper (e.g. `resolveColor(context)`) that does no `.of(context)` lookup is no longer flagged; `Theme.of(context)`, `context.read()`, `context.size`, and `dependOnInheritedWidgetOfExactType` still are. No action required.
- **`avoid_string_substring` recognizes more bounds guards and no longer flags provably in-bounds slices.** It now accepts the else-branch of an `indexOf` ternary, a substring evaluated inside an `if` condition, `isEmpty`/`isNotEmpty` guards, `startsWith`/`isEmpty`/regex early-exit returns, property/index substring arguments (`prefix.length`, `match.start`, `split[0]`), and post-loop slices bounded by a preceding loop. No action required.
- **`avoid_returning_null_for_future` no longer flags `return null` from a function declared to return a nullable Future (`Future<T>?`).** A nullable Future explicitly permits null, so the return is type-correct; only non-nullable `Future<T>` is still flagged. No action required.
- **`avoid_ios_hardcoded_device_model` no longer flags device names that appear as data.** A device model in a list/set/map literal (e.g. an email-signature noise-filter corpus) is exempt, while a genuine `== 'iPhone 14'` comparison or `model.contains('iPod touch')` check still fires. No action required.
- **`require_dialog_tests` no longer flags calls that merely contain "Dialog" in their name.** A localization string getter such as `emergencyDirectoryDialogHeader(...)` is not a dialog launch; the rule now matches known dialog launchers or `*Dialog*` calls that return an awaitable. No action required.
- **`require_error_identification` no longer flags non-color ternaries that select a log-severity enum or text label.** It now requires a branch to be `Color`-typed, so a `DebugLevels.Error` selection is not mistaken for an error-color cue. No action required.
- **`avoid_unbounded_cache_growth` recognizes `removeWhere` / `removeRange` / `clear` as eviction.** A cache pruned with these idiomatic operations is no longer reported as unbounded. No action required.

### Added (Extension)

- **The Package Dashboard toolbar adds a "Save Upgrade Report" button next to "Save".** It writes the same per-package JSON as "Save" but filtered to only packages with an available update, to `reports/YYYYMMDD/..._pubspec_upgrade.json`, giving you a focused upgrade worklist. No action required.

### Changed (Extension)

- **The Package Vibrancy dashboards are now fully translatable.** Around 265 previously-hardcoded English strings across the report, comparison, package-detail, detail, and chart webviews now resolve through the extension's localization catalog, so they translate alongside the rest of the UI instead of always rendering in English. No visible change for English users; other locales pick up the translations once the locale catalogs are regenerated.

### Fixed (Extension)

- **Brand, tool, and code-identifier names are no longer machine-translated or transliterated in the localized UI.** Product and tool names ("Saropa Lints", "VS Code", "pub.dev", "OWASP", "SPDX", "Dart", "Flutter") and literal identifiers such as file names and config keys (`violations.json`, `analysis_options`, `pubspec.yaml`, `dev_dependencies`, `saropa_lints`) were being rendered as native words or local-script transliterations (e.g. "Saropa Fusseln", "VS Kodu", "पब.डेव", "الانتهاكات.json") across translated command titles, settings descriptions, and dashboards; every locale now shows one worldwide spelling, and the translation pipeline shields these terms so future regenerations keep them intact. No action required.

<details>
<summary>Maintenance</summary>

- The publish script now gates the release on a CHANGELOG Overview check: the version section must open with an intro paragraph ending in a `[log](.../vX.Y.Z/CHANGELOG.md)` link pinned to the proposed version. A missing intro or a stale/wrong-version link prompts retry (default) / ignore / abort instead of shipping silently. Build tooling only; no behavior change for users.
- The extension translation script gained operator controls for long NLLB runs: a graceful Ctrl-C (first press finishes the in-flight string, flushes the cache, and exits cleanly; second force-quits), a `--mode` selector — gaps-only / gaps + upgrade low-quality Google→NLLB / force re-translate — with an interactive menu, persistent per-string engine provenance, and `--show` / `--set` / `--unset` commands to inspect, override, or remove cached translations. Build tooling only (excluded from the `.vsix`); no behavior change for users.
- The translation script's `--mode` menu adds an audit-only option (`--mode audit`) that writes the gaps + low-quality (upgrade-candidate) report to file without translating, pruning, or rewriting any locale, plus an `[a]` abort option that exits the menu with no changes. Build tooling only; no behavior change for users.
- The publish pipeline no longer machine-translates extension locales; it now runs the coverage check in `--mode audit` (writes the gaps report, translates nothing) and, on a remaining gap, prompts Retry (re-audit, default) / Ignore / Abort. Closing gaps is an explicit separate step (edit `dictionaries.py` or run the translator yourself). Build tooling only; no behavior change for users.
- The extension package now excludes `scripts/**` (build-time i18n/MT tooling) from the published `.vsix`. Those scripts are never loaded at runtime — runtime locales ship from `src/i18n/locales` via the esbuild bundle — and shipping them leaked the machine-translation cache, whose high-entropy translated strings tripped Open VSX's secret scanner and blocked publication. No behavior change.
- The publish script now checks for `VSCE_PAT` before the Marketplace publish step and prompts with token-creation guidance when it is missing, mirroring the existing Open VSX handling. A missing or expired Marketplace token previously failed with an opaque `vsce` error and only a generic "PAT expired?" guess. No behavior change.
- Documented the upstream cause of the `analyzer`/`analyzer_plugin` version caps in `pubspec.yaml`: Flutter pins `meta` exactly inside the SDK, analyzer 13 raised its `meta` floor above that pin, and the caps clear only when Flutter stable bumps its bundled `meta`. Added links to the Dart pinning rationale and the open Flutter unpin issue. No behavior change.

</details>

## [13.12.3]

Adds a family of compound performance rules that flag GPU-expensive widgets only when a parent makes their cost recur every frame or every scrolled item, leaving intentional one-off use alone, plus a Project Map panel that ranks features by rendering risk before you profile. Also clears a broad round of false positives across the async-context, logging, disposal, date-formatting, enum-map, environment-mixing, parameter-mutation, and error-widget rules, so patterns that previously forced project-local ignores now pass cleanly. No action required unless you added an ignore for one of these patterns. [log](https://github.com/saropa/saropa_lints/blob/v13.12.3/CHANGELOG.md)

### Added

- **Six compound performance rules — an expensive widget is flagged only when its parent makes the cost recur, never on its own.** `avoid_opacity_in_animated_builder`, `avoid_opacity_in_scrollable`, `avoid_backdrop_filter_in_scrollable`, `avoid_shader_mask_in_scrollable`, `avoid_image_filter_in_scrollable`, and `avoid_clip_path_in_animated_builder` catch GPU-expensive widgets (`Opacity`, `BackdropFilter`, `ShaderMask`, `ImageFiltered`/`ColorFiltered`, `ClipPath`) placed inside an `AnimatedBuilder` or a scrollable, where they re-composite every frame or every scrolled item. Static, one-off use of the same widgets is intentionally not reported. Recommended tier and above.
- **The Project Map dashboard now ranks features by performance gravity.** A new panel scores each feature (0–100) from the compound performance patterns its files contain, surfacing which features carry the most rendering risk before you profile. The score reflects pattern severity alone, so adding pattern-free files never changes it. Enable on the CLI with `project_health --performance`.

### Fixed

- **`avoid_context_in_async_static` no longer flags a guarded or pre-await `BuildContext` parameter.** The rule reported the parameter unconditionally whenever the method was an async static, so a context used only before the async gap opened, or only after a `mounted` check, was wrongly flagged and forced widespread ignores. It now reuses the same flow analysis as the sibling after-await rule and fires only when the context is used after an `await` without a guard. Genuinely unguarded post-await usage still flags. No action required.
- **`avoid_debug_print` and `avoid_print_error` no longer flag the logging infrastructure's own sink.** Both rules redirect callers to structured logging, but the implementation of that logging — functions named `debug*`, `_debug*`, or `breadcrumb` — must call `debugPrint`/`print` directly, since routing back through `debug()` would recurse infinitely. Both rules now exempt calls inside those logging-primitive functions. Ordinary application `debugPrint`/`print`-in-catch usage still flags. No action required.
- **`avoid_duplicate_object_elements` no longer flags a repeated entry in a gradient `colors:`/`stops:` list.** Those parameters are ordered, position-sensitive sequences where a symmetric ramp deliberately repeats an endpoint (`[base, highlight, base]`), so the duplicate is required by the visual shape, not a copy-paste error. The rule now skips lists bound to a `colors:` or `stops:` argument. Duplicate identifiers, booleans, and nulls in ordinary collections still flag. No action required.
- **`avoid_large_list_copy` no longer flags a structurally-required `.toList()` in a switch arm, record field, or `yield`.** The exemption that recognizes mandatory-`List` contexts climbed through transparent wrappers but stopped at a `switch`-expression arm, a record literal, or a `yield`, so a `.toList()` inside a `List<T>` getter built from a `switch` was wrongly flagged on every arm. It now climbs through those nodes to the enclosing return/body and treats a generator `yield` as requiring a `List`. A genuinely avoidable `.toList()` (lazy chain whose result is discarded) still flags. No action required.
- **`avoid_manual_date_formatting` no longer flags non-`DateTime` types or internal keys.** A string interpolation reading two or more `.month`/`.day`/`.year` getters was treated as manual date formatting even when the value came from a custom calendar type (`HebrewDate`, a project `DateTime` wrapper) or built an internal dedup/cache key, because an unresolved type was assumed to be a `DateTime`. An unresolved type is now treated as non-`DateTime`, and the internal-key exemption now also covers values returned from or assigned inside a key/cache/hash-named function. Manual formatting of a real `DateTime` for display still flags. No action required.
- **`avoid_missing_enum_constant_in_map` no longer flags a partial map constrained by a sibling argument.** A map that omits enum constants is intentional when a sibling argument on the same constructor fixes that enum to a single value — `Dismissible(direction: DismissDirection.up, dismissThresholds: {DismissDirection.up: 0.25})`, where the other directions can never fire. The rule now skips an enum-keyed map passed as a named argument when a sibling named argument has a value of the same enum type. A standalone partial enum-keyed map still flags. No action required.
- **`avoid_undisposed_instances` and `require_field_dispose` now recognize disposal through a multi-section cascade.** A controller disposed via `_c?..removeListener(f)..dispose()` read as undisposed because the AST rule looked at the cascade section's (empty) syntactic target and the string-based rule's patterns only matched `..dispose()` as the first cascade section. The AST rule now resolves the cascade receiver and the string rule matches `dispose()` in any cascade position. A field whose cascade never calls a disposal method still flags. No action required.
- **`no_equal_arguments` no longer flags constructors where equal arguments are required.** A repeated identifier argument was treated as a copy-paste error even for a neutral gray (`Color.fromRGBO(g, g, g, 1)`), a point-anchor rect (`RelativeRect.fromLTRB(x, y, x, y)`), or a square (`Size(d, d)`), where the equal values are the documented idiom. The rule now exempts `fromRGBO`, `fromARGB`, `fromLTRB`, `Size`, and `Offset`. A repeated identifier passed to any other callee (e.g. `setPosition(x, x)`) still flags. No action required.
- **`no_equal_nested_conditions` no longer flags an inner check whose variable was reassigned.** When a nested `if` repeats the outer condition textually but the condition's variable was reassigned in between (`if (q == null) { q = q?.trim(); if (q == null) … }`), the inner check tests the new value and is a mandatory guard, not redundant. The rule now tracks reassignments in the then-branch and stays quiet when a condition variable was reassigned before the inner check. A genuinely redundant inner check (no reassignment) still flags. No action required.
- **`prefer_dispose_before_new_instance` no longer flags a deferred post-frame disposal.** When a controller field is reassigned and the previous instance is captured into a local and disposed later — typically in an `addPostFrameCallback`/`Future.microtask` closure, because disposing inline asserts while the controller is still attached — the old instance is correctly released. The rule now recognizes the capture-and-dispose idiom (including disposal inside a callback closure). A reassignment with no disposal of the prior instance still flags. No action required.
- **`prefer_layout_builder_for_constraints` no longer flags a window-width breakpoint query.** `MediaQuery.sizeOf(context).width` passed as a positional argument to a device-class helper (`ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)`) reads the window width to pick a layout strategy, not to size a widget — `LayoutBuilder` would give the local box width, the wrong signal. The rule now exempts a width/height used as a positional call argument. A width/height assigned to a `width:`/`height:` named argument (actual widget sizing) still flags. No action required.
- **`prefer_reusing_assigned_local` no longer flags a post-increment index or a repeated constructor allocation.** An index read with a side effect (`pts[i++]`) advances the index each evaluation, and `ValueNotifier<bool>(false)` declared twice allocates two distinct objects, so neither is a redundant recompute — yet both were flagged as reusable. The rule now treats `++`/`--` in the initializer and PascalCase constructor-style calls as non-reusable. A genuine repeated pure read still flags. No action required.
- **`require_error_widget` no longer flags a `builder:` method tear-off that handles the error.** When a `FutureBuilder`/`StreamBuilder` `builder:` was a method reference (`builder: _buildContent`) rather than an inline closure, the rule fell back to a substring check of the identifier name and so fired on every tear-off, even when the referenced method fully handled `snapshot.hasError`. It now resolves the referenced method by name and inspects its body, suppressing rather than reporting when the method cannot be located (cross-library tear-off). A tear-off whose body ignores the error state still flags. No action required.
- **`avoid_mixed_environments` no longer flags environment keywords that appear only as substrings of unrelated identifiers.** The rule matched `prod`/`release`/`test`/`dev`/`live`/`local` as raw substrings, so a config class with `release_notes` and `latest` (or `developer`, `delivery`, `locale`) was wrongly reported as mixing production and development configuration. It now tokenizes identifiers into whole words — splitting on non-letters and camelCase — and matches keywords by exact word, so `release_notes`/`latest` are ignored while genuine mixes (`apiUrlProd` alongside `debugFlag`) still flag. No action required.
- **`avoid_parameter_mutation` no longer flags index assignment into a List, typed-data, or Map parameter.** Filling a caller-allocated buffer by index (`p[i] = value` on a `List`/`Uint8List`/`Map` passed in to be populated) is the out-parameter/output pattern — the same intent already exempted for `.add`/`.addAll` — yet it was flagged unconditionally, producing hundreds of false positives on generated fill-buffer tables. Index assignment into a collection parameter is now exempt; field and cascade-field assignment on a DTO parameter (the real caller-corruption case) still flags. No action required.

<details>
<summary>Maintenance</summary>

- Reworked the unreleased `prefer_dispose_before_new_instance` deferred-dispose helper to walk the AST instead of substring-matching `block.toSource()`, removing a `source.contains()` anti-pattern that the CI guard rejects and matching the disposed receiver exactly across plain, null-aware, and cascade forms. No behavior change.
- Added regression fixtures for `avoid_equal_expressions` covering compound arithmetic with identical operands (`dx * dx + dy * dy`, `(a * a + b * b) / 2`). The rule already excludes arithmetic operators (fixed in 13.12.2); these cases guard against a future regression. No behavior change.
- The extension localization tooling can now use Meta NLLB-200-3.3B (local, offline) as the primary machine-translation engine, with Google Translate as the per-string fallback — substantially higher quality on low-resource languages where the free web engine produces near-gibberish. It activates automatically when the model is on disk (reusing a download shared with other Saropa tooling) and falls back to Google otherwise; `SAROPA_SKIP_NLLB=1` forces Google-only and `nllb_engine.py --setup` downloads the model. No shipped locale strings change until the locales are regenerated and committed. No behavior change for the lint package.

</details>

## [13.12.2]

Fixes a `nullify_after_dispose` false positive that flagged `dispose()`/`cancel()`/`close()` calls on local variables, a `prefer_single_setstate` false positive that flagged `setState` calls sitting in mutually-exclusive branches, an `avoid_equal_expressions` false positive that flagged arithmetic with identical operands such as `1024 * 1024`, and an `avoid_variable_shadowing` false positive that flagged a name legitimately reused in disjoint sibling scopes (two collection-`for` loops in separate literals, or the same local in two separate `switch` cases). No action required unless you added a project-local ignore for these patterns. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **`avoid_variable_shadowing` no longer flags a name reused in a disjoint sibling or sequential scope.** Shadowing is a nesting relationship, but the checker tracked declared names in one flat set for the whole body and added the loop variable of a collection-`for` (inside a list/set/map literal) and locals in brace-less `switch` cases without ever removing them when the scope closed, so reusing the same name in a second sibling literal or a later `case` was wrongly reported. It now snapshots and restores the name set around each collection-`for` element and each switch case, matching the existing handling for statement-level loops and if/else blocks. Genuinely nested shadows (an inner block, loop, or closure hiding a still-live outer name) still flag. No action required.
- **`nullify_after_dispose` no longer flags a disposable local variable.** The rule targets nullable instance fields, but it treated any disposed `SimpleIdentifier` as a non-final nullable field, so disposing a method-local (such as a `final ui.Codec`) was falsely reported even though a local cannot be nulled and needs none. It now confirms the target is a declared field of the enclosing class before reporting. Genuine nullable fields disposed without nullification still flag. No action required.
- **`prefer_single_setstate` no longer flags `setState` calls in mutually-exclusive branches or across an `await`.** The rule counted every `setState` in a method body together, so calls in separate `if`/`else` arms, distinct `switch` cases, a `try` body versus its `catch`, or on opposite sides of an `await` (the `setState(busy=true); await …; setState(busy=false)` loading-state idiom) were reported as mergeable even though they can never run together in one synchronous pass. It now treats each branch as its own scope and an `await` as a segment boundary, flagging only when two or more `setState` calls share one synchronous straight-line path. Genuine sequential `setState` calls still flag. No action required.
- **`avoid_equal_expressions` no longer flags arithmetic with identical operands.** The matcher previously fired on any binary expression whose left and right source text matched, sweeping in legitimate constant math like `1024 * 1024`, `60 * 60`, `x * x`, and `1 << 1`. It now restricts the identical-operand check to comparison (`==`, `<`, `>`, `<=`, `>=`) and logical (`&&`, `||`) operators, where two identical sides always produce a constant or redundant result. Genuine copy-paste bugs (`a == a`, `w > w`, `flag && flag`) still flag. No action required.

## [13.12.1]

Fixes two `prefer_value_listenable_builder` false positives: one on `State` classes that back a `FutureBuilder`/`StreamBuilder` cache with a plain cache-key companion field plus one `setState` that re-runs the fetch, and one on screens whose extra rebuild state lives in a `final` controller republished by a bare `setState(() {})`. Also fixes two `prefer_reusing_assigned_local` false positives: one where a nested builder closure reuses a parameter name (such as `snapshot`) that an outer scope already declared, and one where a live value (such as a `GlobalKey`'s `currentContext`) is intentionally re-read after an `await`. Renames the `impact_report` CLI tool to `severity_report` (the old name still works). No action required unless you added a project-local ignore for one of these patterns. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **`prefer_reusing_assigned_local` no longer flags a read re-evaluated after an `await`.** A suspension point lets external state change between two reads (for example a `GlobalKey`'s `currentContext` flipping from null to mounted while the navigator boots during an awaited delay), so the cached value is no longer guaranteed equal and reusing it would reintroduce a cross-async-gap bug. The rule now treats an intervening `await` as a barrier and stays quiet; redundant re-reads with no `await` between them still flag. No action required.
- **`prefer_reusing_assigned_local` no longer flags an identical expression read against a shadowed inner variable.** When a nested closure parameter (such as a `FutureBuilder` builder whose `snapshot` shadows the outer `StreamBuilder` `snapshot`) reads the same member text as an outer local, the rule now confirms the identifiers resolve to the same binding before reporting, so reuse is never suggested across a shadow where it would read the wrong value or fail to compile. Genuine same-binding recomputes still flag. No action required.
- **`prefer_value_listenable_builder` no longer fires on the cached `FutureBuilder` idiom when the cache carries a non-`Future` key field.** A non-`Future` field now counts as single-value state only when it is reassigned inside a `setState` callback, so a cache key mutated only in helper methods (or re-initialized via a `setState` tear-off) is correctly ignored. Genuine single-value `setState` state stays flagged. No action required.
- **`prefer_value_listenable_builder` no longer fires when a `State` also rebuilds via a bare `setState(() {})` whose callback assigns no field.** A bare rebuild signals state held outside the counted fields — a `final` `TextEditingController`/`Listenable` or a parent value — that a single `ValueListenableBuilder` cannot model, so the rule now stays quiet (this also covers the common `setState(() => cb?.call())` safe-setState wrapper). Genuine single-value state still triggers. No action required.

### Changed

- **Renamed the `impact_report` CLI tool to `severity_report`** to match the three-level severity model (errors / warnings / info) that replaced the old five-bucket impact grades. Run `dart run saropa_lints:severity_report`; the old `dart run saropa_lints:impact_report` keeps working as an alias, so no action required.

<details><summary>Maintenance</summary>

- Fixed the publish audit's "Rules by Severity" table, which had been counting zero for every rule since the impact taxonomy collapsed because it still keyed on the retired `critical`/`high`/`medium`/`low` value set instead of `error`/`warning`/`info`.

</details>

## [13.12.0]

Adds support for analyzer 12, now that Flutter stable ships the `meta` version analyzer 12 requires. Flutter and Dart projects on analyzer 12 can use saropa_lints without being pinned back to analyzer 11. analyzer 13 stays excluded because it requires a newer `meta` than Flutter stable currently pins. No action required. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Changed

- Added analyzer 12 support: widened the `analyzer`/`analyzer_plugin` constraints and updated the plugin internally for analyzer 12's API changes, so it now compiles and runs on analyzer 11 and 12. analyzer 13 remains excluded because it demands a newer `meta` than Flutter stable pins, which would break `flutter pub add`. No action required.

### Fixed

- **The "issues found" popup shown after analysis no longer claims violations when the Findings dashboard is empty, and no longer offers dead "Copy Report" / "Open Report" buttons.** It now waits for the analyzer to finish writing its results before appearing, counts what the dashboard will actually display so the two always agree, and shows each button only when the report it opens exists. When a run produces no findings it shows an honest "see Output" message instead. No action required.

## [13.11.14]

Adds `prefer_reusing_assigned_local` (Recommended), which flags an expression recomputed verbatim when a local variable already holds its result and offers a quick fix to reuse the local. It is the complement of `prefer_cached_getter`: the local already exists, so the fix swaps the recompute for the local rather than creating one. No action required. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- New rule `prefer_reusing_assigned_local` (Recommended, INFO): reports a pure-read expression recomputed in the same block when a local already caches it, with a quick fix to reuse the local. It only fires when the value cannot have changed — it skips non-deterministic calls, write targets, and any recompute after the receiver or local is mutated. No action required.

## [13.11.13]

Fixes a `prefer_value_listenable_builder` false positive on `State` classes that hold one reassigned field plus a `final` collection mutated in place, and restores line-level `// ignore:` suppression for diagnostics reported on a declaration's name (such as class-level rules). No action required unless you added a project-local ignore for either pattern below. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **`prefer_value_listenable_builder` no longer fires when a `State` mutates a `final` `List`/`Set`/`Map` field in place inside `setState` (e.g. `_selected.add(v)` or `_tally[k] = v`).** That collection is a second independent state the single-value suggestion would silently drop, so the rule now treats such a widget as multi-state and stays quiet — remove any project-local `// ignore_for_file: prefer_value_listenable_builder` added for this case. A `final` collection that is only read in `setState` still triggers the rule.
- **A `// ignore:` on the line directly above a declaration now suppresses diagnostics reported on the declaration's name (class-level rules such as `prefer_value_listenable_builder` and `avoid_global_key_misuse`).** Previously only `// ignore_for_file:` worked for these, because the directive attaches to the declaration keyword rather than the name token the rule reports on — place the `// ignore:` on the line immediately above the declaration as usual and it now applies, including below a `///` doc block.

## [13.11.12]

Fixes a suppression bug where a `// ignore:` placed directly above a declaration that also carries a `///` doc comment was silently ignored. No action required. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **A `// ignore:` directly above a `///`-documented declaration is now honored.** When a doc comment preceded the declaration, the suppression silently never fired for any diagnostic reported on a child node (e.g. a map literal), so teams had no working narrow-suppression for those sites — place the `// ignore:` on the line immediately above the declaration as usual and it now applies.
- **`pass_existing_stream_to_stream_builder` no longer fires on a private cache-method that returns a stored `Stream<...>?` field.** A `stream: _getStream(filter)` accessor that rebuilds its stream only when inputs change already satisfies the rule's own advice to store and reuse the stream, so it now mirrors the cache-method exemption its `FutureBuilder` sibling already had — remove any project-local `// ignore: pass_existing_stream_to_stream_builder` added on such accessors.
- **`avoid_missing_enum_constant_in_map` documentation now describes the rule (its examples had been copy-pasted from an unrelated rule) and the supported escape hatch for intentionally-sparse tables.** The rule cannot see the (usually cross-file) read site, so it cannot tell a deliberate sparse lookup table whose absent keys are a null-handled default from a latent bug — for those tables suppress with a verified `// ignore: avoid_missing_enum_constant_in_map` on the line above the declaration, now honored even under a `///` doc comment.

## [13.11.11]

False-positive fixes for the `avoid_large_list_copy` and `prefer_single_setstate` rules. No action required unless you added a project-local ignore for the patterns below. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **`avoid_large_list_copy` no longer fires on `.toList()` used as a map-entry value or a set/list-literal element.** A `toJson()` map value such as `'items': items.map((e) => e.name).toList()` must be a concrete List because a lazy Iterable is not JSON-encodable, so the copy is structurally required, not gratuitous — remove any project-local `// ignore: avoid_large_list_copy` comments added on such literal entries.
- **`prefer_single_setstate` no longer fires on `setState` calls that live in separate closures (e.g. two buttons' `onPressed` handlers).** Such calls run on different events and can never be merged, so only multiple `setState` calls within one synchronous execution scope are now flagged — remove any project-local `// ignore: prefer_single_setstate` comments added on distinct-callback `setState` calls.

## [13.11.10]

False-positive fixes for the `require_file_exists_check`, `avoid_parameter_mutation`, `require_intl_date_format_locale`, and `prefer_value_listenable_builder` rules. No action required unless you added a project-local ignore for the patterns below. [log](https://github.com/saropa/saropa_lints/blob/v13.11.10/CHANGELOG.md)

### Fixed

- **`require_file_exists_check` no longer fires when the read is guarded by the synchronous `existsSync()` check.** Only the async `exists()` form was recognized, so the common `file.existsSync() ? await file.readAsBytes() : null` pattern was wrongly flagged — the guard is now also detected in `if` conditions, ternary conditions, and preceding statements. Remove any project-local `// ignore: require_file_exists_check` added on `existsSync()`-guarded reads.
- **`avoid_parameter_mutation` no longer fires on `notifier.value = x` for a `ValueNotifier`/`ChangeNotifier` parameter.** Mutating a notifier passed in for that exact purpose is idiomatic Flutter, not corruption of caller-owned data, so the warning was inapplicable — remove any project-local `// ignore: avoid_parameter_mutation` comments added on such notifier writes.
- **`require_intl_date_format_locale` no longer fires on `DateFormat.yMd(locale)` and other named constructors that already pass a locale.** Named constructors take the locale as their only positional argument, but the rule applied the unnamed-constructor rule (needs two arguments) and flagged every one — one project saw 16 false positives in a single file. Remove any project-local `// ignore: require_intl_date_format_locale` comments added on such calls.
- **`prefer_value_listenable_builder` no longer fires when the single state field is a `Future`/`Stream` cache backing a `FutureBuilder`/`StreamBuilder`.** That field uses `setState` to invalidate-and-re-fetch (e.g. `_future = null`), which `ValueListenableBuilder` cannot express, so the suggestion was inapplicable — remove any project-local `// ignore: prefer_value_listenable_builder` added on such async-cache states.

## [13.11.9]

A false-positive fix for the `avoid_nullable_interpolation` rule. No action required unless you added a project-local ignore for the patterns below. [log](https://github.com/saropa/saropa_lints/blob/v13.11.9/CHANGELOG.md)

### Fixed

- **`avoid_nullable_interpolation` no longer fires on `${x ?? fallback}`, on syntactic `if (x != null)` / `x != null ? ... : ...` guards over chained property access, or on developer-facing log calls (`debug`, `breadcrumb`, `debugPrint`, `print`, `dart:developer log`).** Enabling the rule on a real Flutter codebase produced floods of false positives at sites where the developer had already handled null or was intentionally logging it for diagnosis (one project saw 58 raw hits across 22 sites, half of them inside `debug()` strings where seeing `null` IS the point). Remove any project-local `// ignore: avoid_nullable_interpolation` comments added for these three patterns.

## [13.11.8]

Identical content — re-released as `13.11.9` to repackage the VS Code extension `.vsix` for Marketplace upload. See `[13.11.9]` for the release notes.

## [13.11.7]

### Fixed

- **`avoid_expensive_build` no longer fires on iteration primitives (`sort`, `where`, `map`, `fold`, `reduce`) inside `build()`.** These calls are the idiomatic shape of list-to-widget rendering (`Column(children: items.map(...).toList())` is the Flutter cookbook pattern) and produced noise without measurable cost on typical UI list sizes — one production project saw 45 WARNING hits on the first run, every one a small-list render. The rule now flags only genuinely heavy operations: `jsonDecode`, `jsonEncode`, `parse`, `tryParse`, `compute`, and the `readAsXxx` file-I/O family. Remove any project-local `// ignore: avoid_expensive_build` comments added for the iteration patterns above.

## [13.11.6]

### Fixed

- **`avoid_large_list_copy` no longer fires when the `.toList()` is structurally required by a named argument, a `??` fallback, or a getter on the result.** Named arguments like `children: items.map(...).toList()`, null-coalescing chains like `source?.where(...).toList() ?? <T>[]`, and getter access like `items.map(...).toList().nonEmpty` all need a concrete `List` and have no lazy alternative — remove any `// ignore: avoid_large_list_copy` added for these three patterns.
- **`avoid_listview_without_item_extent` no longer fires on `ListView.separated`.** The `.separated` constructor does not declare `itemExtent`, `prototypeItem`, or `itemExtentBuilder` (an extent applied to items would also apply to separators, which never share one), so the rule's correction was unfixable on `.separated`. The rule now targets `ListView.builder` only — remove any `// ignore: avoid_listview_without_item_extent` added on `.separated` call sites.
- **`avoid_listview_without_item_extent` no longer fires on inline non-scrolling `ListView.builder`.** When the call sets both `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` the inner list does not scroll and `shrinkWrap` already forces eager layout, so the extent-hint guidance does not apply and forcing one would clip variable-height rows — remove any `// ignore: avoid_listview_without_item_extent` that was added for this pattern.

## [13.11.5]

### Added

- **Code Health scanner auto-skips generated files.** Filename suffixes `.g.dart`, `.freezed.dart`, `.mocks.dart`, `.gr.dart`, `.config.dart`, `.chopper.dart`, `.gen.dart`, `.drift.dart`, and the protobuf family (`.pb.dart`, `.pbenum.dart`, `.pbgrpc.dart`, `.pbjson.dart`, `.pbserver.dart`) are excluded at file-walk time; gen-l10n output (`lib/l10n/app_localizations*.dart`, `lib/l10n/intl_*.dart`) is skipped by path. A header-marker fallback (`GENERATED CODE`, `DO NOT MODIFY`, `DO NOT EDIT`, `AUTO-GENERATED FILE` in the first 1KB) catches codegen output that lands at non-standard paths. The hero band shows an `N suppressed` pill so suppression is visible, never silent.
- **`// ignore_for_file: code_health` directive support.** Add `// ignore_for_file: code_health` at the top of a Dart file to keep it out of the Code Health scan entirely; add `// ignore_for_file: code_health:complex,undocumented` to drop only specific flags from every row in that file. The directive composes with normal analyzer ignore lists (`// ignore_for_file: avoid_print, code_health` is recognized).

### Added (Extension)

- **"Suppress in file" button on every issue in the Code Health Dashboard's expanded detail row.** Click writes a `// ignore_for_file: code_health:<flag>` directive at the top of the source file (merging with any existing ignore list — sorted, deduped, idempotent) and offers a one-click Rescan. Files-not-yet-saved are respected via VS Code's workspace file API.

### Changed (Extension)

- **Code Health Dashboard "Worst functions" rows now explain WHY each function scored low.** Flag pills (`unused`, `complex`, `undocumented`, …) used to carry only the label, so a reader had to look at four other columns to reconstruct the evidence. Each pill now reads `complex (CC 36)`, `unused (0 callers)`, `uncovered (0% tests)` etc. — the threshold the row tripped, inline. A chevron next to the score expands the row to show every issue with its threshold rule (e.g. "Flagged when cyclomatic complexity exceeds 10"), so readers can confirm what to fix without leaving the table. Expand state survives sort and filter changes. No action required.

<details><summary>Maintenance</summary>

- Publish script no longer hard-aborts when the extension locale coverage gate fails. The user is now prompted Ignore / Retry (default) / Abort, so the typical recovery — edit `extension/scripts/i18n/dictionaries.py` and rerun the generator — happens in-place without restarting the whole publish.

</details>

---

## [13.11.4]

### Added (Extension)

- **Saropa Package Dashboard hero now shows a "Scanned X ago" pill with the actual scan timestamp.** Hovering reveals the absolute date/time. Previously the Rescan button could feel like a no-op because the dashboard re-rendered with identical numbers and no recency indicator, so users had no way to tell whether the click triggered a fresh scan or returned cached results. The pill updates on every scan completion (including the trailing rescan that fires after a coalesced in-flight scan), so a click producing fresh data flips "5m ago" back to "just now". No action required.

### Fixed (Extension)

- **Package Dashboard no longer drops direct dependencies that follow a zero-indent comment.** A `# cspell:ignore foo` (or any other column-zero comment) inside `dependencies:` or `dependency_overrides:` was treated as a new top-level YAML key, exiting the active section and silently skipping every package declared after it. On the saropa contacts pubspec two `# cspell:ignore …` comments caused ~14 direct deps (`device_info_plus`, `image`, `share_plus`, `youtube_player_flutter`, …) to vanish from the dashboard and the saved `pubspec_vibrancy.json`. The parser now ignores comment and blank lines in the section-exit guard. A real top-level key still ends the section. No action required — rescan to repopulate.
- **Package Dashboard Total Size and Size Distribution now exclude dev_dependencies.** Dev-only tooling like `saropa_lints`, `build_runner`, and `lints` was being summed into the "Total Size" card and given its own bar in the Size Distribution chart, even though dev deps never reach the APK / IPA / web bundle. On projects that use `saropa_lints` as a dev dep, the chart was assigning it ~66% of "total size" — the opposite of what either surface communicates. Both now drop dev deps unconditionally; the "Include dev" toggle still controls the package table. A new caption under the chart and updated Total Size tooltip call out the exclusion. No action required.

### Fixed

- **`require_error_widget` no longer fires when error handling lives in an extension method on `AsyncSnapshot`.** Centralized helpers like `snapshot.snapLoadingProgress()` (returns the loading widget or null) and `snapshot.reportErrorIfAny()` were reported as missing error handling because the substring check at the call site never saw the literal `hasError` / `.error` text — the inspection happened inside the extension. The rule now walks the builder body and treats an inline `.hasError` / `.error` / `.stackTrace` access, any method invocation on the snapshot parameter, or any helper whose name itself contains "error" as sufficient. The same change also closes a latent false negative where a local variable named `hasErrorState` suppressed the lint via raw substring match. Remove any project-local `// ignore: require_error_widget` comments added to silence the false positive.
- **`require_late_initialization_in_init_state` no longer fires on reassignment inside `onPressed`, `onTap`, or `setState` callbacks.** Standard "View All / load more" patterns — a `late` field that is correctly initialized in `initState` and then reset to a different value inside a button or gesture callback — were incorrectly reported as build-path initialization because the rule matched the assignment via a regex over the build method's source text and could not see that the assignment was lexically nested inside a closure. The rule now walks the AST and skips assignments inside nested function expressions, and excludes any late field that `initState` already assigns. Remove any project-local `// ignore: require_late_initialization_in_init_state` comments added to silence the false positive.
- **`pass_existing_future_to_future_builder` no longer fires on the cache-method pattern.** When the `future:` argument is a private instance method (`_getContactsFuture(...)`) on a class that declares at least one `Future<...>?` field, the rule now treats the call as a cached-future accessor rather than a fresh allocation. This is the idiomatic pattern when the cached future depends on dynamic input that a `late final` field cannot model, and the rule's own correction message ("cache the Future") already endorses it. Public methods and methods on classes without a nullable Future field still fire. Remove any project-local `// ignore: pass_existing_future_to_future_builder` comments added to silence the false positive.

---

## [13.11.3]

### Fixed

- **`function_always_returns_null` no longer fires on `@override` declarations that return null.** Overriding a nullable parent member (e.g. `@override Color? get barrierColor => null;` on a no-barrier `ModalRoute`) honors the parent's contract — the override cannot widen the return type, and returning anything other than `null` would lie about absence. The rule now skips any declaration carrying `@override`; if the parent's return type were non-nullable, the override would already be a compile error, so the annotation alone is a sufficient signal. No action required.
- **`avoid_small_touch_targets` no longer false-fires on wide-band overlays.** A `SizedBox` or `Container` whose single small axis (e.g. `height: 38`) wrapped a `GestureDetector`, `InkWell`, or `InkResponse` — typically a dismiss-on-tap pill, list row, or `Positioned.fill` overlay — was incorrectly flagged as a small touch target even though the tap region spans the full parent width. The rule now distinguishes icon-sized targets (`IconButton`, `Checkbox`, `Radio`, `Switch`, `TextButton`, `ElevatedButton`, `OutlinedButton`) — where either axis under 44 px is a real concern — from region recognizers, which require both axes explicitly under 44 px to fire. Remove any project-local `// ignore: avoid_small_touch_targets` comments added to silence the false positive.
- **`prefer_layout_builder_for_constraints` no longer fires inside `static` utility methods that take a `BuildContext`.** Static helpers like `MenuUtils.popupMenuConstraints(BuildContext)` compute absolute viewport-fraction dimensions for non-widget return types (`BoxConstraints`, `Size`, `EdgeInsets`); `LayoutBuilder` is structurally inapplicable to them because there is no parent constraint to consult and the return is data, not a widget. Instance methods that take `BuildContext` (the 2026-04-28 case) still fire. Remove any project-local `// ignore: prefer_layout_builder_for_constraints` comments added to silence the false positive on static utilities.

<details>
<summary>Maintenance</summary>

- **Python publish-tooling tests now find the repo root.** The unittest suite was relocated to `scripts/modules/tests/` in May without updating its `parents[2]` repo-root index, leaving CI's test job red against every release commit since (including `Release v13.11.2`). No user impact.
- **Removed post-publish auto-bump of `pubspec.yaml`.** Releases no longer auto-commit `chore: bump version to n.n.n+1`. The next publish prompt now defaults to a patch bump only when `CHANGELOG.md` has an `[Unreleased]` section, so minor or major releases no longer have to undo a pre-committed patch decision and main no longer carries phantom version-bump commits for releases that never shipped. No user impact.
- **Stopped per-release churn of `views.help.name` across 25 locale bundles.** The static value is now the localized word "Help" alone (no version suffix); the runtime `createTreeView().title` injection in `extension/src/extension.ts` continues to display the live `(vX.Y.Z)` from `package.json`, unchanged from the user's perspective. The pre-compile sync script that stamped the version on every locale was deleted, which also fixes a long-standing duplicate-version pattern that had crept into Arabic, Persian, and Polish bundles (the stripper only matched lowercase Latin `v`, leaving translated version parens intact across releases). No user impact.

</details>

---

## [13.11.2]

### Fixed

- **Analysis reports no longer pile up — one file per VS Code session, overwritten in place** — every file save was previously generating a new `*_saropa_lint_report.log` (one observed project had 6,837 trashed reports / 659 MB in `reports/.trash/`), violating the reporter's documented contract; the reporter now overwrites the same file on each debounce cycle and also prunes trashed reports older than 14 days. No action required.

---

## [13.11.1]

Stub build for publishing. No recorded changes.

---

## [13.11.0]

This release ships a new **Saropa Project Map** dashboard — a project-wide health scan that walks your code and ranks the worst files across complexity, coverage, dead code, churn, coupling, and import cycles, then prints a prioritized worklist (and copy-paste agent prompts) so you know what to fix first. The **Code Health Dashboard** also got a major overhaul: it opens instantly with a live progress bar, can be paused/resumed/restarted/canceled, caches per-file results so re-scans are fast, and lets you slice the worst-functions table by score, search, or any combination of flag categories — then bulk-copy what's left to the clipboard. And pubspec validation no longer pesters you about files inside the pub cache or vendored third-party packages. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added

- **Project Health scan (`dart run saropa_lints:project_health`)** — walks a Dart project and reports the largest files and folders by lines (split into code, comment, and blank) and on-disk size. Per-file results stream to a `reports/.saropa_lints/health/files.ndjson` shard while only bounded aggregates stay in memory, so it stays fast and memory-flat on very large projects. Building blocks of the Saropa Project Map dashboard.
  - `--complexity` adds per-file cognitive and cyclomatic complexity, local-variable and boolean-condition density, nesting depth, class cohesion (LCOM), and a 0–100 Maintainability Index — all from a single parse per file (no element resolution, so memory stays flat).
  - `--deadweight` flags unused files and dead top-level symbols (composing the existing cross-file engine); `--coverage`/`--lcov` reads line coverage; `--git` adds per-file churn, recency, and a bus-factor proxy from history (bounded for large repos).
  - `--assets` flags pubspec assets/fonts declared but never referenced in code (heuristic — report-only, verify before deleting).
  - `--islands` finds **transitive dead private islands** — private declarations that reference each other but are unreachable from any live root, the case Dart's `unused_element` misses.
  - `--coupling` surfaces **change-coupled file pairs** (files that keep changing together in git history), and `--stubs` flags tests with no assertions.
  - `--fix` (with `--deadweight`) writes a reviewable `git rm` script — never deletes in place, never comments code out.
  - Surfaced in the extension sidebar as a new **"Saropa Project Map"** dashboard (sixth "Editor dashboards" leaf). The scan runs asynchronously with a cancellable progress notification (never freezes the editor) and renders **in-editor** with charts drawn by a vendored ECharts bundle (works offline, no CDN/network).
  - `--format markdown` emits a prioritized, 🔥-tiered "hot spots" worklist — files bad on multiple axes at once (large, complex, low-maintainability, dead, churning, uncovered) — with checkbox actions that **name the offending functions** (file + line + cognitive score), ready to hand to an AI agent. Dead-weight items carry a "verify before deleting" caveat.
  - `--format prompts` emits one self-contained, copy-paste-ready agent task per hot spot — the file, the exact functions to simplify (name/line/score), dead symbols, coverage, and churn, plus behavior-preserving constraints — so an AI can fix it without re-deriving the analysis.
  - `--update-baseline` / `--baseline <path>` capture a health snapshot and compare against it, reporting what got better or worse and **exiting non-zero on regression** (CI gate on rising complexity, growing dead code, or falling coverage).
  - Coverage runs now **warn when `lcov.info` predates the latest commit** — stale coverage is reported as unverified instead of silently trusted.
  - Optional **`.saropa_health.yaml`** config: an allowlist that silences known false positives in the heuristic sections (dead files, dead symbols, islands, assets) plus shared `exclude` globs — so the report stays trustworthy instead of crying wolf.
  - **Refactoring-ROI ranking** — a continuous "fix this first for maximum risk reduction" score combining complexity, size, git churn, and under-coverage. Surfaced in the text report and JSON (`topFiles.byRoi`); a better priority signal than the discrete 🔥 count.
  - **Natural-language exec summary** + **what-if cleanup simulator** ("removing the N unused files would delete X lines, Y% of the codebase") in the text/JSON report.
  - **Public-API doc coverage** (`%` of public declarations with `///`) and **import coupling** (fan-in/fan-out + instability, with `--deadweight`) added to the per-file metrics and summary.
  - **Health time-machine** (`--history`) — reconstructs the trajectory of size and complexity across recent git tags (via `git archive`, never touching the working tree).
  - Saropa Project Map webview gains **click-a-row-to-open-the-file** drill-down, **type-to-filter** search over the hot-spot table, a **hierarchical folder treemap** (click a folder to drill in, breadcrumb to go back), and an opt-in **in-editor "heat" CodeLens** (per-function complexity above functions) — off by default, toggled with "Saropa Lints: Toggle Saropa Project Map Heat CodeLens".
  - `--cycles` lists import cycles with a **suggested cut** per cycle (the stable→volatile edge to remove); `--cache` reuses the parse for unchanged files so rescans are faster.
  - Visual refresh of the HTML dashboard: brand-anchored orange palette (light + dark via CSS vars), a sticky banner with gradient-text title and a relative-time "scanned X ago" chip, KPI cards merged into the banner with a staggered reveal and a heat-tinted highlight on Dead files / Hot spots, a continuous orange ramp on the size treemap plus a gradient legend bar, sticky table head with a brand-colored active-sort indicator, table zebra striping, monospace path column and tabular-figure numerics, skeleton shimmer on charts until ECharts mounts, and an orange `:focus-visible` ring — all gated by `prefers-reduced-motion`.
  - Maintainability Index ranking now uses the unclamped score internally, so the worst-of-the-worst files (which all clamp to 0) are ordered correctly.
  - `--format html` writes a self-contained, theme-aware interactive report (Apache ECharts): a stat-card header, collapsible panels, a size treemap, a churn×complexity scatter, and a sortable 🔥 hot-spot table. Follows the OS/editor light/dark scheme and respects reduced-motion.
  - Also supports `--format text|json`, `--top`, and `--exclude <glob>`.

### Fixed

- **Code Health scan no longer crashes on a file the analyzer can't fully parse** — one source file with a parse-level diagnostic (for example an `await` outside an async function, common while editing) previously aborted the whole scan with an unhandled exception; it now tolerates such files and keeps scanning the rest. No action required.
- **Code Health scan starts faster and can't hang on symlinks** — file discovery now skips heavy directories (`build`, `.dart_tool`, `node_modules`, `Pods`, `.git`, …) and no longer follows symbolic links, so the scan reaches your `lib/` sources quickly instead of crawling generated output, and a symlink loop can't wedge it. No action required.
- **Code Health no longer stalls on huge generated files** — files over ~512 KB (e.g. `flutter gen-l10n` `app_localizations*.dart` at multiple MB) are skipped; parsing one previously froze the progress bar for many seconds with no health value. The panel also shows the file it is *currently* processing and a per-phase time estimate, so a slow phase reads as working, not stalled. No action required.
- **`require_https_only` no longer flags prose mentions of the `http://` scheme** — user-facing strings that name supported schemes (e.g. `'http:// or https:// URLs are supported.'`, the Korean equivalent `'http:// 또는 https:// URL만 지원됩니다.'` in a Flutter `app_localizations_*.dart` file, or a bare `'http://'` constant) are no longer reported as insecure URLs. A real URL has no whitespace between scheme and host, so strings with whitespace right after `http://` (or just the bare scheme) are descriptive text, not network requests. Hardcoded HTTP URLs (`'http://api.example.com'`, `Uri.parse('http://…')`, `http.get('http://…')`) still fire. No action required; any `// ignore:` markers added to work around this false positive can be removed.

### Added (Extension)

- **The Code Health Dashboard now opens immediately and fills in live while it scans** — instead of a notification that sat at "scanning…" with no movement, it shows a progress bar, the current file, running counts of files and functions, and a streaming preview of the worst functions found so far, so a long scan never looks frozen. While the scanner is compiling/starting the bar shows an animated indeterminate state rather than a dead 0%. No action required.
- **Pause, Resume, Restart, and Cancel controls on the Code Health scan** — a long scan can now be suspended and continued, restarted, or stopped from the dashboard, and closing the panel also stops it, so the scan no longer runs unstoppably in the background. Canceling now stops the whole scanner process tree (previously a runaway scan could keep running on Windows). No action required.
- **The scanning panel shows the extension version and the scanner-engine version** — if the project's `saropa_lints` is too old to report progress, the engine line says so instead of leaving a stuck 0%, making it obvious when the dashboard and the scanned project's package versions don't match. No action required.

### Changed (Extension)

- **Code Health scan readout is easier to read** — file and function counts now use thousands separators, and the elapsed/remaining times show minutes and hours (for example `1h 52m`) instead of a raw seconds count. The per-phase progress percent shows one decimal place so it visibly moves on a multi-thousand-file phase. No action required.
- **Click a row in the live "problems found" preview to jump to that function** — each row opens the file at the function's line in the editor. No action required.
- **File paths in the scan panel keep the filename visible** — long paths now collapse the leading directories instead of cropping the end, and the worst-functions rows line up in fixed columns. No action required.
- **The Code Health scan no longer reports third-party code** — vendored packages under `dependency_overrides/` are skipped, so the worst-functions list stops surfacing un-actionable rows (such as a bare `==`) from code you don't own. Operator overrides in your own code are now labeled (`operator ==`) rather than shown as a bare symbol. No action required.
- **Code Health scans are now incremental** — each file's parse is hashed and cached, so a file unchanged since the last scan is not re-parsed, and within a single scan no file is parsed twice across the parse and usage phases. The cache lives at `.saropa/project-vibrancy-cache/mvp_cache.json` and self-invalidates per-file on content change and globally on engine upgrade; delete the folder to force a cold scan. No action required.
- **Code Health Dashboard report is the full project, not a 200-row slice** — the worst-functions table, the search filter, and the KPI tile clicks now operate on every scored function. Previously clicking "Test drift: 974" only showed the handful of test-drift rows that happened to be in the worst-200, which read as a broken filter. The row count above the table now shows `showing N of TOTAL` truthfully. No action required.
- **Every Code Health scan is saved to a JSON file you can share** — written to `reports/<yyyymmdd>/<yyyymmdd>_<HHmmss>_saropa_code_health.json` under the project root, with a strip under the KPI cards showing the path and Copy / Open / Reveal-in-Explorer buttons. The path is also clickable to copy. No action required.
- **Code Health Dashboard rows redesigned for readability** — the redundant grade column is gone (the grade duplicated the score axis); the score is a colored whole-number pill (red→amber→green) with readable black text instead of the previous low-contrast yellow-on-yellow grade pill; function names are clickable and open the file at the line; file paths collapse the directory and keep the basename whole; a new *Changed* column shows how long ago the file was last touched (`3d`, `5w`, `2mo`). No action required.
- **Column sort indicators are now honest** — the active column shows an arrow in the actual sort direction; other columns show nothing. Previously every column displayed an up-arrow forever, which read as decoration rather than state. No action required.
- **Header shows the number of problem functions** — the hero now carries a `N problems` chip (functions scoring under 50, i.e. grades D / E / F) alongside the function count and gate status; the duplicated hero gauge (which redundantly displayed the same average score with different rounding) was removed. No action required.
- **`complex` is now a KPI tile and click-to-filter category** — alongside Unused / Uncovered / Stub-tested / Suspicious coverage / Test drift, so high-complexity functions are surfaced and filterable the same way as the other flag classes. No action required.
- **The Code Health Dashboard no longer freezes on large projects** — function rows now ship to the webview as a JSON data block and the script renders a 500-row window into the DOM, so a project with tens of thousands of functions opens responsively and column-header sort is instant. The "Show next 500" button at the bottom of the table reveals the next chunk on demand. No action required.
- **Hide boilerplate methods toggle (default ON)** — a new toolbar checkbox hides operator overrides (`==`, `<`, `[]`, …) and the equality / serialization / dispatch boilerplate (`hashCode`, `toString`, `noSuchMethod`, `copyWith`, `props`, `fromJson`, `toJson`, `fromMap`, `toMap`). These dominate "worst functions" lists in real projects but rarely deserve triage attention; uncheck the box to see them. No action required.
- **Bulk-copy methods for analysis is filter-driven** — narrow the Worst Functions table with the new *Score ≤ N* threshold, the search field, the *Hide boilerplate* toggle, and the KPI tiles (multi-select — click multiple to combine flags, e.g. `unused` AND `complex`), then click *Copy filtered (N)* to send every visible row to the clipboard as `file:line  function-name  (score, flags)`, one line per row, ready to paste into a chat or issue. No per-row checkboxes; the filters are the selection. The active-filter strip lists every applied filter (search, score threshold, each flag) with its own dismiss button. No action required.
- **The Score column now explains what it measures** — hovering the column header shows the composite formula (`40% coverage + 25% usage + 15% age + 15% complexity + 5% documentation`), and Usage / Coverage / Complexity / Changed columns gained similar tooltips so a reader doesn't have to guess what each axis means. No action required.

### Fixed (Extension)

- **Pubspec validation and Package Vibrancy diagnostics no longer fire on third-party packages** — opening a vendored `pubspec.yaml` under the pub cache (`Pub/Cache/hosted/…`, `~/.pub-cache/…`) or under `.dart_tool` / `node_modules` was producing `saropa-pubspec`, `saropa-sdk`, and `Package Vibrancy` diagnostics on files you can't edit, polluting the Problems panel. The listener now skips any pubspec outside the open workspace and any pubspec inside a known cache or generated directory. No action required.
- **"Score dipped below N" toasts no longer repeat on every save when the score oscillates near a band edge, and no longer fire from one-off partial-sweep dips** — each crossing of a band (90 / 80 / 70 / 60 / 50) now fires at most once and only re-arms after the score recovers clearly above that band (5 points), and a downward crossing is held one snapshot before firing so an intermediate partial sweep that briefly skews the score (the case where the dashboard reads 93 while a stale toast had already said "below 50") is dropped quietly when the next snapshot recovers. Set `saropaLints.regressionNudge.enabled` to `false` to silence regression toasts entirely.
- **"No errors!" celebration toast no longer repeats when the error count flickers between 0 and 1** — the toast is now persisted per workspace and only re-fires after errors return and are cleared again, so an intermediate analyzer batch that briefly drops and re-adds an error stops producing a stream of identical celebrations. No action required.

<details><summary>Maintenance</summary>

- When the extension runs as its own in-development build (F5 from the repo), the Code Health scan now executes the in-repo `saropa_lints` CLI against the opened project (via `--path`) instead of the project's pinned package version, so new CLI behavior can be tested without a path override. Installed builds are unaffected — they still use the project's own CLI.
- `git blame` in the vibrancy scan now passes the scanned project as its working directory, so age scoring stays correct when the CLI process runs from a different directory than the scanned project.
- Health time-machine (`--history`) now refuses to inherit a parent repo's tags. `git tag` climbs the directory tree, so running the scan on a subdirectory of another repo (the case that surfaces here is the publish script redirecting `TMP` into `build/test_tmp` inside this repo) silently reported the parent's tags as the project's own history. The scan now requires the scanned path to host its own `.git` entry (directory or worktree file) before asking git anything.
- Publish-time US-English spelling audit now also flags British forms embedded in CamelCase identifiers (e.g. `_ScanCancelled`, `OnColourPicked`); the original word-boundary regex missed these because there is no `\b` between two letters of the same identifier. The audit also exempts archived plan docs under `plans/history/` so old write-ups don't keep tripping the gate after their work has shipped. <!-- cspell:ignore Cancelled Colour -->

</details>

---

## [13.10.4]

The `avoid_money_arithmetic_on_double` rule stops mistaking layout math for money — names like `trailingTotal` or `widthTotal` that add up pixel widths are no longer flagged, while genuine money totals like `totalPrice` and `invoiceTotal` still are. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Fixed

- **`avoid_money_arithmetic_on_double` no longer flags non-financial `*Total` aggregates** — identifiers ending in `total` (`trailingTotal`, `widthTotal`, `angleTotal`, and single words like `cartTotal`) are pixel/geometry sums rather than currency, so they are now exempt unless paired with a real money word such as `totalPrice` or `invoiceTotal`. No action required; any `// ignore:` markers added to work around this false positive can be removed.

---

## [13.10.3]

The `prefer_spread_over_addall` style hint stops nagging when you mutate a collection in place — clearing a list and re-filling it, for example — where spread syntax simply can't apply. The `avoid_large_list_copy` rule no longer warns on `.toList()` calls where a concrete list is actually required. The lint score in the status bar no longer flashes a misleading red 0% while a scan is still in progress, and a low score no longer paints the status bar red. The Findings dashboard's health gauge is steadier too — it no longer collapses to an empty dot or whiplashes from A to E while a scan is running. Its Top Rules list now shows the 10 noisiest rules, sorts on a header click, and expands each rule to reveal its full message and the files it affects. And `move_variable_closer_to_its_usage` now understands that loop accumulators and long initializers genuinely can't move, so it stays quiet on them. [log](https://github.com/saropa/saropa_lints/blob/v13.10.3/CHANGELOG.md)

### Fixed

- **`prefer_spread_over_addall` no longer flags in-place mutation that has no spread equivalent** — it previously fired on every `addAll` call, including `clear(); addAll(items);` on the current object (where there is no receiver to spread into) and unrelated user-defined `addAll` methods. It now reports only `addAll` on a `List`/`Set`/`Queue` receiver that exists to spread into. No action required; any `// ignore:` markers added to work around this false positive can be removed.
- **`avoid_large_list_copy` no longer flags `.toList()` that is structurally required** — a `.toList()` used as a cascade target (`...toList()..sort()`), as a branch of a ternary assigned to a typed `List`, or bounded by `take(N)` is no longer reported, because a concrete list is unavoidable or the copy is already bounded. No action required.
- **`move_variable_closer_to_its_usage` no longer flags variables that cannot move closer** — it now measures distance in intervening statements instead of source lines and stays silent when the first use is nested inside a loop, branch, or block the declaration must enclose, clearing false positives on loop accumulators, multi-line initializers, and values read across sibling branches. No action required; any `// ignore:` markers added to work around this can be removed.

### Added (Extension)

- **Each Top Rules row on the Findings dashboard now expands** to show the rule's full message and the files it affects, with each file clickable to jump straight to it — triage a noisy rule without scrolling down to the findings list. No action required.

### Fixed (Extension)

- **The status bar no longer shows a false 0% lint score from an in-progress scan** — the score divides violations by the files analyzed so far, so a partial editor sweep could crater it; it now appears only once a full analysis has covered enough of the project. If the tooltip says "partial scan", run a full analysis to get the score.
- **The status-bar "updates available" count no longer over-reports** — it had counted packages whose update status was undetermined (offline / no pub.dev data) as available updates; it now counts only packages with a real newer version. No action required.
- **The Findings dashboard health gauge no longer collapses to an empty dot** — its entrance animation restarted on every refresh and got stuck near the empty frame; the ring now paints the true score instantly on every render. No action required.
- **The Findings dashboard "Group by" dropdown is now legible when open** — the option list inherited a low-contrast highlight; it now uses the editor's dropdown colors. No action required.

### Changed (Extension)

- **Saropa now uses a single status-bar item instead of two** — the score/vibrancy summary and the separate finding-count badge were merged, so a high score no longer sits next to a contradictory "⚠ N" count; the count is now appended to the one item (e.g. `Saropa: 98% ▼2 · V8/10 · ⚠ 96`) and clicking it opens the Findings Dashboard. No action required.
- **The lint score no longer colors the status bar red** — a low score is informational, not an error, so the status-bar background now stays neutral. No action required.
- **Suppressed packages no longer skew the vibrancy score, "updates available", or problem counts** — dismissing a package now removes it from the status-bar numbers and the tree's update/problem badges alike, while the "packages scanned" line shows how many are suppressed so the totals reconcile. No action required.
- **The Findings dashboard health grade no longer whiplashes from A to E mid-scan** — it dims to a "computing" state while an analysis is streaming results in, then reveals the settled grade once the run finishes. No action required.
- **The health gauge shows the score without the "/100" suffix** — the denominator was redundant next to the letter grade. No action required.
- **The Findings dashboard Top Rules table is trimmed to the 10 noisiest rules and its Rule / Count / Severity headers are now click-to-sort** — fewer, richer rows that you can reorder for triage. No action required.

<details><summary>Maintenance</summary>

- Wired the `vibrancy-state` unit tests into the test build (they had drifted out and stopped compiling) and refreshed their fixtures; added coverage for the shared `isUpdatable` predicate and suppressed-package exclusion.
- Added a `filesExpected` field to `violations.json` (the project-file denominator) so the extension can detect a partial analysis.
- Documented the empty `cross_file_fixture/test/*_test.dart` files as mirror-test presence markers (existence-only fixtures, not stub tests) to stop them reading as broken.

</details>

---

## [13.4.2] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 12.6.1.

