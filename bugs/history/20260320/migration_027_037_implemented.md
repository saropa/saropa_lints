# Migration candidates #027 and #037 — implemented

**Date:** 2026-03-20  
**Source plans:** `plan/implementable_only_in_plugin_extension/migration-candidate-027-*.md`, `migration-candidate-037-*.md` (moved here as completed).

## Summary

| Plan | Rule | Notes |
|------|------|--------|
| #027 (Flutter 3.24, PR #147621) | `prefer_super_key` | `Key? key` + `super(key: key)` on widget subclasses → `super.key`. Quick fix. Shared detection: `flutter_migration_widget_detection.dart`. `LintImpact.medium`. |
| #037 (Flutter 3.22, PR #144319) | `avoid_chip_delete_inkwell_circle_border` | Chip `deleteIcon` with `InkWell` + `CircleBorder` `customBorder`. No auto-fix. Uses `InstanceCreationExpression` **and** unqualified `MethodInvocation` for chip calls; nested `InkWell`/`CircleBorder` support both parse shapes. `requiredPatterns` + `RuleCost.medium`. |

## Tests

- `test/flutter_migration_widget_detection_test.dart` — AST-based before/after and false-positive cases.
- `test/flutter_migration_widget_rules_test.dart` — metadata and fix registration.
- Fixture: `example/lib/flutter_migration_widget_rules_fixture.dart` (primary; `example_widgets` does not cross-import `example/lib` mocks).

## Original plan files

Archived next to this note as `migration-candidate-027-*.md` and `migration-candidate-037-*.md`.
