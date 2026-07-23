# Extension sidebar view icons

The VS Code extension's five contributed sidebar views (Banner, Editor Dashboards, Status, Settings, Help) had no `icon` property, which the extension manifest schema flags and which left the views unlabeled if a user dragged one out of the activity bar panel into another container.

## Finish Report (2026-07-12)

Added an `icon` property to each of the five view entries under `contributes.views.saropaLints` in `extension/package.json`, using built-in VS Code codicon references (no new asset files):

- `saropaLints.banner` → `$(info)`
- `saropaLints.editorDashboards` → `$(graph)`
- `saropaLints.status` → `$(warning)`
- `saropaLints.settings` → `$(gear)`
- `saropaLints.help` → `$(question)`

**Scope:** Extension manifest only (`extension/package.json`); no TypeScript logic or Dart rule changes.

**Review:** Confirmed via grep that no test in `extension/src/test/` references the view `icon` field, so no test assertions required updating.

**Localization:** No new user-facing text was added — codicon references (`$(name)`) are icon identifiers, not translatable copy, so no `en.json` or catalog changes apply.

**Changelog:** Added a `### Fixed` bullet under the `[14.3.3]` (unreleased) section in `CHANGELOG.md`.
