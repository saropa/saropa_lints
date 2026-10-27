# PLAN: Analyzer upgrade (12 to 13/14) without breaking target projects

**Status:** Open. Owner decisions recorded in section 4. Nothing implemented yet.
**Merged:** 2026-10-27 from the analyzer 13 migration plan, the analyzer 10 upgrade review, and the dual-compatibility proposal. The three source files are removed.
**Terms:** "target project" is an app or package that installs saropa_lints. "The package" is saropa_lints. "Plugin" is the analyzer plugin the analysis server loads.

---

## 1. Where we are (2026-10-27)

- Latest release: saropa_lints 16.7.0 (published 2026-10-06). It requires `analyzer ^12.1.0` and `meta ^1.18.3`.
- Latest analyzer: 14.6.0 (2026-10-20). Latest Flutter stable: 3.47.8 (2026-10-23, Dart 3.13.7).
- build_runner, source_gen, freezed, drift_dev and dart_style need analyzer 13 or 14. A target project that adds saropa_lints under `dev_dependencies` cannot take them.
- Saropa Contacts (our app) has saropa_lints commented out in `pubspec.yaml` because of this ([pubspec.yaml](/Users/craighathaway/Documents/src/contacts/pubspec.yaml) lines 686-728).
- The analyzer 13 migration was done once (commits `39b665c8`, `2b6cc8a4`, `028b30ce`, `d6cb4f8f`, all in main history) and reverted from main on 2026-08-25 (`f088516b`, `ecbdc1f3`, `7b06ef7c`). It set a Dart 3.13.0 floor and Flutter 3.47 adoption was near zero at the time.
- A separate break already exists (section 3): target projects on Flutter 3.44 and older cannot resolve saropa_lints 14.0.3 or later as a dev dependency.

## 2. The problem in plain words

- saropa_lints is built on the Dart analyzer package. Analyzer 13 renamed classes the package depends on. About 1,900 call sites change.
- pub requires one analyzer version per target project. If the package needs analyzer 12 and another tool needs 14, version solving fails.
- Staying on analyzer 12 blocks new projects. Moving to 13/14 must not break projects that are on analyzer 12 today.

## 3. Who is affected today

| Target project | Status |
|---|---|
| Flutter 3.47+, saropa_lints as dev dependency, other tools on analyzer 12 | Works. |
| Same, with current build_runner, drift_dev or freezed | Fails: version solving conflict. |
| Flutter 3.44 or older, saropa_lints as dev dependency | Broken for 14.0.3 and later: `meta` conflict. |
| Plugin route only (`analysis_options.yaml`) | Works on any Flutter. |

**The `meta` break.**
- Commit `6dfc4b92` (2026-06-18, "add pubspec version-constraint reviewer rules", author account "saropa") raised `meta` from `^1.18.0` to `^1.18.3`. It shipped in 14.0.3.
- The comment above the line in `pubspec.yaml` says "NOT ^1.18.3 ... do NOT raise this floor". Value and comment disagree.
- The commit message never mentions `meta`. The same hunk raised four other lower bounds to versions already in the lock file, which looks like an automatic "tighten lower bounds" run. This is inference.
- The code uses `package:meta` only for `@visibleForTesting` (3 uses). `meta` 1.18.3 added only `TargetKind.importDirective`, which the code does not use.
- `meta` is a direct dependency only because `dart pub publish` rejects an undeclared `package:meta` import (commit `be9d823e`, 2026-06-12).
- Flutter 3.44 pins `meta` at exactly 1.18.0. Window of the break so far: 2026-06-18 to today for Flutter 3.44 and older; for Flutter 3.47+ it was never broken.
- Scratch test 2026-10-27: a copy of the pubspec with `meta: ^1.18.0` resolves in a project that pins `meta: 1.18.0`. With `^1.18.3` it fails with "saropa_lints from path is forbidden". Resolution only; no build, no lint run.
- Local projects checked 2026-10-27 (`dart pub get --dry-run` with `saropa_lints` pointed at the patched copy):
  - `example`, `self_check` and `packages/saropa_lints_api` lock `meta` 1.19.0 and analyzer 12.1.0. Only the `saropa_lints` path entry itself changes. `meta` and analyzer stay.
  - `example_packages` has no lock file.
  - Saropa Contacts and its two worktrees (`contacts-wt-android-release`, `contacts-wt-release-slice6`) do not depend on saropa_lints (commented out). Their committed `pubspec.lock` has analyzer 14.6.0 and `meta` 1.19.0. The patch does not touch them.
- A looser `meta` floor cannot remove a solution that exists today. It only adds solutions, and pub still picks the newest `meta` (1.19.0 in every lock above). The patch changes nothing else.
- Not known: how many projects were affected, and whether anyone reported it.

## 4. Decisions

### Made by the owner (2026-10-27)

1. Release order: a 16.x patch first, then the major version. No separate migration branch.
2. The extension checks the target project's Dart/Flutter version before offering a saropa_lints upgrade, for both the `pubspec.lock` version and the `analysis_options.yaml` plugin version. The extension also manages migration and upgrades.
3. Ignore the history documents.
4. D2, analyzer range: `>=13.0.0 <15.0.0`. The owner asked for the best choice for compatibility, not the lowest version. Develop and test on the latest, 14.6.0. CI also tests 13.0.0, the lowest version in the range. Versions in between are not tested one by one; pub picks the newest analyzer the project's Dart allows.
5. D3: forward-only. 16.x is frozen after the major ships. No back-ports.
6. D4: the major is 17.0.0.
7. D5: accepted as recommended. Decide after the section 7 findings. No work now.
8. Rename the rule `deprecated_new_in_comment_reference` to `deprecated_new_in_comment_reference_extended`, per the project's collision-rename convention (`_extended` suffix). Done 2026-10-27, not committed.
9. D1: restore `meta ^1.18.0` in the 16.x patch. Built 2026-10-27 as part of 16.10.0 (not committed, not published). A project pinning `meta` exactly 1.18.0 resolves with the real pubspec (`dart pub get --dry-run` exit 0); the repo's own resolution is unchanged.

### Open

| # | Decision | Recommendation | Why |
|---|---|---|---|
| none | | | |

## 5. Plan, in order

1. **16.x patch (D1).**
   - Set `meta: ^1.18.0` and fix the comment so value and comment agree.
   - Run `dart pub publish --dry-run` (the publish check that introduced `meta`).
   - CHANGELOG entry. Publish as a patch.
   - `pubspec.yaml` says version 16.10.0, but pub.dev latest is 16.7.0 and the tag `v16.7.0` is 4 commits behind HEAD. The patch publishes those 4 commits too. Review them before publishing, and set the version number the publish script expects.
2. **Extension, first part.**
   - Read the Dart/Flutter version of the target project and the `environment.sdk` of each saropa_lints version from the pub.dev API.
   - Offer only versions the project can resolve. Otherwise offer: pin `^16.7.0`, or upgrade Flutter (`flutter upgrade` goes to latest stable; the minimum version has no one-command path without FVM).
   - Extend the existing checker ([extension/src/upgrade-checker.ts](/Users/craighathaway/src/saropa_lints/extension/src/upgrade-checker.ts), which reads `pubspec.lock` and compares to pub.dev) to also read `version:` under `plugins: saropa_lints:` in `analysis_options.yaml`. [analyzerPluginWatch.ts](/Users/craighathaway/src/saropa_lints/extension/src/analyzerPluginWatch.ts) already watches that file.
   - Keep every command the extension runs (`dart run saropa_lints:init`, `scan`, `baseline`, `cross_file`, `write_config`) working against 16.x and the new major. Gate any new flag by installed version.
3. **Migration (section 6)** on main.
4. **CI.** Compile and run the full test suite at analyzer 14.6.0 (latest) and 13.0.0 (lowest in the range). Add both to CI. Also run the scratch-project solver test (section 12).
5. **Publish the major (D4)** only if steps 3 and 4 pass.
6. **Cleanup.** README, `init` output, pubspec comments, stale statements (section 13), Package Vibrancy held-back entry.

## 6. Migration work

### Source and scope

- Start from the earlier migration commits (section 1). Cherry-pick, then redo the renames over code added since 2026-08-25: 541 commits, 185 `lib/` files, about 100 under `lib/src/rules`.
- The Dart 3.13.0 SDK floor of `39b665c8` is not required. Keep `sdk: ">=3.9.0 <4.0.0"`. Analyzer 13.0.0 needs only Dart 3.9.
- Typedef aliases do not work: `NamedArgument` is not an `Expression` and its getters differ.

### Renames (counts from HEAD `0efa9cab`)

| Old | New | Refs / files |
|---|---|---|
| `NamedExpression` | `NamedArgument` (in `ArgumentList`), `RecordLiteralNamedField` (in `RecordLiteral`). Not an `Expression`. | 796 / 146 |
| `.name.label.name` | `.name.lexeme` | 611 / 115 |
| `ArgumentList.arguments` | `NodeList<Argument>`; value via `.argumentExpression`. Not every `.arguments` is an `ArgumentList`; filter. | 1,106 / 173 |
| `visitNamedExpression` / `addNamedExpression` | `visitNamedArgument` + `visitRecordLiteralNamedField` / `addNamedArgument` | 10 / 5, 23 / 15 |
| `SimpleFormalParameter` | `RegularFormalParameter` | 107 / 38 |
| `DefaultFormalParameter` | removed; use `FormalParameter.defaultClause` | 77 / 38 |
| `NormalFormalParameter` | `FormalParameter` | 11 / 10 |
| `FunctionTypedFormalParameter` | `RegularFormalParameter` plus `functionTypedSuffix` | 3 / 3 |
| `CapturingRuleVisitorRegistry implements RuleVisitorRegistry` | 4 methods removed, 6 added (`lib/src/scan/capturing_registry.dart`, `lib/src/native/compat_visitor.dart`) | 1 |
| `GeneralizingAstVisitor` subclasses | named arguments no longer reach `visitExpression`; `visitCollectionElement` removed (not in the analyzer changelog). Review each. | 10 files |
| `Label.name`, `BreakStatement.label`, `ContinueStatement.label` | `Token`, `LabelReference?` | low |
| `FormalParameterElement.isInitializingFormal` / `isSuperFormal` | type checks against `FieldFormalParameterElement` / `SuperFormalParameterElement` (removed in 14.0.0) | 0 in `lib/` |

Suggested order: formal-parameter renames, visitor renames, `NamedExpression` split (widget rules first, 40+ in `widget_patterns_avoid_prefer_rules.dart`), `ArgumentList.arguments` types (watch `arguments.whereType<NamedExpression>()`, which needs a double rename), registry methods, element API checks, private imports.

### Private imports (3 files)

| File | Import |
|---|---|
| `lib/src/scan/scan_runner.dart` | `package:analyzer/src/string_source.dart` |
| `test/support/resolved_rule_harness.dart` | `package:analyzer/src/string_source.dart` |
| `test/integrity/saropa_plugin_registration_test.dart` | `package:analyzer/src/lint/config.dart` |

Also `package:analysis_server_plugin/src/correction/fix_generators.dart` (`ProducerGenerator`). The `string_source.dart` and `fix_generators.dart` imports exist in analyzer 13.3/14.6 and plugin 0.3.15/0.3.25 (source reading). Find a public replacement for each, or document the workaround.

### Dart 3.13 primary constructors

Rules that visit `ConstructorDeclaration` (159 refs) or `ClassDeclaration` (656 refs) must handle `class Point(final int x, final int y);`. Add fixtures in `example/lib/`. `prefer_primary_constructor` stays detection-only until the major ships. Not tested: how analyzer 12.1 handles primary constructors inside the plugin.

### Overlap with official lints

Dart 3.13 adds six lints: `use_declaring_parameters`, `initialize_in_field_declaration`, `unnecessary_const_in_enum_constructor`, `unnecessary_type_name_in_constructor`, `unnecessary_primary_constructor_body`, `empty_container_bodies`. It deprecates three: `avoid_private_typedef_functions`, `one_member_abstracts`, `avoid_null_checks_in_equality_operators`. Check for duplicate saropa rules and doc references. Consider tier recommendations.

### Validation

- `dart pub get` resolves.
- `dart analyze --fatal-infos`. Every deprecation is fixed in the same upgrade.
- Full `dart test`, then `dart format .` (the 3.13 formatter may change output).
- Scan CLI against test projects. All example fixtures compile.
- No regressions in rule behavior.

### Lessons carried over from the analyzer 10 upgrade

- No blind repo-wide search-replace. A rename such as `node.members` applies to some node types only (analyzer 10: the four declaration types).
- The plugin packages (`analyzer_plugin`, `analysis_server_plugin`) can break independently of the analyzer AST.
- Check `.parent is X` patterns after structure changes. Prefer `thisOrAncestorOfType<X>()`.
- Analyzer 10 shipped as v7.0.0 and was retracted the same month and replaced by v8.0.0, because Flutter's `meta` pin made it unresolvable. The test in section 12 exists to prevent a repeat.
- The analyzer 10 `body`/`namePart` changes are already in the code.

## 7. Analyzer version facts (pub.dev, 2026-10-27)

### Pairings

| Plugin `analysis_server_plugin` | Pins analyzer | analyzer sdk | analyzer meta |
|---|---|---|---|
| 0.3.14 | 12.1.0 | ^3.9.0 | ^1.18.0 |
| 0.3.15 | 13.0.0 | ^3.9.0 | ^1.18.0 |
| 0.3.16 / 0.3.17 / 0.3.18 | 13.1.0 / 13.2.0 / 13.3.0 | ^3.11.0 | ^1.18.3 |
| 0.3.19 to 0.3.24 | 14.0.0 to 14.5.0 | ^3.11.0 | ^1.18.3 |
| 0.3.25 | 14.6.0 | ^3.13.0 | ^1.18.3 |

Each plugin release pins one analyzer exactly. pub picks the newest analyzer the project's Dart allows: Dart 3.9/3.10 gets 13.0.0; Dart 3.11/3.12 up to 14.5.0; Dart 3.13 gets 14.6.0.

### Analyzer 14 behavior (analyzer changelog; nothing compiled)

| Version | Date | Change | Effect |
|---|---|---|---|
| 14.0.0 | 2026-06-18 | Removed 5 APIs deprecated in 13.1/13.2 (`isInitializingFormal`, `isSuperFormal`, `formalParameters`, `typeParameters`, `PackageConfigFileBuilder`) | 0 uses in `lib/` |
| 14.1 to 14.4 | | Internal changes; new experimental APIs; `FunctionBody.lookupThisType` replaced by `CompilationUnit.lookupThisType` (14.4) | 0 uses |
| 14.5.0 | 2026-10-06 | `new` in doc comment references no longer parsed; annotations are checked like constant expressions, so diagnostics change; several annotation diagnostics removed | User-visible messages change |
| 14.2 to 14.5 | | Regression: `analyzer: exclude:` patterns from an included options file stop matching | Dart 3.11/3.12 users capped at 14.5.0 keep it |
| 14.6.0 | 2026-10-20 | About 19 diagnostic names replaced by new read/write names (`undefined_getter`, `undefined_method`, `assignment_to_final`, ...). Fixes the `exclude:` regression. Needs Dart 3.13. | Old names in `// ignore:` and `analysis_options.yaml` are still accepted but have no effect |

- The 13.3 to 14.6 source diff shows the V1 `RuleVisitorRegistry` unchanged (183 methods) and no removed AST getter that `lib/` uses.
- The changelog for 13.0.0 to 14.7.0-dev makes no performance or memory claim. Not measured.
- saropa_lints uses none of the new 14 APIs. The 13 changes are forced renames, not features.

### Diagnostic renames: who is affected

- Built-in diagnostics shown in the editor come from the Dart SDK's bundled analyzer, not from the plugin's analyzer. Dart SDK 3.13.7 bundles analyzer 14.1.0-dev, and its changelog does not contain the 14.6.0 rename. So target projects meet the rename when their Dart SDK ships an analyzer at 14.6 or later (a later Dart release), whether or not they use saropa_lints.
- Exposure inside this repo:
  - `lib/`: no use of the renamed diagnostic names. The rule `deprecated_new_in_comment_reference` (`lib/src/rules/core/documentation_rules.dart`) has the same name as an analyzer diagnostic that 14.5 removes, but it detects `[new X]` with its own regex over comment tokens, so it keeps working. Owner decision: rename it to `deprecated_new_in_comment_reference_extended`.
  - `example/lib/avoid_duplicate_elements_fixture.dart` lines 18 and 38-41: `ignore_for_file: undefined_identifier, undefined_getter, ...`. These stop suppressing once the SDK analyzer is 14.6 or later.
- Decision D5 covers whether the extension should find and rewrite old names in target projects.

## 8. Ecosystem and how others handle analyzer majors

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

- No latest release above requires analyzer 12.
- Why the range includes 13: auto_route_generator needs analyzer 13 or lower; hive_ce_generator needs 14.4 or lower.
- Common practice: publish a new version on the new analyzer, leave old versions published, and let pub pick per project. Only analyzer itself back-ports (7.7.1, 8.4.1). This is observed from the packages named here, not a census.
- riverpod_lint moved forward through analyzer majors in patch releases of one 3.1.x line (3.1.1 `^9.0.0`, 3.1.4 `^12.0.0`, 3.1.6 `^13.0.0`, 3.1.9 `>=13.0.0 <15.0.0`). No parallel line.
- custom_lint stalled at analyzer 8 (0.8.1, 2025-09-09). Its users cannot take it on newer analyzers.
- Counter-example: lean_builder 1.2.2 declares `>=10.0.0 <15.0.0` but imports `NamedArgument`, so its lower bound does not compile. A wide range needs a CI job at the lowest end (step 4).
- Not checked: the release process of dart_code_metrics and its successors.

## 9. Flutter and `meta` dates

| Date | Event |
|---|---|
| 2026-04-08 | analyzer 12.1.0 |
| 2026-04-22 | analyzer 13.0.0 |
| 2026-05-18 | Flutter 3.44.0 (Dart 3.12, `meta` 1.18.0 exact) |
| 2026-06-04 | analyzer 13.1.0; `meta` 1.18.3 |
| 2026-06-18 | analyzer 14.0.0; saropa_lints 14.0.3 sets `meta ^1.18.3` |
| 2026-08-06 | Flutter 3.44.9 |
| 2026-08-12 | Flutter 3.47.0 (Dart 3.13.0, `meta ^1.18.3`) |
| 2026-10-20 | analyzer 14.6.0 |
| 2026-10-23 | Flutter 3.47.8 (current stable); 3.50 beta on Dart 3.14 |

- Flutter 3.47.0 has been stable for 76 days. Flutter 3.44.0 for 162 days.
- Analyzer 13.0.0 needs `meta ^1.18.0`, which Flutter 3.44 satisfies. Analyzer 13.1.0 and later need `meta ^1.18.3`, so a Flutter project on any 14.x needs Flutter 3.47.
- The Flutter `meta` pin does not apply to the plugin route. The server resolves the plugin in a private pure-Dart package.

## 10. The two install routes

| | Dev-dependency route (pubspec) | Plugin route (`analysis_options.yaml`) |
|---|---|---|
| Written as | `dev_dependencies: saropa_lints: ^x.y.z` | `plugins: saropa_lints: version: "x.y.z"` |
| Read by | `dart pub get` | The analysis server |
| Analyzer used | The project's resolved analyzer. Must agree with all other dependencies. | Its own, in a private package (`plugin_entrypoint`) that the server builds with `dart pub upgrade`. No clash with the project. |
| Update reminder | pub (`pub outdated`, `pub upgrade`) and the extension's checker | None from pub. The user edits the string by hand. The extension will add a check (decision 2). |
| Needed for | Version resolution, lock file, and `dart run saropa_lints:*` (init, scan, baseline) | Loading lint rules into the editor |

- The README tells users to run `dart pub add --dev saropa_lints`, which creates the dev-dependency route.
- Verified from SDK 3.13.7 source: the server generates `plugin_entrypoint` with `analysis_server_plugin ^0.3.8` and each listed plugin at the configured version. A scratch copy with `saropa_lints: 16.7.0` resolved analyzer 12.1.0, while Contacts resolves 14.6.0 on the same machine.
- Not verified: whether `saropa_lints:init` rewrites the plugin `version:` line, and whether the loader accepts a version range or only an exact version.
- The plugin route gives up version resolution, the lock file and reminders. It is a fallback for projects that cannot resolve a dev dependency, not a replacement.

## 11. Risks

1. **Existing `meta` break** for Flutter 3.44 and older (section 3).
2. **Migration size:** about 1,900 call sites plus 185 changed files since the last migration.
3. **Untested claims:** no compile against analyzer 13 or 14; "13 and 14 share one code path" is source reading only.
4. **Freeze:** projects held on analyzer 12 get no new rules after the major ships (D3).
5. **Extension:** it can offer a version the project cannot resolve, it does not check the plugin version, and it must keep working with 16.x.
6. **Analyzer 14.x behavior:** the 14.2-14.5 `exclude:` regression and the 14.6 diagnostic renames (section 7).
7. **Hard pins:** a target project with `saropa_lints: ^17` or `any` plus tools pinned to analyzer 12 gets a solver error that names the conflict. Choosing 16.x resolves it.
8. **Analyzer below 11:** objectbox_generator (needs `<11`) and custom_lint (needs `^8`) users cannot take any version as a dev dependency. The plugin route still works.
9. **Composite plugins** that import saropa_lints types break on an analyzer floor change. Needs a major version.
10. **Future SDK:** if a future Dart SDK moves `analysis_server_plugin` past `^0.3`, 16.x stops loading as a plugin. Date unknown.
11. **README snippets:** users who copy an old snippet stay on 16.x. The README must state which constraint serves which analyzer line.

## 12. Tests required before publishing the major

1. Compile and run the full test suite at analyzer 13.0.0 (plugin 0.3.15) and at 14.6.0 (plugin 0.3.25).
2. Scratch project held on analyzer 12: `dart pub add saropa_lints` against the new metadata resolves to 16.x; `saropa_lints: ^16.7.0` stays put; `saropa_lints: ^17` fails with a clear message.
3. Scratch project with `meta` pinned to 1.18.0 resolves the 16.x patch (done for the patch on 2026-10-27; repeat on the published artifact).
4. Dart 3.9 to 3.12 projects: confirm which analyzer pub selects at each Dart version.

## 13. Stale statements to fix

- `pubspec.yaml` lines ~104 and ~123: Flutter stable no longer pins `meta` exactly 1.18.0 (3.47.x ships `^1.18.3`).
- `pubspec.yaml` line ~108: analyzer 13.0.0 needs `meta ^1.18.0`, not `^1.18.3`.
- `pubspec.yaml` lines ~159-164: comment says `^1.18.0`, value is `^1.18.3` (fixed by D1).
- `pubspec.yaml` HARD STOP comments on `analysis_server_plugin` and `analyzer`: obsolete once the major ships.
- `PACKAGE_VIBRANCY.md` (~line 43) and the seeded held-back entry for `analyzer >=13.0.0`: same stale `meta` reasoning.
- `CHANGELOG.md`: says 16.7.0 was skipped in favor of 16.8.0; pub.dev shows 16.7.0 published on 2026-10-06.
- Issue 256 comment of 2026-08-29: says riverpod_lint, freezed and drift_dev are stuck on analyzer 12. They moved to 13/14.
- The comment in `scripts/check_plan_naming.py` names the removed plan file.
- Old claim "unresolvable in any Flutter-stable app": true only for the dev-dependency route on Flutter 3.44 and older.

## 14. Unknowns

- The share of target projects still on analyzer 12. pub.dev has no per-version download data.
- Whether any analyzer version below 14.6.0 compiles. Nothing was built.
- How analyzer 12.1 handles Dart 3.13 primary constructors inside the plugin.
- Whether the extension works with `dart pub global activate saropa_lints` without changes.
- Whether `saropa_lints:init` rewrites the plugin version, and whether the loader accepts a range.
- How many projects were hit by the `meta` break, and whether anyone reported it.
- Performance and memory of analyzer 14 compared with 12.
