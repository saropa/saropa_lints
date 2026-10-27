# PROPOSAL: Keep saropa_lints usable for both analyzer 12 projects and analyzer 13+ projects

**Status: Open. No decision recorded.**

<!-- Status values: Open → Accepted → In Progress → Closed -->
<!-- Use "Declined" if rejected, with rationale in the Decision section -->

Created: 2026-10-27
Revised: 2026-10-27 (see "Correction history")
Type: Infrastructure
Related rules: none (affects every rule that reads arguments or formal parameters)

This document stands alone. Read it top to bottom; no other file is needed for context.

---

## Owner's actual question

- Upgrading saropa_lints to analyzer 13 is trivial for the owner. Effort is not the issue.
- The issue is BACKWARDS COMPATIBILITY in both directions:
  - If saropa_lints moves to analyzer 13, it does not work for the vast majority of existing Flutter projects, which are on analyzer 12.
  - If saropa_lints stays on analyzer 12, it does not work for new projects, whose tools need analyzer 13 or 14.
- The owner asked:
  - How do other projects handle analyzer major upgrades (build_runner, drift_dev, freezed, json_serializable, dart_style, other linters)?
  - Is this only a linter problem?
  - What is the version-control and release process?
  - How do users upgrade?
  - What is the point of the pubspec route versus the analysis_options.yaml plugin route?
- Owner's context:
  - In the Saropa Contacts app, saropa_lints is commented out of `pubspec.yaml` only because of RAM limits on the owner's MacBook. It is normally enabled.
  - The Contacts `pubspec.yaml` notes (lines ~680-730) say build_runner >=2.16, dart_style >=3.1.9 and drift_dev >=2.34.1 are BLOCKED. Reason given: they need analyzer 13+ and saropa_lints caps at `^12.1.0` (dart-lang/sdk issue 62944).
  - The committed Contacts lock already shows analyzer 14.6.0, build_runner 2.16.2, drift_dev 2.35.2 and dart_style 3.1.14. That is because saropa_lints is off there. With saropa_lints on, those versions cannot resolve.
  - build_runner 2.17.1 needs analyzer `>=14.3.0 <15.0.0`.

---

## Summary

- saropa_lints 16.7.0 (latest on pub.dev) requires `analyzer ^12.1.0`. Current code generators require analyzer 13 or 14.
- A project that lists saropa_lints as a dev dependency cannot take current build_runner, source_gen, freezed, drift_dev or dart_style.
- Every analyzer-based package faces the same analyzer major jumps. The common practice is: publish a new version on the new analyzer, leave old versions published, and let pub pick the newest version each project can use.
- The author's recommendation (not a decision): the same forward move. Publish saropa_lints 17.0.0 on `analyzer >=13.0.0 <15.0.0`. Leave 16.x published and frozen. Keep the dev-dependency route as the main route.
- Projects pinned to analyzer 12 are not broken by this. pub picks 16.7.0 for them. They stop receiving new rules until they update their other tools.
- Two parallel lines (Option A) are needed only if the owner wants analyzer-12 projects to keep receiving NEW rules.

---

## Process: pubspec route versus analysis_options.yaml plugin route

### The two routes

| | Dev-dependency route (pubspec) | Plugin route (analysis_options.yaml) |
|---|---|---|
| Where it is written | `dev_dependencies: saropa_lints: ^x.y.z` in `pubspec.yaml` | `plugins: saropa_lints: version: "x.y.z"` in `analysis_options.yaml` |
| What reads it | `dart pub get` and the project's version solver | The Dart analysis server (the IDE and `dart analyze`) |
| What it is for | Version resolution against all other dependencies, the lock file (`pubspec.lock`), `dart pub outdated` and `dart pub upgrade` reminders. Also gives `dart run saropa_lints:init`, `scan`, `baseline` and the VS Code extension's `dart run` calls a package to run. | Loads the lint rules into the analysis server. |
| Which analyzer it uses | The project's resolved analyzer. It must agree with every other dependency. | Its own. The server builds a private package for the plugin. No clash with the project. |
| Who keeps the version current | pub. `pub outdated` shows newer versions. `pub upgrade` moves within the caret. | The user, by hand. Nothing reminds the user. |
| Lock file | `pubspec.lock`, committed | None in the project. The server's private package is resolved with `pub upgrade` on its own. |

### How the plugin route works (verified by SDK source, Dart 3.13.7)

- The analysis server generates a synthetic package named `plugin_entrypoint`.
- That package depends on `analysis_server_plugin ^0.3.8` (the range in Dart 3.13.7) and on each listed plugin at the version written in `analysis_options.yaml`.
- The server runs `dart pub upgrade` in that package's own folder, compiles an AOT snapshot and runs it in an isolate.
- The project's lock file and the analyzer bundled in the SDK are not used.
- A scratch copy of that package with `saropa_lints: 16.7.0` resolved analyzer 12.1.0. The Contacts repo resolves analyzer 14.6.0 at the same time on the same machine. This shows the two do not clash.
- What the SDK does decide: its Dart version must meet the plugin's `sdk:` floors, and its `analysis_server_plugin` range must include the plugin's version.
- The Flutter `meta` pin does not apply there. The synthetic package is pure Dart.

### Why the dev dependency exists at all

- The `init` command, the `scan` command, the baseline command and the VS Code extension call `dart run saropa_lints:<tool>`. `dart run` needs the package in the project.
- The README tells users to run `dart pub add --dev saropa_lints`. That creates the resolution conflict this proposal is about.

### How a user upgrades

| Route | Steps |
|---|---|
| Dev dependency | Edit the constraint in `pubspec.yaml` if it blocks the new version, or run `dart pub upgrade` (stays inside the caret) or `dart pub upgrade --major-versions` (rewrites the caret to the newest major). Commit `pubspec.yaml` and `pubspec.lock`. `dart pub outdated` reports when a newer version exists. |
| Plugin | Edit `version: "x.y.z"` in `analysis_options.yaml` by hand. Commit that file. Nothing reminds the user to do this. |

### Version control and release process

- Both files (`pubspec.yaml`, `analysis_options.yaml`) are committed. `pubspec.lock` is committed for apps.
- Publishing a version to pub.dev is permanent. Old versions stay resolvable. A version can be retracted only within 7 days of publishing (pub policy, not re-verified here).
- The saropa_lints publish scripts refuse stable versions with an odd minor (`stable_version_error`, commit `0efa9cab`). Two lines cannot be split by minor. They must be split by major.
- Whether `saropa_lints:init` rewrites the plugin `version:` line was not verified. The Contacts `analysis_options.yaml` comments say `saropa_lints:init` regenerates the diagnostics block on version syncs.

---

## How other analyzer-based packages handle analyzer majors

### Is this only a linter problem?

- No. Every package built on the analyzer has the same problem: code generators (build_runner, source_gen, drift_dev, freezed, json_serializable, riverpod_generator, injectable, envied), the formatter (dart_style), mocking (mockito) and other linters.
- Each analyzer major can remove or rename public AST classes. Analyzer 13 did exactly that in place, with no deprecation period (dart-lang/sdk issue 62944).

### The common pattern

- Publish a new version that needs the new analyzer.
- Leave old versions published.
- pub picks, per project, the newest version compatible with all of that project's constraints.
- Almost none keep two parallel release lines.
- Only analyzer itself back-ports (7.7.1 and 8.4.1 exist).

### What was and was not measured

- NOT measured per package: the statement "almost none keep two parallel lines". It rests on the packages below and is not a census.
- Verified by pub.dev data (2026-10-27): the latest release of each of these accepts analyzer 13 or 14, and none requires analyzer 12.
  - build_runner 2.17.1, drift_dev 2.35.2, dart_style 3.1.14, source_gen 4.3.1, json_serializable 6.15.2, freezed 4.0.3, riverpod_generator 4.0.9, mockito 5.8.1, injectable_generator 3.1.3, envied_generator 1.3.10.
- Constraint histories of the last three releases were checked for the tools in the table under "Ecosystem state". In those, no package ran two parallel major lines.
- The earlier research covered 30 packages in total for the "no parallel lines" observation. Only the packages named above are claimed here.
- Counter-example: lean_builder 1.2.2 declares `>=10.0.0 <15.0.0` but imports `NamedArgument`. Its lower bound does not compile. A wide analyzer range is only honest when a CI job builds at the lowest end.
- Tools that span 12 to 14 in one release (json_serializable, envied_generator, injectable_generator, source_gen 4.2.4) do not use the renamed AST nodes.

---

## Motivation

### The conflict, reproduced (verified by data)

`dart pub get --dry-run` on a pure Dart project with `build_runner: ^2.17.0` and `saropa_lints: any` (Dart 3.13.7):

```
And because saropa_lints >=14.0.3 depends on analyzer ^12.1.0 and build_runner >=2.16.2 depends on analyzer ^14.3.0, build_runner >=2.16.2 is incompatible with saropa_lints.
So, because proj depends on both build_runner ^2.17.0 and saropa_lints any, version solving failed.
```

Saropa Contacts already resolves analyzer 14.6.0, build_runner 2.16.2, dart_style 3.1.14, drift_dev 2.35.2 and source_gen 4.3.1 when saropa_lints is left out of `dev_dependencies`.

### saropa_lints constraints today (verified, local pubspec.yaml)

- `sdk: ">=3.9.0 <4.0.0"`
- `analysis_server_plugin: ^0.3.14` (each release pins analyzer EXACTLY: 0.3.14 = analyzer 12.1.0)
- `analyzer: ^12.1.0`
- `analyzer_plugin` capped below 0.15.0
- `meta: ^1.18.3`
- Latest on pub.dev: 16.7.0 (published 2026-10-06).

### analyzer versions on pub.dev (verified by data)

| analyzer | sdk | meta |
|---|---|---|
| 12.1.0 | ^3.9.0 | ^1.18.0 |
| 13.0.0 | ^3.9.0 | ^1.18.0 |
| 13.3.0 | ^3.11.0 | ^1.18.3 |
| 14.6.0 | ^3.13.0 | ^1.18.3 |

- Analyzer 13.0.x does NOT force a Dart 3.13 floor.
- pub picks the newest analyzer the SDK allows. A range `>=13.0.0 <15.0.0` therefore works on:
  - Dart 3.9: gets analyzer 13.0 to 13.2
  - Dart 3.11: gets 13.3 and later
  - Dart 3.13: gets 14.x

### Ecosystem state (pub.dev, 2026-10-27, verified by data)

| Tool | Latest | Latest analyzer range | Newest version that accepts 12.1 |
|---|---|---|---|
| build_runner | 2.17.1 | `>=14.3.0 <15.0.0` | 2.15.1 |
| source_gen | 4.3.1 | `>=14.0.0 <15.0.0` | 4.2.4 |
| dart_style | 3.1.14 | `>=13.1.0 <15.0.0` | 3.1.8 |
| drift_dev | 2.35.2 | `>=13.0.0 <15.0.0` | 2.34.0 |
| freezed | 4.0.3 | `>=14.0.0 <15.0.0` | none |
| riverpod_generator | 4.0.9 | `>=13.0.0 <15.0.0` | 4.0.4 |
| riverpod_lint | 3.1.9 | `>=13.0.0 <15.0.0` | 3.1.4 |
| mockito | 5.8.1 | `>=13.3.0 <15.0.0` | 5.6.4 |
| test | 1.33.0 | `>=13.0.0 <15.0.0` | 1.31.1 |
| json_serializable | 6.15.2 | `>=10.0.0 <15.0.0` | 6.15.2 |
| injectable_generator | 3.1.3 | `>=10.0.0 <15.0.0` | 3.1.3 |
| envied_generator | 1.3.10 | `>=8.0.0 <15.0.0` | 1.3.10 |
| auto_route_generator | 10.6.0 | `>=10.0.0 <14.0.0` | 10.6.0 |
| hive_ce_generator | 1.12.0 | `>=14.0.0 <14.5.0` | 1.11.2 |

- No latest release of these tools requires analyzer 12.
- A project held at analyzer 12 today is held by an old lock or by saropa_lints itself. The Contacts repo was the second case.

### Flutter `meta` pins (verified by data)

| Flutter | Dart | `meta` in `packages/flutter/pubspec.yaml` |
|---|---|---|
| 3.41.9 | 3.11 | 1.17.0 |
| 3.44.9 | 3.12 | 1.18.0 |
| 3.47.0 / 3.47.8 | 3.13 | `^1.18.3` |

- saropa_lints has declared `meta ^1.18.3` since 14.0.3 (2026-06-19). As a dev dependency it already resolves only on Flutter 3.47+.
- analyzer 13.0.0 needs `meta ^1.18.0` and `sdk ^3.9.0`. Only 13.1.0+ need `meta ^1.18.3` and `sdk ^3.11.0`. 14.6.0 needs `sdk ^3.13.0`.

### History this builds on

- `plans/history/2026.06/2026.06.20/revert_analyzer_13_bump.md` settled that the analyzer 13 jump is a source migration. That still holds.
- `plans/blocked/PLAN_analyzer_13_migration.md` records the migration, done once on branch `analyzer-13-migration`: `39b665c8` (set Dart floor 3.13.0, analyzer ^13.1.0) plus `2b6cc8a4`, `028b30ce`, `d6cb4f8f`. The merge to main was reverted the same day (`f088516b`, `ecbdc1f3`, `7b06ef7c`). Reason given: Flutter 3.47.1 adoption was near zero, and the 3.13.0 SDK floor would have orphaned most consumers. `prefer_primary_constructor` stayed on main as detection-only.
- `plans/history/2026.06/2026.06.04/analyzer-12-support.md` records the earlier jump to analyzer 12.
- `plans/history/2026.09/2026.09.19/PLAN_vibrancy_upgrade_blast_radius.md` and `PACKAGE_VIBRANCY.md` (~line 43) built the Package Vibrancy advisor note that blocks the analyzer 13 nudge ("analyzer 13.1.0 needs meta ^1.18.3; Flutter pins meta 1.18.0"). That seeded entry (`analyzer >=13.0.0` held back) is now stale for the same reasons as the pubspec comments (see "Stale statements").
- The "Dart 3.13 floor" reason does not apply to a 13.0 range (see the analyzer table above). The floor in `39b665c8` was a choice of that commit, not a requirement of analyzer 13.0.x.

---

## Detection / Behavior

### How resolution behaves (standard pub solver behavior; NOT yet run in a real analyzer-12-pinned project)

- The solver picks the newest saropa_lints version compatible with every other constraint in the project.
- `dart pub add saropa_lints` in a project pinned to analyzer 12 resolves to the last analyzer-12-compatible release (16.7.0). No manual step.
- A project with `saropa_lints: ^16.7.0` stays on 16.x until its owner changes that constraint. A caret on a major does not admit 17.
- A project with the newer tools resolves to 17.x.
- So "16.x frozen, 17.x forward" does NOT break old projects. They simply stop receiving new rules until they update their other tools.

### Cases that remain a problem

- (a) A project with a hard `saropa_lints: ^17` or `any`, plus tools pinned to analyzer 12. Result: a resolution error that names the conflict. Expected. The user fixes it by choosing 16.x.
- (b) Users who copy an old README snippet. A README that names `^16.7.0` keeps them on the frozen line. The README must say so.
- (c) Projects whose tools need analyzer below 11 (objectbox_generator needs `<11`, custom_lint needs `^8`). Neither 16.x nor 17.x serves them as a dev dependency. The plugin route still works.

### Analyzer 13 breaks that hit `lib/` (source diff only; counts from HEAD `0efa9cab`)

| API | Refs / files | Replacement |
|---|---|---|
| `NamedExpression` | 796 / 146 | `NamedArgument` (not an `Expression`) |
| `.name.label.name` | 611 / 115 | `.name.lexeme` |
| `ArgumentList.arguments` | 1,106 / 173 | `NodeList<Argument>`; value via `.argumentExpression` |
| `visitNamedExpression` / `addNamedExpression` | 10 / 5, 23 / 15 | `visitNamedArgument` / `addNamedArgument` |
| `SimpleFormalParameter` | 107 / 38 | `RegularFormalParameter` |
| `DefaultFormalParameter` | 77 / 38 | `FormalParameter.defaultClause` |
| `NormalFormalParameter` | 11 / 10 | `FormalParameter` |
| `FunctionTypedFormalParameter` | 3 / 3 | `FormalParameter.functionTypedSuffix` |
| `CapturingRuleVisitorRegistry implements RuleVisitorRegistry` | 1 | 4 methods removed, 6 added |
| `GeneralizingAstVisitor` subclasses | 10 files | named arguments no longer reach `visitExpression`; `visitCollectionElement` removed (not in the changelog) |

- The formal-parameter changes total 184 references (SimpleFormalParameter 107 + DefaultFormalParameter 77).
- Analyzer 14 removals (`FormalParameterElement.isInitializingFormal`, `isSuperFormal`, `formalParameters`, `typeParameters`, `PackageConfigFileBuilder`, `FunctionBody.lookupThisType`) have 0 uses in `lib/`. The 4 `.formalParameters` uses are on `ExecutableElement`.
- A source diff of 13.3.0 against 14.6.0 shows the V1 `RuleVisitorRegistry` unchanged (183 methods) and no removed V1 AST getter that `lib/` uses. So 13 and 14 look compatible for everything saropa_lints uses.
- The private imports `package:analyzer/src/string_source.dart` and `package:analysis_server_plugin/src/correction/fix_generators.dart` (`ProducerGenerator`) exist in analyzer 13.3/14.6 and plugin 0.3.15/0.3.25.
- One code path cannot compile on both 12 and 13. Dart has no conditional compilation on a dependency version.
- Nothing was compiled against analyzer 13 or 14. All of the above comes from reading source and changelogs.
- dart-lang/sdk issue 62944 (closed 2026-04-28) is the design record for the in-place `NamedExpression` to `NamedArgument` rename. Related: issues 62799, 63002, 62970.
- The earlier migration must be redone over the 185 `lib/` files changed since the revert (541 commits, about 100 under `lib/src/rules`).

---

## Proposed Tier

Tier: not applicable (infrastructure).
Justification: dependency and release-process change only. No rule behavior change.

---

## Edge Cases

1. **Pure Dart projects on Dart 3.9 to 3.12** — with `analyzer >=13.0.0` pub selects analyzer 13.0.x on Dart 3.9/3.10 and 13.x/14.0-14.5 on 3.11/3.12. Needs a downgrade CI job.
2. **Flutter 3.44 projects that keep the dev dependency** — admitted only if `meta` is lowered to `^1.18.0`; pub then selects analyzer 13.0.0.
3. **Projects with auto_route_generator 10.6.0** — cap `<14`. A range that includes 13 lets them resolve.
4. **Projects with objectbox_generator or custom_lint** — need analyzer `<11` / `^8`. Neither 16.x nor the new line serves them as a dev dependency. The plugin route still works.
5. **Frozen 16.x on a future SDK** — when a future SDK raises its `analysis_server_plugin` range past `^0.3`, 16.x stops loading as a plugin. Date unknown.
6. **Composite plugins that import saropa_lints types** — break on the analyzer floor change. Needs a major version.
7. **Version numbering** — `stable_version_error` refuses odd stable minors. Two lines must be split by major, not by minor.
8. **README snippet** — must state which constraint serves which analyzer line (see "Cases that remain a problem").

---

## Alternatives Considered

| Option | Cost | Outcome |
|---|---|---|
| Forward move (author's primary recommendation) | One migration (done once already). One branch. CI adds a downgrade job. README change. | 17.0.0 on analyzer `>=13.0.0 <15.0.0`. 16.x stays published and frozen. pub picks per project. Analyzer-12 projects keep 16.7.0 and get no new rules. |
| A. Two parallel majors (16.x on analyzer 12 with back-ports, 17.x on 13/14) | Two branches and CI runs. About 100 rule commits landed in the 2 months after the revert, so about 50 back-ports a month, each with node renames. | Analyzer-12 projects keep receiving new rules. Highest upkeep. |
| B. Adapter package selected by pub (`saropa_lints_ast_compat` 1.x on 12, 2.x on 13/14) | Rewrite about 1,900 call sites to adapter calls. Weaker typing. Two-version CI forever. Extra package. | One saropa_lints line across 12 to 14. No published precedent found. |
| C. Separate package for the command-line tools | New package, extension rewiring, docs. More moving parts. | Takes the tools out of the project's resolution. Same effect as the plugin-only supplement below, with more work. |
| Plugin-only supplement (optional, was "Option D") | README, `init` and extension changes. | Removes the resolution conflict for users who hit one. Costs the pubspec benefits (see below). |

- Typedef aliases in the analyzer would not have helped: `NamedArgument` is not an `Expression`, and its getters differ.

### Is Option A still needed?

- Only if the owner wants analyzer-12 projects to keep receiving NEW rules.
- If not, the forward move alone is enough. Old projects keep 16.7.0 and are not broken.
- Cost if wanted: about 50 back-ports a month with renamed nodes (an estimate from commit counts, not measured effort).

### The plugin-only route as an optional supplement

- It is the route for people who hit a resolution conflict they cannot fix.
- It gives up the normal pubspec benefits:
  - no version resolution against the rest of the project
  - no lock file entry
  - no `pub outdated` or `pub upgrade` reminders
- The version in `analysis_options.yaml` is typed by hand. Nothing reminds the user to update it.
- Command-line tools would need `dart pub global activate saropa_lints`. Not verified: whether the extension works with a global activation.
- Not verified: whether the plugin loader accepts a version range or only an exact version in the `version:` field.
- It is not a replacement for the dev-dependency route.

### Recommendation (author's, not a decision)

Ordinary forward move:

- Publish 17.0.0 with:
  - `analyzer: ">=13.0.0 <15.0.0"`
  - `analysis_server_plugin: ">=0.3.15 <0.4.0"`
  - `analyzer_plugin: ">=0.14.9 <0.15.0"`
  - `meta: ^1.18.0`
  - `sdk: ">=3.9.0 <4.0.0"` unchanged. The 3.13 floor in `39b665c8` is not required.
- Leave 16.x published and frozen. No back-ports (unless the owner chooses Option A).
- Keep the dev-dependency route as the main route.
- README: `dart pub add --dev saropa_lints` stays. Add a note that projects pinned to analyzer 12 resolve to 16.7.0 automatically, or can write `^16.7.0`.
- Mention the plugin-only route as an optional supplement, with its downsides.
- Add a CI job that runs `dart pub downgrade` (analyzer 13.0.x) beside the normal job (analyzer 14.x). Both compile and test.

---

## Correction history

The first version of this proposal (and the Saropa Contacts plan with the same content) was wrong in these ways:

1. **Overstated breakage.** It said the dev-dependency route BREAKS for projects pinned to analyzer 12 after a 17.x release. That is wrong. The solver picks the newest compatible saropa_lints. Analyzer-12 projects resolve to 16.7.0. The correct remaining cases are listed under "Cases that remain a problem".
2. **Option D recommended without need.** The plugin-only install (drop the dev dependency, tools via `dart pub global activate`) was the primary recommendation. It gives up version resolution, the lock file and update reminders, and it was not needed to solve the problem. It is now an optional supplement.
3. **Missing context.** It did not say how other analyzer-based packages handle analyzer majors, or that this is not only a linter problem. Now in its own section.
4. **Missing process answers.** It did not explain what the pubspec route is for, what the plugin route is, how users upgrade, or how version control works. Now in "Process".
5. **Why the earlier work missed the point.** The first research answered "how hard is the port" instead of "how do old and new projects stay compatible". The first recommendation was not checked against pub's solver behavior. The solver claim in this revision is also still untested in a real project (see "Next steps", item 1).

---

## Decision

<!-- Fill in when the proposal is accepted or declined. No decision recorded. -->

None recorded. Open choices for the owner: forward-only (17.0.0, 16.x frozen) versus two parallel lines (Option A). The author's recommendation is forward-only; that is not a decision.

---

## Next steps

1. Scratch-project test of the solver claim: create a project pinned to analyzer 12 (tools at analyzer 12), run `dart pub add saropa_lints` against a local copy of 17.0.0 metadata or a path/hosted simulation, and confirm it resolves to 16.7.0. Also test `saropa_lints: ^16.7.0` staying put and `saropa_lints: ^17` failing with a clear message.
2. Compile saropa_lints against analyzer 13.0.0 and 14.6.0 to confirm the source-diff claim (13 and 14 share one code path).
3. Owner decision: forward-only versus two lines. Undecided. Author's recommendation: forward-only.
4. Fix the stale statements listed below.
5. Redo the migration over the 185 changed `lib/` files (steps in "Implementation Notes").

---

## Implementation Notes

1. Branch, revert `f088516b`, re-apply `2b6cc8a4`.
2. Re-run the renames over code added since 2026-08-25 (541 commits, 185 `lib/` files changed).
3. Update `lib/src/scan/capturing_registry.dart` and `lib/src/native/compat_visitor.dart` for the new registry and visitor methods (4 removed, 6 added).
4. Review the 10 `GeneralizingAstVisitor` subclasses.
5. Set the constraints above. Remove the HARD STOP comments in `pubspec.yaml`.
6. CI: normal job (analyzer 14.x) plus `dart pub downgrade` job (analyzer 13.0.x), both compile and test.
7. Update `README.md`, `init` output and the extension's `dart run saropa_lints:` calls as needed.
8. Update the Package Vibrancy held-back entry for `analyzer >=13.0.0`.

### Stale statements in saropa_lints (doc issues to fix)

- `pubspec.yaml` lines ~104 and ~123: say Flutter stable pins `meta` exactly 1.18.0. Flutter 3.47.x ships `^1.18.3`.
- `pubspec.yaml` line ~108: says analyzer 13.0.0 needs `meta ^1.18.3`. It needs `^1.18.0`. Only 13.1.0+ need `^1.18.3`.
- `pubspec.yaml` lines ~159-164: the comment says `^1.18.0`, the value is `^1.18.3`.
- Issue 256 comment of 2026-08-29: says riverpod_lint, freezed and drift_dev are stuck on analyzer 12. They moved on to 13/14.
- `CHANGELOG.md`: says 16.7.0 was skipped in favor of 16.8.0. pub.dev shows 16.7.0 published on 2026-10-06.
- `plans/blocked/PLAN_analyzer_13_migration.md`: says the migration ships as 16.0.0. This proposal says 17.0.0 and the current release is 16.7.0.
- `plans/blocked/PLAN_analyzer_13_migration.md` and `revert_analyzer_13_bump.md`: say analyzer 13 is unresolvable in any Flutter-stable app. That holds for the dev-dependency route on Flutter 3.44 and older only. It no longer holds on Flutter 3.47+, and the revert's Dart 3.13 floor reason does not apply to a 13.0 range.
- `pubspec.yaml` HARD STOP comments (analysis_server_plugin and analyzer blocks): obsolete once the above is applied.
- `PACKAGE_VIBRANCY.md` (~line 43) and the seeded held-back entry: example text and entry describe the same stale meta reasoning.

---

## Verification status

### Verified by data (pub.dev API, dry-run output, SDK source and docs)

- analyzer version table (sdk and meta per version).
- Latest versions and analyzer ranges in the ecosystem table.
- saropa_lints 16.7.0 is latest on pub.dev and requires `analyzer ^12.1.0`.
- The `dart pub get --dry-run` conflict output.
- Flutter `meta` pins.
- Plugin loader behavior (Dart SDK 3.13.7 source and `using_plugins.md`) and the scratch resolution of analyzer 12.1 versus the Contacts repo's 14.6.

### Verified by source-reading only

- All analyzer 13 and 14 break lists and the usage counts.
- 13 and 14 compatibility for everything saropa_lints uses.
- Private import availability in analyzer 13.3/14.6.
- Option cost estimates: two parallel lines about 50 back-ports a month (from commit counts); compat package about 1,900 rewritten call sites, no precedent found; separate tools package means more moving parts.

---

## Unknowns

- The share of projects still on analyzer 12 is not measured. pub.dev has no per-version download data.
- No compile was run against analyzer 13.0.0 or 14.6.0.
- Analyzer 12.1 with Dart 3.13 primary constructors inside the plugin was not tested.
- Whether the VS Code extension works with a global activation was not checked.
- Whether `saropa_lints:init` updates the plugin version in `analysis_options.yaml` was not checked.
- Whether `pub add` resolves as described in a real analyzer-12-pinned project was not run. The description follows standard solver behavior. Test it with a scratch project first.
- Whether the plugin loader accepts a version range or only an exact version in the `version:` field of `analysis_options.yaml` was not verified.
- The per-package claim "almost none keep two parallel lines" was not measured beyond the packages named above.

---

## Commits

<!-- Add commit hashes as implementation lands -->
