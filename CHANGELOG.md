<!-- markdownlint-disable-file MD024 MD033 -->
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

## [13.12.3]

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

### Fixed

- **`require_file_exists_check` no longer fires when the read is guarded by the synchronous `existsSync()` check.** Only the async `exists()` form was recognized, so the common `file.existsSync() ? await file.readAsBytes() : null` pattern was wrongly flagged — the guard is now also detected in `if` conditions, ternary conditions, and preceding statements. Remove any project-local `// ignore: require_file_exists_check` added on `existsSync()`-guarded reads.
- **`avoid_parameter_mutation` no longer fires on `notifier.value = x` for a `ValueNotifier`/`ChangeNotifier` parameter.** Mutating a notifier passed in for that exact purpose is idiomatic Flutter, not corruption of caller-owned data, so the warning was inapplicable — remove any project-local `// ignore: avoid_parameter_mutation` comments added on such notifier writes.
- **`require_intl_date_format_locale` no longer fires on `DateFormat.yMd(locale)` and other named constructors that already pass a locale.** Named constructors take the locale as their only positional argument, but the rule applied the unnamed-constructor rule (needs two arguments) and flagged every one — one project saw 16 false positives in a single file. Remove any project-local `// ignore: require_intl_date_format_locale` comments added on such calls.
- **`prefer_value_listenable_builder` no longer fires when the single state field is a `Future`/`Stream` cache backing a `FutureBuilder`/`StreamBuilder`.** That field uses `setState` to invalidate-and-re-fetch (e.g. `_future = null`), which `ValueListenableBuilder` cannot express, so the suggestion was inapplicable — remove any project-local `// ignore: prefer_value_listenable_builder` added on such async-cache states.

## [13.11.9]

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

## [13.10.2]

This release cleans up the extension's translated interface. The Saropa brand name is no longer turned into local scripts, stray placeholder gibberish has been cleared out of several languages, and a batch of toolbar and status strings that were stuck in English are now translated across all 24 languages. The Help panel also shows the version you actually have installed. [log](https://github.com/saropa/saropa_lints/blob/v13.10.2/CHANGELOG.md)

### Fixed (Extension)

- **The "Saropa" brand name is no longer translated or transliterated in any language** — it had been rendered in local scripts (Arabic, Hindi, Bengali, and others) across the localized UI, and now stays "Saropa" everywhere. No action required.
- **Removed leftover translation-marker gibberish from several non-English strings** — fragments like `q0q` had leaked into some translated labels and now no longer appear. No action required.
- **The Help panel title shows the version you actually have installed** — it had a fixed version baked into each translation that drifted out of date every release; it is now read live at runtime. No action required.
- **Translated UI strings that were previously stuck in English across all 24 languages** — toolbar and menu entries (Export, Filter & focus, Reload from disk, Re-enable disabled rules, severity filter) and the package update/vulnerability counts are now localized. No action required.

<details><summary>Maintenance</summary>

- Rewrote the locale generator's placeholder shield to use an ASCII sentinel with a strict integrity check, brand-term protection, and a self-healing cache, so machine translation can no longer ship transliterated brand names or leftover marker residue; poisoned cache entries re-translate automatically on the next run.
- The publish pipeline now machine-translates newly added English strings and gates the release on full locale coverage, so untranslated or incomplete UI can no longer ship.

</details>

---

## [13.10.1]

### Fixed

- **`use_setstate_synchronously` no longer flags `setState` after an `if (cond || !mounted) return;` guard** — the early-exit recognizer now treats either operand of an `||` disjunction as a valid not-mounted check, matching how it already handles `&&` for positive `mounted` guards. No action required; any `// ignore:` markers added to work around this false positive can be removed.

<details><summary>Maintenance</summary>

- **Stopped tracking `packages/saropa_lints_api/pubspec.lock`** — it had been committed before the `.gitignore` rule that ignores sub-package lockfiles, so the index contradicted the stated intent (consumers re-resolve; tracked sub-package locks only create merge churn). Now untracked via `git rm --cached`.
- Consolidated the build backlog and planning index into `ROADMAP.md` and dropped the eight already-shipped platform-config rules from it; internal planning docs only, no packaged behavior change.

</details>

---

## [13.10.0]

Findings dashboard cleanup: the duplicate Impact filter row, Group-by-Impact option, and Impact-mix donut are gone — Severity is now the single axis (Impact had mirrored Severity since the 5→3 collapse). The "More" menu is grouped into Export / Filter / Open / System sections with separators, file paths in the findings table truncate from the front so the filename stays visible, the redundant toolbar Refresh has moved into the menu as "Reload from disk", and a new "Re-enable disabled rules…" item lets you recover from an accidental disable without leaving the dashboard. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Added (Extension)

- **New More-menu item "Re-enable disabled rules…"** opens a multi-select quick-pick over the rules currently disabled in `analysis_options_custom.yaml` and re-enables the ones you tick — closes a gap where disabling a rule from the Findings dashboard left no in-dashboard path back. No action required.
- **New More-menu item "Reload from disk"** in the System section re-renders the dashboard from the existing `violations.json` without re-running the analyzer; replaces the visible toolbar Refresh button which was indistinguishable from Run analysis. No action required.

### Changed (Extension)

- **Findings dashboard "More" menu is now grouped** into Export / Filter & focus / Open dashboard / System with section headers, horizontal separators between groups, and a uniform-width icon column so labels align — the flat 17-item list was visually inscrutable. No action required.
- **File paths in the findings table truncate from the front instead of the end** so the filename (the part you most need to read) stays visible when the column narrows; the full path is still in the hover title. No action required.

### Removed (Extension)

- **Duplicate Impact filter UI removed from the Findings dashboard** — the second pill row, "Group by Impact" option, Impact-mix donut chart, and impact chips on the active-filter strip all mirrored Severity since the 5→3 collapse on 2026-05-03 and added no information. The underlying `Violation.impact` / `byImpact` fields in `violations.json` are kept for back-compat with external consumers. No action required.
- **Visible toolbar Refresh button removed** in favor of "Reload from disk" inside the More menu (see Added). The hidden `#btn-refresh` stub is retained so existing keybindings and selectors continue to resolve. No action required.

---

## [13.9.2]

<details><summary>Maintenance</summary>

- **The pub.dev and VS Code Marketplace listings now share one README** — `extension/README.md` is gitignored and regenerated from the root `README.md` at publish time (same pattern already used for `extension/CHANGELOG.md`), so the package and extension descriptions can no longer drift apart.

</details>

---

## [13.9.1]

### Fixed

- **`avoid_positioned_outside_stack` no longer fires when `Positioned` is passed via a `List<Widget>` (or `child:`) parameter to a custom widget that internally spreads it into a `Stack`** — e.g. `FocusCard(backgroundLayers: [Positioned(...)])` where `FocusCard` is a user-defined card that hosts a Stack inside its own `build()`. The ancestor walk now treats the direct custom-widget parent as indeterminate (its internal layout is invisible to static analysis); Flutter framework widgets like `Column`/`Row` are still walked past, so the real bug `Column(children: [Positioned(...)])` continues to lint. No action required — remove any `// ignore: avoid_positioned_outside_stack` you added for this shape.

### Added (Extension)

- **Package Dashboard now explains the project grade** — clicking the radial gauge (or the **Project Package Grade** summary card) opens a new "Why this grade?" panel showing the score distribution, risk signals (flagged / vulnerable / updates available), the five lowest-scoring packages, and the score-to-grade thresholds. Every row inside the panel is interactive: distribution and signal entries filter the package table, and the lowest-scoring entries jump straight to the relevant row. No action required.

### Fixed (Extension)

- **Package Dashboard now shows code size, not tarball size, across every surface** — the Size column, Total Size summary card, package detail panel, package comparison "Code Size" dimension, sidebar detail view, and Size Distribution chart all now read what each package contributes to your built app (its `lib/` plus declared assets), with the gzipped archive total as a labeled fallback when the analyzer hasn't run yet. The Package Dashboard's Health Score panel also gains `+example` / `+tests` / `+tools` / `+docs` rows when a package ships those folders, so the bonus already feeding the overall score is now visible row-by-row instead of invisible. Previously the v13.9.0 fix only landed in the editor hover; every dashboard surface still showed the old tarball number (e.g. `audioplayers` rendering as 20,535 KB on the Dashboard table). No action required.
- **Package Dashboard size tooltips now describe code size in every language** — the Size column header, Total Size caveat, and Footprint toggle tooltips said "archive size before tree shaking" in all 25 shipped locales, contradicting the corrected number shown beside them. The copy now explains the column reports code size (lib + declared assets) and falls back to archive size only when code size is unavailable. No action required.
- **Package Dashboard radial grade gauge now paints the arc again** — under the strict webview CSP the inline CSS variables that drove the stroke length were being dropped, so only a single rounded line-cap dot was visible next to the letter grade. The arc and its load animation now use SVG presentation attributes and SMIL, which survive the CSP. No action required.
- **Package Vibrancy toolbar no longer shows a redundant "Search packages" label next to the search box** — the label is now hidden from view (it remains for screen readers) so the placeholder text inside the input is the only visible cue. No action required.
- **Package Vibrancy toolbar buttons read as buttons in every theme** — Rescan / Open Project / Copy / Save / pubspec.yaml had a full-pill shape and a transparent border fallback that disappeared on themes that don't define `button.border`. Buttons now use a softer rounded-rect (6px) and fall back to `widget.border`, matching the FOOTPRINT segmented control which moved off the full-pill shape for the same reason. No action required.
- **"All" age-slider label no longer reads as the value of the Preset dropdown** — the divider between the Published-age group and the Preset group is now higher-contrast, the trailing gap is wider, and the slider's max-value readout sits in a small chip so it stops blending into the neighboring "Preset" label. No action required.

<details><summary>Maintenance</summary>

- Added dedicated tests pinning the code-size dashboard behaviors (size cell prefers `codeSizeBytes`, archive fallback, on-disk tooltip asymmetry, Health Score maintainer-quality rows, `codeSize` JSON export field, "Code size" column tooltip copy).
- Added `comparison-ranker.test.ts` to the test `tsconfig` include list — the file existed but never compiled, so its stale "Archive Size" dimension assertion went unrun.

</details>

---

## [13.9.0]

The extension UI is now fully translated into every shipped non-English language — sidebar, dashboards, status bar, command palette, and webviews no longer fall back to English. Package Vibrancy stops over-flagging packages that ship demo media or sample servers, drops misleading "replace with itself" upgrade hints, and rewards packages that include example, test, and doc folders. The Package Dashboard also gains collapsible sections, attaches tooltips to the cards they describe, hides toolbar buttons when there's nothing to do, and renders the Dependency Network diagram cleanly instead of as overlapping garbled text. [log](https://github.com/saropa/saropa_lints/blob/v13.9.0/CHANGELOG.md)

### Added (Extension)

- **Extension UI now fully localized across all 24 shipped non-English locales** — every string in the sidebar, dashboards, status bar, command palette, and webviews now has a curated translation for ar, bn, de, es, fa, fil, fr, he, hi, id, it, ja, ko, nl, pl, pt, ru, sw, th, tr, uk, ur, vi, and zh. Previously many UI fragments fell back to English in non-English locales because the dictionary was sparse and a defensive guard in the translator was silently reverting legitimate translations whose placeholders sat at non-leading positions. No action required.
- **Collapsible Package Dashboard sections** — Size Distribution, Filters, and the Packages table each sit inside their own expander now so you can fold any of them away to focus on the rest of the view; all three default to open so the landing experience is unchanged. No action required.
- **Package hover now reports code size and credits maintainer-quality folders** — the primary "size" line shows what a package actually contributes to your built app (its `lib/` plus assets it declares for bundling), not the pub.dev tarball total. The hover separately shows the on-disk total with a per-folder breakdown so you can see when a tarball is dominated by demos or test fixtures, and packages that ship `example/`, `test/`, `tool/`, or `doc/` now earn positive health-score components instead of bloat penalties. No action required.

### Fixed (Extension)

- **Vibrancy bloat rating no longer over-reports packages that ship sample media or demo servers** — bloat now scores on code size (what reaches your app), not the gzipped tarball, so packages like `audioplayers` (which carry tens of MB of demo audio in `example/`) drop from a 9/10 bloat alarm to a low rating that matches their actual install cost. The per-app Total Size budget and the comparison view's size dimension switched to the same measure. No action required.
- **Self-replacement entries removed from the curated package issues list** — 30 known-issue entries (`audioplayers`, `file_picker`, `flutter_local_notifications`, `flutter_typeahead`, and others) listed themselves as the replacement, which produced misleading "Replace with X" UX where X was the same package the user already had. Those entries still flag the affected old versions, but the upgrade path comes from the version range rather than a self-pointing replacement. No action required.

- **Package Dashboard toolbar buttons hide when their action is a no-op** — the "← Back" package-navigation button, the "× Clear" chart filter indicator, and the "↻ Reset view" toolbar button now stay hidden whenever there's nothing to act on (no nav history, no live chart filter, view state matches defaults). Back was previously shown disabled, Reset view was always shown, and the chart Clear strip could survive a session restore that referenced a package no longer in the chart. No action required.
- **Size Distribution bars render at their correct width and color again** — after the chart was wrapped in a `<details>` expander, the bar-fill elements rendered at 0% width with no visible color because the inline `--bar-width` custom property failed to apply. The renderer now emits the style on a single attribute line (matching the Findings Dashboard's working pattern) and the chart script re-applies the width via `setProperty()` at init from a duplicate `data-bar-width` attribute, so the bars survive whichever rendering path the webview takes. No action required.
- **Package Dashboard caveats now attach to the cards they describe** — the tree-shaking footnote ("Archive sizes before tree shaking…") now appears as a tooltip on the **Total Size** card, and the activity-threshold legend ("90d = stale, 180d = dormant") now appears in each grade card's tooltip (Vibrant/Stable/Outdated/Abandoned/EOL). Both previously sat in a floating note at the bottom of the summary block where readers couldn't easily connect them to the relevant data. No action required.
- **Package dashboard Dependency Network panel rendered as garbled overlapping text** — the diagram now lists each transitive once on the right column with edges fanning in from every direct that pulls it in, instead of duplicating shared transitive labels at colliding Y positions. The panel also moved below the package table so it no longer pushes the table off-screen. No action required.

<details><summary>Maintenance</summary>

- **Publish script now resolves dependencies in every workspace package before any analyze runs.** A new "Dependencies" step in `scripts/publish.py` runs `dart pub get` in the project root and in every `packages/*/` with a `pubspec.yaml`, ahead of the audit, format, analyze, and test gates. Previously a stale or missing `.dart_tool/package_config.json` in `packages/saropa_lints_api/` surfaced as thousands of phantom `package:test/test.dart` errors during the audit's analyze step, which forced a manual abort + two-directory `dart pub get` + restart of the whole pipeline.
- **Translation pipeline (`extension/scripts/i18n/`) modernized.** `generate_translations.py` now prints colored per-locale progress (with Windows VT enabling), labels the prefetch step with an explicit "translating N new strings via Google…" count, persists the MT cache after every locale so a Ctrl-C never throws away paid-for Google calls, and exits cleanly (130) instead of dumping a Python traceback. A final coverage audit writes `extension/reports/i18n_translation_audit.md` with a cross-locale rollup (most-missed strings first), paste-ready Python dict stubs per locale, and a per-locale missing list. The translator's placeholder-rename guard now compares placeholders as a *set* (Bengali, Japanese, Korean legitimately reorder `{count}`/`{ruleCount}`) and its MT-garbage "leading-garbled" guard is skipped for curated dictionary entries (Arabic, Ukrainian, Turkish, etc. legitimately put modifier words before the first placeholder). Curated `"X": "X"` passthrough entries in `dictionaries.py` are now counted as translated rather than missing in the audit.

</details>

---

## [13.8.0]

The Findings Dashboard now lets you reconcile its count with the Problems panel without leaving the window: clickable pills in the hero status line surface analyzer findings (built-in Dart SDK lints plus any third-party `custom_lint` plugins like riverpod_lint) and analyzer-side TODOs that fall outside saropa's rule set, plus a discoverability prompt for the existing TODO/HACK workspace scanner. All three default off; one click toggles each on or off, and none feed health score, KPI cards, or filtering. [log](https://github.com/saropa/saropa_lints/blob/vX.Y.Z/CHANGELOG.md)

### Added (Extension)

- **Findings Dashboard supplementary pills (#224)** — three clickable pills in the dashboard hero surface non-saropa analyzer findings, analyzer-side TODO diagnostics, and the existing TODO/HACK scanner toggle directly on the surface that has the discoverability gap. New workspace settings `saropaLints.includeOtherAnalyzerFindingsInDashboard` and `saropaLints.includeAnalyzerTodosInDashboard` (default off); commands `Saropa Lints: Toggle Show Other Analyzer Findings on Dashboard`, `... Toggle Show Analyzer TODOs on Dashboard`, and `... Toggle TODO/HACK Workspace Scanner` invokable from the command palette. No action required.

---

## [13.7.2]

### Added (Extension)

- **Auto-analyze on dependency changes** — the extension now watches `pubspec.lock` and automatically re-runs `dart analyze` when dependencies change (after `pub get` / `pub upgrade`), with a 10-second cancel-restart debounce to coalesce rapid lock-file rewrites. Controlled by the new `saropaLints.runAnalysisAfterDependencyChange` setting (default: on); toggle from the sidebar Settings row or command palette. No action required.

<details><summary>Maintenance</summary>

- Tracked `reports/organize_reports.py` in git by switching `.gitignore` from directory-level to content-level ignore with a negation rule; also added `example*/reports/` to `.gitignore` so generated report output under example directories stays untracked.

</details>

---

## [13.7.1]

### Fixed

- **`avoid_string_substring` no longer fires on indexOf-guarded, loop-bounded, or early-exit-guarded substring calls** — the rule now recognizes `while`/`for` loop conditions, preceding `if (idx == -1) return` guards, and if-conditions that reference substring arguments as evidence of bounds safety. No action required.
- **Analyzer v9 `useDeclaringConstructorsAst` crashes resolved** — all `.namePart.typeName` accesses (132 sites) and `.namePart.typeParameters` accesses (4 sites) now use safe `nameToken` / `nameTypeParameters` extensions that fall back to the pre-gate `.name` / `.typeParameters` API; additionally, `_wrapCallback` now catches `UnsupportedError` globally so any remaining gated property on any analyzer version skips the rule gracefully instead of crashing the plugin. Closes the remaining failures reported in [#224](https://github.com/saropa/saropa_lints/issues/224). No action required.


### Fixed (Extension)

- **Regression-nudge toasts no longer stack during slow linting** — when the analyzer writes partial results over several seconds the score can cross multiple thresholds downward, previously firing a separate notification for each; now the nudge debounces for 3 seconds and shows only the worst threshold crossed. No action required.

<details><summary>Maintenance</summary>

- Ran `dart pub get` in `packages/saropa_lints_api/` to resolve missing `test` dependency; added source comment noting sub-package requires its own dependency resolution.

</details>

---

## [13.7.0]

The VS Code extension dashboard is now fully internationalized, and two analyzer-facing bugs are fixed — a false positive on Face ID rules when the plist key was already present, and a crash on projects running analyzer v9.

### Changed (Extension)

- **Dashboard i18n: remaining webview strings routed through runtime keys** — Code Health, Config Dashboard suppressions strip, Lints Config mirrors, Related Rule Telemetry, sidebar layout panel, and Security Posture tree now resolve all user-facing text through `l10n()` instead of hardcoded English literals; locale files regenerated for all 24 shipped locales. No action required.
- **Language picker: reload prompt and multilingual discoverability** — changing the UI language now prompts to reload the window (manifest NLS labels like sidebar and command titles require a VS Code reload to take effect); the command palette entry shows the word "Language" in five languages so non-English speakers can find it; the "Auto" option shows which locale it resolves to. No action required.

### Fixed

- **Analyzer v9 `useDeclaringConstructorsAst` crash** — all 335+ `.body.members` call sites now use safe `bodyMembers` / `bodyConstants` extensions that fall back to the pre-declaring-constructors API when the gate throws; projects on `analysis_server_plugin ^0.3.4` with `analyzer 9.x` can run `dart analyze` without the plugin crashing. No action required.
- **`require_ios_face_id_usage_description` false positive when Info.plist key is present** — the rule's early-return guard failed to locate the project root when the analyzed file was resolved via a non-filesystem URI scheme (`package:`, `dart:`, etc.), causing the guard to fall through and fire on every `LocalAuthentication` call site even when `NSFaceIDUsageDescription` was already configured; URI handling and Windows path normalization in `InfoPlistChecker` are now robust. No action required.

<details><summary>Maintenance</summary>
- **Runtime i18n function renamed `t()` → `l10n()`** — the translation lookup function in `runtime.ts` is now `l10n()` for clarity; all 492 call sites updated. No action required unless you import `t` from `src/i18n/runtime` in a fork.

</details>

---

## [13.6.0]

This release improves how you steer large findings lists and repeat searches across sessions (multi-key sort, bulk JSON copy, and workspace-persisted recents). It tightens RTL behavior for stack toggles, adds cross-file CLI defaults you can commit in **`analysis_options.yaml`**, gives IDE troubleshooting clearer native-plugin-first guidance, and ships a **`verify-nls-keys`** check for Marketplace manifest parity. Score and dashboard consistency improvements from earlier work remain in place. [log](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG.md)

### Changed (Extension)

- **Findings Dashboard consistency and run UX** — score/toast regression nudges now use the same visible-findings basis as the dashboard (ending stale-history vs dashboard-empty mismatches), and the dashboard now shows an in-panel progress bar with duplicate-click guard plus an automatic full refresh after analysis completes; no action required.
- **Findings triage ergonomics** — you can Shift+click a second column header as a tie-breaker (labeled ① / ②), checkbox-select multiple findings, and copy the selection as JSON; large tables defer off-screen row work via `content-visibility` so scrolling stays smoother; recent text-filter queries now persist **per workspace** across reloads alongside the Known Issues catalog and Command Catalog search popovers; no action unless you routinely clear Workspace State intentionally.
- **Lints Config pack toggles RTL** — the enable switch knob now tracks right-to-left layouts using logical positioning so the knob lands on the expected side; reload the dashboard if you switched UI direction mid-session; no YAML change needed.
- **Manifest localization guard** — **`npm run verify-nls-keys`** (under **`extension/`**) asserts every **`%…%`** placeholder from **`extension/package.json`** resolves in **`extension/package.nls.json`**, catching missing English strings before Marketplace packaging; contributors should run it after editing contributed labels or command titles.
- **More shipped UI locales filled** — **`package.nls.*`** and **`src/i18n/locales/*`** now include machine-translated copy for **`bn`, `fa`, `fil`, `he`, `id`, `pl`, `sw`, `th`, `tr`, `uk`, and `vi`** (plus corrections for **`de`**, **`nl`**, and **`ru`** dependency-count wording); regenerate with **`SAROPA_I18N_MACHINE_TRANSLATE=1`** if you fork strings. Hebrew uses Google target code **`iw`** in the generator.
- **Package Vibrancy freshness vs tree** — new-version toasts patch the last scan so the tree and dashboard match the toast, rewrite the workspace startup fingerprint with that snapshot so VS Code reloads before the next full scan still show those versions, and reuse the last dependency graph for lightweight republish; no action required beyond normal Package Vibrancy use.

### Changed

- **Cross-file CLI project defaults** — `dart run saropa_lints:cross_file …` merges optional **`saropa_lints_cross_file`** settings from **`analysis_options.yaml`** (shared excludes and heuristic/analysis toggles), with explicit CLI flags still applied on top; add that map once per repo if you reuse the same exclusions between engineers and CI; no Dart source change beyond refreshing config when adopting it.
- **Additional quick fixes** — `avoid_redundant_semantics`, `require_baseline_text_baseline`, and `avoid_unconstrained_dialog_column` now offer IDE fixes (remove redundant `Semantics` around an `Image` that already has `semanticLabel`, insert `textBaseline` when using baseline cross-axis alignment, and add `mainAxisSize: MainAxisSize.min` for `Column` inside dialogs); apply only where the suggestion matches intent; no config change.

<details><summary>Maintenance</summary>

- **Contributor planning docs** — assorted `plans/*.md` checklists (quick-fix, testing/release, stub tests, localization guide, severity follow-ups, cross-file CLI, UX backlog, rule-pack migration, comment coverage) were refreshed for clearer sequencing and sign-off trails; docs only, **no shipped rule or extension behavior** beyond what is listed under **`### Changed (Extension)`** above.
- **Maintainer tooling** — the quick-fix audit script prints a stdout summary before writing the dated report file, and the bundled quality-gate **example** YAML documents recommended `new_*` metrics with legacy-alias notes; no action unless you vendor that sample into your own CI gate.
- **Comment coverage CLI** — the worst-files table uses an **L/C** column (physical lines per comment line, higher means sparser) instead of a percentage so maintainers spot thin files faster when running the comment-coverage script locally.

</details>

---

## [13.5.0]

This release restores real compatibility for analyzer 9 consumers, including Flutter-stable setups that cannot move to analyzer 12+ yet. The plugin and CLI now build cleanly instead of failing during startup due to missing analyzer APIs, so projects pinned to analyzer 9 can run `dart analyze` again with current saropa_lints. [log](https://github.com/saropa/saropa_lints/blob/v13.5.0/CHANGELOG.md)

### Fixed

- **Analyzer 9 compatibility** — analyzer-version shims now backfill API gaps (`lowerCaseName`, constructor/extension-type accessors, and registry deltas) so saropa_lints compiles and runs on analyzer 9 instead of crashing during plugin bootstrap; no action required beyond upgrading.
- **Rule AST compatibility** — extension/constructor rule paths now handle analyzer-9 node shapes (nullable extension bodies, primary-constructor availability, and member traversal) so previously failing rule files compile and execute consistently; no action required beyond upgrading.
- **CLI bootstrap on older analyzers** — CLI entrypoint shebang handling was corrected so command wrappers no longer fail parsing before imports on analyzer-9 toolchains; no action required beyond upgrading.

---

## [13.4.9]

This release smooths language and notification behavior in the extension. UI language selection now saves reliably, and score-milestone feedback is quieter during cleanup work. Translation strings for the picker are now complete across shipped locales, so language switching feels consistent. [log](https://github.com/saropa/saropa_lints/blob/v13.4.9/CHANGELOG.md)

### Fixed (Extension)

- **Pick UI language** — choosing a language no longer fails with "Unable to write to Workspace Settings … not a registered configuration"; the picker now saves **`saropaLints.uiLanguage`** to **User** settings so the choice applies reliably across workspaces. No action required — pick your language again if a previous attempt failed.

### Changed (Extension)

- **Health score milestones** — crossing an upward band (50–90) now shows a **short status-bar message** instead of an **information notification**, so steady improvement does not spam the notification center. No action required.
- **Pick UI language** — the quick pick and sidebar **UI language** row list each language in **native script** with the **English name in parentheses** (except English), so the list is readable in the language itself and still easy to cross-reference for maintainers. No action required.
- **Runtime locale catalogs** — `uiLanguage.pick.*` strings (quick pick title, placeholder, and **Auto** row) are translated in every shipped `extension/src/i18n/locales/<locale>.json`, with matching phrase keys in `extension/scripts/i18n/dictionaries.py` so `generate_locales.py` keeps them after regeneration. No action required.
- **UI language scope (docs)** — `extension/scripts/i18n/README.md` now states explicitly that **User** settings are the **intended** scope so one language applies across all workspaces; per-workspace overrides remain out of scope unless product requirements change. No action required.

<details><summary>Maintenance</summary>

- **Publish workflow** — `scripts/publish.py` / extension packaging: US English spelling check skips `extension/scripts/i18n/` (translation data, not US-maintained prose); optional regeneration of `package.nls.<locale>.json` and runtime locale JSON from English sources before compiling the VSIX. No action required for package consumers.

</details>

---

## [13.4.8]

This release adds first-class localization support to the extension UI and introduces a direct language picker workflow. It also fixes a lingering package-size chart issue so visual weighting matches real values. If you use translated UI strings or the vibrancy chart, this is the reliability pass for both. [log](https://github.com/saropa/saropa_lints/blob/v13.4.8/CHANGELOG.md)

### Added (Extension)

- **Localization framework** — contribution strings in `package.json` now resolve through `package.nls.json`, with generated `package.nls.<locale>.json` files for additional languages. Shared webview strings live under `extension/src/i18n/` with a runtime locale picked from VS Code's display language or **`saropaLints.uiLanguage`**.
- **Pick UI language** — new command and prominent **Actions** row to switch language; open dashboards refresh automatically so you can verify translations without reloading the window.

### Fixed (Extension)

- **Size Distribution** chart now actually renders each bar at a length proportional to its share of total size. The fix shipped in v13.4.6 didn't take effect in the live webview and v13.4.7 didn't carry a re-fix, so bars kept rendering at the full track width across both releases; this release switches to the same CSS pattern the Findings Dashboard's bar charts have used reliably for months. No action required — reopen the report after updating.

---

## [13.4.7]

Package Vibrancy no longer launches a fresh scan after every individual `pub upgrade`. The watcher now waits for a whole upgrade session to settle, runs at most one scan at a time, and skips when `pubspec.lock` has not actually changed — the overlapping toasts and slowdown when upgrading several packages in a row are gone. The Package Dashboard webview also stops looking like a "dead page" during the very first scan: instead of the empty-state grade-E gauge with zero rows it now shows a clear "Scan in progress" placeholder, and the open panel auto-refreshes when the scan finishes.

### Changed (Extension)

- **Package Vibrancy** — the file-system watcher now debounces `pubspec.lock` changes by 30s (was 5s) so a session of back-to-back `pub upgrade` calls collapses into a single trailing scan instead of starting a fresh ~60s scan after each individual upgrade. Previously the abort-on-supersede pattern still left earlier scans running to completion (their HTTP fetches don't honor the abort signal), so three sequential upgrades produced three overlapping toasts and heavy CPU/network contention. No action required.
- **Package Vibrancy** — `runScan` now coalesces concurrent invocations: if a scan is already in flight, a second call stashes its options and the in-flight scan launches exactly one trailing scan when it finishes. Callers no longer stack parallel scans, and `forceRefresh: true` is sticky across coalesced calls so a "Rescan (clear cache)" click is honored even when it lands during a watcher-triggered scan. No action required.
- **Package Vibrancy** — the watcher now hashes `pubspec.lock` against the persisted last-scan fingerprint and skips when bytes are unchanged. `pub get` against an unchanged tree, git operations that restore the same lock, and IDE auto-resolve no longer trigger a wasteful full rescan. No action required.

### Fixed (Extension)

- **Package Dashboard** — the webview now shows an explicit "Scan in progress" placeholder when opened during the first scan instead of the empty dashboard with `Grade E · 0/100`, an empty radial gauge, and an empty table. Users were reading the empty-state render as a broken or failed scan. No action required — open the dashboard while a fresh scan is running to see the new placeholder.
- **Package Dashboard** — the open dashboard panel now auto-refreshes when a scan completes. It used to be built once from `latestResults` and never re-render itself, so users who opened it during a scan stayed on stale or empty data until they manually reran the "Show Report" command. No action required.

---

## [13.4.6]

This release fixes two high-friction issues users hit during normal analysis work: the Package Vibrancy size chart now renders proportionally, and tier YAML version pinning no longer breaks analyzer-plugin resolution on newer analyzer stacks. In practice, charts are readable again and analysis setup is less likely to fail after upgrades. [log](https://github.com/saropa/saropa_lints/blob/v13.4.6/CHANGELOG.md)

### Fixed (Extension)

- The **Size Distribution** chart in the Package Vibrancy report now renders each bar at a length proportional to its share of total size. The earlier attempt to fix this didn't take effect in the VS Code webview, so bars kept rendering at the full track width; bars now use the same width-and-grow pattern the Findings Dashboard charts already use reliably. No action required — reopen the report after updating.

### Fixed

- `lib/tiers/{essential,recommended,professional,comprehensive,pedantic}.yaml` no longer pin the embedded plugin to the old `^5.0.0-beta.8` constraint that's been frozen since Feb 2026. The Dart analyzer's plugin manager fetches that constraint into a synthetic project under `.dartServer/.plugin_manager/<hash>/` and runs `pub upgrade` against it — with the stale pin, anyone whose project also depends on a package requiring a newer analyzer (e.g. `riverpod_lint ^3.1.3` requiring `analyzer ^9.0.0`) had `dart analyze` abort with "An error occurred while setting up the analyzer plugin package". The yamls now ship `^13.0.0`, which resolves cleanly against the current analyzer range, and the publish script keeps them in sync with `pubspec.yaml` on every major bump so they can't drift again. Reported as [#216](https://github.com/saropa/saropa_lints/issues/216). No action required after upgrading; consumers using `include: package:saropa_lints/tiers/<tier>.yaml` will start resolving cleanly on the next `pub get`.

<details><summary>Maintenance</summary>

- New module `scripts/modules/_tier_yaml_version.py` rewrites the saropa_lints `version:` line in each `lib/tiers/*.yaml` at publish time, anchored to the current major from `pubspec.yaml`. Runs inside the existing "Version sync" step so the change ships in the same publish commit as the version bump. 13 unit tests pin the contract — major-only widening, idempotent re-runs, CRLF preservation, and no false-matches against unrelated `version:` keys.

</details>

---

## [13.4.5]

This release reduces false positives in command-line and tooling code paths. Rules that make sense for Flutter UI threads no longer fire on scripts under `tool/`, so local utility scripts and generators stop producing noisy warnings. It keeps lint signal focused on code where the risk model actually applies. [log](https://github.com/saropa/saropa_lints/blob/v13.4.5/CHANGELOG.md)

### Fixed

- `avoid_blocking_main_thread` (and other UI-thread rules) no longer fire on scripts under `tool/` — repo-local CLI utilities run via `dart run` and never execute on a Flutter UI isolate, so sync I/O is legitimate there. Mirrors the existing skip for `bin/`. No action required.

<details><summary>Maintenance</summary>

- `tool/rule_pack_audit.dart` and `tool/generate_rule_pack_registry.dart` — `applyCompositeRulePacks` now returns a new map instead of mutating its argument, clearing the `avoid_parameter_mutation` lint. Both call sites updated to consume the returned map. No change to extracted pack contents or generator output.
- Plugin self-source `analysis_options.yaml` excludes `tool/**` belt-and-braces, matching the existing `bin/**` exclusion. The cached plugin snapshot lags local edits to `SaropaContext.isCliToolScript`, so the host-level exclude prevents `dart analyze` noise during the cache rebuild window.

</details>

---

## [13.4.4]

This release expands quick-fix coverage and hardens extension update-check behavior. More rules now have one-step IDE fixes, and upgrade notifications break through stale dismiss windows when a new version is actually available. For day-to-day users, that means faster cleanup and fewer “why didn’t I get prompted?” moments. [log](https://github.com/saropa/saropa_lints/blob/v13.4.4/CHANGELOG.md)

### Added

- Quick fix coverage extended to ten more rules (Batch 13). Each rule now offers a one-step IDE correction so the lint can be cleared without manual edits — no action required if you already had these rules enabled. The newly-fixable rules are `prefer_raw_strings`, `prefer_period_after_doc`, `format_comment_style`, `prefer_const_border_radius`, `prefer_const_widgets_in_lists`, `avoid_redundant_async_on_load`, `avoid_single_cascade_in_expression_statements`, `avoid_escaping_inner_quotes`, `avoid_types_on_closure_parameters`, and `prefer_expression_body_getters`.

### Fixed (Extension)

- Upgrade-check throttle now lets a newly-published `saropa_lints` version break through the dismiss memory immediately instead of being suppressed for up to 24 hours. The previous gate was a single 24h timer, so a release published the morning after a dismiss stayed invisible until that timer elapsed; the gate is now a 1-hour anti-thrash window combined with a per-version dismiss memory, so a new pub.dev version always re-prompts even within the same day. Legacy state self-heals on the next write — no user action required.

<details><summary>Maintenance</summary>

- Removed two orphan extension commands — `saropaLints.config.copyAsJson` ("Copy Triage as JSON") and `saropaLints.overview.copyAsJson` ("Copy Overview as JSON") — that were declared in `package.json` and listed in the command catalog but had no runtime handler after the Triage and Overview trees were merged into Settings/dashboards. Invoking them from the palette previously failed with `command not found`; the entries are now gone.
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

## [13.4.2] and Earlier

> **Looking for older changes?**
> See [CHANGELOG_ARCHIVE.md](https://github.com/saropa/saropa_lints/blob/main/CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 12.6.1.

