# Plan naming convention + cross-reference consistency pass

Seven plan files belonging to the extension UI redesign family had inconsistent naming
(`PLAN_extension_ui_redesign.md`, `PLAN_central_dashboard_consolidation.md`,
`PLAN_sidebar_and_hub_reset.md`, etc.) with no shared prefix grouping them. Internal
cross-references used the old names, and several plans carried stale information.

## Changes

### Naming convention

All 7 UI-redesign plans renamed to share the `PLAN_ext_ui_` prefix via `git mv`:

| Old name | New name |
|---|---|
| `PLAN_extension_ui_redesign.md` | `PLAN_ext_ui_redesign.md` |
| `PLAN_central_dashboard_consolidation.md` | `PLAN_ext_ui_dashboard_consolidation.md` |
| `PLAN_sidebar_and_hub_reset.md` | `PLAN_ext_ui_sidebar_reset.md` |
| `PLAN_report_styles_migration.md` | `PLAN_ext_ui_report_styles.md` |
| `PLAN_dart_side_deferred.md` | `PLAN_ext_ui_dart_deferred.md` |
| `PLAN_optimizer_embed_sort_bulk.md` | `PLAN_ext_ui_optimizer_embed.md` |
| `PLAN_package_dashboard_embedded_tabs.md` | `PLAN_ext_ui_package_tabs.md` |

The 7 unrelated plans (`PLAN_comment_coverage.md`, `PLAN_migration_plugin_system.md`, etc.)
were not renamed — they do not belong to a family.

### Cross-reference updates

All 12 internal `Parent:` / `Relationship to:` / `Supersedes:` references across the 7 plan
files updated to use the new filenames. Stale references in `plans/history/` were left as-is
(historical record, not active navigation).

### Redundancy and consistency fixes

1. **Parent plan Phase 6 deferred items** — dead code removal (`transformProjectMapHtml`,
   `webviewThemeOverride`, `pmPaneThemeTokens`) and unit test creation for projectMapShell/Reports
   marked `[x]` DONE with 2026-09-05 date and description.

2. **Parent plan Phase 7 deferred item** — keyboard shortcuts overlay for Rules & Tiers and
   Project Map marked `[x]` DONE with 2026-09-05 date.

3. **Parent plan** — added a "Related plans" index block listing all 6 child/sibling plans
   with one-line role descriptions.

4. **Dashboard consolidation plan list C** — annotated that the Home hub (the intended host
   for summary cards) was removed in commit `ea2c7a8e`. Noted that sidebar live descriptions
   from `PLAN_ext_ui_sidebar_reset.md` may make these cards unnecessary.

5. **Dart-deferred plan WP5** — annotated as TS-only (no Dart changes needed despite the
   plan's "Dart-side" title). Updated the stale "Home hub" reference to note its removal.
