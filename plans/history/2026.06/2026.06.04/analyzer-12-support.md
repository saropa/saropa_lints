# Analyzer 12 support

The `analyzer: ">=9.0.0 <12.0.0"` cap carried a comment claiming the package must stay below analyzer 12 because Flutter stable pinned `meta 1.17.0`. That meta precondition is now met (Flutter 3.44.1 ships `meta 1.18.0`), so the cap can move to admit analyzer 12 — but only after migrating the plugin source for analyzer 12's breaking API changes.

## Finish Report (2026-06-04)

### Scope

(A) Dart lint rules / analyzer plugin. Dependency-constraint change plus the source migration it requires. No new rules, no tier changes, no `example/` fixtures.

### What changed and why

1. **`pubspec.yaml`** — `analyzer` `>=9.0.0 <12.0.0` → `>=9.0.0 <13.0.0`; `analyzer_plugin` `<0.14.7` → `<0.15.0`. The `<13` cap is the single forcing function: pub's solver picks analyzer 12.1.0 (13.1.0 is avoided because it needs `meta ^1.18.3`, above Flutter stable's exact `meta 1.18.0` pin). The `analyzer_plugin` cap had to rise in lockstep — no `analyzer_plugin` below 0.14.7 supports analyzer 12, so leaving `<0.14.7` would have made resolution pick analyzer 11 again (a silent no-op bump). Both dependency comments were rewritten: the old text blamed Flutter's `meta 1.17.0`, which is stale; the live blocker is analyzer 13's `meta ^1.18.3` floor.

2. **`lib/src/rules/core/naming_style_rules.dart`** and **`lib/src/rules/architecture/structure_rules.dart`** — `final LibraryIdentifier? x = node.name;` → `final x = node.name;`. Analyzer 12 changed `LibraryDirective.name` from `LibraryIdentifier?` to `DottedName?`. Removing the explicit version-specific annotation lets inference pick the correct per-version type; `.toSource()` and `reporter.atNode(...)` work on both because both types are `AstNode`s. Behaviorally identical on analyzer 11.

3. **`lib/src/scan/capturing_registry.dart`** — added `addBlockEnumBody` and `addEmptyEnumBody`. Analyzer 12 split the single `addEnumBody` into these two and dropped `addEnumBody`; the file previously omitted the split pair while pinned `<12`. All three are now implemented so the class satisfies the `RuleVisitorRegistry` interface on both analyzer 9-11 (`addEnumBody`) and 12 (the split pair). The unused override on each version is an `override_on_non_overriding_member` warning, already suppressed by the `lib/**` analyzer exclude.

4. **`test/rules/widget/flutter_migration_widget_detection_test.dart`** — comment-only. The stale "we pin to analyzer <12 / Flutter meta 1.17.0" note was corrected; the `cls.body as BlockClassBody` cast stays valid because analyzer 12 kept `BlockClassBody` as a subtype.

5. **`CHANGELOG.md`** — new `## [Unreleased]` → `### Changed` entry. pubspec `version` left at 13.11.14 (version bump belongs to the publish flow, not run).

### Verification

- **CI command** (`dart analyze --fatal-infos`): clean, exit 0. Note: `analysis_options.yaml` excludes `lib/**` by design (rule source trips its own rules), so this command does NOT cover plugin source — the two compile-level API breaks were invisible to it and only surfaced when running the test suite. An initial "analyze clean" claim was wrong for this reason and was corrected.
- **Full test suite under analyzer 12.1.0**: 6035 pass, 1 skipped, 0 fail.
- **Full test suite under analyzer 11.0.0** (temporary pin, then restored): the 3 affected test files + scan = 208 pass, 0 fail. Confirms the migration is non-breaking on the currently-shipping analyzer version.
- **Analyzer 9 floor**: cannot be exercised on the local Dart 3.12.1 SDK — downgrading pulls package versions whose compile pipeline fails (`frontend_server.dart.snapshot` missing). Pre-existing SDK/analyzer-9 incompatibility, independent of this change; the declared `>=9.0.0` floor was not modified.
- **Flutter consumer simulation**: throwaway Flutter 3.44.1 app + local path dep resolved `meta 1.18.0` (held at Flutter's pin), `analyzer 12.1.0` (13.1.0 avoided), saropa_lints from path — clean. This is the decisive check; the package's own pure-Dart solve does not reproduce the `meta` pin (it grabs 1.18.3).

### Outstanding

- analyzer 13 cannot be admitted until Flutter stable ships `meta ^1.18.3`; the `<13` cap and its comment document this.
- The throwaway Flutter test project at `d:\tmp\flutter_meta_check` could not be deleted (a Dart process held a file lock during the session); left to decay in `d:\tmp`.
- No version bump / publish performed (per standing instruction).
