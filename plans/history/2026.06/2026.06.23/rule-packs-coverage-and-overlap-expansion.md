# Rule Packs — coverage and overlap expansion

Before this change, large parts of the rule tree (most `widget/`, several `core/`,
and the `commerce/`, `hardware/`, `codegen/`, and parts of `config/` and `resources/`
directories) belonged to no selectable Rule Pack, so users browsing the VS Code Rule
Packs sidebar or grouping findings by pack saw those rules only under "No pack". This
change adds sixteen new concern ("theme") packs — thirteen that close the coverage gaps
and three cross-cutting "lens" packs that deliberately span the existing taxonomy.

## Finish Report (2026-06-23)

### Scope
- (A) Dart lint registry + generator tooling.
- (B) Generated VS Code extension artifact (`rulePackDefinitions.ts`) — regenerated, not
  hand-edited.

### What changed
- `tool/generate_rule_pack_registry.dart` — extended the `kThemePacks` map (the single
  source for concern packs) with sixteen new entries. Each maps a stable pack id and human
  label to one or more rule source paths under `lib/src/rules/`; rosters are derived at
  generation time by scanning those paths for `LintCode('...')` names, so the packs extend
  automatically when rules are added to a covered file.
  - Coverage packs (each gives a previously-unpacked file a home): `widgets`, `layout`,
    `animation`, `dialogs`, `notifications`, `naming`, `class_design`, `build_context`,
    `in_app_purchase`, `hardware`, `freezed`, `file_io`, `project_config`.
  - Overlapping "lens" packs (intentionally cross category boundaries; additive merge means
    a shared rule is never double-counted): `leak_prevention`, `ui_polish`,
    `release_readiness`.
- `lib/src/config/rule_pack_codes_generated.dart` and
  `extension/src/rulePacks/rulePackDefinitions.ts` — regenerated from the generator. Theme
  pack count moved from 14 to 30.
- `CHANGELOG.md` — Unreleased overview sentence plus an `Added (Extension)` bullet.

### Why this approach
Concern packs are the established mechanism for cross-cutting, non-package, non-SDK rule
bundles. Their rosters derive from the source tree rather than hand-maintained lists, and
the additive merge model already supports a rule belonging to several packs at once, so
both the coverage packs and the overlapping lens packs fit the existing design with no
new code paths. Theme packs auto-receive their advisory `flutter` pubspec marker via the
generator, which preserves the `kRulePackPubspecMarkers.keys == kRulePackRuleCodes.keys`
invariant without manual marker entries.

### Validation
- `dart run tool/generate_rule_pack_registry.dart` — wrote both generated files, 30 theme
  packs, zero WARN lines (every pack matched at least one `LintCode`).
- `dart run tool/rule_pack_audit.dart` — exit 0 (the "REGISTRY ONLY" lines are pre-existing
  informational notes for non-package packs).
- `dart test test/config/rule_pack_registry_test.dart
  test/config/rule_packs_pubspec_markers_test.dart test/config/rule_packs_config_test.dart
  test/config/rule_packs_migration_membership_test.dart
  test/config/rule_packs_sdk_gates_test.dart test/config/rule_packs_semver_test.dart` — all
  pass. The marker-keys/rule-code-keys invariant and the "every pack declares ≥1 marker"
  invariant both held.
- Extension `rulePackDefinitions.test.ts` asserts only specific known packs are present and
  carry rosters (no hardcoded pack count or full-list assertion), so the additions do not
  break it.

### Notes for maintainers
- No new lint rules, no `tiers.dart` changes, no quick fixes — packs reference existing
  rule codes only; rule and quick-fix counts are unchanged.
- Pack labels are emitted inline (English) into the generated `rulePackDefinitions.ts`,
  matching the pre-existing convention for every pack label in that generated registry; no
  `en.json` keys were added, so the extension catalog generator is a no-op for this change.
- `core/documentation_rules.dart`, `testing/*`, and `ui/internationalization_rules.dart`
  were intentionally not given new coverage packs because the existing tier-roster packs
  (`documentation`, `testing`, `localization`) already cover them.
