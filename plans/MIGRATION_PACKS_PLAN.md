# Migration Packs Plan

Created 2026-09-02. Adds rule packs to the VS Code extension that surface
saropa_lints rules equivalent to each alternative lint package, enabling
one-click migration from any alternative to saropa.

## Concept

The rule pack system already supports this pattern. Each alternative package
gets a **migration pack** — a curated set of existing saropa rules that cover
what that package provided. When a user has e.g. `pyramid_lint` in their
pubspec, the extension detects it and surfaces a "Migrate from pyramid_lint"
pack in the "For your project" accordion. Toggling it on enables the subset
of saropa rules that replace pyramid_lint's rules.

No new Dart rule classes are needed — migration packs are subsets of existing
rules. No new UI code is needed — the webview, toggle, YAML persistence, and
detection all operate generically over `RULE_PACK_DEFINITIONS`.

## Architecture

### Pack registration (Dart side)

File: `lib/src/config/rule_packs.dart` (or a new `migration_packs.dart` if
the file gets too large).

- Pack id format: `migrate_<package>` (e.g. `migrate_pyramid_lint`)
- `matchPubNames`: the source package name (e.g. `['pyramid_lint']`) so
  detection fires when the user still has the old package in pubspec
- Rule codes: the HAVE column from each migration guide's rule mapping table
- No dependency gates needed — migration packs fire on pubspec presence alone

### Generated registry (TS side)

Run `dart run tool/generate_rule_pack_registry.dart` to propagate changes to
`extension/src/rulePacks/rulePackDefinitions.ts` automatically.

### Domain grouping

File: `extension/src/rulePacks/packDomains.ts`

- Add `'Migrations'` to `PACK_DOMAIN_ORDER` (after `SDK_DOMAIN`, before
  `OTHER_DOMAIN`)
- Map each `migrate_*` id to `'Migrations'`

### l10n

File: `extension/src/i18n/locales/en.json`

- Add keys under `rulePacks.migration.*` namespace
- Label pattern: `"Migrate from {name}"`
- Regenerate translations after

## Which packages get migration packs

Only packages with meaningful HAVE coverage (≥40% or ≥3 rules). Packages
with near-zero coverage produce empty/trivial packs — those guides exist for
documentation but don't warrant a pack.

### Tier 1 — high coverage, ship first (16 packages)

| Package | HAVE rules | Total | Coverage |
|---------|-----------|-------|----------|
| DCM | 421 | 487 | 86% |
| flutter_skill_lints | 231 | 279 | 83% |
| many_lints | 190 | 261 | 73% |
| awesome_lints | 100 | 123 | 81% |
| dart_code_linter | 68 | 82 | 83% |
| dart_code_metrics_presets | 27 | 77 | 35% |
| pyramid_lint | 24 | 36 | 67% |
| solid_lints | 15 | 31 | 48% |
| flutter_quality_lints | 15 | 18 | 83% |
| essential_lints | 9 | 27 | 33% |
| leancode_lint | 9 | 23 | 39% |
| mad_lint | 7 | 13 | 54% |
| flutter_doctor_ai | 5 | 5 | 100% |
| ripplearc_linter | 5 | 24 | 21% |
| flutter_hooks_lint | 4 | 7 | 57% |
| bloc_lint | 3 | 9 | 33% |

### Tier 2 — moderate coverage (8 packages)

| Package | HAVE rules | Total | Coverage |
|---------|-----------|-------|----------|
| VGA | ~15 enhanced | ~206 | complementary |
| flutter_best_practices_lints | 2 | 5 | 40% |
| flutter_custom_lints | 2 | 5 | 40% |
| flutter_sane_lints | 2 | 2 | 100% |
| klin_dart | 2 | 6 | 33% |
| hardcoded_strings_lint | 1 | 1 | 100% |
| equatable_lint | 1 | 2 | 50% |
| accessibility_lint | 3 | 5 | 60% |

### Skip — guide-only, no pack (14 packages)

all_observer_lint, context_plus_lint, logd_linters, fast_equatable_lint,
import_lint, json_serializable_lints, json_parser_linter,
jsdaddy_custom_lints, architecture_lints, architecture_linter,
clean_architecture_kit, design_system_lints, df_safer_dart_lints,
subpackage_lint, team_guard, mvvm_linter, import_order_lint,
equatable_lint_ultimate, flutter_refactor_plugin,
dart_code_metrics_annotations

## Implementation steps

| Step | Files | Effort | Depends on |
|------|-------|--------|------------|
| A. Harden dead-package guide language | 3 MD files | Small | — |
| B. Extract HAVE rule codes from each migration guide into pack maps | 1 Dart file | Medium | — |
| C. Run `generate_rule_pack_registry.dart` | generated TS | Trivial | B |
| D. Add `'Migrations'` domain + id mappings | packDomains.ts | Small | C |
| E. Add l10n keys for migration pack labels | en.json | Small | D |
| F. Run tests (`rule_pack_*` test suite) | — | Small | B-E |
| G. Update README index | 1 MD file | Trivial | A |

Step A is done (2026-09-02).

## Open questions

1. **VGA** is a preset-only package (stock analyzer rules, not custom_lint).
   Its migration pack would list the ~15 saropa rules that are enhanced
   equivalents of VGA stock rules. Worth doing, but the `matchPubNames`
   detection is different — VGA users include it via `analysis_options.yaml`
   `include:`, not a pubspec dependency. May need special detection or
   manual opt-in only.

2. **DCM** is a commercial product (dcm.dev) with 487 rules. A migration
   pack with 421 rule codes is large. Consider whether the pack should be
   split into sub-packs (DCM-common, DCM-flutter, DCM-bloc, DCM-riverpod)
   matching DCM's own categories, or kept as one large pack.

---

_Last updated: 2026-09-02_
