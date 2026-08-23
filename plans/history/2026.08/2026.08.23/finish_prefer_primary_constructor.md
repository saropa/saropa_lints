# Finish Report: prefer_primary_constructor rule

New lint rule `prefer_primary_constructor` flags Dart classes eligible for Dart 3.13+ primary constructor syntax, gated on the project's `pubspec.yaml` SDK lower bound being >=3.13.0.

## Finish Report (2026-08-23)

### What changed

A new `SaropaLintRule` subclass `PreferPrimaryConstructorRule` was added at `lib/src/rules/config/dart_sdk_migration_rules.dart`. The rule reads the project's `pubspec.yaml` SDK lower bound (mtime-cached per project root, mirroring `lib/src/config/pubspec_lock_resolver.dart` so a live SDK-constraint bump is picked up without a plugin restart) and only registers class-declaration analysis when the lower bound is >=3.13.0.

Detection logic (`isPrimaryConstructorEligible`, a top-level `@visibleForTesting` function, purely syntactic — no resolved-type dependency) implements the proposal's 10 eligibility conditions plus two additional exclusions found during review:

- `late final` fields (no primary-constructor equivalent for `late`, even though the field is final).
- Fields or constructor parameters carrying their own annotation (no established placement rule for an annotation on a primary-constructor parameter).

Tier: Professional. Severity: INFO. Impact: info. RuleType: codeSmell. Cost: medium. `usesTypeResolution`: false (corrected during review — the rule never touches a resolved type).

No quick fix was implemented; the proposal's Quick Fix section (const/doc/annotation preservation, named-param handling) is a separate, more involved follow-up.

### Registration

- Export: `lib/src/rules/all_rules.dart` — `export 'config/dart_sdk_migration_rules.dart'`
- Factory: `lib/saropa_lints.dart` — `PreferPrimaryConstructorRule.new`
- Tier: `lib/src/tiers.dart` — `'prefer_primary_constructor'` in `professionalOnlyRules`

### Testing

- `test/rules/config/dart_sdk_migration_rules_test.dart`: instantiation/metadata pin, tier-registration check, 6 `sdkIsAtLeast` boundary tests, and 21 `isPrimaryConstructorEligible` behavior tests parsing real (unresolved) ASTs via `parseString` — covering all 15 fixture scenarios from the proposal plus the two additional exclusions above. 28/28 pass.
- Fixture added at `example/lib/config/prefer_primary_constructor_fixture.dart` (17 classes: the proposal's 15 scenarios plus `late final` and annotated-field cases). The fixture cannot fire inside this repo's own `example/` project because `example/pubspec.yaml` declares `sdk: ">=3.9.0 <4.0.0"`, below the rule's 3.13.0 gate — confirmed by scanning `example/lib/config/` at Professional tier (0 diagnostics, as expected). Bumping the example project's shared SDK constraint was considered and rejected as an unauthorized shared-infrastructure change; behavior is instead proven directly against `isPrimaryConstructorEligible`.
- An external throwaway probe project (SDK >=3.13.0, outside the repo) was attempted to prove end-to-end CLI firing but the scan CLI reported 0 files processed for any rule on that path (environment/CLI-path issue, not reproduced against in-repo paths) — abandoned after reasonable effort; see handoff reflection.
- `dart test test/rules/config/ test/integrity/saropa_lints_test.dart`: 241/241 pass. No regressions.
- `dart format`: clean on all touched files.

### Review findings addressed

A delegated review (general-purpose agent, sonnet) flagged four items, all fixed:

1. SDK-lower cache had no invalidation — fixed with an mtime-keyed cache plus `clearDartSdkMigrationCacheForTests()`.
2. `usesTypeResolution` was incorrectly `true` for a purely syntactic rule — changed to `false`.
3. No behavior test existed to prove detection logic correct — added (see Testing above).
4. `late final` and annotated fields/params were unhandled false-positive sources — excluded, with fixture + test coverage added.
