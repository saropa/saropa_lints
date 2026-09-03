# Fix: Core Dart Lint Name Collisions Blocking Publish

Two saropa_lints rule names — `avoid_null_checks_in_equality_operators` and
`prefer_initializing_formals` — collided with core Dart/Flutter analyzer lint
names, triggering the publish script's Check 8 (core lint collision gate) and
blocking release.

## Finish Report (2026-09-03)

### Root cause

The collision guard rail (Check 8 in `_tier_integrity.py`) was added in the
August 2026 rename pass, but these two rules survived unrenamed:

- `avoid_null_checks_in_equality_operators` was added AFTER the rename pass
  (in the 15.2.10 unreleased batch) and was never checked against the core
  lint namespace.
- `prefer_initializing_formals` was marked for DROP in the rename plan but
  was re-added in 15.2.10 with a saropa-specific implementation (inverse-rule
  pairing with `prefer_constructor_body_assignment`, saropa metadata).

### Fix

Both rules renamed with `_extended` suffix per the project's established
collision-rename convention:

| Old name | New name |
|----------|----------|
| `avoid_null_checks_in_equality_operators` | `avoid_null_checks_in_equality_operators_extended` |
| `prefer_initializing_formals` | `prefer_initializing_formals_extended` |

### Files changed

- `lib/src/rules/data/equality_rules.dart` — LintCode name + message prefix
- `lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart` — same
- `lib/src/tiers.dart` — tier set entries (2 lines)
- `test/rules/data/equality_rules_test.dart` — assertion strings
- `test/rules/stylistic/stylistic_whitespace_constructor_rules_test.dart` — same
- `example/lib/equality/avoid_null_checks_in_equality_operators_fixture.dart` — expect_lint + comments
- `example/lib/stylistic_whitespace_constructor/prefer_initializing_formals_fixture.dart` — same
- `CHANGELOG.md` — updated rule name references + noted suffix reason
- `README_STYLISTIC.md` — code comment reference
- `self_check/reports/.saropa_lints/consumer_contract.json` — rule name entry

### Hardening (post-review)

- Fixture files renamed on disk to match rule names
  (`*_extended_fixture.dart` suffix).
- Stale plan references updated:
  - `PLAN_quick_fix.md` → `prefer_initializing_formals_extended`
  - `PLAN_analyzer_13_migration.md` → annotated with saropa equivalent name
- Migration docs updated:
  - `migration_from_vga.md` → both rules marked ENHANCED with new names
  - `migration_from_dcm.md` → `prefer-initializing-formals` marked HAVE

### Dart-side collision guard (new)

Added `test/integrity/core_lint_collision_test.dart` — reads
`CORE_DART_LINT_NAMES` from the Python module at test time and fails if
any registered saropa_lints rule name collides. Catches collisions during
`dart test`, not just at publish time.

### Verification

- Tier integrity check: ALL CHECKS PASSED (0 collisions)
- Rule tests: 61 pass
- Integrity tests: 2705 pass
- Core lint collision test: 1 pass
